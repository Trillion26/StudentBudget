import 'package:drift/drift.dart';
import 'package:drift/wasm.dart';
import 'package:sqlite3/wasm.dart';

/// In Chrome (development only) SQLite runs in the page and keeps its data
/// in the browser's IndexedDB. Needs web/sqlite3.wasm.
QueryExecutor openConnection() => LazyDatabase(() async {
      final sqlite3 = await WasmSqlite3.loadFromUrl(Uri.parse('sqlite3.wasm'));
      final fileSystem = await IndexedDbFileSystem.open(dbName: 'student_budget');
      sqlite3.registerVirtualFileSystem(fileSystem, makeDefault: true);
      return WasmDatabase(sqlite3: sqlite3, path: '/student_budget.sqlite', fileSystem: fileSystem);
    });
