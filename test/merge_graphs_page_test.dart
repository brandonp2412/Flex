import 'package:flex/database/exercise_analytics.dart';
import 'package:flex/graph/merge_graphs_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_app.dart';

GraphExerciseSummary summary({
  required int? id,
  required String name,
  bool cardio = false,
  bool bodyWeight = false,
  String unit = 'kg',
}) => GraphExerciseSummary(
  exerciseId: id,
  bodyWeight: bodyWeight,
  name: name,
  unit: unit,
  cardio: cardio,
  weight: 50,
  reps: 8,
  duration: 0,
  distance: 0,
  created: DateTime(2026, 11, 1),
);

void main() {
  final mergeable = [
    summary(id: 100, name: 'Machine row'),
    summary(id: 101, name: 'Cable row'),
  ];

  for (final size in [
    const Size(320, 640),
    const Size(360, 800),
    const Size(390, 844),
    const Size(412, 915),
    const Size(1440, 900),
  ]) {
    testWidgets('Merge review lays out without overflow at $size', (
      WidgetTester tester,
    ) async {
      final harness = await FlexTestHarness.create();
      await harness.pump(
        tester,
        MergeGraphsPage(summaries: mergeable),
        surfaceSize: size,
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const Key('merge-name-slider')),
        150,
        scrollable: find.byType(Scrollable).first,
      );

      expect(find.byKey(const Key('merge-name-slider')), findsOneWidget);
      expect(find.byKey(const Key('confirm-merge-graphs')), findsOneWidget);
      expect(tester.takeException(), isNull);

      final slider = tester.widget<Slider>(
        find.byKey(const Key('merge-name-slider')),
      );
      slider.onChanged!(mergeable.length.toDouble());
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const Key('merge-custom-name')),
        120,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.byKey(const Key('merge-custom-name')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('body weight cannot be merged with an exercise', (
    WidgetTester tester,
  ) async {
    final harness = await FlexTestHarness.create();
    await harness.pump(
      tester,
      MergeGraphsPage(
        summaries: [
          summary(id: null, name: 'Weight', bodyWeight: true),
          summary(id: 100, name: 'Bench press'),
        ],
      ),
    );
    await tester.pumpAndSettle();

    final button = tester.widget<FilledButton>(
      find.byKey(const Key('confirm-merge-graphs')),
    );
    expect(button.onPressed, isNull);
    await tester.scrollUntilVisible(
      find.textContaining('Body weight cannot be merged'),
      150,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.textContaining('Body weight cannot be merged'), findsOneWidget);
  });
}
