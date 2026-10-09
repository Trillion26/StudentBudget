import 'dart:math' as math;

import 'budget_month.dart';
import 'dates.dart';
import 'models.dart';
import 'money.dart';

/// Totals for one budget month.
class MonthFigures {
  const MonthFigures({
    required this.income,
    required this.spent,
    required this.saved,
    required this.fromSavings,
    required this.incomeCount,
  });

  static const zero = MonthFigures(income: 0, spent: 0, saved: 0, fromSavings: 0, incomeCount: 0);

  /// Sum of `income` transactions.
  final int income;

  /// Sum of `expense` transactions. `fromSavings` is never included.
  final int spent;

  /// Sum of `toSavings` transactions.
  final int saved;

  /// Sum of `fromSavings` transactions (shown separately, not spending).
  final int fromSavings;

  /// How many income transactions were logged.
  final int incomeCount;

  bool get hasLoggedIncome => incomeCount > 0;
}

/// The headline numbers on Overview for one budget month.
class MonthSummary {
  const MonthSummary({
    required this.month,
    required this.figures,
    required this.plannedIncome,
    required this.baseIncome,
    required this.usesPlannedIncome,
    required this.moneyLeft,
    required this.daysLeft,
    required this.dailyAllowance,
  });

  final BudgetMonth month;
  final MonthFigures figures;
  final int plannedIncome;

  /// Actual income if any was logged this month, otherwise planned income.
  final int baseIncome;
  final bool usesPlannedIncome;

  /// base income − spent − saved. Negative when over budget.
  final int moneyLeft;

  /// Days from today through the last day of the month (current month only).
  final int daysLeft;

  /// Whole euros a day (in cents), or null when over budget or not the
  /// current month.
  final int? dailyAllowance;

  bool get isOver => moneyLeft < 0;
  int get overBy => moneyLeft < 0 ? -moneyLeft : 0;
}

/// Where a category stands against its monthly budget.
enum CategoryState {
  /// Spent ≤ budget.
  within,

  /// Spent > budget and budget > 0.
  over,

  /// No budget set but some spending.
  noBudget,

  /// No budget and no spending.
  empty,
}

class CategoryStatus {
  const CategoryStatus({required this.budget, required this.spent});

  final int budget;
  final int spent;

  /// budget − spent (negative when over).
  int get remaining => budget - spent;

  CategoryState get state {
    if (budget > 0 && spent > budget) return CategoryState.over;
    if (budget <= 0 && spent > 0) return CategoryState.noBudget;
    if (budget <= 0 && spent <= 0) return CategoryState.empty;
    return CategoryState.within;
  }

  bool get isOver => state == CategoryState.over;

  /// Fill of the progress bar, 0–1. Full when over or when there is no
  /// budget but some spending.
  double get progress {
    if (budget <= 0) return spent > 0 ? 1 : 0;
    return math.min(1, spent / budget);
  }

  /// "€ 400 left of € 600", "€ 120 over", "No budget set".
  String get label {
    switch (state) {
      case CategoryState.over:
        return '${formatEuro(spent - budget)} over';
      case CategoryState.noBudget:
        return 'No budget set';
      case CategoryState.empty:
        return 'No budget set';
      case CategoryState.within:
        return '${formatEuro(remaining)} left of ${formatEuro(budget)}';
    }
  }

  CategoryStatus operator +(CategoryStatus other) =>
      CategoryStatus(budget: budget + other.budget, spent: spent + other.spent);
}

/// Goal progress labels.
enum GoalState { reached, onTrack, behind, noTarget, noTargetDate }

class GoalProgress {
  const GoalProgress({
    required this.balance,
    required this.target,
    required this.targetDate,
    required this.neededPerMonth,
    required this.averageMonthlySaving,
    required this.state,
  });

  final int balance;
  final int? target;
  final DateTime? targetDate;

  /// Whole euros per month (in cents) still needed to reach the target by
  /// the target date, or null without a target and date.
  final int? neededPerMonth;

