// Crave by: Secret Cafe's official logo as the app's brand: the animated splash, sign in, register and Home.
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ecoreward_bin/core/app_theme.dart';
import 'package:ecoreward_bin/models/models.dart';
import 'package:ecoreward_bin/screens/customer/customer_home_screen.dart';
import 'package:ecoreward_bin/screens/login_screen.dart';
import 'package:ecoreward_bin/screens/register_screen.dart';
import 'package:ecoreward_bin/screens/splash_screen.dart';
import 'package:ecoreward_bin/widgets/ui.dart';

import 'support/fonts.dart';

void _phone(WidgetTester tester, {double width = 393, double height = 852}) {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Future<void> _finish(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 20));
}

bool _shows(Widget w, String asset) {
  if (w is! Image) return false;
  var p = w.image;
  if (p is ResizeImage) p = p.imageProvider;
  return p is AssetImage && p.assetName == asset;
}

Finder _asset(String asset) => find.byWidgetPredicate((w) => _shows(w, asset));

double _opacity(WidgetTester tester, String layer) =>
    tester.widget<Opacity>(find.byKey(ValueKey('logo-$layer'))).opacity;

Matrix4 _transform(WidgetTester tester, String layer) => tester.widget<Transform>(
    find.descendant(of: find.byKey(ValueKey('logo-$layer')), matching: find.byType(Transform)).first).transform;

const _layers = ['steam', 'cup', 'name', 'tagline'];

/// The fade into the next screen: it starts counting on the frame after the handoff, and the faded-out splash
/// leaves on the frame after it ends.
Future<void> _handOver(WidgetTester tester) async {
  await tester.pump(BrandSplash.handoff);
  await tester.pump(BrandSplash.handoff);
  await tester.pump();
}

