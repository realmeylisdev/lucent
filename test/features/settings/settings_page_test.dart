import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucent/core/services/auto_start_service.dart';
import 'package:lucent/features/settings/cubit/settings_cubit.dart';
import 'package:lucent/features/settings/data/settings_repository.dart';
import 'package:lucent/features/settings/view/settings_page.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockAutoStart extends Mock implements AutoStartService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SettingsRepository repository;
  late SettingsCubit cubit;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    repository = SettingsRepository(prefs);
    await repository.load();
    cubit = SettingsCubit(repository: repository, autoStart: _MockAutoStart())
      ..hydrate();
    addTearDown(cubit.close);
  });

  Widget buildSubject() => BlocProvider<SettingsCubit>.value(
    value: cubit,
    child: const MaterialApp(home: SettingsPage()),
  );

  testWidgets('renders the section labels', (tester) async {
    // Tall surface so the whole settings ListView lays out (otherwise sections
    // below the fold are never built and can't be found).
    tester.view.physicalSize = const Size(900, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(buildSubject());
    await tester.pump();

    expect(find.text('UNLOCK'), findsOneWidget);
    expect(find.text('LOCK BEHAVIOR'), findsOneWidget);
    expect(find.text('CLEANING'), findsOneWidget);
    expect(find.text('APPEARANCE'), findsOneWidget);
    expect(find.text('LAUNCH'), findsOneWidget);
    expect(find.text('GLOBAL HOTKEY'), findsOneWidget);
  });

  testWidgets('toggling pointer lock persists to the repository', (
    tester,
  ) async {
    await tester.pumpWidget(buildSubject());
    await tester.pump();

    final before = cubit.state.settings.pointerLock;
    final toggle = find.ancestor(
      of: find.text('Lock trackpad / pointer'),
      matching: find.byType(SwitchListTile),
    );
    expect(toggle, findsOneWidget);

    await tester.tap(toggle);
    await tester.pumpAndSettle();

    expect(cubit.state.settings.pointerLock, !before);
    expect(repository.value.pointerLock, !before);
  });
}
