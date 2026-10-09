import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'services/firebase_service.dart';
import 'services/notification_service.dart';
import 'models/models.dart';
import 'screens/login_screen.dart';
import 'screens/customer/customer_home_screen.dart';
import 'screens/admin/admin_dashboard_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  FirebaseService.init();
  // Login/register/scanner layouts are sized from screen height; landscape was never designed (audit M-14).
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));
  runApp(const ECORewardApp());

  // Run non-critical tasks in the background AFTER the app is visible
  FirebaseService.seedRewardsIfEmpty();
  NotificationService.init();
}

class ECORewardApp extends StatelessWidget {
  const ECORewardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ECOReward Bin',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Roboto',
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4CAF50),
          primary: const Color(0xFF4CAF50),
        ),
      ),
      home: const _AuthGate(),
    );
  }
}

/// Reuses Firebase's persisted session instead of asking for a login on every launch (audit M-13).
class _AuthGate extends StatelessWidget {
  const _AuthGate();

  Future<UserModel?> _restore() async {
    if (FirebaseService.currentUid == null) return null;
    try {
      return await FirebaseService.getCurrentUser().timeout(const Duration(seconds: 8));
    } catch (_) {
      return null;   // unreachable / no profile: fall back to the login screen
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<UserModel?>(
        future: _restore(),
        builder: (_, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Scaffold(
              backgroundColor: Color(0xFF0A2E0C),
              body: Center(child: CircularProgressIndicator(color: Color(0xFF66BB6A))),
            );
          }
          final user = snap.data;
          if (user == null) return const LoginScreen();
          return user.role == 'admin' ? const AdminDashboardScreen() : const CustomerHomeScreen();
        },
      );
}
