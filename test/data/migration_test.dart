import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;
import 'package:student_budget/data/budget_store.dart';
import 'package:student_budget/data/database.dart';
import 'package:student_budget/logic/models.dart';

/// The CREATE TABLE statements of schema 1: today's tables without the
/// columns and table that schema 2 added.
Future<List<String>> schemaOneTables() async {
  final db = AppDatabase(NativeDatabase.memory());
  final rows = await db.customSelect("SELECT name, sql FROM sqlite_master WHERE type = 'table'").get();
  await db.close();
  final statements = <String>[];
  for (final row in rows) {
    final name = row.read<String>('name');
    var sql = row.read<String>('sql');
    if (name == 'mortgages' || name.startsWith('sqlite_')) continue;
    // Drop the schema 2 column definitions.
    sql = sql.replaceAll(RegExp(r',\s*"(person|partner1_name|partner2_name)"[^,)]*'), '');
    statements.add(sql);
  }
  return statements;
}

void main() {
  test('a schema 1 database (student app) upgrades and keeps its data', () async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    final tables = await schemaOneTables();
    expect(tables.join(), isNot(contains('person')));

    final dir = Directory.systemTemp.createTempSync('budget_migration');
    final file = File('${dir.path}/db.sqlite');
    final old = sqlite.sqlite3.open(file.path);
    for (final sql in tables) {
      old.execute(sql);
    }
    old.execute(
      '''INSERT INTO settings (id, created_at, budget_month_start_day, app_lock_enabled, has_completed_onboarding)
                   VALUES (1, '2026-01-01T00:00:00.000Z', 1, 0, 1)''',
    );
    old.execute('''INSERT INTO category_groups (id, created_at, name, icon, sort_order, kind)
                   VALUES ('g', '2026-01-01T00:00:00.000Z', 'Food', '🛒', 0, 'spending')''');
    old.execute(
      '''INSERT INTO categories (id, created_at, name, emoji, group_id, monthly_budget, sort_order, is_archived)
                   VALUES ('c', '2026-01-01T00:00:00.000Z', 'Groceries', '🛒', 'g', 50000, 0, 0)''',
    );
    old.execute('''INSERT INTO transactions (id, created_at, kind, amount, date, note, category_id)
                   VALUES ('t', '2026-10-04T09:00:00.000Z', 'expense', 8550, '2026-10-04', 'Old entry', 'c')''');
    old.execute('PRAGMA user_version = 1');
    old.close();

    final store = BudgetStore(AppDatabase(NativeDatabase(file)), clock: () => DateTime(2026, 10, 7, 10));
    await store.init();
    final txn = store.data.transactions.single;
    expect(txn.note, 'Old entry');
    expect(txn.amount, 8550);
    expect(txn.person, Person.joint);
    expect(store.data.settings.partner1Name, 'Partner 1');
    expect(store.data.settings.hasCompletedOnboarding, isTrue);
    expect(store.data.mortgages, isEmpty);
    // The new features work on the upgraded database.
    await store.setPartnerNames('Kathleen', 'Triston');
    await store.saveMortgage(
      name: 'Part 1',
      type: MortgageType.linear,
      balance: 10000000,
      balanceDate: DateTime.utc(2026, 1, 1),
      endDate: DateTime.utc(2046, 1, 1),
      annualInterestRatePercent: 3.5,
    );
    expect(store.data.mortgages, hasLength(1));
    await store.db.close();
    dir.deleteSync(recursive: true);
  });
}
