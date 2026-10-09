// Layout smoke tests: every main screen at 360x640, 393x852 and a 800x1280 tablet, with
// text at 1.0x and 1.3x, in light and dark (admin: dark only). A RenderFlex overflow or any
// other exception fails the test. No Firebase: screens that load data show their error state.
//
// Real Roboto metrics are loaded from the Flutter SDK so text widths match a phone; without
// them the test font's square glyphs would report overflows that never happen on a device.

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ecoreward_bin/core/app_theme.dart';
import 'package:ecoreward_bin/models/models.dart';
import 'package:ecoreward_bin/screens/admin/admin_dashboard_screen.dart';
import 'package:ecoreward_bin/screens/admin/admin_qr_screen.dart';
import 'package:ecoreward_bin/screens/admin/admin_rewards_screen.dart';
import 'package:ecoreward_bin/screens/admin/admin_users_screen.dart';
import 'package:ecoreward_bin/screens/customer/badges_screen.dart';
import 'package:ecoreward_bin/screens/customer/customer_home_screen.dart';
import 'package:ecoreward_bin/screens/customer/customer_profile_screen.dart';
import 'package:ecoreward_bin/screens/customer/impact_screen.dart';
import 'package:ecoreward_bin/screens/customer/leaderboard_screen.dart';
import 'package:ecoreward_bin/screens/customer/qr_scanner_screen.dart';
import 'package:ecoreward_bin/screens/customer/rewards_screen.dart';
import 'package:ecoreward_bin/screens/customer/reward_detail_screen.dart';
import 'package:ecoreward_bin/screens/customer/scan_history_screen.dart';
import 'package:ecoreward_bin/screens/login_screen.dart';
import 'package:ecoreward_bin/screens/register_screen.dart';
import 'package:ecoreward_bin/screens/splash_screen.dart';

/// The app's own bundled fonts (DM Sans body, Fraunces headings): measure with what ships.
Future<void> _loadAppFonts() async {
  Future<ByteData> read(String f) async => ByteData.view(File('assets/fonts/$f').readAsBytesSync().buffer);
  final body = FontLoader('DMSans');
  for (final w in [400, 500, 600, 700]) { body.addFont(read('DMSans-$w.ttf')); }
  await body.load();
  final display = FontLoader('Fraunces');
  for (final w in [600, 700, 800]) { display.addFont(read('Fraunces-$w.ttf')); }
  await display.load();
}

Future<void> _loadRealFonts() async {
  // flutter_tester lives in <flutter>/bin/cache/artifacts/engine/<platform>/.
  final artifacts = File(Platform.resolvedExecutable).parent.parent.parent;
  final dir = Directory('${artifacts.path}${Platform.pathSeparator}material_fonts');
  if (!dir.existsSync()) {
    // ignore: avoid_print
    print('Roboto not found under ${dir.path}; using the test font (stricter widths).');
    return;
  }
  Future<ByteData> read(String f) async =>
      ByteData.view(File('${dir.path}${Platform.pathSeparator}$f').readAsBytesSync().buffer);
  final roboto = FontLoader('Roboto');
  for (final f in ['roboto-regular.ttf', 'roboto-medium.ttf', 'roboto-bold.ttf', 'roboto-black.ttf']) {
    roboto.addFont(read(f));
  }
  await roboto.load();
  await (FontLoader('MaterialIcons')..addFont(read('materialicons-regular.otf'))).load();
}

// ── Sample data ───────────────────────────────────────────────────────────────
final _now = DateTime.now();
final _user = UserModel(
  uid: 'u1', username: 'Maria Clara Santos', email: 'maria.clara.santos@example.com', role: 'customer',
  points: 1240, lifetimePoints: 1385, createdAt: DateTime(2026, 3, 1), scanCount: 57, streak: 8,
  lastScanDate: '${_now.year}-${_now.month.toString().padLeft(2, '0')}-${_now.day.toString().padLeft(2, '0')}',
  badges: const ['first_scan', 'eco_starter', 'streak_3', 'streak_7'],
);
final _newUser = UserModel(uid: 'u2', username: 'Al', email: 'al@x.co', role: 'customer', createdAt: _now);
final _logs = [
  for (var i = 0; i < 12; i++)
    WasteLog(
      userId: 'u1',
      wasteType: ['Biodegradable', 'Recyclable', 'Residual'][i % 3],
      pointsEarned: [15, 10, 5][i % 3],
      pointsAwarded: [23, 15, 8][i % 3],
      timestamp: _now.subtract(Duration(hours: i * 7)),
      binId: 'abcd1234',
    ),
];
final _rewards = [
  Reward(id: 'r1', title: 'Free Iced Caramel Macchiato (Large)', description: 'Any large iced drink from the menu, one per visit', pointsCost: 500, category: 'Coffee', stock: 3),
  Reward(id: 'r2', title: 'Pastry', description: 'Croissant or muffin', pointsCost: 2000, category: 'Food'),
  Reward(id: 'r3', title: '10% off', description: 'Whole order discount', pointsCost: 300, category: 'Discount', stock: 0),
  Reward(id: 'r4', title: 'Tumbler', description: 'Reusable cup', pointsCost: 1200, category: 'Other'),
];
final _redemptions = [
  Redemption(id: 'x1', userId: 'u1', rewardId: 'r1', rewardTitle: 'Free Iced Caramel Macchiato (Large)', pointsUsed: 500,
      redeemedAt: _now.subtract(const Duration(days: 1)), redemptionCode: 'AB12CD34', userEmail: 'maria.clara.santos@example.com'),
  Redemption(id: 'x2', userId: 'u1', rewardId: 'r3', rewardTitle: '10% off', pointsUsed: 300,
      redeemedAt: _now.subtract(const Duration(days: 9)), redemptionCode: 'ZZ99YY88'),
];
final _customers = [
  for (var i = 0; i < 8; i++)
    UserModel(uid: 'c$i', username: i == 0 ? 'Bartholomew Alexander' : 'user$i', email: 'user$i@example.com',
        role: 'customer', points: 900 - i * 100, createdAt: _now),
];

