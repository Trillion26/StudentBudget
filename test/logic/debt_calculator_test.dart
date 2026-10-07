import 'package:flutter_test/flutter_test.dart';
import 'package:student_budget/logic/dates.dart';
import 'package:student_budget/logic/debt_calculator.dart';
import 'package:student_budget/logic/models.dart';

void main() {
  group('estimateBalance', () {
    test('r = 0 is balance minus repayments', () {
      expect(
        DebtCalculator.estimateBalance(balanceOnStartDate: 1000000, annualInterestRatePercent: 0, monthsSinceStart: 4, totalRepaid: 200000),
        800000,
      );
    });

    test('n = 0 is the starting balance', () {
      expect(
        DebtCalculator.estimateBalance(balanceOnStartDate: 1000000, annualInterestRatePercent: 24, monthsSinceStart: 0, totalRepaid: 50000),
        1000000,
      );
    });

    test('r > 0 follows the spreadsheet formula', () {
      // B = R10 000, 24% a year (r = 2%), n = 3, P = R3 000:
      // 10000 × 1,02³ − (3000/3) × (1,02³ − 1)/0,02 = 10612,08 − 3060,40 = 7551,68
      expect(
        DebtCalculator.estimateBalance(balanceOnStartDate: 1000000, annualInterestRatePercent: 24, monthsSinceStart: 3, totalRepaid: 300000),
        755168,
      );
    });

    test('never below zero', () {
      expect(
        DebtCalculator.estimateBalance(balanceOnStartDate: 100000, annualInterestRatePercent: 0, monthsSinceStart: 2, totalRepaid: 500000),
        0,
      );
    });
  });

  group('monthsToPayOff (NPER, rounded up)', () {
    test('no interest', () {
      expect(DebtCalculator.monthsToPayOff(balance: 100000, monthlyPayment: 30000, annualInterestRatePercent: 0), 4);
      expect(DebtCalculator.monthsToPayOff(balance: 90000, monthlyPayment: 30000, annualInterestRatePercent: 0), 3);
    });

    test('with interest matches NPER', () {
      // NPER(2%, -1000, 10000) = 11,27 → 12
      expect(DebtCalculator.monthsToPayOff(balance: 1000000, monthlyPayment: 100000, annualInterestRatePercent: 24), 12);
    });

    test('payment that does not cover interest is never paid off', () {
      // Interest is R200 a month; paying R150 never clears it.
      expect(DebtCalculator.monthsToPayOff(balance: 1000000, monthlyPayment: 15000, annualInterestRatePercent: 24), isNull);
      expect(DebtCalculator.monthsToPayOff(balance: 1000000, monthlyPayment: 20000, annualInterestRatePercent: 24), isNull);
      expect(DebtCalculator.monthsToPayOff(balance: 1000000, monthlyPayment: 0, annualInterestRatePercent: 0), isNull);
    });

    test('already paid off', () {
      expect(DebtCalculator.monthsToPayOff(balance: 0, monthlyPayment: 0, annualInterestRatePercent: 24), 0);
    });
  });

  test('monthsSinceStart', () {
    expect(DebtCalculator.monthsSinceStart(day(2026, 7, 15), day(2026, 10, 14)), 2);
    expect(DebtCalculator.monthsSinceStart(day(2026, 7, 15), day(2026, 10, 15)), 3);
    expect(DebtCalculator.monthsSinceStart(day(2026, 10, 15), day(2026, 10, 1)), 0);
  });

  group('estimate', () {
    TxnFacts pay(int rand, DateTime date) => TxnFacts(kind: TxnKind.expense, amount: rand * 100, date: date, categoryId: 'loan');

    test('balance, repayment, payoff month', () {
      final e = DebtCalculator.estimate(
        balanceOnStartDate: 1000000,
        startDate: day(2026, 7, 7),
        annualInterestRatePercent: 24,
        repayments: [
          pay(500, day(2026, 6, 1)), // before start: ignored
          pay(1000, day(2026, 8, 1)),
          pay(1000, day(2026, 9, 1)),
          pay(1000, day(2026, 10, 1)),
        ],
        today: day(2026, 10, 7),
        budgetMonthStartDay: 1,
      );
      expect(e.balance, 755168);
      expect(e.repaidSinceStart, 300000);
      expect(e.repaidThisYear, 300000);
      expect(e.monthlyRepayment, 100000);
      // NPER(2%, -1000, 7551,68) = 8,24 → 9 months → July 2027
      expect(e.monthsToPayOff, 9);
      expect(e.payoffMonth, DateTime.utc(2027, 7));
      expect(e.isFromStatement, isFalse);
    });

    test('latest statement balance replaces the estimate', () {
      final e = DebtCalculator.estimate(
        balanceOnStartDate: 1000000,
        startDate: day(2026, 7, 7),
        annualInterestRatePercent: 0,
        repayments: const [],
        today: day(2026, 10, 7),
        budgetMonthStartDay: 1,
        latestStatementBalance: 420000,
      );
      expect(e.balance, 420000);
      expect(e.isFromStatement, isTrue);
      expect(e.neverPaidOff, isTrue);
    });
  });
}
