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

    if (settings.brightnessBoost) {
      await _brightness.boostToMax();
    }

    await windowManager.setFullScreen(true);
    await windowManager.setAlwaysOnTop(true);

    final rgb = (settings.backgroundColor & 0xFFFFFF)
        .toRadixString(16)
        .padLeft(6, '0');
    await _monitorCover.coverSecondaryDisplays(backgroundColorHex: '#$rgb');

    final engaged = await _nativeLock.startLock(
      unlockKey: settings.unlockKeyEnum,
      unlockHoldDuration: settings.unlockHoldDuration,
      lockPointer: settings.pointerLock,
      allowMouseMove: settings.allowMouseMove,
    );

    // CRITICAL: if the lock did not engage, the native hook is NOT swallowing
    // keys — there is no working unlock and the user would be trapped on a
    // black fullscreen. Abort: tear everything back down and surface the
    // failure so the home screen can tell the user what to do.
    if (!engaged) {
      await _teardown();
      emit(
        const CleaningState(
          status: CleaningStatus.failed,
          errorMessage:
              'Could not lock input. Grant Accessibility '
              'permission and try again.',
        ),
      );
      return;
    }

    // Lock engaged — subscribe to native unlock events now. Subscribing only
    // after a successful engage means the abort path above can never race with
    // an incoming event (and unlock progress only fires once the user holds the
    // key, well after this point, so nothing is missed).
    _eventSub = _nativeLock.events.listen(_onNativeEvent);

    if (settings.hasCountdown) {
      _startCountdown();
    }
  }

  /// Clear a [CleaningStatus.failed] state back to idle so the home banner
  /// does not re-fire. Safe to call when not failed (no-op).
  void acknowledgeFailure() {
    if (state.status == CleaningStatus.failed) {
      emit(const CleaningState.idle());
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
    await _teardown();
    emit(const CleaningState.idle());
  }

  /// Release every lock/cover/window override and cancel subs/timers, in the
  /// reverse order they were applied. Each collaborator already swallows its
  /// own platform errors, so this always completes — it is the single recovery
  /// path shared by [stop] and the lock-failure abort in [start].
  Future<void> _teardown() async {
    _countdownTimer?.cancel();
    _countdownTimer = null;

    await _nativeLock.stopLock();
    await _monitorCover.releaseAll();
    await _brightness.restore();
    await windowManager.setAlwaysOnTop(false);
    await windowManager.setFullScreen(false);

    await _eventSub?.cancel();
    _eventSub = null;
  }

  @override
  Future<void> close() async {
    _countdownTimer?.cancel();
    await _eventSub?.cancel();
    return super.close();
  }
}
