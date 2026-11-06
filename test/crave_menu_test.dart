// Crave's whole menu as rewards (2026-11-04): staff add it in one tap at 50 points each, and Home's reward card
// shows each item's photo.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ecoreward_bin/core/app_theme.dart';
import 'package:ecoreward_bin/core/crave_menu.dart';
import 'package:ecoreward_bin/models/models.dart';
import 'package:ecoreward_bin/screens/admin/admin_rewards_screen.dart';
import 'package:ecoreward_bin/screens/customer/customer_home_screen.dart';
import 'package:ecoreward_bin/screens/customer/reward_detail_screen.dart';
import 'package:ecoreward_bin/screens/customer/reward_row.dart';
import 'package:ecoreward_bin/screens/customer/rewards_screen.dart';
import 'package:ecoreward_bin/widgets/ui.dart';

Reward _reward(String title, {String? id, int cost = 50, String description = 'Enjoy a free cup of coffee'}) =>
    Reward(id: id ?? title, title: title, description: description, pointsCost: cost, category: 'Coffee');

UserModel _user(int points) => UserModel(uid: 'u1', username: 'Ana', email: 'ana@example.com', role: 'customer',
    points: points, createdAt: DateTime(2026, 9, 1));

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(393, 852);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// Unmounts the page and runs out its timers (snackbars, entrances).
Future<void> _finish(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 20));
}

