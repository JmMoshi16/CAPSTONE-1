// The staff console type floor (DESIGN_SYSTEM.md): no text below 11 sp. Screens migrated to AdminType are
// listed here; add each one as it moves off literal font sizes.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ecoreward_bin/core/admin_theme.dart';
import 'package:ecoreward_bin/core/app_theme.dart';
import 'package:ecoreward_bin/models/models.dart';
import 'package:ecoreward_bin/screens/admin/admin_users_screen.dart';

double? _size(InlineSpan span) => span.style?.fontSize;

void main() {
  test('the staff ramp never goes below 11 sp', () {
    for (final s in [AdminType.caption, AdminType.label, AdminType.body, AdminType.section, AdminType.input,
        AdminType.title, AdminType.stat, AdminType.heading]) {
      expect(s.fontSize, greaterThanOrEqualTo(11));
    }
  });

  testWidgets('admin users screen: every visible text is 11 sp or larger', (tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final users = [
      for (var i = 0; i < 4; i++)
        UserModel(uid: 'u$i', username: 'User $i', email: 'u$i@x.com', role: 'customer', points: 10 * i,
            lifetimePoints: 300 * i, createdAt: DateTime(2026)),
    ];
    await tester.pumpWidget(MaterialApp(theme: AppTheme.admin,
        home: Scaffold(body: AdminUsersScreen(customers: users, logs: const []))));
    await tester.pump(const Duration(seconds: 2));

    final tooSmall = <String>[];
    for (final rt in tester.widgetList<RichText>(find.byType(RichText))) {
      final size = _size(rt.text) ?? 14;
      if (size < 11) tooSmall.add('"${rt.text.toPlainText()}" at $size');
    }
    expect(tooSmall, isEmpty);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  });
}
