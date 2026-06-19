import 'dart:async';

import 'package:tray_manager/tray_manager.dart';

/// Callbacks the tray/menu-bar item invokes.
class TrayCallbacks {
  const TrayCallbacks({
    required this.onStartCleaning,
    required this.onDisplayLab,
    required this.onPixelFixer,
    required this.onSettings,
    required this.onQuit,
  });

  final Future<void> Function() onStartCleaning;
  final Future<void> Function() onDisplayLab;
  final Future<void> Function() onPixelFixer;
  final Future<void> Function() onSettings;
  final Future<void> Function() onQuit;
}

/// macOS menu-bar / Windows + Linux system-tray item.
class TrayService with TrayListener {
  TrayCallbacks? _callbacks;

  static const _startKey = 'start_cleaning';
  static const _labKey = 'display_lab';
  static const _pixelFixerKey = 'pixel_fixer';
  static const _settingsKey = 'settings';
  static const _quitKey = 'quit';

  /// Initialize the tray icon + menu and bind [callbacks].
  Future<void> init(TrayCallbacks callbacks) async {
    _callbacks = callbacks;
    trayManager.addListener(this);
    await trayManager.setIcon(
      'assets/tray/lucent_tray.png',
      isTemplate: true, // macOS menu-bar: tint the monochrome glyph to match.
    );
    await trayManager.setContextMenu(
      Menu(
        items: [
          MenuItem(key: _startKey, label: 'Start Cleaning'),
          MenuItem(key: _labKey, label: 'Display Lab'),
          MenuItem(key: _pixelFixerKey, label: 'Pixel Fixer'),
          MenuItem.separator(),
          MenuItem(key: _settingsKey, label: 'Settings'),
          MenuItem.separator(),
          MenuItem(key: _quitKey, label: 'Quit Lucent'),
        ],
      ),
    );
  }

  @override
  void onTrayIconMouseDown() => trayManager.popUpContextMenu();

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    final cb = _callbacks;
    if (cb == null) return;
    switch (menuItem.key) {
      case _startKey:
        unawaited(cb.onStartCleaning());
      case _labKey:
        unawaited(cb.onDisplayLab());
      case _pixelFixerKey:
        unawaited(cb.onPixelFixer());
      case _settingsKey:
        unawaited(cb.onSettings());
      case _quitKey:
        unawaited(cb.onQuit());
    }
  }

  Future<void> dispose() async {
    trayManager.removeListener(this);
    await trayManager.destroy();
  }
}
