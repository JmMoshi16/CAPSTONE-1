// Phase 2 of the UI/UX transformation: the shared design-system pieces every screen now uses
// (dates, scan rows, dialogs, type roles, codes, headers). One behaviour per test.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ecoreward_bin/core/app_theme.dart';
import 'package:ecoreward_bin/models/models.dart';
import 'package:ecoreward_bin/widgets/ui.dart';

import 'support/fonts.dart';

Widget _app(Widget child, {ThemeData? theme}) =>
    MaterialApp(theme: theme ?? AppTheme.light, home: Scaffold(body: child));

void main() {
  setUpAll(() async {
    await loadRealFonts();
    await loadAppFonts();
  });

  group('AppDates: one way to write a date', () {
    final now = DateTime(2026, 10, 20, 15, 0);
    test('a moment today, yesterday, this year and another year', () {
      expect(AppDates.moment(DateTime(2026, 10, 20, 9, 5), now: now), 'Today, 9:05 AM');
      expect(AppDates.moment(DateTime(2026, 10, 19, 21, 30), now: now), 'Yesterday, 9:30 PM');
      expect(AppDates.moment(DateTime(2026, 3, 4, 8, 0), now: now), 'Mar 4, 8:00 AM');
      expect(AppDates.moment(DateTime(2025, 12, 31, 23, 59), now: now), 'Dec 31, 2025, 11:59 PM');
    });
    test('a day label for headers', () {
      expect(AppDates.dayLabel(DateTime(2026, 10, 20, 1), now: now), 'Today');
      expect(AppDates.dayLabel(DateTime(2026, 10, 19), now: now), 'Yesterday');
      expect(AppDates.dayLabel(DateTime(2026, 10, 12), now: now), 'Mon, Oct 12');
      expect(AppDates.dayLabel(DateTime(2025, 10, 12), now: now), 'Sun, Oct 12, 2025');
    });
    test('plain formats', () {
      final d = DateTime(2026, 7, 9, 14, 3);
      expect(AppDates.day(d), 'Jul 9');
      expect(AppDates.dayYear(d), 'Jul 9, 2026');
      expect(AppDates.monthYear(d), 'Jul 2026');
      expect(AppDates.time(d), '2:03 PM');
      expect(AppDates.full(d), 'Thursday, Jul 9, 2026 at 2:03 PM');
    });
  });

  group('AppScanRow: one scan row everywhere', () {
    final log = WasteLog(userId: 'u', wasteType: 'Recyclable', pointsEarned: 10, timestamp: DateTime(2026, 3, 4, 8),
        binId: 'abcd1234');
    for (final grouped in [false, true]) {
      testWidgets('shows type, time and points, and opens details (grouped: $grouped)', (tester) async {
        var opened = 0;
        await tester.pumpWidget(_app(AppScanRow(log: log, grouped: grouped, onTap: () => opened++)));
        expect(find.text('Recyclable'), findsOneWidget);
        expect(find.textContaining('Mar 4'), findsOneWidget);
        expect(find.text('+10 pts'), findsOneWidget);
        await tester.tap(find.byType(AppScanRow));
        expect(opened, 1);
        expect(tester.getSemantics(find.byType(AppScanRow)).label, contains('Recyclable scan, +10 points'));
      });
    }
  });

  group('AppDialog', () {
    testWidgets('confirm returns true, cancel false, tapping outside null', (tester) async {
      final results = <bool?>[];
      await tester.pumpWidget(_app(Builder(builder: (ctx) => TextButton(
          onPressed: () async => results.add(await showAppDialog(ctx,
              title: 'Sign out?', message: 'You can sign in again any time.', confirmLabel: 'Sign out',
              destructive: true)),
          child: const Text('open')))));
      for (final action in ['Sign out', 'Cancel', null]) {
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
        expect(find.text('Sign out?'), findsOneWidget);
        if (action == null) {
          await tester.tapAt(const Offset(4, 4));
        } else {
          await tester.tap(find.widgetWithText(AppButton, action));
        }
        await tester.pumpAndSettle();
      }
      expect(results, [true, false, null]);
    });

    testWidgets('a destructive confirm uses the danger colour of the current theme', (tester) async {
      for (final theme in [AppTheme.light, AppTheme.dark]) {
        await tester.pumpWidget(_app(Builder(builder: (ctx) => TextButton(
            onPressed: () => showAppDialog(ctx, title: 'Delete?', confirmLabel: 'Delete', destructive: true),
            child: const Text('open'))), theme: theme));
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
        final colors = tester.element(find.text('Delete?')).colors;
        final style = tester.widget<FilledButton>(find.descendant(of: find.widgetWithText(AppButton, 'Delete'),
            matching: find.byType(FilledButton))).style!;
        expect(style.backgroundColor!.resolve({}), colors.danger, reason: '${theme.brightness}');
        await tester.tapAt(const Offset(4, 4));
        await tester.pumpAndSettle();
      }
    });
  });

  group('Type roles', () {
    testWidgets('every role is defined and numerals line up (tabular figures)', (tester) async {
      await tester.pumpWidget(_app(const SizedBox()));
      final t = Theme.of(tester.element(find.byType(SizedBox))).textTheme;
      for (final s in [t.displayLarge, t.displayMedium, t.displaySmall, t.headlineMedium, t.headlineSmall,
        t.titleLarge, t.titleMedium, t.titleSmall, t.bodyLarge, t.bodyMedium, t.bodySmall, t.labelLarge,
        t.labelMedium, t.labelSmall]) {
        expect(s?.fontSize, isNotNull);
        expect(s!.fontSize, greaterThanOrEqualTo(11));
      }
      expect(t.displayMedium!.fontFamily, AppType.displayFamily);
      expect(AppType.numeral.fontFeatures, contains(const FontFeature.tabularFigures()));
      expect(AppType.code.fontFeatures, contains(const FontFeature.tabularFigures()));
      expect(AppType.code.fontFamily, isNot('monospace'), reason: 'monospace is not bundled; iOS falls back');
    });
  });

  group('Headers and back', () {
    testWidgets('AppBackButton is a labelled 48 dp target that pops', (tester) async {
      await tester.pumpWidget(MaterialApp(theme: AppTheme.light, home: Builder(builder: (ctx) => TextButton(
          onPressed: () => Navigator.push(ctx, MaterialPageRoute(builder: (_) => const Scaffold(
              body: Center(child: AppBackButton())))),
          child: const Text('open')))));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byType(AppBackButton)).width, greaterThanOrEqualTo(48));
      expect(find.byTooltip('Back'), findsOneWidget);
      await tester.tap(find.byType(AppBackButton));
      await tester.pumpAndSettle();
      expect(find.text('open'), findsOneWidget);
    });

    testWidgets('AppHeader shows its title and keeps it when collapsed', (tester) async {
      await tester.pumpWidget(MaterialApp(theme: AppTheme.light, home: const Scaffold(body: CustomScrollView(slivers: [
        AppSliverHeader(title: 'Scan History'),
        SliverToBoxAdapter(child: SizedBox(height: 2000)),
      ]))));
      expect(find.text('Scan History'), findsWidgets);
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -600));
      await tester.pumpAndSettle();
      expect(find.text('Scan History').hitTestable(), findsOneWidget, reason: 'the collapsed bar names the page');
    });
  });
}
