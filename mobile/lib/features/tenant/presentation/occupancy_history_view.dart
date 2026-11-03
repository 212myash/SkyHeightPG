import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/app_loader.dart';
import '../../../core/widgets/empty_state_view.dart';
import '../../../core/widgets/error_state_view.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/occupancy_history_model.dart';

class OccupancyHistorySheet extends ConsumerStatefulWidget {
  final String? tenantId;
  final String? tenantName;

  const OccupancyHistorySheet({
    super.key,
    this.tenantId,
    this.tenantName,
  });

  static Future<void> show(
    BuildContext context, {
    String? tenantId,
    String? tenantName,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => OccupancyHistorySheet(
          tenantId: tenantId,
          tenantName: tenantName,
        ),
      ),
    );
  }

  @override
  ConsumerState<OccupancyHistorySheet> createState() =>
      _OccupancyHistorySheetState();
}

class _OccupancyHistorySheetState extends ConsumerState<OccupancyHistorySheet> {
  bool _isLoading = true;
  String? _error;
  List<OccupancyHistoryItem> _history = [];
  Map<String, dynamic>? _tenantInfo;

  @override
  void initState() {
    super.initState();
    _fetchHistory();
  }

  Future<void> _fetchHistory() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final api = ref.read(apiClientProvider);
      final endpoint = widget.tenantId != null
          ? ApiEndpoints.tenantOccupancyHistory(widget.tenantId!)
          : ApiEndpoints.myOccupancyHistory;

      final res = await api.get(endpoint);

      if (mounted) {
        if (res.data != null && res.data['success'] == true) {
          final data = res.data['data'] as Map<String, dynamic>? ?? {};
          final list = (data['history'] as List<dynamic>? ?? [])
              .map((e) =>
                  OccupancyHistoryItem.fromJson(e as Map<String, dynamic>))
              .toList();

          setState(() {
            _tenantInfo = data['tenant'] as Map<String, dynamic>?;
            _history = list;
            _isLoading = false;
          });
        } else {
          setState(() {
            _error = res.data?['message'] ?? 'Failed to load occupancy history.';
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

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return AppColors.success;
      case 'transferred':
        return Colors.blue.shade700;
      case 'vacated':
        return Colors.grey.shade700;
      default:
        return AppColors.textSecondary;
    }
  }

  Color _getStatusBg(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return AppColors.successLight;
      case 'transferred':
        return Colors.blue.shade50;
      case 'vacated':
        return Colors.grey.shade100;
      default:
        return AppColors.background;
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayName = widget.tenantName ??
        _tenantInfo?['fullName'] ??
        'Occupancy Timeline';

    return Column(
      children: [
        // Modal Handle
        Center(
          child: Container(
            margin: const EdgeInsets.only(top: 10, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),

        // Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Occupancy History', style: AppTextStyles.h2),
                  Text(
                    displayName,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.refresh_rounded),
                onPressed: _fetchHistory,
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: AppColors.border),

        // Body
        Expanded(
          child: _isLoading
              ? const Center(child: AppLoader(text: 'Loading timeline...'))
              : _error != null
                  ? ErrorStateView(message: _error!, onRetry: _fetchHistory)
                  : _history.isEmpty
                      ? const EmptyStateView(
                          title: 'No Occupancy History',
                          description:
                              'No historical room records have been logged for this tenant yet.',
                          icon: Icons.history_rounded,
                        )
                      : RefreshIndicator(
                          onRefresh: _fetchHistory,
                          child: ListView.separated(
                            padding: const EdgeInsets.all(20),
                            itemCount: _history.length,
                            separatorBuilder: (context, index) =>
                                const SizedBox(height: 14),
                            itemBuilder: (context, index) {
                              final item = _history[index];
                              return _buildHistoryCard(item, index);
                            },
                          ),
                        ),
        ),
      ],
    );
  }

  Widget _buildHistoryCard(OccupancyHistoryItem item, int index) {
    final statusColor = _getStatusColor(item.occupancyStatus);
    final statusBg = _getStatusBg(item.occupancyStatus);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: item.isActive ? AppColors.primary : AppColors.border,
          width: item.isActive ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: Room Number + Status Badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: item.isActive
                            ? AppColors.primarySurface
                            : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.meeting_room_rounded,
                        color: item.isActive
                            ? AppColors.primary
                            : Colors.grey.shade600,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Room ${item.roomNumber}',
                          style: AppTextStyles.h3.copyWith(
                            color: item.isActive
                                ? AppColors.primary
                                : AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          item.durationString,
                          style: AppTextStyles.bodySmall.copyWith(
                            fontWeight: FontWeight.w600,
                            color: statusColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusBg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    item.occupancyStatus.toUpperCase(),
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Divider(height: 1, color: AppColors.divider),
            const SizedBox(height: 12),

            // Date Range
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Check-in Date', style: AppTextStyles.bodySmall),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(Icons.login_rounded,
                              size: 14, color: AppColors.textSecondary),
                          const SizedBox(width: 4),
                          Text(item.formattedJoiningDate,
                              style: AppTextStyles.labelMedium),
                        ],
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Check-out Date', style: AppTextStyles.bodySmall),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(
                            item.isActive
                                ? Icons.hourglass_top_rounded
                                : Icons.logout_rounded,
                            size: 14,
                            color: item.isActive
                                ? AppColors.success
                                : AppColors.textSecondary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            item.formattedLeavingDate,
                            style: AppTextStyles.labelMedium.copyWith(
                              color: item.isActive ? AppColors.success : null,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // Rent snapshot & reason if available
            if (item.monthlyRentSnapshot > 0 || item.reason.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (item.monthlyRentSnapshot > 0)
                      Text(
                        'Monthly Rent at Stay: ${CurrencyFormatter.format(item.monthlyRentSnapshot)}',
                        style: AppTextStyles.bodySmall.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    if (item.reason.isNotEmpty) ...[
                      if (item.monthlyRentSnapshot > 0)
                        const SizedBox(height: 4),
                      Text(
                        'Note: ${item.reason}',
                        style: AppTextStyles.bodySmall.copyWith(
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
