/// Date helpers. All app dates are calendar days with no time of day; they
/// are kept as UTC midnight so day arithmetic is never affected by
/// daylight-saving changes on the developer's computer.
library;

const List<String> monthNames = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];

const List<String> shortMonthNames = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

const List<String> weekdayNames = [
  'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday',
];

/// A calendar day (UTC midnight) from year, month and day. Month and day
/// may overflow, like [DateTime] (e.g. month 13 is January next year).
DateTime day(int year, int month, int dayOfMonth) => DateTime.utc(year, month, dayOfMonth);

/// The calendar day of [value], dropping the time and time zone.
DateTime dateOnly(DateTime value) => DateTime.utc(value.year, value.month, value.day);

/// Today's date on this device.
DateTime today() => dateOnly(DateTime.now());

/// Whole days from [from] to [to] (both calendar days).
int daysBetween(DateTime from, DateTime to) => dateOnly(to).difference(dateOnly(from)).inDays;

/// Number of whole calendar months from the month of [from] to the month
/// of [to] (ignores the day of month).
int monthsBetween(DateTime from, DateTime to) => (to.year * 12 + to.month) - (from.year * 12 + from.month);

/// `2026-10-04`
String isoDate(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

/// Reads `2026-10-04`; returns null when the text is not a real date.
DateTime? parseIsoDate(String text) {
  final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(text);
  if (match == null) return null;
  final y = int.parse(match[1]!), m = int.parse(match[2]!), d = int.parse(match[3]!);
  final value = DateTime.utc(y, m, d);
  if (value.year != y || value.month != m || value.day != d) return null;
  return value;
}

/// `4 Oct 2026`
String shortDate(DateTime value) => '${value.day} ${shortMonthNames[value.month - 1]} ${value.year}';

/// `Saturday 4 October`
String longDayLabel(DateTime value) =>
    '${weekdayNames[value.weekday - 1]} ${value.day} ${monthNames[value.month - 1]}';

/// `March 2027`
String monthYearLabel(DateTime value) => '${monthNames[value.month - 1]} ${value.year}';
