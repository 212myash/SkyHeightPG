import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_loader.dart';
import '../../../core/widgets/dashboard_metric_card.dart';
import '../../../core/widgets/error_state_view.dart';
import '../../../core/widgets/status_badge.dart';
import '../../auth/providers/auth_provider.dart';

class TenantDashboardScreen extends ConsumerStatefulWidget {
  const TenantDashboardScreen({super.key});

  @override
  ConsumerState<TenantDashboardScreen> createState() => _TenantDashboardScreenState();
}

class _TenantDashboardScreenState extends ConsumerState<TenantDashboardScreen> {
  bool _isLoading = true;
  String? _error;
  Map<String, dynamic>? _tenantData;
  Map<String, dynamic>? _latestBill;
  Map<String, dynamic>? _latestMeter;

  @override
  void initState() {
    super.initState();
    _fetchTenantDashboard();
  }

  Future<void> _fetchTenantDashboard() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final api = ref.read(apiClientProvider);

      final results = await Future.wait([
        api.get(ApiEndpoints.myTenantProfile).then((r) => r.data).catchError((_) => null),
        api.get(ApiEndpoints.myBills).then((r) => r.data).catchError((_) => null),
        api.get(ApiEndpoints.myMeter).then((r) => r.data).catchError((_) => null),
      ]);

      if (mounted) {
        final profileRes = results[0];
        final billsRes = results[1];
        final meterRes = results[2];

        if (profileRes != null && profileRes['success'] == true) {
          _tenantData = profileRes['data'] as Map<String, dynamic>?;
        }

        if (billsRes != null && billsRes['success'] == true) {
          final bills = billsRes['data'] as List<dynamic>? ?? [];
          if (bills.isNotEmpty) {
            _latestBill = bills.first as Map<String, dynamic>?;
          }
        }

        if (meterRes != null && meterRes['success'] == true) {
          _latestMeter = meterRes['data'] as Map<String, dynamic>?;
        }

        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Sky Height PG', style: AppTextStyles.h2.copyWith(fontSize: 18)),
            Text(
              user != null ? 'Welcome, ${user.name}' : 'Tenant Portal',
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _fetchTenantDashboard,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: AppLoader(text: 'Loading your dashboard...'));
    }

    if (_error != null) {
      return ErrorStateView(message: _error!, onRetry: _fetchTenantDashboard);
    }

    final tenant = _tenantData;
    if (tenant == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Text(
            'Your tenant account is registered, but you have not yet been assigned to a room by the PG Owner.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final room = tenant['room'] is Map ? tenant['room'] as Map<String, dynamic> : null;
    final roomNum = room?['roomNumber'] ?? '-';
    final floor = room?['floor'] ?? '-';
    final bed = tenant['assignedBed'] ?? '-';
    final rent = tenant['monthlyRent'] ?? 0;
    final deposit = tenant['securityDeposit'] ?? 0;
    final status = (tenant['status'] ?? 'ACTIVE').toString();

    // Latest bill fields
    final billStatus = (_latestBill?['paymentStatus'] ?? 'NO_BILL').toString();
    final billMonth = _latestBill?['billingMonth'] ?? 'Current';
    final totalBill = _latestBill?['totalAmount'] ?? 0;
    final paidAmount = _latestBill?['paidAmount'] ?? 0;
    final pendingAmount = (totalBill - paidAmount).clamp(0, double.infinity);

    // Latest meter fields
    final unitsConsumed = _latestMeter?['unitsConsumed'] ?? 0;
    final currentReading = _latestMeter?['currentReading'] ?? 0;

    return RefreshIndicator(
      onRefresh: _fetchTenantDashboard,
      color: AppColors.primary,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        children: [
          // Room & Bed Header Card
          AppCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.primarySurface,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.meeting_room_rounded, color: AppColors.primary, size: 24),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Room $roomNum', style: AppTextStyles.h2),
                            Text('Floor $floor • Bed $bed', style: AppTextStyles.bodySmall),
                          ],
                        ),
                      ],
                    ),
                    StatusBadge(status: status),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(height: 1, color: AppColors.divider),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Monthly Rent', style: AppTextStyles.bodySmall),
                        Text(
                          CurrencyFormatter.format(rent),
                          style: AppTextStyles.labelLarge.copyWith(color: AppColors.primary),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('Security Deposit', style: AppTextStyles.bodySmall),
                        Text(
                          CurrencyFormatter.format(deposit),
                          style: AppTextStyles.labelLarge,
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Bill Status Card
          Text('Latest Bill Summary', style: AppTextStyles.h3),
          const SizedBox(height: 10),
          AppCard(
            padding: const EdgeInsets.all(20),
            child: _latestBill == null
                ? Row(
                    children: [
                      const Icon(Icons.check_circle_outline, color: AppColors.success, size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'No pending bill generated for this month.',
                          style: AppTextStyles.bodyMedium,
                        ),
                      ),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(billMonth, style: AppTextStyles.h3),
                          StatusBadge(status: billStatus),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Total Billed', style: AppTextStyles.bodySmall),
                              Text(CurrencyFormatter.format(totalBill), style: AppTextStyles.labelLarge),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text('Pending Due', style: AppTextStyles.bodySmall),
                              Text(
                                CurrencyFormatter.format(pendingAmount),
                                style: AppTextStyles.h3.copyWith(
                                  color: pendingAmount > 0 ? AppColors.error : AppColors.success,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: 20),

          // Utility & Sub-meter Card
          Text('Electricity Sub-Meter', style: AppTextStyles.h3),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: DashboardMetricCard(
                  title: 'Units Consumed',
                  value: '$unitsConsumed Units',
                  icon: Icons.bolt_rounded,
                  accentColor: Colors.amber.shade700,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DashboardMetricCard(
                  title: 'Latest Reading',
                  value: '$currentReading kWh',
                  icon: Icons.electric_meter_rounded,
                  accentColor: AppColors.info,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
