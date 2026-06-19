import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucent/core/models/unlock_key.dart';
import 'package:lucent/features/cleaning/widgets/cleaning_mode_selector.dart';
import 'package:lucent/features/settings/cubit/settings_cubit.dart';

/// Settings screen bound to [SettingsCubit]; every change persists immediately.
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  static Route<void> route() =>
      MaterialPageRoute<void>(builder: (_) => const SettingsPage());

  static const _colors = <int>[
    0xFF000000,
    0xFF101010,
    0xFF1A1A2E,
    0xFF0E2A1E,
    0xFFFFFFFF,
  ];

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<SettingsCubit>();
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: BlocBuilder<SettingsCubit, SettingsState>(
        builder: (context, state) {
          final s = state.settings;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const _SectionLabel('Unlock'),
              ListTile(
                title: const Text('Unlock key'),
                subtitle: const Text('Hold this inside the lock to exit'),
                trailing: DropdownButton<UnlockKey>(
                  value: s.unlockKeyEnum,
                  onChanged: (v) =>
                      v == null ? null : cubit.setUnlockKey(v.token),
                  items: UnlockKey.values
                      .map(
                        (k) => DropdownMenuItem(
                          value: k,
                          child: Text(k.label),
                        ),
                      )
                      .toList(),
                ),
              ),
              ListTile(
                title: const Text('Unlock hold duration'),
                subtitle: Text(
                  '${(s.unlockHoldMs / 1000).toStringAsFixed(1)}s',
                ),
              ),
              Slider(
                value: s.unlockHoldMs.toDouble(),
                min: 1000,
                max: 5000,
                divisions: 8,
                label: '${(s.unlockHoldMs / 1000).toStringAsFixed(1)}s',
                onChanged: (v) => cubit.setUnlockHoldMs(v.round()),
              ),
              const Divider(),
              const _SectionLabel('Lock behavior'),
              SwitchListTile(
                title: const Text('Lock trackpad / pointer'),
                value: s.pointerLock,
                onChanged: cubit.setPointerLock,
              ),
              SwitchListTile(
                title: const Text('Boost brightness to max'),
                value: s.brightnessBoost,
                onChanged: cubit.setBrightnessBoost,
              ),
              const Divider(),
              const _SectionLabel('Appearance'),
              ListTile(
                title: const Text('Background color'),
                subtitle: Wrap(
                  spacing: 8,
                  children: _colors
                      .map(
                        (c) => _ColorDot(
                          argb: c,
                          selected: s.backgroundColor == c,
                          onTap: () => cubit.setBackgroundColor(c),
                        ),
                      )
                      .toList(),
                ),
              ),
              const Divider(),
              const _SectionLabel('Cleaning mode'),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: CleaningModeSelector(
                  value: s.cleaningMode,
                  onChanged: cubit.setCleaningMode,
                ),
              ),
              SwitchListTile(
                title: const Text('Guided wipe overlay'),
                subtitle: Text(
                  s.cleaningMode.supportsGuidedWipe
                      ? 'Faint grid tracks where you have wiped'
                      : 'Available in Screen / Full modes',
                ),
                value: s.guidedWipe && s.cleaningMode.supportsGuidedWipe,
                onChanged: s.cleaningMode.supportsGuidedWipe
                    ? cubit.setGuidedWipe
                    : null,
              ),
              const Divider(),
              const _SectionLabel('Timer'),
              ListTile(
                title: const Text('Auto-exit countdown'),
                subtitle: Text(
                  s.hasCountdown ? '${s.countdownSeconds}s' : 'Off',
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(value: 0, label: Text('Off')),
                    ButtonSegment(value: 15, label: Text('15s')),
                    ButtonSegment(value: 30, label: Text('30s')),
                    ButtonSegment(value: 60, label: Text('60s')),
                  ],
                  emptySelectionAllowed: true,
                  selected: const {0, 15, 30, 60}.contains(s.countdownSeconds)
                      ? {s.countdownSeconds}
                      : const <int>{},
                  showSelectedIcon: false,
                  onSelectionChanged: (v) => cubit.setCountdownSeconds(v.first),
                ),
              ),
              const Divider(),
              const _SectionLabel('Launch'),
              SwitchListTile(
                title: const Text('Start Lucent on login'),
                value: s.autoStart,
                onChanged: cubit.setAutoStart,
              ),
              SwitchListTile(
                title: const Text('Start in cleaning mode'),
                subtitle: const Text('Begin cleaning immediately on launch'),
                value: s.startInCleaning,
                onChanged: cubit.setStartInCleaning,
              ),
              const Divider(),
              const _SectionLabel('Global hotkey'),
              ListTile(
                title: const Text('Start-cleaning hotkey'),
                subtitle: Text(s.hotkey),
                trailing: const Icon(Icons.keyboard_outlined),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Text(
      text.toUpperCase(),
      style: const TextStyle(
        color: Colors.white38,
        fontSize: 12,
        letterSpacing: 1.2,
      ),
    ),
  );
}

class _ColorDot extends StatelessWidget {
  const _ColorDot({
    required this.argb,
    required this.selected,
    required this.onTap,
  });
  final int argb;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: Color(argb),
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? Colors.blueAccent : Colors.white24,
            width: selected ? 3 : 1,
          ),
        ),
      ),
    );
  }
}
