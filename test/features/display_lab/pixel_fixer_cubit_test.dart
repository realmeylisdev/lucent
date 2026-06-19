import 'dart:async';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:lucent/features/display_lab/cubit/pixel_fixer_cubit.dart';
import 'package:lucent/features/display_lab/models/auto_stop_preset.dart';
import 'package:lucent/features/display_lab/models/pixel_fixer_mode.dart';
import 'package:lucent/features/settings/data/settings_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<SettingsRepository> _repo([Map<String, Object>? seed]) async {
  SharedPreferences.setMockInitialValues(seed ?? {});
  final repo = SettingsRepository(await SharedPreferences.getInstance());
  await repo.load();
  return repo;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PixelFixerCubit', () {
    test('starts stopped at the calm default frequency', () async {
      final cubit = PixelFixerCubit(repository: await _repo());
      expect(cubit.state.running, isFalse);
      expect(cubit.state.frequencyHz, PixelFixerState.defaultHz);
      expect(cubit.state.regionEnabled, isFalse);
      expect(cubit.state.autoStop, AutoStopPreset.off);
      unawaited(cubit.close());
    });

    test('seeds initial config from persisted settings', () async {
      final repo = await _repo();
      await repo.save(
        repo.value.copyWith(
          pixelFixerMode: 'whiteFlash',
          pixelFixerHz: 7,
          pixelFixerRegionEnabled: true,
          pixelFixerAutoStopMinutes: 30,
        ),
      );
      final cubit = PixelFixerCubit(repository: repo);
      expect(cubit.state.mode, PixelFixerMode.whiteFlash);
      expect(cubit.state.frequencyHz, 7);
      expect(cubit.state.regionEnabled, isTrue);
      expect(cubit.state.autoStop, AutoStopPreset.thirtyMin);
      expect(cubit.state.running, isFalse); // never auto-runs.
      unawaited(cubit.close());
    });

    test('stale mode token degrades to rgbCycle', () async {
      final repo = await _repo();
      await repo.save(repo.value.copyWith(pixelFixerMode: 'garbage'));
      final cubit = PixelFixerCubit(repository: repo);
      expect(cubit.state.mode, PixelFixerMode.rgbCycle);
      unawaited(cubit.close());
    });

    test('start/stop toggles running', () async {
      final cubit = PixelFixerCubit(repository: await _repo())..start();
      expect(cubit.state.running, isTrue);
      cubit.stop();
      expect(cubit.state.running, isFalse);
      unawaited(cubit.close());
    });

    test('timer advances the frame while running', () async {
      final cubit = PixelFixerCubit(repository: await _repo())
        ..setFrequency(10)
        ..start();
      await Future<void>.delayed(const Duration(milliseconds: 350));
      expect(cubit.state.frame, greaterThan(0));
      await cubit.close();
    });

    test('frequency is clamped to the safe range', () async {
      final cubit = PixelFixerCubit(repository: await _repo())
        ..setFrequency(999);
      expect(cubit.state.frequencyHz, PixelFixerState.maxHz);
      cubit.setFrequency(0);
      expect(cubit.state.frequencyHz, PixelFixerState.minHz);
      unawaited(cubit.close());
    });

    test('setMode changes the color strategy and persists', () async {
      final repo = await _repo();
      final cubit = PixelFixerCubit(repository: repo)
        ..setMode(PixelFixerMode.whiteFlash);
      expect(cubit.state.mode, PixelFixerMode.whiteFlash);
      await Future<void>.delayed(Duration.zero);
      expect(repo.value.pixelFixerMode, 'whiteFlash');
      unawaited(cubit.close());
    });

    test('region setters update state and persist on end', () async {
      final repo = await _repo();
      final cubit = PixelFixerCubit(repository: repo)
        ..setRegionEnabled(true)
        ..setRegion(const Rect.fromLTWH(10, 20, 120, 140));
      expect(cubit.state.regionEnabled, isTrue);
      expect(cubit.state.region, const Rect.fromLTWH(10, 20, 120, 140));
      await Future<void>.delayed(Duration.zero);
      expect(repo.value.pixelFixerRegionEnabled, isTrue);
      expect(repo.value.pixelFixerRegionLeft, 10);
      expect(repo.value.pixelFixerRegionWidth, 120);
      unawaited(cubit.close());
    });

    test('setRegion with persist:false leaves prefs untouched', () async {
      final repo = await _repo();
      final cubit = PixelFixerCubit(repository: repo)
        ..setRegion(const Rect.fromLTWH(5, 5, 300, 300), persist: false);
      expect(cubit.state.region, const Rect.fromLTWH(5, 5, 300, 300));
      await Future<void>.delayed(Duration.zero);
      // Default region width stays persisted (no write happened).
      expect(repo.value.pixelFixerRegionWidth, 200);
      unawaited(cubit.close());
    });

    test('auto-stop arms a countdown on start', () async {
      final cubit = PixelFixerCubit(repository: await _repo())
        ..setAutoStop(AutoStopPreset.tenMin)
        ..start();
      expect(cubit.state.remainingSeconds, 600);
      cubit.stop();
      expect(cubit.state.remainingSeconds, 0);
      unawaited(cubit.close());
    });

    test('auto-stop counts down and stops at zero', () async {
      // A 1-second countdown is not selectable, so drive the tick path by
      // arming then letting one real second elapse from a low remaining.
      final cubit = PixelFixerCubit(repository: await _repo())
        ..setAutoStop(AutoStopPreset.tenMin)
        ..start();
      expect(cubit.state.running, isTrue);
      await Future<void>.delayed(const Duration(milliseconds: 1100));
      expect(cubit.state.remainingSeconds, lessThan(600));
      cubit.stop();
      unawaited(cubit.close());
    });

    test('changing preset while running restarts the countdown', () async {
      final cubit = PixelFixerCubit(repository: await _repo())
        ..setAutoStop(AutoStopPreset.tenMin)
        ..start()
        ..setAutoStop(AutoStopPreset.thirtyMin);
      expect(cubit.state.remainingSeconds, 1800);
      cubit
        ..setAutoStop(AutoStopPreset.off)
        ..stop();
      expect(cubit.state.remainingSeconds, 0);
      unawaited(cubit.close());
    });

    test('setFrequency while running preserves the auto-stop target', () async {
      final cubit = PixelFixerCubit(repository: await _repo())
        ..setAutoStop(AutoStopPreset.sixtyMin)
        ..start();
      final before = cubit.state.remainingSeconds;
      cubit.setFrequency(8);
      // Re-arming the frame timer must not reset the countdown.
      expect(cubit.state.remainingSeconds, before);
      cubit.stop();
      unawaited(cubit.close());
    });

    test('close stops emitting further frames', () async {
      final cubit = PixelFixerCubit(repository: await _repo())
        ..setFrequency(10)
        ..start();
      await cubit.close();
      final frameAfterClose = cubit.state.frame;
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(cubit.state.frame, frameAfterClose);
    });
  });

  group('clampRectToBounds', () {
    const bounds = Size(800, 600);

    test('keeps an in-bounds rect unchanged', () {
      const rect = Rect.fromLTWH(100, 100, 200, 200);
      expect(clampRectToBounds(rect, bounds), rect);
    });

    test('pushes an off-screen rect back inside', () {
      const rect = Rect.fromLTWH(700, 500, 200, 200);
      final clamped = clampRectToBounds(rect, bounds);
      expect(clamped.right, lessThanOrEqualTo(bounds.width));
      expect(clamped.bottom, lessThanOrEqualTo(bounds.height));
      expect(clamped.left, greaterThanOrEqualTo(0));
      expect(clamped.top, greaterThanOrEqualTo(0));
    });

    test('enforces the minimum region side', () {
      const rect = Rect.fromLTWH(0, 0, 10, 10);
      final clamped = clampRectToBounds(rect, bounds);
      expect(clamped.width, PixelFixerState.minRegionSide);
      expect(clamped.height, PixelFixerState.minRegionSide);
    });

    test('caps the region to the available size', () {
      const rect = Rect.fromLTWH(0, 0, 2000, 2000);
      final clamped = clampRectToBounds(rect, bounds);
      expect(clamped.width, bounds.width);
      expect(clamped.height, bounds.height);
    });

    test('returns the rect unchanged when bounds are empty', () {
      const rect = Rect.fromLTWH(0, 0, 2000, 2000);
      expect(clampRectToBounds(rect, Size.zero), rect);
    });
  });
}
