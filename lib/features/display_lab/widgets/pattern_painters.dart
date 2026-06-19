import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:lucent/features/display_lab/models/lab_pattern.dart';

/// Builds the right [CustomPainter] for [pattern] at the given
/// [devicePixelRatio] (the device-pixel-accurate sharpness patterns need it).
CustomPainter painterForPattern(LabPattern pattern, double devicePixelRatio) =>
    switch (pattern.kind) {
      LabPatternKind.solid ||
      LabPatternKind.flatField => SolidPainter(Color(pattern.value)),
      LabPatternKind.grayscaleStaircase => GrayscaleStaircasePainter(
        pattern.value,
      ),
      LabPatternKind.smpteColorBars => const SmpteColorBarsPainter(),
      LabPatternKind.rgbColorBars100 => const RgbColorBarsPainter(),
      LabPatternKind.gradientLinear => const LinearGradientPainter(),
      LabPatternKind.gradientRadial => const RadialGradientPainter(),
      LabPatternKind.gammaCalibration => const GammaCalibrationPainter(),
      LabPatternKind.checkerboard1px => CheckerboardPainter(devicePixelRatio),
      LabPatternKind.textLegibility => const TextLegibilityPainter(),
      LabPatternKind.alignmentGrid => const AlignmentGridPainter(),
      LabPatternKind.overscan => const OverscanPainter(),
      LabPatternKind.nearBlackSteps => const NearBlackStepsPainter(),
      LabPatternKind.nearWhiteSteps => const NearWhiteStepsPainter(),
      LabPatternKind.pixelInversion => PixelInversionPainter(devicePixelRatio),
    };

/// Fills the whole canvas with one [color]. Backs solids and flat fields.
class SolidPainter extends CustomPainter {
  const SolidPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) =>
      canvas.drawColor(color, BlendMode.src);

  @override
  bool shouldRepaint(SolidPainter old) => old.color != color;
}

/// [steps] equal-width vertical bars from black to white with hard edges.
class GrayscaleStaircasePainter extends CustomPainter {
  const GrayscaleStaircasePainter(this.steps);

  final int steps;

