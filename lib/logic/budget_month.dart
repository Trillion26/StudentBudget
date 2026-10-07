import 'dates.dart';

/// One budget month. With start day `d`, the month labelled
/// "October 2026" runs from 2026-10-d up to and including the day before
/// 2026-11-d. With `d` = 1 this is the calendar month.
class BudgetMonth implements Comparable<BudgetMonth> {
  BudgetMonth(int year, int month, this.startDay)
      : assert(startDay >= 1 && startDay <= 28, 'startDay must be 1–28'),
        year = DateTime.utc(year, month).year,
        month = DateTime.utc(year, month).month;

  /// The budget month that contains [date].
  factory BudgetMonth.containing(DateTime date, int startDay) {
    final d = dateOnly(date);
    if (d.day >= startDay) return BudgetMonth(d.year, d.month, startDay);
    return BudgetMonth(d.year, d.month - 1, startDay);
  }

  /// The year and month in the label, e.g. 2026 and 10 for "October 2026".
  final int year;
  final int month;

  /// The day of the month on which every budget month starts (1–28).
  final int startDay;

  /// First day in this budget month.
  DateTime get start => day(year, month, startDay);

  /// First day of the next budget month (exclusive end).
  DateTime get endExclusive => day(year, month + 1, startDay);

  /// Last day in this budget month.
  DateTime get lastDay => day(year, month + 1, startDay - 1);

  /// Number of days in this budget month.
  int get length => daysBetween(start, endExclusive);

  bool contains(DateTime date) {
    final d = dateOnly(date);
    return !d.isBefore(start) && d.isBefore(endExclusive);
  }

  /// Days left counting [today] through the last day of the month.
  /// Zero when today is after the month; the whole month when before it.
  int daysLeft(DateTime today) {
    final t = dateOnly(today);
    if (!t.isBefore(endExclusive)) return 0;
    if (t.isBefore(start)) return length;
    return daysBetween(t, endExclusive);
  }

  BudgetMonth get next => BudgetMonth(year, month + 1, startDay);
  BudgetMonth get previous => BudgetMonth(year, month - 1, startDay);

  BudgetMonth plusMonths(int count) => BudgetMonth(year, month + count, startDay);

  /// Same label month with a different start day.
  BudgetMonth withStartDay(int newStartDay) => BudgetMonth(year, month, newStartDay);

  /// Months from this one to [other] (positive when [other] is later).
  int monthsUntil(BudgetMonth other) => (other.year * 12 + other.month) - (year * 12 + month);

  /// "October 2026"
  String get label => '${monthNames[month - 1]} $year';

  /// "Oct"
  String get shortLabel => shortMonthNames[month - 1];

  /// "25 Oct – 24 Nov", or empty for calendar months.
  String get rangeLabel {
    if (startDay == 1) return '';
    final last = lastDay;
    return '${start.day} ${shortMonthNames[start.month - 1]} – ${last.day} ${shortMonthNames[last.month - 1]}';
  }

  bool isBefore(BudgetMonth other) => compareTo(other) < 0;
  bool isAfter(BudgetMonth other) => compareTo(other) > 0;

  @override
  int compareTo(BudgetMonth other) => (year * 12 + month) - (other.year * 12 + other.month);

  @override
  bool operator ==(Object other) =>
      other is BudgetMonth && other.year == year && other.month == month && other.startDay == startDay;

  @override
  int get hashCode => Object.hash(year, month, startDay);

  @override
  String toString() => 'BudgetMonth($label, starts on day $startDay)';
}
