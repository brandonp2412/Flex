import 'package:flutter/foundation.dart';

@immutable
class FlexLineChartPoint {
  final double x;
  final double y;
  final int? column;

  const FlexLineChartPoint(this.x, this.y, {this.column});
}
