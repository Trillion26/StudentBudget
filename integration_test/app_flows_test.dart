// Runs on an iPhone simulator in GitHub Actions (see .github/workflows/ios.yml).
// Locally on Windows: flutter test integration_test -d windows
//
// The iPhone share sheet and file picker are system screens that tests
// can't drive, so the backup flow uses the same store calls the Settings
// buttons use (export → decode → restore) and checks the result on screen.
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:student_budget/app.dart';
import 'package:student_budget/data/backup.dart';
import 'package:student_budget/data/budget_store.dart';
import 'package:student_budget/data/database.dart';

import '../test/support/test_store.dart' show setExamplePlan;

Future<BudgetStore> freshStore() async {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  final store = BudgetStore(AppDatabase(NativeDatabase.memory()), clock: () => DateTime(2026, 10, 7, 10));
  await store.init();
  await setExamplePlan(store);
  await store.completeOnboarding();
  return store;
}

Future<void> addExpense(WidgetTester tester, String amount, String category) async {
  await tester.tap(find.byKey(const Key('addButton')));
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(const Key('amountField')), amount);
  await tester.pumpAndSettle();
  await tester.tap(find.text(category).last);
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('saveButton')));
  await tester.pumpAndSettle();
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('add an expense', (tester) async {
    final store = await freshStore();
    await tester.pumpWidget(StudentBudgetApp(store: store));
    await tester.pumpAndSettle();
    expect(find.text('€\u00A0180'), findsOneWidget);

    await addExpense(tester, '85,50', 'Groceries');

    expect(find.text('Added €\u00A085,50 to Groceries'), findsOneWidget);
    expect(find.text('€\u00A0176'), findsOneWidget);
    expect(store.data.transactions.single.amount, 8550);
    await tester.pump(const Duration(seconds: 5));
    await store.db.close();
  });

  testWidgets('back up and restore', (tester) async {
    final store = await freshStore();
    await tester.pumpWidget(StudentBudgetApp(store: store));
    await tester.pumpAndSettle();
    await addExpense(tester, '85,50', 'Groceries');
    await tester.pump(const Duration(seconds: 5));
    await addExpense(tester, '400', 'Childcare (kinderopvang)');
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    final before = store.snapshot();
    final json = store.exportBackupJson();

    await store.resetAll();
    await tester.pumpAndSettle();
    expect(store.data.transactions, isEmpty);

    final backup = decodeBackup(json);
    expect(backup.summary, '2 transactions, 6 goals, last entry 7 Oct 2026');
    await store.restore(backup);
    await tester.pumpAndSettle();

    expect(store.snapshot().transactions, before.transactions);
    expect(store.snapshot().categories, before.categories);
    // Back on Overview with the restored spending: € 4.014,50 ÷ 25 = € 160.
    expect(find.text('€\u00A0160'), findsOneWidget);
    await store.db.close();
  });
}
