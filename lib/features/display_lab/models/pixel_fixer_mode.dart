import 'dart:ui';

/// Strategies the stuck-pixel exerciser uses to drive sub-pixels on and off.
enum PixelFixerMode {
  /// Hard-cuts through black/white/R/G/B to toggle every sub-pixel.
  rgbCycle('RGB Cycle'),

  /// Alternates full white and black to flush stuck cells.
  whiteFlash('White Flash'),

  /// Per-frame random solids for a less rhythmic stimulus.
  noise('Noise');

  const PixelFixerMode(this.label);

  /// Human-readable name for the mode selector.
  final String label;

  /// Fixed color sequence each mode cycles through, one color per frame.
  ///
  /// Hard cuts (no fades) are intentional — they exercise sub-pixels best.
  List<Color> get sequence => switch (this) {
    PixelFixerMode.rgbCycle => const [
      Color(0xFF000000),
      Color(0xFFFFFFFF),
      Color(0xFFFF0000),
      Color(0xFF00FF00),
      Color(0xFF0000FF),
      Color(0xFFFF0000),
      Color(0xFF00FF00),
      Color(0xFF0000FF),
    ],
    PixelFixerMode.whiteFlash => const [
      Color(0xFF000000),
      Color(0xFFFFFFFF),
    ],
    PixelFixerMode.noise => const [
      Color(0xFFFF0000),
      Color(0xFF00FF00),
      Color(0xFF0000FF),
      Color(0xFFFFFF00),
      Color(0xFF00FFFF),
      Color(0xFFFF00FF),
      Color(0xFFFFFFFF),
      Color(0xFF000000),
    ],
  };

  /// Color shown on frame [frame] for this mode.
  Color colorForFrame(int frame) {
    final seq = sequence;
    return seq[frame % seq.length];
  }
}
