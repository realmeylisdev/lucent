import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucent/features/display_lab/cubit/pixel_fixer_cubit.dart';
import 'package:lucent/features/display_lab/models/auto_stop_preset.dart';
import 'package:lucent/features/display_lab/models/pixel_fixer_mode.dart';
import 'package:lucent/features/display_lab/widgets/draggable_region.dart';
import 'package:lucent/features/settings/data/settings_repository.dart';

/// Full-screen stuck-pixel exerciser. Rapidly cycles solid colors to coax
/// stuck sub-pixels back to life. A photosensitivity warning is shown and must
/// be dismissed before the first run; the flash rate is capped at 10 Hz.
///
/// NOTE: Non-locking — the native hook is NOT engaged; Esc / long-press exits.
class PixelFixerPage extends StatelessWidget {
  const PixelFixerPage({super.key});

  /// Self-provisions a [PixelFixerCubit] from the app-wide
  /// [SettingsRepository] so the page can launch standalone (tray) or from
  /// Display Lab, always seeded with the last-used persisted config.
  static Route<void> route() => MaterialPageRoute<void>(
    builder: (context) => BlocProvider(
      create: (_) =>
          PixelFixerCubit(repository: context.read<SettingsRepository>()),
      child: const PixelFixerPage(),
    ),
    fullscreenDialog: true,
  );

  @override
  Widget build(BuildContext context) => const _PixelFixerView();
}

class _PixelFixerView extends StatefulWidget {
  const _PixelFixerView();

  @override
  State<_PixelFixerView> createState() => _PixelFixerViewState();
}

class _PixelFixerViewState extends State<_PixelFixerView> {
  final _focusNode = FocusNode();
  bool _warned = false;
  bool _controlsVisible = true;
  Timer? _autoHide;

  @override
  void dispose() {
    _autoHide?.cancel();
    _focusNode.dispose();
    super.dispose();
  }

  void _showControls() {
    setState(() => _controlsVisible = true);
    _autoHide?.cancel();
    _autoHide = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _controlsVisible = false);
    });
  }

  Future<void> _confirmAndStart() async {
    if (_warned) {
      context.read<PixelFixerCubit>().start();
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Photosensitivity warning'),
        content: const Text(
          'This rapidly flashes full-screen colors. Flashing lights can '
          'trigger seizures in people with photosensitive epilepsy. Do not '
          'use it if you or anyone watching is susceptible, and look away if '
          'you feel unwell.\n\nThe rate is capped at 10 Hz (default 3 Hz).',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('I understand, start'),
          ),
        ],
      ),
    );
    if (ok ?? false) {
      _warned = true;
      if (mounted) context.read<PixelFixerCubit>().start();
    }
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      unawaited(Navigator.of(context).maybePop());
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  /// Centers the default region on first layout if it still carries the 0,0
  /// sentinel and the cubit knows the live screen size.
  void _maybeCenterRegion(PixelFixerState state, Size size) {
    if (!state.regionEnabled || !state.regionNeedsCentering) return;
    if (size.isEmpty) return;
    final centered = Rect.fromCenter(
      center: size.center(Offset.zero),
      width: state.region.width,
      height: state.region.height,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        // Auto-derived default (not a user gesture): don't persist it.
        context.read<PixelFixerCubit>().setRegion(centered, persist: false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      focusNode: _focusNode,
      onKeyEvent: _onKey,
      child: BlocBuilder<PixelFixerCubit, PixelFixerState>(
        builder: (context, state) {
          final cubit = context.read<PixelFixerCubit>();
          final color = state.mode.colorForFrame(state.frame);
          final showChrome = _controlsVisible || !state.running;
          return Scaffold(
            backgroundColor: const Color(0xFF000000),
            body: LayoutBuilder(
              builder: (context, constraints) {
                final size = constraints.biggest;
                _maybeCenterRegion(state, size);
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _showControls,
                  onLongPress: () =>
                      unawaited(Navigator.of(context).maybePop()),
                  child: Stack(
                    children: [
                      if (state.regionEnabled)
                        DraggableRegion(
                          region: state.region,
                          color: color,
                          bounds: size,
                          editable: showChrome,
                          onChanged: (rect) =>
                              cubit.setRegion(rect, persist: false),
                          onChangeEnd: () => cubit.setRegion(state.region),
                        )
                      else
                        Positioned.fill(child: ColoredBox(color: color)),
                      if (state.running && state.autoStop != AutoStopPreset.off)
                        _AutoStopPill(label: state.remainingLabel),
                      if (showChrome)
                        _Controls(
                          state: state,
                          onToggle: () {
                            if (state.running) {
                              cubit.stop();
                            } else {
                              unawaited(_confirmAndStart());
                            }
                            _showControls();
                          },
                        ),
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

/// Static, once-per-second countdown pill near the top-center. Stays visible
/// while the bottom controls auto-hide because it is safety/expectation info.
class _AutoStopPill extends StatelessWidget {
  const _AutoStopPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: const EdgeInsets.only(top: 24),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            'Auto-stop in $label',
            style: const TextStyle(
              color: Colors.white70,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ),
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls({required this.state, required this.onToggle});

  final PixelFixerState state;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<PixelFixerCubit>();
    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.65),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Pixel Fixer — rapidly flashes colors to revive stuck pixels',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('Full screen'),
                    selected: !state.regionEnabled,
                    onSelected: (_) => cubit.setRegionEnabled(false),
                  ),
                  ChoiceChip(
                    label: const Text('Region'),
                    selected: state.regionEnabled,
                    onSelected: (_) => cubit.setRegionEnabled(true),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  for (final mode in PixelFixerMode.values)
                    ChoiceChip(
                      label: Text(mode.label),
                      selected: state.mode == mode,
                      onSelected: (_) => cubit.setMode(mode),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Speed',
                    style: TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 220,
                    child: Slider(
                      value: state.frequencyHz.toDouble(),
                      min: PixelFixerState.minHz.toDouble(),
                      max: PixelFixerState.maxHz.toDouble(),
                      divisions: PixelFixerState.maxHz - PixelFixerState.minHz,
                      label: '${state.frequencyHz} Hz',
                      onChanged: (v) =>
                          cubit.setFrequency(v.round(), persist: false),
                      onChangeEnd: (v) => cubit.setFrequency(v.round()),
                    ),
                  ),
                  Text(
                    '${state.frequencyHz} Hz',
                    style: const TextStyle(color: Colors.white70),
                  ),
                ],
              ),
              const Text(
                'higher = more aggressive',
                style: TextStyle(color: Colors.white38, fontSize: 11),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Auto-stop:',
                    style: TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(width: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final preset in AutoStopPreset.values)
                        ChoiceChip(
                          label: Text(preset.label),
                          selected: state.autoStop == preset,
                          onSelected: (_) => cubit.setAutoStop(preset),
                        ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: onToggle,
                icon: Icon(
                  state.running ? Icons.stop : Icons.play_arrow,
                ),
                label: Text(state.running ? 'Stop' : 'Start'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