// ── Screens under test ────────────────────────────────────────────────────────
final Map<String, Widget Function()> _customerScreens = {
  'Launch screen': () => const BrandSplash(),
  'Login': () => const LoginScreen(),
  'Register': () => const RegisterScreen(),
  'Home': () => homeTabPreview(user: _user, logs: _logs, rewards: _rewards, redemptions: _redemptions, myRank: 3),
  'Home (new user, offline)': () => homeTabPreview(user: _newUser, offline: true),
  'Rewards': () => RewardsScreen(user: _user, rewards: _rewards, onRedeemed: () {}),
  'Impact': () => ImpactScreen(logs: _logs),
  'Impact (empty)': () => ImpactScreen(logs: const [], onScan: () {}),
  'Scan History': () => ScanHistoryScreen(logs: _logs),
  'Scan History (empty)': () => ScanHistoryScreen(logs: const [], onScan: () {}),
  'Leaderboard (offline)': () => const LeaderboardScreen(currentUid: 'u1'),
  'Badges': () => BadgesScreen(user: _user),
  'Profile': () => CustomerProfileScreen(user: _user, logs: _logs, onUpdated: () {}),
  'Success': () => successScreenPreview(),
  'Success (badges + rank-up)': () =>
      successScreenPreview(points: 23, basePoints: 15, newBadges: ['first_scan', 'streak_7'], lifetimeBefore: 190),
  'Staff code': () => StaffCodeScreen(redemption: _redemptions.first),
  'Reward detail (can redeem)': () => RewardDetailScreen(reward: _rewards[0], user: _user, heroTag: 't1',
      icon: Icons.coffee_rounded, color: const Color(0xFF795548)),
  'Reward detail (locked)': () => RewardDetailScreen(reward: _rewards[1], user: _user, heroTag: 't2',
      icon: Icons.fastfood_rounded, color: const Color(0xFFFF7043)),
};

final Map<String, Widget Function()> _adminScreens = {
  'Admin dashboard': () => dashboardTabPreview(logs: _logs, customers: _customers),
  'Admin rewards': () => AdminRewardsScreen(rewards: _rewards, onChanged: () {}),
  'Admin users': () => AdminUsersScreen(customers: _customers, logs: _logs),
  'Admin QR': () => const AdminQRScreen(),
};

const _sizes = {'360x640': Size(360, 640), '393x852': Size(393, 852), 'tablet': Size(800, 1280)};
const _scales = [1.0, 1.3];

Future<void> _render(WidgetTester tester, Widget screen, Size size, double scale, ThemeData theme) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    theme: theme,
    builder: (ctx, child) =>
        MediaQuery(data: MediaQuery.of(ctx).copyWith(textScaler: TextScaler.linear(scale)), child: child!),
    home: screen,
  ));
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(seconds: 3));   // entrances, count-ups, data timeouts
  // Any overflow or exception reported during the pumps fails the test with full details.
  // Dispose and let delayed callbacks run so no timer is left pending.
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 20));
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({'notifications_prompted': true});
    await _loadRealFonts();   // Roboto: fallback glyphs and MaterialIcons
    await _loadAppFonts();
  });

  for (final s in _customerScreens.entries) {
    for (final size in _sizes.entries) {
      for (final scale in _scales) {
        for (final dark in [false, true]) {
          testWidgets('${s.key} @ ${size.key}, text ${scale}x, ${dark ? 'dark' : 'light'}', (tester) async {
            await _render(tester, s.value(), size.value, scale, dark ? AppTheme.dark : AppTheme.light);
          });
        }
      }
    }
  }
  for (final s in _adminScreens.entries) {
    for (final size in _sizes.entries) {
      for (final scale in _scales) {
        testWidgets('${s.key} @ ${size.key}, text ${scale}x', (tester) async {
          await _render(tester, s.value(), size.value, scale, AppTheme.admin);
        });
      }
    }
  }
}
