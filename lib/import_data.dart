import 'package:flex/app_message.dart';
import 'package:flex/data_action_tile.dart';
import 'dart:convert';
import 'dart:io';

import 'package:csv/csv.dart';
import 'package:drift/drift.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flex/app_permissions_dialog.dart';
import 'package:flex/data_portability/external_workout_csv.dart';
import 'package:flex/data_portability/graph_csv.dart';
import 'package:flex/data_portability/import_issue.dart';
import 'package:flex/database/database.dart';
import 'package:flex/database/exercise_catalog.dart';
import 'package:flex/import_validation_exception.dart';
import 'package:flex/l10n/generated/app_localizations.dart';
import 'package:flex/l10n/l10n.dart';
import 'package:flex/logging.dart';
import 'package:flex/main.dart';
import 'package:flex/settings/backup_archive.dart';
import 'package:flex/storage/app_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

String _localizedImportError(Object error, AppLocalizations l10n) {
  if (error is MissingBackupDatabaseException) {
    return l10n.backupArchiveMissingDatabase;
  }
  if (error is ImportValidationException) return error.message;
  if (error is GraphCsvImportException) return error.message;
  if (error is ExternalWorkoutImportException) return error.message;
  return l10n.unexpectedError;
}

Future<({int plans, int links})> replacePlansFromCsv(
  AppDatabase database,
  String csvContent,
  AppLocalizations l10n,
) async {
  final csvList = CsvDecoder().convert(csvContent);
  if (csvList.isEmpty) throw ImportValidationException(l10n.csvFileEmpty);
  if (csvList.length <= 1) {
    throw ImportValidationException(l10n.csvNeedsDataRow);
  }

  return database.transaction(() async {
    final plansToInsert = <PlansCompanion>[];
    final links = <PlanExercisesCompanion>[];
    for (final row in csvList.skip(1)) {
      final idStr = row[0].toString().trim();
      final id = int.tryParse(idStr);
      if (id == null) {
        throw ImportValidationException(l10n.expectedIntegerPlanId(idStr));
      }
      plansToInsert.add(
        PlansCompanion.insert(
          id: Value(id),
          days: row[1].toString().trim(),
          title: Value(row[2].toString().trim()),
          sequence: Value(int.tryParse(row[3].toString().trim())),
        ),
      );

      final exerciseNames = row[4].toString().trim().split(';');
      for (final rawExerciseName in exerciseNames) {
        final exerciseName = rawExerciseName.trim();
        if (exerciseName.isEmpty) continue;
        var exercise = await getExerciseByName(database, exerciseName);
        exercise ??= await createExerciseDefinition(
          database,
          name: exerciseName,
          cardio: false,
          displayUnit: 'kg',
        );
        links.add(
          PlanExercisesCompanion.insert(
            planId: id,
            exerciseId: exercise.id,
            enabled: true,
            timers: const Value(true),
          ),
        );
      }
    }

    await database.planExercises.deleteAll();
    await database.plans.deleteAll();
    await database.plans.insertAll(plansToInsert);
    await database.planExercises.insertAll(links);
    return (plans: plansToInsert.length, links: links.length);
  });
}

class ImportData extends StatelessWidget {
  final BuildContext ctx;

