import 'dates.dart';

/// Validation rules shared by forms and the backup reader.
class Validation {
  const Validation._();

  static const int maxNoteLength = 60;
  static const int maxNameLength = 40;
  static final DateTime earliestDate = DateTime.utc(2020, 1, 1);

  /// Latest allowed transaction date: one year after [today].
  static DateTime latestDate(DateTime today) {
    final t = dateOnly(today);
    return DateTime.utc(t.year + 1, t.month, t.day);
  }

  /// Error message or null.
  static String? date(DateTime value, DateTime today) {
    final d = dateOnly(value);
    if (d.isBefore(earliestDate)) return 'Pick a date from 1 Jan 2020 onwards';
    if (d.isAfter(latestDate(today))) return 'Pick a date no more than a year ahead';
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
