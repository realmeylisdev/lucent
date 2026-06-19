import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:lucent/app/desktop_chrome.dart';
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
              const _SectionLabel(
                'Unlock',
                description: 'How to end a cleaning session.',
              ),
              ListTile(
                title: const Text('Unlock key'),
                subtitle: const Text(
                  'Hold this key inside the lock to exit. "Esc or Space" '
                  'accepts either.',
                ),
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
                  'Hold time before release — longer avoids accidental '
                  'exits. ${(s.unlockHoldMs / 1000).toStringAsFixed(1)}s',
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
              const _SectionLabel(
                'Lock behavior',
                description: 'What the lock blocks while cleaning.',
              ),
              SwitchListTile(
                title: const Text('Lock trackpad / pointer'),
                subtitle: const Text('Swallow trackpad and mouse input too.'),
                value: s.pointerLock,
                onChanged: cubit.setPointerLock,
              ),
              SwitchListTile(
                title: const Text('Boost brightness to max'),
                subtitle: const Text(
                  'Raise display brightness so smudges are easy to see.',
                ),
                value: s.brightnessBoost,
                onChanged: cubit.setBrightnessBoost,
              ),
              const Divider(),
              const _SectionLabel(
                'Cleaning',
                description: 'How the cleaning surface looks and behaves.',
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Which screens the cover spans.',
                  style: TextStyle(fontSize: 13),
                ),
              ),
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
              ListTile(
                title: const Text('Auto-exit countdown'),
                subtitle: Text(
                  'Automatically end after this long. Off means manual exit '
                  'only. ${s.hasCountdown ? '${s.countdownSeconds}s' : 'Off'}',
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
              const _SectionLabel(
                'Appearance',
                description:
                    "The app's look. Cleaning and Display Lab test screens "
                    'always stay dark.',
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: SegmentedButton<ThemeMode>(
                  segments: const [
                    ButtonSegment(
                      value: ThemeMode.system,
                      icon: Icon(Icons.brightness_auto_outlined),
                      label: Text('System'),
                    ),
                    ButtonSegment(
                      value: ThemeMode.light,
                      icon: Icon(Icons.light_mode_outlined),
                      label: Text('Light'),
                    ),
                    ButtonSegment(
                      value: ThemeMode.dark,
                      icon: Icon(Icons.dark_mode_outlined),
                      label: Text('Dark'),
                    ),
                  ],
                  selected: {s.themeModeEnum},
                  showSelectedIcon: false,
                  onSelectionChanged: (v) => cubit.setThemeMode(v.first.name),
                ),
              ),
              const Divider(),
              const _SectionLabel(
                'Launch',
                description: 'What happens when Lucent starts.',
              ),
              SwitchListTile(
                title: const Text('Start Lucent on login'),
                subtitle: const Text('Launch automatically when you sign in.'),
                value: s.autoStart,
                onChanged: cubit.setAutoStart,
              ),
              SwitchListTile(
                title: const Text('Start in cleaning mode'),
                subtitle: const Text(
                  'Begin a cleaning session immediately on launch.',
                ),
                value: s.startInCleaning,
                onChanged: cubit.setStartInCleaning,
              ),
              const Divider(),
              const _SectionLabel(
                'Global hotkey',
                description:
                    'Press a key combination to start cleaning from '
                    'anywhere — even when Lucent is in the background.',
              ),
              _HotkeyRecorderTile(hotkey: s.hotkey, saving: state.saving),
            ],
          );
        },
      ),
    );
  }
}

/// The press-to-record global-hotkey field plus its live state caption and a
/// low-emphasis "Reset to default" affordance.
class _HotkeyRecorderTile extends StatefulWidget {
  const _HotkeyRecorderTile({required this.hotkey, required this.saving});

  final String hotkey;
  final bool saving;

  @override
  State<_HotkeyRecorderTile> createState() => _HotkeyRecorderTileState();
}

enum _CaptionState { resting, invalid, saved }

class _HotkeyRecorderTileState extends State<_HotkeyRecorderTile> {
  static const _defaultHotkey = 'ctrl+alt+l';

  _CaptionState _caption = _CaptionState.resting;
  String _invalidMessage = '';
  Timer? _resetTimer;

  /// The HotKeyRecorder grabs ALL keystrokes while mounted, so it is only
  /// mounted during an active recording (toggled by tapping the field); the
  /// rest of the time the current combo shows as a static button.
  bool _recording = false;

  @override
  void dispose() {
    _resetTimer?.cancel();
    super.dispose();
  }

