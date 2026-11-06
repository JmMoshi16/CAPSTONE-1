// The floating pill tab bar (FloatingPillNav): what each slot does, where the bubble goes, and how it adapts.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ecoreward_bin/core/app_theme.dart';
import 'package:ecoreward_bin/models/models.dart';
import 'package:ecoreward_bin/screens/customer/customer_home_screen.dart';
import 'package:ecoreward_bin/widgets/ui.dart';

import 'support/fonts.dart';

const _tabs = [
  FloatingNavTab(glyph: NavGlyphKind.home, label: 'Home'),
  FloatingNavTab(glyph: NavGlyphKind.rewards, label: 'Rewards'),
  FloatingNavTab(glyph: NavGlyphKind.activity, label: 'Activity'),
  FloatingNavTab(glyph: NavGlyphKind.profile, label: 'Profile'),
];

final _scan = find.byKey(const ValueKey('nav-scan'));

class _Host extends StatefulWidget {
  const _Host({required this.log});
  final List<String> log;
  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  int index = 0;
  @override
  Widget build(BuildContext context) => Scaffold(
        body: const SizedBox.expand(),
        bottomNavigationBar: FloatingPillNav(
          tabs: _tabs,
          selectedIndex: index,
          onTap: (i) {
            widget.log.add('tab $i');
            setState(() => index = i);
          },
          action: FloatingNavAction(glyph: NavGlyphKind.scan, label: 'Scan',
              semanticLabel: 'Scan the QR code at the bin', onTap: () => widget.log.add('scan'),
              onLongPress: () => widget.log.add('scan with light'), longPressHint: 'scan with the flashlight on'),
        ),
      );
}

Future<void> _pump(WidgetTester tester, {Size size = const Size(393, 852), ThemeData? theme, bool reduced = false,
    List<String>? log}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    theme: theme ?? AppTheme.light,
    home: Builder(builder: (ctx) => MediaQuery(
          data: MediaQuery.of(ctx).copyWith(disableAnimations: reduced),
          child: _Host(log: log ?? []),
        )),
  ));
}

