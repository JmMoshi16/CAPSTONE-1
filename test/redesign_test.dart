// Phase 3 of the UI/UX transformation: customer screens. Behaviour that the redesign adds or corrects;
// layout at every size is covered by layout_test.dart.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ecoreward_bin/core/app_theme.dart';
import 'package:ecoreward_bin/core/gamification.dart' show dayKey;
import 'package:ecoreward_bin/models/models.dart';
import 'package:ecoreward_bin/screens/customer/customer_home_screen.dart';
import 'package:ecoreward_bin/screens/customer/impact_screen.dart';
import 'package:ecoreward_bin/screens/customer/qr_scanner_screen.dart' show scanWindowRect;
import 'package:ecoreward_bin/screens/customer/rewards_screen.dart';
import 'package:ecoreward_bin/screens/register_screen.dart';
import 'package:ecoreward_bin/screens/splash_screen.dart';
import 'package:flutter/services.dart';
import 'package:ecoreward_bin/widgets/ui.dart';

import 'support/fonts.dart';

Future<void> _finish(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 20));
}

void _phone(WidgetTester tester, {double width = 393, double height = 852}) {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

UserModel _user({int streak = 0, String? lastScan}) => UserModel(
    uid: 'u', username: 'Ana', email: 'ana@example.com', role: 'customer', points: 120, lifetimePoints: 300,
    createdAt: DateTime(2026, 1, 1), streak: streak, lastScanDate: lastScan, scanCount: 4);

Reward _reward(String title, {int stock = -1}) =>
    Reward(id: title, title: title, description: 'Hot', pointsCost: 50, category: 'Coffee', stock: stock);

/// The page name in a collapsed forest header (HeroHeaderSpace): 0 hidden, 1 shown.
double _barTitleOpacity(WidgetTester tester) => tester.widget<Opacity>(find.descendant(
    of: find.byType(HeroHeaderSpace), matching: find.byKey(const ValueKey('bar-title')))).opacity;

WasteLog _log(DateTime at) => WasteLog(userId: 'u', wasteType: 'Recyclable', pointsEarned: 10, timestamp: at, binId: 'x');

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({'notifications_prompted': true});
    await loadRealFonts();
    await loadAppFonts();
  });

  group('Home', () {
    testWidgets('an active streak is visible in the hero', (tester) async {
      _phone(tester);
      await tester.pumpWidget(MaterialApp(theme: AppTheme.light,
          home: homeTabPreview(user: _user(streak: 5, lastScan: dayKey(DateTime.now())))));
      await tester.pump(const Duration(seconds: 3));
      expect(find.bySemanticsLabel(RegExp(r'^5-day streak')), findsOneWidget);
      await _finish(tester);
    });

    testWidgets('no streak chip without a streak', (tester) async {
      _phone(tester);
      await tester.pumpWidget(MaterialApp(theme: AppTheme.light, home: homeTabPreview(user: _user())));
      await tester.pump(const Duration(seconds: 3));
      expect(find.bySemanticsLabel(RegExp(r'day streak, details$')), findsNothing);
      await _finish(tester);
    });

    testWidgets('the goal card says what it counts: the last 7 days, and today', (tester) async {
      _phone(tester, height: 1600);
      final now = DateTime.now();
      final logs = [_log(now), _log(now), _log(now.subtract(const Duration(days: 3)))];
      await tester.pumpWidget(MaterialApp(theme: AppTheme.light, home: homeTabPreview(user: _user(), logs: logs)));
      await tester.pump(const Duration(seconds: 3));
      expect(find.text('3 of 10 scans in the last 7 days', skipOffstage: false), findsOneWidget);
      expect(find.text('2 today', skipOffstage: false), findsOneWidget);
      expect(find.textContaining('this week', skipOffstage: false), findsNothing);
      await _finish(tester);
    });

    testWidgets('the leaderboard shortcut uses the page name', (tester) async {
      _phone(tester, width: 320, height: 640);
      await tester.pumpWidget(MaterialApp(theme: AppTheme.light, home: homeTabPreview(user: _user())));
      await tester.pump(const Duration(seconds: 3));
      expect(find.text('Leaderboard'), findsOneWidget);
      expect(find.text('Ranking'), findsNothing);
      expect(tester.takeException(), isNull);
      await _finish(tester);
    });
  });

  group('Rewards', () {
    testWidgets('the collapsed header still names the page', (tester) async {
      _phone(tester);
      await tester.pumpWidget(MaterialApp(theme: AppTheme.light, home: RewardsScreen(user: _user(),
          rewards: [for (var i = 0; i < 12; i++) _reward('Latte $i')], onRedeemed: () {})));
      await tester.pump(const Duration(seconds: 2));
      expect(_barTitleOpacity(tester), 0);
      await tester.drag(find.text('Latte 3'), const Offset(0, -500));
      await tester.pumpAndSettle();
      expect(_barTitleOpacity(tester), closeTo(1, 0.001));
      await _finish(tester);
    });

    testWidgets('new rewards from Home replace the old list (stock stays current)', (tester) async {
      _phone(tester, height: 1600);
      final rewards = ValueNotifier([_reward('Latte')]);
      await tester.pumpWidget(MaterialApp(theme: AppTheme.light, home: ValueListenableBuilder<List<Reward>>(
          valueListenable: rewards,
          builder: (_, r, __) => RewardsScreen(user: _user(), rewards: r, onRedeemed: () {}))));
      await tester.pump(const Duration(seconds: 2));
      expect(find.text('Sold out'), findsNothing);
      rewards.value = [_reward('Latte', stock: 0)];
      await tester.pump(const Duration(seconds: 2));
      expect(find.text('Sold out'), findsWidgets);
      await _finish(tester);
    });

    testWidgets('swiping moves between Available and My codes, like any tab bar', (tester) async {
      _phone(tester);
      await tester.pumpWidget(MaterialApp(theme: AppTheme.light,
          home: RewardsScreen(user: _user(), rewards: [_reward('Latte')], onRedeemed: () {})));
      await tester.pump(const Duration(seconds: 2));
      await tester.fling(find.text('Latte'), const Offset(-300, 0), 1500);
      await tester.pumpAndSettle();
      expect(find.text('Latte').hitTestable(), findsNothing, reason: 'now on My codes');
      await _finish(tester);
    });
  });

  group('Sign-in screens', () {
    testWidgets('Register works with password managers and submits from the keyboard', (tester) async {
      _phone(tester);
      await tester.pumpWidget(MaterialApp(theme: AppTheme.light, home: const RegisterScreen()));
      await tester.pump(const Duration(seconds: 2));
      expect(find.byType(AutofillGroup), findsOneWidget);
      final fields = tester.widgetList<TextField>(find.byType(TextField)).toList();
      expect(fields.map((f) => f.autofillHints?.first), [AutofillHints.newUsername, AutofillHints.email,
          AutofillHints.newPassword, AutofillHints.newPassword]);
      expect(fields.last.textInputAction, TextInputAction.done);
      expect(fields.last.onSubmitted, isNotNull);
      await _finish(tester);
    });

    testWidgets('the cream splash uses dark status-bar icons', (tester) async {
      await tester.pumpWidget(MaterialApp(theme: AppTheme.light, home: const BrandSplash()));
      final region = tester.widget<AnnotatedRegion<SystemUiOverlayStyle>>(
          find.byType(AnnotatedRegion<SystemUiOverlayStyle>).last);
      expect(region.value.statusBarIconBrightness, Brightness.dark);
    });
  });

  testWidgets('on a tablet, Home keeps a reading width instead of stretching', (tester) async {
    _phone(tester, width: 1024, height: 1366);
    await tester.pumpWidget(MaterialApp(theme: AppTheme.light, home: homeTabPreview(user: _user())));
    await tester.pump(const Duration(seconds: 3));
    expect(tester.getSize(find.byType(AppSurface)).width, lessThanOrEqualTo(AppLayout.readingWidth));
    expect(tester.getCenter(find.byType(AppSurface)).dx, closeTo(512, 1), reason: 'centred');
    await _finish(tester);
  });

  group('Scanner window', () {
    // The status card sits 64 dp above the bottom and is about 150 dp tall while verifying.
    for (final size in const [Size(320, 568), Size(360, 640), Size(393, 852), Size(800, 1280)]) {
      test('a square window that clears the status card at $size', () {
        final r = scanWindowRect(size);
        expect(r.width, r.height);
        expect(r.left, greaterThanOrEqualTo(0));
        expect(r.right, lessThanOrEqualTo(size.width));
        expect(r.top, greaterThan(120), reason: 'room for the hint and the top bar');
        expect(r.bottom, lessThan(size.height - 64 - 150));
        expect(r.width, lessThanOrEqualTo(320), reason: 'a tablet does not get a giant frame');
      });
    }
  });

  group('Activity', () {
    final now = DateTime.now();
    final logs = [for (var i = 0; i < 9; i++) _log(now.subtract(Duration(hours: i * 30)))];

    testWidgets('shows recent scans and leads to the full history, instead of repeating it', (tester) async {
      _phone(tester, height: 3000);
      String? opened;
      await tester.pumpWidget(MaterialApp(theme: AppTheme.light,
          home: ImpactScreen(logs: logs, onOpenHistory: (f) => opened = f)));
      await tester.pump(const Duration(seconds: 3));
      expect(find.byType(AppScanRow), findsNWidgets(5));
      await tester.tap(find.text('See all 9 scans'));
      expect(opened, 'All');
      await _finish(tester);
    });

    testWidgets('the header counts the last 7 days, like Home', (tester) async {
      _phone(tester);
      await tester.pumpWidget(MaterialApp(theme: AppTheme.light, home: ImpactScreen(logs: logs)));
      await tester.pump(const Duration(seconds: 3));
      final header = find.byType(HeroHeaderSpace);
      expect(find.descendant(of: header, matching: find.text('Last 7 days')), findsOneWidget);
      expect(find.descendant(of: header, matching: find.text('Recyclable')), findsNothing);
      await _finish(tester);
    });

    testWidgets('the collapsed header still names the page', (tester) async {
      _phone(tester);
      await tester.pumpWidget(MaterialApp(theme: AppTheme.light, home: ImpactScreen(logs: logs)));
      await tester.pump(const Duration(seconds: 3));
      expect(_barTitleOpacity(tester), 0);
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -600));
      await tester.pumpAndSettle();
      expect(_barTitleOpacity(tester), closeTo(1, 0.001));
      await _finish(tester);
    });
  });
}
