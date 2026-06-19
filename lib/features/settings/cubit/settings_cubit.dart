import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucent/core/services/auto_start_service.dart';
import 'package:lucent/features/cleaning/models/cleaning_mode.dart';
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
      _persist(_repository.value.copyWith(unlockKey: token));

  Future<void> setUnlockHoldMs(int ms) =>
      _persist(_repository.value.copyWith(unlockHoldMs: ms));

  Future<void> setPointerLock(bool value) =>
      _persist(_repository.value.copyWith(pointerLock: value));

  Future<void> setBrightnessBoost(bool value) =>
      _persist(_repository.value.copyWith(brightnessBoost: value));

  Future<void> setBackgroundColor(int argb) =>
      _persist(_repository.value.copyWith(backgroundColor: argb));

  Future<void> setCountdownSeconds(int seconds) =>
      _persist(_repository.value.copyWith(countdownSeconds: seconds));

  Future<void> setStartInCleaning(bool value) =>
      _persist(_repository.value.copyWith(startInCleaning: value));

  Future<void> setHotkey(String value) =>
      _persist(_repository.value.copyWith(hotkey: value));

  Future<void> setCleaningMode(CleaningMode mode) =>
      _persist(_repository.value.copyWith(cleaningMode: mode));

  Future<void> setGuidedWipe(bool value) =>
      _persist(_repository.value.copyWith(guidedWipe: value));

  Future<void> setAutoStart(bool value) async {
    await _autoStart.setEnabled(value);
    await _persist(_repository.value.copyWith(autoStart: value));
  }
}
