import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucent/core/platform/native_lock_controller.dart';
import 'package:lucent/core/services/brightness_service.dart';
import 'package:lucent/core/services/multi_monitor_cover.dart';
import 'package:lucent/features/cleaning/models/cleaning_mode.dart';
import 'package:lucent/features/settings/model/lucent_settings.dart';
import 'package:window_manager/window_manager.dart';

part 'cleaning_state.dart';

/// Orchestrates a cleaning session: native lock + fullscreen + multi-monitor
/// cover + brightness boost + optional countdown auto-exit.
///
/// Unlock is driven ENTIRELY by the native event stream: this cubit never
/// listens for keystrokes (they are swallowed by the hook). It maps
/// [UnlockProgress] -> [CleaningState.unlockProgress] and [UnlockCompleted] ->
/// [stop].
class CleaningCubit extends Cubit<CleaningState> {
  CleaningCubit({
    required this._nativeLock,
    required this._monitorCover,
    required this._brightness,
  }) : super(const CleaningState.idle());

  final NativeLockController _nativeLock;
  final MultiMonitorCover _monitorCover;
  final BrightnessService _brightness;

  StreamSubscription<NativeLockEvent>? _eventSub;
  Timer? _countdownTimer;

  /// Begin cleaning with the user's [settings].
  Future<void> start(LucentSettings settings) async {
    if (state.status == CleaningStatus.cleaning) return;

    final guided = settings.guidedWipeActive;
    emit(
      CleaningState(
        status: CleaningStatus.cleaning,
        backgroundColor: settings.backgroundColor,
        remainingSeconds: settings.hasCountdown
            ? settings.countdownSeconds
            : null,
        mode: settings.cleaningMode,
        totalSeconds: settings.hasCountdown ? settings.countdownSeconds : null,
        guidedWipe: guided,
        gridColumns: guided ? 12 : 0,
        gridRows: guided ? 8 : 0,
      ),
    );

    // Listen to native unlock events BEFORE the lock engages so no progress is
    // missed.
    _eventSub = _nativeLock.events.listen(_onNativeEvent);

    if (settings.brightnessBoost) {
      await _brightness.boostToMax();
    }

    await windowManager.setFullScreen(true);
    await windowManager.setAlwaysOnTop(true);

    final rgb = (settings.backgroundColor & 0xFFFFFF)
        .toRadixString(16)
        .padLeft(6, '0');
    await _monitorCover.coverSecondaryDisplays(backgroundColorHex: '#$rgb');

    await _nativeLock.startLock(
      unlockKey: settings.unlockKeyEnum,
      unlockHoldDuration: settings.unlockHoldDuration,
      lockPointer: settings.pointerLock,
      allowMouseMove: settings.allowMouseMove,
    );

    if (settings.hasCountdown) {
      _startCountdown();
    }
  }

  /// Mark a coverage cell as wiped. No-op if guided-wipe isn't active or the
  /// cell is already covered (keeps emits cheap). Coverage is purely cosmetic;
  /// the session never ends because of it.
  void markCellCovered(int index) {
    if (!state.guidedWipe || state.coveredCells.contains(index)) return;
    emit(state.copyWith(coveredCells: {...state.coveredCells, index}));
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final remaining = (state.remainingSeconds ?? 0) - 1;
      if (remaining <= 0) {
        timer.cancel();
        unawaited(stop());
      } else {
        emit(state.copyWith(remainingSeconds: remaining));
      }
    });
  }

  void _onNativeEvent(NativeLockEvent event) {
    switch (event) {
      case UnlockProgress(:final value):
        emit(state.copyWith(unlockProgress: value));
      case UnlockCompleted():
        unawaited(stop());
      case NativeLockFailed():
        unawaited(stop());
    }
  }

  /// End the session and release every lock/cover together.
  Future<void> stop() async {
    if (state.status == CleaningStatus.idle) return;

    _countdownTimer?.cancel();
    _countdownTimer = null;

    await _nativeLock.stopLock();
    await _monitorCover.releaseAll();
    await _brightness.restore();
    await windowManager.setAlwaysOnTop(false);
    await windowManager.setFullScreen(false);

    await _eventSub?.cancel();
    _eventSub = null;

    emit(const CleaningState.idle());
  }

  @override
  Future<void> close() async {
    _countdownTimer?.cancel();
    await _eventSub?.cancel();
    return super.close();
  }
}
