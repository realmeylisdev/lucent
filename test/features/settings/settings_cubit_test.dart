import 'package:flutter_test/flutter_test.dart';
import 'package:lucent/core/services/auto_start_service.dart';
import 'package:lucent/features/settings/cubit/settings_cubit.dart';
import 'package:lucent/features/settings/data/settings_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SettingsCubit', () {
    late SettingsRepository repository;
    late SettingsCubit cubit;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      repository = SettingsRepository(prefs);
      await repository.load();
      cubit = SettingsCubit(
        repository: repository,
        autoStart: AutoStartService(),
      )..hydrate();
    });

    tearDown(() async {
      await cubit.close();
    });

    test('setters rebase on the repo so external writes survive', () async {
      // Simulate PixelFixerCubit persisting its config straight to the repo
      // (a separate cubit writing the same shared repository).
      await repository.save(
        repository.value.copyWith(
          pixelFixerHz: 9,
          pixelFixerMode: 'whiteFlash',
        ),
      );

      // The user then changes an UNRELATED setting through SettingsCubit,
      // whose in-memory snapshot predates the pixel-fixer write.
      await cubit.setPointerLock(false);

      // The pixel-fixer config must NOT be clobbered by a stale snapshot.
      expect(repository.value.pixelFixerHz, 9);
      expect(repository.value.pixelFixerMode, 'whiteFlash');
      expect(repository.value.pointerLock, isFalse);
      expect(cubit.state.settings.pixelFixerHz, 9);
    });
  });
}
