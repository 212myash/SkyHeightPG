import 'package:flutter_test/flutter_test.dart';
import 'package:sky_height_pg/core/utils/currency_formatter.dart';

void main() {
  group('Application Recovery & Consistency Tests', () {
    test('Cumulative arrears calculation sums across multiple unpaid bills', () {
      final bills = [
        {'billingMonth': '2026-10', 'totalAmount': 6000, 'paidAmount': 0, 'paymentStatus': 'pending'},
        {'billingMonth': '2026-11', 'totalAmount': 6850, 'paidAmount': 0, 'paymentStatus': 'pending'},
        {'billingMonth': '2026-09', 'totalAmount': 5500, 'paidAmount': 5500, 'paymentStatus': 'paid'},
      ];

      num totalArrears = 0;
      for (final b in bills) {
        final bStatus = (b['paymentStatus'] ?? '').toString().toLowerCase();
        if (bStatus != 'paid') {
          final tot = (b['totalAmount'] as num?) ?? 0;
          final pd = (b['paidAmount'] as num?) ?? 0;
          totalArrears += (tot - pd).clamp(0, double.infinity);
        }
      }

      expect(totalArrears, 12850);
      expect(CurrencyFormatter.format(totalArrears), '₹12,850');
    });

    test('Arrears calculation handles fully paid bills accurately', () {
      final bills = [
        {'billingMonth': '2026-11', 'totalAmount': 6850, 'paidAmount': 6850, 'paymentStatus': 'paid'},
      ];

      num totalArrears = 0;
      for (final b in bills) {
        final bStatus = (b['paymentStatus'] ?? '').toString().toLowerCase();
        if (bStatus != 'paid') {
          final tot = (b['totalAmount'] as num?) ?? 0;
          final pd = (b['paidAmount'] as num?) ?? 0;
          totalArrears += (tot - pd).clamp(0, double.infinity);
        }
      }

      expect(totalArrears, 0);
    });

    test('Arrears calculation correctly handles partial payments', () {
      final bills = [
        {'billingMonth': '2026-11', 'totalAmount': 7000, 'paidAmount': 3000, 'paymentStatus': 'partially_paid'},
      ];

      num totalArrears = 0;
      for (final b in bills) {
        final bStatus = (b['paymentStatus'] ?? '').toString().toLowerCase();
        if (bStatus != 'paid') {
          final tot = (b['totalAmount'] as num?) ?? 0;
          final pd = (b['paidAmount'] as num?) ?? 0;
          totalArrears += (tot - pd).clamp(0, double.infinity);
        }
      }

      expect(totalArrears, 4000);
      expect(CurrencyFormatter.format(totalArrears), '₹4,000');
    });
  });
}
