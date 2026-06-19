import 'dart:async';

import 'package:flutter/services.dart';
import 'package:lucent/core/constants/channels.dart';
import 'package:lucent/core/models/unlock_key.dart';

/// Event emitted by the native input hook to Flutter.
sealed class NativeLockEvent {
  const NativeLockEvent();
}

/// Native is reporting how far through the unlock hold-gesture the user is.
class UnlockProgress extends NativeLockEvent {
  const UnlockProgress(this.value);

  /// 0..1 hold completion. Drives the on-screen unlock ring.
  final double value;
}

/// The user completed the unlock hold inside the native hook. Flutter MUST now
/// tear down the cleaning session and release every monitor cover.
class UnlockCompleted extends NativeLockEvent {
  const UnlockCompleted();
}

/// The native hook stopped unexpectedly (e.g. permission revoked mid-session,
/// CGEventTap disabled by the OS and could not be re-enabled).
class NativeLockFailed extends NativeLockEvent {
  const NativeLockFailed(this.message);
  final String message;
}

/// Dart-side facade over the native OS-level input lock.
///
/// The native implementations (Swift `CGEventTapController` on macOS, a
/// `WH_KEYBOARD_LL` hook on Windows, an X11/Wayland grab on Linux) all speak the
/// same `video.divine.lucent/input_lock` contract defined in [LucentChannels].
///
/// Unlock design (see [NativeLockEvent]): keystrokes are swallowed by the hook
/// so Flutter cannot observe the unlock key directly. The hook watches the
/// configured [UnlockKey] hold, streams `unlockProgress`, then emits
/// `lockReleased(reason: userGesture)`. Flutter reacts by ending the session.
class NativeLockController {
  NativeLockController({
    MethodChannel? method,
    EventChannel? events,
  }) : _method = method ?? const MethodChannel(LucentChannels.method),
       _events = events ?? const EventChannel(LucentChannels.events);

  final MethodChannel _method;
  final EventChannel _events;

  Stream<NativeLockEvent>? _eventStream;

  /// Broadcast stream of native -> Dart lock events, filtered to the subset the
  /// cleaning session reacts to. Informational events (`lockEngaged`,
  /// `permissionChanged`, re-enabled `tapDisabled`) are dropped here.
  Stream<NativeLockEvent> get events => _eventStream ??= _events
      .receiveBroadcastStream()
      .map(_decode)
      .where((event) => event != null)
      .cast<NativeLockEvent>();

  NativeLockEvent? _decode(dynamic raw) {
    final map = (raw as Map).cast<String, dynamic>();
    switch (map['type'] as String?) {
      case 'unlockProgress':
        return UnlockProgress((map['value'] as num).toDouble());
      case 'lockReleased':
        final reason = map['reason'] as String? ?? 'unknown';
        if (reason == 'userGesture') return const UnlockCompleted();
        if (reason == 'programmatic') return null; // we initiated stopLock().
        return NativeLockFailed(map['detail'] as String? ?? reason);
      case 'tapDisabled':
        final reEnabled = map['reEnabled'] as bool? ?? false;
        return reEnabled
            ? null
            : NativeLockFailed('input tap disabled: ${map['cause']}');
      default:
        // lockEngaged / permissionChanged / unknown — not session-terminating.
        return null;
    }
  }

  /// Engage the native input lock.
  ///
  /// Sends the unlock gesture config first (so the hook knows which swallowed
  /// key ends the session), then installs the tap. [lockPointer] toggles
  /// trackpad/mouse swallowing.
  ///
  /// When [lockPointer] && [allowMouseMove], clicks/scroll stay swallowed but
  /// bare cursor MOVEMENT reaches Flutter (macOS honors this; Windows/Linux may
  /// ignore it and keep the cursor frozen — degrade gracefully, no error).
  ///
  /// Returns `true` ONLY when the native tap actually engaged. Any failure —
  /// a thrown [PlatformException], a [MissingPluginException] (no native
  /// implementation), or the native side reporting `engaged == false/null` —
  /// returns `false` so the caller can abort cleanly instead of softlocking on
  /// a black screen with no working unlock.
  Future<bool> startLock({
    required UnlockKey unlockKey,
    required Duration unlockHoldDuration,
    required bool lockPointer,
    required bool allowMouseMove,
  }) async {
    try {
      await _method.invokeMethod<bool>(LucentMethods.configureUnlockGesture, {
        'gesture': switch (unlockKey) {
          UnlockKey.space => 'holdSpace',
          UnlockKey.either => 'holdEscOrSpace',
          UnlockKey.escape => 'holdEsc',
        },
        'holdDurationMs': unlockHoldDuration.inMilliseconds,
        'requireKeyUpReset': true,
      });
      final engaged = await _method.invokeMethod<bool>(LucentMethods.lock, {
        'swallowPointer': lockPointer,
        'allowMouseMove': allowMouseMove,
        'displayIds': <String>[],
      });
      return engaged ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  /// Release the native input lock (app-initiated, e.g. timer end / quit).
  ///
  /// Swallows channel errors so teardown ALWAYS completes — even if the native
  /// side is gone or never installed the plugin.
  Future<void> stopLock() async {
    try {
      await _method.invokeMethod<bool>(LucentMethods.unlock, {
        'reason': 'programmatic',
      });
    } on MissingPluginException {
      // Nothing to release.
    } on PlatformException {
      // Best-effort; never block teardown.
    }
  }

  /// macOS: whether Accessibility / Input-Monitoring is granted. Other
  /// platforms report `notRequired` and therefore resolve to `true`.
  ///
  /// Fails safe: any channel error resolves to `false` so the UI keeps Start
  /// disabled / shows the accessibility card rather than letting a doomed lock
  /// attempt proceed into the softlock.
  Future<bool> isAccessibilityTrusted() async {
    try {
      final status = await _method.invokeMethod<String>(
        LucentMethods.checkPermission,
      );
      return status == 'granted' || status == 'notRequired';
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  /// macOS: prompt + open System Settings > Privacy & Security > Accessibility.
  ///
  /// Best-effort: a missing handler must not crash the home screen.
  Future<void> openAccessibilitySettings() async {
    try {
      await _method.invokeMethod<void>(LucentMethods.requestPermission);
    } on MissingPluginException {
      // No native implementation; nothing to open.
    } on PlatformException {
      // Best-effort.
    }
  }
}
