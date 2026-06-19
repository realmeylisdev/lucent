import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucent/features/accessibility/cubit/accessibility_cubit.dart';
import 'package:lucent/features/cleaning/cubit/cleaning_cubit.dart';
import 'package:lucent/features/cleaning/view/cleaning_page.dart';
import 'package:lucent/features/display_test/view/display_test_page.dart';
import 'package:lucent/features/home/widgets/accessibility_card.dart';
import 'package:lucent/features/settings/cubit/settings_cubit.dart';
import 'package:lucent/features/settings/view/settings_page.dart';

/// Landing screen: big Start Cleaning button, quick Display Test, Settings,
/// and (macOS) Accessibility-permission status with guided onboarding.
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  Future<void> _startCleaning(BuildContext context) async {
    final settings = context.read<SettingsCubit>().state.settings;
    await context.read<CleaningCubit>().start(settings);
    if (context.mounted) {
      await Navigator.of(context).push(CleaningPage.route());
    }
  }

  @override
  Widget build(BuildContext context) {
    final accessibility = context.watch<AccessibilityCubit>().state;
    final canClean = accessibility.isGranted;

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Lucent',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 40, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Lock the keyboard and wipe your screen in peace.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white54),
                ),
                const SizedBox(height: 32),
                if (accessibility.needsGrant) ...[
                  const AccessibilityCard(),
                  const SizedBox(height: 16),
                ],
                FilledButton.icon(
                  onPressed: canClean ? () => _startCleaning(context) : null,
                  icon: const Icon(Icons.cleaning_services_outlined),
                  label: const Text('Start Cleaning'),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () =>
                      Navigator.of(context).push(DisplayTestPage.route()),
                  icon: const Icon(Icons.gradient_outlined),
                  label: const Text('Display Test'),
                ),
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: () =>
                      Navigator.of(context).push(SettingsPage.route()),
                  icon: const Icon(Icons.settings_outlined),
                  label: const Text('Settings'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
