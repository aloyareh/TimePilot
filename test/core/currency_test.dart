import 'package:flutter_test/flutter_test.dart';
import 'package:time_pilot/core/currency/currency_service.dart';

void main() {
  const table = RateTable({
    'USD': 1.0,
    'IDR': 16000.0,
    'GBP': 0.8,
    'EUR': 0.9,
  });

  group('RateTable.convert', () {
    test('USD <-> IDR', () {
      expect(table.convert(1, 'USD', 'IDR'), 16000);
      expect(table.convert(16000, 'IDR', 'USD'), closeTo(1, 1e-9));
    });

    test('USD -> GBP', () {
      expect(table.convert(20, 'USD', 'GBP'), closeTo(16, 1e-9));
    });

    test('silang tanpa lewat IDR: GBP -> EUR', () {
      expect(table.convert(1, 'GBP', 'EUR'), closeTo(1.125, 1e-9));
    });

    test('mata uang tak dikenal melempar ArgumentError', () {
      expect(() => table.convert(1, 'USD', 'JPY'), throwsArgumentError);
    });
  });

  group('RateTable.fromJson', () {
    test('respons valid', () {
      final t = RateTable.fromJson({
        'result': 'success',
        'rates': {'IDR': 16500, 'GBP': 0.77, 'EUR': 0.91, 'JPY': 150},
      });
      expect(t.perUsd['USD'], 1.0);
      expect(t.perUsd['IDR'], 16500.0);
      expect(t.isFallback, isFalse);
    });

    test('kunci rates hilang melempar FormatException', () {
      expect(() => RateTable.fromJson({'x': 1}), throwsFormatException);
    });

    test('salah satu kurs hilang melempar FormatException', () {
      expect(
        () => RateTable.fromJson({'rates': {'IDR': 16500, 'GBP': 0.77}}),
        throwsFormatException,
      );
    });

    test('toJson lalu fromCache menghasilkan nilai sama', () {
      final at = DateTime.utc(2026, 10, 20, 1, 0);
      final t = RateTable.fromJson({
        'rates': {'IDR': 16500, 'GBP': 0.77, 'EUR': 0.91},
      }, fetchedAt: at);
      final back = RateTable.fromCache(t.toJson());
      expect(back.perUsd['IDR'], 16500.0);
      expect(back.fetchedAt, at);
    });
  });

  group('formatMoney', () {
    test('USD 2 desimal', () => expect(formatMoney(5, 'USD'), r'$5.00'));
    test('IDR titik ribuan, tanpa desimal', () {
      expect(formatMoney(16000, 'IDR'), 'Rp 16.000');
      expect(formatMoney(1234567.8, 'IDR'), 'Rp 1.234.568');
    });
    test('GBP koma ribuan', () => expect(formatMoney(1234.5, 'GBP'), '£1,234.50'));
    test('negatif', () => expect(formatMoney(-5, 'USD'), r'-$5.00'));
  });

  test('contoh late fee PBI-18: 15 menit x \$20/jam = \$5.00', () {
    final fee = 15 / 60 * 20;
    expect(formatMoney(fee, 'USD'), r'$5.00');
  });
}