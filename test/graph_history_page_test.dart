import 'package:flex/database/exercise_set_repository.dart';
import 'package:flex/database/body_weight_repository.dart';
import 'package:flex/database/exercise_analytics.dart';
import 'package:flex/weight_page.dart';
import 'package:flutter/gestures.dart';
import 'package:flex/graph/graph_history_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../integration_test/support/mock_tab_controller.dart';
import '../integration_test/support/fixtures.dart';
import 'support/test_app.dart';

void main() {
  testWidgets(
    'long press selects multiple graph history rows and deletes them',
    (WidgetTester tester) async {
      final harness = await FlexTestHarness.create();
      await insertExerciseSetFixture(
        harness.database,
        'Graph history test',
        reps: 2,
        weight: 3,
        created: testNow.subtract(const Duration(days: 1)),
      );
      await insertExerciseSetFixture(
        harness.database,
        'Graph history test',
        reps: 4,
        weight: 5,
        created: testNow,
      );
      final sets = (await getExerciseSets(
        harness.database,
        search: 'Graph history test',
      )).where((set) => set.name == 'Graph history test').toList();
      final tabController = MockTabController();
      addTearDown(tabController.dispose);

      await harness.pump(
        tester,
        GraphHistoryPage(
          name: 'Graph history test',
          initialSets: sets,
          tabController: tabController,
        ),
      );
      await tester.pumpAndSettle();

      final list = tester.widget<ListView>(find.byType(ListView));
      expect((list.padding! as EdgeInsets).top, 0);
      expect(find.text('2 × 3 kg'), findsOne);
      expect(find.text('4 × 5 kg'), findsOne);
      await tester.longPress(find.text('4 × 5 kg'));
      await tester.pumpAndSettle();
      expect(find.text('1 selected'), findsOne);

      await tester.tap(find.text('2 × 3 kg'));
      await tester.pumpAndSettle();
      expect(find.text('2 selected'), findsOne);
      expect(find.byTooltip('Edit selected'), findsOne);

      await tester.tap(find.byTooltip('Delete selected'));
      await tester.pumpAndSettle();
      expect(find.text('Confirm delete'), findsOne);

      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();

      final remaining = (await getExerciseSets(
        harness.database,
        search: 'Graph history test',
      )).where((set) => set.name == 'Graph history test');
      expect(remaining, isEmpty);
      expect(find.text('No history yet for Graph history test'), findsOne);
    },
  );
  testWidgets(
    'refresh keeps exact exercise history when similar names are newer',
    (WidgetTester tester) async {
      final harness = await FlexTestHarness.create();
      final exact = await insertExerciseSetFixture(
        harness.database,
        'Press',
        reps: 5,
        weight: 100,
        created: testNow.subtract(const Duration(days: 30)),
      );
      for (var i = 0; i < 25; i++) {
        await insertExerciseSetFixture(
          harness.database,
          'Bench Press',
          reps: i + 1,
          weight: 50 + i.toDouble(),
          created: testNow.subtract(Duration(minutes: i)),
        );
      }

      final initialSets = await getExerciseSetsForExercise(
        harness.database,
        exerciseName: 'Press',
      );
      expect(initialSets.map((set) => set.id), contains(exact.id));

      final tabController = TabController(
        length: 4,
        initialIndex: 1,
        vsync: tester,
      );
      addTearDown(tabController.dispose);

      await harness.pump(
        tester,
        GraphHistoryPage(
          name: 'Press',
          initialSets: initialSets,
          tabController: tabController,
        ),
      );
      tabController.animateTo(2, duration: const Duration(milliseconds: 1));
      await tester.pumpAndSettle();

      expect(find.text('5 × 100 kg'), findsOneWidget);
      expect(find.text('No history yet for Press'), findsNothing);
    },
  );
  testWidgets('weight history edits and deletes only the weight record', (
    tester,
  ) async {
    final harness = await FlexTestHarness.create();
    final unrelated = await insertExerciseSetFixture(
      harness.database,
      'Unrelated press',
      reps: 5,
      weight: 50,
      created: testNow,
    );
    final weightId = await recordBodyWeight(
      harness.database,
      timestamp: testNow,
      weightKg: 80,
    );
    expect(unrelated.id, weightId);

    final tabController = MockTabController();
    addTearDown(tabController.dispose);
    await harness.pump(
      tester,
      GraphHistoryPage(
        name: 'Weight',
        initialSets: await getBodyWeightGraphHistory(),
        tabController: tabController,
        bodyWeight: true,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('1 × 80 kg'));
    await tester.pumpAndSettle();
    expect(find.byType(WeightPage), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).first, '81');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect((await getBodyWeightById(harness.database, weightId))?.weightKg, 81);
    expect(
      (await getExerciseSetById(harness.database, unrelated.id))?.weight,
      50,
    );
    expect(find.text('1 × 81 kg'), findsOneWidget);

    await tester.tap(find.text('1 × 81 kg'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(await getBodyWeightById(harness.database, weightId), isNull);
    expect(await getExerciseSetById(harness.database, unrelated.id), isNotNull);
  });

  testWidgets('desktop weight history context menu deletes the weight table', (
    tester,
  ) async {
    final harness = await FlexTestHarness.create();
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 800);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final unrelated = await insertExerciseSetFixture(
      harness.database,
      'Unrelated row',
      reps: 2,
      weight: 40,
      created: testNow,
    );
    final weightId = await recordBodyWeight(
      harness.database,
      timestamp: testNow,
      weightKg: 80,
    );
    expect(unrelated.id, weightId);
    final tabController = MockTabController();
    addTearDown(tabController.dispose);
    await harness.pump(
      tester,
      GraphHistoryPage(
        name: 'Weight',
        initialSets: await getBodyWeightGraphHistory(),
        tabController: tabController,
        bodyWeight: true,
      ),
      surfaceSize: const Size(1200, 800),
    );
    await tester.pumpAndSettle();

    final gesture = await tester.startGesture(
      tester.getCenter(find.text('1 × 80 kg')),
      kind: PointerDeviceKind.mouse,
      buttons: kSecondaryMouseButton,
    );
    await gesture.up();
    await tester.pumpAndSettle();
    expect(find.text('Delete'), findsOneWidget);
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(await getBodyWeightById(harness.database, weightId), isNull);
    expect(await getExerciseSetById(harness.database, unrelated.id), isNotNull);
  });
}
