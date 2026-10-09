/// Plain data used by the calculators. These carry no Flutter or database
/// types so the rules can be unit-tested with fixed dates.
library;

/// What a transaction did with the money.
enum TxnKind {
  /// Money came in (salary, child benefit). Needs a category.
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

/// Who an entry belongs to: the household as a whole or one partner.
enum Person { joint, partner1, partner2 }

/// How a mortgage part is repaid.
enum MortgageType {
  /// The same total payment every month; the repayment share grows.
  annuity,

  /// The same repayment every month; interest, and so the total, goes down.
  linear,

  /// Interest only; the loan is repaid in one go at the end.
  interestOnly,
}

/// The parts of a transaction that the rules need.
class TxnFacts {
  const TxnFacts({
    required this.kind,
    required this.amount,
    required this.date,
    this.categoryId,
    this.goalId,
    this.person = Person.joint,
  });

  final TxnKind kind;

  /// Whole cents, always above zero.
  final int amount;

  /// Calendar day (see `dateOnly`).
  final DateTime date;
  final String? categoryId;
  final String? goalId;
  final Person person;
}
