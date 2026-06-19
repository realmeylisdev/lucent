part of 'pixel_fixer_cubit.dart';

/// Immutable state for the stuck-pixel exerciser.
class PixelFixerState extends Equatable {
  const PixelFixerState({
    required this.mode,
    required this.running,
    required this.frame,
    required this.frequencyHz,
  });

  const PixelFixerState.initial()
    : mode = PixelFixerMode.rgbCycle,
      running = false,
      frame = 0,
      frequencyHz = defaultHz;

  /// Slowest selectable flash rate.
  static const int minHz = 1;

  /// Fastest selectable rate — kept below the 15-25 Hz photosensitive band.
  static const int maxHz = 10;

  /// Calm default rate.
  static const int defaultHz = 3;

  /// Active color-cycle strategy.
  final PixelFixerMode mode;

  /// Whether the timer is currently advancing frames.
  final bool running;

  /// Monotonic frame counter; the view derives the fill color from it.
  final int frame;

  /// Flash rate in Hz, within [minHz]..[maxHz].
  final int frequencyHz;

  /// Timer interval in milliseconds derived from [frequencyHz].
  int get intervalMs => (1000 / frequencyHz).round();

  PixelFixerState copyWith({
    PixelFixerMode? mode,
    bool? running,
    int? frame,
    int? frequencyHz,
  }) => PixelFixerState(
    mode: mode ?? this.mode,
    running: running ?? this.running,
    frame: frame ?? this.frame,
    frequencyHz: frequencyHz ?? this.frequencyHz,
  );

  @override
  List<Object?> get props => [mode, running, frame, frequencyHz];
}
