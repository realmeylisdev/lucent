import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucent/features/display_lab/cubit/pixel_fixer_cubit.dart';
import 'package:lucent/features/display_lab/models/pixel_fixer_mode.dart';

/// Full-screen stuck-pixel exerciser. Rapidly cycles solid colors to coax
/// stuck sub-pixels back to life. A photosensitivity warning is shown and must
/// be dismissed before the first run; the flash rate is capped at 10 Hz.
///
/// NOTE: Non-locking — the native hook is NOT engaged; Esc / long-press exits.
class PixelFixerPage extends StatelessWidget {
  const PixelFixerPage({super.key});

  static Route<void> route() => MaterialPageRoute<void>(
    builder: (_) => BlocProvider(
      create: (_) => PixelFixerCubit(),
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

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      focusNode: _focusNode,
      onKeyEvent: _onKey,
      child: BlocBuilder<PixelFixerCubit, PixelFixerState>(
        builder: (context, state) {
          final color = state.mode.colorForFrame(state.frame);
          return Scaffold(
            backgroundColor: const Color(0xFF202020),
            body: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _showControls,
              onLongPress: () => unawaited(Navigator.of(context).maybePop()),
              child: Stack(
                children: [
                  Positioned.fill(child: ColoredBox(color: color)),
                  if (_controlsVisible || !state.running)
                    _Controls(
                      state: state,
                      onToggle: () {
                        if (state.running) {
                          context.read<PixelFixerCubit>().stop();
                        } else {
                          unawaited(_confirmAndStart());
                        }
                        _showControls();
                      },
                    ),
                ],
              ),
            ),
          );
        },
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
                      onChanged: (v) => cubit.setFrequency(v.round()),
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
