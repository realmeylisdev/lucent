import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucent/core/constants/channels.dart';
import 'package:lucent/core/models/unlock_key.dart';
import 'package:lucent/core/platform/native_lock_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('NativeLockController.startLock gesture mapping', () {
    late List<MethodCall> calls;
    late NativeLockController controller;

    setUp(() {
      calls = [];
      const channel = MethodChannel(LucentChannels.method);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            return true;
          });
      controller = NativeLockController();
    });

    Future<String?> gestureFor(UnlockKey key) async {
      calls.clear();
      await controller.startLock(
        unlockKey: key,
        unlockHoldDuration: const Duration(milliseconds: 2500),
        lockPointer: true,
        allowMouseMove: false,
      );
      final configure = calls.firstWhere(
        (c) => c.method == LucentMethods.configureUnlockGesture,
      );
      return (configure.arguments as Map)['gesture'] as String?;
    }

    test('escape -> holdEsc', () async {
      expect(await gestureFor(UnlockKey.escape), 'holdEsc');
    });

    test('space -> holdSpace', () async {
      expect(await gestureFor(UnlockKey.space), 'holdSpace');
    });

    test('either -> holdEscOrSpace', () async {
      expect(await gestureFor(UnlockKey.either), 'holdEscOrSpace');
    });
  });

  group('UnlockKey', () {
    test('either round-trips through fromToken', () {
      expect(UnlockKey.fromToken('either'), UnlockKey.either);
      expect(UnlockKey.either.label, 'Esc or Space');
    });
  });

  group('NativeLockController defensive paths', () {
    const channel = MethodChannel(LucentChannels.method);
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final controller = NativeLockController();

    Future<bool> start() => controller.startLock(
      unlockKey: UnlockKey.escape,
      unlockHoldDuration: const Duration(milliseconds: 2500),
      lockPointer: true,
      allowMouseMove: false,
    );

    tearDown(() => messenger.setMockMethodCallHandler(channel, null));

    test('startLock is false when lock reports not engaged', () async {
      messenger.setMockMethodCallHandler(
        channel,
        (call) async => call.method != LucentMethods.lock,
      );
      expect(await start(), isFalse);
    });

    test('startLock is false on a PlatformException', () async {
      messenger.setMockMethodCallHandler(
        channel,
        (call) async => throw PlatformException(code: 'boom'),
      );
      expect(await start(), isFalse);
    });

    test('startLock is false when the plugin is missing', () async {
      messenger.setMockMethodCallHandler(channel, null);
      expect(await start(), isFalse);
    });

    test('isAccessibilityTrusted fails safe to false on error', () async {
      messenger.setMockMethodCallHandler(
        channel,
        (call) async => throw PlatformException(code: 'boom'),
      );
      expect(await controller.isAccessibilityTrusted(), isFalse);
    });
  });
}
