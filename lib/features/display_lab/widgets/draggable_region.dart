import 'package:flutter/material.dart';
import 'package:lucent/features/display_lab/cubit/pixel_fixer_cubit.dart';

/// Renders the confined color-cycling rectangle over a solid-black backdrop.
///
/// The page is non-locking, so normal Flutter gestures apply: drag the body to
/// move the region, drag the bottom-right handle to resize it. The black
/// outside area doubles as a "park" so a stuck pixel just outside the box is
/// left dark. Border + handle are low-contrast and only shown while [editable]
/// so a long unattended run shows nothing but the cycling rectangle on black.
class DraggableRegion extends StatelessWidget {
  const DraggableRegion({
    required this.region,
    required this.color,
    required this.bounds,
    required this.editable,
    required this.onChanged,
    required this.onChangeEnd,
    super.key,
  });

  /// Current region rectangle in logical screen-space px.
  final Rect region;

  /// The cycling fill color for the current frame.
  final Color color;

  /// Live layout size used to clamp moves/resizes within the screen.
  final Size bounds;

  /// Whether chrome (border + handle) shows and gestures are interactive.
  final bool editable;

  /// Called on every pan update with the new clamped rect (no persistence).
  final ValueChanged<Rect> onChanged;

  /// Called on pan end so the cubit persists the final rect.
  final VoidCallback onChangeEnd;

  static const double _handleSize = 28;

  @override
  Widget build(BuildContext context) {
    final clamped = clampRectToBounds(region, bounds);
    return Stack(
      children: [
        const Positioned.fill(child: ColoredBox(color: Color(0xFF000000))),
        Positioned(
          left: clamped.left,
          top: clamped.top,
          width: clamped.width,
          height: clamped.height,
          child: MouseRegion(
            cursor: editable ? SystemMouseCursors.move : MouseCursor.defer,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanUpdate: editable
                  ? (details) => onChanged(
                      clampRectToBounds(
                        clamped.shift(details.delta),
                        bounds,
                      ),
                    )
                  : null,
              onPanEnd: editable ? (_) => onChangeEnd() : null,
              child: Stack(
                children: [
                  Positioned.fill(child: ColoredBox(color: color)),
                  if (editable)
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.25),
                          ),
                        ),
                      ),
                    ),
                  if (editable)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: _ResizeHandle(
                        size: _handleSize,
                        bounds: bounds,
                        rect: clamped,
                        onChanged: onChanged,
                        onChangeEnd: onChangeEnd,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ResizeHandle extends StatelessWidget {
  const _ResizeHandle({
    required this.size,
    required this.bounds,
    required this.rect,
    required this.onChanged,
    required this.onChangeEnd,
  });

  final double size;
  final Size bounds;
  final Rect rect;
  final ValueChanged<Rect> onChanged;
  final VoidCallback onChangeEnd;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.resizeDownRight,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanUpdate: (details) {
          // Top-left stays anchored; grow width/height by the drag delta.
          final next = Rect.fromLTWH(
            rect.left,
            rect.top,
            rect.width + details.delta.dx,
            rect.height + details.delta.dy,
          );
          onChanged(clampRectToBounds(next, bounds));
        },
        onPanEnd: (_) => onChangeEnd(),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.5),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(8),
            ),
          ),
          child: const Icon(
            Icons.open_in_full,
            size: 16,
            color: Colors.black54,
          ),
        ),
      ),
    );
  }
}