  /// Average net saving into this goal over the last 3 budget months.
  final int averageMonthlySaving;
  final GoalState state;

  /// 0–1, or null without a target.
  double? get progress {
    final t = target;
    if (t == null || t <= 0) return null;
    return math.max(0, math.min(1, balance / t));
  }

  /// Extra per month needed when behind (whole euros, in cents).
  int get shortfallPerMonth {
    final needed = neededPerMonth;
    if (needed == null) return 0;
    return ceilToWholeEuro(needed - averageMonthlySaving);
  }

  /// "Goal reached", "On track", "Behind – save € 60 more a month",
  /// "No target set", "No target date".
  String get statusLabel {
    switch (state) {
      case GoalState.reached:
        return 'Goal reached';
      case GoalState.onTrack:
        return 'On track';
      case GoalState.behind:
        return 'Behind – save ${formatEuro(shortfallPerMonth)} more a month';
      case GoalState.noTarget:
        return 'No target set';
      case GoalState.noTargetDate:
        return 'No target date';
    }
  }

  /// "€ 250 a month gets you there by March 2027", or null.
  String? get planLabel {
    final needed = neededPerMonth;
    final date = targetDate;
    if (needed == null || date == null || state == GoalState.reached) return null;
    return '${formatEuro(needed)} a month gets you there by ${monthYearLabel(date)}';
  }
}

/// One row of the year view.
class YearGroupRow {
  YearGroupRow({required this.groupId, required this.monthly, required this.annualBudget});

  final String groupId;

  /// Spent per budget month, January first (12 entries).
  final List<int> monthly;

  /// The group's monthly budgets × 12.
  final int annualBudget;

  int get total => monthly.fold(0, (a, b) => a + b);

  /// annual budget − total (negative when over).
  int get difference => annualBudget - total;
}

class YearSummary {
  const YearSummary({
    required this.year,
    required this.spentPerMonth,
    required this.plannedSpendingPerMonth,
    required this.groups,
    required this.income,
    required this.saved,
    required this.spent,
  });

  final int year;

  /// Spending per budget month, January first (12 entries).
  final List<int> spentPerMonth;
  final int plannedSpendingPerMonth;
  final List<YearGroupRow> groups;
  final int income;
  final int saved;
  final int spent;

  /// saved ÷ income, or null when no income.
  double? get savingsRate => BudgetCalculator.savingsRate(saved: saved, income: income);
}

/// Every budget rule from the brief. No Flutter or database imports.
class BudgetCalculator {
  const BudgetCalculator._();

  /// Totals for the transactions that fall inside [month].
  static MonthFigures monthFigures(Iterable<TxnFacts> txns, BudgetMonth month) {
    var income = 0, spent = 0, saved = 0, fromSavings = 0, incomeCount = 0;
    for (final t in txns) {
      if (!month.contains(t.date)) continue;
      switch (t.kind) {
        case TxnKind.income:
          income += t.amount;
          incomeCount++;
        case TxnKind.expense:
          spent += t.amount;
        case TxnKind.toSavings:
          saved += t.amount;
        case TxnKind.fromSavings:
          fromSavings += t.amount;
      }
    }
    return MonthFigures(
      income: income,
      spent: spent,
      saved: saved,
      fromSavings: fromSavings,
      incomeCount: incomeCount,
    );
  }

  /// Actual income if any is logged, otherwise planned income.
  static int baseIncome(MonthFigures figures, int plannedIncome) =>
      figures.hasLoggedIncome ? figures.income : plannedIncome;

  /// base income − spent − saved.
  static int moneyLeft(MonthFigures figures, int plannedIncome) =>
      baseIncome(figures, plannedIncome) - figures.spent - figures.saved;

  /// floor(money left ÷ days left) in whole euros, as cents. Null when
  /// money left is below zero or there are no days left.
  static int? dailyAllowance({required int moneyLeft, required int daysLeft}) {
    if (moneyLeft < 0 || daysLeft <= 0) return null;
    final perDay = moneyLeft ~/ daysLeft;
    return perDay - perDay % 100;
  }

