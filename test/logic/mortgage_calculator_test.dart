import 'package:flutter_test/flutter_test.dart';
import 'package:student_budget/logic/dates.dart';
import 'package:student_budget/logic/models.dart';
import 'package:student_budget/logic/mortgage_calculator.dart';

void main() {
  // € 300.000 over 30 years at 4%, starting 1 Jan 2026.
  final start = day(2026, 1, 1);
  final end = day(2056, 1, 1);

  test('30 years is 360 payments, February 2026 to January 2056', () {
    expect(MortgageCalculator.paymentCount(start, end), 360);
    final s = MortgageCalculator.schedule(
      balance: 30000000,
      balanceDate: start,
      endDate: end,
      annualRatePercent: 4,
      type: MortgageType.annuity,
    );
    expect(s.first.month, DateTime.utc(2026, 2));
    expect(s.last.month, DateTime.utc(2056, 1));
  });

  test('annuity: € 1.432,25 a month, ending at zero', () {
    expect(MortgageCalculator.annuityPayment(balance: 30000000, annualRatePercent: 4, months: 360), 143225);
    final s = MortgageCalculator.schedule(
      balance: 30000000,
      balanceDate: start,
      endDate: end,
      annualRatePercent: 4,
      type: MortgageType.annuity,
    );
    expect(s.first.interest, 100000); // 300.000 × 4% ÷ 12
    expect(s.first.repayment, 43225);
    expect(s.first.total, 143225);
    expect(s[100].total, 143225);
    expect(s.last.balanceAfter, 0);
    expect(s.fold(0, (a, p) => a + p.repayment), 30000000);
    // The repayment share grows over time.
    expect(s[200].repayment, greaterThan(s[100].repayment));
  });

  test('linear: the same repayment each month and falling interest', () {
    final s = MortgageCalculator.schedule(
      balance: 36000000,
      balanceDate: start,
      endDate: end,
      annualRatePercent: 4,
      type: MortgageType.linear,
    );
    expect(s.first.repayment, 100000);
    expect(s.first.interest, 120000);
    expect(s[1].interest, lessThan(s.first.interest));
    expect(s.last.balanceAfter, 0);
  });

  test('interest only: interest each month, the whole loan at the end', () {
    final s = MortgageCalculator.schedule(
      balance: 12000000,
      balanceDate: start,
      endDate: day(2027, 1, 1),
      annualRatePercent: 3,
      type: MortgageType.interestOnly,
    );
    expect(s.length, 12);
    expect(s.first.interest, 30000);
    expect(s.first.repayment, 0);
    expect(s.last.repayment, 12000000);
    expect(s.last.balanceAfter, 0);
  });

  test('0% interest spreads the loan evenly', () {
    expect(MortgageCalculator.annuityPayment(balance: 1200000, annualRatePercent: 0, months: 12), 100000);
  });

  test('status on a day, and totals for a year', () {
    final status = MortgageCalculator.status(
      balance: 30000000,
      balanceDate: start,
      endDate: end,
      annualRatePercent: 4,
      type: MortgageType.annuity,
      today: day(2026, 10, 7),
    );
    // February to October: 9 payments made, October's included.
    expect(status.thisMonth!.month, DateTime.utc(2026, 10));
    expect(status.paymentsLeft, 351);
    expect(status.balanceNow, status.schedule[8].balanceAfter);
    final year = status.inYear(2026);
    expect(year.interest + year.repayment, 11 * 143225);
    expect(status.balanceAtEndOf(2026, 30000000), status.schedule[10].balanceAfter);
    expect(status.balanceAtEndOf(2025, 30000000), 30000000);
  });

  test('before the first payment nothing is paid yet', () {
    final status = MortgageCalculator.status(
      balance: 30000000,
      balanceDate: start,
      endDate: end,
      annualRatePercent: 4,
      type: MortgageType.annuity,
      today: day(2026, 1, 20),
    );
    expect(status.thisMonth, isNull);
    expect(status.balanceNow, 30000000);
    expect(status.paymentsLeft, 360);
  });
}
