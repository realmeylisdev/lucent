import 'dart:async';

import 'package:tray_manager/tray_manager.dart';

/// Callbacks the tray/menu-bar item invokes.
class TrayCallbacks {
  const TrayCallbacks({
    required this.onStartCleaning,
    required this.onDisplayTest,
    required this.onSettings,
    required this.onQuit,
  });

  final Future<void> Function() onStartCleaning;
  final Future<void> Function() onDisplayTest;
  final Future<void> Function() onSettings;
  final Future<void> Function() onQuit;
}

/// macOS menu-bar / Windows + Linux system-tray item.
class TrayService with TrayListener {
  TrayCallbacks? _callbacks;

  static const _startKey = 'start_cleaning';
  static const _testKey = 'display_test';
  static const _settingsKey = 'settings';
  static const _quitKey = 'quit';

  /// Initialize the tray icon + menu and bind [callbacks].
  Future<void> init(TrayCallbacks callbacks) async {
    _callbacks = callbacks;
    trayManager.addListener(this);
    await trayManager.setIcon(
      // Provide a platform-appropriate template icon asset in your bundle.
      'assets/tray/lucent_tray.png',
    );
    await trayManager.setContextMenu(
      Menu(
        items: [
          MenuItem(key: _startKey, label: 'Start Cleaning'),
          MenuItem(key: _testKey, label: 'Display Test'),
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
      case _testKey:
        unawaited(cb.onDisplayTest());
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
