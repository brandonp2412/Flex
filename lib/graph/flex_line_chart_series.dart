import 'package:flex/graph/flex_line_chart_point.dart';
import 'package:flutter/material.dart';

@immutable
class FlexLineChartSeries {
  final List<FlexLineChartPoint> points;
  final Color color;
  final String name;

  const FlexLineChartSeries({
    required this.points,
    required this.color,
    this.name = '',
  });
}
