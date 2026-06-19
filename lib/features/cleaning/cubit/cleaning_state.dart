part of 'cleaning_cubit.dart';

/// idle = no session; cleaning = lock engaged; failed = lock could not engage
/// (aborted + torn down, [CleaningState.errorMessage] surfaces why).
enum CleaningStatus { idle, cleaning, failed }

/// Immutable cleaning-session state.
class CleaningState extends Equatable {
  const CleaningState({
    required this.status,
    this.backgroundColor = 0xFF000000,
    this.unlockProgress = 0,
    this.remainingSeconds,
    this.mode = CleaningMode.full,
    this.totalSeconds,
    this.guidedWipe = false,
    this.gridColumns = 0,
    this.gridRows = 0,
    this.coveredCells = const <int>{},
    this.errorMessage,
  });

  const CleaningState.idle()
    : status = CleaningStatus.idle,
      backgroundColor = 0xFF000000,
      unlockProgress = 0,
      remainingSeconds = null,
      mode = CleaningMode.full,
      totalSeconds = null,
      guidedWipe = false,
      gridColumns = 0,
      gridRows = 0,
      coveredCells = const <int>{},
      errorMessage = null;

  final CleaningStatus status;
  final int backgroundColor;

  /// User-facing reason the session failed to start, or null when not failed.
  final String? errorMessage;

  /// 0..1 progress of the native-detected unlock hold gesture.
  final double unlockProgress;

  /// Seconds left on the optional auto-exit countdown, or null if disabled.
  final int? remainingSeconds;

  /// Surface + guidance style chosen for this session.
  final CleaningMode mode;

  /// Countdown starting value, so the ring can compute a depleting fraction.
  final int? totalSeconds;

  /// Whether the guided-wipe overlay renders this session.
  final bool guidedWipe;

  /// Coverage grid dimensions (0 when guided-wipe is inactive).
  final int gridColumns;
  final int gridRows;

  /// Flat cell indices (row * columns + column) already wiped.
  final Set<int> coveredCells;

  bool get isCleaning => status == CleaningStatus.cleaning;

  /// Whether the last start attempt aborted before engaging the lock.
  bool get failed => status == CleaningStatus.failed;

  int get _cellCount => gridColumns * gridRows;

  /// 0..1 fraction of cells wiped. 0 when there is no grid.
  double get coverage => _cellCount == 0 ? 0 : coveredCells.length / _cellCount;

  /// 0..1 fraction of countdown time remaining, or null when no countdown.
  double? get countdownFraction =>
      (remainingSeconds == null || totalSeconds == null || totalSeconds == 0)
      ? null
      : remainingSeconds! / totalSeconds!;

  CleaningState copyWith({
    CleaningStatus? status,
    int? backgroundColor,
    double? unlockProgress,
    int? remainingSeconds,
    CleaningMode? mode,
    int? totalSeconds,
    bool? guidedWipe,
    int? gridColumns,
    int? gridRows,
    Set<int>? coveredCells,
    String? errorMessage,
  }) {
    return CleaningState(
      status: status ?? this.status,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      unlockProgress: unlockProgress ?? this.unlockProgress,
      remainingSeconds: remainingSeconds ?? this.remainingSeconds,
      mode: mode ?? this.mode,
      totalSeconds: totalSeconds ?? this.totalSeconds,
      guidedWipe: guidedWipe ?? this.guidedWipe,
      gridColumns: gridColumns ?? this.gridColumns,
      gridRows: gridRows ?? this.gridRows,
      coveredCells: coveredCells ?? this.coveredCells,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [
    status,
    backgroundColor,
    unlockProgress,
    remainingSeconds,
    mode,
    totalSeconds,
    guidedWipe,
    gridColumns,
    gridRows,
    coveredCells,
    errorMessage,
  ];
}
