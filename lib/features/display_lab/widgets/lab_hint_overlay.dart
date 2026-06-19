import 'package:flutter/material.dart';

/// Bottom-aligned hint shown over the full-screen viewer/fixer.
///
/// When [expanded] is true it shows [title] + [subtitle] (auto-shown for a
/// couple of seconds on each change); otherwise it fades to a faint corner
/// label so it never bakes into a uniformity judgment. The text always sits on
/// a translucent dark plate so it stays legible over ANY pattern — including
/// pure-white fields and the bright bars of color/grayscale patterns.
class LabHintOverlay extends StatelessWidget {
  const LabHintOverlay({
    required this.title,
    required this.subtitle,
    this.expanded = true,
    super.key,
  });

  final String title;
  final String subtitle;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Align(
        alignment: expanded ? Alignment.bottomCenter : Alignment.bottomLeft,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: expanded
                ? _Plate(
                    key: const ValueKey('expanded'),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  )
                : _Plate(
                    key: const ValueKey('faint'),
                    child: Text(
                      title,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 13,
                      ),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

/// Translucent dark backing plate that keeps hint text legible over any field.
class _Plate extends StatelessWidget {
  const _Plate({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        child: child,
      ),
    );
  }
}
