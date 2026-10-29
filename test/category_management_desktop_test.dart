import 'package:flex/database/categories.dart';
import 'package:flex/settings/category_management_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_app.dart';

void main() {
  testWidgets('desktop category rows expose actions without overflow menu', (
    tester,
  ) async {
    final harness = await FlexTestHarness.create();
    await createCategory('Legs');
    await createCategory('Arms');
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await harness.pump(
      tester,
      const CategoryManagementPage(),
      surfaceSize: const Size(1200, 800),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.more_vert), findsNothing);
    expect(find.byIcon(Icons.edit_outlined), findsWidgets);
    expect(find.byIcon(Icons.merge_outlined), findsWidgets);
    expect(find.byIcon(Icons.delete_outline), findsWidgets);

    await tester.tap(find.byIcon(Icons.edit_outlined).first);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
  });

  testWidgets('mobile categories retain compact action menu', (tester) async {
    final harness = await FlexTestHarness.create();
    await createCategory('Legs');
    await harness.pump(
      tester,
      const CategoryManagementPage(),
      surfaceSize: const Size(390, 800),
    );
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.more_vert), findsWidgets);
  });
}
