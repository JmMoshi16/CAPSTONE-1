// Impact numbers must be verifiable (PROJECT_DEEP_AUDIT.md U, 2026-10-15): counts of scanned items only,
// no CO₂ or weight figures until items are weighed per scan.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ecoreward_bin/core/app_theme.dart';
import 'package:ecoreward_bin/models/models.dart';
import 'package:ecoreward_bin/screens/customer/customer_home_screen.dart';
import 'package:ecoreward_bin/screens/customer/impact_screen.dart';

final _now = DateTime.now();
WasteLog _log(String type) =>
    WasteLog(userId: 'u', wasteType: type, pointsEarned: 10, timestamp: _now, binId: 'b');
final _logs = [
  for (var i = 0; i < 3; i++) _log('Recyclable'),
  for (var i = 0; i < 2; i++) _log('Biodegradable'),
  _log('Residual'),
];

Future<void> _pump(WidgetTester tester, Widget w) async {
  tester.view.physicalSize = const Size(800, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(theme: AppTheme.light, home: w));
  await tester.pump(const Duration(seconds: 3));
}

Future<void> _done(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 20));
}

void _noUnsupportedFigures() {
  expect(find.textContaining('CO₂ you', skipOffstage: false), findsNothing);
  expect(find.textContaining(RegExp(r'\d\s?kg'), skipOffstage: false), findsNothing);
  expect(find.textContaining('phone charges', skipOffstage: false), findsNothing);
}

void main() {
  setUpAll(() => SharedPreferences.setMockInitialValues({'notifications_prompted': true}));

  testWidgets('Impact screen: counts of scanned items, no CO₂ estimate', (tester) async {
    await _pump(tester, ImpactScreen(logs: _logs));
    expect(find.text('5 of 6 items you scanned', skipOffstage: false), findsOneWidget);
    _noUnsupportedFigures();
    await _done(tester);
  });

  testWidgets('Home "Your impact" tile uses the same count', (tester) async {
    final user = UserModel(uid: 'u', username: 'Ana', email: 'a@x.com', role: 'customer', points: 60,
        createdAt: DateTime(2026));
    await _pump(tester, homeTabPreview(user: user, logs: _logs));
    expect(find.text('5 recyclable or compostable', skipOffstage: false), findsOneWidget);
    _noUnsupportedFigures();
    await _done(tester);
  });
}
