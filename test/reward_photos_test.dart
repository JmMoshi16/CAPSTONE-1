// Crave's product photos on rewards: picked by the reward's name, bundled with the app (no database field), the
// drawn icon whenever the name gives nothing away.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ecoreward_bin/core/app_theme.dart';
import 'package:ecoreward_bin/widgets/ui.dart';

const _dir = 'assets/rewards';

/// Every reward name Crave sells (and the four live rewards), with the photo it should show.
const _expected = {
  // The live rewards (2026-11-04).
  'Caramel Macchiato': 'caramel_drip',
  'Dirty Matcha': 'matcha_dream',
  'Hot Chocolate': 'dark_choco_dream',
  'takoFRIES': 'fries',
  // Coffee based.
  'Mocha': 'mocha',
  'Caramel Drip': 'caramel_drip',
  'Classic': 'classic',
  'Salted Classic': 'salted_classic',
  'Sweet & Salty': 'sweet_and_salty',
  'Sweet Classic': 'sweet_classic',
  'Orange Americano': 'orange_americano',
  'Cookies & Brew': 'cookies_and_brew',
  'Sweet Oat': 'sweet_oat',
  // Tropical series.
  'Sunrise': 'sunrise',
  'Signature Blend': 'signature_blend',
  // Non-coffee based.
  'Strawberry Dream': 'strawberry_dream',
  'Mango Mirage': 'mango_mirage',
  'Blueberry Haze': 'blueberry_haze',
  'Strawberry Matcha': 'strawberry_matcha',
  'Matcha Cookies': 'matcha_cookies',
  'Matcha Dream': 'matcha_dream',
  'Dark Choco Dream': 'dark_choco_dream',
  'Chocnut Cloud': 'chocnut_cloud',
  'Choco Berry': 'choco_berry',
  // Food.
  'Sweet Glazed Tocino': 'tocino',
  'Smokey Garlic Tapa': 'tapa',
  'Crunch Bowl': 'crunch_bowl',
  'Smokey Classic Crunch Bowl': 'crunch_smokey_classic',
  'Spicy Mango Crunch Bowl': 'crunch_spicy_mango',
  "Buzz n' Burn Crunch Bowl": 'crunch_buzz_n_burn',
  'The OG Burger': 'og_burger',
  'Samgy Burger': 'samgy_burger',
  'Pizza Burger': 'pizza_burger',
  'Fries': 'fries',
};

void main() {
  test('each Crave product and each live reward gets its own photo', () {
    for (final MapEntry(key: title, value: photo) in _expected.entries) {
      expect(rewardPhoto(title), '$_dir/$photo.webp', reason: title);
    }
  });

  test('case and spacing do not matter', () {
    expect(rewardPhoto('DIRTY MATCHA (Large)'), '$_dir/matcha_dream.webp');
    expect(rewardPhoto('Spicy Mango'), '$_dir/crunch_spicy_mango.webp', reason: 'the crunch flavour, not the drink');
    expect(rewardPhoto('Smokey Classic'), '$_dir/crunch_smokey_classic.webp', reason: 'the crunch flavour, not coffee');
    expect(rewardPhoto('Free pizzaburger'), '$_dir/pizza_burger.webp');
    expect(rewardPhoto('Sweet and Salty'), '$_dir/sweet_and_salty.webp');
  });

  test('a name that gives nothing away keeps the drawn icon', () {
    for (final title in ['Iced Latte', 'Croissant', '10% off', 'Tumbler', 'Free gift', 'Steak plate', 'Boat ride']) {
      expect(rewardPhoto(title), isNull, reason: title);
    }
  });

  testWidgets('every photo is bundled and decodes', (tester) async {
    await tester.pumpWidget(const SizedBox());
    final ctx = tester.element(find.byType(SizedBox));
    for (final photo in _expected.values.toSet()) {
      Object? failure;
      await tester.runAsync(() => precacheImage(AssetImage('$_dir/$photo.webp'), ctx, onError: (e, _) => failure = e));
      expect(failure, isNull, reason: photo);
    }
  });

  group('RewardArt', () {
    Future<void> pump(WidgetTester tester, String title, {bool muted = false}) async {
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(body: Center(child: RewardArt(title: title, category: 'Coffee', size: 112, muted: muted))),
      ));
    }

    String asset(WidgetTester tester) =>
        ((tester.widget<Image>(find.byType(Image)).image as ResizeImage).imageProvider as AssetImage).assetName;

    testWidgets('shows the photo for a Crave product, decoded at the size it is drawn', (tester) async {
      await pump(tester, 'Dirty Matcha');
      expect(asset(tester), '$_dir/matcha_dream.webp');
      expect((tester.widget<Image>(find.byType(Image)).image as ResizeImage).width, 112 * tester.view.devicePixelRatio);
      expect(find.byType(Icon), findsNothing);
      expect(tester.getSize(find.byType(RewardArt)), const Size.square(112));
    });

    testWidgets('keeps the drawn icon when there is no photo', (tester) async {
      await pump(tester, 'Iced Latte');
      expect(find.byType(Image), findsNothing);
      expect(find.byIcon(Icons.local_drink_rounded), findsOneWidget);
    });

    testWidgets('a sold-out photo is greyed out', (tester) async {
      await pump(tester, 'Dirty Matcha', muted: true);
      expect(find.ancestor(of: find.byType(Image), matching: find.byType(ColorFiltered)), findsOneWidget);
    });
  });
}
