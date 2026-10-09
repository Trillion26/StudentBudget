import 'package:flutter_test/flutter_test.dart';
import 'package:student_budget/data/budget_store.dart';
import 'package:student_budget/logic/dates.dart';
import 'package:student_budget/logic/models.dart';

import '../support/test_store.dart';

void main() {
  late BudgetStore store;
  setUp(() async => store = await createTestStore());
  tearDown(() => store.db.close());

  group('seed data', () {
    test('household starter budget: 13 groups, 63 categories, all at € 0', () async {
      final fresh = await createTestStore(examplePlan: false);
      final d = fresh.data;
      expect(d.plannedIncome, 0);
      expect(d.plannedSpending, 0);
      expect(d.groups.length, 13);
      expect(d.incomeGroups.length, 1);
      expect(d.activeIncomeCategories.length, 7);
      expect(d.categories.length, 63);
      expect(
        d.categories.map((c) => c.name),
        containsAll(['Mortgage', 'Salary – Partner 1', 'Childcare (kinderopvang)']),
      );
      await fresh.db.close();
    });

    test('the example plan used by the tests is € 4.500 in and € 4.200 out', () {
      expect(store.data.plannedIncome, 450000);
      expect(store.data.plannedSpending, 420000);
    });

    test('every category has an emoji and a unique name', () {
      final names = store.data.categories.map((c) => c.name.toLowerCase()).toSet();
      expect(names.length, store.data.categories.length);
      expect(store.data.categories.every((c) => c.emoji.isNotEmpty), isTrue);
    });

    test('six goals, no loans and no mortgage yet', () {
      expect(store.data.goals.map((g) => g.name), [
        'Emergency buffer',
        'Holiday fund',
        "Kids' savings",
        'Home improvements',
        'Next car',
        'Investments',
      ]);
      expect(store.data.goals.every((g) => g.startingBalance == 0 && g.targetAmount == null), isTrue);
      expect(store.data.debts, isEmpty);
      expect(store.data.mortgages, isEmpty);
    });

    test('settings start with defaults', () {
      final s = store.data.settings;
      expect(s.budgetMonthStartDay, 1);
      expect(s.appLockEnabled, isFalse);
      expect(s.hasCompletedOnboarding, isFalse);
      expect(s.partner1Name, 'Partner 1');
      expect(s.partner2Name, 'Partner 2');
    });

    test('seeding runs only once', () async {
      await store.init();
      expect(store.data.categories.length, 63);
    });
  });

  group('transactions', () {
    String categoryId(String name) => store.data.categories.firstWhere((c) => c.name == name).id;

    test('adding an expense updates the daily allowance', () async {
      final month = store.data.monthOf(store.today());
      final before = store.data.summary(month, store.today());
      expect(before.dailyAllowance, 18000); // € 4.500 ÷ 25 days
      await store.addTransaction(
        TxnDraft(
          kind: TxnKind.expense,
          amount: 8550,
          date: store.today(),
          categoryId: categoryId('Groceries'),
          note: 'Albert Heijn',
        ),
      );
      final after = store.data.summary(month, store.today());
      expect(after.figures.spent, 8550);
      expect(after.moneyLeft, 441450);
      expect(after.dailyAllowance, 17600); // 4414,50 ÷ 25 = 176,58 → € 176
    });

    test('delete and undo put the same row back', () async {
      final row = await store.addTransaction(
        TxnDraft(kind: TxnKind.expense, amount: 4000, date: store.today(), categoryId: categoryId('Fuel & charging')),
      );
      final deleted = await store.deleteTransaction(row.id);
      expect(store.data.transactions, isEmpty);
      await store.restoreTransaction(deleted!);
      expect(store.data.transactions.single, row);
    });

    test('rejects missing category and bad amounts', () async {
      expect(
        () => store.addTransaction(TxnDraft(kind: TxnKind.expense, amount: 100, date: store.today())),
        throwsArgumentError,
      );
      expect(
        () => store.addTransaction(
          TxnDraft(kind: TxnKind.expense, amount: 0, date: store.today(), categoryId: categoryId('Groceries')),
        ),
        throwsArgumentError,
      );
      expect(
        () => store.addTransaction(
          TxnDraft(kind: TxnKind.expense, amount: 100, date: day(2025, 12, 31), categoryId: categoryId('Groceries')),
        ),
        throwsArgumentError,
      );
    });

    test('taking from savings changes the goal, not Spent', () async {
      final goal = store.data.goals.first;
      await store.addTransaction(
        TxnDraft(kind: TxnKind.toSavings, amount: 50000, date: store.today(), goalId: goal.id),
      );
      await store.addTransaction(
        TxnDraft(
          kind: TxnKind.fromSavings,
          amount: 20000,
          date: store.today(),
          goalId: goal.id,
          categoryId: categoryId('Holiday'),
        ),
      );
      final month = store.data.monthOf(store.today());
      final summary = store.data.summary(month, store.today());
      expect(summary.figures.spent, 0);
      expect(summary.figures.saved, 50000);
      expect(store.data.goalProgress(goal, month).balance, 30000);
    });

    test('start day 25 moves transactions into the right budget months', () async {
      await store.addTransaction(
        TxnDraft(kind: TxnKind.expense, amount: 1000, date: day(2026, 9, 26), categoryId: categoryId('Groceries')),
      );
      await store.addTransaction(
        TxnDraft(kind: TxnKind.expense, amount: 2000, date: day(2026, 10, 3), categoryId: categoryId('Groceries')),
      );
      final sept1 = store.data.monthOf(day(2026, 9, 26));
      expect(sept1.label, 'September 2026');
      await store.setBudgetMonthStartDay(25);
      final current = store.data.monthOf(store.today());
      expect(current.label, 'September 2026'); // 25 Sep – 24 Oct
      expect(store.data.summary(current, store.today()).figures.spent, 3000);
    });
  });

  group('household', () {
    String categoryId(String name) => store.data.categories.firstWhere((c) => c.name == name).id;

    test('entries remember who paid', () async {
      final row = await store.addTransaction(
        TxnDraft(
          kind: TxnKind.expense,
          amount: 2500,
          date: store.today(),
          categoryId: categoryId('Groceries'),
          person: Person.partner2,
        ),
      );
      expect(row.person, Person.partner2);
      expect(store.data.transactions.single.person, Person.partner2);
      final plain = await store.addTransaction(
        TxnDraft(kind: TxnKind.expense, amount: 100, date: store.today(), categoryId: categoryId('Groceries')),
      );
      expect(plain.person, Person.joint);
    });

    test('naming the partners renames their categories', () async {
      await store.setPartnerNames('Kathleen', 'Triston');
      expect(store.data.settings.partner1Name, 'Kathleen');
      expect(store.data.personName(Person.partner2), 'Triston');
      final names = store.data.categories.map((c) => c.name);
      expect(names, containsAll(['Salary – Kathleen', 'Health insurance – Triston', 'Pocket money – Kathleen']));
      expect(names.any((n) => n.endsWith('Partner 1')), isFalse);
      // Renaming again follows the new names, and budgets stay.
      await store.setPartnerNames('Kath', 'Triston');
      expect(store.data.categories.firstWhere((c) => c.name == 'Salary – Kath').monthlyBudget, 250000);
    });

    test('partner names must be different and not empty', () async {
      expect(() => store.setPartnerNames('Sam', 'sam'), throwsArgumentError);
      expect(() => store.setPartnerNames('', 'Sam'), throwsArgumentError);
    });

    test('a mortgage part is saved and its status worked out', () async {
      final mortgageCategory = categoryId('Mortgage');
      await store.saveMortgage(
        name: 'Part 1',
        lender: 'ING',
        type: MortgageType.annuity,
        balance: 30000000,
        balanceDate: day(2026, 1, 1),
        endDate: day(2056, 1, 1),
        annualInterestRatePercent: 4,
        fixedRateUntil: day(2036, 1, 1),
        linkedCategoryId: mortgageCategory,
      );
      final m = store.data.mortgages.single;
      expect(m.lender, 'ING');
      final status = store.data.mortgageStatus(m, store.today());
      expect(status.thisMonth!.total, 143225);
      expect(
        () => store.saveMortgage(
          name: 'Bad',
          type: MortgageType.linear,
          balance: 100,
          balanceDate: day(2026, 5, 1),
          endDate: day(2026, 5, 20),
          annualInterestRatePercent: 3,
        ),
        throwsArgumentError,
      );
      await store.deleteMortgage(m.id);
      expect(store.data.mortgages, isEmpty);
    });
  });

  group('categories', () {
    test('names are unique ignoring case', () async {
      final group = store.data.spendingGroups.first;
      expect(store.categoryNameError('groceries'), contains('already have'));
      expect(() => store.addCategory(groupId: group.id, name: 'GROCERIES', emoji: '🛒'), throwsArgumentError);
      final added = await store.addCategory(groupId: group.id, name: 'Garden', emoji: '🌳', monthlyBudget: 5000);
      expect(store.data.plannedSpending, 425000);
      await store.setCategoryArchived(added.id, true);
      expect(store.data.plannedSpending, 420000);
      expect(store.data.categoriesIn(group.id).any((c) => c.id == added.id), isFalse);
    });
  });

  group('backup reminder', () {
    test('shows after 20 transactions with no recent backup, hides for 7 days', () async {
      var now = testNow;
      final s = await createTestStore(clock: () => now);
      final id = s.data.categories.firstWhere((c) => c.name == 'Groceries').id;
      for (var i = 0; i < 20; i++) {
        await s.addTransaction(TxnDraft(kind: TxnKind.expense, amount: 100, date: s.today(), categoryId: id));
      }
      expect(s.shouldShowBackupReminder, isTrue);
      await s.hideBackupReminder();
      expect(s.shouldShowBackupReminder, isFalse);
      now = now.add(const Duration(days: 8));
      expect(s.shouldShowBackupReminder, isTrue);
      await s.markBackedUp();
      expect(s.shouldShowBackupReminder, isFalse);
      now = now.add(const Duration(days: 15));
      expect(s.shouldShowBackupReminder, isTrue);
      await s.db.close();
    });
  });

  test('reset puts the starter budget back and shows onboarding again', () async {
    await store.completeOnboarding();
    await store.setPartnerNames('Kathleen', 'Triston');
    await store.resetAll();
    expect(store.data.plannedIncome, 0);
    expect(store.data.settings.partner1Name, 'Partner 1');
    expect(store.data.settings.hasCompletedOnboarding, isFalse);
    expect(store.data.transactions, isEmpty);
  });
}
