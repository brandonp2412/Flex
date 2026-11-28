import 'package:flutter/gestures.dart';
import 'package:flex/responsive.dart';
import 'package:flex/app_search.dart';
import 'package:permission_handler_platform_interface/permission_handler_platform_interface.dart';
import 'package:flex/database/body_weight_repository.dart';
import 'package:flex/graph/merge_graphs_page.dart';
import 'package:flex/l10n/l10n.dart';
import 'package:flex/about_page.dart';
import 'package:flex/permissions_page.dart';
import 'package:flex/weight_page.dart';
import 'package:flex/database/exercise_set_repository.dart';
import 'package:flex/database/failed_migrations_page.dart';
import 'package:flex/graph/exercise_editor_page.dart';
import 'package:flex/graph/global_progress_page.dart';
import 'package:flex/graph/graph_history_page.dart';
import 'package:flex/graph/graph_notes_page.dart';
import 'package:flex/plan/plan_exercise_settings_dialog.dart';
import 'package:flex/sets/edit_set_page.dart';
import 'package:flex/sets/edit_sets_page.dart';
import 'package:flex/settings/category_management_page.dart';
import 'package:flex/settings/settings_category_page.dart';
import 'package:flex/settings/tab_settings.dart';
import 'package:flex/settings/whats_new.dart';
import 'package:flex/constants.dart';
import 'package:flex/database/database.dart';
import 'package:flex/database/exercise_analytics.dart';
import 'package:flex/graph/exercise_graph_page.dart';
import 'package:flex/main.dart';
import 'package:flex/plan/edit_plan_page.dart';
import 'package:flex/settings/settings_page.dart';
import 'package:flex/timer/timer_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';

import 'support/graph_fixtures.dart';
import 'support/mock_tab_controller.dart';
import 'support/screenshot_helpers.dart';

class _ScreenshotPermissions extends PermissionHandlerPlatform {
  @override
  Future<PermissionStatus> checkPermissionStatus(Permission permission) async =>
      PermissionStatus.denied;
}

