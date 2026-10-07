import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../logic/dates.dart';
import '../logic/models.dart';
import 'tables.dart';

export 'tables.dart';

part 'database.g.dart';

/// The app's SQLite database on the phone.
@DriftDatabase(tables: [CategoryGroups, Categories, Transactions, SavingsGoals, Debts, Settings])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  /// Opens (or creates) the database file in the app's documents folder.
  /// In Chrome it uses the browser's storage instead.
  factory AppDatabase.open() => AppDatabase(
        driftDatabase(
          name: 'student_budget',
          web: DriftWebOptions(
            sqlite3Wasm: Uri.parse('sqlite3.wasm'),
            driftWorker: Uri.parse('drift_worker.js'),
          ),
        ),
      );

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );

  /// Deletes every row in every table (used by reset and restore).
  Future<void> wipe() async {
    await customStatement('PRAGMA foreign_keys = OFF');
    try {
      await transaction(() async {
        for (final TableInfo<Table, dynamic> table in [transactions, debts, savingsGoals, categories, categoryGroups, settings]) {
          await delete(table).go();
        }
      });
    } finally {
      await customStatement('PRAGMA foreign_keys = ON');
    }
  }
}

/// Converts database rows to the plain facts the calculators use.
extension TxnFactsX on Txn {
  TxnFacts get facts => TxnFacts(kind: kind, amount: amount, date: dateOnly(date), categoryId: categoryId, goalId: goalId);
}