  @override
  void paint(Canvas canvas, Size size) {
    final barWidth = size.width / steps;
    for (var i = 0; i < steps; i++) {
      final v = (i * 255 / (steps - 1)).round();
      final paint = Paint()..color = Color.fromARGB(255, v, v, v);
      canvas.drawRect(
        Rect.fromLTWH(i * barWidth, 0, barWidth + 1, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(GrayscaleStaircasePainter old) => old.steps != steps;
}

/// SMPTE 75% color bars with castellation and PLUGE row.
class SmpteColorBarsPainter extends CustomPainter {
  const SmpteColorBarsPainter();

  static const _top = [
    Color(0xFFBFBFBF),
    Color(0xFFBFBF00),
    Color(0xFF00BFBF),
    Color(0xFF00BF00),
    Color(0xFFBF00BF),
    Color(0xFFBF0000),
    Color(0xFF0000BF),
  ];

  static const _mid = [
    Color(0xFF0000BF),
    Color(0xFF000000),
    Color(0xFFBF00BF),
    Color(0xFF000000),
    Color(0xFF00BFBF),
    Color(0xFF000000),
    Color(0xFFBFBFBF),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final topH = size.height * 0.67;
    final midH = size.height * 0.08;
    final barW = w / 7;
    final paint = Paint();
    for (var i = 0; i < 7; i++) {
      canvas
        ..drawRect(
          Rect.fromLTWH(i * barW, 0, barW + 1, topH),
          paint..color = _top[i],
        )
        ..drawRect(
          Rect.fromLTWH(i * barW, topH, barW + 1, midH),
          paint..color = _mid[i],
        );
    }
    _paintPluge(canvas, size, topH + midH);
  }

  void _paintPluge(Canvas canvas, Size size, double top) {
    final w = size.width;
    final h = size.height - top;
    final paint = Paint();
    final sixth = w / 6;
    void block(double x, double width, Color c) => canvas.drawRect(
      Rect.fromLTWH(x, top, width + 1, h),
      paint..color = c,
    );
    block(0, sixth, const Color(0xFF101040));
    block(sixth, sixth, const Color(0xFFFFFFFF));
    block(2 * sixth, sixth, const Color(0xFF200040));
    // Three narrow PLUGE strips occupy the rightmost 3 * strip; the black
    // setup block fills the gap up to them, so nothing overshoots the edge.
    final strip = w / 24;
    final base = w - 3 * strip;
    block(3 * sixth, base - 3 * sixth, const Color(0xFF000000));
    block(base, strip, const Color(0xFF030303));
    block(base + strip, strip, const Color(0xFF101010));
    block(base + 2 * strip, strip, const Color(0xFF1A1A1A));
  }

  @override
  bool shouldRepaint(SmpteColorBarsPainter old) => false;
}

/// 8 full-height 100%-saturation bars.
class RgbColorBarsPainter extends CustomPainter {
  const RgbColorBarsPainter();

  static const _bars = [
    Color(0xFFFFFFFF),
    Color(0xFFFFFF00),
    Color(0xFF00FFFF),
    Color(0xFF00FF00),
    Color(0xFFFF00FF),
    Color(0xFFFF0000),
    Color(0xFF0000FF),
    Color(0xFF000000),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final barW = size.width / _bars.length;
    final paint = Paint();
    for (var i = 0; i < _bars.length; i++) {
      canvas.drawRect(
        Rect.fromLTWH(i * barW, 0, barW + 1, size.height),
        paint..color = _bars[i],
      );
    }
  }

  @override
  bool shouldRepaint(RgbColorBarsPainter old) => false;
}

/// Raw (un-dithered) black-to-white horizontal gradient.
class LinearGradientPainter extends CustomPainter {
  const LinearGradientPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = ui.Gradient.linear(
        Offset.zero,
        Offset(size.width, 0),
        const [Color(0xFF000000), Color(0xFFFFFFFF)],
      );
    canvas.drawRect(Offset.zero & size, paint);
  }

  @override
  bool shouldRepaint(LinearGradientPainter old) => false;
}

/// White-center to black-edge radial gradient.
class RadialGradientPainter extends CustomPainter {
  const RadialGradientPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..shader = ui.Gradient.radial(
        center,
        math.max(size.width, size.height) / 2,
        const [Color(0xFFFFFFFF), Color(0xFF000000)],
      );
    canvas.drawRect(Offset.zero & size, paint);
  }

  @override
  bool shouldRepaint(RadialGradientPainter old) => false;
}

/// Three gamma patches (1.8 / 2.2 / 2.4): a fine line field that averages to
/// ~50% surrounded by the gamma-encoded swatch for that value.
class GammaCalibrationPainter extends CustomPainter {
  const GammaCalibrationPainter();

  static const _swatches = [
    Color(0xFFCCCCCC),
    Color(0xFFBABABA),
    Color(0xFFB2B2B2),
  ];
  static const _labels = ['1.8', '2.2', '2.4'];

  @override
  void paint(Canvas canvas, Size size) {
    final cellW = size.width / 3;
    final patch = math.min(cellW, size.height) * 0.4;
    for (var i = 0; i < 3; i++) {
      final cx = cellW * i + cellW / 2;
      final cy = size.height / 2;
      canvas.drawRect(
        Rect.fromLTWH(cellW * i, 0, cellW + 1, size.height),
        Paint()..color = _swatches[i],
      );
      final rect = Rect.fromCenter(
        center: Offset(cx, cy),
        width: patch,
        height: patch,
      );
      _paintLines(canvas, rect);
      _paintLabel(canvas, _labels[i], Offset(cx, cy + patch / 2 + 12));
    }
  }

  void _paintLines(Canvas canvas, Rect rect) {
    final white = Paint()..color = const Color(0xFFFFFFFF);
    canvas.drawRect(rect, Paint()..color = const Color(0xFF000000));
    for (var y = rect.top.floor(); y < rect.bottom; y += 2) {
      canvas.drawRect(
        Rect.fromLTWH(rect.left, y.toDouble(), rect.width, 1),
        white,
      );
    }
  }

  void _paintLabel(Canvas canvas, String text, Offset center) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(color: Color(0xFF202020), fontSize: 12),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, center.translate(-tp.width / 2, 0));
  }

