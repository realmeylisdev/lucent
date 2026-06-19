import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucent/features/display_lab/models/lab_pattern.dart';
import 'package:lucent/features/display_lab/models/lab_pattern_catalog.dart';

part 'display_lab_state.dart';

/// Navigation/selection brain for the Display Lab: the active menu category,
/// the pattern currently viewed full-screen (null = menu showing), and whether
/// the on-screen hint overlay is visible.
class DisplayLabCubit extends Cubit<DisplayLabState> {
  DisplayLabCubit() : super(const DisplayLabState.initial());

  /// Switch the active category in the menu grid.
  void selectCategory(LabPatternCategory category) =>
      emit(state.copyWith(activeCategory: category));

  /// Enter the full-screen viewer on [pattern]; resets the hint to visible.
  void openPattern(LabPattern pattern) => emit(
    state.copyWith(
      activePattern: pattern,
      activeCategory: pattern.category,
      hintVisible: true,
    ),
  );

  /// Leave the viewer and return to the menu.
  void closeViewer() => emit(state.copyWith(clearPattern: true));

  /// Advance to the next pattern in the flat catalog, wrapping around.
  void next() => _step(1);

  /// Step to the previous pattern in the flat catalog, wrapping around.
  void previous() => _step(-1);

  void _step(int delta) {
    final current = state.activePattern;
    if (current == null) return;
    const list = LabPatternCatalog.all;
    final index = list.indexWhere((p) => p.id == current.id);
    if (index < 0) return;
    final nextIndex = (index + delta + list.length) % list.length;
    openPattern(list[nextIndex]);
  }

  /// Toggle the hint overlay (also used for the 'h'/'i' keys and center tap).
  void toggleHint() => emit(state.copyWith(hintVisible: !state.hintVisible));
}
