import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucent/core/services/multi_monitor_cover.dart' show MultiMonitorCover;
import 'package:lucent/features/cleaning/cubit/cleaning_cubit.dart';
import 'package:lucent/features/cleaning/widgets/unlock_ring.dart';
import 'package:lucent/features/settings/cubit/settings_cubit.dart';

/// Full-screen cleaning surface (primary display). Secondary displays are
/// covered by [MultiMonitorCover] windows.
///
/// The unlock instruction + ring are the only chrome; everything else is the
/// solid cleaning color. The native hook owns key/pointer swallowing.
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
        final unlockKey =
            context.read<SettingsCubit>().state.settings.unlockKeyEnum;
        return Scaffold(
          backgroundColor: Color(state.backgroundColor),
          body: SafeArea(
            child: Stack(
              children: [
                Center(
                  child: AnimatedOpacity(
                    opacity: state.unlockProgress > 0 ? 1 : 0.35,
                    duration: const Duration(milliseconds: 200),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        UnlockRing(progress: state.unlockProgress),
                        const SizedBox(height: 24),
                        Text(
                          'Hold ${unlockKey.label} to unlock',
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (state.remainingSeconds != null)
                  Positioned(
                    top: 24,
                    right: 24,
                    child: Text(
                      '${state.remainingSeconds}s',
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 18,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
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
