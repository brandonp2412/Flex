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
  final bool showPreview;

  const GraphCurveSettings({super.key, this.showPreview = false});

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
