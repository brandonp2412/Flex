import 'package:flex/database/database.dart';
import 'package:flex/graph/flex_line_chart.dart';
import 'package:flex/graph/flex_line_chart_interaction.dart';
import 'package:flex/graph/flex_line_chart_layout.dart';
import 'package:flex/graph/flex_line_chart_renderer.dart';
import 'package:flex/graph/flex_line_chart_series.dart';
import 'package:flex/graph/line_chart_axis_label.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class FlexGroupedLineChart extends StatelessWidget {
  final List<FlexLineChartSeries> series;
  final List<String> xLabels;
  final String Function(int seriesIndex, int xIndex) tooltipText;
  final bool showLeftLabels;
  final bool bottomLabels;

  const FlexGroupedLineChart({
    super.key,
    required this.series,
    required this.xLabels,
    required this.tooltipText,
    this.showLeftLabels = true,
    this.bottomLabels = false,
  });

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<Setting>();
    final axisLabelColor = Theme.of(context).colorScheme.onSurface;
    final points = [for (final line in series) ...line.points];

    final yBounds = calculateFlexChartYAxis(points);

    return FlexLineChartInteraction(
      renderer: FlexLineChartRenderer(
        series: series,
        minY: yBounds.$1,
        maxY: yBounds.$2,
        yStep: yBounds.$3,
        curveLines: settings.curveLines,
        curveSmoothness: settings.curveSmoothness ?? 0.35,
        showGridlines: settings.showChartGridlines,
        fillChartArea: settings.fillChartArea,
        showLeftLabels: showLeftLabels,
        bottomLabels: bottomLabels,
        xLabels: [
          for (var i = 0; i < xLabels.length; i++)
            LineChartAxisLabel(i.toDouble(), xLabels[i], column: i),
        ],
        uniformXCount: xLabels.length,
        axisLabelColor: axisLabelColor,
      ),
      rowLabel: (mark) => tooltipText(mark.seriesIndex, mark.index),
    );
  }
}
