import 'package:hotkey_manager/hotkey_manager.dart';

/// Registers a single global hotkey that starts cleaning from anywhere.
class GlobalHotkeyService {
  HotKey? _current;

  /// Register [hotKey], replacing any previously registered hotkey.
  /// [onPressed] fires when the hotkey is hit globally.
  Future<void> register(
    HotKey hotKey, {
    required Future<void> Function() onPressed,
  }) async {
    await unregister();
    _current = hotKey;
    await hotKeyManager.register(
      hotKey,
      keyDownHandler: (_) => onPressed(),
    );
  }

  Future<void> unregister() async {
    final current = _current;
    if (current != null) {
      await hotKeyManager.unregister(current);
      _current = null;
    }
  }
}
