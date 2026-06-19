import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lucent/features/display_lab/cubit/display_lab_cubit.dart';
import 'package:lucent/features/display_lab/models/lab_pattern_catalog.dart';

void main() {
  group('LabPatternCatalog', () {
    test('is non-empty and every pattern has a label and purpose', () {
      expect(LabPatternCatalog.all, isNotEmpty);
      for (final pattern in LabPatternCatalog.all) {
        expect(pattern.label, isNotEmpty);
        expect(pattern.purpose, isNotEmpty);
        expect(pattern.id, isNotEmpty);
      }
    });

    test('every pattern id is unique', () {
      final ids = LabPatternCatalog.all.map((p) => p.id).toSet();
      expect(ids.length, LabPatternCatalog.all.length);
    });
  });

  group('DisplayLabCubit', () {
    test('starts in the menu with no active pattern', () {
      final cubit = DisplayLabCubit();
      expect(cubit.state.activePattern, isNull);
      expect(cubit.state.hintVisible, isTrue);
      unawaited(cubit.close());
    });

    test('openPattern enters viewer and syncs the category', () {
      final cubit = DisplayLabCubit();
      final pattern = LabPatternCatalog.all.last;
      cubit.openPattern(pattern);
      expect(cubit.state.activePattern, pattern);
      expect(cubit.state.activeCategory, pattern.category);
      unawaited(cubit.close());
    });

    test('next/previous wrap around the flat catalog', () {
      final cubit = DisplayLabCubit()
        ..openPattern(LabPatternCatalog.all.last)
        ..next();
      expect(cubit.state.activePattern, LabPatternCatalog.all.first);
      cubit.previous();
      expect(cubit.state.activePattern, LabPatternCatalog.all.last);
      unawaited(cubit.close());
    });

    test('closeViewer clears the active pattern', () {
      final cubit = DisplayLabCubit()
        ..openPattern(LabPatternCatalog.all.first)
        ..closeViewer();
      expect(cubit.state.activePattern, isNull);
      unawaited(cubit.close());
    });

    test('toggleHint flips visibility', () {
      final cubit = DisplayLabCubit();
      final before = cubit.state.hintVisible;
      cubit.toggleHint();
      expect(cubit.state.hintVisible, !before);
      unawaited(cubit.close());
    });
  });
}
