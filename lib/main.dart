import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'core/app_theme.dart';
import 'firebase_ios_options.dart';
import 'widgets/ui.dart';
import 'services/firebase_service.dart';
import 'services/notification_service.dart';
import 'services/sound_service.dart';
import 'services/appearance.dart';
import 'models/models.dart';
import 'screens/login_screen.dart';
import 'screens/splash_screen.dart';
import 'widgets/eco_animations.dart';
import 'screens/customer/customer_home_screen.dart';
import 'screens/admin/admin_dashboard_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // iPhone has no google-services.json: it gets its settings in code. Android is unchanged.
  await Firebase.initializeApp(options: defaultTargetPlatform == TargetPlatform.iOS ? iosFirebaseOptions : null);
  FirebaseService.init();
  // Login/register/scanner layouts are sized from screen height; landscape was never designed (audit M-14).
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));
  await Appearance.load();   // a few ms; avoids a light-to-dark flash at launch
  runApp(const ECORewardApp());

  // Run non-critical tasks in the background AFTER the app is visible
  FirebaseService.seedRewardsIfEmpty();
  NotificationService.init();
  AppSounds.load().ignore();          // reads the Profile sound switch
  EcoAnimations.precache().ignore();   // first loader/success animation shows instantly; failure is harmless
}

class ECORewardApp extends StatelessWidget {
  const ECORewardApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Customer screens follow Profile > Appearance (default: the phone's setting); admin screens are always dark.
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: Appearance.mode,
      builder: (_, mode, __) => MaterialApp(
        title: 'ECOReward Bin',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: mode,
        // Auth gate: a still launch screen while the saved session is checked, then home or login.
        home: const _AuthGate(),
      ),
    );
  }
}

/// Reuses Firebase's persisted session instead of asking for a login on every launch (audit M-13),
/// routing by role. If a session exists but the profile cannot be loaded (offline, timeout), the
/// user gets Retry instead of being dropped to the login screen.
class _AuthGate extends StatefulWidget {
  const _AuthGate();
  @override
  State<_AuthGate> createState() => _AuthGateState();
}

enum _Restore { signedOut, ready, unreachable }

class _AuthGateState extends State<_AuthGate> {
  // Created once (a FutureBuilder future built inline would re-fetch on every rebuild).
  late Future<(_Restore, UserModel?)> _future = _restore();

  Future<(_Restore, UserModel?)> _restore() async {
    if (FirebaseService.currentUid == null) return (_Restore.signedOut, null);
    try {
      final user = await FirebaseService.getCurrentUser().timeout(const Duration(seconds: 8));
      // Signed in but no profile document: treat as signed out.
      return user == null ? (_Restore.signedOut, null) : (_Restore.ready, user);
    } catch (_) {
      return (_Restore.unreachable, null);
    }
  }

  void _retry() => setState(() => _future = _restore());

  Future<void> _useAnotherAccount() async {
    await FirebaseService.logout();
    _retry();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<(_Restore, UserModel?)>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            // The still launch screen, shown only while the saved sign-in is checked.
            return const BrandSplash();
          }
          final (state, user) = snap.data ?? (_Restore.unreachable, null);
          switch (state) {
            case _Restore.signedOut:
              return const LoginScreen();
            case _Restore.ready:
              return user!.role == 'admin' ? const AdminDashboardScreen() : const CustomerHomeScreen();
            case _Restore.unreachable:
              return Scaffold(
                body: SafeArea(
                  child: Column(children: [
                    Expanded(
                      child: ErrorState(
                        title: "Couldn't reach ECOReward",
                        message: "You're still signed in. Check your connection and try again.",
                        onRetry: _retry,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpace.lg),
                      child: TextButton(onPressed: _useAnotherAccount, child: const Text('Sign in with another account')),
                    ),
                  ]),
                ),
              );
          }
        },
      );
}
