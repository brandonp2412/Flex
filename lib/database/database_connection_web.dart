import 'package:drift/drift.dart';
import 'package:drift/wasm.dart';
// ignore: deprecated_member_use
import 'package:drift/web.dart' show DriftWebStorage;
import 'package:web/web.dart';

const _activeDatabaseKey = 'flex.activeDatabase';
const _defaultDatabaseName = 'flexify';
final _sqliteUri = Uri.parse('sqlite3.wasm');
final _workerUri = Uri.parse('drift_worker.dart.js');

String get activeWebDatabase =>
    window.localStorage.getItem(_activeDatabaseKey) ?? _defaultDatabaseName;

void activateWebDatabase(String name) =>
    window.localStorage.setItem(_activeDatabaseKey, name);

DatabaseConnection createPersistentConnection() => DatabaseConnection.delayed(
  Future(() async {
    final name = activeWebDatabase;
    final result = await openWebDatabase(
      name,
      initialize: name == _defaultDatabaseName ? _restoreLegacyDatabase : null,
    );
    return result.resolvedExecutor;
  }),
);

Future<WasmDatabaseResult> openWebDatabase(
  String name, {
  Future<Uint8List?> Function()? initialize,
}) async {
  final result = await WasmDatabase.open(
    databaseName: name,
    sqlite3Uri: _sqliteUri,
    driftWorkerUri: _workerUri,
    initializeDatabase: initialize,
  );
  if (result.chosenImplementation == WasmStorageImplementation.inMemory) {
    await result.resolvedExecutor.close();
    throw StateError('This browser cannot persist Flex data.');
  }
  return result;
}

Future<void> discardWebDatabase(WasmDatabaseResult result, String name) async {
  final storage = result.chosenImplementation.storageApi;
  if (storage == null) return;
  final probe = await WasmDatabase.probe(
    sqlite3Uri: _sqliteUri,
    driftWorkerUri: _workerUri,
    databaseName: name,
  );
  await probe.deleteDatabase((storage, name));
}

Future<Uint8List?> _restoreLegacyDatabase() async {
  final storage = await DriftWebStorage.indexedDbIfSupported('flexify_db');
  await storage.open();
  try {
    return await storage.restore();
  } finally {
    await storage.close();
  }
}

QueryExecutor createConnectionForPath(String path) {
  throw UnsupportedError('Path-based database connection not supported on web');
}
