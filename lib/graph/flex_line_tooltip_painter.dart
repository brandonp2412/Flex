import 'package:drafter/drafter.dart';
import 'package:drafter/painting.dart';
import 'package:flex/graph/flex_line_chart.dart';
import 'package:flex/graph/flex_line_chart_layout.dart';
import 'package:flutter/material.dart';

class FlexLineTooltipPainter extends CustomPainter {
  final ValueNotifier<int?> activeIndex;
  final ChartScene scene;
  final DrafterThemeColors theme;
  final String Function(PlotMark mark) rowLabel;

  FlexLineTooltipPainter({
    required this.activeIndex,
    required this.scene,
    required this.theme,
    required this.rowLabel,
  }) : super(repaint: activeIndex);

  @override
  void paint(Canvas canvas, Size size) {
    final index = activeIndex.value;
    final bounds = scene.bounds;
    if (index == null || bounds == null) return;

    final marks = ChartHitTest.marksAtIndex(scene, index);
    if (marks.isEmpty) return;

    final x = scene.scale?.xForIndex(index) ?? marks.first.center.dx;
    drawTrackball(
      canvas,
      x: x,
      top: bounds.top,
      bottom: bounds.bottom,
      lineColor: theme.crosshair,
      markers: [for (final mark in marks) mark.center],
      markerColors: [for (final mark in marks) mark.color],
    );
    final title = marks.first.label.isEmpty ? null : marks.first.label;
    drawFlexChartTooltip(
      canvas,
      anchor: Offset(
        x,
        FlexLineChart.tooltipTopForMarks(
          [for (final mark in marks) mark.center.dy],
          rowCount: marks.length,
          hasTitle: title != null,
        ),
      ),
      container: size,
      title: title,
      background: theme.tooltipBackground,
      textColor: theme.tooltipText,
      mutedTextColor: theme.tooltipMutedText,
      rows: [
        for (final mark in marks)
          TooltipRow(rowLabel(mark), swatch: mark.color),
      ],
    );
  }

  @override
  bool shouldRepaint(covariant FlexLineTooltipPainter oldDelegate) =>
      oldDelegate.scene != scene ||
      oldDelegate.theme != theme ||
      oldDelegate.rowLabel != rowLabel;
}
