import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucent/core/platform/native_lock_controller.dart';
import 'package:lucent/core/services/auto_start_service.dart';
import 'package:lucent/core/services/brightness_service.dart';
import 'package:lucent/core/services/multi_monitor_cover.dart';
import 'package:lucent/features/accessibility/cubit/accessibility_cubit.dart';
import 'package:lucent/features/cleaning/cubit/cleaning_cubit.dart';
import 'package:lucent/features/home/view/home_page.dart';
import 'package:lucent/features/home/widgets/accessibility_card.dart';
import 'package:lucent/features/settings/cubit/settings_cubit.dart';
import 'package:lucent/features/settings/data/settings_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockNativeLock extends Mock implements NativeLockController {}

class _MockMonitorCover extends Mock implements MultiMonitorCover {}

class _MockBrightness extends Mock implements BrightnessService {}

class _MockAutoStart extends Mock implements AutoStartService {}

/// AccessibilityCubit whose state can be set directly in tests, bypassing the
/// platform-dependent refresh().
class _TestAccessibilityCubit extends AccessibilityCubit {
  _TestAccessibilityCubit() : super(nativeLock: _MockNativeLock());

  void setStatus(AccessibilityStatus status) =>
      emit(AccessibilityState(status: status));
}

/// CleaningCubit whose state can be seeded directly so the failure SnackBar can
/// be exercised deterministically without driving the real platform channels.
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

  late SettingsRepository repository;
  late SettingsCubit settingsCubit;
  late _SeedableCleaningCubit cleaningCubit;
  late _TestAccessibilityCubit accessibilityCubit;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    repository = SettingsRepository(prefs);
    await repository.load();
    settingsCubit = SettingsCubit(
      repository: repository,
      autoStart: _MockAutoStart(),
    )..hydrate();

    cleaningCubit = _SeedableCleaningCubit();
    accessibilityCubit = _TestAccessibilityCubit();
  });

  tearDown(() async {
    await settingsCubit.close();
    await cleaningCubit.close();
    await accessibilityCubit.close();
  });

  void useLargeSurface(WidgetTester tester) {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Widget buildSubject() => MultiBlocProvider(
    providers: [
      BlocProvider<SettingsCubit>.value(value: settingsCubit),
      BlocProvider<CleaningCubit>.value(value: cleaningCubit),
      BlocProvider<AccessibilityCubit>.value(value: accessibilityCubit),
    ],
    child: const MaterialApp(home: HomePage()),
  );

  testWidgets('renders with Start enabled when accessibility granted', (
    tester,
  ) async {
    useLargeSurface(tester);
    accessibilityCubit.setStatus(AccessibilityStatus.granted);
    await tester.pumpWidget(buildSubject());
    await tester.pump();

    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Start Cleaning'),
    );
    expect(button.onPressed, isNotNull);
    expect(find.byType(AccessibilityCard), findsNothing);
  });

  testWidgets('shows accessibility card + disabled Start when denied', (
    tester,
  ) async {
    useLargeSurface(tester);
    accessibilityCubit.setStatus(AccessibilityStatus.denied);
    await tester.pumpWidget(buildSubject());
    await tester.pump();

    expect(find.byType(AccessibilityCard), findsOneWidget);
    expect(find.text('Open System Settings'), findsOneWidget);

    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Start Cleaning'),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('surfaces a SnackBar when the lock fails to engage', (
    tester,
  ) async {
    useLargeSurface(tester);
    accessibilityCubit.setStatus(AccessibilityStatus.granted);
    await tester.pumpWidget(buildSubject());
    await tester.pump();

    // A failed cleaning state must surface its message to the user.
    cleaningCubit.seed(
      const CleaningState(
        status: CleaningStatus.failed,
        errorMessage:
            'Could not lock input. Grant Accessibility '
            'permission and try again.',
      ),
    );
    await tester.pump(); // process the BlocListener.
    await tester.pump(); // let the SnackBar enter.

    expect(find.textContaining('Could not lock input'), findsOneWidget);
  });

  testWidgets('has an About affordance', (tester) async {
    useLargeSurface(tester);
    accessibilityCubit.setStatus(AccessibilityStatus.granted);
    await tester.pumpWidget(buildSubject());
    await tester.pump();
    expect(find.widgetWithText(TextButton, 'About'), findsOneWidget);
  });
}
