import 'package:drift/drift.dart';
import 'package:flex/database/database.dart';
import 'package:flex/graph/graphs_page.dart';
import 'package:flex/main.dart' as app;
import 'package:flex/main.dart';
import 'package:flex/plan/plans_page.dart';
import 'package:flex/sets/history_page_widget.dart';
import 'package:flex/timer/timer_page.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

Future<void> appWrapper(
  WidgetTester tester, {
  required String localeIdentifier,
}) async {
  if (kIsWeb &&
      const bool.fromEnvironment('SCREENSHOT_WEB_ANDROID_INSETS') &&
      tester.view.devicePixelRatio > 1) {
    final scale = tester.view.devicePixelRatio;
    final phone = tester.view.physicalSize.width / scale < 600;
    final padding = FakeViewPadding(
      top: 24 * scale,
      bottom: (phone ? 24 : 32) * scale,
    );
    tester.view.padding = padding;
    tester.view.viewPadding = padding;
  }
  final galleryTheme = kIsWeb && Uri.base.queryParameters['gallery'] == 'full'
      ? Uri.base.queryParameters['theme']
      : null;
  final themeMode = switch (galleryTheme) {
    'light' => ThemeMode.light.toString(),
    'amoled' => 'ThemeMode.amoled',
    _ => ThemeMode.dark.toString(),
  };
  await app.db.settings.update().write(
    SettingsCompanion(
      themeMode: Value(themeMode),
      explainedPermissions: const Value(true),
      restTimers: const Value(true),
      systemColors: const Value(false),
      curveLines: const Value(true),
      showImages: const Value(false),
      showGlobalProgress: const Value(false),
      localeOverride: Value(localeIdentifier),
    ),
  );
  final settings = await (db.settings.select()..limit(1)).getSingle();

  await tester.pumpWidget(app.appProviders(settings));
}

BuildContext getBuildContext(WidgetTester tester, String tabBarState) {
  switch (tabBarState) {
    case 'PlansPage':
      return (tester.state(find.byType(PlansPage)) as PlansPageState)
          .navKey
          .currentContext!;
    case 'GraphsPage':
      return (tester.state(find.byType(GraphsPage)) as GraphsPageState)
          .navKey
          .currentContext!;
    case 'TimerPage':
      return (tester.state(find.byType(TimerPage)) as TimerPageState).context;
    case 'HistoryPage':
      return tester.element(find.byType(HistoryPageWidget));
  }

  return tester.element(find.byType(MaterialApp));
}

void navigateTo({required BuildContext context, required Widget page}) {
  Navigator.of(context).push(MaterialPageRoute(builder: (context) => page));
}

Future<void> generateScreenshot({
  required IntegrationTestWidgetsFlutterBinding binding,
  required WidgetTester tester,
  required String screenshotName,
  required String tabBarState,
  required String localeIdentifier,
  Future<void> Function(BuildContext context)? navigateToPage,
  bool skipSettle = false,
}) async {
  await appWrapper(tester, localeIdentifier: localeIdentifier);
  await tester.pumpAndSettle();

  await tester.tap(find.byKey(Key(tabBarState)));
  await tester.pumpAndSettle();

  if (navigateToPage != null) {
    final navState = getBuildContext(tester, tabBarState);
    if (navState.mounted) await navigateToPage(navState);
  }

  skipSettle ? await tester.pump() : await tester.pumpAndSettle();
  await binding.convertFlutterSurfaceToImage();
  skipSettle ? await tester.pump() : await tester.pumpAndSettle();
  await binding.takeScreenshot(screenshotName);
}