void registerFullScreenshotSuite(IntegrationTestWidgetsFlutterBinding binding) {
  group('Full screenshot gallery', () {
    void scene(
      String name,
      String tab,
      Future<void> Function(WidgetTester, BuildContext) open,
    ) {
      testWidgets(name, (tester) async {
        await generateScreenshot(
          binding: binding,
          tester: tester,
          screenshotName: 'full-$name',
          tabBarState: tab,
          localeIdentifier: 'en',
          navigateToPage: (context) => open(tester, context),
        );
      });
    }

    Future<void> search(WidgetTester tester, String hint, String query) async {
      final finder = find.byWidgetPredicate(
        (widget) => widget is SearchBar && widget.hintText == hint,
      );
      final bar = tester.widget<SearchBar>(finder.last);
      bar.controller!.text = query;
      bar.onChanged!(query);
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
    }

    void route(String name, String tab, Future<Widget> Function() page) =>
        scene(name, tab, (tester, context) async {
          final widget = await page();
          if (context.mounted) navigateTo(context: context, page: widget);
        });

    for (final category in SettingsCategory.values) {
      route(
        'settings-${category.name}',
        'PlansPage',
        () async => category == SettingsCategory.tabs
            ? const TabSettings()
            : SettingsCategoryPage(category),
      );
    }

    route(
      'categories',
      'PlansPage',
      () async => const CategoryManagementPage(),
    );
    scene('category-create', 'PlansPage', (tester, context) async {
      navigateTo(context: context, page: const CategoryManagementPage());
      await tester.pumpAndSettle();
      await tester.tap(find.byType(FloatingActionButton).last);
    });
    scene('about', 'PlansPage', (tester, context) async {
      Navigator.of(
        context,
        rootNavigator: true,
      ).push(MaterialPageRoute(builder: (_) => const AboutPage()));
    });
    route('whats-new', 'PlansPage', () async => const WhatsNew());
    scene('permissions', 'PlansPage', (tester, context) async {
      PermissionHandlerPlatform.instance = _ScreenshotPermissions();
      Navigator.of(
        context,
        rootNavigator: true,
      ).push(MaterialPageRoute(builder: (_) => const PermissionsPage()));
    });
    testWidgets('database-error', (tester) async {
      await appWrapper(tester, localeIdentifier: 'en');
      await tester.pumpAndSettle();
      await tester.pumpWidget(
        const FailedMigrationsPage(
          error: 'Example: database migration failed.',
        ),
      );
      await tester.pumpAndSettle();
      await binding.convertFlutterSurfaceToImage();
      await binding.takeScreenshot('full-database-error');
    });
    route(
      'plan-create',
      'PlansPage',
      () async => EditPlanPage(plan: PlansCompanion.insert(days: '')),
    );
    scene('plan-exercise-settings', 'PlansPage', (tester, context) async {
      showDialog<void>(
        context: context,
        builder: (_) => PlanExerciseSettingsDialog(
          name: 'Barbell bench press',
          initial: const PlanExercisesCompanion(),
          onChanged: (_) {},
        ),
      );
    });
    route(
      'exercise-create',
      'GraphsPage',
      () async => const ExerciseEditorPage.add(),
    );
    route(
      'exercise-edit',
      'GraphsPage',
      () async => const ExerciseEditorPage.edit(name: screenshotExercise),
    );
    route(
      'global-progress',
      'GraphsPage',
      () async => GlobalProgressPage(tabController: MockTabController()),
    );
    route(
      'exercise-history',
      'GraphsPage',
      () async => GraphHistoryPage(
        name: screenshotExercise,
        initialSets: await getGraphHistory(
          screenshotExercise,
          bodyWeight: false,
        ),
        tabController: MockTabController(),
      ),
    );
    scene('exercise-notes', 'GraphsPage', (tester, context) async {
      final notes = TextEditingController(
        text:
            'Keep shoulders stable. Increase weight when all sets reach 12 reps.',
      );
      final navigator = Navigator.of(
        context,
        rootNavigator: !isDesktopLayout(context),
      );
      navigator.push(
        MaterialPageRoute(
          builder: (_) => GraphNotesPage(controller: notes, onChanged: () {}),
        ),
      );
    });
    route(
      'set-edit',
      'HistoryPage',
      () async => EditSetPage(
        exerciseSet: (await ExerciseSetQuery(
          db,
          exerciseName: screenshotExercise,
        ).get()).first,
      ),
    );
    route(
      'sets-bulk-edit',
      'HistoryPage',
      () async => EditSetsPage(
        ids: (await ExerciseSetQuery(
          db,
          exerciseName: screenshotExercise,
          limit: 3,
        ).get()).map((set) => set.id).toList(),
      ),
    );
    route('body-weight', 'GraphsPage', () async => const WeightPage());
    scene('settings-language', 'PlansPage', (tester, context) async {
      navigateTo(
        context: context,
        page: const SettingsCategoryPage(SettingsCategory.appearance),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('language-setting-dropdown')));
    });

    Future<ExerciseGraphPage> strengthGraph() async => ExerciseGraphPage(
      initialName: screenshotExercise,
      initialUnit: 'kg',
      initialData: await getStrengthData(
        target: 'kg',
        name: screenshotExercise,
        metric: StrengthMetric.bestWeight,
        period: Period.day,
        start: null,
        end: null,
        limit: 11,
      ),
      tabCtrl: MockTabController(),
    );

    scene('graph-options', 'GraphsPage', (tester, context) async {
      final page = await strengthGraph();
      if (!context.mounted) return;
      navigateTo(context: context, page: page);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('graph-options-button')));
    });
    route(
      'graph-merge',
      'GraphsPage',
      () async => MergeGraphsPage(
        summaries: (await watchGraphs().first)
            .where(
              (summary) =>
                  summary.name == screenshotExercise ||
                  summary.name == 'Barbell shoulder press',
            )
            .toList(),
      ),
    );
    route(
      'graph-empty-exercise',
      'GraphsPage',
      () async => ExerciseGraphPage(
        initialName: 'Squat',
        initialUnit: 'kg',
        initialData: [],
        tabCtrl: MockTabController(),
      ),
    );
    scene('history-filters', 'HistoryPage', (tester, context) async {
      await tester.tap(find.byIcon(Icons.filter_list).first);
    });
    scene('history-filter-reps', 'HistoryPage', (tester, context) async {
      await tester.tap(find.byIcon(Icons.filter_list).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text(context.l10n.repsLabel).last);
    });
    scene('history-date-picker', 'HistoryPage', (tester, context) async {
      await tester.tap(find.byIcon(Icons.filter_list).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text(context.l10n.startDate).last);
    });
    route(
      'set-create',
      'HistoryPage',
      () async => EditSetPage(
        exerciseSet: ExerciseSetView(
          id: 0,
          name: 'Barbell bench press',
          reps: 8,
          weight: 80,
          unit: 'kg',
          created: DateTime.now(),
          cardio: false,
        ),
      ),
    );
    scene('set-delete-confirmation', 'HistoryPage', (tester, context) async {
      final set = (await ExerciseSetQuery(
        db,
        exerciseName: screenshotExercise,
      ).get()).first;
      if (!context.mounted) return;
      navigateTo(
        context: context,
        page: EditSetPage(exerciseSet: set),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.delete).last);
    });
    scene('settings-search', 'PlansPage', (tester, context) async {
      navigateTo(context: context, page: const SettingsPage());
      await tester.pumpAndSettle();
      final bar = tester.widget<SearchBar>(find.byType(SearchBar).last);
      bar.controller!.text = 'graph';
      bar.onChanged!('graph');
      await tester.pumpAndSettle();
    });
    for (final (name, category) in [
      ('settings-appearance-more', SettingsCategory.appearance),
      ('settings-workouts-more', SettingsCategory.workouts),
    ]) {
      scene(name, 'PlansPage', (tester, context) async {
        navigateTo(context: context, page: SettingsCategoryPage(category));
        await tester.pumpAndSettle();
        final list = find
            .descendant(
              of: find.byType(SettingsCategoryPage),
              matching: find.byType(Scrollable),
            )
            .first;
        final position = tester.state<ScrollableState>(list).position;
        if (category == SettingsCategory.workouts) {
          final expansion = find.byType(ExpansionTile).last;
          position.jumpTo(position.maxScrollExtent);
          await tester.pumpAndSettle();
          await tester.ensureVisible(expansion);
          await tester.tap(
            find.descendant(
              of: expansion,
              matching: find.text(context.l10n.navGraphs),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.text(context.l10n.showGraphXAxisToggle), findsOneWidget);
        }
        position.jumpTo(position.maxScrollExtent);
        await tester.pumpAndSettle();
      });
    }
    scene('settings-delete-confirmation', 'PlansPage', (tester, context) async {
      navigateTo(
        context: context,
        page: const SettingsCategoryPage(SettingsCategory.data),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(context.l10n.deleteRecords).last);
      await tester.pumpAndSettle();
      await tester.tap(
        find
            .descendant(
              of: find.byType(BottomSheet),
              matching: find.text(context.l10n.navGraphs),
            )
            .last,
      );
    });
    scene('plan-selection', 'PlansPage', (tester, context) async {
      final target = find.text('Monday').first;
      if (isDesktopLayout(context)) {
        await tester.tap(target, buttons: kSecondaryMouseButton);
      } else {
        await tester.longPress(target);
      }
      await tester.pumpAndSettle();
      expect(
        tester.widget<AppSearch>(find.byType(AppSearch).first).controller,
        isNotEmpty,
      );
    });
    scene('plan-search-empty', 'PlansPage', (tester, context) async {
      await search(tester, context.l10n.searchPlans, 'nonexistent workout');
      expect(find.text(context.l10n.noMatchingPlans), findsOneWidget);
    });
    scene('graph-search-empty', 'GraphsPage', (tester, context) async {
      await search(tester, context.l10n.searchGraphs, 'nonexistent exercise');
      expect(find.text(context.l10n.noGraphsFound), findsOneWidget);
    });
    scene('history-search-empty', 'HistoryPage', (tester, context) async {
      await search(tester, context.l10n.searchHistory, 'nonexistent exercise');
      expect(find.text(context.l10n.noEntriesYet), findsOneWidget);
    });

    testWidgets('Seed cardio and body-weight gallery fixtures', (tester) async {
      for (var index = 0; index < 8; index++) {
        final date = graphFixtureNow.subtract(Duration(days: index * 4));
        await insertGraphSet(
          db,
          'Stationary bike',
          0,
          reps: 0,
          date: date,
          cardio: true,
          unit: 'km',
          duration: 30 + index * 0.5,
          distance: 12 - index * 0.3,
          category: 'Cardio',
        );
        await recordBodyWeight(db, timestamp: date, weightKg: 79 + index * 0.4);
      }
    });
    route(
      'cardio-set-edit',
      'HistoryPage',
      () async => EditSetPage(
        exerciseSet: (await ExerciseSetQuery(
          db,
          exerciseName: 'Stationary bike',
        ).get()).first,
      ),
    );
    route(
      'cardio-exercise-edit',
      'GraphsPage',
      () async => const ExerciseEditorPage.edit(name: 'Stationary bike'),
    );
    route('cardio-graph', 'GraphsPage', () async {
      final summary = (await watchGraphs().first).firstWhere(
        (summary) => summary.name == 'Stationary bike',
      );
      return ExerciseGraphPage(
        initialName: summary.name,
        initialUnit: summary.unit,
        initialData: await getInitialGraphData(summary),
        tabCtrl: MockTabController(),
        cardio: true,
      );
    });
    route(
      'body-weight-graph',
      'GraphsPage',
      () async => ExerciseGraphPage(
        initialName: 'Weight',
        initialUnit: 'kg',
        initialData: await getBodyWeightData(
          target: 'kg',
          period: Period.day,
          start: null,
          end: null,
          limit: 20,
        ),
        tabCtrl: MockTabController(),
        bodyWeight: true,
      ),
    );
    route(
      'body-weight-history',
      'GraphsPage',
      () async => GraphHistoryPage(
        name: 'Weight',
        initialSets: await getBodyWeightGraphHistory(),
        tabController: MockTabController(),
        bodyWeight: true,
      ),
    );
    scene('timer-idle', 'TimerPage', (tester, context) async {
      await context.read<TimerState>().stopTimer();
    });
  });
}
