import '../logic/budget_calculator.dart';
import '../logic/budget_month.dart';
import '../logic/debt_calculator.dart';
import '../logic/models.dart';
import '../logic/mortgage_calculator.dart';
import 'database.dart';

/// A read-only snapshot of everything in the database, with the lookups the
/// screens need. A household has at most a few thousand transactions a
/// year, so the whole set is kept in memory and recalculated after each change.
class AppData {
  AppData({
    required this.settings,
    required List<CategoryGroup> groups,
    required List<BudgetCategory> categories,
    required List<Txn> transactions,
    required List<SavingsGoal> goals,
    required this.debts,
    List<Mortgage> mortgages = const [],
  })  : mortgages = List.unmodifiable([...mortgages]..sort((a, b) => a.sortOrder.compareTo(b.sortOrder))),
        groups = List.unmodifiable(groups..sort((a, b) => a.sortOrder.compareTo(b.sortOrder))),
        categories = List.unmodifiable(_sortCategories(categories, groups)),
        transactions = List.unmodifiable(transactions..sort(newestFirst)),
        goals = List.unmodifiable(goals..sort((a, b) => a.sortOrder != b.sortOrder ? a.sortOrder.compareTo(b.sortOrder) : a.id.compareTo(b.id))) {
    for (final g in this.groups) {
      groupById[g.id] = g;
    }
    for (final c in this.categories) {
      categoryById[c.id] = c;
    }
    for (final g in this.goals) {
      goalById[g.id] = g;
    }
    facts = List.unmodifiable(this.transactions.map((t) => t.facts));
    for (final t in this.transactions) {
      if (t.categoryId != null) usage[t.categoryId!] = (usage[t.categoryId!] ?? 0) + 1;
      if (t.goalId != null) usage[t.goalId!] = (usage[t.goalId!] ?? 0) + 1;
    }
  }

  /// Group order first, then the category's own order, then id so the order
  /// is always the same.
  static List<BudgetCategory> _sortCategories(List<BudgetCategory> categories, List<CategoryGroup> groups) {
    final groupOrder = {for (final g in groups) g.id: g.sortOrder};
    return categories
      ..sort((a, b) {
        final byGroup = (groupOrder[a.groupId] ?? 0).compareTo(groupOrder[b.groupId] ?? 0);
        if (byGroup != 0) return byGroup;
        final byOrder = a.sortOrder.compareTo(b.sortOrder);
        return byOrder != 0 ? byOrder : a.id.compareTo(b.id);
      });
  }

  /// Newest date first; same day: newest entry first.
  static int newestFirst(Txn a, Txn b) {
    final byDate = b.date.compareTo(a.date);
    if (byDate != 0) return byDate;
    final byCreated = b.createdAt.compareTo(a.createdAt);
    return byCreated != 0 ? byCreated : a.id.compareTo(b.id);
  }

  final AppSettings settings;
  final List<CategoryGroup> groups;
  final List<BudgetCategory> categories;
  final List<Txn> transactions;
  final List<SavingsGoal> goals;
  final List<Debt> debts;
  final List<Mortgage> mortgages;

  final Map<String, CategoryGroup> groupById = {};
  final Map<String, BudgetCategory> categoryById = {};
  final Map<String, SavingsGoal> goalById = {};

  /// How many transactions use each category or goal id.
  final Map<String, int> usage = {};
  late final List<TxnFacts> facts;

  int get startDay => settings.budgetMonthStartDay;

  /// "Joint", or the partner's name.
  String personName(Person person) => switch (person) {
        Person.joint => 'Joint',
        Person.partner1 => settings.partner1Name,
        Person.partner2 => settings.partner2Name,
      };

  BudgetMonth monthOf(DateTime date) => BudgetMonth.containing(date, startDay);

  List<CategoryGroup> get incomeGroups => groups.where((g) => g.kind == GroupKind.income).toList();
  List<CategoryGroup> get spendingGroups => groups.where((g) => g.kind == GroupKind.spending).toList();

  bool isIncomeCategory(String categoryId) =>
      groupById[categoryById[categoryId]?.groupId]?.kind == GroupKind.income;

  /// Categories in [groupId], archived ones left out unless asked for.
  List<BudgetCategory> categoriesIn(String groupId, {bool includeArchived = false}) => categories
      .where((c) => c.groupId == groupId && (includeArchived || !c.isArchived))
      .toList();

