// Phase 1 of the UI/UX transformation (PROJECT_REDESIGN_ROADMAP.md): one regression test per
// verified bug from the UI/UX audit. Each test failed before its fix.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
// The platform start() types are not exported; the fake camera needs them.
// ignore: implementation_imports
import 'package:mobile_scanner/src/mobile_scanner_view_attributes.dart';
// ignore: implementation_imports
import 'package:mobile_scanner/src/objects/start_options.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ecoreward_bin/core/app_theme.dart';
import 'package:ecoreward_bin/models/models.dart';
import 'package:ecoreward_bin/screens/admin/admin_dashboard_screen.dart';
import 'package:ecoreward_bin/screens/admin/admin_rewards_screen.dart';
import 'package:ecoreward_bin/screens/admin/admin_users_screen.dart';
import 'package:ecoreward_bin/screens/customer/customer_home_screen.dart';
import 'package:ecoreward_bin/screens/customer/customer_profile_screen.dart';
import 'package:ecoreward_bin/screens/customer/impact_screen.dart';
import 'package:ecoreward_bin/screens/customer/leaderboard_screen.dart';
import 'package:ecoreward_bin/screens/customer/qr_scanner_screen.dart';
import 'package:ecoreward_bin/screens/customer/reward_detail_screen.dart';
import 'package:ecoreward_bin/screens/customer/scan_errors.dart';
import 'package:ecoreward_bin/screens/customer/scan_history_screen.dart';
import 'package:ecoreward_bin/services/firebase_service.dart' show QRValidationResult, ScanClaim, ScanCredit;
import 'package:ecoreward_bin/widgets/ui.dart';

import 'support/fonts.dart';

Widget _app(Widget home, {ThemeData? theme}) => MaterialApp(theme: theme ?? AppTheme.light, home: home);

Future<void> _finish(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 20));
}

