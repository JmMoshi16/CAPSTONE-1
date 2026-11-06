// Screenshot tests for the key surfaces of the redesign. Skipped by default (see dart_test.yaml):
// run `flutter test --tags golden --run-skipped` on the Windows dev PC that made the images.
// Only surfaces that do not depend on the clock: Home's greeting, "Today" and the 7-day count change with the
// time of day, so Home is covered piece by piece (the glass balance pane, scan rows dated in 2024).
@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ecoreward_bin/core/app_theme.dart';
import 'package:ecoreward_bin/models/models.dart';
import 'package:ecoreward_bin/screens/customer/rewards_screen.dart';
import 'package:ecoreward_bin/widgets/ui.dart';

import 'support/fonts.dart';

final _user = UserModel(uid: 'u', username: 'Maria Santos', email: 'm@x.com', role: 'customer', points: 1240,
    lifetimePoints: 1385, createdAt: DateTime(2026, 3, 1));
final _rewards = [
  Reward(id: '1', title: 'Iced Latte', description: 'Any size', pointsCost: 900, category: 'Coffee'),
  Reward(id: '2', title: 'Croissant', description: 'Butter', pointsCost: 600, category: 'Food'),
  Reward(id: '3', title: '10% off', description: 'Any order', pointsCost: 1500, category: 'Discount'),
];
// A past year, so the rows read the same whatever today's date is ("Mar 4, 2024, 9:00 AM").
final _logs = [
  for (var i = 0; i < 3; i++)
    WasteLog(userId: 'u', wasteType: ['Recyclable', 'Biodegradable', 'Residual'][i], pointsEarned: 10,
        timestamp: DateTime(2024, 3, 4 + i, 9), binId: 'x'),
];

Future<void> _golden(WidgetTester tester, String name, Widget screen, ThemeData theme,
    {Size size = const Size(393, 852)}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(debugShowCheckedModeBanner: false, theme: theme, home: screen));
  // Images (photos, the Crave logo) decode off the fake clock: give them real time, or a capture may miss them.
  for (var i = 0; i < 6; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 150)));
    await tester.pump(const Duration(seconds: 5));   // past every entrance and the hero's drift
  }
  await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/$name.png'));
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 20));
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({'notifications_prompted': true});
    await loadRealFonts();
    await loadAppFonts();
  });

  for (final (name, theme) in [('light', AppTheme.light), ('dark', AppTheme.dark)]) {
    testWidgets('scan rows $name', (t) => _golden(t, 'scan_rows_$name', Scaffold(body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [for (final l in _logs) AppScanRow(log: l, onTap: () {})]))), theme,
        size: const Size(393, 300)));
    testWidgets('rewards $name', (t) => _golden(t, 'rewards_$name',
        RewardsScreen(user: _user, rewards: _rewards, onRedeemed: () {}), theme));
  }
  testWidgets('glass balance pane', (t) => _golden(t, 'glass_pane', const Scaffold(body: AuroraBackground(
      child: Padding(
        padding: EdgeInsets.all(20),
        child: AppSurface(depth: Depth.floating, onHero: true, padding: EdgeInsets.all(20), child: Row(children: [
          Expanded(child: Text('1,240 pts', style: TextStyle(color: AppPalette.cream, fontSize: 40))),
          EcoCoin(size: 60),
        ])),
      ))), AppTheme.light, size: const Size(393, 220)));
  // Café photos: the menu grid (ready and saving) and the Home card's glass at empty, half and full. Photos decode
  // off the fake clock, so they get real time to load before the capture.
  testWidgets('reward photos', (tester) async {
    tester.view.physicalSize = const Size(393, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final menu = [
      Reward(id: 'a', title: 'Matcha Dream', description: 'Iced, coffee-free', pointsCost: 125, category: 'Coffee'),
      Reward(id: 'b', title: 'Mocha', description: 'Iced coffee', pointsCost: 135, category: 'Coffee'),
      Reward(id: 'c', title: 'The OG Burger', description: 'Quarter pounder', pointsCost: 150, category: 'Food'),
      Reward(id: 'd', title: 'Classic', description: 'Iced coffee', pointsCost: 120, category: 'Coffee'),
    ];
    await tester.pumpWidget(MaterialApp(debugShowCheckedModeBanner: false, theme: AppTheme.light, home: Scaffold(
      body: Column(children: [
        SizedBox(height: 150, child: Row(children: [
          for (final level in [0.0, 0.5, 1.0])
            Expanded(child: Padding(
              padding: const EdgeInsets.all(8),
              child: ClipRRect(borderRadius: BorderRadius.circular(16),
                  child: RewardFill(title: 'Sunrise', category: 'Coffee', level: level)),
            )),
        ])),
        Expanded(child: RewardsScreen(user: UserModel(uid: 'u', username: 'A', email: 'a@x.com', role: 'customer',
            points: 130, createdAt: DateTime(2026, 3, 1)), rewards: menu, onRedeemed: () {})),
      ]),
    )));
    for (var i = 0; i < 10; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 150)));
      await tester.pump(const Duration(seconds: 3));
    }
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/reward_photos.png'));
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 20));
  });
  testWidgets('signature coin', (t) => _golden(t, 'coin',
      const Scaffold(body: Center(child: EcoCoin(size: 160))), AppTheme.light, size: const Size(240, 240)));
}
