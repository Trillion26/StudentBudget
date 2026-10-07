import 'package:flutter_test/flutter_test.dart';
import 'package:student_budget/logic/money.dart';

/// Replaces the non-breaking thousands separator with a normal space so the
/// expectations read like the brief.
String plain(String s) => s.replaceAll(thousandsSeparator, ' ');

void main() {
  group('formatRand', () {
    test('whole amounts have no cents', () {
      expect(plain(formatRand(125000)), 'R1 250');
      expect(plain(formatRand(450000)), 'R4 500');
      expect(plain(formatRand(100000000)), 'R1 000 000');
      expect(formatRand(14300), 'R143');
      expect(formatRand(0), 'R0');
    });

    test('cents use a comma', () {
      expect(formatRand(8550), 'R85,50');
      expect(formatRand(1205), 'R12,05');
      expect(plain(formatRand(125005)), 'R1 250,05');
      expect(formatRand(1), 'R0,01');
    });

    test('negatives', () {
      expect(formatRand(-32000), '-R320');
      expect(formatRand(-8550), '-R85,50');
      expect(plain(formatRand(-125000)), '-R1 250');
    });

    test('options', () {
      expect(formatRand(8500, alwaysShowCents: true), 'R85,00');
      expect(formatRand(8599, wholeRand: true), 'R85');
      expect(formatRand(-8599, wholeRand: true), '-R85');
    });

    test('uses a non-breaking space between thousands', () {
      expect(formatRand(125000), 'R1 250');
    });

    test('three-digit amounts are not grouped', () {
      expect(groupThousands(999), '999');
      expect(plain(groupThousands(1000)), '1 000');
    });

    test('field and CSV formats', () {
      expect(formatAmountForField(8550), '85,50');
      expect(formatAmountForField(120000), '1200');
      expect(formatAmountForField(0), '');
      expect(formatAmountForCsv(8550), '85.50');
      expect(formatAmountForCsv(-5), '-0.05');
    });
  });

  group('parseAmount', () {
    test('accepts a comma or a point for cents', () {
      expect(parseAmount('85,50').cents, 8550);
      expect(parseAmount('85.50').cents, 8550);
      expect(parseAmount('85,5').cents, 8550);
      expect(parseAmount(',5').cents, 50);
    });

    test('accepts spaces, an R and whole numbers', () {
      expect(parseAmount('1 250').cents, 125000);
      expect(parseAmount('R85').cents, 8500);
      expect(parseAmount(' r 12 ').cents, 1200);
    });

    test('rejects zero, empty and negative-looking input', () {
      expect(parseAmount('').error, 'Enter an amount above R0');
      expect(parseAmount('0').error, 'Enter an amount above R0');
      expect(parseAmount('0,00').error, 'Enter an amount above R0');
      expect(parseAmount('-5').isValid, isFalse);
      expect(parseAmount('abc').error, 'Enter a number, like 85,50');
    });

    test('at most 2 decimals and one separator', () {
      expect(parseAmount('85,505').error, 'Use at most 2 decimals, like 85,50');
      expect(parseAmount('1.250,50').isValid, isFalse);
    });

    test('upper limit is R10 000 000', () {
      expect(parseAmount('10000000').cents, 1000000000);
      expect(parseAmount('10000000,01').isValid, isFalse);
      expect(parseAmount('99999999999').isValid, isFalse);
    });

    test('budget fields may be empty or zero', () {
      expect(parseAmount('', allowZero: true).cents, 0);
      expect(parseAmount('0', allowZero: true).cents, 0);
    });
  });

  test('ceilToWholeRand', () {
    expect(ceilToWholeRand(5001), 5100);
    expect(ceilToWholeRand(5000), 5000);
    expect(ceilToWholeRand(0), 0);
    expect(ceilToWholeRand(-10), 0);
  });
}
