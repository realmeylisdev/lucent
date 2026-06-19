import 'package:lucent/features/display_lab/models/lab_pattern.dart';

/// Static catalog of every Display Lab inspection pattern.
///
/// [all] is the flat, ordered list the full-screen viewer cycles through with
/// next/previous (wrapping). [byCategory] groups them for the menu grid.
abstract final class LabPatternCatalog {
  /// Every pattern, grouped by category in declaration order.
  static const List<LabPattern> all = [
    // ---- Solids ----------------------------------------------------------
    LabPattern(
      id: 'solidWhite',
      label: 'Solid White',
      category: LabPatternCategory.solids,
      purpose: 'Reveals smudges, dust, dimming, and dark/dead sub-pixels.',
      kind: LabPatternKind.solid,
      value: 0xFFFFFFFF,
      nominalBackground: 0xFFFFFFFF,
    ),
    LabPattern(
      id: 'solidBlack',
      label: 'Solid Black',
      category: LabPatternCategory.solids,
      purpose: 'Exposes stuck/lit sub-pixels, backlight bleed, and clouding.',
      kind: LabPatternKind.solid,
      value: 0xFF000000,
    ),
    LabPattern(
      id: 'solidRed',
      label: 'Solid Red',
      category: LabPatternCategory.solids,
      purpose: 'Isolates the red sub-pixel layer for dead/stuck red cells.',
      kind: LabPatternKind.solid,
      value: 0xFFFF0000,
      nominalBackground: 0xFFFF0000,
    ),
    LabPattern(
      id: 'solidGreen',
      label: 'Solid Green',
      category: LabPatternCategory.solids,
      purpose: 'Isolates green sub-pixels — best field for any anomaly.',
      kind: LabPatternKind.solid,
      value: 0xFF00FF00,
      nominalBackground: 0xFF00FF00,
    ),
    LabPattern(
      id: 'solidBlue',
      label: 'Solid Blue',
      category: LabPatternCategory.solids,
      purpose: 'Isolates blue sub-pixels and reveals blue-channel mura.',
      kind: LabPatternKind.solid,
      value: 0xFF0000FF,
      nominalBackground: 0xFF0000FF,
    ),
    LabPattern(
      id: 'solidCyan',
      label: 'Solid Cyan',
      category: LabPatternCategory.solids,
      purpose: 'Lights green+blue; cross-checks red sub-pixel faults.',
      kind: LabPatternKind.solid,
      value: 0xFF00FFFF,
      nominalBackground: 0xFF00FFFF,
    ),
    LabPattern(
      id: 'solidMagenta',
      label: 'Solid Magenta',
      category: LabPatternCategory.solids,
      purpose: 'Lights red+blue; cross-checks green sub-pixel faults.',
      kind: LabPatternKind.solid,
      value: 0xFFFF00FF,
      nominalBackground: 0xFFFF00FF,
    ),
    LabPattern(
      id: 'solidYellow',
      label: 'Solid Yellow',
      category: LabPatternCategory.solids,
      purpose: 'Lights red+green; sensitive to color-temperature tint.',
      kind: LabPatternKind.solid,
      value: 0xFFFFFF00,
      nominalBackground: 0xFFFFFF00,
    ),
    LabPattern(
      id: 'solidGray50',
      label: '50% Gray',
      category: LabPatternCategory.solids,
      purpose: 'Neutral mid-tone reveals tint/cast and non-uniformity.',
      kind: LabPatternKind.solid,
      value: 0xFF808080,
      nominalBackground: 0xFF808080,
    ),
    // ---- Grayscale -------------------------------------------------------
    LabPattern(
      id: 'grayscaleStaircase16',
      label: 'Grayscale Staircase (16)',
      category: LabPatternCategory.grayscale,
      purpose: 'Checks black/white levels and gamma across 16 steps.',
      kind: LabPatternKind.grayscaleStaircase,
      value: 16,
    ),
    LabPattern(
      id: 'grayscaleStaircase32',
      label: 'Grayscale Staircase (32)',
      category: LabPatternCategory.grayscale,
      purpose: 'Finer luminance steps expose gamma kinks and posterization.',
      kind: LabPatternKind.grayscaleStaircase,
      value: 32,
    ),
    // ---- Color Bars ------------------------------------------------------
    LabPattern(
      id: 'smpteColorBars',
      label: 'SMPTE Color Bars (75%)',
      category: LabPatternCategory.colorBars,
      purpose: 'Reference bars + PLUGE for color order and black level.',
      kind: LabPatternKind.smpteColorBars,
    ),
    LabPattern(
      id: 'rgbColorBars100',
      label: 'RGB Color Bars (100%)',
      category: LabPatternCategory.colorBars,
      purpose: 'Full-saturation bars to check peak color and clipping.',
      kind: LabPatternKind.rgbColorBars100,
    ),
    // ---- Gamma -----------------------------------------------------------
    LabPattern(
      id: 'gammaGradientHorizontal',
      label: 'Horizontal Gradient',
      category: LabPatternCategory.gamma,
      purpose: 'Reveals banding/posterization across the luminance range.',
      kind: LabPatternKind.gradientLinear,
      nominalBackground: 0xFF808080,
    ),
    LabPattern(
      id: 'gammaGradientRadial',
      label: 'Radial Gradient',
      category: LabPatternCategory.gamma,
      purpose: 'Concentric rings make gamma banding obvious off-axis.',
      kind: LabPatternKind.gradientRadial,
      nominalBackground: 0xFF808080,
    ),
    LabPattern(
      id: 'gammaCalibration22',
      label: 'Gamma Calibration (2.2)',
      category: LabPatternCategory.gamma,
      purpose: 'Match the line patch to its swatch to verify display gamma.',
      kind: LabPatternKind.gammaCalibration,
      nominalBackground: 0xFFBABABA,
    ),
    // ---- Sharpness -------------------------------------------------------
    LabPattern(
      id: 'sharpnessCheckerboard1px',
      label: '1px Checkerboard',
      category: LabPatternCategory.sharpness,
      purpose: 'Max-frequency test for scaling softness and native res.',
      kind: LabPatternKind.checkerboard1px,
      nominalBackground: 0xFF808080,
    ),
    LabPattern(
      id: 'sharpnessTextLegibility',
      label: 'Fine Text Legibility',
      category: LabPatternCategory.sharpness,
      purpose: 'Checks small-text crispness and sub-pixel fringing.',
      kind: LabPatternKind.textLegibility,
      nominalBackground: 0xFFFFFFFF,
    ),
    LabPattern(
      id: 'inversionPixelWalk',
      label: 'Pixel-Inversion / Walk',
      category: LabPatternCategory.sharpness,
      purpose: 'Fine patterns shimmer on panels with inversion defects.',
      kind: LabPatternKind.pixelInversion,
      nominalBackground: 0xFF808080,
    ),
    // ---- Geometry --------------------------------------------------------
    LabPattern(
      id: 'geometryGrid',
      label: 'Alignment Grid + Crosshair',
      category: LabPatternCategory.geometry,
      purpose: 'Checks linearity, centering, and aspect-ratio roundness.',
      kind: LabPatternKind.alignmentGrid,
    ),
    LabPattern(
      id: 'geometryOverscan',
      label: 'Overscan / Edge Markers',
      category: LabPatternCategory.geometry,
      purpose: 'Nested frames reveal cropped or overscanned edges.',
      kind: LabPatternKind.overscan,
    ),
    // ---- Uniformity ------------------------------------------------------
    LabPattern(
      id: 'uniformityFlat25',
      label: 'Uniformity Flat — 25%',
      category: LabPatternCategory.uniformity,
      purpose: 'Low-level flat field surfaces mura and clouding (DSE).',
      kind: LabPatternKind.flatField,
      value: 0xFF404040,
      nominalBackground: 0xFF404040,
    ),
    LabPattern(
      id: 'uniformityFlat50',
      label: 'Uniformity Flat — 50%',
      category: LabPatternCategory.uniformity,
      purpose: 'Mid-level flat field — most revealing for dirty-screen effect.',
      kind: LabPatternKind.flatField,
      value: 0xFF808080,
      nominalBackground: 0xFF808080,
    ),
    LabPattern(
      id: 'uniformityFlat75',
      label: 'Uniformity Flat — 75%',
      category: LabPatternCategory.uniformity,
      purpose: 'High-level flat field surfaces vignetting and corner dimming.',
      kind: LabPatternKind.flatField,
      value: 0xFFBFBFBF,
      nominalBackground: 0xFFBFBFBF,
    ),
    LabPattern(
      id: 'uniformityFlat100',
      label: 'Uniformity Flat — 100%',
      category: LabPatternCategory.uniformity,
      purpose: 'Peak-brightness field for backlight bleed and white tint.',
      kind: LabPatternKind.flatField,
      value: 0xFFFFFFFF,
      nominalBackground: 0xFFFFFFFF,
    ),
    // ---- Contrast --------------------------------------------------------
    LabPattern(
      id: 'contrastNearBlack',
      label: 'Near-Black Clipping Steps',
      category: LabPatternCategory.contrast,
      purpose: 'Shadow-detail test — low steps must stay distinct from black.',
      kind: LabPatternKind.nearBlackSteps,
    ),
    LabPattern(
      id: 'contrastNearWhite',
      label: 'Near-White Clipping Steps',
      category: LabPatternCategory.contrast,
      purpose: 'Highlight-detail test — top steps must stay below pure white.',
      kind: LabPatternKind.nearWhiteSteps,
      nominalBackground: 0xFFFFFFFF,
    ),
  ];

  /// Patterns belonging to [category], in catalog order.
  static List<LabPattern> byCategory(LabPatternCategory category) =>
      all.where((p) => p.category == category).toList();

  /// Categories that actually contain at least one pattern, in menu order.
  static List<LabPatternCategory> get categories => LabPatternCategory.values
      .where((c) => all.any((p) => p.category == c))
      .toList();
}
