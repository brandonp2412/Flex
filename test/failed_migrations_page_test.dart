import 'package:flex/database/failed_migrations_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('migration failure follows system brightness: $brightness', (
      tester,
    ) async {
      tester.binding.platformDispatcher.platformBrightnessTestValue =
          brightness;
      addTearDown(
        tester.binding.platformDispatcher.clearPlatformBrightnessTestValue,
      );
      await tester.pumpWidget(
        const FailedMigrationsPage(error: 'Example error'),
      );
      await tester.pumpAndSettle();
      expect(
        Theme.of(tester.element(find.byType(Scaffold))).brightness,
        brightness,
      );
    });
  }
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
      const FailedMigrationsPage(error: 'Example database error'),
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
