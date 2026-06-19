import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucent/features/display_lab/cubit/display_lab_cubit.dart';
import 'package:lucent/features/display_lab/models/lab_pattern_catalog.dart';
import 'package:lucent/features/display_lab/view/display_lab_page.dart';
import 'package:lucent/features/display_lab/widgets/lab_hint_overlay.dart';
import 'package:lucent/features/display_lab/widgets/pattern_tile.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget buildSubject(DisplayLabCubit cubit) => BlocProvider<DisplayLabCubit>(
    create: (_) => cubit,
    child: const MaterialApp(home: DisplayLabPage()),
  );

  testWidgets('renders the category chips and pattern tiles', (tester) async {
    final cubit = DisplayLabCubit();
    await tester.pumpWidget(buildSubject(cubit));
    await tester.pump();

    expect(find.text(LabPatternCatalog.categories.first.label), findsWidgets);
    expect(find.byType(PatternTile), findsWidgets);
  });

  testWidgets('tapping a pattern opens the full-screen viewer', (tester) async {
    final cubit = DisplayLabCubit();
    await tester.pumpWidget(buildSubject(cubit));
    await tester.pump();

    final firstTile = find.byType(PatternTile).first;
    await tester.tap(firstTile);
    await tester.pumpAndSettle();

    expect(find.byType(CustomPaint), findsWidgets);
    expect(find.byType(LabHintOverlay), findsOneWidget);

    // Drive the viewer's 2500ms auto-hide timer so it doesn't leak.
    await tester.pump(const Duration(seconds: 3));
    // Unwind the viewer route so its FocusNode disposes cleanly.
    Navigator.of(tester.element(find.byType(LabHintOverlay))).pop();
    await tester.pumpAndSettle();
  });
}
