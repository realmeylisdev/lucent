part of 'settings_cubit.dart';

/// Immutable settings state wrapping the persisted [LucentSettings].
class SettingsState extends Equatable {
  const SettingsState({required this.settings, this.saving = false});

  const SettingsState.initial()
      : settings = LucentSettings.defaults,
        saving = false;

  final LucentSettings settings;
  final bool saving;

  SettingsState copyWith({LucentSettings? settings, bool? saving}) =>
      SettingsState(
        settings: settings ?? this.settings,
        saving: saving ?? this.saving,
      );

  @override
  List<Object?> get props => [settings, saving];
}
