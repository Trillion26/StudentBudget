// To look at the workbook, save it with:
//
//   flutter test test/export/year_report_test.dart --dart-define=OUT=build/student-budget-2026.xlsx
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:student_budget/data/budget_store.dart';
import 'package:student_budget/export/year_report.dart';
import 'package:student_budget/logic/dates.dart';
import 'package:student_budget/logic/models.dart';

import '../support/test_store.dart';

const outPath = String.fromEnvironment('OUT');

Future<void> addSampleYear(BudgetStore store) async {
  String cat(String name) => store.data.categories.firstWhere((c) => c.name == name).id;
  final goal = store.data.goals.first.id;
  Future<void> add(
    TxnKind kind,
    int rand,
    int month,
    int dayOfMonth, {
    String? category,
    String? goalId,
    String note = '',
  }) => store.addTransaction(
    TxnDraft(
      kind: kind,
      amount: rand * 100,
      date: day(2026, month, dayOfMonth),
      categoryId: category == null ? null : cat(category),
      goalId: goalId,
      note: note,
    ),
  );
  for (var m = 1; m <= 10; m++) {
    await add(TxnKind.income, 3000, m, 1, category: 'Allowance from family');
    await add(TxnKind.income, 1200 + m * 30, m, 3, category: 'Part-time job', note: 'Weekend shifts');
    await add(TxnKind.expense, 950 + m * 25, m, 4, category: 'Groceries', note: 'Checkers & <Spar>');
    await add(TxnKind.expense, 380, m, 6, category: 'Taxi fares');
    await add(TxnKind.expense, m.isEven ? 260 : 120, m, 8, category: 'Eating out & takeaways');
    await add(TxnKind.toSavings, 300, m, 2, goalId: goal);
  }
  await add(TxnKind.expense, 1450, 2, 14, category: 'Textbooks', note: 'Semester books');
  await add(TxnKind.fromSavings, 500, 7, 20, goalId: goal, category: 'Textbooks');
  // Outside 2026: left out of the 2026 report.
  await store.addTransaction(
    TxnDraft(kind: TxnKind.expense, amount: 99900, date: day(2027, 1, 5), categoryId: cat('Groceries')),
  );
}

void main() {
  test('builds a workbook with a dashboard, charts and the year\'s entries', () async {
    final store = await createTestStore();
    await addSampleYear(store);
    final bytes = store.exportExcel(2026);
    if (outPath.isNotEmpty) {
      File(outPath)
        ..createSync(recursive: true)
        ..writeAsBytesSync(bytes);
    }

    final zip = ZipDecoder().decodeBytes(bytes);
    String part(String name) => utf8.decode(zip.findFile(name)!.content);
    expect(zip.findFile('[Content_Types].xml'), isNotNull);
    expect(
      part('xl/workbook.xml'),
      allOf(
        contains('name="Dashboard"'),
        contains('name="Months"'),
        contains('name="Transactions"'),
        contains('name="Goals &amp; debts"'),
      ),
    );
    // Dashboard: bar and two doughnuts. Line chart reads the Months sheet.
    expect([for (var i = 1; i <= 4; i++) zip.findFile('xl/charts/chart$i.xml')], everyElement(isNotNull));
    expect(part('xl/charts/chart1.xml'), contains('<c:barChart>'));
    expect(part('xl/charts/chart4.xml'), allOf(contains('<c:lineChart>'), contains("'Months'!\$A\$4:\$A\$15")));

    final strings = part('xl/sharedStrings.xml');
    expect(strings, contains('STUDENT BUDGET DASHBOARD'));
    expect(strings, contains('Checkers &amp; &lt;Spar&gt;'));
    // 10 months × 6 entries + 2, and nothing from 2027.
    final transactions = part('xl/worksheets/sheet3.xml');
    expect(RegExp('<row ').allMatches(transactions).length, 63);
    expect(transactions, isNot(contains('<v>999</v>')));
    // Income for the year: 10 × 3000 + sum of 1200 + m × 30.
    expect(part('xl/worksheets/sheet1.xml'), contains('<v>${30000 + 12000 + 30 * 55}</v>'));
  });

  test('a year without entries still exports', () async {
    final store = await createTestStore();
    final zip = ZipDecoder().decodeBytes(store.exportExcel(2035));
    expect(utf8.decode(zip.findFile('xl/sharedStrings.xml')!.content), contains('No entries in 2035.'));
  });

  test('file name', () {
    expect(yearReportFileName(2026), 'student-budget-2026.xlsx');
  });
}
