import 'package:flutter/material.dart';
import 'package:lucent/features/display_lab/models/lab_pattern.dart';
import 'package:lucent/features/display_lab/widgets/pattern_painters.dart';

/// Catalog tile: a small card with a clipped mini-preview of the pattern's
/// painter plus its label. Tapping it enters the full-screen viewer.
class PatternTile extends StatelessWidget {
  const PatternTile({required this.pattern, required this.onTap, super.key});

  final LabPattern pattern;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ColoredBox(
                color: const Color(0xFF000000),
                child: CustomPaint(
                  painter: painterForPattern(pattern, dpr),
                  size: Size.infinite,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Text(
                pattern.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
