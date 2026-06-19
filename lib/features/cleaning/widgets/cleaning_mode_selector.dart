import 'package:flutter/material.dart';
import 'package:lucent/features/cleaning/models/cleaning_mode.dart';

/// Compact one-tap segmented selector over [CleaningMode.values]. Reused on the
/// home screen (before Start) and in settings; persists as last-used wherever
/// [onChanged] writes through a cubit.
class CleaningModeSelector extends StatelessWidget {
  const CleaningModeSelector({
    required this.value,
    required this.onChanged,
    super.key,
  });

  final CleaningMode value;
  final ValueChanged<CleaningMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<CleaningMode>(
      segments: [
        for (final m in CleaningMode.values)
          ButtonSegment<CleaningMode>(value: m, label: Text(m.label)),
      ],
      selected: {value},
      showSelectedIcon: false,
      onSelectionChanged: (s) => onChanged(s.first),
    );
  }
}
