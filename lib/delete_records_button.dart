import 'package:flex/app_confirmation.dart';
import 'package:flex/data_action_tile.dart';
import 'dart:io';

import 'package:flex/l10n/l10n.dart';
import 'package:flex/main.dart';
import 'package:flex/storage/app_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class DeleteRecordsButton extends StatelessWidget {
  final BuildContext ctx;

  const DeleteRecordsButton({super.key, required this.ctx});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return DataActionTile(
      icon: Icons.delete_outline_rounded,
      label: l10n.deleteRecords,
      destructive: true,
      actions: [
        (
          Icons.insights,
          l10n.navGraphs,
          () => _delete(l10n.deleteAllGraphsConfirmation, () async {
            await db.delete(db.exerciseSets).go();
          }),
        ),
        (
          Icons.event,
          l10n.navPlans,
          () => _delete(l10n.deleteAllPlansConfirmation, () async {
            await db.transaction(() async {
              await db.delete(db.planExercises).go();
              await db.delete(db.plans).go();
            });
          }),
        ),
        (
          Icons.storage,
          l10n.databaseLabel,
          () => _delete(l10n.deleteDatabaseConfirmation, () async {
            final file = await getDatabaseFile();
            await db.close();
            await db.executor.close();
            await file.delete();
            if (defaultTargetPlatform == TargetPlatform.iOS ||
                defaultTargetPlatform == TargetPlatform.android) {
              SystemNavigator.pop();
            } else {
              exit(0);
            }
          }, close: false),
        ),
      ],
    );
  }

  Future<void> _delete(
    String message,
    Future<void> Function() operation, {
    bool close = true,
  }) async {
    final confirmed = await showAppConfirmation(
      ctx,
      title: ctx.l10n.confirmDelete,
      message: message,
      actionLabel: ctx.l10n.actionDelete,
      destructive: true,
    );
    if (!confirmed || !ctx.mounted) return;
    await operation();
    if (close && ctx.mounted) Navigator.pop(ctx);
  }
}
