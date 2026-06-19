import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucent/features/display_lab/models/pixel_fixer_mode.dart';

part 'pixel_fixer_state.dart';

/// Drives the stuck-pixel exerciser: a periodic [Timer] advances the frame
/// counter (and therefore the on-screen color) while running. The flash rate is
/// capped at a safe range and the view shows a photosensitivity warning before
/// the first run — see PixelFixerState.minHz / PixelFixerState.maxHz.
class PixelFixerCubit extends Cubit<PixelFixerState> {
  PixelFixerCubit() : super(const PixelFixerState.initial());

  Timer? _timer;

  /// Start (or restart) cycling at the current speed.
  void start() {
    _timer?.cancel();
    _timer = Timer.periodic(
      Duration(milliseconds: state.intervalMs),
      (_) => emit(state.copyWith(frame: state.frame + 1)),
    );
    emit(state.copyWith(running: true));
  }

  /// Stop cycling (keeps the current frame/color shown).
  void stop() {
    _timer?.cancel();
    _timer = null;
    emit(state.copyWith(running: false));
  }

  /// Toggle between running and stopped.
  void toggle() => state.running ? stop() : start();

  /// Switch the color-cycle strategy.
  void setMode(PixelFixerMode mode) => emit(state.copyWith(mode: mode));

  /// Set the flash rate in whole Hz, clamped to the safe range; re-arms the
  /// timer if currently running so the new rate takes effect immediately.
  void setFrequency(int hz) {
    final clamped = hz.clamp(PixelFixerState.minHz, PixelFixerState.maxHz);
    emit(state.copyWith(frequencyHz: clamped));
    if (state.running) start();
  }

  @override
  Future<void> close() {
    _timer?.cancel();
    _timer = null;
    return super.close();
  }
}
