import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Depleting countdown ring — the conceptual inverse of the unlock ring (the
/// arc SHRINKS toward 0 as time runs out). Shares the unlock ring's stroke,
/// cap, and 12-o'clock start angle so the two read as one family.
class CountdownRing extends StatelessWidget {
  const CountdownRing({
    required this.fraction,
    required this.secondsLeft,
    super.key,
  });

  /// 0..1 portion of the countdown still remaining.
  final double fraction;

  /// Whole seconds left, shown centered.
  final int secondsLeft;

  @override
  Widget build(BuildContext context) {
    final urgent = secondsLeft <= 5;
    final fillColor = urgent
        ? Theme.of(context).colorScheme.error.withValues(alpha: 0.85)
        : Colors.white60;
    return SizedBox(
      width: 56,
      height: 56,
      child: CustomPaint(
        painter: _CountdownPainter(fraction.clamp(0, 1), fillColor),
        child: Center(
          child: Text(
            '$secondsLeft',
            style: TextStyle(
              color: fillColor,
              fontSize: 16,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ),
    );
  }
}

class _CountdownPainter extends CustomPainter {
  _CountdownPainter(this.fraction, this.fillColor);

  final double fraction;
  final Color fillColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2 - 4;
    final track = Paint()
      ..color = Colors.white12
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;
    final fill = Paint()
      ..color = fillColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    canvas
      ..drawCircle(center, radius, track)
      ..drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        2 * math.pi * fraction,
        false,
        fill,
      );
  }

  @override
  bool shouldRepaint(_CountdownPainter old) =>
      old.fraction != fraction || old.fillColor != fillColor;
}