Widget _splash({Widget? child, bool reduced = false}) => MaterialApp(
      theme: AppTheme.light,
      home: MediaQuery(data: MediaQueryData(disableAnimations: reduced), child: BrandSplash(child: child)),
    );

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({'notifications_prompted': true});
    await loadRealFonts();
    await loadAppFonts();
  });

  group('The official logo', () {
    test('is bundled as the full 1254 px image, and the layer cuts fall only on empty yellow rows', () async {
      final data = await rootBundle.load(CraveBrand.logo);
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      final image = (await codec.getNextFrame()).image;
      expect((image.width, image.height), (1254, 1254));
      final px = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
      bool inkIn(int row) {
        for (var x = 0; x < image.width; x++) {
          final i = (row * image.width + x) * 4;
          if (px.getUint8(i + 2) - px.getUint8(i + 1) > 40) return true;   // navy: blue above green
        }
        return false;
      }

      final cuts = CraveBrand.layers.map((l) => l.$1).skip(1);
      for (final cut in cuts) {
        final row = (cut * image.height).round();
        for (final r in [row - 2, row - 1, row, row + 1]) {
          expect(inkIn(r), isFalse, reason: 'cut at row $row crosses the artwork');
        }
      }
      // The layers tile the whole image, so together they are the logo, once.
      expect(CraveBrand.layers.first.$1, 0);
      expect(CraveBrand.layers.last.$2, 1);
      for (var i = 1; i < CraveBrand.layers.length; i++) {
        expect(CraveBrand.layers[i].$1, CraveBrand.layers[i - 1].$2);
      }
    });
  });

  group('Splash', () {
    testWidgets('yellow, with the cup first, then the steam rising, CRAVE, and BY: SECRET CAFE last', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_splash());
      final bg = tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor;
      expect(bg, CraveBrand.ground, reason: "the logo's own yellow, so its edges vanish");
      expect(_asset(CraveBrand.logo), findsWidgets);

      final shownAt = <String, int>{};
      for (var ms = 0; ms <= 2600; ms += 50) {
        for (final l in _layers) {
          if (!shownAt.containsKey(l) && _opacity(tester, l) > 0) shownAt[l] = ms;
        }
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(shownAt['cup']!, greaterThan(100), reason: 'a moment of plain yellow first');
      expect(shownAt['cup']!, lessThan(shownAt['steam']!));
      expect(shownAt['steam']!, lessThan(shownAt['name']!));
      expect(shownAt['name']!, lessThan(shownAt['tagline']!));
      await _finish(tester);
    });

    testWidgets('the steam rises out of the cup into place', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_splash());
      await tester.pump(const Duration(milliseconds: 750));
      expect(_transform(tester, 'steam').getTranslation().y, greaterThan(0), reason: 'still below its place');
      await tester.pump(const Duration(seconds: 2));
      expect(_transform(tester, 'steam').getTranslation().y, 0);
      await _finish(tester);
    });

    testWidgets('it ends on the complete original logo: every layer whole and in place', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_splash());
      await tester.pump(BrandSplash.intro);
      for (final l in _layers) {
        expect(_opacity(tester, l), 1, reason: l);
        expect(_transform(tester, l).isIdentity(), isTrue, reason: l);
      }
      await _finish(tester);
    });

    testWidgets('fresh steam keeps rising above the cup while it waits', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_splash());
      await tester.pump(const Duration(seconds: 3));
      final a = _transform(tester, 'vapour').getTranslation().y;
      await tester.pump(const Duration(milliseconds: 400));
      final b = _transform(tester, 'vapour').getTranslation().y;
      expect(a, isNot(b));
      expect(_transform(tester, 'steam').isIdentity(), isTrue, reason: "the logo's own steam stays put");
      await _finish(tester);
    });

    SplashLight light(WidgetTester tester) => tester.widget<SplashLight>(find.byType(SplashLight));

    testWidgets('the yellow is alive: a warm light drifts across it, and never stops', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_splash());
      expect(light(tester).strength, 0, reason: "starts as the launch screen's flat yellow, so no jump");
      await tester.pump(const Duration(seconds: 1));
      expect(light(tester).strength, 1);
      final seen = <double>{};
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 1700));
        seen.add(light(tester).phase);
      }
      expect(seen.length, 12, reason: 'still moving 20 s in, long after the reveal');
      await _finish(tester);
    });

    testWidgets('with reduced motion the yellow stays still', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_splash(reduced: true));
      await tester.pump(const Duration(milliseconds: 300));
      expect(light(tester).strength, 0);
      await _finish(tester);
    });

    testWidgets('it hands over to the first screen after the reveal, not before', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_splash(child: const Text('Sign in')));
      await tester.pump(const Duration(milliseconds: 2400));
      expect(find.text('Sign in'), findsNothing);
      await tester.pump(BrandSplash.intro);
      await _handOver(tester);
      expect(find.text('Sign in'), findsOneWidget);
      expect(_asset(CraveBrand.logo), findsNothing);
      await _finish(tester);
    });

    testWidgets('a slow sign-in check holds the finished logo, then hands over', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_splash());
      await tester.pump(const Duration(seconds: 6));
      expect(_opacity(tester, 'tagline'), 1);
      await tester.pumpWidget(_splash(child: const Text('Home')));
      await _handOver(tester);
      expect(find.text('Home'), findsOneWidget);
      expect(_asset(CraveBrand.logo), findsNothing);
      await _finish(tester);
    });

    testWidgets('with reduced motion the whole logo shows at once, still, then hands over', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_splash(child: const Text('Sign in'), reduced: true));
      await tester.pump();
      for (final l in _layers) {
        expect(_opacity(tester, l), 1, reason: l);
        expect(_transform(tester, l).isIdentity(), isTrue, reason: l);
      }
      expect(find.byKey(const ValueKey('logo-vapour')), findsNothing);
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
      expect(find.text('Sign in'), findsOneWidget);
      await _finish(tester);
    });

    for (final size in const [Size(320, 568), Size(393, 852), Size(800, 1280)]) {
      testWidgets('the logo is square, whole and on screen at $size', (tester) async {
        _phone(tester, width: size.width, height: size.height);
        await tester.pumpWidget(_splash());
        await tester.pump(BrandSplash.intro);
        final box = tester.getRect(find.byKey(const ValueKey('splash-logo')));
        expect(box.width, closeTo(box.height, 1e-9), reason: 'never stretched');
        expect(box.left, greaterThanOrEqualTo(0));
        expect(box.right, lessThanOrEqualTo(size.width));
        expect(box.top, greaterThanOrEqualTo(0));
        expect(box.bottom, lessThanOrEqualTo(size.height));
        expect(box.width, greaterThan(size.shortestSide * 0.6), reason: 'the hero of the screen');
        expect(tester.takeException(), isNull);
        await _finish(tester);
      });
    }

    testWidgets('screen readers hear the café, loading', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_splash());
      expect(find.bySemanticsLabel('Crave by Secret Cafe. Loading'), findsOneWidget);
      await _finish(tester);
    });
  });

  group('Logo in the app', () {
    testWidgets('sign in shows the official logo, not the old leaf animation', (tester) async {
      _phone(tester);
      await tester.pumpWidget(MaterialApp(theme: AppTheme.light, home: const LoginScreen()));
      await tester.pump(const Duration(seconds: 2));
      expect(find.byType(CraveLogo), findsOneWidget);
      expect(_asset(CraveBrand.logo), findsOneWidget);
      await _finish(tester);
    });

    testWidgets('register shows the official logo', (tester) async {
      _phone(tester);
      await tester.pumpWidget(MaterialApp(theme: AppTheme.light, home: const RegisterScreen()));
      await tester.pump(const Duration(seconds: 2));
      expect(_asset(CraveBrand.logo), findsOneWidget);
      expect(tester.takeException(), isNull);
      await _finish(tester);
    });

    Widget home() => MaterialApp(theme: AppTheme.light, home: homeTabPreview(user: UserModel(
        uid: 'u', username: 'JmMoshi', email: 'a@b.c', role: 'customer', points: 120, lifetimePoints: 300,
        createdAt: DateTime(2026, 1, 1), streak: 0, scanCount: 4)));

    testWidgets("Home's header carries the café's cup mark", (tester) async {
      _phone(tester, width: 360, height: 640);
      await tester.pumpWidget(home());
      await tester.pump(const Duration(seconds: 3));
      expect(_asset(CraveBrand.mark), findsOneWidget);
      expect(find.bySemanticsLabel('Crave by Secret Cafe'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await _finish(tester);
    });

    testWidgets("on a phone narrower than 360 dp the mark gives the name its room", (tester) async {
      _phone(tester, width: 320, height: 640);
      await tester.pumpWidget(home());
      await tester.pump(const Duration(seconds: 3));
      expect(_asset(CraveBrand.mark), findsNothing);
      expect(tester.takeException(), isNull);
      await _finish(tester);
    });
  });
}
