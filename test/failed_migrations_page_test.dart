import 'package:flex/app.dart';
import 'package:flex/settings/app_appearance.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Recovery uses the saved theme and accent', (tester) async {
    final dispatcher = tester.binding.platformDispatcher;
    addTearDown(dispatcher.clearPlatformBrightnessTestValue);
    const seed = Colors.teal;

    for (final (mode, deviceBrightness, expectedBrightness) in [
      ('ThemeMode.light', Brightness.dark, Brightness.light),
      ('ThemeMode.dark', Brightness.light, Brightness.dark),
      ('ThemeMode.amoled', Brightness.light, Brightness.dark),
      ('ThemeMode.system', Brightness.light, Brightness.light),
      ('ThemeMode.system', Brightness.dark, Brightness.dark),
    ]) {
      dispatcher.platformBrightnessTestValue = deviceBrightness;
      await tester.pumpWidget(
        App.recovery(
          error: 'Database unavailable',
          appearance: (
            themeMode: mode,
            seedColor: seed.toARGB32(),
            systemColors: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(Scaffold));
      final theme = Theme.of(context);
      final expected = ColorScheme.fromSeed(
        seedColor: seed,
        brightness: expectedBrightness,
      );
      expect(theme.brightness, expectedBrightness);
      expect(theme.colorScheme.primary, expected.primary);
      expect(
        theme.scaffoldBackgroundColor,
        mode == 'ThemeMode.amoled' ? Colors.black : expected.surface,
      );
      expect(find.text('Database unavailable'), findsOneWidget);
    }
  });
  testWidgets('migration failure opens the releases page on a small screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const channel = MethodChannel('plugins.flutter.io/url_launcher');
    final messenger = tester.binding.defaultBinaryMessenger;
    MethodCall? launched;
    messenger.setMockMethodCallHandler(channel, (call) async {
      launched = call;
      return true;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

    await tester.pumpWidget(
      const App.recovery(
        error: 'Example database error',
        appearance: defaultAppAppearance,
      ),
    );
    await tester.pumpAndSettle();

    final positions = [
      for (final label in [
        'Export data',
        'Delete records',
        'View releases',
        'Email me',
      ])
        tester.getTopLeft(find.text(label)).dy,
    ];
    expect(positions, orderedEquals([...positions]..sort()));

    final releases = find.widgetWithText(ListTile, 'View releases');
    await tester.ensureVisible(releases);
    await tester.tap(releases);
    await tester.pumpAndSettle();

    expect(launched?.method, 'launch');
    expect(
      launched?.arguments['url'],
      'https://github.com/brandonp2412/Flex/releases',
    );
    expect(launched?.arguments['useWebView'], isFalse);
    expect(tester.takeException(), isNull);
  });
}