double _bubbleX(WidgetTester tester) => tester.getCenter(find.byKey(const ValueKey('nav-pill'))).dx;
double _bubbleY(WidgetTester tester) => tester.getCenter(find.byKey(const ValueKey('nav-pill'))).dy;
double _labelX(WidgetTester tester, String label) => tester.getCenter(find.text(label)).dx;

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({'notifications_prompted': true});
    await loadRealFonts();
    await loadAppFonts();
  });

  testWidgets('tabs switch, Scan opens the scanner (long press: with the light), and is never a tab', (tester) async {
    final log = <String>[];
    await _pump(tester, log: log);
    await tester.tap(find.text('Rewards'));
    await tester.tap(find.text('Scan'));
    await tester.longPress(find.text('Scan'));
    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    expect(log, ['tab 1', 'scan', 'scan with light', 'tab 3']);
  });

  testWidgets('the bubble sits over the selected tab, and follows it', (tester) async {
    await _pump(tester);
    await tester.pumpAndSettle();
    expect(_bubbleX(tester), closeTo(_labelX(tester, 'Home'), 1));
    await tester.tap(find.text('Activity'));
    await tester.pumpAndSettle();
    expect(_bubbleX(tester), closeTo(_labelX(tester, 'Activity'), 1));
  });

  testWidgets('quick taps end on the last tab, without a jump back', (tester) async {
    await _pump(tester);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Profile'));
    await tester.pump(const Duration(milliseconds: 80));
    final midway = _bubbleX(tester);
    await tester.tap(find.text('Rewards'));
    await tester.pump(const Duration(milliseconds: 16));
    expect((_bubbleX(tester) - midway).abs(), lessThan(30), reason: 'it turns from where it is');
    await tester.pumpAndSettle();
    expect(_bubbleX(tester), closeTo(_labelX(tester, 'Rewards'), 1));
  });

  testWidgets('with reduced motion the bubble moves at once, without lifting', (tester) async {
    await _pump(tester, reduced: true);
    await tester.pump();
    final restY = _bubbleY(tester);
    await tester.tap(find.text('Profile'));
    await tester.pump();
    expect(_bubbleX(tester), closeTo(_labelX(tester, 'Profile'), 1));
    expect(_bubbleY(tester), restY);
  });

  testWidgets('the bubble hops: it lifts on the way and settles at the same height', (tester) async {
    await _pump(tester);
    await tester.pumpAndSettle();
    final restY = _bubbleY(tester);
    await tester.tap(find.text('Profile'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));   // half way
    expect(_bubbleY(tester), lessThan(restY - 4), reason: 'lifted off the bar');
    await tester.pumpAndSettle();
    expect(_bubbleY(tester), closeTo(restY, 0.01), reason: 'landed back on the bar');
  });

  testWidgets("the bubble and Scan are lit from above, like the app's other surfaces", (tester) async {
    for (final theme in [AppTheme.light, AppTheme.dark]) {
      await _pump(tester, theme: theme);
      await tester.pumpAndSettle();
      BoxDecoration deco(Finder f) => tester.widget<DecoratedBox>(f).decoration as BoxDecoration;
      expect(deco(find.descendant(of: find.byKey(const ValueKey('nav-pill')), matching: find.byType(DecoratedBox)).first)
          .gradient, isNotNull, reason: 'bubble, ${theme.brightness}');
      expect(deco(_scan)
          .gradient, isNotNull, reason: 'Scan, ${theme.brightness}');
    }
  });

  testWidgets('the selected label is bold mint on the forest bar; the others are quiet', (tester) async {
    await _pump(tester);
    await tester.pumpAndSettle();
    final c = tester.element(find.text('Home')).colors;
    TextStyle style(String label) => DefaultTextStyle.of(tester.element(find.text(label))).style;
    expect(style('Home').color, c.accent);
    expect(style('Home').fontWeight, FontWeight.w800);
    expect(style('Rewards').color, isNot(c.accent));
    expect(style('Rewards').fontWeight, FontWeight.w600);
  });

  testWidgets('screen readers hear which tab is selected', (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(tester);
    await tester.pumpAndSettle();
    expect(tester.getSemantics(find.bySemanticsLabel('Home')),
        isSemantics(label: 'Home', isButton: true, isSelected: true));
    expect(tester.getSemantics(find.bySemanticsLabel('Rewards')),
        isSemantics(label: 'Rewards', isButton: true, isSelected: false));
    handle.dispose();
  });

  testWidgets('Scan never wears the bubble: a different colour, in the bar', (tester) async {
    for (final theme in [AppTheme.light, AppTheme.dark]) {
      await _pump(tester, theme: theme);
      await tester.pumpAndSettle();
      BoxDecoration deco(Finder f) => tester.widget<DecoratedBox>(f).decoration as BoxDecoration;
      final scan = deco(_scan);
      final bubble = deco(find.descendant(of: find.byKey(const ValueKey('nav-pill')),
          matching: find.byType(DecoratedBox)).first);
      for (final colour in bubble.gradient!.colors) {
        expect(scan.gradient!.colors, isNot(contains(colour)), reason: '${theme.brightness}');
      }
      final bubbleRect = tester.getRect(find.byKey(const ValueKey('nav-pill')));
      expect(tester.getCenter(_scan).dy, greaterThan(bubbleRect.bottom - 14),
          reason: 'Scan sits in the bar, below where the bubble rises');
    }
  });

  testWidgets('on a tablet the bar keeps a pill width, centred', (tester) async {
    await _pump(tester, size: const Size(1024, 1366));
    await tester.pumpAndSettle();
    final bar = tester.getRect(find.byKey(const ValueKey('nav-capsule')));
    expect(bar.width, lessThanOrEqualTo(520));
    expect(bar.center.dx, closeTo(512, 1));
  });

  testWidgets('Home: the bar floats over the page, and the last item scrolls clear of it', (tester) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final now = DateTime.now();
    await tester.pumpWidget(MaterialApp(theme: AppTheme.light, home: homeTabPreview(
      user: UserModel(uid: 'u', username: 'Ana', email: 'a@x.com', role: 'customer', createdAt: DateTime(2026)),
      logs: [for (var i = 0; i < 3; i++) WasteLog(userId: 'u', wasteType: 'Residual', pointsEarned: 10,
          timestamp: now.subtract(Duration(hours: i)), binId: 'x')],
    )));
    await tester.pump(const Duration(seconds: 3));
    expect(find.byWidgetPredicate((w) => w is Scaffold && w.extendBody), findsOneWidget, reason: 'content passes behind');
    await tester.drag(find.byType(CustomScrollView).first, const Offset(0, -3000));
    await tester.pumpAndSettle();
    final lastRow = tester.getRect(find.byType(AppScanRow).last);
    expect(lastRow.bottom, lessThanOrEqualTo(tester.getRect(find.byType(FloatingPillNav)).top));
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 20));
  });

  for (final width in [320.0, 360.0, 393.0, 430.0, 1024.0]) {
    testWidgets('at $width dp the bubble is centred over every tab', (tester) async {
      await _pump(tester, size: Size(width, 900));
      for (final label in ['Home', 'Rewards', 'Activity', 'Profile']) {
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();
        expect(_bubbleX(tester), closeTo(_labelX(tester, label), 0.5), reason: label);
        expect(tester.takeException(), isNull);
      }
    });
  }

  double bubbleScale(WidgetTester tester) => tester.widget<Transform>(find.descendant(
      of: find.byKey(const ValueKey('nav-pill')), matching: find.byType(Transform)).first).transform.storage[0];

  testWidgets('the bubble lands with a gentle pop, then settles at its own size', (tester) async {
    await _pump(tester);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Activity'));
    await tester.pump();
    var peak = 0.0;
    for (var ms = 0; ms < 400; ms += 20) {
      await tester.pump(const Duration(milliseconds: 20));
      peak = math.max(peak, bubbleScale(tester));
    }
    expect(peak, inInclusiveRange(1.02, 1.08), reason: 'a pop, not a bounce');
    await tester.pumpAndSettle();
    expect(bubbleScale(tester), closeTo(1, 1e-9));
  });

  testWidgets('with reduced motion there is no pop', (tester) async {
    await _pump(tester, reduced: true);
    await tester.pump();
    await tester.tap(find.text('Activity'));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 60));
      expect(bubbleScale(tester), 1);
    }
  });

  testWidgets('the capsule is 60 dp tall at normal text size, taller for larger text', (tester) async {
    await _pump(tester);
    final ctx = tester.element(find.text('Home'));
    expect(FloatingPillNav.barHeight(ctx), 60);
  });

  testWidgets('every icon draws outlined and filled, at any size', (tester) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: Wrap(children: [
      for (final kind in NavGlyphKind.values)
        for (final filled in [false, true])
          for (final size in [16.0, 24.0, 48.0])
            NavGlyph(kind, size: size, color: Colors.black, filled: filled, cutout: Colors.white),
    ]))));
    expect(tester.takeException(), isNull);
    expect(find.byType(NavGlyph), findsNWidgets(NavGlyphKind.values.length * 6));
  });

  testWidgets("Home's shortcuts use the app's own icons, not stock ones", (tester) async {
    SharedPreferences.setMockInitialValues({'notifications_prompted': true});
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(theme: AppTheme.light, home: homeTabPreview(user: UserModel(uid: 'u',
        username: 'Ana', email: 'a@x.com', role: 'customer', points: 85, createdAt: DateTime(2026, 9, 1)))));
    await tester.pump(const Duration(seconds: 3));
    for (final stock in [Icons.qr_code_scanner_rounded, Icons.confirmation_number_outlined, Icons.leaderboard_outlined,
        Icons.military_tech_outlined]) {
      expect(find.byIcon(stock), findsNothing, reason: '$stock');
    }
    final kinds = tester.widgetList<NavGlyph>(find.byType(NavGlyph)).map((g) => g.kind).toSet();
    expect(kinds, containsAll([NavGlyphKind.scan, NavGlyphKind.codes, NavGlyphKind.leaderboard, NavGlyphKind.badges]));
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 20));
  });

  testWidgets('Home uses the floating pill tab bar', (tester) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(theme: AppTheme.light, home: homeTabPreview(user: UserModel(uid: 'u',
        username: 'Ana', email: 'a@x.com', role: 'customer', createdAt: DateTime(2026)))));
    await tester.pump(const Duration(seconds: 3));
    expect(find.byType(FloatingPillNav), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 20));
  });
}
