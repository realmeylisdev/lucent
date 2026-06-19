/// Method/event channel names + method identifiers shared with the native
/// (Swift / C++ / GTK) host.
///
/// This is the unified `InputLock` contract that every platform implements
/// identically:
///   * macOS  — `CGEventTapController` behind `InputLockPlugin.swift`
///   * Windows — `WH_KEYBOARD_LL` / `WH_MOUSE_LL` low-level hooks
///   * Linux  — X11 `XGrabKeyboard` / Wayland shortcut-inhibit
abstract final class LucentChannels {
  /// Imperative calls Dart -> native (configure / lock / unlock / permissions).
  static const method = 'video.divine.lucent/input_lock/methods';

  /// Stream native -> Dart of unlock-progress + terminal lock events.
  ///
  /// CRITICAL: because the native hook SWALLOWS keystrokes, Flutter never sees
  /// the unlock keypress. The native layer detects the hold-gesture itself and
  /// pushes `unlockProgress` (0..1) followed by `lockReleased` here.
  static const events = 'video.divine.lucent/input_lock/events';
}

/// Method names invoked on [LucentChannels.method].
abstract final class LucentMethods {
  /// Returns a permission status string
  /// (`granted` | `denied` | `notDetermined` | `notRequired`).
  static const checkPermission = 'checkPermission';

  /// Triggers the OS permission prompt / opens the relevant Settings pane.
  static const requestPermission = 'requestPermission';

  /// MUST be called before [lock]: tells the native hook which swallowed key,
  /// held for how long, ends the session.
  static const configureUnlockGesture = 'configureUnlockGesture';

  /// Installs the native global input tap. Returns `bool engaged`.
  static const lock = 'lock';

  /// Tears down the tap and restores input. Returns `bool released`.
  static const unlock = 'unlock';

  /// Whether a native tap is currently installed.
  static const isLocked = 'isLocked';
}
