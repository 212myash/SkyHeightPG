import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/constants/app_assets.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
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
        title: Row(
          children: [
            const AppBrandLogo.symbol(height: 34),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sky Height Apartment',
                  style: AppTextStyles.h2.copyWith(fontSize: 17),
                ),
                Text(
                  user != null ? 'Hello, ${user.name}' : 'Owner Portal',
                  style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.how_to_reg_outlined),
            onPressed: () => context.push('/owner/registrations').then((_) => _fetchSummary()),
            tooltip: 'Registrations',
          ),
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () => context.push('/notifications'),
            tooltip: 'Notifications',
          ),
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline_rounded),
            onPressed: () => context.push('/chat'),
            tooltip: 'Messages & Groups',
          ),
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

    final rooms = (_summaryData?['rooms'] as Map<String, dynamic>?) ?? {};
    final occupancy = (_summaryData?['occupancy'] as Map<String, dynamic>?) ?? rooms;
    final financials = (_summaryData?['financials'] as Map<String, dynamic>?) ?? {};
    final complaints = (_summaryData?['complaints'] as Map<String, dynamic>?) ?? {};
    final electricity = (_summaryData?['electricity'] as Map<String, dynamic>?) ?? {};
    final tenants = (_summaryData?['tenants'] as Map<String, dynamic>?) ?? {};
    final recentTransactions = (_summaryData?['recentTransactions'] as List<dynamic>?) ?? [];

    final totalRooms = (rooms['total'] ?? occupancy['total'] ?? occupancy['totalRooms'] ?? 0) as num;
    final totalBeds = (occupancy['totalBeds'] ?? occupancy['totalCapacity'] ?? rooms['totalCapacity'] ?? 0) as num;
    final occupiedBeds = (occupancy['occupiedBeds'] ?? rooms['occupiedBeds'] ?? 0) as num;
    final availableBeds = (occupancy['availableBeds'] ?? rooms['availableBeds'] ?? 0) as num;
    final activeTenants = (tenants['active'] ?? tenants['total'] ?? 0) as num;

    final occupancyRate = totalBeds > 0
        ? ((occupiedBeds / totalBeds) * 100).toStringAsFixed(1)
        : (occupancy['occupancyRate']?.toString() ?? '0');

    final totalCollected = (financials['totalCollected'] ?? financials['monthlyRentCollection'] ?? 0) as num;
    final pendingAmount = (financials['pendingAmount'] ?? financials['pendingPayments'] ?? 0) as num;
    final totalExpenses = (financials['totalExpenses'] ?? financials['monthlyExpenses'] ?? 0) as num;
    final netProfit = (financials['netProfit'] ?? financials['netIncome'] ?? 0) as num;

    final openComplaints = (complaints['open'] ?? complaints['openComplaints'] ?? 0) as num;
    final unitsConsumed = (electricity['totalUnits'] ?? electricity['unitsConsumed'] ?? 0) as num;
    final electricityAmount = (electricity['totalAmount'] ?? 0) as num;

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
                    _buildStatCol('Rooms', '$totalRooms', AppColors.textPrimary),
                    _buildStatCol('Tenants', '$activeTenants', AppColors.info),
                    _buildStatCol('Capacity', '$totalBeds', AppColors.textSecondary),
                    _buildStatCol('Occupied', '$occupiedBeds', AppColors.primary),
                    _buildStatCol('Vacancies', '$availableBeds', AppColors.success),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Quick Management Actions
          Row(
            children: [
              Expanded(
                child: _buildActionTile(
                  icon: Icons.how_to_reg_rounded,
                  label: 'Approvals',
                  color: AppColors.primary,
                  onTap: () => context.push('/owner/registrations').then((_) => _fetchSummary()),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildActionTile(
                  icon: Icons.campaign_rounded,
                  label: 'Broadcast',
                  color: AppColors.info,
                  onTap: () => context.push('/notifications/create'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildActionTile(
                  icon: Icons.forum_rounded,
                  label: 'Messages',
                  color: AppColors.success,
                  onTap: () => context.push('/chat'),
                ),
              ),
            ],
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
                onTap: () => context.push('/owner/billing'),
              ),
              DashboardMetricCard(
                title: 'Pending Dues',
                value: CurrencyFormatter.format(pendingAmount),
                icon: Icons.pending_actions_outlined,
                accentColor: AppColors.warning,
                onTap: () => context.push('/owner/billing'),
              ),
              DashboardMetricCard(
                title: 'Total Expenses',
                value: CurrencyFormatter.format(totalExpenses),
                icon: Icons.receipt_long_outlined,
                accentColor: AppColors.info,
                onTap: () => context.push('/owner/expenses'),
              ),
              DashboardMetricCard(
                title: 'Net Profit',
                value: CurrencyFormatter.format(netProfit),
                icon: Icons.trending_up_rounded,
                accentColor: netProfit >= 0 ? AppColors.success : AppColors.error,
                onTap: () => context.push('/owner/expenses'),
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
                  subtitle: electricityAmount > 0 ? CurrencyFormatter.format(electricityAmount) : null,
                  icon: Icons.bolt_rounded,
                  accentColor: Colors.amber.shade700,
                  onTap: () => context.push('/owner/meter'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DashboardMetricCard(
                  title: 'Open Complaints',
                  value: '$openComplaints Open',
                  subtitle: openComplaints == 0 ? 'All resolved' : null,
                  icon: Icons.report_problem_outlined,
                  accentColor: openComplaints > 0 ? AppColors.error : AppColors.success,
                  onTap: () => context.push('/owner/complaints'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Recent Verified Payments Section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Recent Verified Payments', style: AppTextStyles.h3),
              TextButton(
                onPressed: () => context.push('/owner/payments'),
                child: const Text('View All'),
              ),
            ],
          ),
          const SizedBox(height: 8),

          if (recentTransactions.isEmpty)
            AppCard(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: Text(
                  'No recent payments found for this period.',
                  style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
                ),
              ),
            )
          else
            AppCard(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: recentTransactions.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final tx = recentTransactions[index] as Map<String, dynamic>? ?? {};
                  final tenantName = (tx['tenant'] is Map ? tx['tenant']['fullName'] : null) ?? 'Tenant';
                  final amount = (tx['amount'] ?? 0) as num;
                  final method = ((tx['paymentMethod'] ?? 'UPI') as String).toUpperCase();
                  final date = DateFormatter.formatDate(tx['paymentDate']);

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: AppColors.successLight,
                          child: Icon(
                            method == 'UPI' ? Icons.qr_code_2_rounded : Icons.payments_rounded,
                            size: 18,
                            color: AppColors.success,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                tenantName,
                                style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '$method • $date',
                                style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '+${CurrencyFormatter.format(amount)}',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.success,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
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
  Widget _buildActionTile({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.25)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: color.withValues(alpha: 0.12),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color),
            ),
          ],
        ),
      ),
    );
  }
}
