import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucent/features/display_test/cubit/test_pattern_cubit.dart';

/// Full-screen display-test viewer. Tap right half / arrow-right = next,
/// tap left half / arrow-left = previous, Esc / tap-and-hold center = exit.
///
/// NOTE: This is a non-locking inspection mode — the native hook is NOT engaged
/// here, so normal Flutter key handling works for navigation and exit.
class DisplayTestPage extends StatelessWidget {
  const DisplayTestPage({super.key});

  static Route<void> route() => MaterialPageRoute<void>(
        builder: (_) => BlocProvider(
          create: (_) => TestPatternCubit(),
          child: const DisplayTestPage(),
        ),
        fullscreenDialog: true,
      );

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<TestPatternCubit>();
    final focusNode = FocusNode();
    return Focus(
      autofocus: true,
      focusNode: focusNode,
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        switch (event.logicalKey) {
          case LogicalKeyboardKey.arrowRight:
          case LogicalKeyboardKey.space:
            cubit.next();
            return KeyEventResult.handled;
          case LogicalKeyboardKey.arrowLeft:
            cubit.previous();
            return KeyEventResult.handled;
          case LogicalKeyboardKey.escape:
            unawaited(Navigator.of(context).maybePop());
            return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: BlocBuilder<TestPatternCubit, TestPatternState>(
        builder: (context, state) {
          return Scaffold(
            body: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: (details) {
                final width = MediaQuery.sizeOf(context).width;
                if (details.localPosition.dx > width / 2) {
                  cubit.next();
                } else {
                  cubit.previous();
                }
              },
              onLongPress: () => Navigator.of(context).maybePop(),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                decoration: state.pattern.decoration,
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      '${state.pattern.label}  •  tap sides to cycle, '
                      'long-press or Esc to exit',
                      style: TextStyle(
                        color: Colors.black.withValues(alpha: 0.35),
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
