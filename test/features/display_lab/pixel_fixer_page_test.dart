import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucent/features/display_lab/cubit/pixel_fixer_cubit.dart';
import 'package:lucent/features/display_lab/view/pixel_fixer_page.dart';
import 'package:lucent/features/settings/data/settings_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SettingsRepository repository;
  late PixelFixerCubit cubit;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    repository = SettingsRepository(prefs);
    await repository.load();
    cubit = PixelFixerCubit(repository: repository);
    addTearDown(cubit.close);
  });

  Widget buildSubject() => RepositoryProvider<SettingsRepository>.value(
    value: repository,
    child: BlocProvider<PixelFixerCubit>.value(
      value: cubit,
      child: const MaterialApp(home: PixelFixerPage()),
    ),
  );

  testWidgets('shows the photosensitivity gate before running', (tester) async {
    await tester.pumpWidget(buildSubject());
    await tester.pump();

    expect(cubit.state.running, isFalse);

    await tester.tap(find.widgetWithText(FilledButton, 'Start'));
    await tester.pumpAndSettle();

    expect(find.text('Photosensitivity warning'), findsOneWidget);
    expect(find.text('I understand, start'), findsOneWidget);
    // Still not running until the user confirms.
    expect(cubit.state.running, isFalse);
  });

  testWidgets('confirming the warning starts cycling', (tester) async {
    await tester.pumpWidget(buildSubject());
    await tester.pump();

    await tester.tap(find.widgetWithText(FilledButton, 'Start'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('I understand, start'));
    await tester.pump();

    expect(cubit.state.running, isTrue);

    // Stop immediately so the periodic frame timer doesn't leak.
    cubit.stop();
    await tester.pump();
  });
}
