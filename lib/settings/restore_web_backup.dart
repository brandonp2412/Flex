import 'dart:js_interop';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:file_picker_web/file_picker_web.dart';
import 'package:flex/database/database.dart';
import 'package:flex/database/database_connection_web.dart';
import 'package:flex/import_validation_exception.dart';
import 'package:flex/l10n/generated/app_localizations.dart';
import 'package:flex/logging.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/wasm.dart';
import 'package:web/web.dart';

import 'backup_archive.dart';

Future<List<PlatformFile>> pickBackupFile() => FilePicker.pickFiles(
  webOptions: const FilePickerWebOptions(cancelUploadOnWindowBlur: false),
);

Future<AppDatabase> restoreWebBackup(
  String filename,
  Uint8List bytes,
  AppLocalizations l10n,
) async {
  final originalName = activeWebDatabase;
  final name = 'flexify-restore-${window.crypto.randomUUID()}';
  final (databaseBytes, images) = _readBackup(filename, bytes, l10n);
  await _validateBackup(databaseBytes, l10n);

  final opened = await openWebDatabase(
    name,
    initialize: () async => databaseBytes,
  );
  final candidate = AppDatabase(opened.resolvedExecutor);
  try {
    await candidate.customSelect('SELECT 1').get();
    if ((await candidate.customSelect('PRAGMA foreign_key_check').get())
        .isNotEmpty) {
      throw ImportValidationException(l10n.invalidBackupFile);
    }
    await candidate.watchSettings().first;
    await _restoreImages(candidate, images);
    final activated = await window.navigator.locks
        .request(
          'flex-backup-restore',
          ((Lock lock) {
            if (activeWebDatabase != originalName) return false.toJS;
            activateWebDatabase(name);
            return true.toJS;
          }).toJS,
        )
        .toDart;
    if (!(activated as JSBoolean).toDart) {
      throw StateError('The active Flex database changed during import.');
    }
  } catch (_) {
    try {
      await candidate.close();
      await discardWebDatabase(opened, name);
    } catch (error, stack) {
      talker.handle(error, stack, 'Failed to discard browser import');
    }
    rethrow;
  }
  return candidate;
}

(Uint8List, Map<String, ArchiveFile>) _readBackup(
  String filename,
  Uint8List bytes,
  AppLocalizations l10n,
) {
  if (p.extension(filename).toLowerCase() != '.zip') return (bytes, {});
  final Archive archive;
  try {
    archive = ZipDecoder().decodeBytes(bytes, verify: true);
  } catch (_) {
    throw ImportValidationException(l10n.invalidBackupFile);
  }
  final files = {
    for (final entry in archive)
      if (entry.isFile) p.posix.normalize(entry.name): entry,
  };
  final database = files[backupDbName] ?? files['flexify.sqlite'];
  if (database == null) throw const MissingBackupDatabaseException();
  return (database.content, files);
}

Future<void> _validateBackup(Uint8List bytes, AppLocalizations l10n) async {
  final sqlite = await WasmSqlite3.loadFromUrl(Uri.parse('sqlite3.wasm'));
  final fs = InMemoryFileSystem();
  sqlite.registerVirtualFileSystem(fs, makeDefault: true);
  const path = '/backup.sqlite';
  final file = fs
      .xOpen(
        Sqlite3Filename(path),
        SqlFlag.SQLITE_OPEN_CREATE | SqlFlag.SQLITE_OPEN_READWRITE,
      )
      .file;
  file.xWrite(bytes, 0);
  file.xClose();
  try {
    final db = sqlite.open(path, mode: OpenMode.readOnly);
    try {
      final tables = db
          .select("SELECT name FROM sqlite_master WHERE type = 'table'")
          .map((row) => row['name'])
          .toSet();
      if (!tables.contains('plans') ||
          (!tables.contains('gym_sets') && !tables.contains('exercises')) ||
          db.select('PRAGMA quick_check').single['quick_check'] != 'ok') {
        throw ImportValidationException(l10n.invalidBackupFile);
      }
    } finally {
      db.close();
    }
  } on SqliteException {
    throw ImportValidationException(l10n.invalidBackupFile);
  }
}

Future<void> _restoreImages(
  AppDatabase candidate,
  Map<String, ArchiveFile> files,
) async {
  await candidate.transaction(() async {
    for (final (table, column) in [
      ('exercises', 'image'),
      ('body_weights', 'photo'),
    ]) {
      final rows = await candidate
          .customSelect(
            'SELECT DISTINCT "$column" AS path FROM "$table" WHERE "$column" IS NOT NULL',
          )
          .get();
      for (final row in rows) {
        final path = row.read<String>('path');
        if (path.startsWith('data:')) continue;
        final image = path.startsWith('images/') ? files[path] : null;
        final uri = image == null
            ? null
            : Uri.dataFromBytes(image.content).toString();
        await candidate.customStatement(
          'UPDATE "$table" SET "$column" = ? WHERE "$column" = ?',
          [uri, path],
        );
      }
    }
  });
}
