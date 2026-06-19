import 'package:lucent/app/bootstrap.dart';

/// Primary application entry point.
///
/// Lucent ships OUTSIDE the Mac App Store as a notarized, hardened-runtime,
/// NON-sandboxed app, because the native input lock requires an Accessibility /
/// Input-Monitoring CGEventTap (AXIsProcessTrusted), which is incompatible with
/// the App Store App Sandbox. See README for signing/notarization details.
Future<void> main() => bootstrap();
