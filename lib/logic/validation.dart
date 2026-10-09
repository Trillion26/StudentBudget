import 'dates.dart';

/// Validation rules shared by forms and the backup reader.
class Validation {
  const Validation._();

  static const int maxNoteLength = 60;
  static const int maxNameLength = 40;
  /// The app covers the years [firstYear] to [lastYear], both included.
  static const int firstYear = 2026;
  static const int lastYear = 2035;

  /// Every year the app covers, oldest first.
  static List<int> get years => [for (var y = firstYear; y <= lastYear; y++) y];

  /// Earliest allowed transaction date: 1 January of [firstYear].
  static final DateTime earliestDate = DateTime.utc(firstYear, 1, 1);

  /// Latest allowed transaction date: 31 December of [lastYear].
  static final DateTime latestDate = DateTime.utc(lastYear, 12, 31);

  /// Error message or null.
  static String? date(DateTime value) {
    final d = dateOnly(value);
    if (d.isBefore(earliestDate)) return 'Pick a date from 1 Jan $firstYear onwards';
    if (d.isAfter(latestDate)) return 'Pick a date up to 31 Dec $lastYear';
    return null;
  }

  /// Error message or null.
  static String? note(String value) =>
      value.length > maxNoteLength ? 'Keep the note to $maxNoteLength characters' : null;

  /// Category name: 1–40 characters and unique (ignoring case and spaces at
  /// the ends) among [existingNames].
  static String? categoryName(String value, Iterable<String> existingNames) {
    final name = value.trim();
    if (name.isEmpty) return 'Give the category a name';
    if (name.length > maxNameLength) return 'Keep the name to $maxNameLength characters';
    final lower = name.toLowerCase();
    if (existingNames.any((n) => n.trim().toLowerCase() == lower)) {
      return 'You already have a category called "$name"';
    }
    return null;
  }

  /// Group, goal or debt name: 1–40 characters.
  static String? name(String value, {String thing = 'it'}) {
    final name = value.trim();
    if (name.isEmpty) return 'Give $thing a name';
    if (name.length > maxNameLength) return 'Keep the name to $maxNameLength characters';
    return null;
  }

  /// Budget month start day: 1–28.
  static bool startDay(int value) => value >= 1 && value <= 28;
}