  List<BudgetCategory> get activeIncomeCategories =>
      [for (final g in incomeGroups) ...categoriesIn(g.id)];

  List<BudgetCategory> get activeSpendingCategories =>
      [for (final g in spendingGroups) ...categoriesIn(g.id)];

  List<SavingsGoal> get activeGoals => goals.where((g) => !g.isArchived).toList();

  /// Sum of the income categories' monthly budgets.
  int get plannedIncome => activeIncomeCategories.fold(0, (a, c) => a + c.monthlyBudget);

  /// Sum of the spending categories' monthly budgets.
  int get plannedSpending => activeSpendingCategories.fold(0, (a, c) => a + c.monthlyBudget);

  int groupBudget(String groupId) => categoriesIn(groupId).fold(0, (a, c) => a + c.monthlyBudget);

  List<Txn> transactionsIn(BudgetMonth month) => transactions.where((t) => month.contains(t.date)).toList();

  MonthSummary summary(BudgetMonth month, DateTime today) => BudgetCalculator.summarise(
        txns: facts,
        month: month,
        plannedIncome: plannedIncome,
        today: today,
      );

  GoalProgress goalProgress(SavingsGoal goal, BudgetMonth currentMonth) => BudgetCalculator.goalProgress(
        goalId: goal.id,
        startingBalance: goal.startingBalance,
        target: goal.targetAmount,
        targetDate: goal.targetDate,
        txns: facts,
        currentMonth: currentMonth,
      );

  /// Balance, repayments and payoff month for [debt]. Repayments are
  /// expenses in the debt's linked category.
  DebtEstimate debtEstimate(Debt debt, DateTime today) => DebtCalculator.estimate(
        balanceOnStartDate: debt.balanceOnStartDate,
        startDate: debt.startDate,
        annualInterestRatePercent: debt.annualInterestRatePercent,
        repayments: debt.linkedCategoryId == null
            ? const []
            : facts.where((t) => t.kind == TxnKind.expense && t.categoryId == debt.linkedCategoryId),
        today: today,
        budgetMonthStartDay: startDay,
        latestStatementBalance: debt.latestStatementBalance,
      );

  /// Balance now, this month's payment and the full schedule for one
  /// mortgage part.
  MortgageStatus mortgageStatus(Mortgage m, DateTime today) => MortgageCalculator.status(
        balance: m.balance,
        balanceDate: m.balanceDate,
        endDate: m.endDate,
        annualRatePercent: m.annualInterestRatePercent,
        type: m.type,
        today: today,
      );

  /// Most-used first. Ties are broken by [thenBy] (largest first), then by
  /// the original order.
  List<T> byUsage<T>(List<T> items, String Function(T) idOf, {int Function(T)? thenBy}) {
    final indexed = items.indexed.toList();
    indexed.sort((a, b) {
      final diff = (usage[idOf(b.$2)] ?? 0) - (usage[idOf(a.$2)] ?? 0);
      if (diff != 0) return diff;
      if (thenBy != null) {
        final second = thenBy(b.$2) - thenBy(a.$2);
        if (second != 0) return second;
      }
      return a.$1 - b.$1;
    });
    return [for (final e in indexed) e.$2];
  }

  /// The label for a transaction's category, goal or both.
  String describe(Txn t) {
    final category = t.categoryId == null ? null : categoryById[t.categoryId];
    final goal = t.goalId == null ? null : goalById[t.goalId];
    switch (t.kind) {
      case TxnKind.income:
      case TxnKind.expense:
        return category?.name ?? 'Unknown category';
      case TxnKind.toSavings:
        return goal?.name ?? 'Savings';
      case TxnKind.fromSavings:
        return category != null ? category.name : (goal?.name ?? 'Savings');
    }
  }

  String emojiFor(Txn t) {
    if (t.kind == TxnKind.toSavings || (t.kind == TxnKind.fromSavings && t.categoryId == null)) {
      return goalById[t.goalId]?.emoji ?? '🐷';
    }
    return categoryById[t.categoryId]?.emoji ?? '❔';
  }

  DateTime? get lastEntryDate => transactions.isEmpty ? null : transactions.first.date;
}
