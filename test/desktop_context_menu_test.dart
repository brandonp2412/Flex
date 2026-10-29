import 'package:flex/responsive.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'Right-click menu is anchored to the pointer inside a navigator',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1200, 800);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Row(
              children: [
                const SizedBox(width: 224),
                Expanded(
                  child: Navigator(
                    onGenerateRoute: (_) => MaterialPageRoute<void>(
                      builder: (_) => Scaffold(
                        body: Center(
                          child: Builder(
                            builder: (context) => GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onSecondaryTapDown: (details) {
                                showDesktopContextMenu<void>(
                                  context,
                                  details.globalPosition,
                                  const [
                                    PopupMenuItem<void>(
                                      child: Text('Right-click action'),
                                    ),
                                  ],
                                );
                              },
                              child: const SizedBox(
                                key: Key('context-target'),
                                width: 120,
                                height: 100,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final pointer = tester.getCenter(find.byKey(const Key('context-target')));
      await tester.tapAt(pointer, buttons: kSecondaryMouseButton);
      await tester.pumpAndSettle();

      final item = find.text('Right-click action');
      expect(item, findsOneWidget);
      final rect = tester.getRect(find.byType(PopupMenuItem<void>));
      final leftDistance = (rect.left - pointer.dx).abs();
      final rightDistance = (rect.right - pointer.dx).abs();
      expect(leftDistance < 24 || rightDistance < 24, isTrue);
      expect((rect.top - pointer.dy).abs(), lessThan(48));
      expect(tester.takeException(), isNull);
    },
  );
}
