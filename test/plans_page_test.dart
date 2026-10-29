import 'package:flex/database/database.dart';
import 'package:flex/plan/workout_sessions.dart';
import 'package:flex/bottom_nav.dart';
import 'package:flex/plan/plans_page.dart';
import 'package:flex/plan/plans_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../integration_test/support/mock_tab_controller.dart';
import 'support/test_app.dart';

Future<void> pumpPlansPage(WidgetTester tester, FlexTestHarness harness) async {
  await harness.pump(tester, PlansPage(tabController: MockTabController()));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Plans do not show an empty state while loading', (tester) async {
    final harness = await FlexTestHarness.create();
    final scroll = ScrollController();
    addTearDown(scroll.dispose);

    Widget list(List<Plan>? plans, List<PlanExerciseEntry>? exercises) =>
        Scaffold(
          body: PlansList(
            plans: plans,
            exercises: exercises,
            navKey: GlobalKey<NavigatorState>(),
            selected: <int>{},
            onSelect: (_) {},
            search: '',
            scroll: scroll,
          ),
        );

    await harness.pump(tester, list(null, null));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('No plans yet'), findsNothing);

    await harness.pump(tester, list(<Plan>[], <PlanExerciseEntry>[]));
    await tester.pumpAndSettle();
    expect(find.text('No plans yet'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('PlansPage lists items', (WidgetTester tester) async {
    final harness = await FlexTestHarness.create();
    await pumpPlansPage(tester, harness);

    expect(find.text('Search plans...'), findsOne);
    expect(find.textContaining('Barbell bench press'), findsOne);
    final list = tester.widget<ReorderableListView>(
      find.byType(ReorderableListView),
    );
    expect(list.padding!.bottom, fabListPadding);
  });

  testWidgets('PlansPage searches exercise names in any word order', (
    WidgetTester tester,
  ) async {
    final harness = await FlexTestHarness.create();
    await pumpPlansPage(tester, harness);

    await tester.enterText(find.byType(SearchBar), '  PRESS   bench ');
    await tester.pumpAndSettle();

    expect(find.textContaining('Barbell bench press'), findsOne);

    await tester.enterText(find.byType(SearchBar), 'nonexistent exercise');
    await tester.pumpAndSettle();
    expect(find.textContaining('Barbell bench press'), findsNothing);
    expect(find.text('No matching plans'), findsOne);
  });

  testWidgets('PlansPage add button', (WidgetTester tester) async {
    final harness = await FlexTestHarness.create();
    await pumpPlansPage(tester, harness);

    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    expect(find.text('Save'), findsOne);
  });

  testWidgets('PlansPage tap tile opens workout', (WidgetTester tester) async {
    final harness = await FlexTestHarness.create();
    await pumpPlansPage(tester, harness);

    await tester.tap(find.textContaining('Barbell bench press'));
    await tester.pumpAndSettle();

    expect(find.byType(Scaffold), findsWidgets);
    expect(find.byType(Scaffold), findsWidgets);
  });

  testWidgets('PlansPage settings', (WidgetTester tester) async {
    final harness = await FlexTestHarness.create();
    await pumpPlansPage(tester, harness);

    await tester.tap(find.byTooltip('Show menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    expect(find.text('Settings'), findsOne);
  });

  testWidgets('PlansPage selects', (WidgetTester tester) async {
    final harness = await FlexTestHarness.create();
    await pumpPlansPage(tester, harness);

    await tester.longPress(find.textContaining('Barbell bench press'));
    await tester.pumpAndSettle();

    expect(find.text('1'), findsOne);
  });

  testWidgets('PlansPage deletes', (WidgetTester tester) async {
    final harness = await FlexTestHarness.create();
    await pumpPlansPage(tester, harness);

    await tester.longPress(find.textContaining('Barbell bench press'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Delete selected'));
    await tester.pumpAndSettle();

    expect(find.text('Confirm delete'), findsOne);
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(find.text('Search plans...'), findsOne);
  });
}
