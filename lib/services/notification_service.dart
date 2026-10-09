import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings();
    await _plugin.initialize(const InitializationSettings(android: android, iOS: ios));
    // Android 13+ silently drops notifications unless the user grants this at runtime (audit M-13).
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    _initialized = true;
  }

  static Future<void> showPointsCredited({
    required String wasteType,
    required int points,
  }) async {
    await _plugin.show(
      1, // one scan-points notification at a time is fine
      '♻️ Points Credited!',
      'You earned +$points pts for $wasteType waste. Keep it up!',
      _details(),
    );
  }

  static Future<void> showBadgeUnlocked(String badgeIcon, String badgeLabel) async {
    // Use a unique ID per badge so multiple unlocks don't overwrite each other
    final id = 100 + badgeLabel.hashCode.abs() % 900;
    await _plugin.show(
      id,
      '🏅 Badge Unlocked!',
      '$badgeIcon $badgeLabel — Great work, eco warrior!',
      _details(),
    );
  }

  static NotificationDetails _details() => const NotificationDetails(
        android: AndroidNotificationDetails(
          'ecoreward_channel',
          'ECOReward Notifications',
          channelDescription: 'Points and badge updates',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(),
      );
}
