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
  await store.setPartnerNames('Kathleen', 'Triston');
  await store.addTransaction(
    TxnDraft(
      kind: TxnKind.income,
      amount: 300000,
      date: day(2026, 10, 1),
      categoryId: cat('Salary – Kathleen'),
      person: Person.partner1,
    ),
  );
  await store.addTransaction(
    TxnDraft(
      kind: TxnKind.expense,
      amount: 8550,
      date: day(2026, 10, 4),
      categoryId: cat('Groceries'),
      note: 'Albert Heijn; "big shop"',
      person: Person.partner2,
    ),
  );
  await store.addTransaction(TxnDraft(kind: TxnKind.toSavings, amount: 20000, date: day(2026, 10, 2), goalId: goal.id));
  await store.addTransaction(
    TxnDraft(
      kind: TxnKind.fromSavings,
      amount: 5000,
      date: day(2026, 10, 3),
      goalId: goal.id,
      categoryId: cat('Holiday'),
    ),
  );
  await store.saveGoal(
    id: goal.id,
    name: goal.name,
    emoji: goal.emoji,
    targetAmount: 300000,
    targetDate: day(2027, 3, 1),
    startingBalance: 1000,
  );
  await store.saveDebt(
    name: 'Student loan',
    lender: 'DUO',
    balanceOnStartDate: 2500000,
    startDate: day(2026, 1, 15),
    annualInterestRatePercent: 2.5,
    linkedCategoryId: cat('Student loan (DUO)'),
    latestStatementBalance: 2400000,
    latestStatementDate: day(2026, 9, 30),
  );
  await store.saveMortgage(
    name: 'Part 1',
    lender: 'ING',
    type: MortgageType.annuity,
    balance: 30000000,
    balanceDate: day(2026, 1, 1),
    endDate: day(2056, 1, 1),
    annualInterestRatePercent: 4.1,
    fixedRateUntil: day(2036, 1, 1),
    linkedCategoryId: cat('Mortgage'),
  );
  await store.addCategory(
    groupId: store.data.spendingGroups.first.id,
    name: 'Garden',
    emoji: '🌳',
    monthlyBudget: 4000,
  );
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
    expect(after.mortgages, before.mortgages);
    expect(after.mortgages, isNotEmpty);
    expect(after.settings.partner1Name, 'Kathleen');
    expect(after.transactions.map((t) => t.person), containsAll([Person.partner1, Person.partner2, Person.joint]));
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
    test(
      'truncated file',
      () => expectRejected(good.substring(0, good.length ~/ 2), contains("isn't a backup from $appName")),
    );

    test('newer version', () {
      final m = parse()..['schemaVersion'] = 3;
      expectRejected(jsonEncode(m), contains('newer version'));
    });

    test('wrong version type', () {
      final m = parse()..['schemaVersion'] = '2';
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

  test('a version 1 backup from the student app still restores', () async {
    final store = await createTestStore();
    await addSampleData(store);
    final m = jsonDecode(store.exportBackupJson()) as Map<String, Object?>;
    m['schemaVersion'] = 1;
    m.remove('mortgages');
    (m['settings'] as Map).remove('partner1Name');
    (m['settings'] as Map).remove('partner2Name');
    for (final t in m['transactions'] as List) {
      (t as Map).remove('person');
    }
    final decoded = decodeBackup(jsonEncode(m));
    expect(decoded.mortgages, isEmpty);
    expect(decoded.settings.partner1Name, 'Partner 1');
    expect(decoded.transactions.every((t) => t.person == Person.joint), isTrue);
    await store.restore(decoded);
    expect(store.data.transactions.length, 4);
    await store.db.close();
  });

  test('CSV export for a year: semicolons and decimal commas for Dutch Excel', () async {
    final store = await createTestStore();
    await addSampleData(store);
    final csv = store.exportCsv(2026);
    final lines = csv.split('\r\n');
    expect(lines.first, '﻿date;kind;who;category;group;goal;amount;note');
    expect(lines[1], '2026-10-01;Received;Kathleen;Salary – Kathleen;Income;;3000,00;');
    expect(
      lines,
      contains('2026-10-04;Spent;Triston;Groceries;Groceries & household;;85,50;"Albert Heijn; ""big shop"""'),
    );
    expect(lines, contains('2026-10-03;Took from savings;Joint;Holiday;Holidays & trips;Emergency buffer;50,00;'));
    expect(store.exportCsv(2025).split('\r\n').where((l) => l.isNotEmpty).length, 1);
    await store.db.close();
  });

  test('backup file name', () {
    expect(backupFileName(DateTime(2026, 10, 7)), 'student-budget-backup-2026-10-07.json');
  });
}
