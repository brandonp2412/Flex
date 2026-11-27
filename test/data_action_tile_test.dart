import 'package:flex/data_action_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Data action menu dispatches only the selected action', (
    tester,
  ) async {
    final selected = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DataActionTile(
            icon: Icons.download_outlined,
            label: 'Export data',
            actions: [
              (Icons.insights, 'Graphs', () => selected.add('graphs')),
              (Icons.event, 'Plans', () => selected.add('plans')),
              (Icons.storage, 'Backup', () => selected.add('backup')),
            ],
          ),
        ),
      ),
    );
    await tester.tap(find.text('Export data'));
    await tester.pumpAndSettle();
    expect(find.text('Graphs'), findsOneWidget);
    expect(find.text('Plans'), findsOneWidget);
    expect(find.text('Backup'), findsOneWidget);
    await tester.tap(find.text('Plans'));
    await tester.pumpAndSettle();
    expect(selected, ['plans']);
    expect(find.text('Graphs'), findsNothing);
    expect(find.text('Export data'), findsOneWidget);
  });

  testWidgets('Dismissing data action menu does not run an action', (
    tester,
  ) async {
    var ran = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DataActionTile(
            icon: Icons.delete_outline,
            label: 'Delete records',
            destructive: true,
            actions: [(Icons.insights, 'Graphs', () => ran = true)],
          ),
        ),
      ),
    );
    await tester.tap(find.text('Delete records'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(ran, isFalse);
    expect(find.text('Graphs'), findsNothing);
  });
}
