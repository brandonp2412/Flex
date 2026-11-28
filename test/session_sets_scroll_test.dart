import 'package:flex/database/exercise_set_view.dart';
import 'package:flex/plan/session_sets.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_app.dart';

void main() {
  for (final current in [false, true]) {
    testWidgets(
      'mouse wheel scrolls ${current ? 'current' : 'previous'} sets horizontally',
      (tester) async {
        final harness = await FlexTestHarness.create();
        final sets = List.generate(
          12,
          (id) => ExerciseSetView(
            bodyWeight: 0,
            cardio: false,
            created: DateTime(2026, 11, 4),
            distance: 0,
            duration: 0,
            id: id,
            name: 'Bench press',
            reps: 8,
            unit: 'kg',
            weight: 100,
          ),
        );
        final parent = ScrollController();
        addTearDown(parent.dispose);
        await harness.pump(
          tester,
          Scaffold(
            body: SingleChildScrollView(
              controller: parent,
              child: Column(
                children: [
                  SizedBox(
                    width: 380,
                    height: 80,
                    child: SessionSets(
                      exerciseId: 1,
                      workoutId: 1,
                      sets: current ? sets : const [],
                      previous: current ? null : sets,
                    ),
                  ),
                  const SizedBox(height: 1600),
                ],
              ),
            ),
          ),
          surfaceSize: const Size(1000, 800),
        );
        await tester.pumpAndSettle();
        final strip = find.byKey(
          Key(current ? 'session-set-scroll' : 'previous-set-scroll'),
        );
        final position = tester
            .state<ScrollableState>(
              find.descendant(of: strip, matching: find.byType(Scrollable)),
            )
            .position;
        position.jumpTo(0);
        await tester.pumpAndSettle();
        Future<void> wheel(double dy, {double dx = 0}) async {
          await tester.sendEventToBinding(
            PointerScrollEvent(
              kind: PointerDeviceKind.mouse,
              position: tester.getCenter(strip),
              scrollDelta: Offset(dx, dy),
            ),
          );
          await tester.pumpAndSettle();
        }

        await wheel(240);
        expect(position.pixels, 240);
        expect(parent.offset, 0);
        await wheel(-120);
        expect(position.pixels, 120);
        await wheel(0, dx: 60);
        expect(position.pixels, 180);
        position.jumpTo(position.maxScrollExtent);
        await tester.pumpAndSettle();
        await wheel(120);
        expect(parent.offset, 120);
      },
    );
  }

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
    final previous = List.filled(
      5,
      set(2, 95).copyWith(created: day.subtract(const Duration(days: 1))),
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
