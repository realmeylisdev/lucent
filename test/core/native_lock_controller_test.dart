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
}
