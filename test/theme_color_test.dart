import 'package:drift/drift.dart' hide isNull;
import 'package:flex/database/database.dart';
import 'package:flex/main.dart';
import 'package:flex/settings/appearance_settings.dart';
import 'package:flex/timer/timer_state.dart';
import 'package:provider/provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_app.dart';

void main() {
  testWidgets('Root theme responds to persisted seed changes', (tester) async {
    final harness = await FlexTestHarness.create();
    final initialSettings = await (harness.database.settings.select()..limit(1))
        .getSingle();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          StreamProvider<Setting>(
            initialData: initialSettings,
            create: (_) => harness.database.watchSettings(),
          ),
          ChangeNotifierProvider<TimerState>.value(value: harness.timerState),
        ],
        child: const App(),
      ),
    );
    await tester.pumpAndSettle();

    MaterialApp themedApp() =>
        tester.widgetList<MaterialApp>(find.byType(MaterialApp)).last;

    expect(
      themedApp().theme!.colorScheme.primary,
      ColorScheme.fromSeed(seedColor: Colors.deepPurple).primary,
    );

    await harness.database.settings.update().write(
      const SettingsCompanion(seedColor: Value(0xFF12AB34)),
    );
    await tester.pumpAndSettle();

    expect(
      themedApp().theme!.colorScheme.primary,
      ColorScheme.fromSeed(seedColor: const Color(0xFF12AB34)).primary,
    );
    expect(
      themedApp().darkTheme!.colorScheme.primary,
      ColorScheme.fromSeed(
        seedColor: const Color(0xFF12AB34),
        brightness: Brightness.dark,
      ).primary,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Custom picker fits compact high text-scale screens', (
    tester,
  ) async {
    final harness = await FlexTestHarness.create();
    await harness.pump(
      tester,
      const AppearanceSettings(),
      surfaceSize: const Size(320, 640),
      textScaler: const TextScaler.linear(1.5),
    );
    await tester.pumpAndSettle();
    final custom = find.byKey(const Key('theme-color-custom'));
    await tester.ensureVisible(custom);
    await tester.pumpAndSettle();
    await tester.tap(custom);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('theme-hex-field')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