void main() {
  setUpAll(() => SharedPreferences.setMockInitialValues({'notifications_prompted': true}));

  test("points follow the menu price in pesos, on the owner's tiers", () {
    const tiers = {59: 100, 60: 120, 69: 120, 70: 125, 79: 125, 80: 130, 89: 130, 90: 135, 99: 135,
        100: 140, 109: 140, 110: 150, 129: 150, 130: 160, 200: 160};
    for (final MapEntry(key: peso, value: points) in tiers.entries) {
      expect(craveMenuPoints(peso), points, reason: 'P$peso');
    }
    int cost(String title) => craveMenuToAdd(const []).firstWhere((r) => r.title == title).pointsCost;
    expect(cost('Classic'), 120, reason: 'P66');
    expect(cost('Sunrise'), 120, reason: 'P63');
    expect(cost('Matcha Dream'), 125, reason: 'P79');
    expect(cost('Orange Americano'), 130, reason: 'P89');
    expect(cost('Blueberry Haze'), 130, reason: 'P84');
    expect(cost('Mocha'), 135, reason: 'P94');
    expect(cost('Caramel Drip'), 135, reason: 'P99');
    expect(cost('Smokey Garlic Tapa'), 140, reason: 'P109');
    expect(cost('Sweet Oat'), 150, reason: 'P129');
    expect(cost('The OG Burger'), 150, reason: 'P129');
    expect(cost('Samgy Burger'), 160, reason: 'P134');
  });

  test('items already added at another price are repriced; others are left alone', () {
    final menu = craveMenuToAdd(const []);
    final mocha = menu.firstWhere((r) => r.title == 'Mocha');
    final classic = menu.firstWhere((r) => r.title == 'Classic');
    expect(craveMenuRepricing([
      _reward('Mocha', id: mocha.id, cost: 50),
      _reward('Classic', id: classic.id, cost: 120),
      _reward('Dirty Matcha', id: 'xyz', cost: 50),
    ]), {mocha.id: 135}, reason: 'Classic is already right; Dirty Matcha is not a menu item');
    expect(craveMenuRepricing(menu), isEmpty);
  });

  test('the whole menu: 28 items priced by tier with no stock limit, each with its own photo', () {
    final menu = craveMenuToAdd(const []);
    expect(menu, hasLength(28));
    for (final r in menu) {
      expect(r.pointsCost, inInclusiveRange(100, 160), reason: r.title);
      expect(r.stock, -1, reason: r.title);
      expect(r.isActive, isTrue, reason: r.title);
      expect(r.description, isNotEmpty, reason: r.title);
      expect(r.id, startsWith('crave_'), reason: r.title);
      expect(rewardPhoto(r.title), isNotNull, reason: r.title);
    }
    expect(menu.map((r) => rewardPhoto(r.title)).toSet(), hasLength(28), reason: 'every item shows its own photo');
    expect(menu.map((r) => r.id).toSet(), hasLength(28));
    expect(menu.where((r) => r.category == 'Food'), hasLength(8));
    expect(menu.where((r) => r.category == 'Coffee'), hasLength(20), reason: 'drinks go under the Coffee chip');
  });

  test('items already there are skipped: by name in any case, or by id when staff renamed one', () {
    final og = craveMenuToAdd(const []).firstWhere((r) => r.title == 'The OG Burger');
    final left = craveMenuToAdd([
      _reward('  matcha DREAM '),
      _reward('Our burger', id: og.id),
      _reward('Dirty Matcha'),
    ]);
    expect(left, hasLength(26));
    expect(left.map((r) => r.title), isNot(contains('Matcha Dream')));
    expect(left.map((r) => r.title), isNot(contains('The OG Burger')));
    expect(craveMenuToAdd(craveMenuToAdd(const [])), isEmpty);
  });

  group('staff Rewards screen', () {
    testWidgets('offers the missing menu items, asks first, then adds exactly those', (tester) async {
      _phone(tester);
      List<Reward>? added;
      Map<String, int>? costs;
      var reloads = 0;
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.admin,
        home: Scaffold(body: AdminRewardsScreen(
          rewards: [_reward('Matcha Dream')],
          onChanged: () => reloads++,
          saveMenu: (a, c) async {
            added = a;
            costs = c;
          },
        )),
      ));
      await tester.pump(const Duration(seconds: 1));
      expect(find.textContaining('27 to add'), findsOneWidget);

      await tester.tap(find.text('Update'));
      await tester.pump(const Duration(seconds: 1));
      expect(added, isNull, reason: 'nothing is written before staff confirm');
      await tester.tap(find.text('Update menu'));
      await tester.pump(const Duration(seconds: 1));

      expect(added, hasLength(27));
      expect(costs, isEmpty);
      expect(added!.map((r) => r.title), isNot(contains('Matcha Dream')));
      expect(reloads, 1);
      await _finish(tester);
    });

    testWidgets('cancelling adds nothing', (tester) async {
      _phone(tester);
      var calls = 0;
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.admin,
        home: Scaffold(body: AdminRewardsScreen(rewards: const [], onChanged: () {}, saveMenu: (_, __) async => calls++)),
      ));
      await tester.pump(const Duration(seconds: 1));
      await tester.tap(find.text('Update'));
      await tester.pump(const Duration(seconds: 1));
      await tester.tap(find.text('Cancel'));
      await tester.pump(const Duration(seconds: 1));
      expect(calls, 0);
      await _finish(tester);
    });

    testWidgets('once the whole menu is in, the offer is gone', (tester) async {
      _phone(tester);
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.admin,
        home: Scaffold(body: AdminRewardsScreen(rewards: craveMenuToAdd(const []), onChanged: () {})),
      ));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Update'), findsNothing);
      await _finish(tester);
    });

    testWidgets('menu items still at the old 50 pts are offered a reprice', (tester) async {
      _phone(tester);
      Map<String, int>? costs;
      final old = [
        for (final r in craveMenuToAdd(const []))
          Reward(id: r.id, title: r.title, description: r.description, pointsCost: 50, category: r.category),
      ];
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.admin,
        home: Scaffold(body: AdminRewardsScreen(rewards: old, onChanged: () {}, saveMenu: (_, c) async => costs = c)),
      ));
      await tester.pump(const Duration(seconds: 1));
      expect(find.textContaining('28 prices to update'), findsOneWidget);
      await tester.tap(find.text('Update'));
      await tester.pump(const Duration(seconds: 1));
      await tester.tap(find.text('Update menu'));
      await tester.pump(const Duration(seconds: 1));
      expect(costs, hasLength(28));
      expect(costs!['crave_samgy_burger'], 160);
      await _finish(tester);
    });
  });

  testWidgets('category chips sit centred when they fit, and scroll from the left when they do not', (tester) async {
    Future<Rect> span(double width) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(MaterialApp(theme: AppTheme.light,
          home: RewardsScreen(user: _user(85), rewards: craveMenuToAdd(const []), onRedeemed: () {})));
      await tester.pump(const Duration(seconds: 2));
      final chips = find.byType(AppChip);
      return tester.getRect(chips.first).expandToInclude(tester.getRect(chips.last));
    }
    addTearDown(tester.view.reset);
    expect((await span(800)).center.dx, closeTo(400, 1));
    final words = tester.getRect(find.text('Rewards from'));
    final logo = tester.getRect(find.byWidgetPredicate((w) =>
        w is Image && w.image is AssetImage && (w.image as AssetImage).assetName == 'assets/brand/crave_logo.png'));
    expect((words.left + logo.right) / 2, closeTo(400, 1), reason: '"Rewards from crave" sits centred over the chips');
    final narrow = await span(320); // the smallest phone supported; the test font makes the chips too wide here
    expect(narrow.left, closeTo(20, 1), reason: 'too wide to centre: starts at the page margin');
    expect(tester.takeException(), isNull);
    await _finish(tester);
  });

  testWidgets('category chips: drinks read as Drinks, each with its count, in a fixed order', (tester) async {
    _phone(tester);
    final fries = Reward(id: 'f', title: 'Fries', description: 'Salted', pointsCost: 50, category: 'Food');
    await tester.pumpWidget(MaterialApp(theme: AppTheme.light,
        home: RewardsScreen(user: _user(200), rewards: [fries, ...craveMenuToAdd(const [])], onRedeemed: () {})));
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('Coffee'), findsNothing);
    final all = tester.getCenter(find.text('All')).dx;
    final drinks = tester.getCenter(find.text('Drinks')).dx;
    final food = tester.getCenter(find.text('Food')).dx;
    expect(all < drinks && drinks < food, isTrue, reason: 'All, Drinks, Food whatever order the data came in');
    expect(find.text('29'), findsOneWidget, reason: 'All');
    expect(find.text('20'), findsOneWidget, reason: 'Drinks');
    expect(find.text('9'), findsOneWidget, reason: 'Food');
    await tester.tap(find.text('Food'));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('Matcha Dream'), findsNothing);
    expect(find.text('Samgy Burger'), findsOneWidget);
    await _finish(tester);
  });

  group('Rewards menu', () {
    testWidgets('a two-column grid of photo tiles, the photo as wide as its tile', (tester) async {
      _phone(tester);
      final menu = craveMenuToAdd(const []);
      await tester.pumpWidget(MaterialApp(theme: AppTheme.light,
          home: RewardsScreen(user: _user(85), rewards: menu, onRedeemed: () {})));
      await tester.pump(const Duration(seconds: 2));
      final tiles = find.byType(RewardTile);
      final a = tester.getRect(tiles.at(0)), b = tester.getRect(tiles.at(1)), third = tester.getRect(tiles.at(2));
      expect(a.top, b.top, reason: 'side by side');
      expect(b.left, greaterThan(a.right));
      expect(third.top, greaterThan(a.bottom), reason: 'two per row on a phone');
      final pic = tester.getRect(find.descendant(of: tiles.at(0), matching: find.byType(Image)));
      expect(pic.width, closeTo(a.width - 2, 0.5), reason: 'edge to edge inside the hairline');
      expect(pic.height, closeTo(pic.width, 0.5), reason: 'square');
      expect(tester.takeException(), isNull);
      await _finish(tester);
    });

    testWidgets("Crave's logo heads the menu, on its own yellow, and reads as text to screen readers", (tester) async {
      _phone(tester);
      await tester.pumpWidget(MaterialApp(theme: AppTheme.light,
          home: RewardsScreen(user: _user(85), rewards: craveMenuToAdd(const []), onRedeemed: () {})));
      await tester.pump(const Duration(seconds: 2));
      final logo = find.byWidgetPredicate((w) =>
          w is Image && w.image is AssetImage && (w.image as AssetImage).assetName == 'assets/brand/crave_logo.png');
      expect(logo, findsOneWidget);
      expect(tester.getRect(logo).bottom, lessThan(tester.getRect(find.text('All')).top),
          reason: 'above the category chips');
      expect(find.bySemanticsLabel(RegExp('Rewards from Crave')), findsOneWidget);
      Object? failure;
      await tester.runAsync(() => precacheImage(const AssetImage('assets/brand/crave_logo.png'),
          tester.element(logo), onError: (e, _) => failure = e));
      expect(failure, isNull, reason: 'bundled and decodes');
      expect(tester.takeException(), isNull);
      await _finish(tester);
    });

    testWidgets('three per row on a tablet', (tester) async {
      tester.view.physicalSize = const Size(800, 1280);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(theme: AppTheme.light,
          home: RewardsScreen(user: _user(85), rewards: craveMenuToAdd(const []), onRedeemed: () {})));
      await tester.pump(const Duration(seconds: 2));
      final tiles = find.byType(RewardTile);
      expect(tester.getRect(tiles.at(2)).top, tester.getRect(tiles.at(0)).top);
      await _finish(tester);
    });
  });

  group('Reward page and tickets', () {
    Future<void> detail(WidgetTester tester, Reward r, {int points = 20}) async {
      _phone(tester);
      await tester.pumpWidget(MaterialApp(theme: AppTheme.light,
          home: RewardDetailScreen(reward: r, user: _user(points), heroTag: 'r')));
      await tester.pump(const Duration(seconds: 2));
    }

    testWidgets('the reward page opens on a large photo, filled as far as the points go', (tester) async {
      await detail(tester, _reward('Dirty Matcha'));
      final fill = tester.widget<RewardFill>(find.byType(RewardFill));
      expect(fill.level, closeTo(20 / 50, 1e-9));
      expect(fill.fit, BoxFit.contain, reason: 'the whole cup shows in the wide frame');
      expect(tester.getSize(find.byType(RewardFill)).height, greaterThan(180), reason: 'a hero, not a tile');
      expect(tester.takeException(), isNull);
      await _finish(tester);
    });

    testWidgets('a sold-out reward page shows the photo greyed, with no fill', (tester) async {
      await detail(tester, Reward(id: 'x', title: 'Dirty Matcha', description: 'd', pointsCost: 50,
          category: 'Coffee', stock: 0));
      expect(find.byType(RewardFill), findsNothing);
      expect(find.byType(ColorFiltered), findsWidgets);
      await _finish(tester);
    });

    testWidgets("a ticket shows the reward's photo with its status in the corner, else the status icon",
        (tester) async {
      await tester.pumpWidget(MaterialApp(theme: AppTheme.light, home: const Scaffold(body: Column(children: [
        RewardTicketArt(title: 'Matcha Dream', icon: Icons.check_circle_rounded, color: Colors.green),
        RewardTicketArt(title: 'Tumbler', icon: Icons.timer_off_rounded, color: Colors.grey),
      ]))));
      expect(find.descendant(of: find.byType(RewardTicketArt).first, matching: find.byType(RewardArt)), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget, reason: 'the status badge on the photo');
      expect(find.descendant(of: find.byType(RewardTicketArt).last, matching: find.byType(RewardArt)), findsNothing);
      expect(find.byIcon(Icons.timer_off_rounded), findsOneWidget);
    });
  });

  group('Home reward card', () {
    Future<void> home(WidgetTester tester, {required int points, required List<Reward> rewards}) async {
      _phone(tester);
      await tester.pumpWidget(MaterialApp(theme: AppTheme.light, home: homeTabPreview(user: _user(points), rewards: rewards)));
      await tester.pump(const Duration(seconds: 3));
    }

    Finder photo(String name) => find.byWidgetPredicate((w) =>
        w is Image && w.image is AssetImage && (w.image as AssetImage).assetName == 'assets/rewards/$name.webp');

    RewardFill fill(WidgetTester tester) => tester.widget<RewardFill>(
        find.descendant(of: find.byKey(const ValueKey('reward-card')), matching: find.byType(RewardFill)));

    testWidgets('ready: the whole drink in a glass inside the card, filled to the top; name, note, price tag, Redeem',
        (tester) async {
      await home(tester, points: 85, rewards: [_reward('Dirty Matcha')]);
      expect(find.text('Ready to redeem'), findsOneWidget);
      expect(photo('matcha_dream'), findsWidgets);
      final card = tester.getRect(find.byKey(const ValueKey('reward-card')));
      final glass = tester.getRect(find.byType(RewardFill));
      expect(glass.height, greaterThan(card.height * 0.8), reason: 'the hero of the card, not a tile');
      final shown = tester.getRect(photo('matcha_dream').first);
      expect(glass.width / shown.height, greaterThanOrEqualTo(0.66), reason: 'the whole cup shows, not a close-up');
      expect(fill(tester).level, 1);
      expect(find.text('Dirty Matcha'), findsOneWidget);
      expect(find.text('Enjoy a free cup of coffee'), findsOneWidget);
      expect(find.text('50 pts'), findsOneWidget, reason: 'the price tag');
      expect(find.text('Redeem'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await _finish(tester);
    });

    testWidgets('out of reach: the drink is filled as far as the points go, and says how far is left', (tester) async {
      await home(tester, points: 20, rewards: [_reward('Dirty Matcha')]);
      expect(find.text('Your next treat'), findsOneWidget);
      expect(find.text('30 pts to go'), findsOneWidget);
      expect(find.text('Redeem'), findsNothing);
      expect(fill(tester).level, closeTo(20 / 50, 1e-9));
      await _finish(tester);
    });

    testWidgets('the fill rises from empty to its level, then its surface keeps waving', (tester) async {
      await tester.pumpWidget(MaterialApp(theme: AppTheme.light, home: const Scaffold(
          body: SizedBox(width: 120, height: 178, child: RewardFill(title: 'Matcha Dream', category: 'Coffee', level: 0.6)))));
      RewardFillState state() => tester.state<RewardFillState>(find.byType(RewardFill));
      expect(state().shownLevel, 0, reason: 'starts empty');
      await tester.pump(const Duration(milliseconds: 300));
      expect(state().shownLevel, inExclusiveRange(0, 0.6), reason: 'rising');
      await tester.pump(const Duration(seconds: 2));
      expect(state().shownLevel, closeTo(0.6, 1e-9), reason: 'risen to its level and stays there');
      final waves = <double>{};
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 700));
        waves.add(state().wavePhase);
        expect(state().shownLevel, closeTo(0.6, 1e-9));
      }
      expect(waves.length, 10, reason: 'the wave never stops');
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('with reduced motion the fill is simply at its level', (tester) async {
      await tester.pumpWidget(MaterialApp(theme: AppTheme.light, home: const MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: Scaffold(body: SizedBox(width: 120, height: 178,
              child: RewardFill(title: 'Matcha Dream', category: 'Coffee', level: 0.6))))));
      RewardFillState state() => tester.state<RewardFillState>(find.byType(RewardFill));
      expect(state().shownLevel, closeTo(0.6, 1e-9));
      final phase = state().wavePhase;
      await tester.pump(const Duration(seconds: 1));
      expect(state().wavePhase, phase, reason: 'a still surface');
    });

    testWidgets('swiping the carousel moves the photo a little slower than its card', (tester) async {
      await home(tester, points: 85, rewards: [_reward('Dirty Matcha'), _reward('Hot Chocolate')]);
      expect(tester.widget<RewardFill>(find.byType(RewardFill).first).parallax, 0);
      await tester.drag(find.byKey(const ValueKey('reward-card')).first, const Offset(-80, 0));
      await tester.pump();
      expect(tester.widget<RewardFill>(find.byType(RewardFill).first).parallax, isNot(0));
      await _finish(tester);
    });

    testWidgets('no photo: the drawn icon fills the panel instead', (tester) async {
      await home(tester, points: 85, rewards: [_reward('Tumbler')]);
      expect(find.descendant(of: find.byKey(const ValueKey('reward-card')), matching: find.byType(Image)), findsNothing);
      expect(find.descendant(of: find.byKey(const ValueKey('reward-card')), matching: find.byType(Icon)), findsWidgets);
      await _finish(tester);
    });
  });
}
