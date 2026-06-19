import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:lucent/core/services/global_hotkey_service.dart';
import 'package:lucent/core/services/tray_service.dart';
import 'package:lucent/features/accessibility/cubit/accessibility_cubit.dart';
import 'package:lucent/features/cleaning/cubit/cleaning_cubit.dart';
import 'package:lucent/features/cleaning/view/cleaning_page.dart';
import 'package:lucent/features/display_lab/view/display_lab_page.dart';
import 'package:lucent/features/display_lab/view/pixel_fixer_page.dart';
import 'package:lucent/features/home/view/home_page.dart';
import 'package:lucent/features/settings/cubit/settings_cubit.dart';
import 'package:lucent/features/settings/view/settings_page.dart';
import 'package:window_manager/window_manager.dart';

/// Hosts the home screen and activates the desktop chrome — the menu-bar / tray
/// item and the global start-cleaning hotkey — once the first frame is ready.
///
/// Tray/hotkey callbacks route to the same flows the home screen uses. This
/// widget sits beneath the app's providers and the root [Navigator], so both
/// `context.read` and `Navigator.of(context)` resolve correctly here.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  TrayService? _tray;
  GlobalHotkeyService? _hotkeys;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_activateChrome());
    });
  }

  Future<void> _activateChrome() async {
    if (!mounted) return;
    _tray = context.read<TrayService>();
    _hotkeys = context.read<GlobalHotkeyService>();

    await _tray!.init(
      TrayCallbacks(
        onStartCleaning: _startCleaning,
        onDisplayLab: _openDisplayLab,
        onPixelFixer: _openPixelFixer,
        onSettings: _openSettings,
        onQuit: _quit,
      ),
    );

    if (!mounted) return;
    final spec = context.read<SettingsCubit>().state.settings.hotkey;
    final hotKey = parseHotKey(spec);
    if (hotKey != null) {
      await _hotkeys!.register(hotKey, onPressed: _startCleaning);
    }
  }

  @override
  void dispose() {
    unawaited(_hotkeys?.unregister());
    unawaited(_tray?.dispose());
    super.dispose();
  }

  Future<void> _startCleaning() async {
    if (!mounted) return;
    final cleaning = context.read<CleaningCubit>();
    if (cleaning.state.status == CleaningStatus.cleaning) return;

    if (!context.read<AccessibilityCubit>().state.isGranted) {
      // Can't lock without permission — surface the window + onboarding card.
      await windowManager.show();
      await windowManager.focus();
      return;
    }

    final settings = context.read<SettingsCubit>().state.settings;
    await cleaning.start(settings);
    if (!mounted) return;
    await Navigator.of(context).push(CleaningPage.route());
  }

  Future<void> _openDisplayLab() async {
    if (!mounted) return;
    await windowManager.show();
    if (!mounted) return;
    await Navigator.of(context).push(DisplayLabPage.route());
  }

  Future<void> _openPixelFixer() async {
    if (!mounted) return;
    await windowManager.show();
    if (!mounted) return;
    await Navigator.of(context).push(PixelFixerPage.route());
  }

  Future<void> _openSettings() async {
    if (!mounted) return;
    await windowManager.show();
    if (!mounted) return;
    await Navigator.of(context).push(SettingsPage.route());
  }

  Future<void> _quit() async {
    await _hotkeys?.unregister();
    await _tray?.dispose();
    await windowManager.destroy();
  }

  /// Re-register the global hotkey live after the user changes it in settings.
  Future<void> _reregisterHotkey(String spec) async {
    final hotkeys = _hotkeys;
    if (hotkeys == null) return; // Chrome not activated yet.
    final hotKey = parseHotKey(spec);
    if (hotKey == null) {
      await hotkeys.unregister();
      return;
    }
    await hotkeys.register(hotKey, onPressed: _startCleaning);
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<SettingsCubit, SettingsState>(
      listenWhen: (prev, curr) => prev.settings.hotkey != curr.settings.hotkey,
      listener: (context, state) =>
          unawaited(_reregisterHotkey(state.settings.hotkey)),
      child: const HomePage(),
    );
  }
}

/// Parses a hotkey spec like `ctrl+alt+l` into a [HotKey], or null if invalid.
///
/// Modifiers: `ctrl`/`control`, `alt`/`opt`/`option`, `shift`,
/// `cmd`/`meta`/`super`/`win`. The final single-letter token is the key.
HotKey? parseHotKey(String spec) {
  final modifiers = <HotKeyModifier>[];
  PhysicalKeyboardKey? key;
  for (final raw in spec.toLowerCase().split('+')) {
    switch (raw.trim()) {
      case 'ctrl' || 'control':
        modifiers.add(HotKeyModifier.control);
      case 'alt' || 'opt' || 'option':
        modifiers.add(HotKeyModifier.alt);
      case 'shift':
        modifiers.add(HotKeyModifier.shift);
      case 'cmd' || 'meta' || 'super' || 'win':
        modifiers.add(HotKeyModifier.meta);
      case final token when token.length == 1:
        final code = token.codeUnitAt(0);
        if (code >= 0x61 && code <= 0x7a) {
          // a-z map to sequential USB HID usages (keyA = 0x00070004).
          key = PhysicalKeyboardKey(0x00070004 + (code - 0x61));
        }
    }
  }
  if (key == null) return null;
  return HotKey(key: key, modifiers: modifiers.isEmpty ? null : modifiers);
}

/// Serializes a [HotKey] back to the `ctrl+alt+l` token format consumed by
/// [parseHotKey]. The strict inverse: modifiers emit in a canonical order
/// (ctrl, alt, shift, cmd) and the single a-z letter key comes last.
///
/// Returns null when the recorded combo has no single a-z letter key (e.g.
/// modifiers-only, F-keys, digits) — [parseHotKey] cannot round-trip those, so
/// the UI uses the null to reject the combo.
String? formatHotKey(HotKey hotKey) {
  final modifiers = hotKey.modifiers ?? const <HotKeyModifier>[];
  final parts = <String>[];
  // Emit in a fixed canonical order so the token is stable across record
  // cycles regardless of the order the recorder reported the modifiers in.
  if (modifiers.contains(HotKeyModifier.control)) parts.add('ctrl');
  if (modifiers.contains(HotKeyModifier.alt)) parts.add('alt');
  if (modifiers.contains(HotKeyModifier.shift)) parts.add('shift');
  if (modifiers.contains(HotKeyModifier.meta)) parts.add('cmd');
  // capsLock / fn are unsupported by parseHotKey and intentionally dropped.
  final offset = hotKey.physicalKey.usbHidUsage - 0x00070004; // keyA == 0.
  if (offset < 0 || offset > 25) return null;
  parts.add(String.fromCharCode(0x61 + offset)); // a-z.
  return parts.join('+');
}
