import 'package:flutter_test/flutter_test.dart';
import 'package:student_budget/app_scope.dart';
import 'package:student_budget/logic/budget_month.dart';
import 'package:student_budget/logic/dates.dart';
import 'package:student_budget/logic/validation.dart';

void main() {
  test('dates run from 1 Jan 2026 to 31 Dec 2035', () {
    expect(Validation.years, [2026, 2027, 2028, 2029, 2030, 2031, 2032, 2033, 2034, 2035]);
    expect(Validation.date(day(2026, 1, 1)), isNull);
    expect(Validation.date(day(2035, 12, 31)), isNull);
    expect(Validation.date(day(2025, 12, 31)), 'Pick a date from 1 Jan 2026 onwards');
    expect(Validation.date(day(2036, 1, 1)), 'Pick a date up to 31 Dec 2035');
  });

  test('the selected month can go up to December 2035 but no further', () {
    final current = BudgetMonth(2026, 10, 1);
    final selected = SelectedMonth()..value = (2031, 4);
    expect(selected.resolve(current), BudgetMonth(2031, 4, 1));
    selected.value = (2036, 2);
    expect(selected.resolve(current), BudgetMonth(2035, 12, 1));
  });
}
