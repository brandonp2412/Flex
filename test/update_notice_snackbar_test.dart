import 'package:flex/l10n/generated/app_localizations.dart';
import 'package:flex/update_notice_snackbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final width in [1280.0, 375.0]) {
    testWidgets('new-version toast fits a $width-wide window', (tester) async {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var openedChanges = false;

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                  newVersionSnackBar(
                    context,
                    '2.2.37',
                    () => openedChanges = true,
                  ),
                ),
                child: const Text('Show'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Show'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      final rect = tester.getRect(
        find
            .descendant(
              of: find.byType(SnackBar),
              matching: find.byType(Material),
            )
            .first,
      );
      if (width >= 900) {
        expect(rect.width, 360);
        expect(rect.center.dx, closeTo(width / 2, 1));
      } else {
        expect(rect.width, greaterThan(300));
        expect(rect.width, lessThan(width));
      }
      expect(find.text('New version 2.2.37'), findsOneWidget);
      await tester.tap(find.text('Changes'));
      expect(openedChanges, isTrue);
    });
  }
}
