import 'package:flex/graph/graph_options_controls.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_app.dart';

void main() {
  testWidgets(
    'active graph options fit without overflow at a narrow desktop width',
    (WidgetTester tester) async {
      final harness = await FlexTestHarness.create();

      await harness.pump(
        tester,
        Scaffold(
          body: SingleChildScrollView(
            child: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 780,
                child: GraphOptionsControls(
                  shortDateFormat: 'M/d/yy',
                  startDate: null,
                  endDate: null,
                  onSelectStart: () {},
                  onClearStart: () {},
                  onSelectEnd: () {},
                  onClearEnd: () {},
                  limit: 20,
                  maxLimit: 100,
                  onLimitChanged: (_) {},
                  timeBasedXAxis: false,
                  onTimeAxisChange: (_) {},
                ),
              ),
            ),
          ),
        ),
        surfaceSize: const Size(820, 720),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Start date'), findsOneWidget);
      expect(find.text('Stop date'), findsOneWidget);
      expect(find.text('Data points'), findsOneWidget);
      expect(find.text('Time-based X axis'), findsOneWidget);
      expect(find.text('Curve lines'), findsOneWidget);

      final startY = tester.getTopLeft(find.text('Start date')).dy;
      final stopY = tester.getTopLeft(find.text('Stop date')).dy;
      final dataY = tester.getTopLeft(find.text('Data points')).dy;
      expect((startY - stopY).abs(), lessThan(2));
      expect(dataY, greaterThan(startY));
      expect(tester.takeException(), isNull);
    },
  );
}
