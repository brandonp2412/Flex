import 'package:drift/drift.dart';
import 'package:flex/constants.dart';
import 'package:flex/database/database.dart';
import 'package:flex/database/exercise_analytics.dart';
import 'package:flex/graph/graphs_page.dart';
import 'package:flex/graph/exercise_graph_page.dart';
import 'package:flex/main.dart' as app;
import 'package:flex/main.dart';
import 'package:flex/plan/edit_plan_page.dart';
import 'package:flex/settings/settings_page.dart';
import 'package:flex/timer/timer_state.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';

import 'full_screenshot_suite.dart';
import 'support/screenshot_helpers.dart';
import 'support/mock_tab_controller.dart';
import 'support/fixtures.dart';
import 'support/graph_fixtures.dart';
import 'test_database.dart';

const _only = String.fromEnvironment('SCREENSHOT_ONLY');
const _screenshotLocales = String.fromEnvironment(
  'SCREENSHOT_LOCALES',
  defaultValue: 'en-US',
);

const _storeLocaleToAppLocale = <String, String>{
  'en-US': 'en',
  'de-DE': 'de',
  'es-ES': 'es',
  'fr-FR': 'fr',
  'hi-IN': 'hi',
  'it-IT': 'it',
  'ja-JP': 'ja',
  'ko-KR': 'ko',
  'nl-NL': 'nl',
  'pl-PL': 'pl',
  'pt-BR': 'pt-BR',
  'tr-TR': 'tr',
  'ru-RU': 'ru',
  'zh-CN': 'zh-CN',
};

bool _skip(String name) => _only.isNotEmpty && _only != name;

