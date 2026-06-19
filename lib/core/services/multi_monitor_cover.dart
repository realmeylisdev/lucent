import 'package:flutter/services.dart';

/// Blacks out every NON-primary display during a cleaning session.
///
/// The native input lock already applies globally across every display, so the
/// keyboard and trackpad are locked everywhere regardless; this adds the
/// *visual* blackout of secondary screens.
///
/// Implemented natively on macOS (`MonitorCoverPlugin` spawns a borderless
/// black `NSWindow` per non-main `NSScreen`). On platforms without the
/// plugin (Windows/Linux today) the calls throw [MissingPluginException] and
/// are treated as a no-op — best-effort, never blocking the cleaning session.
class MultiMonitorCover {
  static const _channel = MethodChannel('video.divine.lucent/monitor_cover');

  /// Spawn a cover on each non-primary display, painted [backgroundColorHex]
  /// (`#rrggbb`).
  Future<void> coverSecondaryDisplays({
    required String backgroundColorHex,
  }) async {
    try {
      await _channel.invokeMethod<bool>(
        'cover',
        {'colorHex': backgroundColorHex},
      );
    } on MissingPluginException {
      // Not implemented on this platform yet — no-op.
    } on PlatformException {
      // Best-effort; never block the cleaning session.
    }
  }

  /// Close every cover window so all displays release together on unlock.
  Future<void> releaseAll() async {
    try {
      await _channel.invokeMethod<bool>('release');
    } on MissingPluginException {
      // Not implemented on this platform yet — no-op.
    } on PlatformException {
      // Best-effort.
    }
  }
}
