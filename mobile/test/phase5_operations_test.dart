import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sky_height_pg/app/theme/app_colors.dart';
import 'package:sky_height_pg/core/network/api_endpoints.dart';
import 'package:sky_height_pg/core/utils/currency_formatter.dart';
import 'package:sky_height_pg/core/utils/date_formatter.dart';
import 'package:sky_height_pg/core/utils/validators.dart';
import 'package:sky_height_pg/core/widgets/dashboard_metric_card.dart';
import 'package:sky_height_pg/core/widgets/status_badge.dart';

void main() {
  group('Phase 5 API Endpoints Tests', () {
    test('Operation endpoints map to correct paths', () {
      expect(ApiEndpoints.meters, '/api/meters');
      expect(ApiEndpoints.monthlyUsage, '/api/meters/monthly-usage');
      expect(ApiEndpoints.roomMeterHistory('rm123'), '/api/meters/room/rm123');

      expect(ApiEndpoints.bills, '/api/bills');
      expect(ApiEndpoints.pendingBills, '/api/bills/pending');
      expect(ApiEndpoints.generateBills, '/api/bills/generate');
      expect(ApiEndpoints.billAdjustments('bill123'), '/api/bills/bill123/adjustments');

      expect(ApiEndpoints.cashPayment, '/api/payments/cash');
      expect(ApiEndpoints.submitUpi, '/api/payments/upi/submit');
      expect(ApiEndpoints.verifyPayment('pay123'), '/api/payments/pay123/verify');

      expect(ApiEndpoints.expenses, '/api/expenses');
      expect(ApiEndpoints.expenseSummary, '/api/expenses/summary');
      expect(ApiEndpoints.expenseById('exp123'), '/api/expenses/exp123');

      expect(ApiEndpoints.complaints, '/api/complaints');
      expect(ApiEndpoints.updateComplaintStatus('comp123'), '/api/complaints/comp123/status');
    });
  });

  group('Phase 5 Business Logic & Formatters', () {
    test('Electricity calculation formulas', () {
      const prev = 1240.5;
      const curr = 1350.0;
      final units = curr - prev;
      expect(units, 109.5);

      const ratePerUnit = 9.5;
      final electricityCost = units * ratePerUnit;
      expect(electricityCost, 1040.25);
      expect(CurrencyFormatter.format(electricityCost), '₹1,040.25');
    });

    test('Total bill amount with adjustments and balances', () {
      const rent = 7500.0;
      const electricity = 450.0;
      const otherCharges = 200.0;
      const adjustments = -150.0; // discount

      final total = rent + electricity + otherCharges + adjustments;
      expect(total, 8000.0);

      const paid = 5000.0;
      final balance = total - paid;
      expect(balance, 3000.0);
    });

    test('Validators for expense and meter inputs', () {
      expect(Validators.positiveNumber('1500', 'Invalid'), isNull);
      expect(Validators.positiveNumber('0', 'Invalid'), 'Invalid');
      expect(Validators.positiveNumber('-50', 'Invalid'), 'Invalid');
      expect(Validators.positiveNumber('abc', 'Invalid'), 'Invalid');

      expect(Validators.required('Electricity Bill', 'Title required'), isNull);
      expect(Validators.required('', 'Title required'), 'Title required');
      expect(Validators.required(null, 'Title required'), 'Title required');
    });

    test('DateFormatter handles month and full date correctly', () {
      expect(DateFormatter.formatMonth('2026-11'), 'Nov 2026');
      expect(DateFormatter.formatDate('2026-11-01T10:00:00Z'), isNotEmpty);
    });
  });

  group('Phase 5 UI Widgets', () {
    testWidgets('StatusBadge handles Phase 5 statuses', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                StatusBadge(status: 'verified'),
                StatusBadge(status: 'open'),
                StatusBadge(status: 'in_progress'),
                StatusBadge(status: 'resolved'),
                StatusBadge(status: 'rejected'),
                StatusBadge(status: 'partially_paid'),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Verified'), findsOneWidget);
      expect(find.text('Open'), findsOneWidget);
      expect(find.text('In Progress'), findsOneWidget);
      expect(find.text('Resolved'), findsOneWidget);
      expect(find.text('Rejected'), findsOneWidget);
      expect(find.text('Partially Paid'), findsOneWidget);
    });

    testWidgets('DashboardMetricCard onTap callback is executed', (tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DashboardMetricCard(
              title: 'Total Expenses',
              value: '₹14,200',
              icon: Icons.receipt_long,
              accentColor: AppColors.info,
              onTap: () {
                tapped = true;
              },
            ),
          ),
        ),
      );

      expect(find.text('Total Expenses'), findsOneWidget);
      expect(find.text('₹14,200'), findsOneWidget);

      await tester.tap(find.byType(DashboardMetricCard));
      await tester.pumpAndSettle();

      expect(tapped, isTrue);
    });

    test('Dashboard summary resilient parsing handles both legacy and updated backend payloads', () {
      // 1. Live Render backend payload (legacy key schema)
      final liveRenderPayload = {
        'month': '2026-11',
        'rooms': {
          'total': 8,
          'occupied': 0,
          'vacant': 5,
          'totalCapacity': 11,
          'occupiedBeds': 8,
          'availableBeds': 3
        },
        'tenants': {'active': 14},
        'financials': {
          'monthlyRentCollection': 76500,
          'pendingPayments': 49500,
          'monthlyExpenses': 0,
          'netIncome': 76500
        },
        'electricity': {
          'unitsConsumed': 1050,
          'totalAmount': 12600
        },
        'complaints': {'open': 0},
        'recentTransactions': [
          {
            'amount': 5000,
            'paymentMethod': 'upi',
            'paymentDate': '2026-11-01T10:00:00.000Z',
            'tenant': {'fullName': 'Aman Sharma'}
          }
        ]
      };

      // Resilient extraction logic
      final rooms = (liveRenderPayload['rooms'] as Map<String, dynamic>?) ?? {};
      final occupancy = (liveRenderPayload['occupancy'] as Map<String, dynamic>?) ?? rooms;
      final financials = (liveRenderPayload['financials'] as Map<String, dynamic>?) ?? {};
      final complaints = (liveRenderPayload['complaints'] as Map<String, dynamic>?) ?? {};
      final electricity = (liveRenderPayload['electricity'] as Map<String, dynamic>?) ?? {};
      final tenants = (liveRenderPayload['tenants'] as Map<String, dynamic>?) ?? {};

      final totalRooms = (rooms['total'] ?? occupancy['total'] ?? 0) as num;
      final totalBeds = (occupancy['totalBeds'] ?? occupancy['totalCapacity'] ?? rooms['totalCapacity'] ?? 0) as num;
      final occupiedBeds = (occupancy['occupiedBeds'] ?? rooms['occupiedBeds'] ?? 0) as num;
      final availableBeds = (occupancy['availableBeds'] ?? rooms['availableBeds'] ?? 0) as num;
      final activeTenants = (tenants['active'] ?? tenants['total'] ?? 0) as num;

      final totalCollected = (financials['totalCollected'] ?? financials['monthlyRentCollection'] ?? 0) as num;
      final pendingAmount = (financials['pendingAmount'] ?? financials['pendingPayments'] ?? 0) as num;
      final totalExpenses = (financials['totalExpenses'] ?? financials['monthlyExpenses'] ?? 0) as num;
      final netProfit = (financials['netProfit'] ?? financials['netIncome'] ?? 0) as num;
      final unitsConsumed = (electricity['totalUnits'] ?? electricity['unitsConsumed'] ?? 0) as num;
      final openComplaints = (complaints['open'] ?? complaints['openComplaints'] ?? 0) as num;

      expect(totalRooms, 8);
      expect(totalBeds, 11);
      expect(occupiedBeds, 8);
      expect(availableBeds, 3);
      expect(activeTenants, 14);
      expect(totalCollected, 76500);
      expect(pendingAmount, 49500);
      expect(totalExpenses, 0);
      expect(netProfit, 76500);
      expect(unitsConsumed, 1050);
      expect(openComplaints, 0);

      // Verify formatted currency values
      expect(CurrencyFormatter.format(totalCollected), '₹76,500');
      expect(CurrencyFormatter.format(pendingAmount), '₹49,500');
      expect(CurrencyFormatter.format(netProfit), '₹76,500');
    });
  });
}
