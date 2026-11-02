// Phase 4 of the UI/UX transformation: the premium visual system (materials, the signature coin, touch
// tilt, dimensional reward art). These check behaviour and fallbacks; how it looks is checked by eye.
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ecoreward_bin/core/app_theme.dart';
import 'package:ecoreward_bin/models/models.dart';
import 'package:ecoreward_bin/screens/customer/customer_home_screen.dart';
import 'package:ecoreward_bin/widgets/ui.dart';

import 'support/fonts.dart';

Widget _app(Widget child, {ThemeData? theme, bool highContrast = false, bool reduced = false}) => MaterialApp(
      theme: theme ?? AppTheme.light,
      home: Builder(builder: (ctx) => MediaQuery(
            data: MediaQuery.of(ctx).copyWith(highContrast: highContrast, disableAnimations: reduced),
            child: Scaffold(body: Center(child: child)),
          )),
    );

Matrix4 _transformOf(WidgetTester tester) =>
    tester.widget<Transform>(find.descendant(of: find.byType(TiltOnTouch), matching: find.byType(Transform)).first)
        .transform;

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({'notifications_prompted': true});
    await loadRealFonts();
    await loadAppFonts();
  });

  group('EcoCoin, the signature mark', () {
    for (final size in [20.0, 64.0]) {
      testWidgets('paints at $size and is hidden from screen readers (decorative)', (tester) async {
        await tester.pumpWidget(_app(EcoCoin(size: size)));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(tester.getSize(find.byType(EcoCoin)), Size(size, size));
        expect(find.descendant(of: find.byType(EcoCoin), matching: find.byType(ExcludeSemantics)), findsWidgets);
      });
    }

    testWidgets('the entrance turn settles flat, and is skipped under reduced motion', (tester) async {
      await tester.pumpWidget(_app(const EcoCoin(size: 64, turnIn: true), reduced: true));
      final still = tester.widget<Transform>(find.descendant(of: find.byType(EcoCoin), matching: find.byType(Transform)));
      expect(still.transform, Matrix4.identity()..setEntry(3, 2, 0.002));
      await tester.pumpWidget(_app(const EcoCoin(size: 64, turnIn: true)));
      await tester.pumpAndSettle();
      final settled = tester.widget<Transform>(find.descendant(of: find.byType(EcoCoin), matching: find.byType(Transform)));
      expect(settled.transform.storage[0], closeTo(1, 1e-6), reason: 'no rotation left once it settles');
    });
  });

  group('AppSurface materials', () {
    testWidgets('glass blurs what is behind it', (tester) async {
      await tester.pumpWidget(_app(const AppSurface(depth: Depth.raised, onHero: true, child: Text('x'))));
      expect(find.byType(BackdropFilter), findsOneWidget);
      final filter = tester.widget<BackdropFilter>(find.byType(BackdropFilter)).filter;
      expect(filter, isA<ImageFilter>());
    });

    testWidgets('high contrast turns glass solid', (tester) async {
      await tester.pumpWidget(_app(const AppSurface(depth: Depth.floating, onHero: true, child: Text('x')),
          highContrast: true));
      expect(find.byType(BackdropFilter), findsNothing);
    });

    testWidgets('raised surfaces cast a shadow in light mode and use a lit edge in dark mode', (tester) async {
      BoxDecoration deco() => tester.widget<Container>(find.descendant(of: find.byType(AppSurface),
          matching: find.byType(Container)).first).decoration! as BoxDecoration;
      await tester.pumpWidget(_app(const AppSurface(depth: Depth.raised, child: Text('x'))));
      expect(deco().boxShadow, isNotEmpty);
      await tester.pumpWidget(_app(const AppSurface(depth: Depth.raised, child: Text('x')), theme: AppTheme.dark));
      await tester.pumpAndSettle();   // the theme change animates
      expect(deco().boxShadow ?? const [], isEmpty);
      expect(deco().gradient, isNotNull, reason: 'the lit top edge');
    });
  });

  group('TiltOnTouch', () {
    Widget card({bool reduced = false}) =>
        _app(const TiltOnTouch(child: SizedBox(width: 300, height: 160, child: ColoredBox(color: Colors.green))),
            reduced: reduced);

    testWidgets('leans towards the finger and settles back on release', (tester) async {
      await tester.pumpWidget(card());
      final box = tester.getRect(find.byType(TiltOnTouch));
      final gesture = await tester.startGesture(box.centerRight - const Offset(10, 0));
      await tester.pumpAndSettle();
      expect(_transformOf(tester).storage[0], lessThan(1), reason: 'rotated about the vertical axis');
      await gesture.up();
      await tester.pumpAndSettle();
      expect(_transformOf(tester).storage[0], closeTo(1, 1e-6));
    });

    testWidgets('a scroll that starts on the card does not tilt it', (tester) async {
      await tester.pumpWidget(card());
      final box = tester.getRect(find.byType(TiltOnTouch));
      final gesture = await tester.startGesture(box.centerRight - const Offset(10, 0));
      await gesture.moveBy(const Offset(0, -40));
      await tester.pumpAndSettle();
      expect(_transformOf(tester).storage[0], closeTo(1, 1e-6));
      await gesture.up();
    });

    testWidgets('stays flat under reduced motion', (tester) async {
      await tester.pumpWidget(card(reduced: true));
      final box = tester.getRect(find.byType(TiltOnTouch));
      final gesture = await tester.startGesture(box.centerRight - const Offset(10, 0));
      await tester.pumpAndSettle();
      expect(find.descendant(of: find.byType(TiltOnTouch), matching: find.byType(Transform)), findsNothing);
      await gesture.up();
    });
  });

  testWidgets('Home: the balance card carries the coin and tilts', (tester) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(theme: AppTheme.light, home: homeTabPreview(user: UserModel(uid: 'u',
        username: 'Ana', email: 'a@x.com', role: 'customer', points: 240, createdAt: DateTime(2026)))));
    await tester.pump(const Duration(seconds: 3));
    expect(find.byType(EcoCoin), findsOneWidget);
    expect(find.byType(TiltOnTouch), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 20));
  });
}
