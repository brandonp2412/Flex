import 'package:flex/app_confirmation.dart';
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
    return ListTile(
      onTap: () {
        showModalBottomSheet(
          useRootNavigator: true,
          context: context,
          builder: (context) {
            return SafeArea(
              child: Wrap(
                children: <Widget>[
                  ListTile(
                    leading: const Icon(Icons.insights),
                    title: Text(context.l10n.navGraphs),
                    onTap: () async {
                      Navigator.pop(context);
                      final confirmed = await showAppConfirmation(
                        ctx,
                        title: ctx.l10n.confirmDelete,
                        message: ctx.l10n.deleteAllGraphsConfirmation,
                        actionLabel: ctx.l10n.actionDelete,
                        destructive: true,
                      );
                      if (!confirmed || !ctx.mounted) return;
                      await db.delete(db.exerciseSets).go();
                      if (!ctx.mounted) return;
                      Navigator.pop(ctx);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.event),
                    title: Text(context.l10n.navPlans),
                    onTap: () async {
                      Navigator.pop(context);
                      final confirmed = await showAppConfirmation(
                        ctx,
                        title: ctx.l10n.confirmDelete,
                        message: ctx.l10n.deleteAllPlansConfirmation,
                        actionLabel: ctx.l10n.actionDelete,
                        destructive: true,
                      );
                      if (!confirmed || !ctx.mounted) return;
                      await db.transaction(() async {
                        await db.delete(db.planExercises).go();
                        await db.delete(db.plans).go();
                      });
                      if (!ctx.mounted) return;
                      Navigator.pop(ctx);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.storage),
                    title: Text(context.l10n.databaseLabel),
                    onTap: () async {
                      Navigator.pop(context);
                      final confirmed = await showAppConfirmation(
                        ctx,
                        title: ctx.l10n.confirmDelete,
                        message: ctx.l10n.deleteDatabaseConfirmation,
                        actionLabel: ctx.l10n.actionDelete,
                        destructive: true,
                      );
                      if (!confirmed || !ctx.mounted) return;
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
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
      leading: Icon(
        Icons.delete_outline_rounded,
        color: Theme.of(context).colorScheme.error,
      ),
      title: Text(
        context.l10n.deleteRecords,
        style: TextStyle(color: Theme.of(context).colorScheme.error),
      ),
      trailing: const Icon(Icons.chevron_right_rounded),
    );
  }
}
