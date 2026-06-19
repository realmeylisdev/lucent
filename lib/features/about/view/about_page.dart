import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// About / help screen: app name, version, a one-line description, the GitHub
/// link, and the license. Reachable from the home screen.
class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  /// Pushes the About screen as a normal page.
  static Route<void> route() =>
      MaterialPageRoute<void>(builder: (_) => const AboutPage());

  static final Uri _repoUri = Uri.parse(
    'https://github.com/realmeylisdev/lucent',
  );

  static const _description =
      'A cross-platform desktop screen-cleaning utility with a real native '
      'OS-level input lock.';

  Future<void> _openRepo() async {
    try {
      await launchUrl(_repoUri, mode: LaunchMode.externalApplication);
    } on PlatformException {
      // No URL handler available; opening the link is best-effort.
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('About')),
      body: Center(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(36),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF2A3252), Color(0xFF12141C)],
                        ),
                      ),
                      child: const Icon(
                        Icons.auto_awesome,
                        size: 36,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Lucent',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: cs.onSurface,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const _VersionLabel(),
                  const SizedBox(height: 16),
                  Text(
                    _description,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: cs.onSurfaceVariant,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 24),
                  OutlinedButton.icon(
                    onPressed: () => unawaited(_openRepo()),
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('View on GitHub'),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'MIT License',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: cs.onSurfaceVariant,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Resolves the running app version asynchronously, showing a placeholder
/// until [PackageInfo.fromPlatform] completes (no crash if it never does).
class _VersionLabel extends StatelessWidget {
  const _VersionLabel();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return FutureBuilder<PackageInfo>(
      future: PackageInfo.fromPlatform(),
      builder: (context, snapshot) {
        final info = snapshot.data;
        final text = info == null
            ? 'Version …'
            : 'Version ${info.version}+${info.buildNumber}';
        return Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
        );
      },
    );
  }
}
