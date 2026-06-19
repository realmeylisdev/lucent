/// Blacks out every NON-primary display during a cleaning session.
///
/// v1 status — DEFERRED (no-op). The native input lock already applies globally
/// across every display, so the keyboard and trackpad are locked everywhere
/// regardless of how many monitors are attached. Only the *visual* blackout of
/// secondary screens is outstanding.
///
/// It is deferred because the desktop multi-window plugins available for
/// Flutter 3.44 (`desktop_multi_window` 0.3.0) cannot position a window on a
/// specific display — its `WindowController` exposes only `show()`/`hide()`,
/// no `setFrame`. A correct implementation needs either the patched
/// `window_manager` fork (as the original used) or Flutter's experimental
/// multi-window API.
///
/// This class keeps the cleaning-session integration point stable: implementing
/// the cover later is a drop-in change behind these two methods, with no caller
/// changes required.
class MultiMonitorCover {
  /// Spawn a black cover on each non-primary display. No-op while deferred.
  Future<void> coverSecondaryDisplays({
    required String backgroundColorHex,
  }) async {
    // Intentionally empty — see class doc. Never blocks the cleaning session.
  }

  /// Release every spawned cover. No-op while deferred.
  Future<void> releaseAll() async {
    // Intentionally empty — nothing is spawned yet.
  }
}
