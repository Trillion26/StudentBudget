import 'dart:math' as math;

import 'budget_month.dart';
import 'dates.dart';
import 'models.dart';

/// Result of estimating one debt.
class DebtEstimate {
  const DebtEstimate({
    required this.balance,
    required this.isFromStatement,
    required this.monthlyRepayment,
    required this.repaidThisYear,
    required this.repaidSinceStart,
    required this.monthsToPayOff,
    required this.payoffMonth,
  });

  /// Estimated balance now, in cents (never below zero).
  final int balance;

  /// True when the latest statement balance replaced the estimate.
  final bool isFromStatement;

  /// Average repayment over the last 3 budget months, in cents.
  final int monthlyRepayment;
  final int repaidThisYear;
  final int repaidSinceStart;

  /// Whole months until paid off, 0 when already paid off, or null when
  /// the repayment doesn't cover the interest (or there is no repayment).
  final int? monthsToPayOff;

  /// The calendar month it is paid off in, or null (see [monthsToPayOff]).
  final DateTime? payoffMonth;

  bool get isPaidOff => balance <= 0;
  bool get neverPaidOff => !isPaidOff && monthsToPayOff == null;
}

/// Debt rules from the spreadsheet's Debts sheet. No Flutter imports.
class DebtCalculator {
  const DebtCalculator._();

  /// Whole months from [start] to [today] (a month counts once the same
  /// day of the month is reached).
  static int monthsSinceStart(DateTime start, DateTime today) {
    var months = monthsBetween(start, today);
    if (today.day < start.day) months--;
    return math.max(0, months);
  }

  /// balance = B(1+r)^n − (P/n)·((1+r)^n − 1)/r, with r the monthly rate.
  /// r = 0 gives B − P; n = 0 gives B. Never below zero. Cents in, cents out.
  static int estimateBalance({
    required int balanceOnStartDate,
    required double annualInterestRatePercent,
    required int monthsSinceStart,
    required int totalRepaid,
  }) {
    final b = balanceOnStartDate.toDouble();
    final n = monthsSinceStart;
    final p = totalRepaid.toDouble();
    if (n <= 0) return math.max(0, balanceOnStartDate);
    final r = annualInterestRatePercent / 100 / 12;
    double value;
    if (r == 0) {
      value = b - p;
    } else {
      final growth = math.pow(1 + r, n).toDouble();
      value = b * growth - (p / n) * ((growth - 1) / r);
    }
    return math.max(0, value.round());
  }

  /// NPER(r, −payment, balance) rounded up: months to pay off [balance]
  /// with a fixed [monthlyPayment]. Null when the payment doesn't cover
  /// the interest.
  static int? monthsToPayOff({
    required int balance,
    required int monthlyPayment,
    required double annualInterestRatePercent,
  }) {
    if (balance <= 0) return 0;
    if (monthlyPayment <= 0) return null;
    final r = annualInterestRatePercent / 100 / 12;
    if (r == 0) return (balance + monthlyPayment - 1) ~/ monthlyPayment;
    final interest = balance * r;
    if (monthlyPayment <= interest) return null;
    final n = -math.log(1 - r * balance / monthlyPayment) / math.log(1 + r);
    // Guard against floating-point noise (e.g. 11.9999999 → 12).
    return (n - 1e-9).ceil();
  }

  /// Everything the Debts screen shows for one debt.
  ///
  /// Repayments are the [repayments] (expense transactions in the linked
  /// category) on or after [startDate].
  static DebtEstimate estimate({
    required int balanceOnStartDate,
    required DateTime startDate,
    required double annualInterestRatePercent,
    required Iterable<TxnFacts> repayments,
    required DateTime today,
    required int budgetMonthStartDay,
    int? latestStatementBalance,
  }) {
    final start = dateOnly(startDate);
    final now = dateOnly(today);
    final counted = repayments.where((t) => t.kind == TxnKind.expense && !t.date.isBefore(start) && !t.date.isAfter(now));
    final repaidSinceStart = counted.fold(0, (a, t) => a + t.amount);
    final repaidThisYear = counted.where((t) => t.date.year == now.year).fold(0, (a, t) => a + t.amount);

    final current = BudgetMonth.containing(now, budgetMonthStartDay);
    final windowStart = current.plusMonths(-2).start;
    final lastThree = counted.where((t) => !t.date.isBefore(windowStart)).fold(0, (a, t) => a + t.amount);
    final monthly = lastThree ~/ 3;

    final balance = latestStatementBalance ??
        estimateBalance(
          balanceOnStartDate: balanceOnStartDate,
          annualInterestRatePercent: annualInterestRatePercent,
          monthsSinceStart: monthsSinceStart(start, now),
          totalRepaid: repaidSinceStart,
        );
    final months = monthsToPayOff(
      balance: balance,
      monthlyPayment: monthly,
      annualInterestRatePercent: annualInterestRatePercent,
    );
    return DebtEstimate(
      balance: math.max(0, balance),
      isFromStatement: latestStatementBalance != null,
      monthlyRepayment: monthly,
      repaidThisYear: repaidThisYear,
      repaidSinceStart: repaidSinceStart,
      monthsToPayOff: months,
      payoffMonth: months == null ? null : DateTime.utc(now.year, now.month + months),
    );
  }
}
