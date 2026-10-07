// Renders every main screen to PNG files for a visual check, and fails on
// any layout overflow. Not part of the normal test run. Run it with:
//
//   flutter test tool/screenshots/screenshots_test.dart --dart-define=OUT=build/screenshots
//
// Emoji show as boxes because the test runner has no emoji font.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:student_budget/data/budget_store.dart';
import 'package:student_budget/logic/dates.dart';
import 'package:student_budget/logic/models.dart';

import '../../test/support/app_harness.dart';
import '../../test/support/fonts.dart';
import '../../test/support/test_store.dart';

const outDir = String.fromEnvironment('OUT', defaultValue: 'build/screenshots');

Future<void> addSampleMonth(BudgetStore store) async {
  String cat(String name) => store.data.categories.firstWhere((c) => c.name == name).id;
  final goals = store.data.goals;
  Future<void> add(TxnKind kind, int rand, int dayOfMonth, {String? category, String? goal, String note = '', int month = 10}) =>
      store.addTransaction(TxnDraft(kind: kind, amount: rand * 100, date: day(2026, month, dayOfMonth), categoryId: category == null ? null : cat(category), goalId: goal, note: note));
  await add(TxnKind.income, 3000, 1, category: 'Allowance from family');
  await add(TxnKind.income, 1200, 3, category: 'Part-time job', note: 'Weekend shifts');
  await add(TxnKind.expense, 640, 2, category: 'Groceries', note: 'Checkers');
  await add(TxnKind.expense, 85, 4, category: 'Groceries', note: 'Bread and milk');
  await add(TxnKind.expense, 250, 2, category: 'Data bundles', note: 'Monthly bundle');
  await add(TxnKind.expense, 120, 5, category: 'Taxi fares', note: 'Taxi to campus');
  await add(TxnKind.expense, 160, 6, category: 'Eating out & takeaways', note: 'Nando\'s with friends');
  await add(TxnKind.expense, 230, 6, category: 'Eating out & takeaways');
  await add(TxnKind.expense, 45, 7, category: 'Coffee & snacks on campus');
  await add(TxnKind.toSavings, 200, 1, goal: goals[0].id);
  await add(TxnKind.toSavings, 300, 1, goal: goals[1].id);
  await add(TxnKind.fromSavings, 150, 3, goal: goals[1].id, category: 'Textbooks', note: 'Second-hand textbook');
  for (var m = 1; m <= 9; m++) {
    await add(TxnKind.expense, 900 + m * 40, 10, category: 'Groceries', month: m);
    await add(TxnKind.expense, 380, 12, category: 'Taxi fares', month: m);
    await add(TxnKind.income, 4500, 1, category: 'Allowance from family', month: m);
    await add(TxnKind.toSavings, 250, 2, goal: goals[1].id, month: m);
  }
  await store.saveGoal(id: goals[1].id, name: goals[1].name, emoji: goals[1].emoji, targetAmount: 800000, targetDate: day(2027, 3, 31));
  await store.saveGoal(id: goals[0].id, name: goals[0].name, emoji: goals[0].emoji, targetAmount: 100000);
  final debt = store.data.debts.first;
  await store.saveDebt(id: debt.id, name: debt.name, lender: 'NSFAS', balanceOnStartDate: 2500000, startDate: day(2026, 1, 1),
      annualInterestRatePercent: 7.5, linkedCategoryId: debt.linkedCategoryId);
  await store.completeOnboarding();
}

Future<void> snap(WidgetTester tester, String name) async {
  await tester.pumpAndSettle();
  final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(screenshotKey));
  final image = await boundary.toImage(pixelRatio: 2);
  final bytes = await tester.runAsync(() => image.toByteData(format: ui.ImageByteFormat.png));
  Directory(outDir).createSync(recursive: true);
  File('$outDir/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
}

