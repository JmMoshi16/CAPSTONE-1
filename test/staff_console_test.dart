// Phase 6 of the UI/UX transformation: the staff console in ECOReward's own design language.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ecoreward_bin/core/admin_theme.dart';
import 'package:ecoreward_bin/core/app_theme.dart';
import 'package:ecoreward_bin/models/models.dart';
import 'package:ecoreward_bin/screens/admin/admin_dashboard_screen.dart' show dashboardTabPreview;
import 'package:ecoreward_bin/widgets/ui.dart';

import 'support/fonts.dart';

void main() {
  setUpAll(() async {
    await loadRealFonts();
    await loadAppFonts();
  });

  test('staff and customers see the same bin colours; residual is never red', () {
    expect(AdminColors.bio, AppColors.dark.bio);
    expect(AdminColors.rec, AppColors.dark.rec);
    expect(AdminColors.res, AppColors.dark.res);
    expect(HSLColor.fromColor(AdminColors.res).saturation, lessThan(0.2), reason: 'charcoal, not red');
  });

  test('the staff accent is the brand mint, not a separate neon green', () {
    expect(AdminColors.accent, AppPalette.sun);
  });

  testWidgets('the forecast is explained in plain words', (tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final now = DateTime.now();
    await tester.pumpWidget(MaterialApp(theme: AppTheme.admin, home: dashboardTabPreview(
      logs: [for (var i = 0; i < 7; i++) WasteLog(userId: 'u', wasteType: 'Recyclable', pointsEarned: 10,
          timestamp: now.subtract(Duration(days: i)), binId: 'x')],
      customers: [UserModel(uid: 'u', username: 'Ana', email: 'a@x.com', role: 'customer', createdAt: DateTime(2026))],
    )));
    await tester.pump(const Duration(seconds: 3));
    expect(find.textContaining('Regression', skipOffstage: false), findsNothing);
    expect(find.textContaining('next 3 days expected', skipOffstage: false), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  });
}
