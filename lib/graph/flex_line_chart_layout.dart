import 'dart:math';

import 'package:drafter/painting.dart';
import 'package:flex/graph/flex_line_chart_point.dart';
import 'package:flutter/material.dart';

const _edgePadFraction = 0.02;
const flexChartLabelSize = 12.0;
const flexChartLabelWeight = FontWeight.w600;
const flexChartAxisLabelGap = 12.0;
const flexChartChartTopInset = 24.0;
const flexChartBottomInset = 16.0;
const flexChartBottomLabelInset = 38.0;
const flexChartTipPadding = 8.0;
const flexChartRowHeight = 16.0;
const flexChartTooltipDotGap = 8.0;
const _tooltipFontSize = 10.0;
const _swatchSize = 8.0;
const _swatchGap = 6.0;

void drawFlexChartTooltip(
  Canvas canvas, {
  required Offset anchor,
  required Size container,
  required List<TooltipRow> rows,
  required Color background,
  required Color textColor,
  required Color mutedTextColor,
  String? title,
}) {
  final hasTitle = title != null && title.isNotEmpty;
  if (rows.isEmpty && !hasTitle) return;

  var maxWidth = 0.0;
  if (hasTitle) {
    maxWidth = measureChartText(
      title,
      color: textColor,
      fontSize: _tooltipFontSize,
      weight: FontWeight.w600,
    );
  }
  for (final row in rows) {
    final textWidth = measureChartText(
      row.text,
      color: textColor,
      fontSize: _tooltipFontSize,
    );
    final rowWidth =
        textWidth + (row.swatch == null ? 0 : _swatchSize + _swatchGap);
    maxWidth = max(maxWidth, rowWidth);
  }

  final titleHeight = hasTitle ? flexChartRowHeight : 0.0;
  final boxWidth = maxWidth + flexChartTipPadding * 2;
  final boxHeight =
      titleHeight + rows.length * flexChartRowHeight + flexChartTipPadding * 2;
  var left = anchor.dx + 12;
  if (left + boxWidth > container.width) {
    left = anchor.dx - 12 - boxWidth;
  }
  left = left.clamp(0.0, max(0.0, container.width - boxWidth)).toDouble();
  final top = anchor.dy
      .clamp(0.0, max(0.0, container.height - boxHeight))
      .toDouble();

  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromLTWH(left, top, boxWidth, boxHeight),
      const Radius.circular(8),
    ),
    Paint()..color = background,
  );

  var rowTop = top + flexChartTipPadding;
  if (hasTitle) {
    drawChartText(
      canvas,
      title,
      Offset(left + flexChartTipPadding, rowTop + flexChartRowHeight / 2),
      color: mutedTextColor,
      fontSize: _tooltipFontSize,
      weight: FontWeight.w600,
      v: VAlign.center,
    );
    rowTop += flexChartRowHeight;
  }
  for (final row in rows) {
    final rowCenter = rowTop + flexChartRowHeight / 2;
    var textX = left + flexChartTipPadding;
    if (row.swatch case final color?) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            textX,
            rowCenter - _swatchSize / 2,
            _swatchSize,
            _swatchSize,
          ),
          const Radius.circular(2),
        ),
        Paint()..color = color,
      );
      textX += _swatchSize + _swatchGap;
    }
    drawChartText(
      canvas,
      row.text,
      Offset(textX, rowCenter),
      color: textColor,
      fontSize: _tooltipFontSize,
      v: VAlign.center,
    );
    rowTop += flexChartRowHeight;
  }
}

double _niceYStep(double span) {
  final target = span / 4;
  final magnitude = pow(10, (log(target) / ln10).floor()).toDouble();
  final scaled = target / magnitude;
  final nice = switch (scaled) {
    < 1.5 => 1.0,
    < 2.25 => 2.0,
    < 3.75 => 2.5,
    < 7.5 => 5.0,
    _ => 10.0,
  };
  return nice * magnitude;
}

(double, double, double) calculateFlexChartYAxis(
  List<FlexLineChartPoint> points,
) {
  if (points.isEmpty) return (0, 1, 0.25);

  var minY = points.map((point) => point.y).reduce(min);
  var maxY = points.map((point) => point.y).reduce(max);
  if (maxY - minY < 1.0) {
    final center = (maxY + minY) / 2;
    minY = center - 0.5;
    maxY = center + 0.5;
  }

  final padding = (maxY - minY) * _edgePadFraction;
  final step = _niceYStep(maxY - minY);
  var lower = ((minY - padding) / step).floor() * step;
  final upper = ((maxY + padding) / step).ceil() * step;
  if (minY >= 0 && lower < 0) lower = 0;
  return (lower, upper, step);
}

(double, double) calculateFlexChartYBounds(List<FlexLineChartPoint> points) {
  final axis = calculateFlexChartYAxis(points);
  return (axis.$1, axis.$2);
}
