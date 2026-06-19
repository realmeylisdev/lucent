part of 'display_lab_cubit.dart';

/// Immutable navigation state for the Display Lab.
class DisplayLabState extends Equatable {
  const DisplayLabState({
    required this.activeCategory,
    this.activePattern,
    this.hintVisible = true,
  });

  const DisplayLabState.initial()
    : activeCategory = LabPatternCategory.solids,
      activePattern = null,
      hintVisible = true;

  /// Category currently selected in the menu grid.
  final LabPatternCategory activeCategory;

  /// Pattern shown full-screen, or null when the menu is visible.
  final LabPattern? activePattern;

  /// Whether the hint/info overlay is currently shown.
  final bool hintVisible;

  /// [clearPattern] forces [activePattern] back to null (copyWith can't null).
  DisplayLabState copyWith({
    LabPatternCategory? activeCategory,
    LabPattern? activePattern,
    bool? hintVisible,
    bool clearPattern = false,
  }) => DisplayLabState(
    activeCategory: activeCategory ?? this.activeCategory,
    activePattern: clearPattern ? null : (activePattern ?? this.activePattern),
    hintVisible: hintVisible ?? this.hintVisible,
  );

  @override
  List<Object?> get props => [activeCategory, activePattern, hintVisible];
}