  const ImportData({super.key, required this.ctx});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return DataActionTile(
      icon: Icons.upload_outlined,
      label: l10n.importData,
      actions: [
        (Icons.insights, l10n.navGraphs, () => _importCsv(_CsvKind.graphs)),
        (
          Icons.fitness_center_outlined,
          l10n.externalWorkoutCsv,
          () => _importCsv(_CsvKind.external),
        ),
        (Icons.event, l10n.navPlans, () => _importCsv(_CsvKind.plans)),
        (Icons.storage, l10n.backupLabel, _importDatabase),
      ],
    );
  }

  Future<void> _importDatabase() async {
    final l10n = ctx.l10n;
    talker.info('Starting Flex database import');

    try {
      if (kIsWeb) {
        await _importDatabaseWeb(l10n);
      } else {
        await _importDatabaseNative(l10n);
      }
    } catch (e, stackTrace) {
      talker.handle(e, stackTrace, 'Failed to import Flex database');
      if (!ctx.mounted) return;
      await _showImportError(l10n, e, stackTrace, kind: 'database');
    }
  }

  Future<void> _importDatabaseNative(AppLocalizations l10n) async {
    final result = await FilePicker.pickFiles();
    if (result.isEmpty) return;

    final selectedFile = File(result.single.path!);
    if (!await selectedFile.exists()) {
      throw ImportValidationException(l10n.selectedFileDoesNotExist);
    }

    final liveDatabase = await getDatabaseFile();
    final storageDir = liveDatabase.parent;
    final tempDirectory = await getTemporaryDirectory();
    final workDir = await tempDirectory.createTemp('flex-import-');
    try {
      final sourceFile = await prepareBackupDatabase(
        selectedFile: selectedFile,
        workingDirectory: workDir,
        storageDirectory: storageDir,
      );
      validateBackupDatabaseFile(sourceFile);

      final candidateFile = File(
        p.join(workDir.path, 'candidate-$backupDbName'),
      );
      await sourceFile.copy(candidateFile.path);

      final candidateDb = AppDatabase.forPath(candidateFile.path);
      try {
        // Opening the candidate performs every required migration and the
        // migration strategy's foreign-key validation before the live
        // database is touched.
        await candidateDb.customSelect('SELECT 1').get();
        final violations = await candidateDb
            .customSelect('PRAGMA foreign_key_check')
            .get();
        if (violations.isNotEmpty) {
          throw StateError('Foreign key violations in imported database');
        }
      } finally {
        await candidateDb.close();
      }

      final rollbackFile = File(p.join(workDir.path, 'rollback-$backupDbName'));

      await db.close();
      if (await liveDatabase.exists()) {
        await liveDatabase.copy(rollbackFile.path);
      }

      try {
        await candidateFile.copy(liveDatabase.path);
        db = AppDatabase.persistent();
        await db.customSelect('SELECT 1').get();
      } catch (_) {
        try {
          await db.close();
        } catch (_) {}
        if (await rollbackFile.exists()) {
          await rollbackFile.copy(liveDatabase.path);
        } else if (await liveDatabase.exists()) {
          await liveDatabase.delete();
        }
        db = AppDatabase.persistent();
        await db.customSelect('SELECT 1').get();
        rethrow;
      }

      dbVersion.value++;
      talker.info('Imported Flex data and image backup');
    } finally {
      await workDir.delete(recursive: true);
    }

    // Permission state belongs to this Android install, not to the imported
    // database. Force a fresh, single checklist for the imported settings.
    await (db.settings.update()).write(
      const SettingsCompanion(
        alarmSound: Value(''),
        explainedPermissions: Value(false),
        notificationPermissionRequested: Value(false),
      ),
    );

    final settings = await (db.settings.select()..limit(1)).getSingle();

    if (!ctx.mounted) return;
    await showAppPermissionsDialog(ctx, required: true, settings: settings);

    if (!ctx.mounted) return;
    Navigator.of(
      ctx,
      rootNavigator: true,
    ).pushNamedAndRemoveUntil('/', (_) => false);
  }

  Future<void> _importDatabaseWeb(AppLocalizations l10n) async {
    final result = await FilePicker.pickFiles();
    if (result.isEmpty) return;

    try {
      await result.single.readAsBytes();
    } catch (_) {
      throw ImportValidationException(l10n.couldNotReadFileData);
    }

    throw ImportValidationException(l10n.databaseImportWebUnsupported);
  }

  Future<void> _importCsv(_CsvKind kind) async {
    final l10n = ctx.l10n;
    final external = kind == _CsvKind.external;
    final plans = kind == _CsvKind.plans;
    try {
      final files = await FilePicker.pickFiles();
      if (files.isEmpty) return;
      final bytes = await files.single.readAsBytes();
      String content;
      if (external) {
        content = utf8.decode(bytes, allowMalformed: false);
      } else if (kIsWeb) {
        content = String.fromCharCodes(bytes);
      } else {
        try {
          content = utf8.decode(bytes, allowMalformed: false);
        } on FormatException {
          content = latin1.decode(bytes);
        }
      }

      switch (kind) {
        case _CsvKind.external:
          final result = await importExternalWorkoutCsv(db, content);
          talker.info(
            'Imported ${result.format.name} CSV: ${result.workouts} workouts, ${result.exercises} exercises, ${result.sets} sets',
          );
          dbVersion.value++;
        case _CsvKind.graphs:
          final result = await importGraphCsv(db, content);
          talker.info(
            'Imported graph/history CSV: exercises=${result.exercises}, workouts=${result.workouts}, sets=${result.exerciseSets}, bodyWeights=${result.bodyWeights}',
          );
        case _CsvKind.plans:
          final result = await replacePlansFromCsv(db, content, l10n);
          talker.info(
            'Imported ${result.plans} plans and ${result.links} exercises',
          );
      }

      if (!ctx.mounted) return;
      if (external) {
        messengerKey.currentState?.showSnackBar(
          SnackBar(
            content: Text(l10n.graphDataImported),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 5),
          ),
        );
      } else {
        Navigator.pop(ctx);
        showAppMessage(plans ? l10n.plansImported : l10n.graphDataImported);
      }
    } catch (error, stackTrace) {
      talker.handle(error, stackTrace, 'Failed to import ${kind.name} CSV');
      if (!ctx.mounted) return;
      if (external) {
        messengerKey.currentState?.showSnackBar(
          SnackBar(
            content: Text(
              l10n.failedToImportGraphs(_localizedImportError(error, l10n)),
            ),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 10),
          ),
        );
      } else {
        await _showImportError(l10n, error, stackTrace, kind: kind.name);
      }
    }
  }

  Future<void> _showImportError(
    AppLocalizations l10n,
    Object error,
    StackTrace stackTrace, {
    required String kind,
  }) async {
    final displayError = _localizedImportError(error, l10n);
    final message = switch (kind) {
      'database' => l10n.failedToImportDatabase(displayError),
      'plans' => l10n.failedToImportPlans(displayError),
      _ => l10n.failedToImportGraphs(displayError),
    };
    final url = kind == 'graphs'
        ? null
        : buildImportReportEmail(
            kind: kind,
            error: error,
            stackTrace: stackTrace,
            version: (await PackageInfo.fromPlatform()).version,
          );
    messengerKey.currentState!.showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        action: url == null
            ? null
            : SnackBarAction(
                label: l10n.emailDeveloper,
                onPressed: () async {
                  await launchUrl(url, mode: LaunchMode.externalApplication);
                },
              ),
        duration: const Duration(seconds: 10),
        persist: false,
      ),
    );
  }
}

enum _CsvKind { graphs, plans, external }
