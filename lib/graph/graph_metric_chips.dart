import 'package:flex/constants.dart';
import 'package:flex/l10n/l10n.dart';
import 'package:flutter/material.dart';

class GraphMetricChips<T> extends StatelessWidget {
  const GraphMetricChips({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  final List<(T, String)> options;
  final T selected;
  final ValueChanged<T> onChanged;

  static List<Color> palette(ColorScheme colors) => [
    colors.primary,
    colors.tertiary,
    colors.secondary,
    const Color(0xFFDFA64B),
    const Color(0xFF4B9BA8),
  ];

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final palette = GraphMetricChips.palette(colors);
    final textTheme = Theme.of(context).textTheme;
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 6,
      children: [
        for (var index = 0; index < options.length; index++)
          Builder(
            builder: (context) {
              final accent = palette[index % palette.length];
              final active = selected == options[index].$1;
              return ChoiceChip(
                key: ValueKey('graph-metric-${options[index].$1}'),
                label: Text(options[index].$2),
                avatar: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: accent,
                    boxShadow: active
                        ? [
                            BoxShadow(
                              color: accent.withValues(alpha: .32),
                              blurRadius: 6,
                            ),
                          ]
                        : null,
                  ),
                ),
                selected: active,
                showCheckmark: false,
                backgroundColor: colors.surfaceContainerLow,
                selectedColor: accent.withValues(alpha: .15),
                labelStyle: textTheme.labelLarge?.copyWith(
                  color: active ? colors.onSurface : colors.onSurfaceVariant,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                side: BorderSide(
                  color: active
                      ? accent.withValues(alpha: .9)
                      : colors.outlineVariant.withValues(alpha: .6),
                  width: active ? 1.35 : 1,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                visualDensity: VisualDensity.compact,
                onSelected: (enabled) {
                  if (enabled && !active) onChanged(options[index].$1);
                },
              );
            },
          ),
      ],
    );
  }
}

List<(StrengthMetric, String)> strengthMetricOptions(
  BuildContext context, {
  required bool showBodyWeight,
}) => [
  (StrengthMetric.bestWeight, context.l10n.bestWeight),
  (StrengthMetric.bestReps, context.l10n.bestReps),
  (StrengthMetric.oneRepMax, context.l10n.oneRepMax),
  (StrengthMetric.volume, context.l10n.volume),
  if (showBodyWeight)
    (StrengthMetric.relativeStrength, context.l10n.relativeStrength),
];
