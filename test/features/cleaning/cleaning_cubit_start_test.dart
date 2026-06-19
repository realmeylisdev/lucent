import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucent/core/models/unlock_key.dart';
import 'package:lucent/core/platform/native_lock_controller.dart';
import 'package:lucent/core/services/brightness_service.dart';
import 'package:lucent/core/services/multi_monitor_cover.dart';
import 'package:lucent/features/cleaning/cubit/cleaning_cubit.dart';
import 'package:lucent/features/settings/model/lucent_settings.dart';
import 'package:mocktail/mocktail.dart';

class _MockNativeLock extends Mock implements NativeLockController {}

class _MockMonitorCover extends Mock implements MultiMonitorCover {}

class _MockBrightness extends Mock implements BrightnessService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockNativeLock nativeLock;
  late _MockMonitorCover monitorCover;
  late _MockBrightness brightness;
  late List<MethodCall> windowCalls;

  // The cleaning start path drives the window_manager plugin channel; mock it
  // so setFullScreen/setAlwaysOnTop don't throw in the test VM and we can
  // assert that teardown invoked setFullScreen(false).
  const windowChannel = MethodChannel('window_manager');

  setUpAll(() {
    registerFallbackValue(UnlockKey.escape);
    registerFallbackValue(Duration.zero);
  });

  setUp(() {
    nativeLock = _MockNativeLock();
    monitorCover = _MockMonitorCover();
    brightness = _MockBrightness();
    windowCalls = [];

    when(
      () => nativeLock.events,
    ).thenAnswer((_) => const Stream<NativeLockEvent>.empty());
    when(() => nativeLock.stopLock()).thenAnswer((_) async {});
    when(
      () => monitorCover.coverSecondaryDisplays(
        backgroundColorHex: any(named: 'backgroundColorHex'),
      ),
    ).thenAnswer((_) async {});
    when(() => monitorCover.releaseAll()).thenAnswer((_) async {});
    when(() => brightness.boostToMax()).thenAnswer((_) async {});
    when(() => brightness.restore()).thenAnswer((_) async {});

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(windowChannel, (call) async {
          windowCalls.add(call);
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(windowChannel, null);
  });

  CleaningCubit makeCubit() => CleaningCubit(
    nativeLock: nativeLock,
    monitorCover: monitorCover,
    brightness: brightness,
  );

  bool sawFullScreenFalse() => windowCalls.any(
    (c) =>
        c.method == 'setFullScreen' &&
        (c.arguments as Map)['isFullScreen'] == false,
  );

  test(
    'start ENGAGES: ends in cleaning and covers secondary displays',
    () async {
      when(
        () => nativeLock.startLock(
          unlockKey: any(named: 'unlockKey'),
          unlockHoldDuration: any(named: 'unlockHoldDuration'),
          lockPointer: any(named: 'lockPointer'),
          allowMouseMove: any(named: 'allowMouseMove'),
        ),
      ).thenAnswer((_) async => true);

      final cubit = makeCubit();
      addTearDown(cubit.close);

      await cubit.start(LucentSettings.defaults);

      expect(cubit.state.status, CleaningStatus.cleaning);
      verify(
        () => monitorCover.coverSecondaryDisplays(
          backgroundColorHex: any(named: 'backgroundColorHex'),
        ),
      ).called(1);
    },
  );

  test('start FAILS: aborts, runs full teardown, ends failed', () async {
    when(
      () => nativeLock.startLock(
        unlockKey: any(named: 'unlockKey'),
        unlockHoldDuration: any(named: 'unlockHoldDuration'),
        lockPointer: any(named: 'lockPointer'),
        allowMouseMove: any(named: 'allowMouseMove'),
      ),
    ).thenAnswer((_) async => false);

    final cubit = makeCubit();
    addTearDown(cubit.close);

    await cubit.start(LucentSettings.defaults);

    expect(cubit.state.status, CleaningStatus.failed);
    expect(cubit.state.errorMessage, isNotNull);

    // The teardown path MUST have run so the user is never trapped.
    verify(() => nativeLock.stopLock()).called(1);
    verify(() => monitorCover.releaseAll()).called(1);
    verify(() => brightness.restore()).called(1);
    expect(sawFullScreenFalse(), isTrue);
  });

  test('acknowledgeFailure clears failed back to idle', () async {
    when(
      () => nativeLock.startLock(
        unlockKey: any(named: 'unlockKey'),
        unlockHoldDuration: any(named: 'unlockHoldDuration'),
        lockPointer: any(named: 'lockPointer'),
        allowMouseMove: any(named: 'allowMouseMove'),
      ),
    ).thenAnswer((_) async => false);

    final cubit = makeCubit();
    addTearDown(cubit.close);

    await cubit.start(LucentSettings.defaults);
    expect(cubit.state.status, CleaningStatus.failed);

    cubit.acknowledgeFailure();
    expect(cubit.state.status, CleaningStatus.idle);
  });
}
