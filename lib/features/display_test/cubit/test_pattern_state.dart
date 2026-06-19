part of 'test_pattern_cubit.dart';

class TestPatternState extends Equatable {
  const TestPatternState(this.pattern);

  final TestPattern pattern;

  @override
  List<Object?> get props => [pattern];
}