List<MapEntry<String, String>> _requestedScreenshotLocales() =>
    _screenshotLocales
        .split(',')
        .map((locale) => locale.trim())
        .where((locale) => locale.isNotEmpty)
        .map(
          (storeLocale) => MapEntry(
            storeLocale,
            _storeLocaleToAppLocale[storeLocale] ??
                (throw ArgumentError.value(
                  storeLocale,
                  'SCREENSHOT_LOCALES',
                  'Unsupported store locale',
                )),
          ),
        )
        .toList(growable: false);

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase database;
  final previousReporter = reportTestException;
  reportTestException = (details, description) {
    previousReporter(details, description);
    (binding.reportData ??= {})['exception-$description'] = details.exception
        .toString();
  };

  testWidgets('Prepare screenshot fixtures', (tester) async {
    await tester.runAsync(() async {
      print('Initializing screenshot fixtures');
      database = createIntegrationTestDatabase();
      app.db = database;
      app.androidChannel = const MethodChannel('com.presley.flexify/timer');
      IntegrationTestWidgetsFlutterBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(app.androidChannel, (message) => null);

      await app.db.delete(app.db.bodyWeights).go();
      await app.db.delete(app.db.exerciseSets).go();
      await app.db.delete(app.db.workouts).go();
      await app.db.delete(app.db.planExercises).go();
      await app.db.delete(app.db.plans).go();

      await seedGraphFixtures(app.db);
      await db.plans.insertAll(screenshotPlans);
      for (final entry in screenshotPlanExercises.entries) {
        for (final exercise in entry.value) {
          await insertPlanExerciseFixture(
            db,
            planId: entry.key,
            exercise: exercise,
          );
        }
      }
      print('Screenshot fixtures initialized');
    });
  });

  tearDownAll(() async {
    await database.close();
  });

  final fullGallery =
      const bool.fromEnvironment('SCREENSHOT_FULL') &&
      (!kIsWeb || Uri.base.queryParameters['gallery'] == 'full');
  if (fullGallery) {
    registerFullScreenshotSuite(binding);
    return;
  }

  for (final screenshotLocale in _requestedScreenshotLocales()) {
    final storeLocale = screenshotLocale.key;
    final appLocale = screenshotLocale.value;

    group('Generate $storeLocale default screenshots ', () {
      testWidgets(
        'PlanPage',
        (tester) async => generateScreenshot(
          binding: binding,
          tester: tester,
          screenshotName: '1_$storeLocale',
          tabBarState: 'PlansPage',
          localeIdentifier: appLocale,
        ),
        skip: _skip('PlanPage'),
      );

      testWidgets(
        'GraphPage',
        (tester) async => generateScreenshot(
          binding: binding,
          tester: tester,
          screenshotName: '2_$storeLocale',
          localeIdentifier: appLocale,
          navigateToPage: (context) async => navigateTo(
            context: context,
            page: GraphsPage(tabController: MockTabController()),
          ),
          tabBarState: 'GraphsPage',
        ),
        skip: _skip('GraphPage'),
      );

      testWidgets(
        'SettingsPage',
        (tester) async => generateScreenshot(
          binding: binding,
          tester: tester,
          screenshotName: '3_$storeLocale',
          localeIdentifier: appLocale,
          navigateToPage: (context) async =>
              navigateTo(context: context, page: const SettingsPage()),
          tabBarState: 'PlansPage',
        ),
        skip: _skip('SettingsPage'),
      );

      testWidgets('StartPlanPage', (tester) async {
        final workout = await db.workouts.insertReturning(
          WorkoutsCompanion.insert(
            planId: const Value(3),
            startedAt: DateTime.now(),
          ),
        );
        final today = DateTime.now().toLocal();
        final seededSetIds = <int>[];
        for (var index = 0; index < 3; index++) {
          final set = await insertGraphSet(
            db,
            'Barbell shoulder press',
            50 + (index * 2.5),
            reps: 8,
            date: today.subtract(Duration(minutes: index)),
            workoutId: workout.id,
          );
          seededSetIds.add(set.id);
        }
        for (var index = 0; index < 2; index++) {
          final set = await insertGraphSet(
            db,
            'Crunch',
            25,
            reps: 12,
            date: today.subtract(Duration(minutes: 10 + index)),
            workoutId: workout.id,
          );
          seededSetIds.add(set.id);
        }

        try {
          await generateScreenshot(
            binding: binding,
            tester: tester,
            screenshotName: '4_$storeLocale',
            localeIdentifier: appLocale,
            navigateToPage: (context) async {
              await tester.tap(find.text('Monday'));
              await tester.pumpAndSettle();
            },
            tabBarState: 'PlansPage',
          );
        } finally {
          await (db.exerciseSets.delete()
                ..where((set) => set.id.isIn(seededSetIds)))
              .go();
          await (db.workouts.delete()
                ..where((workout) => workout.planId.equals(3)))
              .go();
        }
      }, skip: _skip('StartPlanPage'));
    });

    group('Generate $storeLocale extra screenshots', () {
      testWidgets(
        'ViewGraphPage',
        (tester) async => generateScreenshot(
          binding: binding,
          tester: tester,
          screenshotName: '5_$storeLocale',
          localeIdentifier: appLocale,
          navigateToPage: (context) async {
            final data = await getStrengthData(
              target: 'kg',
              name: screenshotExercise,
              metric: StrengthMetric.bestWeight,
              period: Period.day,
              start: null,
              end: null,
              limit: 11,
            );
            if (!context.mounted) return;
            navigateTo(
              context: context,
              page: ExerciseGraphPage(
                tabCtrl: MockTabController(),
                initialName: 'Shoulder press',
                initialUnit: 'kg',
                initialData: data,
              ),
            );
          },
          tabBarState: 'GraphsPage',
        ),
        skip: _skip('ViewGraphPage'),
      );

      testWidgets(
        'GraphHistory',
        (tester) async => generateScreenshot(
          binding: binding,
          tester: tester,
          screenshotName: '6_$storeLocale',
          tabBarState: 'HistoryPage',
          localeIdentifier: appLocale,
        ),
        skip: _skip('GraphHistory'),
      );

      testWidgets('EditPlanPage', (tester) async {
        const planId = 99;
        final plan = PlansCompanion.insert(
          id: const Value(planId),
          days: 'Tuesday,Thursday,Saturday',
          title: const Value('Upper body strength'),
        );
        await db.into(db.plans).insert(plan);
        for (final exercise in const [
          'Barbell bench press',
          'Barbell bent-over row',
          'Dumbbell chest press',
          'Dumbbell lateral raise',
          'Barbell biceps curl',
          'Triceps dip',
        ]) {
          await insertPlanExerciseFixture(
            db,
            planId: planId,
            exercise: exercise,
          );
        }

        try {
          await generateScreenshot(
            binding: binding,
            tester: tester,
            screenshotName: '7_$storeLocale',
            localeIdentifier: appLocale,
            navigateToPage: (context) async {
              if (!context.mounted) return;
              navigateTo(
                context: context,
                page: EditPlanPage(plan: plan),
              );
            },
            tabBarState: 'PlansPage',
          );
        } finally {
          await (db.delete(
            db.planExercises,
          )..where((tbl) => tbl.planId.equals(planId))).go();
          await (db.delete(
            db.plans,
          )..where((tbl) => tbl.id.equals(planId))).go();
        }
      }, skip: _skip('EditPlanPage'));

      testWidgets(
        'TimerPage',
        (tester) async => generateScreenshot(
          binding: binding,
          tester: tester,
          screenshotName: '8_$storeLocale',
          localeIdentifier: appLocale,
          skipSettle: true,
          navigateToPage: (context) async {
            context.read<TimerState>().setTimer(60, 7);
            await tester.pump();
          },
          tabBarState: 'TimerPage',
        ),
        skip: _skip('TimerPage'),
      );
    });
  }
}
