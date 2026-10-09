import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:student_budget/app_info.dart';
import 'package:student_budget/data/budget_store.dart';
import 'package:student_budget/logic/money.dart';

import '../support/app_harness.dart';
import '../support/test_store.dart';

String plain(String s) => s.replaceAll(thousandsSeparator, ' ');

Finder textContaining(String text) => find.byWidgetPredicate(
      (w) => w is Text && plain(w.data ?? w.textSpan?.toPlainText() ?? '').contains(text),
    );

void main() {
  late BudgetStore store;

  setUp(() async {
    store = await createTestStore();
  });
  tearDown(() => store.db.close());

  testWidgets('fresh install shows onboarding, then Overview with the starter budget', (tester) async {
    await pumpApp(tester, store);
    expect(find.text(appName), findsOneWidget);
    expect(find.text('Skip'), findsOneWidget);

    await tester.tap(find.byKey(const Key('onboardingNext')));
    await tester.pumpAndSettle();
    expect(find.text('What comes in each month?'), findsOneWidget);
    expect(textContaining('Total each month: R4 500'), findsOneWidget);

    await tester.tap(find.byKey(const Key('onboardingNext')));
    await tester.pumpAndSettle();
    expect(find.text('When does your money month start?'), findsOneWidget);

    await tester.tap(find.text('Start budgeting'));
    await tester.pumpAndSettle();

    // Overview: R4 500 planned, 25 days left on 7 October → R180 a day.
    expect(find.text('October 2026'), findsOneWidget);
    expect(find.text('You can spend'), findsOneWidget);
    expect(find.text('R180'), findsOneWidget);
    expect(find.text('a day for the next 25 days'), findsOneWidget);
    expect(textContaining('(R4 500 left this month)'), findsOneWidget);
    expect(find.textContaining('Based on your planned income'), findsOneWidget);
  });

  testWidgets('Overview shows the daily allowance', (tester) async {
    await store.completeOnboarding();
    await pumpApp(tester, store);
    expect(find.byKey(const Key('headlineNumber')), findsOneWidget);
    expect(find.text('R180'), findsOneWidget);
    expect(find.text('Where your money is going'), findsOneWidget);
    expect(find.text('Groceries & household'), findsOneWidget);
    expect(textContaining('R1 300 left of R1 300'), findsOneWidget);
  });

  testWidgets('the Add sheet saves an expense and Overview updates', (tester) async {
    await store.completeOnboarding();
    await pumpApp(tester, store);

    await tester.tap(find.byKey(const Key('addButton')));
    await tester.pumpAndSettle();
    expect(find.text('Add expense'), findsOneWidget);

    // Disabled until an amount and a category are chosen.
    await tester.enterText(find.byKey(const Key('amountField')), '85,50');
    await tester.pump();
    await tester.tap(find.text('Groceries'));
    await tester.pump();
    await tester.tap(find.byKey(const Key('saveButton')));
    await tester.pumpAndSettle();

    expect(find.text('Added R85,50 to Groceries'), findsOneWidget);
    expect(find.text('Undo'), findsOneWidget);
    expect(store.data.transactions.single.amount, 8550);
    // R4 414,50 ÷ 25 days = R176,58 → R176
    expect(find.text('R176'), findsOneWidget);
    expect(textContaining('R1 214,50 left of R1 300'), findsOneWidget);

    // Undo removes it again.
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(store.data.transactions, isEmpty);
    expect(find.text('R180'), findsOneWidget);
    await waitForToast(tester);
  });

  testWidgets('going over a category budget shows "over" text', (tester) async {
    await store.completeOnboarding();
    await pumpApp(tester, store);
    await tester.tap(find.byKey(const Key('addButton')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('amountField')), '520');
    await tester.tap(find.text('Taxi fares'));
    await tester.pump();
    await tester.tap(find.byKey(const Key('saveButton')));
    await tester.pumpAndSettle();
    // Transport budget is R500 (taxi R400 + Uber R100): R20 over.
    expect(find.text('R20 over'), findsOneWidget);
    await waitForToast(tester);
  });

  testWidgets('the amount field explains what to fix', (tester) async {
    await store.completeOnboarding();
    await pumpApp(tester, store);
    await tester.tap(find.byKey(const Key('addButton')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('amountField')), '85,505');
    await tester.pump();
    expect(find.text('Use at most 2 decimals, like 85,50'), findsOneWidget);
  });
}
