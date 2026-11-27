import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

@immutable
class LineChartAxisLabel {
  final double x;
  final int? column;
  final String text;

  const LineChartAxisLabel(this.x, this.text, {this.column});
}
