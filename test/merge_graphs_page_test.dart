import 'package:flex/bottom_nav.dart';
import 'package:flex/home_page.dart';
import 'package:flex/graph/graphs_page.dart';
import 'package:flex/settings/category_management_page.dart';
import 'package:flex/database/categories.dart';
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

  testWidgets('mobile merge and category actions clear the floating dock', (
    tester,
  ) async {
    final harness = await FlexTestHarness.create();
    await createCategory('Legs');
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 800);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await harness.pump(
      tester,
      const HomePage(),
      surfaceSize: const Size(390, 800),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('GraphsPage')));
    await tester.pumpAndSettle();
    final navigator = tester
        .state<GraphsPageState>(find.byType(GraphsPage))
        .navKey
        .currentState!;
    navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => MergeGraphsPage(summaries: mergeable),
      ),
    );
    await tester.pumpAndSettle();
    final dock = find.byType(BottomNav);
    final merge = find.byKey(const Key('confirm-merge-graphs'));
    expect(
      tester.getBottomLeft(merge).dy,
      lessThanOrEqualTo(tester.getBottomLeft(dock).dy - bottomNavHeight),
    );
    expect(merge.hitTestable(), findsOneWidget);
    navigator.pop();
    await tester.pumpAndSettle();
    navigator.push(
      MaterialPageRoute<void>(builder: (_) => const CategoryManagementPage()),
    );
    await tester.pumpAndSettle();
    final fab = find.byType(FloatingActionButton);
    expect(
      tester.getBottomLeft(fab).dy,
      lessThanOrEqualTo(tester.getBottomLeft(dock).dy - bottomNavHeight),
    );
    await tester.tap(fab);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
  });

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
