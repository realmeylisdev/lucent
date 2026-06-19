import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucent/core/models/test_pattern.dart';

part 'test_pattern_state.dart';

/// Cycles through [TestPattern]s for smudge & dead/stuck-pixel hunting.
class TestPatternCubit extends Cubit<TestPatternState> {
  TestPatternCubit() : super(const TestPatternState(TestPattern.white));

  void next() => emit(TestPatternState(state.pattern.next));
  void previous() => emit(TestPatternState(state.pattern.previous));
  void select(TestPattern pattern) => emit(TestPatternState(pattern));
}
