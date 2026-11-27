import 'dart:math';

import 'package:drafter/drafter.dart';
import 'package:drafter/painting.dart';
import 'package:flex/graph/flex_line_chart.dart';
import 'package:flex/graph/flex_line_chart_layout.dart';
import 'package:flex/graph/flex_line_chart_scale.dart';
import 'package:flex/graph/line_chart_axis_label.dart';
import 'package:flutter/material.dart';

class FlexLineChartRenderer extends ChartRenderer
    implements InteractiveRenderer {
  final List<FlexLineChartSeries> series;
  final FlexLineChartSeries? trendSeries;
  final double minY;
  final double maxY;
  final double yStep;
  final bool curveLines;
  final double curveSmoothness;
  final bool showGridlines;
  final bool fillChartArea;
  final bool showLeftLabels;
  final bool bottomLabels;
  final List<LineChartAxisLabel> xLabels;
  final int? uniformXCount;
  final Color axisLabelColor;

  const FlexLineChartRenderer({
    required this.series,
    required this.minY,
    required this.maxY,
    required this.yStep,
    required this.curveLines,
    required this.curveSmoothness,
    required this.showGridlines,
    required this.fillChartArea,
    required this.showLeftLabels,
    required this.bottomLabels,
    required this.xLabels,
    required this.uniformXCount,
    required this.axisLabelColor,
    this.trendSeries,
  });

  ChartBounds _bounds(Size size) {
    final left = showLeftLabels ? 48.0 : 8.0;
    final bottom = bottomLabels
        ? flexChartBottomLabelInset
        : flexChartBottomInset;
    return ChartBounds.insets(
      size,
      left: left,
      top: flexChartChartTopInset,
      right: 8,
      bottom: bottom,
    );
  }

  List<FlexLineChartPoint> get _allPoints => [
    for (final line in series) ...line.points,
  ];

  bool hasIndex(int index) {
    for (final line in series) {
      for (var pointIndex = 0; pointIndex < line.points.length; pointIndex++) {
        if ((line.points[pointIndex].column ?? pointIndex) == index)
          return true;
      }
    }
    return false;
  }

  (double, double) get _xBounds {
    final points = _allPoints;
    if (points.isEmpty) return (0, 1);
    final minX = points.map((point) => point.x).reduce(min);
    final maxX = points.map((point) => point.x).reduce(max);
    return maxX == minX ? (minX - 0.5, maxX + 0.5) : (minX, maxX);
  }

  double _xForPoint(
    FlexLineChartPoint point,
    int pointIndex,
    ChartBounds bounds,
  ) {
    final count = uniformXCount;
    if (count != null) {
      if (count <= 1) return bounds.left + bounds.width / 2;
      final column = point.column ?? pointIndex;
      return bounds.left + bounds.width * column / (count - 1);
    }

    final xBounds = _xBounds;
    return bounds.left +
        bounds.width * (point.x - xBounds.$1) / (xBounds.$2 - xBounds.$1);
  }

  double _yForValue(double value, ChartBounds bounds) {
    final span = maxY - minY;
    if (span == 0) return bounds.bottom;
    return bounds.bottom - (value - minY) / span * bounds.height;
  }

  List<Offset> _pixelPoints(FlexLineChartSeries line, ChartBounds bounds) => [
    for (var i = 0; i < line.points.length; i++)
      Offset(
        _xForPoint(line.points[i], i, bounds),
        _yForValue(line.points[i].y, bounds),
      ),
  ];

  Path _linePath(List<Offset> points) {
    if (!curveLines || points.length < 3) return polylinePath(points);

    final tension = curveSmoothness.clamp(0.0, 1.0);
    if ((tension - 0.35).abs() < 0.001) return smoothPath(points);

    final path = Path()..moveTo(points.first.dx, points.first.dy);
    final controlScale = tension / 2.1;
    for (var i = 0; i < points.length - 1; i++) {
      final p0 = points[i == 0 ? i : i - 1];
      final p1 = points[i];
      final p2 = points[i + 1];
      final p3 = points[i + 2 >= points.length ? i + 1 : i + 2];
      final c1 = Offset(
        p1.dx + (p2.dx - p0.dx) * controlScale,
        p1.dy + (p2.dy - p0.dy) * controlScale,
      );
      final c2 = Offset(
        p2.dx - (p3.dx - p1.dx) * controlScale,
        p2.dy - (p3.dy - p1.dy) * controlScale,
      );
      path.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, p2.dx, p2.dy);
    }
    return path;
  }

  void _drawSeries(
    Canvas canvas,
    ChartBounds bounds,
    FlexLineChartSeries line, {
    required bool fill,
    required double progress,
  }) {
    final points = _pixelPoints(line, bounds);
    if (points.length < 2) return;

    final path = _linePath(points);
    final metrics = path.computeMetrics().toList();
    final drawn = Path();
    final clamped = progress.clamp(0.0, 1.0);
    for (final metric in metrics) {
      drawn.addPath(
        metric.extractPath(0, metric.length * clamped),
        Offset.zero,
      );
    }

    if (fill && fillChartArea) {
      final fillPath = Path.from(path)
        ..lineTo(points.last.dx, bounds.bottom)
        ..lineTo(points.first.dx, bounds.bottom)
        ..close();
      canvas.drawPath(
        fillPath,
        Paint()
          ..style = PaintingStyle.fill
          ..shader = areaGradientShader(
            line.color,
            top: points.map((point) => point.dy).reduce(min),
            bottom: bounds.bottom,
            topAlpha: series.length > 1 ? 0.16 : 0.3,
          ),
      );
    }

    canvas.drawPath(
      drawn,
      Paint()
        ..color = line.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..isAntiAlias = true,
    );
  }

  void _drawDashedTrend(
    Canvas canvas,
    ChartBounds bounds,
    FlexLineChartSeries trend,
  ) {
    final points = _pixelPoints(trend, bounds);
    if (points.length < 2) return;
    final path = polylinePath(points);
    final paint = Paint()
      ..color = trend.color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;

    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final end = min(distance + 5, metric.length);
        canvas.drawPath(metric.extractPath(distance, end), paint);
        distance += 10;
      }
    }
  }

  void _drawAxes(Canvas canvas, ChartBounds bounds) {
    if (showLeftLabels) {
      final tickCount = ((maxY - minY) / yStep).round();
      for (var i = 0; i <= tickCount; i++) {
        final value = minY + yStep * i;
        final y = _yForValue(value, bounds);
        drawChartText(
          canvas,
          ChartFormatting.format(value),
          Offset(bounds.left - 7, y),
          color: axisLabelColor,
          fontSize: flexChartLabelSize,
          weight: flexChartLabelWeight,
          h: HAlign.end,
          v: VAlign.center,
        );
      }
    }

    if (!bottomLabels || xLabels.isEmpty) return;
    final centers = <double>[];
    final widths = <double>[];
    for (final label in xLabels) {
      final point = FlexLineChartPoint(label.x, 0, column: label.column);
      centers.add(_xForPoint(point, label.column ?? centers.length, bounds));
      widths.add(
        measureChartText(
          label.text,
          fontSize: flexChartLabelSize,
          weight: flexChartLabelWeight,
          color: axisLabelColor,
        ),
      );
    }
    final keep = FlexLineChart.selectXAxisLabelIndices(
      centers,
      widths,
      flexChartAxisLabelGap,
    ).toSet();
    for (var i = 0; i < xLabels.length; i++) {
      if (!keep.contains(i)) continue;
      drawChartText(
        canvas,
        xLabels[i].text,
        Offset(centers[i], bounds.bottom + 15),
        color: axisLabelColor,
        fontSize: flexChartLabelSize,
        weight: flexChartLabelWeight,
        h: HAlign.center,
        v: VAlign.center,
      );
    }
  }

  @override
  void draw(
    Canvas canvas,
    Size size,
    DrafterThemeColors theme,
    double progress,
  ) {
    if (size.isEmpty) return;
    final bounds = _bounds(size);
    if (showGridlines) {
      final gridPaint = Paint()
        ..color = axisLabelColor.withValues(alpha: 0.12)
        ..strokeWidth = 1;
      for (var i = 0; i <= 4; i++) {
        final y = bounds.top + bounds.height * i / 4;
        canvas.drawLine(
          Offset(bounds.left, y),
          Offset(bounds.right, y),
          gridPaint,
        );
      }
    }
    _drawAxes(canvas, bounds);
    canvas.save();
    canvas.clipRect(
      Rect.fromLTRB(bounds.left, bounds.top, bounds.right, bounds.bottom),
    );

    for (var i = 0; i < series.length; i++) {
      _drawSeries(canvas, bounds, series[i], fill: true, progress: progress);
    }

    final trend = trendSeries;
    if (trend != null && trend.points.isNotEmpty) {
      _drawDashedTrend(canvas, bounds, trend);
    }
    canvas.restore();
  }

  @override
  ChartScene buildScene(Size size) {
    final bounds = _bounds(size);
    final xByIndex = <int, double>{};

    for (final line in series) {
      for (var pointIndex = 0; pointIndex < line.points.length; pointIndex++) {
        final point = line.points[pointIndex];
        final index = point.column ?? pointIndex;
        xByIndex.putIfAbsent(
          index,
          () => _xForPoint(point, pointIndex, bounds),
        );
      }
    }

    final orderedColumns = xByIndex.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    final hitRegions = <int, Rect>{};
    for (var i = 0; i < orderedColumns.length; i++) {
      final column = orderedColumns[i];
      final left = i == 0
          ? bounds.left
          : (orderedColumns[i - 1].value + column.value) / 2;
      final right = i == orderedColumns.length - 1
          ? bounds.right
          : (column.value + orderedColumns[i + 1].value) / 2;
      hitRegions[column.key] = Rect.fromLTRB(
        left,
        bounds.top,
        right,
        bounds.bottom,
      );
    }

    final marks = <PlotMark>[];
    for (var seriesIndex = 0; seriesIndex < series.length; seriesIndex++) {
      final line = series[seriesIndex];
      for (var pointIndex = 0; pointIndex < line.points.length; pointIndex++) {
        final point = line.points[pointIndex];
        final index = point.column ?? pointIndex;
        marks.add(
          PlotMark(
            index: index,
            seriesIndex: seriesIndex,
            seriesName: line.name,
            label: '',
            value: point.y,
            center: Offset(
              _xForPoint(point, pointIndex, bounds),
              _yForValue(point.y, bounds),
            ),
            region: hitRegions[index],
            color: line.color,
          ),
        );
      }
    }

    final scale = xByIndex.isEmpty
        ? null
        : FlexLineChartScale(
            bounds: bounds,
            count: xByIndex.length,
            minValue: minY,
            maxValue: maxY,
            xByIndex: xByIndex,
          );

    return ChartScene(
      bounds: bounds,
      scale: scale,
      categories: const [],
      marks: marks,
    );
  }

  @override
  String get accessibilityLabel => 'Line chart';

  @override
  String get accessibilityValue {
    final count = _allPoints.length;
    return count == 0 ? 'No data' : '$count points';
  }
}
