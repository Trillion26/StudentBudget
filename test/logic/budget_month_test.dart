import 'package:flutter_test/flutter_test.dart';
import 'package:student_budget/logic/budget_month.dart';
import 'package:student_budget/logic/dates.dart';

void main() {
  group('start day 1 (calendar months)', () {
    final oct = BudgetMonth(2026, 10, 1);

    test('runs from the 1st to the last day of the month', () {
      expect(oct.start, day(2026, 10, 1));
      expect(oct.lastDay, day(2026, 10, 31));
      expect(oct.endExclusive, day(2026, 11, 1));
      expect(oct.length, 31);
      expect(oct.label, 'October 2026');
      expect(oct.rangeLabel, '');
    });

    test('contains its first and last day only', () {
      expect(oct.contains(day(2026, 9, 30)), isFalse);
      expect(oct.contains(day(2026, 10, 1)), isTrue);
      expect(oct.contains(day(2026, 10, 31)), isTrue);
      expect(oct.contains(day(2026, 11, 1)), isFalse);
      expect(oct.contains(DateTime(2026, 10, 31, 23, 59)), isTrue);
    });

    test('month ends of different lengths', () {
      expect(BudgetMonth(2026, 4, 1).length, 30);
      expect(BudgetMonth(2026, 2, 1).length, 28);
      expect(BudgetMonth(2026, 12, 1).lastDay, day(2026, 12, 31));
      expect(BudgetMonth(2026, 12, 1).next, BudgetMonth(2027, 1, 1));
      expect(BudgetMonth(2027, 1, 1).previous, BudgetMonth(2026, 12, 1));
    });

    test('leap years', () {
      expect(BudgetMonth(2028, 2, 1).length, 29);
      expect(BudgetMonth(2028, 2, 1).lastDay, day(2028, 2, 29));
      expect(BudgetMonth.containing(day(2028, 2, 29), 1), BudgetMonth(2028, 2, 1));
      expect(BudgetMonth(2100, 2, 1).length, 28);
    });
  });

  group('start day 25', () {
    final oct = BudgetMonth(2026, 10, 25);

    test('October 2026 runs 25 Oct to 24 Nov', () {
      expect(oct.start, day(2026, 10, 25));
      expect(oct.lastDay, day(2026, 11, 24));
      expect(oct.length, 31);
      expect(oct.rangeLabel, '25 Oct – 24 Nov');
    });

    test('dates fall into the right budget month', () {
      expect(BudgetMonth.containing(day(2026, 10, 24), 25), BudgetMonth(2026, 9, 25));
      expect(BudgetMonth.containing(day(2026, 10, 25), 25), oct);
      expect(BudgetMonth.containing(day(2026, 11, 24), 25), oct);
      expect(BudgetMonth.containing(day(2026, 11, 25), 25), BudgetMonth(2026, 11, 25));
    });

    test('wraps over the new year', () {
      final dec = BudgetMonth(2026, 12, 25);
      expect(dec.lastDay, day(2027, 1, 24));
      expect(BudgetMonth.containing(day(2027, 1, 10), 25), dec);
      expect(BudgetMonth.containing(day(2026, 1, 3), 25), BudgetMonth(2025, 12, 25));
    });

    test('leap years', () {
      expect(BudgetMonth(2028, 1, 25).length, 31); // 25 Jan – 24 Feb
      expect(BudgetMonth(2028, 2, 25).length, 29); // 25 Feb – 24 Mar, includes 29 Feb
      expect(BudgetMonth(2027, 2, 25).length, 28);
      expect(BudgetMonth.containing(day(2028, 2, 29), 25), BudgetMonth(2028, 2, 25));
    });
  });

  test('start day 28 in February', () {
    final feb = BudgetMonth(2026, 2, 28);
    expect(feb.start, day(2026, 2, 28));
    expect(feb.lastDay, day(2026, 3, 27));
  });

  group('days left', () {
    final oct = BudgetMonth(2026, 10, 1);
    test('counts today through the last day', () {
      expect(oct.daysLeft(day(2026, 10, 1)), 31);
      expect(oct.daysLeft(day(2026, 10, 7)), 25);
      expect(oct.daysLeft(day(2026, 10, 31)), 1);
    });
    test('is zero after the month and full before it', () {
      expect(oct.daysLeft(day(2026, 11, 1)), 0);
      expect(oct.daysLeft(day(2026, 9, 15)), 31);
    });
    test('works with start day 25', () {
      final m = BudgetMonth(2026, 10, 25);
      expect(m.daysLeft(day(2026, 11, 24)), 1);
      expect(m.daysLeft(day(2026, 10, 25)), 31);
    });
  });

  test('ordering and month arithmetic', () {
    final a = BudgetMonth(2026, 10, 1);
    expect(a.isBefore(a.next), isTrue);
    expect(a.monthsUntil(BudgetMonth(2027, 3, 1)), 5);
    expect(a.plusMonths(-10), BudgetMonth(2025, 12, 1));
  });
}
