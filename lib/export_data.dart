import 'dart:convert';

import 'package:csv/csv.dart';

import 'package:drift/drift.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flex/data_portability/graph_csv.dart';
import 'package:flex/data_action_tile.dart';
import 'package:flex/l10n/l10n.dart';
import 'package:flex/main.dart';
import 'package:flex/logging.dart';
import 'package:flex/plan/workout_sessions.dart';
import 'package:flex/settings/backup_archive.dart';
import 'package:flex/utils.dart';
import 'package:flex/storage/app_storage.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

class ExportData extends StatefulWidget {
  const ExportData({super.key});

  @override
  State<ExportData> createState() => _ExportDataState();
}

class _ExportDataState extends State<ExportData> {
  bool exporting = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return DataActionTile(
      icon: Icons.download_outlined,
      label: l10n.exportData,
      busy: exporting,
      actions: [
        (Icons.insights, l10n.navGraphs, _exportGraphs),
        (Icons.event, l10n.navPlans, _exportPlans),
        (Icons.storage, l10n.backupLabel, _exportBackup),
      ],
    );
  }

  Future<void> _exportGraphs() async {
    if (!await requestNotificationPermission()) return;
    final csv = await exportGraphCsv(db);
    await FilePicker.saveFile(
      fileName: 'graphs.csv',
      bytes: Uint8List.fromList(utf8.encode(csv)),
    );
    talker.info('Exported redesigned graph/history CSV');
  }

  Future<void> _exportPlans() async {
    final plans = await db.plans.select().get();
    final data = <List<dynamic>>[
      ['id', 'days', 'title', 'sequence', 'exercises'],
    ];
    for (final plan in plans) {
      final planExercises = await getPlanExerciseEntries(db, plan.id);
      data.add([
        plan.id,
        plan.days,
        plan.title ?? '',
        plan.sequence ?? '',
        planExercises.map((e) => e.exercise.name).join(';'),
      ]);
    }
    if (!await requestNotificationPermission()) return;
    final csv = CsvEncoder(lineDelimiter: "\n").convert(data);
    await FilePicker.saveFile(
      fileName: 'plans.csv',
      bytes: Uint8List.fromList(csv.codeUnits),
    );
    talker.info('Exported ${plans.length} plans to CSV');
  }

  Future<void> _exportBackup() async {
    setState(() => exporting = true);
    final tempDirectory = await getTemporaryDirectory();
    final workDir = await tempDirectory.createTemp('flex-export-');
    try {
      final databaseFile = await getDatabaseFile();
      final archive = await createBackupArchive(
        databasePath: databaseFile.path,
        workingDirectory: workDir,
      );
      await FilePicker.saveFile(
        fileName: 'flex-backup.zip',
        bytes: await archive.readAsBytes(),
      );
      talker.info('Exported Flex data and image backup');
    } finally {
      await workDir.delete(recursive: true);
      if (mounted) setState(() => exporting = false);
    }
  }
}
