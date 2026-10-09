// Behaviour tests for the four flows a judge is most likely to try: signing in (routing by
// role), redeeming (button states), scanning a bad code (error dialogs) and the admin QR
// countdown. No Firebase: sign-in and the clock are injected; screens that load data after
// routing simply show their offline state.

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ecoreward_bin/core/admin_theme.dart';
import 'package:ecoreward_bin/core/app_theme.dart';
import 'package:ecoreward_bin/core/auth_messages.dart';
import 'package:ecoreward_bin/models/models.dart';
import 'package:ecoreward_bin/screens/admin/admin_dashboard_screen.dart';
import 'package:ecoreward_bin/screens/admin/admin_qr_screen.dart' show ExpiryRing;
import 'package:ecoreward_bin/screens/customer/customer_home_screen.dart';
import 'package:ecoreward_bin/screens/customer/reward_detail_screen.dart';
import 'package:ecoreward_bin/screens/customer/scan_errors.dart';
import 'package:ecoreward_bin/screens/login_screen.dart';
import 'package:ecoreward_bin/services/firebase_service.dart' show QRValidationResult;
import 'package:ecoreward_bin/widgets/ui.dart';

Widget _app(Widget home, {ThemeData? theme}) => MaterialApp(theme: theme ?? AppTheme.light, home: home);

/// Unmounts and runs pending timers, so no animation or delayed callback leaks between tests.
Future<void> _finish(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 20));
}

UserModel _user(String role, {int points = 0}) =>
    UserModel(uid: 'u-$role', username: 'Test $role', email: '$role@example.com', role: role,
        points: points, createdAt: DateTime(2026, 1, 1));

