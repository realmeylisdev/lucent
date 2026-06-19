import 'package:flutter/material.dart';

/// Calm dimmed guidance surface for keyboard cleaning mode. NOT the bright
/// cleaning color — you are wiping keys, not the display, so a glaring screen
/// would be unpleasant and reflect on the keyboard. Renders behind the shared
/// unlock ring + hint in the cleaning page.
class KeyboardGuidanceSurface extends StatelessWidget {
  const KeyboardGuidanceSurface({super.key});

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Color(0xFF0E0F13),
      child: Center(
        child: Padding(
          padding: EdgeInsets.only(bottom: 160),
          child: Icon(
            Icons.keyboard_alt_outlined,
            size: 64,
            color: Colors.white24,
          ),
        ),
      ),
    );
  }
}
