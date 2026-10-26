import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings();
    await _plugin.initialize(const InitializationSettings(android: android, iOS: ios));
    // The Android 13+ permission is no longer asked at startup: the app asks after the first
    // successful scan, with an explanation first (see widgets/notification_prompt.dart).
    _initialized = true;
  }

  static AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

  /// Whether notifications can be shown (true on platforms without a runtime permission).
  static Future<bool> enabled() async {
    try {
      return await _android?.areNotificationsEnabled() ?? true;
    } catch (_) {
      return true;
    }
  }

  /// Shows the system permission dialog on Android 13+; a no-op elsewhere.
  static Future<void> requestPermission() async {
    try {
      await _android?.requestNotificationsPermission();
    } catch (_) {
      // Not available on this platform/version: nothing to ask.
    }
  }

  static Future<void> showPointsCredited({
    required String wasteType,
    required int points,
    int? basePoints,
    double multiplier = 1.0,
  }) async {
    // Display only: explain a streak bonus as "15 × 1.5" next to the credited total.
    final bonus = multiplier > 1.0 && basePoints != null
        ? ' ($basePoints × ${multiplier == multiplier.roundToDouble() ? multiplier.toStringAsFixed(0) : multiplier} streak bonus)'
        : '';
    await _plugin.show(
      1, // one scan-points notification at a time is fine
      'Points credited',
      'You earned +$points pts$bonus for $wasteType waste. Keep it up!',
      _details(),
    );
  }

  static Future<void> showBadgeUnlocked(String badgeLabel) async {
    // Use a unique ID per badge so multiple unlocks don't overwrite each other
    final id = 100 + badgeLabel.hashCode.abs() % 900;
    await _plugin.show(
      id,
      'Badge unlocked',
      '$badgeLabel — nice work.',
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
