import 'package:flex/app_fab.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('AppFab smoothly collapses and expands when scrolling', (
    tester,
  ) async {
    final scroll = ScrollController();
    addTearDown(scroll.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          floatingActionButtonAnimator:
              FloatingActionButtonAnimator.noAnimation,
          floatingActionButton: AppFab(
            onPressed: () {},
            label: const Text('Add'),
            icon: const Icon(Icons.add),
            scroll: scroll,
          ),
          body: ListView(
            controller: scroll,
            children: const [SizedBox(height: 2000)],
          ),
        ),
      ),
    );

    expect(
      tester
          .widget<FloatingActionButton>(find.byType(FloatingActionButton))
          .isExtended,
      isTrue,
    );
    final fab = find.byType(FloatingActionButton);
    final animatedContainer = find.descendant(
      of: find.byType(AppFab),
      matching: find.byType(AnimatedContainer),
    );
    final expandedWidth = tester.getSize(animatedContainer).width;
    expect(expandedWidth, 100);
    expect(
      tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity,
      1,
    );

    scroll.jumpTo(300);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    final intermediateWidth = tester.getSize(animatedContainer).width;
    await tester.pumpAndSettle();
    final collapsedWidth = tester.getSize(animatedContainer).width;
    expect(collapsedWidth, 56);

    expect(intermediateWidth, greaterThan(collapsedWidth));
    expect(intermediateWidth, lessThan(expandedWidth));
    expect(tester.widget<FloatingActionButton>(fab).isExtended, isFalse);

    scroll.jumpTo(0);
    await tester.pumpAndSettle();
    expect(tester.getSize(animatedContainer).width, expandedWidth);
    expect(tester.widget<FloatingActionButton>(fab).isExtended, isTrue);
  });
}