void _phone(WidgetTester tester, {double width = 360, double height = 640}) {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

UserModel _user(String name, {int points = 100, int lifetime = 100, String role = 'customer'}) => UserModel(
    uid: name, username: name, email: '$name@example.com', role: role, points: points, lifetimePoints: lifetime,
    createdAt: DateTime(2026, 1, 1));

WasteLog _log(String type, {DateTime? at}) => WasteLog(
    userId: 'u', wasteType: type, pointsEarned: 10, timestamp: at ?? DateTime(2026, 10, 20, 9), binId: 'a1b2c3d4');

/// A camera that "sees" one bin code as soon as it starts.
class _CameraWithCode extends MobileScannerPlatform {
  final _codes = StreamController<BarcodeCapture?>.broadcast();
  final String raw;
  int starts = 0;
  _CameraWithCode(this.raw);

  @override
  Future<MobileScannerViewAttributes> start(StartOptions startOptions) async {
    starts++;
    Future.microtask(() => _codes.add(BarcodeCapture(barcodes: [Barcode(rawValue: raw)])));
    return const MobileScannerViewAttributes(currentTorchMode: TorchState.off, numberOfCameras: 1, size: Size(640, 480));
  }

  @override
  Stream<BarcodeCapture?> get barcodesStream => _codes.stream;
  @override
  Stream<TorchState> get torchStateStream => const Stream.empty();
  @override
  Stream<double> get zoomScaleStateStream => const Stream.empty();
  @override
  Widget buildCameraView() => const ColoredBox(color: Colors.black);
  @override
  Future<void> stop() async {}
  @override
  Future<void> updateScanWindow(Rect? window) async {}
  @override
  Future<void> dispose() async {}
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({'notifications_prompted': true});
    await loadRealFonts();
    await loadAppFonts();
  });

  // ── 1. Staff: every sort option works ───────────────────────────────────────
  testWidgets('staff can sort customers by Name without an error', (tester) async {
    _phone(tester, width: 800, height: 2400);
    await tester.pumpWidget(_app(
        Scaffold(body: AdminUsersScreen(customers: [_user('Cara'), _user('Abe'), _user('Bea'), _user('Dan')], logs: const [])),
        theme: AppTheme.admin));
    await tester.pump(const Duration(seconds: 2));
    await tester.tap(find.text('Name'));
    await tester.pump(const Duration(seconds: 2));
    expect(tester.takeException(), isNull);
    expect(tester.getTopLeft(find.text('Abe')).dy, lessThan(tester.getTopLeft(find.text('Dan')).dy));
    await _finish(tester);
  });

  // ── 2. Scanner: closing the error any way resumes scanning ─────────────────
  testWidgets('tapping outside a scan error resumes scanning', (tester) async {
    var scanAgain = 0, back = 0;
    await tester.pumpWidget(_app(Builder(builder: (ctx) => Scaffold(body: TextButton(
        onPressed: () => showScanErrorDialog(ctx, ScanError.expired,
            onScanAgain: () => scanAgain++, onBack: () => back++),
        child: const Text('show'))))));
    await tester.tap(find.text('show'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tapAt(const Offset(4, 4));   // the barrier
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(AlertDialog), findsNothing);
    expect((scanAgain, back), (1, 0));
    await _finish(tester);
  });

  // ── 3. Scanner: a claim that never answers ends in a clear message ─────────
  testWidgets('a scan the server never answers shows the connection message', (tester) async {
    final camera = _CameraWithCode('ECOBIN:Recyclable:5f0c2d8e-1111-4222-8333-944455556666');
    MobileScannerPlatform.instance = camera;
    await tester.pumpWidget(_app(QRScannerScreen(
        userId: 'u', username: 'U', claim: (_, __) => Completer<ScanClaim>().future)));
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text(ScanError.offline.title), findsNothing);
    await tester.pump(kScanClaimTimeout + const Duration(seconds: 1));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text(ScanError.offline.title), findsOneWidget);
    await _finish(tester);
  });

  // ── Phase 5: one thing at a time after a scan ──────────────────────────────
  for (final prompted in [true, false]) {
    testWidgets('success: no prompt over the celebration, and Done always leaves (asked before: $prompted)',
        (tester) async {
      SharedPreferences.setMockInitialValues({'notifications_prompted': prompted});
      MobileScannerPlatform.instance = _CameraWithCode('ECOBIN:Recyclable:5f0c2d8e-1111-4222-8333-944455556666');
      await tester.pumpWidget(_app(Builder(builder: (ctx) => Scaffold(body: TextButton(
          onPressed: () => Navigator.push(ctx, MaterialPageRoute(builder: (_) => QRScannerScreen(
              userId: 'u', username: 'U',
              claim: (_, __) async => const ScanClaim(QRValidationResult.valid,
                  wasteType: 'Recyclable', basePoints: 10, credit: ScanCredit(10, 1, ['first_scan']))))),
          child: const Text('home'))))));
      await tester.tap(find.text('home'));
      await tester.pump();
      await tester.pump();
      for (var i = 0; i < 30 && find.text('Points added').evaluate().isEmpty; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));   // plugin calls
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.text('Points added'), findsOneWidget);
      await tester.pump(const Duration(seconds: 4));   // the whole celebration, confetti included
      expect(find.byType(BottomSheet), findsNothing, reason: 'nothing pops up on top of the celebration');
      await tester.tap(find.text('Done'));
      for (var i = 0; i < 10; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
        await tester.pump(const Duration(milliseconds: 300));
      }
      // Without the notification plugin (tests) the question cannot be asked; Done must still leave.
      expect(find.text('home'), findsOneWidget);
      await _finish(tester);
    });
  }

  // ── 4. Staff reward form fits with the keyboard open ────────────────────────
  testWidgets('the add-reward form scrolls instead of overflowing with the keyboard up', (tester) async {
    _phone(tester);
    await tester.pumpWidget(_app(Scaffold(body: AdminRewardsScreen(rewards: const [], onChanged: () async {})),
        theme: AppTheme.admin));
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.byTooltip('Add reward'));
    await tester.pump(const Duration(seconds: 1));
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);   // the keyboard
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(find.text('Add reward'), 100, scrollable: find.byType(Scrollable).last);
    expect(find.text('Add reward'), findsOneWidget);
    await _finish(tester);
  });

  // ── 5. Home fits a 320 dp phone ─────────────────────────────────────────────
  testWidgets('Home quick actions fit a 320 dp wide phone', (tester) async {
    _phone(tester, width: 320, height: 640);
    await tester.pumpWidget(_app(homeTabPreview(user: _user('Ana'))));
    await tester.pump(const Duration(seconds: 3));
    expect(tester.takeException(), isNull);
    await _finish(tester);
  });

  // ── 6. Android back on a tab goes to the first tab ──────────────────────────
  testWidgets('back on a later tab returns to the first tab; on the first tab it leaves', (tester) async {
    var index = 2;
    await tester.pumpWidget(_app(Builder(builder: (ctx) => Scaffold(body: TextButton(
        onPressed: () => Navigator.push(ctx, MaterialPageRoute(builder: (_) => StatefulBuilder(builder: (_, s) {
              return TabBackScope(index: index, onFirstTab: () => s(() => index = 0), child: Text('tab $index'));
            }))),
        child: const Text('open'))))));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('tab 2'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('tab 0'), findsOneWidget, reason: 'back went to the first tab, not out');
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('open'), findsOneWidget, reason: 'back on the first tab leaves');
  });

  // ── 7. Pull-to-refresh says "Up to date" only when the reload has finished ─
  // Profile, staff rewards and the dashboard already waited (an async arrow returning the reload's
  // Future awaits it), so the audit finding did not reproduce there; these tests keep it that way.
  Future<void> pull(WidgetTester tester) async {
    await tester.fling(find.byType(Scrollable).first, const Offset(0, 500), 1500);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('Profile pull-to-refresh waits for the reload', (tester) async {
    _phone(tester);
    final reload = Completer<void>();
    await tester.pumpWidget(_app(CustomerProfileScreen(user: _user('Ana'), logs: const [],
        onUpdated: () => reload.future)));
    await tester.pump(const Duration(seconds: 2));
    await pull(tester);
    expect(find.text('Up to date'), findsNothing, reason: 'still loading');
    reload.complete();
    await tester.pump();
    await tester.pump();
    expect(find.text('Up to date'), findsOneWidget);
    await _finish(tester);
  });

  testWidgets('staff reward list pull-to-refresh waits for the reload', (tester) async {
    _phone(tester);
    final reload = Completer<void>();
    final reward = Reward(id: 'r', title: 'Latte', description: 'Hot', pointsCost: 50, category: 'Coffee');
    await tester.pumpWidget(_app(Scaffold(body: AdminRewardsScreen(rewards: [reward], onChanged: () => reload.future)),
        theme: AppTheme.admin));
    await tester.pump(const Duration(seconds: 1));
    await pull(tester);
    expect(find.text('Up to date'), findsNothing, reason: 'still loading');
    reload.complete();
    await tester.pump();
    await tester.pump();
    expect(find.text('Up to date'), findsOneWidget);
    await _finish(tester);
  });

  testWidgets('staff dashboard pull-to-refresh waits for the reload', (tester) async {
    _phone(tester);
    final reload = Completer<void>();
    await tester.pumpWidget(_app(dashboardTabPreview(logs: [_log('Recyclable')], customers: [_user('Ana')],
        onRefresh: () => reload.future), theme: AppTheme.admin));
    await tester.pump(const Duration(seconds: 3));
    await pull(tester);
    expect(find.text('Up to date'), findsNothing, reason: 'still loading');
    reload.complete();
    await tester.pump();
    await tester.pump();
    expect(find.text('Up to date'), findsOneWidget);
    await _finish(tester);
  });

  testWidgets('the leaderboard can be pulled to refresh even when it is short', (tester) async {
    _phone(tester, height: 2000);   // everything fits: nothing to scroll
    await tester.pumpWidget(_app(const LeaderboardScreen(currentUid: 'u1')));   // offline: error state
    await tester.pump(const Duration(seconds: 3));
    await pull(tester);
    expect(find.text('Refreshing…').evaluate().isNotEmpty || find.text('Up to date').evaluate().isNotEmpty, isTrue);
    await _finish(tester);
  });

  // ── 8. Scan History shows a scan made from it ───────────────────────────────
  testWidgets('Scan History reloads after a scan started from it', (tester) async {
    _phone(tester);
    await tester.pumpWidget(_app(ScanHistoryScreen(
      logs: const [],
      onScan: () async {},
      onRefresh: () async => [_log('Recyclable')],
    )));
    await tester.pump(const Duration(seconds: 2));
    await tester.tap(find.text('Scan a QR code'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('1 scan · 10 pts total'), findsOneWidget);
    await _finish(tester);
  });

  // ── 9. A redemption code is never cut off ───────────────────────────────────
  testWidgets('a redemption code stays whole in a narrow space at large text', (tester) async {
    await tester.pumpWidget(MaterialApp(theme: AppTheme.light,
        home: const MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(2)),
          child: Center(child: SizedBox(width: 90, child: RedemptionCode('ABCD1234'))),
        )));
    final paragraph = tester.renderObject<RenderParagraph>(find.text('ABCD 1234'));
    expect(paragraph.didExceedMaxLines, isFalse);
    expect(tester.getSize(find.byType(RedemptionCode)).width, lessThanOrEqualTo(90));
    expect(tester.takeException(), isNull);
  });

  // ── 10. Copy that says what is true ─────────────────────────────────────────
  testWidgets('a sold-out reward does not tell the customer to earn more points', (tester) async {
    _phone(tester);
    final reward = Reward(id: 'r', title: 'Latte', description: 'Hot', pointsCost: 50, category: 'Coffee', stock: 0);
    await tester.pumpWidget(_app(RewardDetailScreen(reward: reward, user: _user('Ana', points: 10), heroTag: 'r')));
    await tester.pump(const Duration(seconds: 2));
    expect(find.textContaining('earn the rest', skipOffstage: false), findsNothing);
    expect(find.textContaining('out of stock', skipOffstage: false), findsOneWidget);
    await _finish(tester);
  });

  testWidgets('Activity does not call the code reference a bin', (tester) async {
    _phone(tester, height: 2400);
    await tester.pumpWidget(_app(ImpactScreen(logs: [_log('Recyclable')])));
    await tester.pump(const Duration(seconds: 3));
    expect(find.textContaining('Bin:', skipOffstage: false), findsNothing);
    await _finish(tester);
  });

  // ── 11. Medal numbers are readable ──────────────────────────────────────────
  test('medal numbers reach 4.5:1 on every medal colour', () {
    double lum(Color c) => c.computeLuminance();
    double ratio(Color a, Color b) {
      final (hi, lo) = lum(a) > lum(b) ? (lum(a), lum(b)) : (lum(b), lum(a));
      return (hi + 0.05) / (lo + 0.05);
    }
    for (final medal in [AppPalette.medalGold, AppPalette.medalSilver, AppPalette.medalBronze]) {
      expect(ratio(AppPalette.medalInk, medal), greaterThanOrEqualTo(4.5), reason: '$medal');
    }
  });

  testWidgets('staff top-3 medal numbers use the readable ink', (tester) async {
    _phone(tester, width: 800, height: 2400);
    await tester.pumpWidget(_app(
        Scaffold(body: AdminUsersScreen(customers: [_user('Abe', lifetime: 30), _user('Bea', lifetime: 20)],
            logs: const [])),
        theme: AppTheme.admin));
    await tester.pump(const Duration(seconds: 2));
    expect(tester.widget<Text>(find.text('1')).style!.color, AppPalette.medalInk);
    await _finish(tester);
  });

  // ── 12. Error screens always offer a way out ────────────────────────────────
  testWidgets('Home error screen offers Sign out as well as Retry', (tester) async {
    _phone(tester);
    await tester.pumpWidget(_app(const CustomerHomeScreen()));   // no Firebase here: the load fails
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('Retry'), findsOneWidget);
    expect(find.text('Sign out'), findsOneWidget);
    await _finish(tester);
  });

  testWidgets('staff dashboard error screen offers Sign out as well as Retry', (tester) async {
    _phone(tester);
    await tester.pumpWidget(_app(const AdminDashboardScreen()));
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('Retry'), findsOneWidget);
    expect(find.text('Sign out'), findsOneWidget);
    await _finish(tester);
  });
}
