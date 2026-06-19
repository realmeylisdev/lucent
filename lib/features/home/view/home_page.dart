import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucent/features/accessibility/cubit/accessibility_cubit.dart';
import 'package:lucent/features/cleaning/cubit/cleaning_cubit.dart';
import 'package:lucent/features/cleaning/view/cleaning_page.dart';
import 'package:lucent/features/cleaning/widgets/cleaning_mode_selector.dart';
import 'package:lucent/features/display_lab/view/display_lab_page.dart';
import 'package:lucent/features/home/widgets/accessibility_card.dart';
import 'package:lucent/features/settings/cubit/settings_cubit.dart';
import 'package:lucent/features/settings/view/settings_page.dart';

/// Landing screen: brand mark, the headline selling point (what the lock
/// blocks), a big Start Cleaning button, Display Lab, Settings, and (macOS)
/// the Accessibility-permission status with guided onboarding.
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  static const _blocks = [
    'Cmd-Q',
    'Cmd-Tab',
    'fn row',
    'globe key',
    'trackpad',
  ];

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

    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0, -0.85),
          radius: 1.3,
          colors: [Color(0xFF1B2138), Color(0xFF0E0F13)],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Padding(
                padding: const EdgeInsets.all(36),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Center(child: _BrandMark()),
                    const SizedBox(height: 20),
                    const Text(
                      'Lucent',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Lock the keyboard and wipe your screen in peace.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white60, fontSize: 15),
                    ),
                    const SizedBox(height: 20),
                    const _BlocksRow(items: _blocks),
                    const SizedBox(height: 28),
                    if (accessibility.needsGrant) ...[
                      const AccessibilityCard(),
                      const SizedBox(height: 16),
                    ],
                    BlocBuilder<SettingsCubit, SettingsState>(
                      builder: (context, state) => CleaningModeSelector(
                        value: state.settings.cleaningMode,
                        onChanged: context
                            .read<SettingsCubit>()
                            .setCleaningMode,
                      ),
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: canClean
                          ? () => _startCleaning(context)
                          : null,
                      icon: const Icon(Icons.cleaning_services_outlined),
                      label: const Text('Start Cleaning'),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () =>
                          Navigator.of(context).push(DisplayLabPage.route()),
                      icon: const Icon(Icons.tune),
                      label: const Text('Display Lab'),
                    ),
                    const SizedBox(height: 8),
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
        ),
      ),
    );
  }
}

/// The Lucent sparkle mark inside a softly glowing rounded square.
class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 84,
      height: 84,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2A3252), Color(0xFF12141C)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6C8CFF).withValues(alpha: 0.35),
            blurRadius: 28,
            spreadRadius: -4,
          ),
        ],
      ),
      child: const Icon(Icons.auto_awesome, size: 42, color: Colors.white),
    );
  }
}

/// "Locks:" followed by pills naming the keys/inputs that get swallowed —
/// the headline difference from apps that only use Flutter key handling.
class _BlocksRow extends StatelessWidget {
  const _BlocksRow({required this.items});

  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 6,
      runSpacing: 6,
      children: [
        const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock_outline, size: 14, color: Colors.white38),
            SizedBox(width: 4),
            Text(
              'Locks',
              style: TextStyle(color: Colors.white38, fontSize: 12),
            ),
          ],
        ),
        for (final item in items) _Pill(item),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white12),
      ),
      child: Text(
        label,
        style: const TextStyle(color: Colors.white70, fontSize: 12),
      ),
    );
  }
}
