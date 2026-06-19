import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucent/features/display_lab/cubit/display_lab_cubit.dart';
import 'package:lucent/features/display_lab/widgets/lab_hint_overlay.dart';
import 'package:lucent/features/display_lab/widgets/pattern_painters.dart';

/// Full-screen pattern viewer. Tap right half / arrow-right / space = next,
/// tap left half / arrow-left = previous, tap center / 'i' = toggle hint,
/// 'h' = hide hint, Esc / long-press = exit.
///
/// NOTE: This is a non-locking inspection mode — the native hook is NOT engaged
/// here, so normal Flutter key handling drives navigation and exit.
class PatternViewerPage extends StatefulWidget {
  const PatternViewerPage({super.key});

  /// Shares the parent's [DisplayLabCubit] so cycling stays in sync with the
  /// menu grid on return — do not create a second instance.
  static Route<void> route(BuildContext context) => MaterialPageRoute<void>(
    builder: (_) => BlocProvider.value(
      value: context.read<DisplayLabCubit>(),
      child: const PatternViewerPage(),
    ),
    fullscreenDialog: true,
  );

  @override
  State<PatternViewerPage> createState() => _PatternViewerPageState();
}

class _PatternViewerPageState extends State<PatternViewerPage> {
  final _focusNode = FocusNode();
  Timer? _autoHide;

  @override
  void initState() {
    super.initState();
    _scheduleAutoHide();
  }

  void _scheduleAutoHide() {
    _autoHide?.cancel();
    final cubit = context.read<DisplayLabCubit>();
    if (!cubit.state.hintVisible) return;
    _autoHide = Timer(const Duration(milliseconds: 2500), () {
      if (mounted && context.read<DisplayLabCubit>().state.hintVisible) {
        // Fade the expanded hint to the faint corner label after the delay.
        setState(() => _expanded = false);
      }
    });
  }

  bool _expanded = true;

  void _onChange() {
    setState(() => _expanded = true);
    _scheduleAutoHide();
  }

  @override
  void dispose() {
    _autoHide?.cancel();
    _focusNode.dispose();
    super.dispose();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final cubit = context.read<DisplayLabCubit>();
    switch (event.logicalKey) {
      case LogicalKeyboardKey.arrowRight:
      case LogicalKeyboardKey.space:
        cubit.next();
        _onChange();
      case LogicalKeyboardKey.arrowLeft:
        cubit.previous();
        _onChange();
      case LogicalKeyboardKey.keyI:
        cubit.toggleHint();
        if (cubit.state.hintVisible) _onChange();
      case LogicalKeyboardKey.keyH:
        if (cubit.state.hintVisible) cubit.toggleHint();
      case LogicalKeyboardKey.escape:
        unawaited(Navigator.of(context).maybePop());
      default:
        return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return Focus(
      autofocus: true,
      focusNode: _focusNode,
      onKeyEvent: _onKey,
      child: BlocBuilder<DisplayLabCubit, DisplayLabState>(
        builder: (context, state) {
          final pattern = state.activePattern;
          if (pattern == null) return const SizedBox.shrink();
          final cubit = context.read<DisplayLabCubit>();
          return Scaffold(
            backgroundColor: const Color(0xFF000000),
            body: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: (details) {
                final width = MediaQuery.sizeOf(context).width;
                final dx = details.localPosition.dx;
                if (dx < width / 3) {
                  cubit.previous();
                  _onChange();
                } else if (dx > width * 2 / 3) {
                  cubit.next();
                  _onChange();
                } else {
                  cubit.toggleHint();
                  if (cubit.state.hintVisible) _onChange();
                }
              },
              onLongPress: () => unawaited(Navigator.of(context).maybePop()),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: painterForPattern(pattern, dpr),
                    ),
                  ),
                  if (state.hintVisible)
                    Positioned.fill(
                      child: LabHintOverlay(
                        title: pattern.label,
                        subtitle:
                            '${pattern.purpose}  •  tap sides to cycle, '
                            'Esc or long-press to exit',
                        expanded: _expanded,
                      ),
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
