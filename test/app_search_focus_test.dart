import 'package:flex/app_search.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_app.dart';

void main() {
  testWidgets('AppSearch padding taps focus the search field', (tester) async {
    final harness = await FlexTestHarness.create();
    final selection = <String>{};

    await harness.pump(
      tester,
      Scaffold(
        body: AppSearch(
          controller: selection,
          onChange: (_) {},
          onSelectAll: () {},
          onDelete: () async {},
          onEdit: () async {},
          onShare: () async {},
        ),
      ),
      surfaceSize: const Size(430, 240),
    );
    await tester.pumpAndSettle();

    final searchBar = find.byType(SearchBar);
    final rect = tester.getRect(searchBar);
    final editable = tester.widget<EditableText>(
      find.descendant(of: searchBar, matching: find.byType(EditableText)),
    );
    expect(editable.focusNode.hasFocus, isFalse);
    expect(rect.left, greaterThan(0));

    await tester.tapAt(Offset(rect.left / 2, rect.center.dy));
    await tester.pump();

    expect(editable.focusNode.hasFocus, isTrue);
  });

  testWidgets('Desktop search shows separate icon actions without overflow', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 800);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final harness = await FlexTestHarness.create();
    final selection = <String>{};
    var selectAllCalls = 0;
    var editCalls = 0;
    var shareCalls = 0;

    Widget search() => Scaffold(
      body: AppSearch(
        controller: selection,
        onChange: (_) {},
        onSelectAll: () => selectAllCalls++,
        onDelete: () async {},
        onEdit: () async {
          editCalls++;
        },
        onShare: () async {
          shareCalls++;
        },
      ),
    );

    await harness.pump(tester, search(), surfaceSize: const Size(1200, 800));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.more_vert), findsNothing);
    expect(find.byKey(const Key('desktop-weight')), findsOneWidget);
    expect(find.byKey(const Key('desktop-search-settings')), findsOneWidget);
    expect(find.byKey(const Key('desktop-select-all')), findsOneWidget);
    await tester.tap(find.byKey(const Key('desktop-select-all')));
    expect(selectAllCalls, 1);

    selection.add('entry');
    await harness.pump(tester, search(), surfaceSize: const Size(1200, 800));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('desktop-clear-selection')), findsOneWidget);
    expect(find.byKey(const Key('desktop-edit')), findsOneWidget);
    expect(find.byKey(const Key('desktop-share')), findsOneWidget);
    expect(find.byKey(const Key('desktop-weight')), findsNothing);
    await tester.tap(find.byKey(const Key('desktop-edit')));
    await tester.tap(find.byKey(const Key('desktop-share')));
    expect(editCalls, 1);
    expect(shareCalls, 1);
    await tester.tap(find.byKey(const Key('desktop-clear-selection')));
    expect(selection, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Clear selection menu uses deselect icon and clears selection', (
    tester,
  ) async {
    final harness = await FlexTestHarness.create();
    final selection = <String>{}..add('plan');

    await harness.pump(
      tester,
      Scaffold(
        body: AppSearch(
          controller: selection,
          onChange: (_) {},
          onSelectAll: () {},
          onDelete: () async {},
          onEdit: () async {},
          onShare: () async {},
        ),
      ),
      surfaceSize: const Size(430, 600),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();

    final tile = tester.widget<ListTile>(
      find.ancestor(
        of: find.text('Clear selection'),
        matching: find.byType(ListTile),
      ),
    );
    expect((tile.leading! as Icon).icon, Icons.deselect);

    await tester.tap(find.text('Clear selection'));
    await tester.pumpAndSettle();
    expect(selection.isEmpty, isTrue);
  });

  testWidgets('AppSearch popup rows have one interactive surface', (
    tester,
  ) async {
    final harness = await FlexTestHarness.create();
    final selection = <String>{};
    var selectedAll = false;

    await harness.pump(
      tester,
      Scaffold(
        body: AppSearch(
          controller: selection,
          onChange: (_) {},
          onSelectAll: () => selectedAll = true,
          onDelete: () async {},
          onEdit: () async {},
          onShare: () async {},
        ),
      ),
      surfaceSize: const Size(430, 600),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();

    final selectAllText = find.text('Select all');
    expect(selectAllText, findsOneWidget);

    final tile = tester.widget<ListTile>(
      find.ancestor(of: selectAllText, matching: find.byType(ListTile)),
    );
    expect(tile.onTap, isNull);

    await tester.tap(selectAllText);
    await tester.pumpAndSettle();

    expect(selectedAll, isTrue);
  });
}