Future<void> tour(WidgetTester tester, String prefix, {Size size = const Size(390, 844), double textScale = 1, Brightness brightness = Brightness.light}) async {
  final store = await tester.runAsync(() async {
    final s = await createTestStore();
    await addSampleMonth(s);
    return s;
  });
  await pumpApp(tester, store!, size: size, textScale: textScale, brightness: brightness);
  await snap(tester, '$prefix-1-overview');
  await tester.scrollUntilVisible(find.text('Groceries & household'), 200, scrollable: find.byType(Scrollable).first);
  await tester.tap(find.text('Groceries & household'));
  await tester.pumpAndSettle();
  await tester.drag(find.byType(CustomScrollView).first, const Offset(0, -300));
  await snap(tester, '$prefix-2-overview-scrolled');

  await tester.tap(find.byKey(const Key('addButton')));
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(const Key('amountField')), '85,50');
  await tester.ensureVisible(find.text('Groceries').last);
  await tester.pumpAndSettle();
  await tester.tap(find.text('Groceries').last);
  await snap(tester, '$prefix-3-add-sheet');
  await tester.tap(find.byKey(const Key('saveButton')));
  await tester.pumpAndSettle();
  await snap(tester, '$prefix-4-after-add-toast');
  await tester.pump(const Duration(seconds: 5));

  await tester.tap(find.bySemanticsLabel(RegExp('^History, tab')));
  await snap(tester, '$prefix-5-history');
  await tester.tap(find.bySemanticsLabel(RegExp('^Budget, tab')));
  await snap(tester, '$prefix-6-budget');
  await tester.tap(find.bySemanticsLabel(RegExp('^Goals, tab')));
  await snap(tester, '$prefix-7-goals');
  await tester.tap(find.bySemanticsLabel(RegExp('^Budget, tab')));
  await tester.pumpAndSettle();
  await tester.scrollUntilVisible(find.text('Debts'), 200, scrollable: find.byType(Scrollable).first);
  await tester.tap(find.text('Debts'));
  await snap(tester, '$prefix-8-debts');
  await tester.pageBack();
  await tester.pumpAndSettle();
  await tester.scrollUntilVisible(find.text('Settings'), 200, scrollable: find.byType(Scrollable).first);
  await tester.tap(find.text('Settings'));
  await snap(tester, '$prefix-9-settings');
  await tester.pageBack();
  await tester.pumpAndSettle();
  await tester.tap(find.bySemanticsLabel(RegExp('^Overview, tab')));
  await tester.pumpAndSettle();
  await tester.scrollUntilVisible(find.text('See the year'), 300, scrollable: find.byType(Scrollable).first);
  // Lift it clear of the tab bar before tapping.
  await tester.drag(find.byType(Scrollable).first, const Offset(0, -250));
  await tester.pumpAndSettle();
  await tester.tap(find.text('See the year'));
  await tester.pumpAndSettle();
  expect(find.text('The year'), findsWidgets);
  await snap(tester, '$prefix-10-year');
  await tester.runAsync(() => store.db.close());
}

void main() {
  setUpAll(loadAppFonts);

  testWidgets('onboarding', (tester) async {
    final store = await tester.runAsync(createTestStore);
    await pumpApp(tester, store!);
    await snap(tester, 'onboarding-1');
    await tester.tap(find.byKey(const Key('onboardingNext')));
    await snap(tester, 'onboarding-2');
    await tester.tap(find.byKey(const Key('onboardingNext')));
    await snap(tester, 'onboarding-3');
    await tester.runAsync(() => store.db.close());
  });

  testWidgets('iPhone 15 light', (tester) => tour(tester, 'p390'));
  testWidgets('iPhone SE', (tester) => tour(tester, 'se', size: const Size(375, 667)));
  testWidgets('Pro Max dark', (tester) => tour(tester, 'max-dark', size: const Size(430, 932), brightness: Brightness.dark));
  testWidgets('SE text 2x', (tester) => tour(tester, 'se-text2', size: const Size(375, 667), textScale: 2));
}
