import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucent/core/platform/native_lock_controller.dart';
import 'package:lucent/core/services/auto_start_service.dart';
import 'package:lucent/core/services/brightness_service.dart';
import 'package:lucent/core/services/multi_monitor_cover.dart';
import 'package:lucent/features/cleaning/cubit/cleaning_cubit.dart';
import 'package:lucent/features/cleaning/models/cleaning_mode.dart';
import 'package:lucent/features/cleaning/view/cleaning_page.dart';
import 'package:lucent/features/cleaning/widgets/countdown_ring.dart';
import 'package:lucent/features/cleaning/widgets/guided_wipe_overlay.dart';
import 'package:lucent/features/cleaning/widgets/keyboard_guidance_surface.dart';
import 'package:lucent/features/cleaning/widgets/unlock_ring.dart';
import 'package:lucent/features/settings/cubit/settings_cubit.dart';
import 'package:lucent/features/settings/data/settings_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockNativeLock extends Mock implements NativeLockController {}

class _MockMonitorCover extends Mock implements MultiMonitorCover {}

class _MockBrightness extends Mock implements BrightnessService {}

class _MockAutoStart extends Mock implements AutoStartService {}

/// CleaningCubit that can be seeded with an arbitrary state for view tests.
class _SeedableCleaningCubit extends CleaningCubit {
  _SeedableCleaningCubit()
    : super(
        nativeLock: _MockNativeLock(),
        monitorCover: _MockMonitorCover(),
        brightness: _MockBrightness(),
      );

  void seed(CleaningState state) => emit(state);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _SeedableCleaningCubit cleaning;
  late SettingsCubit settings;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final repo = SettingsRepository(prefs);
    await repo.load();
    settings = SettingsCubit(repository: repo, autoStart: _MockAutoStart())
      ..hydrate();
    cleaning = _SeedableCleaningCubit();
    addTearDown(settings.close);
    addTearDown(cleaning.close);
  });

  Widget buildSubject() => MultiBlocProvider(
    providers: [
      BlocProvider<CleaningCubit>.value(value: cleaning),
      BlocProvider<SettingsCubit>.value(value: settings),
    ],
    child: const MaterialApp(home: CleaningPage()),
  );

  testWidgets('full mode shows the unlock ring + hold hint', (tester) async {
    cleaning.seed(
      const CleaningState(status: CleaningStatus.cleaning),
    );
    await tester.pumpWidget(buildSubject());
    await tester.pump();

    expect(find.byType(UnlockRing), findsOneWidget);
    expect(find.text('Hold Esc to unlock'), findsOneWidget);
  });

  testWidgets('keyboard mode shows the guidance surface', (tester) async {
    cleaning.seed(
      const CleaningState(
        status: CleaningStatus.cleaning,
        mode: CleaningMode.keyboard,
      ),
    );
    await tester.pumpWidget(buildSubject());
    await tester.pump();

    expect(find.byType(KeyboardGuidanceSurface), findsOneWidget);
  });

  testWidgets('guided wipe shows the overlay and a coverage label', (
    tester,
  ) async {
    cleaning.seed(
      const CleaningState(
        status: CleaningStatus.cleaning,
        guidedWipe: true,
        gridColumns: 12,
        gridRows: 8,
        coveredCells: {0, 1, 2},
      ),
    );
    await tester.pumpWidget(buildSubject());
    await tester.pump();

    expect(find.byType(GuidedWipeOverlay), findsOneWidget);
    expect(find.textContaining('Wiped'), findsOneWidget);
  });

  testWidgets('countdown shows the countdown ring', (tester) async {
    cleaning.seed(
      const CleaningState(
        status: CleaningStatus.cleaning,
        remainingSeconds: 15,
        totalSeconds: 30,
      ),
    );
    await tester.pumpWidget(buildSubject());
    await tester.pump();

    expect(find.byType(CountdownRing), findsOneWidget);
  });

  testWidgets('pops back when the session transitions off cleaning', (
    tester,
  ) async {
    cleaning.seed(const CleaningState(status: CleaningStatus.cleaning));
    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider<CleaningCubit>.value(value: cleaning),
          BlocProvider<SettingsCubit>.value(value: settings),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).push(
                    CleaningPage.route(),
                  ),
                  child: const Text('go'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    expect(find.byType(UnlockRing), findsOneWidget);

    // Transition to failed: the page should pop back to the launcher.
    cleaning.seed(
      const CleaningState(
        status: CleaningStatus.failed,
        errorMessage: 'boom',
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(UnlockRing), findsNothing);
    expect(find.text('go'), findsOneWidget);
  });
}
