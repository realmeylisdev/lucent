import 'package:equatable/equatable.dart';
import 'package:lucent/core/models/unlock_key.dart';
import 'package:lucent/features/cleaning/models/cleaning_mode.dart';

/// Immutable user settings. Background color stored as a 32-bit ARGB int.
class LucentSettings extends Equatable {
  const LucentSettings({
    required this.unlockKey,
    required this.unlockHoldMs,
    required this.pointerLock,
    required this.brightnessBoost,
    required this.backgroundColor,
    required this.autoStart,
    required this.startInCleaning,
    required this.countdownSeconds,
    required this.hotkey,
    required this.cleaningMode,
    required this.guidedWipe,
  });

  static const defaults = LucentSettings(
    unlockKey: 'escape',
    unlockHoldMs: 2500,
    pointerLock: true,
    brightnessBoost: true,
    backgroundColor: 0xFF000000,
    autoStart: false,
    startInCleaning: false,
    countdownSeconds: 0, // 0 == no auto-exit timer.
    hotkey: 'ctrl+alt+l',
    cleaningMode: CleaningMode.full,
    guidedWipe: false,
  );

  final String unlockKey;
  final int unlockHoldMs;
  final bool pointerLock;
  final bool brightnessBoost;
  final int backgroundColor;
  final bool autoStart;
  final bool startInCleaning;
  final int countdownSeconds;
  final String hotkey;
  final CleaningMode cleaningMode;
  final bool guidedWipe;

  UnlockKey get unlockKeyEnum => UnlockKey.fromToken(unlockKey);
  Duration get unlockHoldDuration => Duration(milliseconds: unlockHoldMs);
  bool get hasCountdown => countdownSeconds > 0;

  /// Guided wipe is only meaningful for surfaces that ARE the screen.
  bool get guidedWipeActive => guidedWipe && cleaningMode.supportsGuidedWipe;

  /// Cursor movement is only delivered to Flutter when guided-wipe is active.
  bool get allowMouseMove => guidedWipeActive;

  LucentSettings copyWith({
    String? unlockKey,
    int? unlockHoldMs,
    bool? pointerLock,
    bool? brightnessBoost,
    int? backgroundColor,
    bool? autoStart,
    bool? startInCleaning,
    int? countdownSeconds,
    String? hotkey,
    CleaningMode? cleaningMode,
    bool? guidedWipe,
  }) {
    return LucentSettings(
      unlockKey: unlockKey ?? this.unlockKey,
      unlockHoldMs: unlockHoldMs ?? this.unlockHoldMs,
      pointerLock: pointerLock ?? this.pointerLock,
      brightnessBoost: brightnessBoost ?? this.brightnessBoost,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      autoStart: autoStart ?? this.autoStart,
      startInCleaning: startInCleaning ?? this.startInCleaning,
      countdownSeconds: countdownSeconds ?? this.countdownSeconds,
      hotkey: hotkey ?? this.hotkey,
      cleaningMode: cleaningMode ?? this.cleaningMode,
      guidedWipe: guidedWipe ?? this.guidedWipe,
    );
  }

  @override
  List<Object?> get props => [
    unlockKey,
    unlockHoldMs,
    pointerLock,
    brightnessBoost,
    backgroundColor,
    autoStart,
    startInCleaning,
    countdownSeconds,
    hotkey,
    cleaningMode,
    guidedWipe,
  ];
}
