import 'package:flutter/material.dart';

/// Full-screen patterns used for smudge hunting and dead/stuck-pixel detection.
///
/// Uniform bright fields (white/gray) reveal smudges and dust; saturated
/// primaries (red/green/blue) and black expose dead or stuck sub-pixels;
/// gradients help spot banding.
enum TestPattern {
  white('White', BoxDecoration(color: Colors.white)),
  red('Red', BoxDecoration(color: Color(0xFFFF0000))),
  green('Green', BoxDecoration(color: Color(0xFF00FF00))),
  blue('Blue', BoxDecoration(color: Color(0xFF0000FF))),
  cyan('Cyan', BoxDecoration(color: Color(0xFF00FFFF))),
  magenta('Magenta', BoxDecoration(color: Color(0xFFFF00FF))),
  yellow('Yellow', BoxDecoration(color: Color(0xFFFFFF00))),
  gray('Gray', BoxDecoration(color: Color(0xFF808080))),
  black('Black', BoxDecoration(color: Colors.black)),
  gradientGray(
    'Gradient (gray)',
    BoxDecoration(
      gradient: LinearGradient(colors: [Colors.black, Colors.white]),
    ),
  ),
  gradientSpectrum(
    'Gradient (spectrum)',
    BoxDecoration(
      gradient: LinearGradient(
        colors: [
          Color(0xFFFF0000),
          Color(0xFFFFFF00),
          Color(0xFF00FF00),
          Color(0xFF00FFFF),
          Color(0xFF0000FF),
          Color(0xFFFF00FF),
        ],
      ),
    ),
  );

  const TestPattern(this.label, this.decoration);

  /// Human-readable name shown in the pattern hint overlay.
  final String label;

  /// Decoration painted full-screen. Solids and gradients both fit here.
  final BoxDecoration decoration;

  /// Next pattern in the cycle (wraps around).
  TestPattern get next => values[(index + 1) % values.length];

  /// Previous pattern in the cycle (wraps around).
  TestPattern get previous =>
      values[(index - 1 + values.length) % values.length];
}
