/// Plain data used by the calculators. These carry no Flutter or database
/// types so the rules can be unit-tested with fixed dates.
library;

/// What a transaction did with the money.
enum TxnKind {
  /// Money came in (allowance, NSFAS, job). Needs a category.
  income,

  /// Money was spent. Needs a category.
  expense,

  /// Money was put into a savings goal. Needs a goal.
  toSavings,

  /// Money was taken out of a savings goal. Needs a goal; may carry a
  /// category to say what it was spent on. Not counted as spending.
  fromSavings,
}

/// Whether a category group holds income or spending categories.
enum GroupKind { income, spending }

/// The parts of a transaction that the rules need.
class TxnFacts {
  const TxnFacts({
    required this.kind,
    required this.amount,
    required this.date,
    this.categoryId,
    this.goalId,
  });

  final TxnKind kind;

  /// Whole cents, always above zero.
  final int amount;

  /// Calendar day (see `dateOnly`).
  final DateTime date;
  final String? categoryId;
  final String? goalId;
}
