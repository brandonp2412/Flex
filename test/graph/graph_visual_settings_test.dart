import 'dart:ui' as ui;

import 'package:drift/drift.dart' hide isNull;
import 'package:flex/database/database.dart';
import 'package:flex/graph/flex_line_chart.dart';
import 'package:flex/graph/graph_curve_settings.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../mock_tests.dart';
import '../support/test_app.dart';

const _points = [
  FlexLineChartPoint(0, 3),
  FlexLineChartPoint(1, 8),
  FlexLineChartPoint(2, 4),
  FlexLineChartPoint(3, 10),
  FlexLineChartPoint(4, 6),
];

void main() {
  test(
    'chart visuals use DB defaults and persist with existing curves',
    () async {
      final database = testDb();
      try {
        final initial = await database.settings.select().getSingle();
        expect(initial.showChartGridlines, isFalse);
        expect(initial.fillChartArea, isTrue);
        expect(initial.curveLines, isTrue);

        await database.settings.update().write(
          const SettingsCompanion(
            showChartGridlines: Value(true),
            fillChartArea: Value(false),
            curveSmoothness: Value(0.7),
          ),
        );

        final saved = await database.settings.select().getSingle();
        expect(saved.showChartGridlines, isTrue);
        expect(saved.fillChartArea, isFalse);
        expect(saved.curveLines, initial.curveLines);
        expect(saved.curveSmoothness, 0.7);
      } finally {
        await database.close();
      }
    },
  );

  testWidgets('visual controls update DB and preview on mobile', (
    tester,
  ) async {
    final harness = await FlexTestHarness.create();
    await harness.pump(
      tester,
      const Scaffold(
        body: SingleChildScrollView(
          child: GraphCurveSettings(showPreview: true),
        ),
      ),
      surfaceSize: const Size(360, 800),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('chart-visuals-preview')), findsOneWidget);
    expect(find.byKey(const Key('chart-gridlines-toggle')), findsOneWidget);
    expect(find.byKey(const Key('chart-shading-toggle')), findsOneWidget);
    expect(find.byKey(const Key('curve-lines-toggle')), findsOneWidget);

    await tester.tap(find.byKey(const Key('chart-gridlines-toggle')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('chart-shading-toggle')));
    await tester.pumpAndSettle();

    var saved = await harness.database.settings.select().getSingle();
    expect(saved.showChartGridlines, isTrue);
    expect(saved.fillChartArea, isFalse);

    await tester.drag(
      find.byKey(const Key('curve-smoothness-slider')),
      const Offset(90, 0),
    );
    await tester.pumpAndSettle();
    saved = await harness.database.settings.select().getSingle();
    expect(saved.curveSmoothness, greaterThan(0.35));

    await tester.tap(find.byKey(const Key('curve-lines-toggle')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<Slider>(find.byKey(const Key('curve-smoothness-slider')))
          .onChanged,
      isNull,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('compact desktop graph options reuse visual switches', (
    tester,
  ) async {
    final harness = await FlexTestHarness.create();
    await harness.pump(
      tester,
      const Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(width: 680, child: GraphCurveSettings(compact: true)),
        ),
      ),
      surfaceSize: const Size(900, 600),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('chart-gridlines-toggle')), findsOneWidget);
    expect(find.byKey(const Key('chart-shading-toggle')), findsOneWidget);
    expect(find.byKey(const Key('curve-lines-toggle')), findsOneWidget);
    expect(find.byKey(const Key('curve-smoothness-slider')), findsOneWidget);

    await tester.tap(find.byKey(const Key('chart-gridlines-toggle')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('chart-shading-toggle')));
    await tester.pumpAndSettle();

    final saved = await harness.database.settings.select().getSingle();
    expect(saved.showChartGridlines, isTrue);
    expect(saved.fillChartArea, isFalse);
    expect(tester.takeException(), isNull);
  });

  for (final grouped in [false, true]) {
    testWidgets(
      '${grouped ? 'Global Progress' : 'Strength/Cardio'} line chart repaints '
      'for gridlines, shading and curves',
      (tester) async {
        final harness = await FlexTestHarness.create();
        final chart = grouped
            ? FlexGroupedLineChart(
                series: const [
                  FlexLineChartSeries(
                    name: 'Strength',
                    color: Colors.deepPurple,
                    points: _points,
                  ),
                  FlexLineChartSeries(
                    name: 'Cardio',
                    color: Colors.teal,
                    points: [
                      FlexLineChartPoint(0, 6),
                      FlexLineChartPoint(1, 4),
                      FlexLineChartPoint(2, 7),
                      FlexLineChartPoint(3, 5),
                      FlexLineChartPoint(4, 9),
                    ],
                  ),
                ],
                xLabels: const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri'],
                tooltipText: (seriesIndex, index) => '$seriesIndex:$index',
                bottomLabels: true,
              )
            : FlexLineChart(
                points: _points,
                dates: [
                  for (var day = 1; day <= 5; day++) DateTime(2026, 11, day),
                ],
                tooltipText: (index) => '$index',
                showTrendLine: false,
              );

        await harness.pump(
          tester,
          Scaffold(
            body: Center(
              child: SizedBox(
                width: 420,
                height: 240,
                child: RepaintBoundary(
                  key: const Key('chart-render'),
                  child: chart,
                ),
              ),
            ),
          ),
          surfaceSize: const Size(500, 350),
        );
        await tester.pumpAndSettle();

        Future<Uint8List> pixels() async {
          final boundary = tester.renderObject<RenderRepaintBoundary>(
            find.byKey(const Key('chart-render')),
          );
          return (await tester.runAsync(() async {
            final image = await boundary.toImage();
            final data = await image.toByteData(
              format: ui.ImageByteFormat.rawRgba,
            );
            image.dispose();
            return data!.buffer.asUint8List();
          }))!;
        }

        var previous = await pixels();
        for (final change in [
          const SettingsCompanion(showChartGridlines: Value(true)),
          const SettingsCompanion(fillChartArea: Value(false)),
          const SettingsCompanion(curveSmoothness: Value(0.85)),
          const SettingsCompanion(curveLines: Value(false)),
        ]) {
          await harness.database.settings.update().write(change);
          await tester.pumpAndSettle();
          final next = await pixels();
          expect(listEquals(previous, next), isFalse);
          previous = next;
        }

        expect(FlexLineChart.axisLabelFontSize, 12);
        expect(FlexLineChart.axisLabelFontWeight, FontWeight.w600);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
