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
import '../../auth/providers/auth_provider.dart';

class OwnerDashboardScreen extends ConsumerStatefulWidget {
  const OwnerDashboardScreen({super.key});

  @override
  ConsumerState<OwnerDashboardScreen> createState() => _OwnerDashboardScreenState();
}

class _OwnerDashboardScreenState extends ConsumerState<OwnerDashboardScreen> {
  bool _isLoading = true;
  String? _error;
  Map<String, dynamic>? _summaryData;

  @override
  void initState() {
    super.initState();
    _fetchSummary();
  }

  Future<void> _fetchSummary() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final api = ref.read(apiClientProvider);
      final response = await api.get(ApiEndpoints.dashboardSummary);
      if (mounted) {
        if (response.data != null && response.data['success'] == true) {
          setState(() {
            _summaryData = response.data['data'] as Map<String, dynamic>? ?? {};
            _isLoading = false;
          });
        } else {
          setState(() {
            _error = response.data?['message'] ?? 'Failed to load dashboard summary';
            _isLoading = false;
          });
        }
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
            Text(
              'Sky Height PG',
              style: AppTextStyles.h2.copyWith(fontSize: 18),
            ),
            Text(
              user != null ? 'Hello, ${user.name}' : 'Owner Portal',
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _fetchSummary,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: AppLoader(text: 'Loading overview...'));
    }

    if (_error != null) {
      return ErrorStateView(
        message: _error!,
        onRetry: _fetchSummary,
      );
    }

    final occupancy = _summaryData?['occupancy'] as Map<String, dynamic>? ?? {};
    final financials = _summaryData?['financials'] as Map<String, dynamic>? ?? {};
    final complaints = _summaryData?['complaints'] as Map<String, dynamic>? ?? {};
    final electricity = _summaryData?['electricity'] as Map<String, dynamic>? ?? {};

    final totalBeds = (occupancy['totalBeds'] ?? 0) as num;
    final occupiedBeds = (occupancy['occupiedBeds'] ?? 0) as num;
    final availableBeds = (occupancy['availableBeds'] ?? 0) as num;
    final occupancyRate = totalBeds > 0 ? ((occupiedBeds / totalBeds) * 100).toStringAsFixed(1) : '0';

    final totalCollected = (financials['totalCollected'] ?? 0) as num;
    final pendingAmount = (financials['pendingAmount'] ?? 0) as num;
    final totalExpenses = (financials['totalExpenses'] ?? 0) as num;
    final netProfit = (financials['netProfit'] ?? 0) as num;

    final openComplaints = (complaints['open'] ?? 0) as num;
    final unitsConsumed = (electricity['totalUnits'] ?? 0) as num;

    return RefreshIndicator(
      onRefresh: _fetchSummary,
      color: AppColors.primary,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        children: [
          // Occupancy Banner Card
          AppCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Occupancy Status', style: AppTextStyles.h3),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '$occupancyRate% Occupied',
                        style: AppTextStyles.badge.copyWith(color: AppColors.primary),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: totalBeds > 0 ? (occupiedBeds / totalBeds).clamp(0.0, 1.0) : 0.0,
                    minHeight: 8,
                    backgroundColor: AppColors.border,
                    valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildStatCol('Total Beds', '$totalBeds', AppColors.textPrimary),
                    _buildStatCol('Occupied', '$occupiedBeds', AppColors.primary),
                    _buildStatCol('Available', '$availableBeds', AppColors.success),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Section Title
          Text('Financial Overview', style: AppTextStyles.h3),
          const SizedBox(height: 12),

          // Financial Metrics Grid
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.35,
            children: [
              DashboardMetricCard(
                title: 'Total Collected',
                value: CurrencyFormatter.format(totalCollected),
                icon: Icons.account_balance_wallet_outlined,
                accentColor: AppColors.success,
              ),
              DashboardMetricCard(
                title: 'Pending Dues',
                value: CurrencyFormatter.format(pendingAmount),
                icon: Icons.pending_actions_outlined,
                accentColor: AppColors.warning,
              ),
              DashboardMetricCard(
                title: 'Total Expenses',
                value: CurrencyFormatter.format(totalExpenses),
                icon: Icons.receipt_long_outlined,
                accentColor: AppColors.info,
              ),
              DashboardMetricCard(
                title: 'Net Profit',
                value: CurrencyFormatter.format(netProfit),
                icon: Icons.trending_up_rounded,
                accentColor: netProfit >= 0 ? AppColors.success : AppColors.error,
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Operations Overview
          Text('Operations & Utility', style: AppTextStyles.h3),
          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: DashboardMetricCard(
                  title: 'Electricity Usage',
                  value: '$unitsConsumed Units',
                  icon: Icons.bolt_rounded,
                  accentColor: Colors.amber.shade700,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DashboardMetricCard(
                  title: 'Open Complaints',
                  value: '$openComplaints Open',
                  icon: Icons.report_problem_outlined,
                  accentColor: openComplaints > 0 ? AppColors.error : AppColors.success,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildStatCol(String title, String val, Color color) {
    return Column(
      children: [
        Text(val, style: AppTextStyles.h2.copyWith(color: color)),
        const SizedBox(height: 2),
        Text(title, style: AppTextStyles.bodySmall),
      ],
    );
  }
}
