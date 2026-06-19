import 'package:screen_brightness/screen_brightness.dart';

/// Boosts display brightness to max during cleaning and restores it after.
class BrightnessService {
  double? _saved;

  /// Save the current brightness and set it to maximum.
  Future<void> boostToMax() async {
    try {
      _saved = await ScreenBrightness.instance.application;
      await ScreenBrightness.instance.setApplicationScreenBrightness(1);
    } on Object catch (_) {
      // Brightness control unsupported on this platform/session; ignore.
    }
  }

  /// Restore the brightness captured by [boostToMax].
  Future<void> restore() async {
    final saved = _saved;
    if (saved == null) return;
    try {
      await ScreenBrightness.instance.setApplicationScreenBrightness(saved);
      await ScreenBrightness.instance.resetApplicationScreenBrightness();
    } on Object catch (_) {
      // ignore
    } finally {
      _saved = null;
    }
  }
}