  /// Everything Overview's headline needs for [month], seen on [today].
  static MonthSummary summarise({
    required Iterable<TxnFacts> txns,
    required BudgetMonth month,
    required int plannedIncome,
    required DateTime today,
  }) {
    final figures = monthFigures(txns, month);
    final left = moneyLeft(figures, plannedIncome);
    final isCurrent = month.contains(today);
    final days = isCurrent ? month.daysLeft(today) : 0;
    return MonthSummary(
      month: month,
      figures: figures,
      plannedIncome: plannedIncome,
      baseIncome: baseIncome(figures, plannedIncome),
      usesPlannedIncome: !figures.hasLoggedIncome,
      moneyLeft: left,
      daysLeft: days,
      dailyAllowance: isCurrent ? dailyAllowance(moneyLeft: left, daysLeft: days) : null,
    );
  }

  /// Spent per category for [month] (expenses only).
  static Map<String, int> spentByCategory(Iterable<TxnFacts> txns, BudgetMonth month) {
    final result = <String, int>{};
    for (final t in txns) {
      if (t.kind != TxnKind.expense || t.categoryId == null || !month.contains(t.date)) continue;
      result[t.categoryId!] = (result[t.categoryId!] ?? 0) + t.amount;
    }
    return result;
  }

  /// Income and spending per person in [start] up to (not including)
  /// [end]. Every person is in the result, with zeros when nothing was
  /// logged.
  static Map<Person, ({int income, int spent})> byPerson(Iterable<TxnFacts> txns, DateTime start, DateTime end) {
    final income = {for (final p in Person.values) p: 0};
    final spent = {for (final p in Person.values) p: 0};
    for (final t in txns) {
      if (t.date.isBefore(start) || !t.date.isBefore(end)) continue;
      if (t.kind == TxnKind.income) income[t.person] = income[t.person]! + t.amount;
      if (t.kind == TxnKind.expense) spent[t.person] = spent[t.person]! + t.amount;
    }
    return {for (final p in Person.values) p: (income: income[p]!, spent: spent[p]!)};
  }

  /// Plan check: planned income − planned spending. Negative is a warning.
  static int planFree({required int plannedIncome, required int plannedSpending}) =>
      plannedIncome - plannedSpending;

  /// startingBalance + all toSavings − all fromSavings for [goalId].
  static int goalBalance({
    required String goalId,
    required int startingBalance,
    required Iterable<TxnFacts> txns,
  }) {
    var balance = startingBalance;
    for (final t in txns) {
      if (t.goalId != goalId) continue;
      if (t.kind == TxnKind.toSavings) balance += t.amount;
      if (t.kind == TxnKind.fromSavings) balance -= t.amount;
    }
    return balance;
  }

  /// (target − balance) ÷ max(1, whole months from [currentMonth] to the
  /// target date), rounded up to whole euros. Zero once reached.
  static int neededPerMonth({
    required int target,
    required int balance,
    required DateTime targetDate,
    required BudgetMonth currentMonth,
  }) {
    final remaining = target - balance;
    if (remaining <= 0) return 0;
    final months = math.max(1, (targetDate.year * 12 + targetDate.month) - (currentMonth.year * 12 + currentMonth.month));
    final perMonth = (remaining + months - 1) ~/ months;
    return ceilToWholeEuro(perMonth);
  }

  /// Average net saving (toSavings − fromSavings) into [goalId] over the
  /// current budget month and the two before it.
  static int averageMonthlySaving({
    required String goalId,
    required Iterable<TxnFacts> txns,
    required BudgetMonth currentMonth,
  }) {
    final from = currentMonth.plusMonths(-2).start;
    final to = currentMonth.endExclusive;
    var net = 0;
    for (final t in txns) {
      if (t.goalId != goalId || t.date.isBefore(from) || !t.date.isBefore(to)) continue;
      if (t.kind == TxnKind.toSavings) net += t.amount;
      if (t.kind == TxnKind.fromSavings) net -= t.amount;
    }
    return net ~/ 3;
  }

