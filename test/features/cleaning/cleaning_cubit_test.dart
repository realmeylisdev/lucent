import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lucent/core/platform/native_lock_controller.dart';
import 'package:lucent/core/services/brightness_service.dart';
import 'package:lucent/core/services/multi_monitor_cover.dart';
import 'package:lucent/features/cleaning/cubit/cleaning_cubit.dart';
import 'package:lucent/features/cleaning/models/cleaning_mode.dart';
import 'package:mocktail/mocktail.dart';

class _MockNativeLock extends Mock implements NativeLockController {}

class _MockMonitorCover extends Mock implements MultiMonitorCover {}

class _MockBrightness extends Mock implements BrightnessService {}

/// Exposes [emit] so the coverage / guard logic can be tested without driving
/// the full [CleaningCubit.start] (which touches windowManager channels).
class _TestableCleaningCubit extends CleaningCubit {
  _TestableCleaningCubit()
    : super(
        nativeLock: _MockNativeLock(),
        monitorCover: _MockMonitorCover(),
        brightness: _MockBrightness(),
      );

  void seed(CleaningState state) => emit(state);
}

CleaningCubit _makeCubit() => CleaningCubit(
  nativeLock: _MockNativeLock(),
  monitorCover: _MockMonitorCover(),
  brightness: _MockBrightness(),
);

void main() {
  group('CleaningState getters', () {
    test('coverage is 0 when there is no grid', () {
      const s = CleaningState.idle();
      expect(s.coverage, 0);
    });

    test('coverage = covered / total cells', () {
      const s = CleaningState(
        status: CleaningStatus.cleaning,
        guidedWipe: true,
        gridColumns: 4,
        gridRows: 2,
        coveredCells: {0, 1},
      );
      expect(s.coverage, closeTo(2 / 8, 1e-9));
    });

    test('countdownFraction is null without an active countdown', () {
      const s = CleaningState(status: CleaningStatus.cleaning);
      expect(s.countdownFraction, isNull);
    });

    test('countdownFraction = remaining / total', () {
      const s = CleaningState(
        status: CleaningStatus.cleaning,
        remainingSeconds: 15,
        totalSeconds: 30,
      );
      expect(s.countdownFraction, closeTo(0.5, 1e-9));
    });

    test('countdownFraction null when total is zero', () {
      const s = CleaningState(
        status: CleaningStatus.cleaning,
        remainingSeconds: 0,
        totalSeconds: 0,
      );
      expect(s.countdownFraction, isNull);
    });
  });

  group('CleaningCubit.markCellCovered', () {
    test('is a no-op when guided-wipe is inactive', () {
      final cubit = _makeCubit()..markCellCovered(3);
      expect(cubit.state.coveredCells, isEmpty);
      unawaited(cubit.close());
    });

    test('adds a new cell when guided-wipe is active', () {
      final cubit = _TestableCleaningCubit()
        ..seed(
          const CleaningState(
            status: CleaningStatus.cleaning,
            guidedWipe: true,
            gridColumns: 4,
            gridRows: 2,
          ),
        )
        ..markCellCovered(5);
      expect(cubit.state.coveredCells, contains(5));
      unawaited(cubit.close());
    });

    test('does not re-emit for an already-covered cell', () {
      final cubit = _TestableCleaningCubit()
        ..seed(
          const CleaningState(
            status: CleaningStatus.cleaning,
            guidedWipe: true,
            gridColumns: 4,
            gridRows: 2,
            coveredCells: {2},
          ),
        );
      final emitted = <CleaningState>[];
      final sub = cubit.stream.listen(emitted.add);
      cubit
        ..markCellCovered(2)
        ..markCellCovered(2);
      expect(emitted, isEmpty);
      unawaited(sub.cancel());
      unawaited(cubit.close());
    });

    test('emits a NEW set so Equatable detects the change', () {
      final cubit = _TestableCleaningCubit()
        ..seed(
          const CleaningState(
            status: CleaningStatus.cleaning,
            guidedWipe: true,
            gridColumns: 4,
            gridRows: 2,
            coveredCells: {1},
          ),
        );
      final before = cubit.state.coveredCells;
      cubit.markCellCovered(2);
      expect(identical(before, cubit.state.coveredCells), isFalse);
      expect(cubit.state.coveredCells, {1, 2});
      unawaited(cubit.close());
    });
  });

  test('idle state defaults to full mode', () {
    const s = CleaningState.idle();
    expect(s.mode, CleaningMode.full);
    expect(s.guidedWipe, isFalse);
  });
}
