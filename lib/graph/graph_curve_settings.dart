import 'package:drift/drift.dart' hide Column;
import 'package:flex/database/database.dart';
import 'package:flex/graph/flex_line_chart.dart';
import 'package:flex/l10n/l10n.dart';
import 'package:flex/main.dart';
import 'package:flex/utils.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Controls the persisted line shape used by graph charts.
class GraphCurveSettings extends StatelessWidget {
  final bool compact;
  final bool showPreview;

  const GraphCurveSettings({
    super.key,
    this.compact = false,
    this.showPreview = false,
  });

  Widget _compactToggle(
    BuildContext context, {
    required Key key,
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ),
          const SizedBox(width: 8),
          Switch(key: key, value: value, onChanged: onChanged),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<Setting>(
      builder: (context, settings, child) {
        final smoothness = (settings.curveSmoothness ?? 0.35).clamp(0.0, 1.0);

        void onCurveChanged(bool value) => db.settings.update().write(
          SettingsCompanion(curveLines: Value(value)),
        );
        void onGridlinesChanged(bool value) => db.settings.update().write(
          SettingsCompanion(showChartGridlines: Value(value)),
        );
        void onShadingChanged(bool value) => db.settings.update().write(
          SettingsCompanion(fillChartArea: Value(value)),
        );
        final onChange = settings.curveLines
            ? (double value) => db.settings.update().write(
                SettingsCompanion(curveSmoothness: Value(value)),
              )
            : null;

        if (compact) {
          final theme = Theme.of(context);
          final colorScheme = theme.colorScheme;

          final curveControls = Container(
            height: 58,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colorScheme.outlineVariant),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Tooltip(
                    message: context.l10n.curveLineGraphsDescription,
                    child: Text(
                      context.l10n.curveLineGraphs,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelLarge,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Switch(
                  key: const Key('curve-lines-toggle'),
                  value: settings.curveLines,
                  onChanged: onCurveChanged,
                ),
                const SizedBox(width: 14),
                Container(
                  width: 1,
                  height: 28,
                  color: colorScheme.outlineVariant,
                ),
                const SizedBox(width: 14),
                Text(
                  context.l10n.curveSmoothness,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 3,
                  child: SizedBox(
                    height: 30,
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 3,
                        thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 7,
                        ),
                        overlayShape: const RoundSliderOverlayShape(
                          overlayRadius: 14,
                        ),
                      ),
                      child: Slider(
                        key: const Key('curve-smoothness-slider'),
                        value: smoothness,
                        min: 0,
                        max: 1,
                        divisions: 20,
                        inactiveColor: colorScheme.primary.withValues(
                          alpha: 0.24,
                        ),
                        onChanged: onChange,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 42,
                  child: Text(
                    formatDisplayPercent(context, smoothness, maxDigits: 0),
                    textAlign: TextAlign.end,
                    style: theme.textTheme.labelLarge,
                  ),
                ),
              ],
            ),
          );
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              curveControls,
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _compactToggle(
                      context,
                      key: const Key('chart-gridlines-toggle'),
                      label: context.l10n.chartGridlines,
                      value: settings.showChartGridlines,
                      onChanged: onGridlinesChanged,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _compactToggle(
                      context,
                      key: const Key('chart-shading-toggle'),
                      label: context.l10n.chartShading,
                      value: settings.fillChartArea,
                      onChanged: onShadingChanged,
                    ),
                  ),
                ],
              ),
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SwitchListTile(
              key: const Key('chart-gridlines-toggle'),
              contentPadding: EdgeInsets.zero,
              title: Text(context.l10n.chartGridlines),
              value: settings.showChartGridlines,
              onChanged: onGridlinesChanged,
            ),
            SwitchListTile(
              key: const Key('chart-shading-toggle'),
              contentPadding: EdgeInsets.zero,
              title: Text(context.l10n.chartShading),
              value: settings.fillChartArea,
              onChanged: onShadingChanged,
            ),
            SwitchListTile(
              key: const Key('curve-lines-toggle'),
              contentPadding: EdgeInsets.zero,
              title: Text(context.l10n.curveLineGraphs),
              subtitle: Text(context.l10n.curveLineGraphsDescription),
              value: settings.curveLines,
              onChanged: onCurveChanged,
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    context.l10n.curveSmoothness,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(formatDisplayPercent(context, smoothness, maxDigits: 0)),
              ],
            ),
            Slider(
              key: const Key('curve-smoothness-slider'),
              value: smoothness,
              min: 0,
              max: 1,
              divisions: 20,
              inactiveColor: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.24),
              onChanged: onChange,
            ),
            if (showPreview)
              SizedBox(
                key: const Key('chart-visuals-preview'),
                height: 172,
                child: FlexLineChart(
                  points: const [
                    FlexLineChartPoint(0, 3),
                    FlexLineChartPoint(1, 6),
                    FlexLineChartPoint(2, 4),
                    FlexLineChartPoint(3, 9),
                    FlexLineChartPoint(4, 5),
                    FlexLineChartPoint(5, 8),
                  ],
                  hideBottom: true,
                  showTrendLine: false,
                  tooltipText: (index) => '${index + 1}',
                ),
              ),
          ],
        );
      },
    );
  }
}
