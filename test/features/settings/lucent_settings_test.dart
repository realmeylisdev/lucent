import 'package:flutter_test/flutter_test.dart';
import 'package:lucent/core/models/unlock_key.dart';
import 'package:lucent/features/settings/model/lucent_settings.dart';

void main() {
  group('LucentSettings', () {
    test('defaults are sensible for a screen-cleaner', () {
      const s = LucentSettings.defaults;
      expect(s.unlockKey, 'escape');
      expect(s.unlockHoldMs, 2500);
      expect(s.pointerLock, isTrue);
      expect(s.brightnessBoost, isTrue);
      expect(s.backgroundColor, 0xFF000000);
      expect(s.autoStart, isFalse);
      expect(s.countdownSeconds, 0);
    });

    test('derived getters map raw fields to typed values', () {
      const s = LucentSettings.defaults;
      expect(s.unlockKeyEnum, UnlockKey.escape);
      expect(s.unlockHoldDuration, const Duration(milliseconds: 2500));
      expect(s.hasCountdown, isFalse);

      final timed = s.copyWith(countdownSeconds: 30);
      expect(timed.hasCountdown, isTrue);
    });

    test('copyWith changes only the named field', () {
      const s = LucentSettings.defaults;
      final updated = s.copyWith(pointerLock: false, unlockHoldMs: 4000);
      expect(updated.pointerLock, isFalse);
      expect(updated.unlockHoldMs, 4000);
      // Untouched fields are preserved.
      expect(updated.brightnessBoost, s.brightnessBoost);
      expect(updated.backgroundColor, s.backgroundColor);
    });

    test('value equality (Equatable) holds for identical settings', () {
      expect(
        LucentSettings.defaults,
        LucentSettings.defaults.copyWith(),
      );
      final changed = LucentSettings.defaults.copyWith(autoStart: true);
      expect(LucentSettings.defaults == changed, isFalse);
    });
  });
}
