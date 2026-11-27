import 'package:flex/settings/backup_database_native.dart';
import 'package:sqlite3/sqlite3.dart';

final class NativeBackupDatabase implements BackupDatabase {
  NativeBackupDatabase(this._database);

  final Database _database;

  @override
  void execute(String sql, [List<Object?> parameters = const []]) =>
      _database.execute(sql, parameters);

  @override
  ResultSet select(String sql, [List<Object?> parameters = const []]) =>
      _database.select(sql, parameters);

  @override
  void close() => _database.close();
}
