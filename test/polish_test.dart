// Polish round (2026-10-27): rewards as a grouped menu, waste colours from the physical bins, the Scan button,
// chips that keep their pill shape, a Home skeleton that matches Home, and numbers read safely from Firestore.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ecoreward_bin/core/app_theme.dart';
import 'package:ecoreward_bin/core/theme.dart';
import 'package:ecoreward_bin/models/models.dart';
import 'package:ecoreward_bin/screens/customer/customer_home_screen.dart';
import 'package:ecoreward_bin/screens/customer/reward_row.dart';
import 'package:ecoreward_bin/screens/customer/rewards_screen.dart';
import 'package:ecoreward_bin/widgets/ui.dart';

Reward _reward(String title, int cost, {String category = 'Coffee', int stock = -1, String description = 'Note'}) =>
    Reward(id: title, title: title, description: description, pointsCost: cost, category: category, stock: stock);

final _user = UserModel(uid: 'u1', username: 'Ana', email: 'ana@example.com', role: 'customer', points: 65,
    createdAt: DateTime(2026, 9, 1));

Future<void> _pump(WidgetTester tester, Widget w, {Size size = const Size(400, 900)}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(theme: AppTheme.light, home: w));
  await tester.pump(const Duration(seconds: 1));
}

Future<void> _done(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 20));
}

