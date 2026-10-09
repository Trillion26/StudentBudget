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
  Future<void> add(TxnKind kind, int euros, int dayOfMonth,
          {String? category, String? goal, String note = '', int month = 10, Person person = Person.joint}) =>
      store.addTransaction(TxnDraft(kind: kind, amount: euros * 100, date: day(2026, month, dayOfMonth),
          categoryId: category == null ? null : cat(category), goalId: goal, note: note, person: person));
  await store.setPartnerNames('Kathleen', 'Triston');
  await add(TxnKind.income, 2500, 1, category: 'Salary – Kathleen', person: Person.partner1);
  await add(TxnKind.income, 2000, 1, category: 'Salary – Triston', person: Person.partner2);
  await add(TxnKind.expense, 1400, 1, category: 'Mortgage', note: 'ING');
  await add(TxnKind.expense, 640, 2, category: 'Groceries', note: 'Albert Heijn', person: Person.partner1);
  await add(TxnKind.expense, 85, 4, category: 'Groceries', note: 'Bread and milk', person: Person.partner2);
  await add(TxnKind.expense, 600, 2, category: 'Childcare (kinderopvang)');
  await add(TxnKind.expense, 120, 5, category: 'Fuel & charging', note: 'Shell', person: Person.partner2);
  await add(TxnKind.expense, 160, 6, category: 'Eating out & takeaway', note: 'Pizza night');
  await add(TxnKind.expense, 45, 7, category: 'Drugstore', note: 'Kruidvat', person: Person.partner1);
  await add(TxnKind.toSavings, 200, 1, goal: goals[0].id);
  await add(TxnKind.toSavings, 300, 1, goal: goals[1].id);
  await add(TxnKind.fromSavings, 150, 3, goal: goals[1].id, category: 'Days out', note: 'Zoo tickets');
  for (var m = 1; m <= 9; m++) {
    await add(TxnKind.expense, 650 + m * 10, 10, category: 'Groceries', month: m);
    await add(TxnKind.expense, 1400, 1, category: 'Mortgage', month: m);
    await add(TxnKind.income, 2500, 1, category: 'Salary – Kathleen', month: m, person: Person.partner1);
    await add(TxnKind.income, 2000, 1, category: 'Salary – Triston', month: m, person: Person.partner2);
    await add(TxnKind.toSavings, 250, 2, goal: goals[1].id, month: m);
  }
  await store.saveGoal(id: goals[1].id, name: goals[1].name, emoji: goals[1].emoji, targetAmount: 300000, targetDate: day(2027, 6, 30));
  await store.saveGoal(id: goals[0].id, name: goals[0].name, emoji: goals[0].emoji, targetAmount: 1000000);
  await store.saveMortgage(name: 'Mortgage', lender: 'ING', type: MortgageType.annuity, balance: 30000000, balanceDate: day(2026, 1, 1),
      endDate: day(2056, 1, 1), annualInterestRatePercent: 4.1, fixedRateUntil: day(2027, 3, 1),
      linkedCategoryId: cat('Mortgage'));
  await store.saveDebt(name: 'Student loan', lender: 'DUO', balanceOnStartDate: 1800000, startDate: day(2026, 1, 1),
      annualInterestRatePercent: 2.5, linkedCategoryId: cat('Student loan (DUO)'));
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
  await tester.scrollUntilVisible(find.text('Mortgage'), 200, scrollable: find.byType(Scrollable).first);
  await tester.tap(find.text('Mortgage').first);
  await snap(tester, '$prefix-8-mortgage');
  await tester.pageBack();
  await tester.pumpAndSettle();
  await tester.scrollUntilVisible(find.text('Loans'), 200, scrollable: find.byType(Scrollable).first);
  await tester.tap(find.text('Loans'));
  await snap(tester, '$prefix-8b-loans');
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
    await tester.tap(find.byKey(const Key('onboardingNext')));
    await snap(tester, 'onboarding-4');
    await tester.runAsync(() => store.db.close());
  });

  testWidgets('iPhone 15 light', (tester) => tour(tester, 'p390'));
  testWidgets('iPhone SE', (tester) => tour(tester, 'se', size: const Size(375, 667)));
  testWidgets('Pro Max dark', (tester) => tour(tester, 'max-dark', size: const Size(430, 932), brightness: Brightness.dark));
  testWidgets('SE text 2x', (tester) => tour(tester, 'se-text2', size: const Size(375, 667), textScale: 2));
}
