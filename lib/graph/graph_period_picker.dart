import 'package:flex/constants.dart';
import 'package:flex/l10n/l10n.dart';
import 'package:flex/responsive.dart';
import 'package:flutter/material.dart';

class GraphPeriodPicker extends StatelessWidget {
  final Period selected;
  final ValueChanged<Period> onChanged;

  const GraphPeriodPicker({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final desktop = isDesktopLayout(context);
    final colors = Theme.of(context).colorScheme;
    final picker = SegmentedButton<Period>(
      showSelectedIcon: false,
      segments: [
        ButtonSegment(value: Period.day, label: Text(context.l10n.periodDay)),
        ButtonSegment(value: Period.week, label: Text(context.l10n.periodWeek)),
        ButtonSegment(
          value: Period.month,
          label: Text(context.l10n.periodMonth),
        ),
        ButtonSegment(value: Period.year, label: Text(context.l10n.periodYear)),
      ],
      selected: {selected},
      onSelectionChanged: (values) {
        if (values.first != selected) onChanged(values.first);
      },
      style: desktop
          ? ButtonStyle(
              side: const WidgetStatePropertyAll(BorderSide.none),
              shape: WidgetStatePropertyAll(
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              backgroundColor: WidgetStateProperty.resolveWith(
                (states) => states.contains(WidgetState.selected)
                    ? colors.primary
                    : Colors.transparent,
              ),
              foregroundColor: WidgetStateProperty.resolveWith(
                (states) => states.contains(WidgetState.selected)
                    ? colors.onPrimary
                    : colors.onSurfaceVariant,
              ),
              padding: const WidgetStatePropertyAll(
                EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              textStyle: WidgetStatePropertyAll(
                Theme.of(
                  context,
                ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
              ),
            )
          : null,
    );

    if (!desktop) return picker;

    return Align(
      alignment: Alignment.center,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(padding: const EdgeInsets.all(4), child: picker),
      ),
    );
  }
}
