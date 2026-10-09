import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppSound { scan, success, badge }

/// Optional, quiet sound effects (scan, success, badge). On by default; the switch in
/// Profile turns them off and is remembered on this phone. Nothing plays until [load] has
/// run at startup (so widget tests stay silent), and any audio error is ignored.
///
/// Playback uses Android's built-in SoundPool through a small channel in MainActivity,
/// so no audio package is needed.
class AppSounds {
  static const _key = 'sounds_enabled';
  static const _channel = MethodChannel('ecoreward/sounds');
  static bool _loaded = false;
  static bool _enabled = true;

  static bool get enabled => _enabled;

  static String _asset(AppSound s) => 'assets/sounds/${s.name}.wav';

  static Future<void> load() async {
    try {
      _enabled = (await SharedPreferences.getInstance()).getBool(_key) ?? true;
      await _channel.invokeMethod<void>('load', AppSound.values.map(_asset).toList());
    } catch (_) {}
    _loaded = true;
  }

  static Future<void> setEnabled(bool v) async {
    _enabled = v;
    try {
      await (await SharedPreferences.getInstance()).setBool(_key, v);
    } catch (_) {}
  }

  /// Whether a sound would actually play (callers fall back to the system click otherwise).
  static bool get active => _loaded && _enabled;

  static Future<void> play(AppSound s) async {
    if (!active) return;
    try {
      await _channel.invokeMethod<void>('play', {'asset': _asset(s), 'volume': 0.6});
    } catch (_) {
      // Sound is a nicety; never let it break a flow.
    }
  }
}
