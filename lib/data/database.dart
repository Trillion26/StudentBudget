import 'package:drift/drift.dart';

import '../logic/dates.dart';
import '../logic/models.dart';
import 'connection/connection.dart';
import 'tables.dart';

export 'tables.dart';

part 'database.g.dart';

/// The app's SQLite database on the phone.
@DriftDatabase(tables: [CategoryGroups, Categories, Transactions, SavingsGoals, Debts, Mortgages, Settings])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  /// Opens (or creates) the database file in the app's documents folder.
  /// In Chrome it uses the browser's storage instead.
  factory AppDatabase.open() => AppDatabase(openConnection());

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        // Household version: who paid, partner names and mortgages.
        await m.addColumn(transactions, transactions.person);
        await m.addColumn(settings, settings.partner1Name);
        await m.addColumn(settings, settings.partner2Name);
        await m.createTable(mortgages);
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  /// Deletes every row in every table (used by reset and restore).
  Future<void> wipe() async {
    await customStatement('PRAGMA foreign_keys = OFF');
    try {
      await transaction(() async {
        for (final TableInfo<Table, dynamic> table in [
          transactions,
          debts,
          mortgages,
          savingsGoals,
          categories,
          categoryGroups,
          settings,
        ]) {
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
  TxnFacts get facts => TxnFacts(
    kind: kind,
    amount: amount,
    date: dateOnly(date),
    categoryId: categoryId,
    goalId: goalId,
    person: person,
  );
}
