import 'package:equatable/equatable.dart';

/// The eight inspection families patterns are grouped under in the menu.
enum LabPatternCategory {
  solids('Solids'),
  grayscale('Grayscale'),
  colorBars('Color Bars'),
  gamma('Gamma'),
  sharpness('Sharpness'),
  geometry('Geometry'),
  uniformity('Uniformity'),
  contrast('Contrast');

  const LabPatternCategory(this.label);

  /// Human-readable section title shown in the catalog menu.
  final String label;
}

/// Discriminator the viewer/tile use to pick the right `CustomPainter`.
///
/// Kept separate from [LabPattern] so the model stays a pure value type while
/// the painting strategy is a cheap const-comparable enum.
enum LabPatternKind {
  solid,
  grayscaleStaircase,
  smpteColorBars,
  rgbColorBars100,
  gradientLinear,
  gradientRadial,
  gammaCalibration,
  checkerboard1px,
  textLegibility,
  alignmentGrid,
  overscan,
  flatField,
  nearBlackSteps,
  nearWhiteSteps,
  pixelInversion,
}

/// Immutable description of one full-screen inspection pattern.
///
/// Carries everything the catalog grid and the full-screen viewer need: a
/// stable [id], a [label], its [category] and one-line [purpose], the painter
/// [kind], and an optional [value] the painter interprets (e.g. step count,
/// flat-field level, or a packed ARGB int for solids).
class LabPattern extends Equatable {
  const LabPattern({
    required this.id,
    required this.label,
    required this.category,
    required this.purpose,
    required this.kind,
    this.value = 0,
    this.nominalBackground = 0xFF000000,
  });

  /// Stable identifier, unique across the catalog.
  final String id;

  /// Name shown on the tile and in the hint overlay.
  final String label;

  /// Family this pattern belongs to.
  final LabPatternCategory category;

  /// One-line explanation of what the pattern reveals.
  final String purpose;

  /// Painter discriminator.
  final LabPatternKind kind;

  /// Painter-specific parameter (solid ARGB, step count, level, etc.).
  final int value;

  /// Nominal field color; the hint overlay flips text black/white against it.
  final int nominalBackground;

  @override
  List<Object?> get props => [id, label, category, purpose, kind, value];
}
