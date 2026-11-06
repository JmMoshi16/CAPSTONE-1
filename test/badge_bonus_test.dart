// Badges pay a one-time bonus: where customers see it (the badges grid and sheet, the scan's success screen and
// its details, the rank explainer).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ecoreward_bin/core/app_theme.dart';
import 'package:ecoreward_bin/models/models.dart';
import 'package:ecoreward_bin/screens/customer/badges_screen.dart';
import 'package:ecoreward_bin/screens/customer/info_sheets.dart';
import 'package:ecoreward_bin/screens/customer/qr_scanner_screen.dart';

UserModel _user({List<String> badges = const []}) => UserModel(uid: 'u', username: 'Ana', email: 'a@b.c',
    role: 'customer', points: 30, lifetimePoints: 30, createdAt: DateTime(2026), scanCount: 2, badges: badges);

Future<void> _finish(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 5));
}

Widget _app(Widget home) => MaterialApp(theme: AppTheme.light, home: home);

/// A page with one button that opens [open], for the sheets.
Widget _opener(void Function(BuildContext) open) =>
    _app(Scaffold(body: Builder(builder: (context) => TextButton(onPressed: () => open(context), child: const Text('open')))));

void main() {
  setUpAll(() => SharedPreferences.setMockInitialValues({'notifications_prompted': true}));

  testWidgets('a locked badge shows what it pays; an earned one shows no amount', (tester) async {
    tester.view.physicalSize = const Size(393, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    // Both 5 pt badges are earned, so "+5 pts" may only appear on a locked card, and must not.
    await tester.pumpWidget(_app(BadgesScreen(user: _user(badges: ['first_scan', 'pts_50']))));
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('+5 pts'), findsNothing, reason: 'earned badges: held before bonuses, so no amount');
    expect(find.text('+10 pts'), findsNWidgets(3), reason: '5 Scans, Century Club, On a Roll');
    expect(find.text('+25 pts'), findsOneWidget, reason: 'Eco Champion');
    expect(find.bySemanticsLabel(RegExp(r'^5 Scans, locked, unlocking it adds 10 pts')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _finish(tester);
  });

  testWidgets("a locked badge's sheet says what unlocking it adds", (tester) async {
    await tester.pumpWidget(_opener((context) => showBadgeSheet(context,
        def: {'id': 'scan_5', 'label': '5 Scans', 'desc': 'Scanned waste 5 times', 'req': 'scans', 'value': 5, 'bonus': 10},
        user: _user())));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Unlocking it adds 10 pts.'), findsOneWidget);
    await _finish(tester);
  });

  testWidgets('the success screen adds the badge bonus to the scan, and says so', (tester) async {
    await tester.pumpWidget(_app(successScreenPreview(points: 23, basePoints: 15, multiplier: 1.5,
        newBadges: ['scan_5'], badgeBonus: 10, pointsBefore: 100, lifetimeBefore: 100)));
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 100));   // the "+33" flies into the balance, which counts up
    }
    expect(find.text('+33 points'), findsOneWidget, reason: 'the scan and its bonus');
    expect(find.text('+15 × 1.5 streak bonus = +23'), findsOneWidget);
    expect(find.text('+10 badge bonus'), findsOneWidget);
    expect(find.text('+10 pts'), findsOneWidget, reason: 'on the 5 Scans row');
    expect(find.text('133 pts'), findsOneWidget, reason: 'the balance counts up to all of it');
    await _finish(tester);
  });

  testWidgets("a scan's details split the streak bonus from the badge bonus", (tester) async {
    final log = WasteLog(userId: 'u', wasteType: 'Biodegradable', pointsEarned: 15, pointsAwarded: 33, badgeBonus: 10,
        timestamp: DateTime(2026, 11, 5, 9), binId: 'abcd1234');
    await tester.pumpWidget(_opener((context) => showScanDetailSheet(context, log)));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('+8'), findsOneWidget, reason: 'streak bonus: 33 - 15 - 10');
    expect(find.text('Badge bonus'), findsOneWidget);
    expect(find.text('+10'), findsOneWidget);
    expect(find.text('+33 pts'), findsOneWidget);
    await _finish(tester);
  });

  testWidgets('the rank explainer says badges count too', (tester) async {
    await tester.pumpWidget(_opener((context) => showRankLevelSheet(context, lifetimePoints: 30)));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Badges add bonus points'), findsOneWidget);
    await _finish(tester);
  });
}
