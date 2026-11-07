import 'package:flex/database/exercise_set_repository.dart';
import 'package:flex/database/exercise_set_view.dart';
import 'package:flex/plan/session_sets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_app.dart';

void main() {
  testWidgets('next pending set aligns with the preview edge after saving', (
    tester,
  ) async {
    final harness = await FlexTestHarness.create();
    final day = DateTime(2026, 11, 4);
    ExerciseSetView set(int id, double weight) => ExerciseSetView(
      bodyWeight: 0,
      cardio: false,
      created: day,
      distance: 0,
      duration: 0,
      id: id,
      name: 'Bench press',
      reps: 8,
      unit: 'kg',
      weight: weight,
    );

    final sets = ValueNotifier<List<ExerciseSetView>>([set(1, 100)]);
    addTearDown(sets.dispose);
    final previous = PreviousExerciseDay(
      day: day.subtract(const Duration(days: 1)),
      sets: List.filled(
        5,
        const PreviousExerciseSet(
          cardio: false,
          unit: 'kg',
          reps: 8,
          weight: 95,
          distance: 0,
          duration: 0,
          incline: null,
        ),
      ),
    );

    await harness.pump(
      tester,
      Scaffold(
        body: Center(
          child: SizedBox(
            width: 190,
            height: 80,
            child: ValueListenableBuilder<List<ExerciseSetView>>(
              valueListenable: sets,
              builder: (_, currentSets, _) => SessionSets(
                exerciseId: 1,
                workoutId: 1,
                sets: currentSets,
                previous: previous,
                compact: true,
              ),
            ),
          ),
        ),
      ),
      surfaceSize: const Size(430, 850),
    );
    await tester.pumpAndSettle();

    final scrollFinder = find.byKey(const Key('session-set-scroll'));
    final controller = tester
        .widget<SingleChildScrollView>(scrollFinder)
        .controller!;
    final initialOffset = controller.offset;
    expect(initialOffset, greaterThan(0));

    sets.value = [set(1, 100), set(2, 110)];
    await tester.pumpAndSettle();

    final cardFinder = find.ancestor(
      of: find.text('Set 3'),
      matching: find.byType(Card),
    );
    final viewport = tester.getRect(scrollFinder);
    final newestCard = tester.getRect(cardFinder);
    expect(controller.offset, greaterThan(initialOffset));
    expect(newestCard.right, closeTo(viewport.right - 8, 1));
    expect(controller.offset, lessThan(controller.position.maxScrollExtent));

    sets.value = [set(1, 100), set(2, 110), set(3, 125)];
    await tester.pumpAndSettle();
    final thirdCard = tester.getRect(
      find.ancestor(of: find.text('Set 4'), matching: find.byType(Card)),
    );
    expect(thirdCard.right, closeTo(viewport.right - 8, 1));
    expect(tester.takeException(), isNull);
  });
}
