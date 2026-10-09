// WCAG AA contrast for the design tokens: 4.5:1 for text, so a palette change cannot
// silently make text unreadable.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ecoreward_bin/core/admin_theme.dart';
import 'package:ecoreward_bin/core/theme.dart';
import 'package:ecoreward_bin/core/tokens.dart';

double contrast(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  final hi = la > lb ? la : lb, lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

void expectAA(Color fg, Color bg, String what) =>
    expect(contrast(fg, bg), greaterThanOrEqualTo(4.5), reason: '$what is ${contrast(fg, bg).toStringAsFixed(2)}:1');

void main() {
  for (final c in [AppColors.light, AppColors.dark]) {
    final mode = c.isDark ? 'dark' : 'light';
    test('$mode text colours on surfaces', () {
      for (final bg in {'surface': c.surface, 'background': c.background}.entries) {
        expectAA(c.textPrimary, bg.value, '$mode textPrimary on ${bg.key}');
        expectAA(c.textSecondary, bg.value, '$mode textSecondary on ${bg.key}');
        expectAA(c.textTertiary, bg.value, '$mode textTertiary on ${bg.key}');
        expectAA(c.primary, bg.value, '$mode primary on ${bg.key}');
      }
      for (final s in {'success': c.success, 'warning': c.warning, 'danger': c.danger, 'gold': c.gold, 'info': c.info}.entries) {
        expectAA(s.value, c.surface, '$mode ${s.key} on surface');
      }
      expectAA(c.onPrimary, c.primary, '$mode onPrimary on primary');
      expectAA(c.onPrimaryContainer, c.primaryContainer, '$mode onPrimaryContainer on primaryContainer');
    });

    test('$mode header text on every gradient stop', () {
      for (final stop in c.hero) {
        expectAA(c.onHero, stop, '$mode onHero');
        expectAA(c.heroAccent, stop, '$mode heroAccent');
      }
    });

    test('$mode white text on waste fills', () {
      for (final fill in [c.bioFill, c.recFill, c.resFill]) {
        expectAA(Colors.white, fill, '$mode white on waste fill');
      }
    });

    test('$mode ink() makes rank and level colours readable', () {
      final colours = [
        for (final p in [0, 60, 250, 600]) getRank(p).color,
        for (final p in [0, 120, 300, 600, 1200, 2500]) getLevel(p).color,
      ];
      for (final col in colours) {
        expectAA(c.ink(col), c.surface, '$mode ink($col)');
      }
    });
  }

  test('admin text colours', () {
    for (final bg in {'card': AdminColors.card, 'background': AdminColors.background}.entries) {
      for (final fg in {
        'textPrimary': AdminColors.textPrimary,
        'textSecondary': AdminColors.textSecondary,
        'textTertiary': AdminColors.textTertiary,
        'accent': AdminColors.accent,
        'blue': AdminColors.blue,
        'purple': AdminColors.purple,
        'orange': AdminColors.orange,
        'danger': AdminColors.danger,
        'gold': AdminColors.gold,
      }.entries) {
        expectAA(fg.value, bg.value, 'admin ${fg.key} on ${bg.key}');
      }
    }
    expectAA(AdminColors.onAccent, AdminColors.accent, 'admin onAccent on accent');
    expectAA(Colors.white, AdminColors.dangerFill, 'white on admin dangerFill');
  });
}
