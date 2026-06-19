import 'package:flutter/material.dart';

/// Faint coverage grid painted over the cleaning surface (screen/full modes
/// only). A [Listener] watches bare cursor MOVEMENT (delivered when the lock
/// engaged with allowMouseMove=true) and reports the cell under the cursor via
/// [onCellCovered].
///
/// Degrades gracefully: if movement is never delivered (some platforms swallow
/// it even when requested), the grid simply renders as static guidance and
/// coverage stays at 0%. Nothing about session termination depends on it.
class GuidedWipeOverlay extends StatelessWidget {
  const GuidedWipeOverlay({
    required this.columns,
    required this.rows,
    required this.coveredCells,
    required this.onCellCovered,
    super.key,
  });

  final int columns;
  final int rows;
  final Set<int> coveredCells;
  final ValueChanged<int> onCellCovered;

  /// Inset so the grid never collides with the top-right countdown ring or the
  /// centered unlock chrome.
  static const double _inset = 24;

  void _report(Size size, Offset local) {
    if (columns <= 0 || rows <= 0) return;
    final width = size.width - _inset * 2;
    final height = size.height - _inset * 2;
    if (width <= 0 || height <= 0) return;
    final x = local.dx - _inset;
    final y = local.dy - _inset;
    if (x < 0 || y < 0 || x >= width || y >= height) return;
    final col = (x / (width / columns)).floor().clamp(0, columns - 1);
    final row = (y / (height / rows)).floor().clamp(0, rows - 1);
    onCellCovered(row * columns + col);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        return Listener(
          behavior: HitTestBehavior.translucent,
          onPointerHover: (e) => _report(size, e.localPosition),
          onPointerMove: (e) => _report(size, e.localPosition),
          child: CustomPaint(
            size: size,
            painter: _GridPainter(
              columns: columns,
              rows: rows,
              covered: coveredCells,
              inset: _inset,
            ),
          ),
        );
      },
    );
  }
}

class _GridPainter extends CustomPainter {
  _GridPainter({
    required this.columns,
    required this.rows,
    required this.covered,
    required this.inset,
  });

  final int columns;
  final int rows;
  final Set<int> covered;
  final double inset;

  @override
  void paint(Canvas canvas, Size size) {
    if (columns <= 0 || rows <= 0) return;
    final width = size.width - inset * 2;
    final height = size.height - inset * 2;
    if (width <= 0 || height <= 0) return;
    final cellW = width / columns;
    final cellH = height / rows;

    final stroke = Paint()
      ..color = Colors.white10
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final fill = Paint()
      ..color = Colors.white.withValues(alpha: 0.06)
      ..style = PaintingStyle.fill;

    for (var row = 0; row < rows; row++) {
      for (var col = 0; col < columns; col++) {
        final rect = Rect.fromLTWH(
          inset + col * cellW + 1,
          inset + row * cellH + 1,
          cellW - 2,
          cellH - 2,
        );
        final rrect = RRect.fromRectAndRadius(
          rect,
          const Radius.circular(6),
        );
        if (covered.contains(row * columns + col)) {
          canvas.drawRRect(rrect, fill);
        }
        canvas.drawRRect(rrect, stroke);
      }
    }
  }

  @override
  bool shouldRepaint(_GridPainter old) =>
      old.columns != columns ||
      old.rows != rows ||
      old.covered.length != covered.length;
}
