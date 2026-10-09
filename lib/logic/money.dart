/// Euro formatting and parsing, the Dutch way: `€ 1.250,50`. Amounts are
/// always whole cents in an [int].
library;

/// Non-breaking space between the euro sign and the number, so "€ 1.250"
/// never wraps onto two lines at large text sizes.
const String euroSign = '€\u00A0';

/// Thousands separator in Dutch amounts.
const String thousandsSeparator = '.';

/// The largest amount a single entry may have: € 10.000.000.
const int maxAmountCents = 10000000 * 100;

/// Formats [cents] as euros in the Dutch style.
///
/// * `125000` → `€ 1.250` (no cents when the amount is whole)
/// * `8550` → `€ 85,50`
/// * `-32000` → `-€ 320`
///
/// Set [alwaysShowCents] to show `,00` on whole amounts (used in amount
/// fields). Set [wholeEuros] to drop the cents entirely (rounded down for
/// positive amounts, towards zero for negative ones).
String formatEuro(int cents, {bool alwaysShowCents = false, bool wholeEuros = false}) {
  final negative = cents < 0;
  var abs = cents.abs();
  if (wholeEuros) abs = abs - abs % 100;
  final euros = abs ~/ 100;
  final rem = abs % 100;
  final buffer = StringBuffer();
  if (negative && abs != 0) buffer.write('-');
  buffer.write(euroSign);
  buffer.write(groupThousands(euros));
  if (rem != 0 || alwaysShowCents) {
    buffer.write(',');
    buffer.write(rem.toString().padLeft(2, '0'));
  }
  return buffer.toString();
}

/// Groups digits in threes with a point: 1250 → "1.250".
String groupThousands(int value) {
  final digits = value.abs().toString();
  final out = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) out.write(thousandsSeparator);
    out.write(digits[i]);
  }
  return (value < 0 ? '-' : '') + out.toString();
}

/// Formats cents as a plain number for an editable field: `8550` → `85,50`,
/// `120000` → `1200`. Empty for zero when [emptyForZero] is set.
String formatAmountForField(int cents, {bool emptyForZero = true}) {
  if (cents == 0 && emptyForZero) return '';
  final euros = cents ~/ 100;
  final rem = cents % 100;
  return rem == 0 ? '$euros' : '$euros,${rem.toString().padLeft(2, '0')}';
}

/// Formats cents for CSV export the way Dutch Excel reads it: `8550` →
/// `85,50` (a comma, no grouping).
String formatAmountForCsv(int cents) {
  final negative = cents < 0;
  final abs = cents.abs();
  return '${negative ? '-' : ''}${abs ~/ 100},${(abs % 100).toString().padLeft(2, '0')}';
}

/// The result of reading a typed amount.
class AmountParseResult {
  const AmountParseResult.ok(int this.cents) : error = null;
  const AmountParseResult.error(String this.error) : cents = null;

  final int? cents;
  final String? error;

  bool get isValid => cents != null;
}

/// Reads a typed amount, Dutch style first:
///
/// * a comma is the decimal separator: "85,50"
/// * points group thousands: "1.250" and "1.250,50"
/// * a single point followed by 1 or 2 digits is read as decimals too, so
///   "85.50" works for people who type it the English way
/// * spaces and a leading "€" or "EUR" are ignored
///
/// When [allowZero] is true, an empty field or 0 is accepted (used for
/// budget fields); otherwise the amount must be above € 0.
AmountParseResult parseAmount(String input, {bool allowZero = false}) {
  var text = input.trim().replaceAll(RegExp('[\\s\u00A0\u202F]'), '');
  final lower = text.toLowerCase();
  if (lower.startsWith('eur')) {
    text = text.substring(3);
  } else if (text.startsWith('€')) {
    text = text.substring(1);
  }
  if (text.isEmpty) {
    return allowZero ? const AmountParseResult.ok(0) : const AmountParseResult.error('Enter an amount above € 0');
  }
  if (!RegExp(r'^[0-9.,]+$').hasMatch(text)) {
    return const AmountParseResult.error('Enter a number, like 85,50');
  }

  String wholePart;
  String centsPart;
  final commas = ','.allMatches(text).length;
  if (commas > 1) {
    return const AmountParseResult.error('Use one comma for cents, like 85,50');
  }
  if (commas == 1) {
    // "1.250,50": points before the comma group thousands.
    final parts = text.split(',');
    if (!_validGrouping(parts[0])) {
      return const AmountParseResult.error('Write thousands like 1.250,50');
    }
    wholePart = parts[0].replaceAll('.', '');
    centsPart = parts[1];
  } else {
    final points = '.'.allMatches(text).length;
    final lastGroup = text.contains('.') ? text.substring(text.lastIndexOf('.') + 1) : '';
    if (points == 1 && lastGroup.length <= 2) {
      // "85.50", typed the English way.
      final parts = text.split('.');
      wholePart = parts[0];
      centsPart = parts[1];
    } else {
      if (!_validGrouping(text)) {
        return const AmountParseResult.error('Write thousands like 1.250,50');
      }
      wholePart = text.replaceAll('.', '');
      centsPart = '';
    }
  }
  if (wholePart.isEmpty) wholePart = '0';
  if (centsPart.length > 2) {
    return const AmountParseResult.error('Use at most 2 decimals, like 85,50');
  }
  if (wholePart.length > 9) {
    return const AmountParseResult.error('Enter an amount up to € 10.000.000');
  }
  final cents = int.parse(wholePart) * 100 + (centsPart.isEmpty ? 0 : int.parse(centsPart.padRight(2, '0')));
  if (cents <= 0 && !allowZero) {
    return const AmountParseResult.error('Enter an amount above € 0');
  }
  if (cents > maxAmountCents) {
    return const AmountParseResult.error('Enter an amount up to € 10.000.000');
  }
  return AmountParseResult.ok(cents);
}

/// True for "1250", "1.250" and "12.500.000"; false for "1.25" or "1..250".
bool _validGrouping(String whole) {
  if (!whole.contains('.')) return true;
  return RegExp(r'^[0-9]{1,3}(\.[0-9]{3})+$').hasMatch(whole);
}

/// Rounds a positive amount up to the next whole euro (zero stays zero,
/// negative amounts become zero).
int ceilToWholeEuro(int cents) => cents <= 0 ? 0 : ((cents + 99) ~/ 100) * 100;
