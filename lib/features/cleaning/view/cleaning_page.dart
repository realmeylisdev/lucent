import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucent/core/services/multi_monitor_cover.dart'
    show MultiMonitorCover;
import 'package:lucent/features/cleaning/cubit/cleaning_cubit.dart';
import 'package:lucent/features/cleaning/models/cleaning_mode.dart';
import 'package:lucent/features/cleaning/widgets/countdown_ring.dart';
import 'package:lucent/features/cleaning/widgets/guided_wipe_overlay.dart';
import 'package:lucent/features/cleaning/widgets/keyboard_guidance_surface.dart';
import 'package:lucent/features/cleaning/widgets/unlock_ring.dart';
import 'package:lucent/features/settings/cubit/settings_cubit.dart';

/// Full-screen cleaning surface (primary display). Secondary displays are
/// covered by [MultiMonitorCover] windows.
///
/// The surface depends on [CleaningState.mode]: keyboard mode shows a calm
/// dimmed guidance surface, screen/full show the solid cleaning color. The
/// unlock ring + hold-to-unlock hint are shared by every mode. The native hook
/// owns key/pointer swallowing.
class CleaningPage extends StatelessWidget {
  const CleaningPage({super.key});

  static Route<void> route() => MaterialPageRoute<void>(
    builder: (_) => const CleaningPage(),
    fullscreenDialog: true,
  );

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<CleaningCubit, CleaningState>(
      listenWhen: (prev, next) =>
          prev.status != next.status && next.status == CleaningStatus.idle,
      listener: (context, state) {
        // Session ended (unlock / countdown / failure): pop back home.
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
      },
      builder: (context, state) {
        final unlockKey = context
            .read<SettingsCubit>()
            .state
            .settings
            .unlockKeyEnum;
        final isKeyboard = state.mode == CleaningMode.keyboard;
        final hint = isKeyboard
            ? 'Cleaning keyboard — hold ${unlockKey.label} to finish'
            : 'Hold ${unlockKey.label} to unlock';
        final fraction = state.countdownFraction;

        return Scaffold(
          backgroundColor: isKeyboard
              ? const Color(0xFF0E0F13)
              : Color(state.backgroundColor),
          body: SafeArea(
            child: Stack(
              children: [
                if (isKeyboard)
                  const Positioned.fill(
                    child: KeyboardGuidanceSurface(),
                  ),
                if (state.guidedWipe)
                  Positioned.fill(
                    child: GuidedWipeOverlay(
                      columns: state.gridColumns,
                      rows: state.gridRows,
                      coveredCells: state.coveredCells,
                      onCellCovered: context
                          .read<CleaningCubit>()
                          .markCellCovered,
                    ),
                  ),
                // Non-interactive chrome; IgnorePointer lets cursor movement
                // fall through to the guided-wipe overlay below (full-screen
                // coverage tracking, incl. the center).
                IgnorePointer(
                  child: Center(
                    child: AnimatedOpacity(
                      opacity: state.unlockProgress > 0 ? 1 : 0.35,
                      duration: const Duration(milliseconds: 200),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          UnlockRing(progress: state.unlockProgress),
                          const SizedBox(height: 24),
                          Text(
                            hint,
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 16,
                            ),
                          ),
                          if (state.guidedWipe) ...[
                            const SizedBox(height: 8),
                            Text(
                              'Wiped ${(state.coverage * 100).round()}%',
                              style: const TextStyle(
                                color: Colors.white38,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
                if (fraction != null && state.remainingSeconds != null)
                  Positioned(
                    top: 24,
                    right: 24,
                    child: CountdownRing(
                      fraction: fraction,
                      secondsLeft: state.remainingSeconds!,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
