import 'package:flex/graph/graph_curve_settings.dart';
import 'package:flex/graph/graph_date_field.dart';
import 'package:flex/graph/limit_control.dart';
import 'package:flex/l10n/l10n.dart';
import 'package:flutter/material.dart';

export 'package:flex/graph/graph_options_button.dart';
export 'package:flex/graph/graph_action_buttons.dart';

class GraphOptionsControls extends StatelessWidget {
  final String shortDateFormat;
  final String? unitValue;
  final List<DropdownMenuItem<String>> unitItems;
  final ValueChanged<String>? onUnitChanged;
  final DateTime? startDate;
  final DateTime? endDate;
  final VoidCallback onSelectStart;
  final VoidCallback onClearStart;
  final VoidCallback onSelectEnd;
  final VoidCallback onClearEnd;
  final int limit;
  final int maxLimit;
  final ValueChanged<int> onLimitChanged;
  final bool? timeBasedXAxis;
  final ValueChanged<bool>? onTimeAxisChange;

  const GraphOptionsControls({
    super.key,
    required this.shortDateFormat,
    this.unitValue,
    this.unitItems = const [],
    this.onUnitChanged,
    required this.startDate,
    required this.endDate,
    required this.onSelectStart,
    required this.onClearStart,
    required this.onSelectEnd,
    required this.onClearEnd,
    required this.limit,
    required this.maxLimit,
    required this.onLimitChanged,
    this.timeBasedXAxis,
    this.onTimeAxisChange,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    Widget sectionLabel(String text) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: theme.textTheme.labelLarge?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
      ),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (unitValue != null && unitItems.isNotEmpty) ...[
          sectionLabel(context.l10n.unitLabel),
          DropdownButtonFormField<String>(
            key: ValueKey(unitValue),
            initialValue: unitValue,
            items: unitItems,
            onChanged: (value) {
              if (value != null) onUnitChanged?.call(value);
            },
          ),
          const SizedBox(height: 20),
        ],
        sectionLabel(context.l10n.dateRange),
        Row(
          children: [
            Expanded(
              child: GraphDateField(
                label: context.l10n.startDate,
                value: startDate,
                hint: shortDateFormat,
                onTap: onSelectStart,
                onClear: onClearStart,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GraphDateField(
                label: context.l10n.stopDate,
                value: endDate,
                hint: shortDateFormat,
                onTap: onSelectEnd,
                onClear: onClearEnd,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        LimitControl(
          limit: limit,
          maxLimit: maxLimit,
          onChanged: onLimitChanged,
        ),
        if (timeBasedXAxis != null && onTimeAxisChange != null)
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(context.l10n.useTimeBasedXAxis),
            value: timeBasedXAxis!,
            onChanged: onTimeAxisChange,
          ),
        const GraphCurveSettings(),
      ],
    );
  }
}
