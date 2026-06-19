import 'package:flutter_test/flutter_test.dart';
import 'package:lucent/features/cleaning/models/cleaning_mode.dart';

void main() {
  group('CleaningMode', () {
    test('fromToken maps known tokens', () {
      expect(CleaningMode.fromToken('screen'), CleaningMode.screen);
      expect(CleaningMode.fromToken('keyboard'), CleaningMode.keyboard);
      expect(CleaningMode.fromToken('full'), CleaningMode.full);
    });

    test('fromToken falls back to full on null / bad data', () {
      expect(CleaningMode.fromToken(null), CleaningMode.full);
      expect(CleaningMode.fromToken('nonsense'), CleaningMode.full);
    });

    test('only screen / full support guided wipe', () {
      expect(CleaningMode.screen.supportsGuidedWipe, isTrue);
      expect(CleaningMode.full.supportsGuidedWipe, isTrue);
      expect(CleaningMode.keyboard.supportsGuidedWipe, isFalse);
    });

    test('every mode has a label and a blurb', () {
      for (final m in CleaningMode.values) {
        expect(m.label, isNotEmpty);
        expect(m.blurb, isNotEmpty);
        expect(m.token, isNotEmpty);
      }
    });
  });
}