  void _onRecorded(HotKey hotKey) {
    final token = formatHotKey(hotKey);
    if (token == null || parseHotKey(token) == null) {
      // Modifiers-only or a non a-z key the parser can't round-trip.
      final modifiersOnly = (hotKey.modifiers ?? const []).isNotEmpty;
      _flashInvalid(
        modifiersOnly
            ? "Add a letter key — modifiers alone won't trigger"
            : 'Use a letter key (A–Z) with at least one modifier.',
      );
      return;
    }
    _resetTimer?.cancel();
    setState(() {
      _caption = _CaptionState.saved;
      _recording = false;
    });
    unawaited(context.read<SettingsCubit>().setHotkey(token));
    _resetTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _caption = _CaptionState.resting);
    });
  }

  void _flashInvalid(String message) {
    _resetTimer?.cancel();
    setState(() {
      _caption = _CaptionState.invalid;
      _invalidMessage = message;
    });
    _resetTimer = Timer(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => _caption = _CaptionState.resting);
    });
  }

  void _resetToDefault() {
    _resetTimer?.cancel();
    setState(() {
      _caption = _CaptionState.saved;
      _recording = false;
    });
    unawaited(context.read<SettingsCubit>().setHotkey(_defaultHotkey));
    _resetTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _caption = _CaptionState.resting);
    });
  }

  /// Humanizes a stored token into "Ctrl+Alt+L" with a platform-aware meta
  /// label (Cmd on macOS, Win elsewhere).
  String _humanize(String token) {
    final isMac = Theme.of(context).platform == TargetPlatform.macOS;
    return token
        .split('+')
        .map((part) {
          switch (part) {
            case 'ctrl':
              return 'Ctrl';
            case 'alt':
              return 'Alt';
            case 'shift':
              return 'Shift';
            case 'cmd':
              return isMac ? 'Cmd' : 'Win';
            default:
              return part.toUpperCase();
          }
        })
        .join('+');
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final borderColor = switch (_caption) {
      _CaptionState.invalid => cs.error,
      _CaptionState.saved => cs.primary,
      _CaptionState.resting => cs.outlineVariant,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          leading: const Icon(Icons.keyboard_outlined),
          title: const Text('Start-cleaning shortcut'),
          trailing: SizedBox(
            width: 230,
            child: _recording
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Expanded(
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          constraints: const BoxConstraints(minHeight: 44),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: cs.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: borderColor),
                          ),
                          // Mounted only while recording, so it never captures
                          // stray keys typed elsewhere on the settings screen.
                          child: HotKeyRecorder(
                            initalHotKey: parseHotKey(widget.hotkey),
                            onHotKeyRecorded: _onRecorded,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        tooltip: 'Cancel',
                        onPressed: () => setState(() => _recording = false),
                      ),
                    ],
                  )
                : OutlinedButton.icon(
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    label: Text(_humanize(widget.hotkey)),
                    onPressed: () => setState(() => _recording = true),
                  ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
          child: _caption == _CaptionState.invalid
              ? Text(
                  _invalidMessage,
                  style: TextStyle(fontSize: 13, color: cs.error),
                )
              : _caption == _CaptionState.saved
              ? Row(
                  children: [
                    Icon(Icons.check, size: 16, color: cs.primary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Saved — ${_humanize(widget.hotkey)} now starts '
                        'cleaning',
                        style: TextStyle(fontSize: 13, color: cs.primary),
                      ),
                    ),
                  ],
                )
              : Text(
                  _recording
                      ? 'Press a letter key with at least one modifier'
                      : 'Current: ${_humanize(widget.hotkey)} — tap to change',
                  style: TextStyle(
                    fontSize: 13,
                    color: cs.onSurfaceVariant,
                  ),
                ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: _resetToDefault,
            child: const Text('Reset to default'),
          ),
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text, {this.description});
  final String text;
  final String? description;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            text.toUpperCase(),
            style: TextStyle(
              color: cs.onSurfaceVariant,
              fontSize: 12,
              letterSpacing: 1.2,
            ),
          ),
          if (description != null) ...[
            const SizedBox(height: 4),
            Text(
              description!,
              style: TextStyle(
                color: cs.onSurfaceVariant,
                fontSize: 13,
              ),
            ),
          ],
        ],
      ),
    );
  }
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
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: Color(argb),
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? cs.primary : cs.outlineVariant,
            width: selected ? 3 : 1,
          ),
        ),
      ),
    );
  }
}
