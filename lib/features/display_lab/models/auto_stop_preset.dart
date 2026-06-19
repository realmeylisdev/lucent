/// Auto-stop timer presets for the Pixel Fixer. The fixer stops itself after
/// the chosen duration (manual stop still works at any time).
enum AutoStopPreset {
  /// No auto-stop — the fixer runs until stopped manually.
  off(0, 'Off'),

  /// Stop after 10 minutes.
  tenMin(10, '10 min'),

  /// Stop after 30 minutes.
  thirtyMin(30, '30 min'),

  /// Stop after 60 minutes.
  sixtyMin(60, '60 min');

  const AutoStopPreset(this.minutes, this.label);

  /// Duration in whole minutes (0 == off).
  final int minutes;

  /// Human-readable label for the selector chip.
  final String label;

  /// Duration in seconds (0 == off).
  int get seconds => minutes * 60;

  /// Resolves a persisted minute count back to a preset, falling back to
  /// [AutoStopPreset.off] for unknown values (e.g. stale prefs).
  static AutoStopPreset fromMinutes(int minutes) => values.firstWhere(
    (preset) => preset.minutes == minutes,
    orElse: () => AutoStopPreset.off,
  );
}
