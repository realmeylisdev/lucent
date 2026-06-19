import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lucent/features/display_lab/cubit/pixel_fixer_cubit.dart';
import 'package:lucent/features/display_lab/models/pixel_fixer_mode.dart';

void main() {
  group('PixelFixerCubit', () {
    test('starts stopped at the calm default frequency', () {
      final cubit = PixelFixerCubit();
      expect(cubit.state.running, isFalse);
      expect(cubit.state.frequencyHz, PixelFixerState.defaultHz);
      unawaited(cubit.close());
    });

    test('start/stop toggles running', () {
      final cubit = PixelFixerCubit()..start();
      expect(cubit.state.running, isTrue);
      cubit.stop();
      expect(cubit.state.running, isFalse);
      unawaited(cubit.close());
    });

    test('timer advances the frame while running', () async {
      final cubit = PixelFixerCubit()
        ..setFrequency(10)
        ..start();
      await Future<void>.delayed(const Duration(milliseconds: 350));
      expect(cubit.state.frame, greaterThan(0));
      await cubit.close();
    });

    test('frequency is clamped to the safe range', () {
      final cubit = PixelFixerCubit()..setFrequency(999);
      expect(cubit.state.frequencyHz, PixelFixerState.maxHz);
      cubit.setFrequency(0);
      expect(cubit.state.frequencyHz, PixelFixerState.minHz);
      unawaited(cubit.close());
    });

    test('setMode changes the color strategy', () {
      final cubit = PixelFixerCubit()..setMode(PixelFixerMode.whiteFlash);
      expect(cubit.state.mode, PixelFixerMode.whiteFlash);
      unawaited(cubit.close());
    });

    test('close stops emitting further frames', () async {
      final cubit = PixelFixerCubit()
        ..setFrequency(10)
        ..start();
      await cubit.close();
      final frameAfterClose = cubit.state.frame;
      await Future<void>.delayed(const Duration(milliseconds: 200));
      // Timer was cancelled in close(), so the frame must not keep advancing.
      expect(cubit.state.frame, frameAfterClose);
    });
  });
}
