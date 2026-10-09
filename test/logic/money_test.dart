import 'package:flutter_test/flutter_test.dart';
import 'package:student_budget/logic/money.dart';

/// Replaces the non-breaking space after the euro sign with a normal space
/// so the expectations are easy to read.
String plain(String s) => s.replaceAll(' ', ' ');

void main() {
  group('formatEuro', () {
    test('whole amounts have no cents', () {
      expect(plain(formatEuro(125000)), '€ 1.250');
      expect(plain(formatEuro(450000)), '€ 4.500');
      expect(plain(formatEuro(100000000)), '€ 1.000.000');
      expect(plain(formatEuro(14300)), '€ 143');
      expect(plain(formatEuro(0)), '€ 0');
    });

    test('cents use a comma', () {
      expect(plain(formatEuro(8550)), '€ 85,50');
      expect(plain(formatEuro(1205)), '€ 12,05');
      expect(plain(formatEuro(125005)), '€ 1.250,05');
      expect(plain(formatEuro(1)), '€ 0,01');
    });

    test('negatives', () {
      expect(plain(formatEuro(-32000)), '-€ 320');
      expect(plain(formatEuro(-8550)), '-€ 85,50');
      expect(plain(formatEuro(-125000)), '-€ 1.250');
    });

    test('options', () {
      expect(plain(formatEuro(8500, alwaysShowCents: true)), '€ 85,00');
      expect(plain(formatEuro(8599, wholeEuros: true)), '€ 85');
      expect(plain(formatEuro(-8599, wholeEuros: true)), '-€ 85');
    });

    test('a non-breaking space follows the euro sign', () {
      expect(formatEuro(125000), '€ 1.250');
    });

    test('three-digit amounts are not grouped', () {
      expect(groupThousands(999), '999');
      expect(groupThousands(1000), '1.000');
    });

    test('field and CSV formats', () {
      expect(formatAmountForField(8550), '85,50');
      expect(formatAmountForField(120000), '1200');
      expect(formatAmountForField(0), '');
      expect(formatAmountForCsv(8550), '85,50');
      expect(formatAmountForCsv(-5), '-0,05');
    });
  });

  group('parseAmount', () {
    test('a comma is the decimal separator', () {
      expect(parseAmount('85,50').cents, 8550);
      expect(parseAmount('85,5').cents, 8550);
      expect(parseAmount(',5').cents, 50);
    });

    test('points group thousands', () {
      expect(parseAmount('1.250').cents, 125000);
      expect(parseAmount('1.250,50').cents, 125050);
      expect(parseAmount('250.000').cents, 25000000);
      expect(parseAmount('1.250.000').cents, 125000000);
    });

    test('a point with one or two digits after it is read as cents', () {
      expect(parseAmount('85.50').cents, 8550);
      expect(parseAmount('85.5').cents, 8550);
    });

    test('accepts spaces, a euro sign or EUR', () {
      expect(parseAmount('1 250').cents, 125000);
      expect(parseAmount('€85').cents, 8500);
      expect(parseAmount('€ 1.250,50').cents, 125050);
      expect(parseAmount(' eur 12 ').cents, 1200);
    });

    test('rejects zero, empty and negative-looking input', () {
      expect(parseAmount('').error, 'Enter an amount above € 0');
      expect(parseAmount('0').error, 'Enter an amount above € 0');
      expect(parseAmount('0,00').error, 'Enter an amount above € 0');
      expect(parseAmount('-5').isValid, isFalse);
      expect(parseAmount('abc').error, 'Enter a number, like 85,50');
    });

    test('rejects badly grouped or over-precise amounts', () {
      expect(parseAmount('85,505').error, 'Use at most 2 decimals, like 85,50');
      expect(parseAmount('1,2,3').error, 'Use one comma for cents, like 85,50');
      expect(parseAmount('12.50,00').error, 'Write thousands like 1.250,50');
      expect(parseAmount('1.25.000').error, 'Write thousands like 1.250,50');
    });

    test('upper limit is € 10.000.000', () {
      expect(parseAmount('10000000').cents, 1000000000);
      expect(parseAmount('10.000.000').cents, 1000000000);
      expect(parseAmount('10000000,01').isValid, isFalse);
      expect(parseAmount('99999999999').isValid, isFalse);
    });

    test('budget fields may be empty or zero', () {
      expect(parseAmount('', allowZero: true).cents, 0);
      expect(parseAmount('0', allowZero: true).cents, 0);
    });
  });

  test('ceilToWholeEuro', () {
    expect(ceilToWholeEuro(5001), 5100);
    expect(ceilToWholeEuro(5000), 5000);
    expect(ceilToWholeEuro(0), 0);
    expect(ceilToWholeEuro(-10), 0);
  });
}
