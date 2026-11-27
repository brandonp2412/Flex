import 'dart:math';

import 'package:flex/database/database.dart';
import 'package:flex/graph/flex_line_chart_interaction.dart';
import 'package:flex/graph/flex_line_chart_layout.dart';
import 'package:flex/graph/flex_line_chart_point.dart';
import 'package:flex/graph/flex_line_chart_renderer.dart';
import 'package:flex/graph/flex_line_chart_series.dart';
import 'package:flex/graph/line_chart_axis_label.dart';
import 'package:flex/utils.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

export 'package:flex/graph/flex_line_chart_point.dart';
export 'package:flex/graph/flex_line_chart_series.dart';
export 'package:flex/graph/flex_grouped_line_chart.dart';

class FlexLineChart extends StatelessWidget {
  final List<FlexLineChartPoint> points;
  final Color? lineColor;
  final List<DateTime> dates;
  final bool? hideBottom;
  final bool? hideLeft;
  final bool? showTrendLine;
  final bool timeBasedXAxis;
  final String Function(int index) tooltipText;
  final ValueChanged<int>? onPointSelected;

  static (double, double) calculateYBounds(List<FlexLineChartPoint> points) =>
      calculateFlexChartYBounds(points);

  @visibleForTesting
  static double get axisLabelFontSize => flexChartLabelSize;

  @visibleForTesting
  static FontWeight get axisLabelFontWeight => flexChartLabelWeight;

  static double tooltipTopForMarks(
    List<double> markYs, {
    required int rowCount,
    bool hasTitle = false,
  }) {
    if (markYs.isEmpty) return 0;

    final tooltipHeight =
        (hasTitle ? flexChartRowHeight : 0) +
        rowCount * flexChartRowHeight +
        flexChartTipPadding * 2;
    return markYs.reduce(min) - tooltipHeight - flexChartTooltipDotGap;
  }

  static List<int> selectXAxisLabelIndices(
    List<double> centers,
    List<double> widths,
    double minGap,
  ) {
    final count = centers.length;
    if (count == 0) return const [];
    if (count == 1) return const [0];

    final order = List<int>.generate(count, (index) => index)
      ..sort((a, b) => centers[a].compareTo(centers[b]));
    final first = order.first;
    final last = order.last;
    final lastLeft = centers[last] - widths[last] / 2;

    // First determine how many labels actually fit while reserving both edges.
    final packed = <int>[first];
    var lastRight = centers[first] + widths[first] / 2;
    for (final index in order.skip(1).take(count - 2)) {
      final left = centers[index] - widths[index] / 2;
      final right = centers[index] + widths[index] / 2;
      if (left < lastRight + minGap || right + minGap > lastLeft) continue;
      packed.add(index);
      lastRight = right;
    }
    packed.add(last);

    if (packed.length <= 2 || packed.length == count) {
      packed.sort();
      return packed;
    }

    // Keep that adaptive label count, but choose the middle labels nearest
    // evenly spaced visual targets instead of packing them left-to-right.
    final balanced = <int>[first];
    var prevPos = 0;
    final span = centers[last] - centers[first];

    for (var slot = 1; slot < packed.length - 1; slot++) {
      final target = centers[first] + span * slot / (packed.length - 1);
      final remainingSlots = packed.length - 1 - slot;
      final maxPos = order.length - 1 - remainingSlots;
      var bestPos = -1;
      var bestDistance = double.infinity;

      for (var position = prevPos + 1; position <= maxPos; position++) {
        final index = order[position];
        final previous = balanced.last;
        final left = centers[index] - widths[index] / 2;
        final previousRight = centers[previous] + widths[previous] / 2;
        if (left < previousRight + minGap) continue;

        final distance = (centers[index] - target).abs();
        if (distance <= bestDistance) {
          bestDistance = distance;
          bestPos = position;
        }
      }

      if (bestPos < 0) {
        packed.sort();
        return packed;
      }

      balanced.add(order[bestPos]);
      prevPos = bestPos;
    }

    balanced.add(last);

    for (var i = 1; i < balanced.length; i++) {
      final previous = balanced[i - 1];
      final current = balanced[i];
      final gap =
          centers[current] -
          widths[current] / 2 -
          (centers[previous] + widths[previous] / 2);
      if (gap < minGap) {
        packed.sort();
        return packed;
      }
    }

    balanced.sort();
    return balanced;
  }

  const FlexLineChart({
    super.key,
    required this.points,
    this.lineColor,
    required this.tooltipText,
    this.dates = const [],
    this.onPointSelected,
    this.hideBottom,
    this.hideLeft,
    this.showTrendLine = true,
    this.timeBasedXAxis = false,
  });

  List<FlexLineChartPoint> _calculateTrendLine(
    List<FlexLineChartPoint> source,
  ) {
    if (source.length < 2) return const [];

    double sumX = 0;
    double sumY = 0;
    double sumXY = 0;
    double sumXX = 0;
    for (final point in source) {
      sumX += point.x;
      sumY += point.y;
      sumXY += point.x * point.y;
      sumXX += point.x * point.x;
    }

    final n = source.length;
    final denominator = n * sumXX - sumX * sumX;
    if (denominator.abs() < 1e-12) return const [];

    final slope = (n * sumXY - sumX * sumY) / denominator;
    final intercept = (sumY - slope * sumX) / n;
    final start = source.first;
    final end = source.last;

    return [
      FlexLineChartPoint(
        start.x,
        slope * start.x + intercept,
        column: start.column,
      ),
      FlexLineChartPoint(end.x, slope * end.x + intercept, column: end.column),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<Setting>();
    final colorScheme = Theme.of(context).colorScheme;
    final primary = lineColor ?? colorScheme.primary;
    final secondary = colorScheme.secondary;
    final labels = <LineChartAxisLabel>[];

    if (hideBottom != true) {
      for (
        var index = 0;
        index < points.length && index < dates.length;
        index++
      ) {
        final created = dates[index];
        labels.add(
          LineChartAxisLabel(
            points[index].x,
            formatDisplayDate(context, created, settings.shortDateFormat),
            column: points[index].column ?? index,
          ),
        );
      }
    }

    return FlexLineChartInteraction(
      renderer: FlexLineChartRenderer.fromSettings(
        settings: settings,
        series: [FlexLineChartSeries(points: points, color: primary)],
        trendSeries: showTrendLine == true
            ? FlexLineChartSeries(
                points: _calculateTrendLine(points),
                color: secondary,
              )
            : null,
        showLeftLabels: hideLeft != true,
        bottomLabels: hideBottom != true,
        xLabels: labels,
        uniformXCount: timeBasedXAxis ? null : points.length,
        axisLabelColor: colorScheme.onSurface,
      ),
      rowLabel: (mark) => tooltipText(mark.index),
      onPointSelected: onPointSelected,
    );
  }
}
