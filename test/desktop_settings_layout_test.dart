import 'package:drift/drift.dart' hide isNull;
import 'package:flex/responsive.dart';
import 'package:flex/database/database.dart';
import 'package:flex/settings/category_management_page.dart';
import 'package:flex/settings/appearance_settings.dart';
import 'package:flex/settings/data_settings.dart';
import 'package:flex/settings/format_settings.dart';
import 'package:flex/settings/plan_settings.dart';
import 'package:flex/settings/workout_settings.dart';
import 'package:flex/settings/tab_settings.dart';
import 'package:flex/settings/timer_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_app.dart';

void main() {
  for (final page in <Widget>[
    const AppearanceSettings(),
    const WorkoutSettings(),
    const PlanSettings(),
    const FormatSettings(),
    const TimerSettings(),
    const TabSettings(),
    const DataSettings(),
    const CategoryManagementPage(),
  ]) {
    for (final width in [390.0, 850.0, 1200.0]) {
      testWidgets('${page.runtimeType} uses flat rows at width $width', (
        tester,
      ) async {
        final harness = await FlexTestHarness.create();
        if (page is TimerSettings) {
          await harness.database.exercises.insertOne(
            ExercisesCompanion.insert(
              name: 'Custom timer exercise',
              kind: 'strength',
              displayUnit: 'kg',
              defaultRestDurationMs: const Value(90000),
            ),
          );
        }
        await harness.pump(tester, page, surfaceSize: Size(width, 900));
        await tester.pumpAndSettle();

        expect(find.byType(ResponsiveSettingsList), findsOneWidget);
        expect(find.byType(Card), findsNothing);
        final content = find
            .descendant(
              of: find.byType(ResponsiveSettingsList),
              matching: find.byType(ListView),
            )
            .first;
        expect(tester.getSize(content).width, lessThanOrEqualTo(760));
        expect(tester.takeException(), isNull);
        if (page is TimerSettings) {
          await tester.scrollUntilVisible(
            find.text('Custom timer exercise'),
            300,
            scrollable: find
                .descendant(of: content, matching: find.byType(Scrollable))
                .first,
          );
          await tester.pumpAndSettle();
          expect(find.byType(Card), findsNothing);
          expect(tester.takeException(), isNull);
        }
      });
    }
  }

  testWidgets('Reordering tabs still updates persisted order', (
    WidgetTester tester,
  ) async {
    final harness = await FlexTestHarness.create();
    await harness.pump(
      tester,
      const TabSettings(),
      surfaceSize: const Size(850, 900),
    );
    await tester.pumpAndSettle();

    final historyHandle = find.descendant(
      of: find.byKey(const Key('HistoryPage')),
      matching: find.byIcon(Icons.drag_handle),
    );
    await tester.drag(historyHandle, const Offset(0, 150));
    await tester.pumpAndSettle();

    final settings = await harness.database.settings.select().getSingle();
    expect(settings.tabs.split(','), isNot(startsWith('HistoryPage')));
  });

  testWidgets('Data management presents actions as list rows', (
    WidgetTester tester,
  ) async {
    final harness = await FlexTestHarness.create();
    await harness.pump(
      tester,
      const DataSettings(),
      surfaceSize: const Size(850, 900),
    );
    await tester.pumpAndSettle();

    expect(find.widgetWithText(ListTile, 'Export data'), findsOneWidget);
    expect(find.widgetWithText(ListTile, 'Import data'), findsOneWidget);
    expect(find.widgetWithText(ListTile, 'Delete records'), findsOneWidget);
  });
}
