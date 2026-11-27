import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flex/database/database.dart';
import 'package:flex/l10n/generated/app_localizations.dart';

Future<List<PlatformFile>> pickBackupFile() => FilePicker.pickFiles();

Future<AppDatabase> restoreWebBackup(
  String filename,
  Uint8List bytes,
  AppLocalizations l10n,
) => throw UnsupportedError('Browser storage is unavailable');
