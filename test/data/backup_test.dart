import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:student_budget/app_info.dart';
import 'package:student_budget/data/backup.dart';
import 'package:student_budget/data/budget_store.dart';
import 'package:student_budget/logic/dates.dart';
import 'package:student_budget/logic/models.dart';

import '../support/test_store.dart';

Future<void> addSampleData(BudgetStore store) async {
  String cat(String name) => store.data.categories.firstWhere((c) => c.name == name).id;
  final goal = store.data.goals.first;
  await store.addTransaction(TxnDraft(kind: TxnKind.income, amount: 300000, date: day(2026, 10, 1), categoryId: cat('Allowance from family')));
  await store.addTransaction(TxnDraft(kind: TxnKind.expense, amount: 8550, date: day(2026, 10, 4), categoryId: cat('Groceries'), note: 'Checkers, "big shop"'));
  await store.addTransaction(TxnDraft(kind: TxnKind.toSavings, amount: 20000, date: day(2026, 10, 2), goalId: goal.id));
  await store.addTransaction(TxnDraft(kind: TxnKind.fromSavings, amount: 5000, date: day(2026, 10, 3), goalId: goal.id, categoryId: cat('Textbooks')));
  await store.saveGoal(id: goal.id, name: goal.name, emoji: goal.emoji, targetAmount: 300000, targetDate: day(2027, 3, 1), startingBalance: 1000);
  final debt = store.data.debts.first;
  await store.saveDebt(
    id: debt.id,
    name: debt.name,
    lender: 'NSFAS',
    balanceOnStartDate: 2500000,
    startDate: day(2026, 1, 15),
    annualInterestRatePercent: 7.5,
    linkedCategoryId: debt.linkedCategoryId,
    latestStatementBalance: 2400000,
    latestStatementDate: day(2026, 9, 30),
  );
  await store.addCategory(groupId: store.data.spendingGroups.first.id, name: 'Gas for cooking', emoji: '🔥', monthlyBudget: 4000);
  await store.setCategoryArchived(cat('Water'), true);
  await store.setBudgetMonthStartDay(25);
  await store.completeOnboarding();
  await store.markBackedUp();
}

void main() {
  test('export, wipe, import gives identical data', () async {
    final store = await createTestStore();
    await addSampleData(store);
    final before = store.snapshot();
    final json = store.exportBackupJson();

    await store.resetAll();
    expect(store.data.transactions, isEmpty);

    final decoded = decodeBackup(json);
    expect(decoded.summary, '4 transactions, 6 goals, last entry 4 Oct 2026');
    await store.restore(decoded);
    final after = store.snapshot();

    expect(after.settings, before.settings);
    expect(after.groups, before.groups);
    expect(after.categories, before.categories);
    expect(after.transactions, before.transactions);
    expect(after.goals, before.goals);
    expect(after.debts, before.debts);
    // And exporting again gives the same file contents.
    final again = jsonDecode(store.exportBackupJson()) as Map<String, Object?>;
    final first = jsonDecode(json) as Map<String, Object?>;
    again.remove('exportedAt');
    first.remove('exportedAt');
    expect(again, first);
    await store.db.close();
  });

  group('rejects bad files without changing anything', () {
    late BudgetStore store;
    late String good;
    setUp(() async {
      store = await createTestStore();
      await addSampleData(store);
      good = store.exportBackupJson();
    });
    tearDown(() => store.db.close());

    Map<String, Object?> parse() => jsonDecode(good) as Map<String, Object?>;

    void expectRejected(String text, Matcher message) {
      final before = store.snapshot();
      expect(
        () => decodeBackup(text),
        throwsA(isA<BackupFormatException>().having((e) => e.message, 'message', message)),
      );
      final after = store.snapshot();
      expect(after.transactions, before.transactions);
      expect(after.categories, before.categories);
    }

    test('not JSON', () => expectRejected('this is not json {', contains("isn't a backup from $appName")));
    test('JSON but not a backup', () => expectRejected('{"hello": 1}', contains("isn't a backup from $appName")));
    test('truncated file', () => expectRejected(good.substring(0, good.length ~/ 2), contains("isn't a backup from $appName")));

    test('newer version', () {
      final m = parse()..['schemaVersion'] = 2;
      expectRejected(jsonEncode(m), contains('newer version'));
    });

    test('wrong version type', () {
      final m = parse()..['schemaVersion'] = '1';
      expectRejected(jsonEncode(m), contains('damaged'));
    });

    test('negative amount', () {
      final m = parse();
      ((m['transactions'] as List).first as Map)['amount'] = -5;
      expectRejected(jsonEncode(m), contains('damaged'));
    });

    test('transaction pointing at a missing category', () {
      final m = parse();
      ((m['transactions'] as List).first as Map)['categoryId'] = 'nope';
      expectRejected(jsonEncode(m), contains('damaged'));
    });

    test('expense without a category', () {
      final m = parse();
      final t = (m['transactions'] as List).firstWhere((t) => (t as Map)['kind'] == 'expense') as Map;
      t['categoryId'] = null;
      expectRejected(jsonEncode(m), contains('category is missing'));
    });

    test('duplicate category names', () {
      final m = parse();
      final cats = m['categories'] as List;
      (cats[1] as Map)['name'] = ((cats[0] as Map)['name'] as String).toUpperCase();
      expectRejected(jsonEncode(m), contains('damaged'));
    });

    test('impossible date', () {
      final m = parse();
      ((m['transactions'] as List).first as Map)['date'] = '2026-02-30';
      expectRejected(jsonEncode(m), contains('damaged'));
    });

    test('start day out of range', () {
      final m = parse();
      (m['settings'] as Map)['budgetMonthStartDay'] = 31;
      expectRejected(jsonEncode(m), contains('damaged'));
    });
  });

  test('CSV export for a year', () async {
    final store = await createTestStore();
    await addSampleData(store);
    final csv = store.exportCsv(2026);
    final lines = csv.split('\r\n');
    expect(lines.first, '﻿date,kind,category,group,goal,amount,note');
    expect(lines[1], '2026-10-01,Received,Allowance from family,Income,,3000.00,');
    expect(lines, contains('2026-10-04,Spent,Groceries,Groceries & household,,85.50,"Checkers, ""big shop"""'));
    expect(lines, contains('2026-10-03,Took from savings,Textbooks,Studies,Emergency fund,50.00,'));
    expect(store.exportCsv(2025).split('\r\n').where((l) => l.isNotEmpty).length, 1);
    await store.db.close();
  });

  test('backup file name', () {
    expect(backupFileName(DateTime(2026, 10, 7)), 'student-budget-backup-2026-10-07.json');
  });
}
