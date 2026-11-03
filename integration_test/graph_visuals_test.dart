import 'dart:io';
import 'dart:ui' as ui;

import 'package:drift/drift.dart' hide isNull;
import 'package:flex/database/database.dart';
import 'package:flex/graph/flex_line_chart.dart';
import 'package:flex/graph/graph_curve_settings.dart';
import 'package:flex/l10n/generated/app_localizations.dart';
import 'package:flex/main.dart' as app;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';

import 'test_database.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('chart visual settings update live charts on device', (
    tester,
  ) async {
    final database = createIntegrationTestDatabase();
    app.db = database;
    addTearDown(database.close);
    final setting = await database.settings.select().getSingle();
    final screenshotKey = GlobalKey();

    await tester.pumpWidget(
      StreamProvider<Setting>(
        initialData: setting,
        create: (_) => database.watchSettings(),
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: RepaintBoundary(
            key: screenshotKey,
            child: Scaffold(
              appBar: AppBar(title: const Text('Chart visuals')),
              body: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const GraphCurveSettings(showPreview: true),
                  const SizedBox(height: 24),
                  const Text('Strength / Cardio'),
                  SizedBox(
                    height: 240,
                    child: FlexLineChart(
                      points: const [
                        FlexLineChartPoint(0, 3),
                        FlexLineChartPoint(1, 9),
                        FlexLineChartPoint(2, 5),
                        FlexLineChartPoint(3, 10),
                        FlexLineChartPoint(4, 6),
                      ],
                      dates: [
                        for (var day = 1; day <= 5; day++)
                          DateTime(2026, 11, day),
                      ],
                      tooltipText: (index) => '$index',
                      showTrendLine: false,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text('Global progress'),
                  SizedBox(
                    key: const Key('global-progress-preview'),
                    height: 240,
                    child: FlexGroupedLineChart(
                      series: const [
                        FlexLineChartSeries(
                          name: 'Push',
                          color: Colors.deepPurple,
                          points: [
                            FlexLineChartPoint(0, 5),
                            FlexLineChartPoint(1, 8),
                            FlexLineChartPoint(2, 6),
                            FlexLineChartPoint(3, 10),
                          ],
                        ),
                        FlexLineChartSeries(
                          name: 'Pull',
                          color: Colors.teal,
                          points: [
                            FlexLineChartPoint(0, 8),
                            FlexLineChartPoint(1, 5),
                            FlexLineChartPoint(2, 9),
                            FlexLineChartPoint(3, 7),
                          ],
                        ),
                      ],
                      xLabels: const ['Mon', 'Tue', 'Wed', 'Thu'],
                      tooltipText: (seriesIndex, xIndex) =>
                          '$seriesIndex:$xIndex',
                      bottomLabels: true,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    Future<void> capture(String name) async {
      final boundary =
          screenshotKey.currentContext!.findRenderObject()!
              as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 1);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        image.dispose();
        final directory = Directory(
          Platform.environment['FLEX_GRAPH_SCREENSHOT_DIR'] ??
              Directory.systemTemp.path,
        );
        await directory.create(recursive: true);
        final output = File('${directory.path}/$name.png');
        await output.writeAsBytes(bytes!.buffer.asUint8List());
        print('Saved ${output.path}');
      });
    }

    await capture('graph_visuals_default');

    await tester.tap(find.byKey(const Key('chart-gridlines-toggle')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('chart-shading-toggle')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('curve-lines-toggle')));
    await tester.pumpAndSettle();

    final updated = await database.settings.select().getSingle();
    expect(updated.showChartGridlines, isTrue);
    expect(updated.fillChartArea, isFalse);
    expect(updated.curveLines, isFalse);
    await capture('graph_visuals_toggled');

    await tester.scrollUntilVisible(
      find.byKey(const Key('global-progress-preview')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await capture('graph_visuals_global');
  });
}
