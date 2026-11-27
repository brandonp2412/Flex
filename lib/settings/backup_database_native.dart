import 'package:flex/settings/native_backup_database.dart';
import 'package:sqlite3/sqlite3.dart';

abstract interface class BackupDatabase {
  void execute(String sql, [List<Object?> parameters = const []]);

  ResultSet select(String sql, [List<Object?> parameters = const []]);

  void close();
}

BackupDatabase openBackupDatabase(String path) =>
    NativeBackupDatabase(sqlite3.open(path));
