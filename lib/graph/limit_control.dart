import 'package:flex/l10n/l10n.dart';
import 'package:flutter/material.dart';

class LimitControl extends StatelessWidget {
  final int limit;
  final int maxLimit;
  final ValueChanged<int> onChanged;

  const LimitControl({
    super.key,
    required this.limit,
    required this.maxLimit,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final label = Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Text(
            context.l10n.dataPoints,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
          decoration: BoxDecoration(
            color: colorScheme.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '$limit',
            style: theme.textTheme.labelMedium?.copyWith(
              color: colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );

    final slider = Slider(
      value: limit.toDouble(),
      inactiveColor: colorScheme.primary.withValues(alpha: 0.24),
      min: 10,
      max: maxLimit.toDouble(),
      divisions: 20,
      onChanged: (value) => onChanged(value.toInt()),
    );

    return Column(mainAxisSize: MainAxisSize.min, children: [label, slider]);
  }
}
