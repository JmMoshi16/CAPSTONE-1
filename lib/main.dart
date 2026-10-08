import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'services/firebase_service.dart';
import 'services/notification_service.dart';
import 'screens/login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  FirebaseService.init();
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
      home: const LoginScreen(),
    );
  }
}
