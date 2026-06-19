part of 'cleaning_cubit.dart';

enum CleaningStatus { idle, cleaning }

/// Immutable cleaning-session state.
class CleaningState extends Equatable {
  const CleaningState({
    required this.status,
    this.backgroundColor = 0xFF000000,
    this.unlockProgress = 0,
    this.remainingSeconds,
  });

  const CleaningState.idle()
      : status = CleaningStatus.idle,
        backgroundColor = 0xFF000000,
        unlockProgress = 0,
        remainingSeconds = null;

  final CleaningStatus status;
  final int backgroundColor;

  /// 0..1 progress of the native-detected unlock hold gesture.
  final double unlockProgress;

  /// Seconds left on the optional auto-exit countdown, or null if disabled.
  final int? remainingSeconds;

  bool get isCleaning => status == CleaningStatus.cleaning;

  CleaningState copyWith({
    CleaningStatus? status,
    int? backgroundColor,
    double? unlockProgress,
    int? remainingSeconds,
  }) {
    return CleaningState(
      status: status ?? this.status,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      unlockProgress: unlockProgress ?? this.unlockProgress,
      remainingSeconds: remainingSeconds ?? this.remainingSeconds,
    );
  }

  @override
  List<Object?> get props =>
      [status, backgroundColor, unlockProgress, remainingSeconds];
}