void main() {
  setUpAll(() => SharedPreferences.setMockInitialValues({'notifications_prompted': true}));

  group('asInt reads Firestore numbers however they were stored', () {
    test('ints, doubles and numeric strings', () {
      expect(asInt(50), 50);
      expect(asInt(50.0), 50, reason: 'a console edit can store 50.0; it used to read as 0 (a free reward)');
      expect(asInt(7.5), 8);
      expect(asInt(' 120 '), 120);
    });
    test('missing or unusable values are null, never a crash', () {
      expect(asInt(null), isNull);
      expect(asInt('abc'), isNull);
      expect(asInt(double.nan), isNull);
      expect(asInt(double.infinity), isNull);
      expect(asInt(true), isNull);
    });
  });

  test('groupRewards: ready, saving, sold out; cheapest first in each', () {
    final g = groupRewards([
      _reward('Meal', 150, category: 'Food'),
      _reward('Latte', 50),
      _reward('Gone', 10, stock: 0),
      _reward('Free cookie', 0),
      _reward('Frappe', 80),
      _reward('Espresso', 65),
    ], 65);
    expect(g.ready.map((r) => r.title), ['Free cookie', 'Latte', 'Espresso'], reason: 'exactly 65 is affordable');
    expect(g.saving.map((r) => r.title), ['Frappe', 'Meal']);
    expect(g.soldOut.map((r) => r.title), ['Gone'], reason: 'sold out never counts as ready, however cheap');
  });

  test('rewardPrice says Free for a zero price', () {
    expect(rewardPrice(0), 'Free');
    expect(rewardPrice(50), '50 pts');
  });

  test('reward pictures come from the name, else the category', () {
    expect(rewardIconData('Dirty Matcha', 'Coffee'), Icons.emoji_food_beverage_rounded);
    expect(rewardIconData('takoFRIES', 'Food'), Icons.lunch_dining_rounded);
    expect(rewardIconData('Iced Latte', 'Coffee'), Icons.local_drink_rounded);
    expect(rewardIconData('Croissant', 'Food'), Icons.bakery_dining_rounded);
    expect(rewardIconData('10% Discount', 'Discount'), Icons.percent_rounded);
    expect(rewardIconData('Hot Chocolate', 'Coffee'), Icons.coffee_rounded);
    expect(rewardIconData('Steak plate', 'Food'), Icons.restaurant_rounded, reason: '"tea" inside "steak" is not tea');
    expect(rewardIconData('Tumbler', 'Other'), Icons.redeem_rounded);
  });

  group('RewardRow', () {
    Future<List<String>> row(WidgetTester tester, Reward r, {int points = 65, VoidCallback? onTap}) async {
      await _pump(tester, Scaffold(body: Material(child: RewardRow(reward: r, points: points, onTap: onTap ?? () {}))));
      return tester.widgetList<RichText>(find.byType(RichText)).map((t) => t.text.toPlainText()).toList();
    }

    testWidgets('ready: price, a chevron, and "ready to redeem" for screen readers', (tester) async {
      final texts = await row(tester, _reward('Latte', 50));
      expect(texts, containsAll(['Latte', '50 pts']));
      expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('Latte, 50 pts, ready to redeem')), findsOneWidget);
      await _done(tester);
    });

    testWidgets('out of reach: how far to go', (tester) async {
      final texts = await row(tester, _reward('Frappe', 80));
      expect(texts, containsAll(['80 pts', '15 pts to go']));
      expect(find.bySemanticsLabel(RegExp('15 more points needed')), findsOneWidget);
      await _done(tester);
    });

    testWidgets('free and sold out', (tester) async {
      expect(await row(tester, _reward('Cookie', 0)), contains('Free'));
      await _done(tester);
      var taps = 0;
      final texts = await row(tester, _reward('Gone', 10, stock: 0), onTap: () => taps++);
      expect(texts, contains('Sold out'));
      expect(find.byIcon(Icons.chevron_right_rounded), findsNothing, reason: 'nothing to open');
      await tester.tap(find.byType(RewardRow));
      expect(taps, 0, reason: 'a sold-out reward cannot be opened');
      await _done(tester);
    });
  });

  testWidgets('Rewards: grouped menu, and the codes tab counts usable codes only', (tester) async {
    await _pump(tester, RewardsScreen(user: _user, onRedeemed: () {}, rewards: [
      _reward('Latte', 50),
      _reward('Frappe', 80),
      _reward('Gone', 10, stock: 0),
    ]));
    expect(find.text('Ready to redeem'), findsOneWidget);
    expect(find.text('Keep saving'), findsOneWidget);
    expect(find.text('Sold out'), findsWidgets);
    expect(find.text('Available'), findsOneWidget);
    expect(find.textContaining('My codes'), findsOneWidget);
    expect(find.textContaining('redeemed'), findsNothing, reason: 'the old "N redeemed" pill repeated the tab');
    await _done(tester);
  });

  testWidgets('a chip in a 48 dp list keeps its pill shape (All used to render as a circle)', (tester) async {
    await _pump(tester, Scaffold(body: SizedBox(
      height: 48,
      child: ListView(scrollDirection: Axis.horizontal, children: [
        AppChip(label: 'All', selected: true, onTap: () {}),
      ]),
    )));
    final pill = tester.getSize(find.descendant(of: find.byType(AppChip), matching: find.byType(AnimatedContainer)));
    expect(pill.width, greaterThan(pill.height * 1.4));
    expect(pill.height, lessThan(48));
    await _done(tester);
  });

  testWidgets('nav bar: Scan is a round action that never looks like the selected tab', (tester) async {
    await _pump(tester, homeTabPreview(user: _user));
    const c = AppColors.light;
    // Two "Scan" labels: the hero shortcut (on forest) and the nav button, whose label must look unselected.
    expect(tester.widgetList<Text>(find.text('Scan')).map((t) => t.style!.color), contains(c.textSecondary),
        reason: 'the nav label used to be bold green, like a selected tab');
    final circles = tester.widgetList<Container>(find.byType(Container)).where((w) {
      final d = w.decoration;
      return d is BoxDecoration && d.shape == BoxShape.circle && d.color == c.primary;
    });
    expect(circles, hasLength(1), reason: 'the Scan button');
    await _done(tester);
  });

  test('residual waste is charcoal like the bin, not the error red', () {
    for (final c in [AppColors.light, AppColors.dark]) {
      expect(c.res, isNot(c.danger));
      expect(HSLColor.fromColor(c.res).saturation, lessThan(0.2), reason: 'a neutral grey, not a warning colour');
    }
    expect(wasteIcon('Biodegradable'), Icons.eco_rounded, reason: 'the kiosk shows a leaf');
  });

  testWidgets('Home skeleton matches Home: no big header block, fits a small phone at 1.3x text', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: const MediaQuery(
        data: MediaQueryData(size: Size(360, 640), textScaler: TextScaler.linear(1.3)),
        child: Scaffold(body: HomeSkeleton()),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
    for (final box in tester.widgetList<SkeletonBox>(find.byType(SkeletonBox))) {
      expect(box.height, lessThanOrEqualTo(160), reason: 'the old skeleton opened with a 260 px grey block');
    }
    await _done(tester);
  });

  group('premium surfaces', () {
    testWidgets('the forest surface drifts on arrival, then rests; with reduced motion it never moves', (tester) async {
      await tester.pumpWidget(MaterialApp(theme: AppTheme.light, home: const AuroraBackground(child: SizedBox(height: 200))));
      expect(tester.binding.hasScheduledFrame, isTrue, reason: 'alive on arrival');
      await tester.pumpAndSettle(const Duration(milliseconds: 500), EnginePhase.sendSemanticsUpdate, const Duration(seconds: 40));
      await _done(tester);

      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light,
        home: const MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: AuroraBackground(child: SizedBox(height: 200)),
        ),
      ));
      await tester.pump();
      expect(tester.binding.hasScheduledFrame, isFalse);
      await _done(tester);
    });

    testWidgets('an entrance that should not play shows its child at once', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: StaggeredEntrance(index: 3, play: false, child: Text('row'))));
      final opacity = tester.widget<Opacity>(find.ancestor(of: find.text('row'), matching: find.byType(Opacity)).first);
      expect(opacity.opacity, 1);
      await _done(tester);
    });

    testWidgets('Home: a reward in the carousel opens it', (tester) async {
      Reward? opened;
      tester.view.physicalSize = const Size(400, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(theme: AppTheme.light, home: Builder(builder: (_) => homeTabPreview(
        user: _user,
        rewards: [_reward('Latte', 50), _reward('Mocha', 60)],
        onOpenReward: (r) => opened = r,
      ))));
      await tester.pump(const Duration(seconds: 2));
      // Ready rewards lead with the most valuable, so Mocha is in focus and Latte peeks from the right.
      await tester.tap(find.text('Mocha'));
      expect(opened?.title, 'Mocha');
      await _done(tester);
    });

    testWidgets('the nav pill slides to the selected tab', (tester) async {
      Future<double> pillLeft(int index) async {
        await _pump(tester, homeTabPreview(user: _user, selectedTab: index));
        await tester.pump(const Duration(seconds: 1));
        return tester.getTopLeft(find.byKey(const ValueKey('nav-pill'))).dx;
      }
      final home = await pillLeft(0);
      final profile = await pillLeft(3);
      expect(profile, greaterThan(home + 200), reason: 'Profile is the last slot');
      await _done(tester);
    });
  });
}
