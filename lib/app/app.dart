import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucent/app/desktop_chrome.dart';
import 'package:lucent/app/theme.dart';
import 'package:lucent/core/platform/native_lock_controller.dart';
import 'package:lucent/core/services/auto_start_service.dart';
import 'package:lucent/core/services/brightness_service.dart';
import 'package:lucent/core/services/global_hotkey_service.dart';
import 'package:lucent/core/services/multi_monitor_cover.dart';
import 'package:lucent/core/services/tray_service.dart';
import 'package:lucent/features/accessibility/cubit/accessibility_cubit.dart';
import 'package:lucent/features/cleaning/cubit/cleaning_cubit.dart';
import 'package:lucent/features/settings/cubit/settings_cubit.dart';
import 'package:lucent/features/settings/data/settings_repository.dart';

/// Root widget: provides repositories + cubits and hosts the desktop chrome
/// (tray, global hotkey) once the first frame is ready.
class LucentApp extends StatelessWidget {
  const LucentApp({
    required this.settingsRepository,
    required this.nativeLock,
    required this.monitorCover,
    required this.brightness,
    required this.autoStart,
    required this.hotkeys,
    required this.tray,
    super.key,
  });

  final SettingsRepository settingsRepository;
  final NativeLockController nativeLock;
  final MultiMonitorCover monitorCover;
  final BrightnessService brightness;
  final AutoStartService autoStart;
  final GlobalHotkeyService hotkeys;
  final TrayService tray;

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider.value(value: settingsRepository),
        RepositoryProvider.value(value: nativeLock),
        RepositoryProvider.value(value: monitorCover),
        RepositoryProvider.value(value: brightness),
        RepositoryProvider.value(value: autoStart),
        RepositoryProvider.value(value: hotkeys),
        RepositoryProvider.value(value: tray),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (_) => SettingsCubit(
              repository: settingsRepository,
              autoStart: autoStart,
            )..hydrate(),
          ),
          BlocProvider(
            create: (_) {
              final cubit = AccessibilityCubit(nativeLock: nativeLock);
              unawaited(cubit.refresh());
              return cubit;
            },
          ),
          BlocProvider(
            create: (context) => CleaningCubit(
              nativeLock: nativeLock,
              monitorCover: monitorCover,
              brightness: brightness,
            ),
          ),
        ],
        child: BlocBuilder<SettingsCubit, SettingsState>(
          builder: (context, state) => MaterialApp(
            title: 'Lucent',
            debugShowCheckedModeBanner: false,
            theme: LucentTheme.light,
            darkTheme: LucentTheme.dark,
            themeMode: state.settings.themeModeEnum,
            home: const AppShell(),
          ),
        ),
      ),
    );
  }
}
