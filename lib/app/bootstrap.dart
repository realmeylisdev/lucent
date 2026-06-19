import 'package:flutter/widgets.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:lucent/app/app.dart';
import 'package:lucent/core/platform/native_lock_controller.dart';
import 'package:lucent/core/services/auto_start_service.dart';
import 'package:lucent/core/services/brightness_service.dart';
import 'package:lucent/core/services/global_hotkey_service.dart';
import 'package:lucent/core/services/multi_monitor_cover.dart';
import 'package:lucent/core/services/tray_service.dart';
import 'package:lucent/features/settings/data/settings_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';

/// Wires up every desktop subsystem and dependency, then runs [LucentApp].
///
/// All collaborators are constructed here and injected via constructors
/// (VGV dependency-injection convention) — nothing reaches out to a global.
Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();

  await windowManager.ensureInitialized();
  await hotKeyManager.unregisterAll();

  const windowOptions = WindowOptions(
    size: Size(720, 560),
    center: true,
    title: 'Lucent',
    minimumSize: Size(560, 460),
  );
  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });

  final prefs = await SharedPreferences.getInstance();
  final settingsRepository = SettingsRepository(prefs);
  await settingsRepository.load();

  final nativeLock = NativeLockController();
  final monitorCover = MultiMonitorCover();
  final brightness = BrightnessService();
  final autoStart = AutoStartService();
  final hotkeys = GlobalHotkeyService();
  final tray = TrayService();

  runApp(
    LucentApp(
      settingsRepository: settingsRepository,
      nativeLock: nativeLock,
      monitorCover: monitorCover,
      brightness: brightness,
      autoStart: autoStart,
      hotkeys: hotkeys,
      tray: tray,
    ),
  );
}
