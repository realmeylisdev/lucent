/// Surface + guidance style for a cleaning session. All modes lock keyboard
/// + pointer; the mode only changes the on-screen surface and copy.
enum CleaningMode {
  screen('screen', 'Screen', 'Wiping the display'),
  keyboard('keyboard', 'Keyboard', 'Wiping the keys'),
  full('full', 'Full', 'Lock everything');

  const CleaningMode(this.token, this.label, this.blurb);

  /// Wire/persistence token.
  final String token;
  final String label;
  final String blurb;

  /// Guided-wipe coverage only makes sense when the surface IS the screen.
  bool get supportsGuidedWipe =>
      this == CleaningMode.screen || this == CleaningMode.full;

  static CleaningMode fromToken(String? token) => values.firstWhere(
    (m) => m.token == token,
    orElse: () => CleaningMode.full,
  );
}
