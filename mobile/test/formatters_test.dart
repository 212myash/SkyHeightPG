import 'package:flutter_test/flutter_test.dart';
import 'package:sky_height_pg/core/utils/currency_formatter.dart';
import 'package:sky_height_pg/core/utils/date_formatter.dart';

void main() {
  group('Formatters Unit Tests', () {
    test('CurrencyFormatter formats INR correctly', () {
      expect(CurrencyFormatter.format(0), '₹0');
      expect(CurrencyFormatter.format(500), '₹500');
      expect(CurrencyFormatter.format(8500), '₹8,500');
      expect(CurrencyFormatter.format(100000), '₹1,00,000');
      expect(CurrencyFormatter.format(null), '₹0');
    });

    test('DateFormatter formats dates and months correctly', () {
      final date = DateTime(2026, 11, 1);
      final formatted = DateFormatter.formatDate(date);
      expect(formatted, contains('Nov'));
      expect(formatted, contains('2026'));

      final month = DateFormatter.formatMonth('2026-11');
      expect(month, 'Nov 2026');
    });
  });
}
