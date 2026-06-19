/// Key the user holds inside the native hook to end a cleaning session.
///
/// The string value is the wire token sent to the native layer, which maps it
/// to the platform key code it watches for inside the event tap.
enum UnlockKey {
  escape('escape', 'Esc'),
  space('space', 'Space');

  const UnlockKey(this.token, this.label);

  /// Token sent over the method channel to the native host.
  final String token;

  /// Human-readable label for the UI.
  final String label;

  static UnlockKey fromToken(String? token) => values.firstWhere(
        (k) => k.token == token,
        orElse: () => UnlockKey.escape,
      );
}