  /// Balance, needed per month and status for one goal.
  static GoalProgress goalProgress({
    required String goalId,
    required int startingBalance,
    required int? target,
    required DateTime? targetDate,
    required Iterable<TxnFacts> txns,
    required BudgetMonth currentMonth,
  }) {
    final balance = goalBalance(goalId: goalId, startingBalance: startingBalance, txns: txns);
    final average = averageMonthlySaving(goalId: goalId, txns: txns, currentMonth: currentMonth);
    if (target == null || target <= 0) {
      return GoalProgress(
        balance: balance,
        target: null,
        targetDate: targetDate,
        neededPerMonth: null,
        averageMonthlySaving: average,
        state: GoalState.noTarget,
      );
    }
    if (balance >= target) {
      return GoalProgress(
        balance: balance,
        target: target,
        targetDate: targetDate,
        neededPerMonth: 0,
        averageMonthlySaving: average,
        state: GoalState.reached,
      );
    }
    if (targetDate == null) {
      return GoalProgress(
        balance: balance,
        target: target,
        targetDate: null,
        neededPerMonth: null,
        averageMonthlySaving: average,
        state: GoalState.noTargetDate,
      );
    }
    final needed = neededPerMonth(
      target: target,
      balance: balance,
      targetDate: targetDate,
      currentMonth: currentMonth,
    );
    return GoalProgress(
      balance: balance,
      target: target,
      targetDate: targetDate,
      neededPerMonth: needed,
      averageMonthlySaving: average,
      state: average >= needed ? GoalState.onTrack : GoalState.behind,
    );
  }

  /// Saved ÷ income for a period; null when income is zero.
  static double? savingsRate({required int saved, required int income}) =>
      income <= 0 ? null : saved / income;

  /// Year view figures for the budget months labelled January–December of
  /// [year]. [groupOfCategory] maps spending category ids to group ids and
  /// [groupBudgets] gives each spending group's monthly budget.
  static YearSummary yearSummary({
    required int year,
    required int startDay,
    required Iterable<TxnFacts> txns,
    required Map<String, String> groupOfCategory,
    required Map<String, int> groupBudgets,
  }) {
    final months = [for (var m = 1; m <= 12; m++) BudgetMonth(year, m, startDay)];
    final yearStart = months.first.start;
    final yearEnd = months.last.endExclusive;
    final perMonth = List<int>.filled(12, 0);
    final perGroup = <String, List<int>>{
      for (final g in groupBudgets.keys) g: List<int>.filled(12, 0),
    };
    var income = 0, saved = 0, spent = 0;
    for (final t in txns) {
      if (t.date.isBefore(yearStart) || !t.date.isBefore(yearEnd)) continue;
      final index = BudgetMonth.containing(t.date, startDay).month - 1;
      switch (t.kind) {
        case TxnKind.income:
          income += t.amount;
        case TxnKind.toSavings:
          saved += t.amount;
        case TxnKind.fromSavings:
          break;
        case TxnKind.expense:
          spent += t.amount;
          perMonth[index] += t.amount;
          final group = groupOfCategory[t.categoryId];
          if (group != null) {
            perGroup.putIfAbsent(group, () => List<int>.filled(12, 0))[index] += t.amount;
          }
      }
    }
    final planned = groupBudgets.values.fold(0, (a, b) => a + b);
    return YearSummary(
      year: year,
      spentPerMonth: perMonth,
      plannedSpendingPerMonth: planned,
      groups: [
        for (final entry in perGroup.entries)
          YearGroupRow(
            groupId: entry.key,
            monthly: entry.value,
            annualBudget: (groupBudgets[entry.key] ?? 0) * 12,
          ),
      ],
      income: income,
      saved: saved,
      spent: spent,
    );
  }
}
