import 'package:flutter/services.dart';

/// One place for haptic feedback so every screen feels the same:
/// tap = any press, primary = main actions, success / error = results.
class AppHaptics {
  static void tap() => HapticFeedback.selectionClick();
  static void primary() => HapticFeedback.lightImpact();
  static void success() => HapticFeedback.mediumImpact();

  /// Two heavy pulses: noticeably different from success.
  static void error() {
    HapticFeedback.heavyImpact();
    Future.delayed(const Duration(milliseconds: 120), HapticFeedback.heavyImpact);
  }
}
