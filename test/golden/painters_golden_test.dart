// Golden tests for the PURE-SHAPE Display Lab painters — text-free only.
//
// CI runs `flutter test` on UBUNTU; pixel goldens generated on macOS would
// mismatch on Linux (font/anti-aliasing differences) and turn CI red. Every
// test here is therefore guarded `skip: !Platform.isMacOS` so the Linux CI
// never runs or compares them. The committed PNGs are generated locally on
// macOS with:
//
//   flutter test --update-goldens test/golden/painters_golden_test.dart
//
// Only painters that draw shapes/colors (no TextPainter) are golden-tested;
// text-drawing painters (gamma calibration, text legibility, overscan,
// near-black/near-white steps) are intentionally excluded.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucent/features/display_lab/widgets/pattern_painters.dart';

void main() {
  const size = Size(240, 160);

  Future<void> expectPainter(
    WidgetTester tester,
    CustomPainter painter,
    String name,
  ) async {
    await tester.pumpWidget(
      Center(
        child: RepaintBoundary(
          child: SizedBox.fromSize(
            size: size,
            child: CustomPaint(size: size, painter: painter),
          ),
        ),
      ),
    );
    await expectLater(
      find.byType(CustomPaint).first,
      matchesGoldenFile('goldens/$name.png'),
    );
  }

  group(
    'text-free pattern painters',
    () {
      testWidgets('solid', (tester) async {
        await expectPainter(
          tester,
          const SolidPainter(Color(0xFF3366CC)),
          'solid',
        );
      });

      testWidgets('rgb_color_bars', (tester) async {
        await expectPainter(
          tester,
          const RgbColorBarsPainter(),
          'rgb_color_bars',
        );
      });

      testWidgets('smpte_color_bars', (tester) async {
        await expectPainter(
          tester,
          const SmpteColorBarsPainter(),
          'smpte_color_bars',
        );
      });

      testWidgets('linear_gradient', (tester) async {
        await expectPainter(
          tester,
          const LinearGradientPainter(),
          'linear_gradient',
        );
      });

      testWidgets('radial_gradient', (tester) async {
        await expectPainter(
          tester,
          const RadialGradientPainter(),
          'radial_gradient',
        );
      });

      testWidgets('alignment_grid', (tester) async {
        await expectPainter(
          tester,
          const AlignmentGridPainter(),
          'alignment_grid',
        );
      });

      testWidgets('checkerboard', (tester) async {
        await expectPainter(
          tester,
          const CheckerboardPainter(1),
          'checkerboard',
        );
      });

      testWidgets('grayscale_staircase', (tester) async {
        await expectPainter(
          tester,
          const GrayscaleStaircasePainter(16),
          'grayscale_staircase',
        );
      });
    },
    skip: !Platform.isMacOS,
  );
}
