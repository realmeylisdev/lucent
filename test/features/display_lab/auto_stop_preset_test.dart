import 'package:flutter_test/flutter_test.dart';
import 'package:lucent/features/display_lab/models/auto_stop_preset.dart';

void main() {
  group('AutoStopPreset', () {
    test('maps minutes to seconds', () {
      expect(AutoStopPreset.off.seconds, 0);
      expect(AutoStopPreset.tenMin.seconds, 600);
      expect(AutoStopPreset.thirtyMin.seconds, 1800);
      expect(AutoStopPreset.sixtyMin.seconds, 3600);
    });

    test('fromMinutes resolves known values', () {
      expect(AutoStopPreset.fromMinutes(0), AutoStopPreset.off);
      expect(AutoStopPreset.fromMinutes(10), AutoStopPreset.tenMin);
      expect(AutoStopPreset.fromMinutes(30), AutoStopPreset.thirtyMin);
      expect(AutoStopPreset.fromMinutes(60), AutoStopPreset.sixtyMin);
    });

    test('fromMinutes degrades unknown values to off', () {
      expect(AutoStopPreset.fromMinutes(15), AutoStopPreset.off);
      expect(AutoStopPreset.fromMinutes(-1), AutoStopPreset.off);
    });

    test('labels are user-facing', () {
      expect(AutoStopPreset.off.label, 'Off');
      expect(AutoStopPreset.tenMin.label, '10 min');
    });
  });
}
