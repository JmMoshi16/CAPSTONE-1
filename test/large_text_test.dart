// Home on the owner's phone: 360 dp wide with the system text at 1.35x (OPPO CPH2799). Text must keep its size
// and spacing, never run together, never sit under the clock.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ecoreward_bin/core/app_theme.dart';
import 'package:ecoreward_bin/models/models.dart';
import 'package:ecoreward_bin/screens/customer/customer_home_screen.dart';
import 'package:ecoreward_bin/widgets/ui.dart';

import 'support/fonts.dart';

Future<void> _home(WidgetTester tester, {double scale = 1.35}) async {
  tester.view.physicalSize = const Size(1080, 2372);
  tester.view.devicePixelRatio = 3;
  tester.view.padding = const FakeViewPadding(top: 96);   // a 32 dp status bar
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  await tester.pumpWidget(MaterialApp(
    theme: AppTheme.light,
    home: homeTabPreview(
      user: UserModel(uid: 'u', username: 'JmMoshi', email: 'a@b.c', role: 'customer', points: 85,
          lifetimePoints: 385, createdAt: DateTime(2026, 1, 1), streak: 0, scanCount: 4),
      rewards: [Reward(id: 'c', title: 'Classic', description: 'Iced coffee', pointsCost: 120, category: 'Coffee')],
    ),
  ));
  await tester.pump(const Duration(seconds: 3));
}

Future<void> _finish(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 20));
}

const _shortcuts = ['Scan', 'My codes', 'Leaderboard', 'Badges'];

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({'notifications_prompted': true});
    await loadRealFonts();
    await loadAppFonts();
  });

  testWidgets('the four shortcut labels share one size, with clear space between them', (tester) async {
    await _home(tester);
    final rects = [for (final l in _shortcuts) tester.getRect(find.text(l).first)];   // first: the hero, not the nav
    for (final r in rects.skip(1)) {
      expect(r.height, closeTo(rects.first.height, 0.5), reason: 'same size, none shrunk on its own');
    }
    for (var i = 1; i < rects.length; i++) {
      expect(rects[i].left - rects[i - 1].right, greaterThanOrEqualTo(6), reason: '${_shortcuts[i - 1]} | ${_shortcuts[i]}');
    }
    await _finish(tester);
  });

  testWidgets('the rank pill says the whole rank and level', (tester) async {
    await _home(tester);
    final pill = tester.renderObject<RenderParagraph>(find.textContaining(RegExp(r', level \d+$')));
    expect(pill.didExceedMaxLines, isFalse, reason: 'not cut to "Silver, leve…"');
    await _finish(tester);
  });

  testWidgets("the rewards heading fits on one line beside See all", (tester) async {
    await _home(tester);
    final title = tester.renderObject<RenderParagraph>(
        find.descendant(of: find.text('Your next treat'), matching: find.byType(RichText)));
    final header = tester.getRect(find.ancestor(of: find.text('Your next treat'), matching: find.byType(SectionHeader)));
    // Measured in the app's own font: the test harness draws button labels in a square fallback font.
    final context = tester.element(find.text('Your next treat'));
    final seeAll = TextPainter(
        text: TextSpan(text: 'See all', style: Theme.of(context).textTheme.labelLarge!.copyWith(fontFamily: 'DMSans')),
        textDirection: TextDirection.ltr,
        textScaler: const TextScaler.linear(1.35))
      ..layout();
    expect(title.getMaxIntrinsicWidth(double.infinity) + seeAll.width + 24, lessThanOrEqualTo(header.width));
    seeAll.dispose();
    await _finish(tester);
  });

  testWidgets('the reward card shows the whole drink in a glass set inside it, not a close-up', (tester) async {
    await _home(tester);
    final card = tester.getRect(find.byKey(const ValueKey('reward-card')));
    final glass = tester.getRect(find.byType(RewardFill));
    // The café's photos are square with the cup standing in the middle 62 % (x 75 to 324 of 400); covering the
    // glass, the photo is drawn this big, so this share of its width shows.
    final photo = tester.getRect(find.descendant(of: find.byType(RewardFill), matching: find.byType(Image)).first);
    expect(glass.width / math.max(photo.width, photo.height), greaterThanOrEqualTo(0.66),
        reason: 'the whole cup, rim to rim, lid to coaster');
    expect(glass.left - card.left, greaterThanOrEqualTo(AppSpace.xs), reason: 'its own glass, inset in the card');
    expect(glass.top - card.top, greaterThanOrEqualTo(AppSpace.xs));
    expect(card.bottom - glass.bottom, greaterThanOrEqualTo(AppSpace.xs));
    final title = tester.renderObject<RenderParagraph>(
        find.descendant(of: find.text('Classic'), matching: find.byType(RichText)));
    expect(title.didExceedMaxLines, isFalse);
    expect(tester.takeException(), isNull);
    await _finish(tester);
  });

  testWidgets('scrolled content never runs under the clock: a navy band fills the status bar', (tester) async {
    await _home(tester);
    // What is drawn, not just the target: the fade's own value.
    double scrim() => tester.widget<FadeTransition>(find.descendant(
        of: find.byKey(const ValueKey('status-scrim')), matching: find.byType(FadeTransition))).opacity.value;
    expect(scrim(), 0, reason: 'at the top the hero is already behind the clock');
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -300));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(scrim(), 1);
    expect(tester.getRect(find.byKey(const ValueKey('status-scrim'))).height, 32);
    await _finish(tester);
  });
}
