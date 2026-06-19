import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucent/features/accessibility/cubit/accessibility_cubit.dart';

/// Guided onboarding card shown on macOS when Accessibility / Input-Monitoring
/// trust is missing. Opens System Settings and lets the user re-check.
class AccessibilityCard extends StatelessWidget {
  const AccessibilityCard({super.key});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<AccessibilityCubit>();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.lock_outline, color: Colors.amber),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Accessibility permission required',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Lucent uses a system-level input lock to swallow keystrokes '
              '(Cmd-Q, Cmd-Tab, fn, media keys) while you clean. macOS '
              'requires you to grant Accessibility access. Lucent ships '
              'outside the App Store specifically so this is possible.',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                FilledButton(
                  onPressed: cubit.openSettings,
                  child: const Text('Open System Settings'),
                ),
                TextButton(
                  onPressed: cubit.refresh,
                  child: const Text('Re-check'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
