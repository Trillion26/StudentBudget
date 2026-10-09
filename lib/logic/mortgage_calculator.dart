import 'dart:math' as math;

import 'dates.dart';
import 'models.dart';

/// One monthly mortgage payment. [month] is the first day of the month it
/// is paid in.
class MortgagePayment {
  const MortgagePayment({
    required this.month,
    required this.interest,
    required this.repayment,
    required this.balanceAfter,
  });

  final DateTime month;

  /// Whole cents.
  final int interest;
  final int repayment;
  final int balanceAfter;

  int get total => interest + repayment;
}

/// What the Mortgage screen and the Excel export show for one part, seen on
/// a given day.
class MortgageStatus {
  const MortgageStatus({
    required this.balanceNow,
    required this.thisMonth,
    required this.paymentsLeft,
    required this.schedule,
  });

  /// Still owed after this month's payment.
  final int balanceNow;

  /// This month's payment, or null before the first or after the last one.
  final MortgagePayment? thisMonth;
  final int paymentsLeft;
  final List<MortgagePayment> schedule;

  /// Interest and repayment paid in calendar [year].
  ({int interest, int repayment}) inYear(int year) {
    var interest = 0, repayment = 0;
    for (final p in schedule) {
      if (p.month.year != year) continue;
      interest += p.interest;
      repayment += p.repayment;
    }
    return (interest: interest, repayment: repayment);
  }

  /// Balance after the last payment of calendar [year] (or the starting
  /// balance when the schedule starts later).
  int balanceAtEndOf(int year, int startingBalance) => balanceAtEndOfMonth(year, 12, startingBalance);

  /// Balance after the last payment up to and including [month] of [year].
  int balanceAtEndOfMonth(int year, int month, int startingBalance) {
    final end = DateTime.utc(year, month);
    var balance = startingBalance;
    for (final p in schedule) {
      if (p.month.isAfter(end)) break;
      balance = p.balanceAfter;
    }
    return balance;
  }
}

/// Mortgage rules. No Flutter or database imports.
class MortgageCalculator {
  const MortgageCalculator._();

  /// Number of monthly payments: one for each month after the month of
  /// [balanceDate], up to and including the month of [endDate].
  static int paymentCount(DateTime balanceDate, DateTime endDate) => math.max(0, monthsBetween(balanceDate, endDate));

  /// The fixed monthly payment of an annuity: B·r ÷ (1 − (1 + r)^−n), in
  /// whole cents. With 0% interest it is B ÷ n.
  static int annuityPayment({required int balance, required double annualRatePercent, required int months}) {
    if (months <= 0) return balance;
    final r = annualRatePercent / 100 / 12;
    if (r == 0) return (balance / months).round();
    return (balance * r / (1 - math.pow(1 + r, -months))).round();
  }

  /// Every payment from the month after [balanceDate] to the month of
  /// [endDate]. Interest is charged on the balance at the start of each
  /// month; the last payment repays whatever is left, so the balance always
  /// ends at zero.
  static List<MortgagePayment> schedule({
    required int balance,
    required DateTime balanceDate,
    required DateTime endDate,
    required double annualRatePercent,
    required MortgageType type,
  }) {
    final n = paymentCount(balanceDate, endDate);
    final r = annualRatePercent / 100 / 12;
    final annuity = annuityPayment(balance: balance, annualRatePercent: annualRatePercent, months: n);
    final linearRepayment = n == 0 ? balance : (balance / n).round();
    final payments = <MortgagePayment>[];
    var left = balance;
    for (var k = 1; k <= n; k++) {
      final interest = (left * r).round();
      final last = k == n;
      var repayment = switch (type) {
        MortgageType.annuity => annuity - interest,
        MortgageType.linear => linearRepayment,
        MortgageType.interestOnly => 0,
      };
      if (last || repayment > left) repayment = left;
      if (repayment < 0) repayment = 0;
      left -= repayment;
      payments.add(
        MortgagePayment(
          month: DateTime.utc(balanceDate.year, balanceDate.month + k),
          interest: interest,
          repayment: repayment,
          balanceAfter: left,
        ),
      );
    }
    return payments;
  }

  /// Where the part stands on [today]. This month's payment counts as made.
  static MortgageStatus status({
    required int balance,
    required DateTime balanceDate,
    required DateTime endDate,
    required double annualRatePercent,
    required MortgageType type,
    required DateTime today,
  }) {
    final payments = schedule(
      balance: balance,
      balanceDate: balanceDate,
      endDate: endDate,
      annualRatePercent: annualRatePercent,
      type: type,
    );
    final month = DateTime.utc(today.year, today.month);
    var now = balance;
    MortgagePayment? current;
    var left = 0;
    for (final p in payments) {
      if (p.month.isAfter(month)) {
        left++;
        continue;
      }
      now = p.balanceAfter;
      if (p.month == month) current = p;
    }
    return MortgageStatus(balanceNow: now, thisMonth: current, paymentsLeft: left, schedule: payments);
  }
}
