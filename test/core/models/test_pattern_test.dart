import 'package:flutter_test/flutter_test.dart';
import 'package:lucent/core/models/test_pattern.dart';

void main() {
  group('TestPattern', () {
    test('exposes the full pattern set with a label and decoration each', () {
      expect(TestPattern.values, isNotEmpty);
      for (final pattern in TestPattern.values) {
        expect(pattern.label, isNotEmpty);
        // Every pattern paints either a solid color or a gradient.
        final decoration = pattern.decoration;
        expect(
          decoration.color != null || decoration.gradient != null,
          isTrue,
          reason: '${pattern.name} must define a color or gradient',
        );
      }
    });

    test('next wraps around from the last pattern to the first', () {
      expect(TestPattern.values.last.next, TestPattern.values.first);
    });

    test('previous wraps around from the first pattern to the last', () {
      expect(TestPattern.values.first.previous, TestPattern.values.last);
    });

    test('next and previous are inverse operations', () {
      for (final pattern in TestPattern.values) {
        expect(pattern.next.previous, pattern);
        expect(pattern.previous.next, pattern);
      }
    });
  });
}
