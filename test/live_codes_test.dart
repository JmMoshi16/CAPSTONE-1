// Codes follow the counter live, the bell's number means "new", and the greeting follows the clock.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ecoreward_bin/core/app_theme.dart';
import 'package:ecoreward_bin/models/models.dart';
import 'package:ecoreward_bin/screens/customer/customer_home_screen.dart';
import 'package:ecoreward_bin/screens/customer/rewards_screen.dart';

final _now = DateTime.now();
Redemption _code(String id, {String status = 'pending'}) => Redemption(id: id, userId: 'u', rewardId: 'r',
    rewardTitle: 'Iced Latte', pointsUsed: 120, redeemedAt: _now.subtract(const Duration(hours: 1)), status: status,
    redemptionCode: 'AB12CD34');

UserModel _user() => UserModel(uid: 'u', username: 'Ana', email: 'a@b.c', role: 'customer', points: 300,
    lifetimePoints: 300, createdAt: DateTime(2026), scanCount: 4);

Future<void> _finish(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 5));
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({'notifications_prompted': true}));

  group('the greeting follows the clock', () {
    test('morning, afternoon, evening', () {
      expect(greetingFor(DateTime(2026, 11, 7, 9)), 'Good morning');
      expect(greetingFor(DateTime(2026, 11, 7, 14)), 'Good afternoon');
      expect(greetingFor(DateTime(2026, 11, 7, 21)), 'Good evening');
    });

    testWidgets('Home left open from morning to night says good evening, without a reload', (tester) async {
      var clock = DateTime(2026, 11, 7, 9);
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: HomeGreeting(clock: () => clock))));
      expect(find.text('Good morning'), findsOneWidget);
      clock = DateTime(2026, 11, 7, 21);
      await tester.pump(const Duration(minutes: 1));
      expect(find.text('Good evening'), findsOneWidget);
      await _finish(tester);
    });
  });

  testWidgets("the bell's number is new codes: opening the bell clears it, My codes keeps the count", (tester) async {
    tester.view.physicalSize = const Size(393, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(theme: AppTheme.light,
        home: homeTabPreview(user: _user(), redemptions: [_code('a'), _code('b')])));
    await tester.pump(const Duration(seconds: 3));
    expect(find.bySemanticsLabel('Notifications, 2 new'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Notifications, 2 new'));
    await tester.pump(const Duration(seconds: 1));
    await tester.tapAt(const Offset(200, 20));   // close the sheet
    await tester.pump(const Duration(seconds: 1));

    expect(find.bySemanticsLabel('Notifications'), findsOneWidget, reason: 'seen: no number on the bell');
    expect(find.bySemanticsLabel(RegExp(r'^My codes.*2')), findsOneWidget, reason: 'still 2 codes to use');
    await _finish(tester);
  });

  testWidgets('My codes moves a code to Claimed the moment staff hand it out', (tester) async {
    final codes = StreamController<List<Redemption>>();
    addTearDown(() { codes.close(); });   // not awaited: a screen still listening would hold it open
    await tester.pumpWidget(MaterialApp(theme: AppTheme.light,
        home: RewardsScreen(user: _user(), rewards: const [], onRedeemed: () {}, codes: codes.stream)));
    codes.add([_code('a')]);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('My codes (1)'), findsOneWidget);

    codes.add([_code('a', status: 'claimed')]);       // staff marked it claimed on the website
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('My codes'), findsOneWidget, reason: 'no usable code left');
    await _finish(tester);
  });

  testWidgets('the code shown at the counter turns into "Handed out" when staff mark it', (tester) async {
    final updates = StreamController<Redemption?>();
    addTearDown(() { updates.close(); });
    await tester.pumpWidget(MaterialApp(theme: AppTheme.light,
        home: StaffCodeScreen(redemption: _code('a'), updates: updates.stream)));
    expect(find.text('Handed out'), findsNothing);
    updates.add(_code('a', status: 'claimed'));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Handed out'), findsOneWidget);
    await _finish(tester);
  });
}
