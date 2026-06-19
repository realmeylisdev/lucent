import 'package:lucent/features/cleaning/models/cleaning_mode.dart';
import 'package:lucent/features/settings/model/lucent_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists [LucentSettings] via shared_preferences.
class SettingsRepository {
  SettingsRepository(this._prefs);

  final SharedPreferences _prefs;

  static const _kUnlockKey = 'unlock_key';
  static const _kUnlockHoldMs = 'unlock_hold_ms';
  static const _kPointerLock = 'pointer_lock';
  static const _kBrightnessBoost = 'brightness_boost';
  static const _kBackgroundColor = 'background_color';
  static const _kAutoStart = 'auto_start';
  static const _kStartInCleaning = 'start_in_cleaning';
  static const _kCountdownSeconds = 'countdown_seconds';
  static const _kHotkey = 'hotkey';
  static const _kCleaningMode = 'cleaning_mode';
  static const _kGuidedWipe = 'guided_wipe';

  LucentSettings _cache = LucentSettings.defaults;

  LucentSettings get value => _cache;

  Future<LucentSettings> load() async {
    return _cache = LucentSettings(
      unlockKey:
          _prefs.getString(_kUnlockKey) ?? LucentSettings.defaults.unlockKey,
      unlockHoldMs:
          _prefs.getInt(_kUnlockHoldMs) ?? LucentSettings.defaults.unlockHoldMs,
      pointerLock:
          _prefs.getBool(_kPointerLock) ?? LucentSettings.defaults.pointerLock,
      brightnessBoost:
          _prefs.getBool(_kBrightnessBoost) ??
          LucentSettings.defaults.brightnessBoost,
      backgroundColor:
          _prefs.getInt(_kBackgroundColor) ??
          LucentSettings.defaults.backgroundColor,
      autoStart:
          _prefs.getBool(_kAutoStart) ?? LucentSettings.defaults.autoStart,
      startInCleaning:
          _prefs.getBool(_kStartInCleaning) ??
          LucentSettings.defaults.startInCleaning,
      countdownSeconds:
          _prefs.getInt(_kCountdownSeconds) ??
          LucentSettings.defaults.countdownSeconds,
      hotkey: _prefs.getString(_kHotkey) ?? LucentSettings.defaults.hotkey,
      cleaningMode: CleaningMode.fromToken(_prefs.getString(_kCleaningMode)),
      guidedWipe:
          _prefs.getBool(_kGuidedWipe) ?? LucentSettings.defaults.guidedWipe,
    );
  }

  Future<void> save(LucentSettings settings) async {
    _cache = settings;
    await _prefs.setString(_kUnlockKey, settings.unlockKey);
    await _prefs.setInt(_kUnlockHoldMs, settings.unlockHoldMs);
    await _prefs.setBool(_kPointerLock, settings.pointerLock);
    await _prefs.setBool(_kBrightnessBoost, settings.brightnessBoost);
    await _prefs.setInt(_kBackgroundColor, settings.backgroundColor);
    await _prefs.setBool(_kAutoStart, settings.autoStart);
    await _prefs.setBool(_kStartInCleaning, settings.startInCleaning);
    await _prefs.setInt(_kCountdownSeconds, settings.countdownSeconds);
    await _prefs.setString(_kHotkey, settings.hotkey);
    await _prefs.setString(_kCleaningMode, settings.cleaningMode.token);
    await _prefs.setBool(_kGuidedWipe, settings.guidedWipe);
  }
}
