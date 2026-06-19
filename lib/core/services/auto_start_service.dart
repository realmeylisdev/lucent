import 'package:launch_at_startup/launch_at_startup.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Wraps `launch_at_startup` so the SettingsCubit can toggle start-on-login.
class AutoStartService {
  bool _initialized = false;

  Future<void> _ensureInit() async {
    if (_initialized) return;
    final info = await PackageInfo.fromPlatform();
    launchAtStartup.setup(
      appName: info.appName.isEmpty ? 'Lucent' : info.appName,
      appPath: info.packageName,
    );
    _initialized = true;
  }

  Future<bool> isEnabled() async {
    await _ensureInit();
    return launchAtStartup.isEnabled();
  }

  Future<void> setEnabled(bool enabled) async {
    await _ensureInit();
    if (enabled) {
      await launchAtStartup.enable();
    } else {
      await launchAtStartup.disable();
    }
  }
}