void main() {
  setUpAll(() => SharedPreferences.setMockInitialValues({'notifications_prompted': true}));

  // ── Login routing ───────────────────────────────────────────────────────────
  group('Login routing', () {
    Future<List<String>> signInAs(WidgetTester tester, Future<UserModel> Function(String, String) signIn,
        {String email = 'me@example.com', String password = 'secret1'}) async {
      final calls = <String>[];
      await tester.pumpWidget(_app(LoginScreen(signIn: (e, p) {
        calls.add('$e|$p');
        return signIn(e, p);
      })));
      await tester.pump(const Duration(seconds: 2));   // form entrance
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), email);
      await tester.enterText(fields.at(1), password);
      await tester.ensureVisible(find.byType(GlowButton));
      await tester.tap(find.byType(GlowButton));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));   // route fade
      return calls;
    }

    testWidgets('an admin lands on the admin dashboard', (tester) async {
      await signInAs(tester, (_, __) async => _user('admin'));
      expect(find.byType(AdminDashboardScreen), findsOneWidget);
      expect(find.byType(LoginScreen), findsNothing);
      await _finish(tester);
    });

    testWidgets('a customer lands on the customer home', (tester) async {
      await signInAs(tester, (_, __) async => _user('customer'));
      expect(find.byType(CustomerHomeScreen), findsOneWidget);
      expect(find.byType(AdminDashboardScreen), findsNothing);
      await _finish(tester);
    });

    testWidgets('email and password are trimmed before signing in', (tester) async {
      final calls = await signInAs(tester, (_, __) async => _user('customer'),
          email: '  me@example.com ', password: ' secret1  ');
      expect(calls, ['me@example.com|secret1']);
      await _finish(tester);
    });

    testWidgets('wrong credentials stay on Login with a friendly message', (tester) async {
      await signInAs(tester, (_, __) async => throw FirebaseAuthException(code: 'invalid-credential'));
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.text(loginErrorMessage('invalid-credential')), findsOneWidget);
      // The button is usable again (not stuck in its loading state).
      expect(tester.widget<GlowButton>(find.byType(GlowButton)).loading, isFalse);
      await _finish(tester);
    });

    testWidgets('an invalid form never calls sign-in', (tester) async {
      final calls = await signInAs(tester, (_, __) async => _user('customer'), email: 'not-an-email', password: '');
      expect(calls, isEmpty);
      expect(find.text('Enter a valid email'), findsOneWidget);
      expect(find.text('Enter your password'), findsOneWidget);
      expect(find.byType(LoginScreen), findsOneWidget);
      await _finish(tester);
    });
  });

  // ── Redeem button states ────────────────────────────────────────────────────
  group('Redeem button', () {
    Reward reward({int cost = 500, int stock = -1}) =>
        Reward(id: 'r1', title: 'Free Latte', description: 'Any size', pointsCost: cost, category: 'Coffee', stock: stock);

    /// Opens the detail screen on top of another route, as the Rewards tab does.
    Future<void> open(WidgetTester tester, Reward r, int points) async {
      await tester.pumpWidget(_app(Builder(builder: (ctx) => Scaffold(body: Center(child: TextButton(
            onPressed: () => Navigator.push<bool>(ctx, MaterialPageRoute(builder: (_) => RewardDetailScreen(
                reward: r, user: _user('customer', points: points), heroTag: 'h', icon: Icons.coffee, color: Colors.brown))),
            child: const Text('open')))))));
      await tester.tap(find.text('open'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
    }

    HoldToConfirmButton button(WidgetTester tester) => tester.widget(find.byType(HoldToConfirmButton));

    /// Presses the hold button for [held], frame by frame (the fill only advances on frames).
    Future<void> hold(WidgetTester tester, Duration held) async {
      await tester.ensureVisible(find.byType(HoldToConfirmButton));
      await tester.pump();
      final gesture = await tester.startGesture(tester.getCenter(find.byType(HoldToConfirmButton)));
      for (var t = Duration.zero; t < held; t += const Duration(milliseconds: 50)) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      await gesture.up();
      await tester.pump(const Duration(seconds: 1));
    }

    testWidgets('affordable: "Hold to redeem"; a full hold confirms', (tester) async {
      await open(tester, reward(cost: 500), 600);
      expect(button(tester).label, 'Hold to redeem');
      expect(button(tester).onConfirmed, isNotNull);

      await hold(tester, const Duration(milliseconds: 1500));   // past the 1.1 s hold
      expect(find.byType(RewardDetailScreen), findsNothing, reason: 'the detail screen closes with a confirmation');
      await _finish(tester);
    });

    testWidgets('affordable: letting go early does not redeem', (tester) async {
      await open(tester, reward(cost: 500), 600);
      await hold(tester, const Duration(milliseconds: 500));
      expect(find.byType(RewardDetailScreen), findsOneWidget);
      await _finish(tester);
    });

    testWidgets('not enough points: disabled and says how many are missing', (tester) async {
      await open(tester, reward(cost: 500), 380);
      expect(button(tester).label, 'Need 120 more points');
      expect(button(tester).onConfirmed, isNull);
      expect(find.text('120 more points needed'), findsOneWidget);
      await _finish(tester);
    });

    testWidgets('sold out: disabled even with enough points', (tester) async {
      await open(tester, reward(cost: 500, stock: 0), 9000);
      expect(button(tester).label, 'Sold out');
      expect(button(tester).onConfirmed, isNull);
      await _finish(tester);
    });
  });

  // ── Scanner errors ──────────────────────────────────────────────────────────
  group('Scanner errors', () {
    test('bin codes are read exactly as before (ECOBIN:<Type>:<uuid>)', () {
      final ok = parseBinCode('ECOBIN:Recyclable:123e4567-e89b-12d3-a456-426614174000');
      expect(ok.error, isNull);
      expect(ok.wasteType, 'Recyclable');
      expect(ok.token, '123e4567-e89b-12d3-a456-426614174000');
      for (final type in kBinWasteTypes) {
        expect(parseBinCode('ECOBIN:$type:abc').error, isNull);
      }
    });

    test('codes that are not ours, or carry an unknown type, are rejected', () {
      expect(parseBinCode('https://example.com').error, ScanError.notOurs);
      expect(parseBinCode('ECOBIN:Recyclable').error, ScanError.notOurs);
      expect(parseBinCode('ecobin:Recyclable:abc').error, ScanError.notOurs);
      expect(parseBinCode('ECOBIN:Plastic:abc').error, ScanError.badType);
      expect(parseBinCode('ECOBIN:recyclable:abc').error, ScanError.badType);
    });

    test('each server result maps to its message (valid shows none)', () {
      expect(scanErrorFor(QRValidationResult.valid), isNull);
      expect(scanErrorFor(QRValidationResult.expired), ScanError.expired);
      expect(scanErrorFor(QRValidationResult.alreadyUsed), ScanError.alreadyClaimed);
      expect(scanErrorFor(QRValidationResult.invalid), ScanError.notFound);
      expect(ScanError.expired.message, contains('20 minutes'));
    });

    for (final e in ScanError.values) {
      testWidgets('dialog "${e.title}": copy, icon and both actions', (tester) async {
        var scanAgain = 0, back = 0;
        await tester.pumpWidget(_app(Builder(builder: (ctx) => Scaffold(body: TextButton(
              onPressed: () => showScanErrorDialog(ctx, e, onScanAgain: () => scanAgain++, onBack: () => back++),
              child: const Text('show'))))));

        Future<void> show() async {
          await tester.tap(find.text('show'));
          await tester.pump(const Duration(milliseconds: 500));
        }

        await show();
        expect(find.text(e.title), findsOneWidget);
        expect(find.text(e.message), findsOneWidget);
        expect(find.byIcon(e.icon), findsOneWidget);
        // Expired / already claimed are amber (not the customer's fault); the rest are red.
        final colors = tester.element(find.text(e.title)).colors;
        expect(tester.widget<Icon>(find.byIcon(e.icon)).color, e.warning ? colors.warning : colors.danger);

        await tester.tap(find.text('Scan again'));
        await tester.pump(const Duration(milliseconds: 500));
        expect(find.byType(AlertDialog), findsNothing);
        expect((scanAgain, back), (1, 0));

        await show();
        await tester.tap(find.text('Back to Home'));
        await tester.pump(const Duration(milliseconds: 500));
        expect(find.byType(AlertDialog), findsNothing);
        expect((scanAgain, back), (1, 1));
        await _finish(tester);
      });
    }
  });

  // ── Admin QR countdown ──────────────────────────────────────────────────────
  group('Admin QR countdown', () {
    const total = Duration(minutes: 20);

    Future<void Function(Duration)> ring(WidgetTester tester, Duration left, {VoidCallback? onExpired}) async {
      var now = DateTime(2026, 10, 10, 9);
      final expiresAt = now.add(left);
      await tester.pumpWidget(_app(
          Scaffold(body: Center(child: ExpiryRing(
              expiresAt: expiresAt, total: total, onExpired: onExpired ?? () {}, now: () => now,
              child: const SizedBox(width: 100, height: 100)))),
          theme: AppTheme.admin));
      return (d) => now = now.add(d);
    }

    Color readoutColor(WidgetTester tester) =>
        tester.widget<Text>(find.textContaining(RegExp(r'^\d\d:\d\d$'))).style!.color!;

    testWidgets('starts at 20:00 in green and counts down each second', (tester) async {
      final advance = await ring(tester, total);
      expect(find.text('20:00'), findsOneWidget);
      expect(readoutColor(tester), kGreen);
      advance(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('19:59'), findsOneWidget);
      advance(const Duration(minutes: 2, seconds: 29));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('17:30'), findsOneWidget);
      expect(find.bySemanticsLabel('Expires in 17 minutes 30 seconds'), findsOneWidget);
      await _finish(tester);
    });

    testWidgets('turns orange under 5 minutes and red under 1 minute', (tester) async {
      final advance = await ring(tester, const Duration(minutes: 5, seconds: 1));
      expect(readoutColor(tester), kGreen);
      advance(const Duration(seconds: 2));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('04:59'), findsOneWidget);
      expect(readoutColor(tester), AdminColors.orange);
      advance(const Duration(minutes: 4));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('00:59'), findsOneWidget);
      expect(readoutColor(tester), AdminColors.danger);
      await _finish(tester);
    });

    testWidgets('reports expiry once the 20 minutes are up, then stops ticking', (tester) async {
      var expired = 0;
      final advance = await ring(tester, const Duration(seconds: 2), onExpired: () => expired++);
      expect(expired, 0);
      advance(const Duration(seconds: 3));
      await tester.pump(const Duration(seconds: 1));
      expect(expired, 1);
      await tester.pump(const Duration(seconds: 5));
      expect(expired, 1, reason: 'the timer is cancelled after expiry');
      await _finish(tester);
    });
  });
}
