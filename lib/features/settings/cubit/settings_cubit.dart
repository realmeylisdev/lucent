import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucent/core/services/auto_start_service.dart';
import 'package:lucent/features/settings/data/settings_repository.dart';
import 'package:lucent/features/settings/model/lucent_settings.dart';

part 'settings_state.dart';

/// Owns user settings; persists every mutation and propagates side effects
/// (auto-start toggle) to the relevant OS service.
class SettingsCubit extends Cubit<SettingsState> {
  SettingsCubit({
    required this._repository,
    required this._autoStart,
  }) : super(const SettingsState.initial());

  final SettingsRepository _repository;
  final AutoStartService _autoStart;

  /// Load persisted values into state at startup.
  void hydrate() => emit(SettingsState(settings: _repository.value));

  Future<void> _persist(LucentSettings next) async {
    emit(state.copyWith(settings: next, saving: true));
    await _repository.save(next);
    emit(state.copyWith(saving: false));
  }

  Future<void> setUnlockKey(String token) =>
      _persist(state.settings.copyWith(unlockKey: token));

  Future<void> setUnlockHoldMs(int ms) =>
      _persist(state.settings.copyWith(unlockHoldMs: ms));

  Future<void> setPointerLock(bool value) =>
      _persist(state.settings.copyWith(pointerLock: value));

  Future<void> setBrightnessBoost(bool value) =>
      _persist(state.settings.copyWith(brightnessBoost: value));

  Future<void> setBackgroundColor(int argb) =>
      _persist(state.settings.copyWith(backgroundColor: argb));

  Future<void> setCountdownSeconds(int seconds) =>
      _persist(state.settings.copyWith(countdownSeconds: seconds));

  Future<void> setStartInCleaning(bool value) =>
      _persist(state.settings.copyWith(startInCleaning: value));

  Future<void> setHotkey(String value) =>
      _persist(state.settings.copyWith(hotkey: value));

  Future<void> setAutoStart(bool value) async {
    await _autoStart.setEnabled(value);
    await _persist(state.settings.copyWith(autoStart: value));
  }
}
