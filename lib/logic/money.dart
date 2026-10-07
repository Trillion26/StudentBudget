/// Rand formatting and parsing. Amounts are always whole cents in an [int].
library;

/// Non-breaking space used as the thousands separator, so "R1 250" never
/// wraps onto two lines at large text sizes.
const String thousandsSeparator = ' ';

/// The largest amount a single entry may have: R10 000 000.
const int maxAmountCents = 10000000 * 100;

/// Formats [cents] as South African rand.
///
/// * `125000` → `R1 250` (no cents when the amount is whole)
/// * `8550` → `R85,50`
/// * `-32000` → `-R320`
///
/// Set [alwaysShowCents] to show `,00` on whole amounts (used in amount
/// fields). Set [wholeRand] to drop the cents entirely (rounded down for
/// positive amounts, towards zero for negative ones).
String formatRand(int cents, {bool alwaysShowCents = false, bool wholeRand = false}) {
  final negative = cents < 0;
  var abs = cents.abs();
  if (wholeRand) abs = abs - abs % 100;
  final rands = abs ~/ 100;
  final rem = abs % 100;
  final buffer = StringBuffer();
  if (negative && abs != 0) buffer.write('-');
  buffer.write('R');
  buffer.write(groupThousands(rands));
  if (rem != 0 || alwaysShowCents) {
    buffer.write(',');
    buffer.write(rem.toString().padLeft(2, '0'));
  }
  return buffer.toString();
}

/// Groups digits in threes with a non-breaking space: 1250 → "1 250".
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
  final rands = cents ~/ 100;
  final rem = cents % 100;
  return rem == 0 ? '$rands' : '$rands,${rem.toString().padLeft(2, '0')}';
}

/// Formats cents for CSV export: `8550` → `85.50` (a point, no grouping).
String formatAmountForCsv(int cents) {
  final negative = cents < 0;
  final abs = cents.abs();
  return '${negative ? '-' : ''}${abs ~/ 100}.${(abs % 100).toString().padLeft(2, '0')}';
}

/// The result of reading an amount the student typed.
class AmountParseResult {
  const AmountParseResult.ok(int this.cents) : error = null;
  const AmountParseResult.error(String this.error) : cents = null;

  final int? cents;
  final String? error;

  bool get isValid => cents != null;
}

/// Reads an amount typed by the student. Accepts a comma or a point for
/// cents ("85,50", "85.50"), spaces as thousands separators ("1 250") and an
/// optional leading "R".
///
/// When [allowZero] is true, an empty field or 0 is accepted (used for
/// budget fields); otherwise the amount must be above R0.
AmountParseResult parseAmount(String input, {bool allowZero = false}) {
  var text = input.trim().replaceAll(RegExp(r'[\s  ]'), '');
  if (text.startsWith('R') || text.startsWith('r')) text = text.substring(1);
  if (text.isEmpty) {
    return allowZero
        ? const AmountParseResult.ok(0)
        : const AmountParseResult.error('Enter an amount above R0');
  }
  if (!RegExp(r'^[0-9.,]+$').hasMatch(text)) {
    return const AmountParseResult.error('Enter a number, like 85,50');
  }
  final separators = RegExp(r'[.,]').allMatches(text).length;
  if (separators > 1) {
    return const AmountParseResult.error('Use one comma or point for cents, like 85,50');
  }
  final parts = text.split(RegExp(r'[.,]'));
  final wholePart = parts[0].isEmpty ? '0' : parts[0];
  final centsPart = parts.length > 1 ? parts[1] : '';
  if (centsPart.length > 2) {
    return const AmountParseResult.error('Use at most 2 decimals, like 85,50');
  }
  if (wholePart.length > 9) {
    return const AmountParseResult.error('Enter an amount up to R10 000 000');
  }
  final cents = int.parse(wholePart) * 100 + (centsPart.isEmpty ? 0 : int.parse(centsPart.padRight(2, '0')));
  if (cents <= 0 && !allowZero) {
    return const AmountParseResult.error('Enter an amount above R0');
  }
  if (cents > maxAmountCents) {
    return const AmountParseResult.error('Enter an amount up to R10 000 000');
  }
  return AmountParseResult.ok(cents);
}

/// Rounds a positive amount up to the next whole rand (zero stays zero,
/// negative amounts become zero).
int ceilToWholeRand(int cents) => cents <= 0 ? 0 : ((cents + 99) ~/ 100) * 100;
