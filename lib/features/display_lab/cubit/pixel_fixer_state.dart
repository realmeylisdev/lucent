part of 'pixel_fixer_cubit.dart';

/// Clamps [rect] so it stays fully within a [size]-sized area, honoring the
/// minimum region edge. Single source of truth reused for drag, resize, and
/// restore-from-prefs. If [size] is empty (no layout yet) the rect is returned
/// unchanged.
Rect clampRectToBounds(Rect rect, Size size) {
  if (size.isEmpty) return rect;
  const minSide = PixelFixerState.minRegionSide;
  final width = rect.width.clamp(minSide, size.width);
  final height = rect.height.clamp(minSide, size.height);
  final left = rect.left.clamp(0.0, size.width - width);
  final top = rect.top.clamp(0.0, size.height - height);
  return Rect.fromLTWH(left, top, width, height);
}

/// Immutable state for the stuck-pixel exerciser.
class PixelFixerState extends Equatable {
  const PixelFixerState({
    required this.mode,
    required this.running,
    required this.frame,
    required this.frequencyHz,
    required this.regionEnabled,
    required this.region,
    required this.autoStop,
    required this.remainingSeconds,
  });

  const PixelFixerState.initial()
    : mode = PixelFixerMode.rgbCycle,
      running = false,
      frame = 0,
      frequencyHz = defaultHz,
      regionEnabled = false,
      region = defaultRegion,
      autoStop = AutoStopPreset.off,
      remainingSeconds = 0;

  /// Seeds transient session state (always stopped) from persisted [settings].
  PixelFixerState.fromSettings(LucentSettings settings)
    : mode = _modeFromToken(settings.pixelFixerMode),
      running = false,
      frame = 0,
      frequencyHz = settings.pixelFixerHz.clamp(minHz, maxHz),
      regionEnabled = settings.pixelFixerRegionEnabled,
      region = Rect.fromLTWH(
        settings.pixelFixerRegionLeft.toDouble(),
        settings.pixelFixerRegionTop.toDouble(),
        settings.pixelFixerRegionWidth.toDouble(),
        settings.pixelFixerRegionHeight.toDouble(),
      ),
      autoStop = AutoStopPreset.fromMinutes(settings.pixelFixerAutoStopMinutes),
      remainingSeconds = 0;

  /// Tolerant token -> mode mapping; stale prefs degrade to RGB Cycle.
  static PixelFixerMode _modeFromToken(String token) =>
      PixelFixerMode.values.firstWhere(
        (mode) => mode.name == token,
        orElse: () => PixelFixerMode.rgbCycle,
      );

  /// Slowest selectable flash rate.
  static const int minHz = 1;

  /// Fastest selectable rate — kept below the 15-25 Hz photosensitive band.
  static const int maxHz = 10;

  /// Calm default rate.
  static const int defaultHz = 3;

  /// Smallest region edge so the body + handle stay grabbable.
  static const double minRegionSide = 80;

  /// Default region: 200x200 logical px at the origin. A 0,0 origin is the
  /// sentinel the view uses to center the region on first layout.
  static const Rect defaultRegion = Rect.fromLTWH(0, 0, 200, 200);

  /// Active color-cycle strategy.
  final PixelFixerMode mode;

  /// Whether the timer is currently advancing frames.
  final bool running;

  /// Monotonic frame counter; the view derives the fill color from it.
  final int frame;

  /// Flash rate in Hz, within [minHz]..[maxHz].
  final int frequencyHz;

  /// Whether cycling is confined to [region] (rest of the screen is black).
  final bool regionEnabled;

  /// Region rectangle in logical screen-space px.
  final Rect region;

  /// Auto-stop preset; [AutoStopPreset.off] disables the countdown.
  final AutoStopPreset autoStop;

  /// Seconds left before auto-stop (0 when off or not counting down).
  final int remainingSeconds;

  /// Timer interval in milliseconds derived from [frequencyHz].
  int get intervalMs => (1000 / frequencyHz).round();

  /// Whether the region's origin is still the centering sentinel (0,0).
  bool get regionNeedsCentering => region.left == 0 && region.top == 0;

  /// `mm:ss` countdown label for the auto-stop pill.
  String get remainingLabel {
    final minutes = (remainingSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (remainingSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  PixelFixerState copyWith({
    PixelFixerMode? mode,
    bool? running,
    int? frame,
    int? frequencyHz,
    bool? regionEnabled,
    Rect? region,
    AutoStopPreset? autoStop,
    int? remainingSeconds,
  }) => PixelFixerState(
    mode: mode ?? this.mode,
    running: running ?? this.running,
    frame: frame ?? this.frame,
    frequencyHz: frequencyHz ?? this.frequencyHz,
    regionEnabled: regionEnabled ?? this.regionEnabled,
    region: region ?? this.region,
    autoStop: autoStop ?? this.autoStop,
    remainingSeconds: remainingSeconds ?? this.remainingSeconds,
  );

  @override
  List<Object?> get props => [
    mode,
    running,
    frame,
    frequencyHz,
    regionEnabled,
    region,
    autoStop,
    remainingSeconds,
  ];
}
