import 'dart:async';
import 'dart:ui';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucent/features/display_lab/models/auto_stop_preset.dart';
import 'package:lucent/features/display_lab/models/pixel_fixer_mode.dart';
import 'package:lucent/features/settings/data/settings_repository.dart';
import 'package:lucent/features/settings/model/lucent_settings.dart';

part 'pixel_fixer_state.dart';

/// Drives the stuck-pixel exerciser: a periodic [Timer] advances the frame
/// counter (and therefore the on-screen color) while running. The flash rate is
/// capped at a safe range and the view shows a photosensitivity warning before
/// the first run — see PixelFixerState.minHz / PixelFixerState.maxHz.
///
/// Config (mode / Hz / region / auto-stop) round-trips through
/// [SettingsRepository] so the fixer reopens with the last-used setup. Session
/// state (running / frame / remaining) is never persisted — the page always
/// reopens stopped so the photosensitivity gate is honored every session.
class PixelFixerCubit extends Cubit<PixelFixerState> {
  PixelFixerCubit({required SettingsRepository repository})
    : _repository = repository,
      super(PixelFixerState.fromSettings(repository.value));

  final SettingsRepository _repository;

  Timer? _timer;
  Timer? _autoStopTimer;

  /// Start (or restart) cycling at the current speed and arm the auto-stop
  /// countdown from a fresh full duration when a preset is selected.
  void start() {
    _timer?.cancel();
    _autoStopTimer?.cancel();
    _timer = Timer.periodic(
      Duration(milliseconds: state.intervalMs),
      (_) => emit(state.copyWith(frame: state.frame + 1)),
    );
    final seconds = state.autoStop.seconds;
    if (seconds > 0) {
      _autoStopTimer = Timer.periodic(
        const Duration(seconds: 1),
        (_) => _tickAutoStop(),
      );
    }
    emit(state.copyWith(running: true, remainingSeconds: seconds));
  }

  /// Stop cycling (keeps the current frame/color shown) and cancel any pending
  /// auto-stop. Same code path for manual and automatic stop.
  void stop() {
    _timer?.cancel();
    _timer = null;
    _autoStopTimer?.cancel();
    _autoStopTimer = null;
    emit(state.copyWith(running: false, remainingSeconds: 0));
  }

  /// Toggle between running and stopped.
  void toggle() => state.running ? stop() : start();

  void _tickAutoStop() {
    final next = state.remainingSeconds - 1;
    if (next <= 0) {
      stop();
    } else {
      emit(state.copyWith(remainingSeconds: next));
    }
  }

  /// Switch the color-cycle strategy (does not re-arm the timers).
  void setMode(PixelFixerMode mode) {
    emit(state.copyWith(mode: mode));
    unawaited(_persist());
  }

  /// Set the flash rate in whole Hz, clamped to the safe range; re-arms the
  /// frame timer if running. Re-arming preserves the auto-stop countdown — the
  /// end time is only (re)set on an explicit [start] or preset change.
  void setFrequency(int hz, {bool persist = true}) {
    final clamped = hz.clamp(PixelFixerState.minHz, PixelFixerState.maxHz);
    emit(state.copyWith(frequencyHz: clamped));
    if (state.running) {
      _timer?.cancel();
      _timer = Timer.periodic(
        Duration(milliseconds: state.intervalMs),
        (_) => emit(state.copyWith(frame: state.frame + 1)),
      );
    }
    // Persist on the slider's drag-END only (persist:false during drag) to
    // avoid hammering SharedPreferences with a write per tick.
    if (persist) unawaited(_persist());
  }

  /// Toggle between full-screen and region cycling. Allowed while running.
  void setRegionEnabled(bool value) {
    emit(state.copyWith(regionEnabled: value));
    unawaited(_persist());
  }

  /// Update the region rectangle (already clamped to bounds by the caller).
  /// Persist on drag/resize END only to avoid hammering prefs.
  void setRegion(Rect rect, {bool persist = true}) {
    emit(state.copyWith(region: rect));
    if (persist) unawaited(_persist());
  }

  /// Change the auto-stop preset. While running, this restarts the countdown
  /// from the new full duration (or cancels it when set to off).
  void setAutoStop(AutoStopPreset preset) {
    emit(state.copyWith(autoStop: preset));
    if (state.running) {
      _autoStopTimer?.cancel();
      _autoStopTimer = null;
      final seconds = preset.seconds;
      if (seconds > 0) {
        _autoStopTimer = Timer.periodic(
          const Duration(seconds: 1),
          (_) => _tickAutoStop(),
        );
      }
      emit(state.copyWith(remainingSeconds: seconds));
    }
    unawaited(_persist());
  }

  Future<void> _persist() async {
    await _repository.save(
      _repository.value.copyWith(
        pixelFixerMode: state.mode.name,
        pixelFixerHz: state.frequencyHz,
        pixelFixerRegionEnabled: state.regionEnabled,
        pixelFixerRegionLeft: state.region.left.round(),
        pixelFixerRegionTop: state.region.top.round(),
        pixelFixerRegionWidth: state.region.width.round(),
        pixelFixerRegionHeight: state.region.height.round(),
        pixelFixerAutoStopMinutes: state.autoStop.minutes,
      ),
    );
  }

  @override
  Future<void> close() {
    _timer?.cancel();
    _timer = null;
    _autoStopTimer?.cancel();
    _autoStopTimer = null;
    return super.close();
  }
}
