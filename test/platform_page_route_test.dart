import 'package:flex/platform_page_route.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
  });

  test('desktop page routes are actually instantaneous', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;

    final route = FlexPageRoute<void>(
      builder: (context) => const SizedBox.shrink(),
    );

    expect(route.transitionDuration, Duration.zero);
    expect(route.reverseTransitionDuration, Duration.zero);
  });

  test('mobile platform does not use desktop route timing', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;

    expect(isDesktopPlatform, isFalse);
  });

  testWidgets('outgoing route snapshots only after pop starts', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final navigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        home: const Scaffold(body: Text('Plans')),
      ),
    );

    navigatorKey.currentState!.push(
      FlexPageRoute<void>(
        snapshotOnPop: true,
        builder: (context) => const Scaffold(body: Text('Start plan')),
      ),
    );
    await tester.pumpAndSettle();

    final snapshot = tester.widget<SnapshotWidget>(find.byType(SnapshotWidget));
    expect(snapshot.controller.allowSnapshotting, isFalse);

    navigatorKey.currentState!.pop();
    expect(snapshot.controller.allowSnapshotting, isTrue);
    await tester.pumpAndSettle();

    expect(find.text('Plans'), findsOneWidget);
    expect(find.text('Start plan'), findsNothing);
    debugDefaultTargetPlatformOverride = null;
  });
}