  @override
  bool shouldRepaint(GammaCalibrationPainter old) => false;
}

/// 1-device-pixel black/white checkerboard, drawn crisply via FilterQuality.none
/// on a tiled 2x2 bitmap scaled by 1/dpr so one cell maps to one physical pixel.
class CheckerboardPainter extends CustomPainter {
  const CheckerboardPainter(this.devicePixelRatio);

  final double devicePixelRatio;

  @override
  void paint(Canvas canvas, Size size) {
    final cell = 1.0 / devicePixelRatio;
    const black = Color(0xFF000000);
    const white = Color(0xFFFFFFFF);
    final cols = (size.width / cell).ceil();
    final rows = (size.height / cell).ceil();
    final paint = Paint()..isAntiAlias = false;
    for (var y = 0; y < rows; y++) {
      for (var x = 0; x < cols; x++) {
        paint.color = ((x + y) & 1) == 0 ? white : black;
        canvas.drawRect(
          Rect.fromLTWH(x * cell, y * cell, cell, cell),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(CheckerboardPainter old) =>
      old.devicePixelRatio != devicePixelRatio;
}

/// Black-on-white (top) and white-on-black (bottom) monospace text at a range
/// of small sizes to test crispness and fringing.
class TextLegibilityPainter extends CustomPainter {
  const TextLegibilityPainter();

  static const _pangram =
      'The quick brown fox jumps over the lazy dog 0123456789';
  static const _sizes = [8.0, 10.0, 12.0, 14.0, 18.0];

  @override
  void paint(Canvas canvas, Size size) {
    final half = size.height / 2;
    canvas
      ..drawRect(
        Rect.fromLTWH(0, 0, size.width, half),
        Paint()..color = const Color(0xFFFFFFFF),
      )
      ..drawRect(
        Rect.fromLTWH(0, half, size.width, half),
        Paint()..color = const Color(0xFF000000),
      );
    _paintColumn(canvas, const Color(0xFF000000), const Offset(16, 16));
    _paintColumn(canvas, const Color(0xFFFFFFFF), Offset(16, half + 16));
  }

  void _paintColumn(Canvas canvas, Color color, Offset start) {
    var dy = start.dy;
    for (final fontSize in _sizes) {
      final tp =
          TextPainter(
              text: TextSpan(
                text: _pangram,
                style: TextStyle(
                  color: color,
                  fontSize: fontSize,
                  fontFamily: 'monospace',
                ),
              ),
              textDirection: TextDirection.ltr,
            )
            ..layout()
            ..paint(canvas, Offset(start.dx, dy.roundToDouble()));
      dy += tp.height + 8;
    }
  }

  @override
  bool shouldRepaint(TextLegibilityPainter old) => false;
}

/// Alignment grid + crosshair + circle + diagonals on black.
class AlignmentGridPainter extends CustomPainter {
  const AlignmentGridPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawColor(const Color(0xFF000000), BlendMode.src);
    final cx = size.width / 2;
    final cy = size.height / 2;
    final thin = Paint()
      ..color = const Color(0xFFFFFFFF)
      ..strokeWidth = 1;
    const spacing = 50.0;
    for (var x = cx; x < size.width; x += spacing) {
      _vline(canvas, x, size.height, thin);
      _vline(canvas, 2 * cx - x, size.height, thin);
    }
    for (var y = cy; y < size.height; y += spacing) {
      _hline(canvas, y, size.width, thin);
      _hline(canvas, 2 * cy - y, size.width, thin);
    }
    final thick = Paint()
      ..color = const Color(0xFFFFFFFF)
      ..strokeWidth = 2;
    canvas
      ..drawLine(Offset(0, cy), Offset(size.width, cy), thick)
      ..drawLine(Offset(cx, 0), Offset(cx, size.height), thick)
      ..drawCircle(
        Offset(cx, cy),
        math.min(size.width, size.height) * 0.4,
        Paint()
          ..color = const Color(0xFFFFFFFF)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      )
      ..drawLine(Offset.zero, Offset(size.width, size.height), thin)
      ..drawLine(Offset(size.width, 0), Offset(0, size.height), thin);
  }

  void _vline(Canvas canvas, double x, double h, Paint p) => canvas.drawLine(
    Offset(x.roundToDouble() + 0.5, 0),
    Offset(x.roundToDouble() + 0.5, h),
    p,
  );

  void _hline(Canvas canvas, double y, double w, Paint p) => canvas.drawLine(
    Offset(0, y.roundToDouble() + 0.5),
    Offset(w, y.roundToDouble() + 0.5),
    p,
  );

  @override
  bool shouldRepaint(AlignmentGridPainter old) => false;
}

/// Nested edge frames (0% white, 2.5% red, 5% green) + corner squares + ticks.
class OverscanPainter extends CustomPainter {
  const OverscanPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawColor(const Color(0xFF000000), BlendMode.src);
    _frame(canvas, size, 0, const Color(0xFFFFFFFF), 2);
    _frame(canvas, size, 0.025, const Color(0xFFFF0000), 1);
    _frame(canvas, size, 0.05, const Color(0xFF00FF00), 1);
    final corner = Paint()..color = const Color(0xFFFFFFFF);
    canvas
      ..drawRect(const Rect.fromLTWH(0, 0, 8, 8), corner)
      ..drawRect(Rect.fromLTWH(size.width - 8, 0, 8, 8), corner)
      ..drawRect(Rect.fromLTWH(0, size.height - 8, 8, 8), corner)
      ..drawRect(
        Rect.fromLTWH(size.width - 8, size.height - 8, 8, 8),
        corner,
      );
    _ticks(canvas, size);
  }

  void _frame(Canvas canvas, Size size, double inset, Color c, double sw) {
    final dx = size.width * inset;
    final dy = size.height * inset;
    canvas.drawRect(
      Rect.fromLTRB(
        dx + sw / 2,
        dy + sw / 2,
        size.width - dx - sw / 2,
        size.height - dy - sw / 2,
      ),
      Paint()
        ..color = c
        ..style = PaintingStyle.stroke
        ..strokeWidth = sw,
    );
  }

  void _ticks(Canvas canvas, Size size) {
    for (var i = 1; i < 10; i++) {
      _tick(canvas, '${i * 10}', Offset(size.width * i / 10, 10));
      _tick(canvas, '${i * 10}', Offset(10, size.height * i / 10));
    }
  }

  void _tick(Canvas canvas, String text, Offset at) {
    TextPainter(
        text: TextSpan(
          text: text,
          style: const TextStyle(color: Color(0xFF808080), fontSize: 10),
        ),
        textDirection: TextDirection.ltr,
      )
      ..layout()
      ..paint(canvas, at);
  }

  @override
  bool shouldRepaint(OverscanPainter old) => false;
}

/// Row of near-black step patches on a pure-black field, labeled with values.
class NearBlackStepsPainter extends CustomPainter {
  const NearBlackStepsPainter();

  static const _values = [
    0,
    1,
    2,
    3,
    4,
    5,
    6,
    8,
    10,
    12,
    14,
    16,
    20,
    24,
    28,
    32,
    0,
  ];

  @override
  void paint(Canvas canvas, Size size) {
    _paintSteps(
      canvas,
      size,
      background: const Color(0xFF000000),
      values: _values,
      labelColor: const Color(0xFF606060),
    );
  }

  @override
  bool shouldRepaint(NearBlackStepsPainter old) => false;
}

/// Row of near-white step patches on a pure-white field, labeled with values.
class NearWhiteStepsPainter extends CustomPainter {
  const NearWhiteStepsPainter();

  static const _values = [
    255,
    254,
    253,
    252,
    251,
    250,
    249,
    247,
    245,
    243,
    241,
    239,
    235,
    231,
    227,
    223,
    255,
  ];

  @override
  void paint(Canvas canvas, Size size) {
    _paintSteps(
      canvas,
      size,
      background: const Color(0xFFFFFFFF),
      values: _values,
      labelColor: const Color(0xFFA0A0A0),
    );
  }

  @override
  bool shouldRepaint(NearWhiteStepsPainter old) => false;
}

void _paintSteps(
  Canvas canvas,
  Size size, {
  required Color background,
  required List<int> values,
  required Color labelColor,
}) {
  canvas.drawColor(background, BlendMode.src);
  final totalW = size.width * 0.8;
  final left = (size.width - totalW) / 2;
  final patchW = totalW / values.length;
  final patchH = size.height * 0.25;
  final top = (size.height - patchH) / 2;
  for (var i = 0; i < values.length; i++) {
    final v = values[i];
    canvas.drawRect(
      Rect.fromLTWH(left + i * patchW, top, patchW + 1, patchH),
      Paint()..color = Color.fromARGB(255, v, v, v),
    );
    TextPainter(
        text: TextSpan(
          text: '$v',
          style: TextStyle(color: labelColor, fontSize: 9),
        ),
        textDirection: TextDirection.ltr,
      )
      ..layout()
      ..paint(canvas, Offset(left + i * patchW + 2, top + patchH + 4));
  }
}

/// Four quadrants of fine 1-device-pixel patterns to show inversion artifacts.
class PixelInversionPainter extends CustomPainter {
  const PixelInversionPainter(this.devicePixelRatio);

  final double devicePixelRatio;

  @override
  void paint(Canvas canvas, Size size) {
    final cell = 1.0 / devicePixelRatio;
    final hw = size.width / 2;
    final hh = size.height / 2;
    const black = Color(0xFF000000);
    const white = Color(0xFFFFFFFF);
    final paint = Paint()..isAntiAlias = false;
    // TL: horizontal 1px lines.
    for (var y = 0.0; y < hh; y += cell) {
      paint.color = ((y / cell).round() & 1) == 0 ? white : black;
      canvas.drawRect(Rect.fromLTWH(0, y, hw, cell), paint);
    }
    // TR: vertical 1px lines.
    for (var x = hw; x < size.width; x += cell) {
      paint.color = (((x - hw) / cell).round() & 1) == 0 ? white : black;
      canvas.drawRect(Rect.fromLTWH(x, 0, cell, hh), paint);
    }
    // BL: 1px checkerboard.
    final cols = (hw / cell).ceil();
    final rows = (hh / cell).ceil();
    for (var y = 0; y < rows; y++) {
      for (var x = 0; x < cols; x++) {
        paint.color = ((x + y) & 1) == 0 ? white : black;
        canvas.drawRect(
          Rect.fromLTWH(x * cell, hh + y * cell, cell, cell),
          paint,
        );
      }
    }
    // BR: 2px dot pattern — single white dots on black with 1px gaps.
    canvas.drawRect(
      Rect.fromLTWH(hw, hh, hw, hh),
      paint..color = black,
    );
    paint.color = white;
    for (var y = 0; y < (hh / (cell * 2)).ceil(); y++) {
      for (var x = 0; x < (hw / (cell * 2)).ceil(); x++) {
        canvas.drawRect(
          Rect.fromLTWH(hw + x * cell * 2, hh + y * cell * 2, cell, cell),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(PixelInversionPainter old) =>
      old.devicePixelRatio != devicePixelRatio;
}
