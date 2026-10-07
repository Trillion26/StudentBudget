import 'package:flutter_test/flutter_test.dart';
import 'package:student_budget/logic/budget_calculator.dart';
import 'package:student_budget/logic/budget_month.dart';
import 'package:student_budget/logic/dates.dart';
import 'package:student_budget/logic/models.dart';

TxnFacts txn(TxnKind kind, int rand, DateTime date, {String? category, String? goal, int cents = 0}) =>
    TxnFacts(kind: kind, amount: rand * 100 + cents, date: date, categoryId: category, goalId: goal);

void main() {
  final oct = BudgetMonth(2026, 10, 1);
  const planned = 450000; // R4 500

  group('monthly figures', () {
    test('sums each kind inside the month only', () {
      final txns = [
        txn(TxnKind.income, 3000, day(2026, 10, 1), category: 'allowance'),
        txn(TxnKind.expense, 85, day(2026, 10, 4), category: 'groceries', cents: 50),
        txn(TxnKind.expense, 400, day(2026, 10, 31), category: 'taxi'),
        txn(TxnKind.toSavings, 200, day(2026, 10, 2), goal: 'emergency'),
        txn(TxnKind.expense, 999, day(2026, 11, 1), category: 'taxi'),
        txn(TxnKind.expense, 999, day(2026, 9, 30), category: 'taxi'),
      ];
      final f = BudgetCalculator.monthFigures(txns, oct);
      expect(f.income, 300000);
      expect(f.spent, 48550);
      expect(f.saved, 20000);
      expect(f.hasLoggedIncome, isTrue);
    });

    test('taking from savings is not counted as spending', () {
      final txns = [
        txn(TxnKind.expense, 100, day(2026, 10, 3), category: 'groceries'),
        txn(TxnKind.fromSavings, 500, day(2026, 10, 3), goal: 'laptop', category: 'textbooks'),
      ];
      final f = BudgetCalculator.monthFigures(txns, oct);
      expect(f.spent, 10000);
      expect(f.fromSavings, 50000);
      expect(BudgetCalculator.spentByCategory(txns, oct), {'groceries': 10000});
    });

    test('start day 25 moves transactions into the right month', () {
      final m = BudgetMonth(2026, 10, 25);
      final txns = [
        txn(TxnKind.expense, 10, day(2026, 10, 24), category: 'a'),
        txn(TxnKind.expense, 20, day(2026, 10, 25), category: 'a'),
        txn(TxnKind.expense, 40, day(2026, 11, 24), category: 'a'),
        txn(TxnKind.expense, 80, day(2026, 11, 25), category: 'a'),
      ];
      expect(BudgetCalculator.monthFigures(txns, m).spent, 6000);
      expect(BudgetCalculator.monthFigures(txns, m.previous).spent, 1000);
      expect(BudgetCalculator.monthFigures(txns, m.next).spent, 8000);
    });
  });

  group('money left and daily allowance', () {
    test('uses planned income until income is logged', () {
      final txns = [txn(TxnKind.expense, 925, day(2026, 10, 5), category: 'groceries')];
      final s = BudgetCalculator.summarise(txns: txns, month: oct, plannedIncome: planned, today: day(2026, 10, 7));
      expect(s.usesPlannedIncome, isTrue);
      expect(s.baseIncome, planned);
      expect(s.moneyLeft, 357500);
      expect(s.daysLeft, 25);
      expect(s.dailyAllowance, 14300); // R3 575 ÷ 25 = R143
    });

    test('switches to actual income once any is logged', () {
      final txns = [
        txn(TxnKind.income, 2000, day(2026, 10, 1), category: 'allowance'),
        txn(TxnKind.expense, 500, day(2026, 10, 5), category: 'groceries'),
        txn(TxnKind.toSavings, 200, day(2026, 10, 5), goal: 'emergency'),
      ];
      final s = BudgetCalculator.summarise(txns: txns, month: oct, plannedIncome: planned, today: day(2026, 10, 7));
      expect(s.usesPlannedIncome, isFalse);
      expect(s.moneyLeft, 130000);
      expect(s.dailyAllowance, 5200); // 1300 / 25 = 52
    });

    test('first day of the month', () {
      final s = BudgetCalculator.summarise(txns: const [], month: oct, plannedIncome: planned, today: day(2026, 10, 1));
      expect(s.daysLeft, 31);
      expect(s.dailyAllowance, 14500); // 4500 / 31 = 145,16 → R145
    });

    test('last day of the month gives everything left', () {
      final s = BudgetCalculator.summarise(txns: const [], month: oct, plannedIncome: planned, today: day(2026, 10, 31));
      expect(s.daysLeft, 1);
      expect(s.dailyAllowance, 450000);
    });

    test('rounds down to whole rand', () {
      expect(BudgetCalculator.dailyAllowance(moneyLeft: 10099, daysLeft: 1), 10000);
      expect(BudgetCalculator.dailyAllowance(moneyLeft: 1000, daysLeft: 3), 300);
    });

    test('over budget shows the overspend instead', () {
      final txns = [
        txn(TxnKind.income, 1000, day(2026, 10, 1), category: 'job'),
        txn(TxnKind.expense, 1320, day(2026, 10, 2), category: 'rent'),
      ];
      final s = BudgetCalculator.summarise(txns: txns, month: oct, plannedIncome: planned, today: day(2026, 10, 7));
      expect(s.isOver, isTrue);
      expect(s.overBy, 32000);
      expect(s.dailyAllowance, isNull);
    });

    test('past and future months have no daily allowance', () {
      final past = BudgetCalculator.summarise(txns: const [], month: oct.previous, plannedIncome: planned, today: day(2026, 10, 7));
      final next = BudgetCalculator.summarise(txns: const [], month: oct.next, plannedIncome: planned, today: day(2026, 10, 7));
      expect(past.dailyAllowance, isNull);
      expect(next.dailyAllowance, isNull);
      expect(next.baseIncome, planned);
    });
  });

  group('category status', () {
    test('within budget', () {
      const s = CategoryStatus(budget: 60000, spent: 20000);
      expect(s.state, CategoryState.within);
      expect(s.remaining, 40000);
      expect(s.label, 'R400 left of R600');
      expect(s.progress, closeTo(1 / 3, 0.0001));
    });

    test('over budget', () {
      const s = CategoryStatus(budget: 60000, spent: 72000);
      expect(s.state, CategoryState.over);
      expect(s.label, 'R120 over');
      expect(s.progress, 1);
    });

    test('exactly on budget is not over', () {
      expect(const CategoryStatus(budget: 60000, spent: 60000).isOver, isFalse);
    });

    test('no budget with spending', () {
      const s = CategoryStatus(budget: 0, spent: 5000);
      expect(s.state, CategoryState.noBudget);
      expect(s.label, 'No budget set');
      expect(s.progress, 1);
      expect(s.isOver, isFalse);
    });
  });

  test('plan check', () {
    expect(BudgetCalculator.planFree(plannedIncome: 450000, plannedSpending: 420000), 30000);
    expect(BudgetCalculator.planFree(plannedIncome: 400000, plannedSpending: 420000), -20000);
  });

  group('goals', () {
    final txns = [
      txn(TxnKind.toSavings, 500, day(2025, 1, 1), goal: 'laptop'),
      txn(TxnKind.toSavings, 250, day(2026, 8, 3), goal: 'laptop'),
      txn(TxnKind.toSavings, 250, day(2026, 9, 3), goal: 'laptop'),
      txn(TxnKind.fromSavings, 100, day(2026, 10, 3), goal: 'laptop', category: 'textbooks'),
      txn(TxnKind.toSavings, 999, day(2026, 10, 3), goal: 'holiday'),
    ];

    test('balance covers all time and both directions', () {
      expect(BudgetCalculator.goalBalance(goalId: 'laptop', startingBalance: 10000, txns: txns), 100000);
    });

    test('needed per month', () {
      // R3 000 target, R500 saved, by March 2027 from October 2026: 5 months.
      expect(
        BudgetCalculator.neededPerMonth(target: 300000, balance: 50000, targetDate: day(2027, 3, 31), currentMonth: oct),
        50000,
      );
      // Target date this month or in the past: everything now.
      expect(
        BudgetCalculator.neededPerMonth(target: 300000, balance: 50000, targetDate: day(2026, 10, 20), currentMonth: oct),
        250000,
      );
      // Rounds up to whole rand.
      expect(
        BudgetCalculator.neededPerMonth(target: 100000, balance: 0, targetDate: day(2027, 1, 1), currentMonth: oct),
        33400,
      );
      expect(
        BudgetCalculator.neededPerMonth(target: 100000, balance: 120000, targetDate: day(2027, 1, 1), currentMonth: oct),
        0,
      );
    });

    test('average monthly saving uses the last 3 budget months', () {
      // Aug 250 + Sep 250 − Oct 100 = 400 ÷ 3
      expect(BudgetCalculator.averageMonthlySaving(goalId: 'laptop', txns: txns, currentMonth: oct), 13333);
    });

    test('status labels', () {
      GoalProgress progress({int? target, DateTime? date}) => BudgetCalculator.goalProgress(
            goalId: 'laptop',
            startingBalance: 0,
            target: target,
            targetDate: date,
            txns: txns,
            currentMonth: oct,
          );

      expect(progress().statusLabel, 'No target set');
      expect(progress(target: 80000).statusLabel, 'Goal reached');
      expect(progress(target: 200000).statusLabel, 'No target date');

      // Balance R900, target R1 500 by Feb 2027: R600 over 4 months = R150 a month.
      final behind = progress(target: 150000, date: day(2027, 2, 1));
      expect(behind.neededPerMonth, 15000);
      expect(behind.state, GoalState.behind);
      expect(behind.statusLabel, 'Behind – save R17 more a month'); // 150 − 133,33 → R17
      expect(behind.planLabel, 'R150 a month gets you there by February 2027');

      // R1 200 by June 2027: R300 over 8 months = R37,50 → R38 a month.
      final onTrack = progress(target: 120000, date: day(2027, 6, 1));
      expect(onTrack.neededPerMonth, 3800);
      expect(onTrack.statusLabel, 'On track');
    });
  });

  test('savings rate', () {
    expect(BudgetCalculator.savingsRate(saved: 20000, income: 400000), 0.05);
    expect(BudgetCalculator.savingsRate(saved: 20000, income: 0), isNull);
  });

  test('year summary', () {
    final txns = [
      txn(TxnKind.expense, 100, day(2026, 1, 5), category: 'groceries'),
      txn(TxnKind.expense, 50, day(2026, 1, 6), category: 'taxi'),
      txn(TxnKind.expense, 70, day(2026, 12, 31), category: 'taxi'),
      txn(TxnKind.expense, 999, day(2027, 1, 1), category: 'taxi'),
      txn(TxnKind.income, 4000, day(2026, 3, 1), category: 'job'),
      txn(TxnKind.toSavings, 400, day(2026, 3, 1), goal: 'g'),
      txn(TxnKind.fromSavings, 300, day(2026, 3, 2), goal: 'g'),
    ];
    final y = BudgetCalculator.yearSummary(
      year: 2026,
      startDay: 1,
      txns: txns,
      groupOfCategory: {'groceries': 'food', 'taxi': 'transport'},
      groupBudgets: {'food': 130000, 'transport': 50000},
    );
    expect(y.spentPerMonth[0], 15000);
    expect(y.spentPerMonth[11], 7000);
    expect(y.spent, 22000);
    expect(y.plannedSpendingPerMonth, 180000);
    final transport = y.groups.firstWhere((g) => g.groupId == 'transport');
    expect(transport.total, 12000);
    expect(transport.annualBudget, 600000);
    expect(transport.difference, 588000);
    expect(y.savingsRate, 0.1);
  });
}
