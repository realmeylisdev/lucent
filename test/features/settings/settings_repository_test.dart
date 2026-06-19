import 'package:flutter_test/flutter_test.dart';
import 'package:lucent/features/cleaning/models/cleaning_mode.dart';
import 'package:lucent/features/settings/data/settings_repository.dart';
import 'package:lucent/features/settings/model/lucent_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SettingsRepository', () {
    test('load returns defaults when nothing is persisted', () async {
      SharedPreferences.setMockInitialValues({});
      final repo = SettingsRepository(await SharedPreferences.getInstance());
      final loaded = await repo.load();
      expect(loaded.cleaningMode, CleaningMode.full);
      expect(loaded.guidedWipe, isFalse);
    });

    test('round-trips cleaningMode + guidedWipe through prefs', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repo = SettingsRepository(prefs);

      const next = LucentSettings.defaults;
      await repo.save(
        next.copyWith(cleaningMode: CleaningMode.keyboard, guidedWipe: true),
      );

      // A fresh repository reads the persisted primitives back.
      final reloaded = await SettingsRepository(prefs).load();
      expect(reloaded.cleaningMode, CleaningMode.keyboard);
      expect(reloaded.guidedWipe, isTrue);
    });

    test('bad mode token degrades to the default (full)', () async {
      SharedPreferences.setMockInitialValues({'cleaning_mode': 'garbage'});
      final repo = SettingsRepository(await SharedPreferences.getInstance());
      final loaded = await repo.load();
      expect(loaded.cleaningMode, CleaningMode.full);
    });

    test('round-trips the pixel-fixer config through prefs', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repo = SettingsRepository(prefs);

      await repo.save(
        LucentSettings.defaults.copyWith(
          pixelFixerMode: 'whiteFlash',
          pixelFixerHz: 8,
          pixelFixerRegionEnabled: true,
          pixelFixerRegionLeft: 40,
          pixelFixerRegionTop: 50,
          pixelFixerRegionWidth: 160,
          pixelFixerRegionHeight: 180,
          pixelFixerAutoStopMinutes: 60,
        ),
      );

      final reloaded = await SettingsRepository(prefs).load();
      expect(reloaded.pixelFixerMode, 'whiteFlash');
      expect(reloaded.pixelFixerHz, 8);
      expect(reloaded.pixelFixerRegionEnabled, isTrue);
      expect(reloaded.pixelFixerRegionLeft, 40);
      expect(reloaded.pixelFixerRegionTop, 50);
      expect(reloaded.pixelFixerRegionWidth, 160);
      expect(reloaded.pixelFixerRegionHeight, 180);
      expect(reloaded.pixelFixerAutoStopMinutes, 60);
    });

    test('pixel-fixer config falls back to defaults', () async {
      SharedPreferences.setMockInitialValues({});
      final repo = SettingsRepository(await SharedPreferences.getInstance());
      final loaded = await repo.load();
      expect(loaded.pixelFixerMode, 'rgbCycle');
      expect(loaded.pixelFixerHz, 3);
      expect(loaded.pixelFixerRegionEnabled, isFalse);
      expect(loaded.pixelFixerRegionWidth, 200);
      expect(loaded.pixelFixerAutoStopMinutes, 0);
    });

    test('round-trips themeMode through prefs', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repo = SettingsRepository(prefs);

      expect((await repo.load()).themeMode, 'system');
      await repo.save(LucentSettings.defaults.copyWith(themeMode: 'dark'));

      final reloaded = await SettingsRepository(prefs).load();
      expect(reloaded.themeMode, 'dark');
    });

    test('preserves the other settings across a round-trip', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repo = SettingsRepository(prefs);

      await repo.save(
        LucentSettings.defaults.copyWith(
          countdownSeconds: 30,
          cleaningMode: CleaningMode.screen,
          guidedWipe: true,
        ),
      );

      final reloaded = await SettingsRepository(prefs).load();
      expect(reloaded.countdownSeconds, 30);
      expect(reloaded.cleaningMode, CleaningMode.screen);
      expect(reloaded.guidedWipe, isTrue);
      expect(reloaded.unlockKey, LucentSettings.defaults.unlockKey);
    });
  });
}
