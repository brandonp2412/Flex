import 'package:drift/drift.dart' hide Column, isNull;
import 'package:flex/bottom_nav.dart';
import 'package:flex/database/database.dart';
import 'package:flex/home_page.dart';
import 'package:flex/settings/settings_page.dart';
import 'package:flex/timer/timer_progress_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_app.dart';

void main() {
  testWidgets(
    'Graphs layout stays fixed while keyboard closes with rest timer',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(360, 780);
      tester.view.viewPadding = const FakeViewPadding(bottom: 24);
      tester.view.padding = const FakeViewPadding(bottom: 24);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetViewPadding);
      addTearDown(tester.view.resetPadding);
      addTearDown(tester.view.resetViewInsets);

      final harness = await FlexTestHarness.create();
      await harness.database.settings.update().write(
        const SettingsCompanion(tabs: Value('GraphsPage')),
      );
      await harness.pump(
        tester,
        const HomePage(),
        surfaceSize: const Size(360, 780),
      );
      await tester.pumpAndSettle();

      harness.timerState.setTimer(180, 0);
      await tester.pump();
      final dock = find.byType(BottomNav);
      final progress = find.byType(TimerProgressIndicator);
      final dockBottom = tester.getBottomLeft(dock).dy;
      final progressTop = tester.getTopLeft(progress).dy;

      tester.view.padding = FakeViewPadding.zero;
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pump();
      expect(tester.getBottomLeft(dock).dy, dockBottom);
      expect(tester.getTopLeft(progress).dy, progressTop);

      final navigator = tester.state<NavigatorState>(
        find
            .descendant(
              of: find.byType(HomePage),
              matching: find.byType(Navigator),
            )
            .first,
      );
      navigator.push(
        MaterialPageRoute<void>(builder: (_) => const SettingsPage()),
      );
      await tester.pump(const Duration(milliseconds: 350));

      final search = find.descendant(
        of: find.byType(SettingsPage),
        matching: find.byType(EditableText),
      );
      await tester.enterText(search, 'pos');
      await tester.pump();
      expect(find.text('pos'), findsOneWidget);

      await tester.tap(
        find.descendant(
          of: find.byType(SettingsPage),
          matching: find.byType(BackButton),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      tester.view.viewInsets = FakeViewPadding.zero;
      tester.view.padding = const FakeViewPadding(bottom: 24);
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.byType(SettingsPage), findsNothing);
      expect(tester.getBottomLeft(dock).dy, dockBottom);
      expect(tester.getTopLeft(progress).dy, progressTop);
      expect(tester.takeException(), isNull);
    },
  );
}
