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
import '../../../core/widgets/app_dialog.dart';
import '../../../core/widgets/app_loader.dart';
import '../../../core/widgets/error_state_view.dart';
import '../../auth/providers/auth_provider.dart';
import 'occupancy_history_view.dart';

class TenantProfileScreen extends ConsumerStatefulWidget {
  const TenantProfileScreen({super.key});

  @override
  ConsumerState<TenantProfileScreen> createState() => _TenantProfileScreenState();
}

class _TenantProfileScreenState extends ConsumerState<TenantProfileScreen> {
  bool _isLoading = true;
  String? _error;
  Map<String, dynamic>? _tenant;

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final api = ref.read(apiClientProvider);
      final res = await api.get(ApiEndpoints.myTenantProfile);
      if (mounted) {
        if (res.data != null && res.data['success'] == true) {
          setState(() {
            _tenant = res.data['data'] as Map<String, dynamic>?;
            _isLoading = false;
          });
        } else {
          setState(() {
            _error = res.data?['message'] ?? 'Failed to load profile';
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
        title: const Text('My Profile & Stay'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _fetchProfile,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: AppLoader(text: 'Loading profile...'))
          : _error != null
              ? ErrorStateView(message: _error!, onRetry: _fetchProfile)
              : _buildContent(user),
    );
  }

  Widget _buildContent(dynamic user) {
    final t = _tenant ?? {};
    final fullName = t['fullName'] ?? user?.name ?? 'Tenant';
    final email = t['email'] ?? user?.email ?? '';
    final phone = t['phone'] ?? user?.phone ?? '-';
    final room = t['room'] is Map ? t['room'] as Map<String, dynamic> : null;
    final roomNum = room?['roomNumber'] ?? '-';
    final floor = room?['floor'] ?? '-';
    final bed = t['assignedBed'] ?? '-';
    final joiningDate = t['joiningDate'] != null ? DateFormatter.formatDate(t['joiningDate'].toString()) : '-';
    final rent = t['monthlyRent'] ?? 0;
    final deposit = t['securityDeposit'] ?? 0;
    final emergency = t['emergencyContact'] is Map ? t['emergencyContact'] as Map<String, dynamic> : null;

    final initials = fullName.isNotEmpty
        ? fullName.trim().split(' ').map((p) => p.isNotEmpty ? p[0] : '').take(2).join('').toUpperCase()
        : 'T';

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Avatar Card
        AppCard(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: AppColors.primary,
                child: Text(
                  initials,
                  style: AppTextStyles.h1.copyWith(color: Colors.white, fontSize: 24),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(fullName, style: AppTextStyles.h2),
                    const SizedBox(height: 2),
                    Text(email, style: AppTextStyles.bodySmall),
                    const SizedBox(height: 2),
                    Text(phone, style: AppTextStyles.bodySmall),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Stay Details
        Text('Stay Details', style: AppTextStyles.labelMedium),
        const SizedBox(height: 8),
        AppCard(
          padding: const EdgeInsets.all(18),
          child: Column(
            children: [
              _buildDetailRow('Room Assignment', 'Room $roomNum (Floor $floor)'),
              const Divider(height: 16, color: AppColors.divider),
              _buildDetailRow('Assigned Bed', 'Bed $bed'),
              const Divider(height: 16, color: AppColors.divider),
              _buildDetailRow('Joining Date', joiningDate),
              const Divider(height: 16, color: AppColors.divider),
              _buildDetailRow('Monthly Rent', CurrencyFormatter.format(rent)),
              const Divider(height: 16, color: AppColors.divider),
              _buildDetailRow('Security Deposit', CurrencyFormatter.format(deposit)),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Occupancy History Timeline Action
        AppCard(
          padding: EdgeInsets.zero,
          child: ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primarySurface,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.history_rounded, color: AppColors.primary, size: 22),
            ),
            title: const Text('Occupancy History & Timeline', style: AppTextStyles.labelLarge),
            subtitle: const Text('View all your room stays, dates, and transfers', style: AppTextStyles.bodySmall),
            trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textLight),
            onTap: () => OccupancyHistorySheet.show(context),
          ),
        ),
        const SizedBox(height: 20),

        // Emergency Contact
        if (emergency != null) ...[
          Text('Emergency Contact', style: AppTextStyles.labelMedium),
          const SizedBox(height: 8),
          AppCard(
            padding: const EdgeInsets.all(18),
            child: Column(
              children: [
                _buildDetailRow('Contact Name', emergency['name'] ?? '-'),
                const Divider(height: 16, color: AppColors.divider),
                _buildDetailRow('Relation', emergency['relation'] ?? '-'),
                const Divider(height: 16, color: AppColors.divider),
                _buildDetailRow('Phone Number', emergency['phone'] ?? '-'),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],

        // Account & Security
        Text('Account Settings', style: AppTextStyles.labelMedium),
        const SizedBox(height: 8),
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primarySurface,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.lock_reset_rounded, color: AppColors.primary, size: 20),
                ),
                title: const Text('Change Password', style: AppTextStyles.labelLarge),
                trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textLight),
                onTap: () => context.push('/change-password'),
              ),
              const Divider(height: 1, color: AppColors.divider),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.errorLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.logout_rounded, color: AppColors.error, size: 20),
                ),
                title: Text(
                  'Sign Out',
                  style: AppTextStyles.labelLarge.copyWith(color: AppColors.error),
                ),
                trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textLight),
                onTap: () async {
                  final confirm = await AppDialog.showConfirmation(
                    context: context,
                    title: 'Sign Out',
                    content: 'Are you sure you want to sign out?',
                    confirmText: 'Sign Out',
                    isDestructive: true,
                  );
                  if (confirm == true) {
                    ref.read(authProvider.notifier).logout();
                  }
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Official Brand Footer
        Center(
          child: Column(
            children: [
              const AppBrandLogo.compact(height: 24),
              const SizedBox(height: 6),
              Text(
                'Sky Height Apartment • v1.0.0',
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.textLight, fontSize: 11),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary)),
        Text(value, style: AppTextStyles.labelLarge),
      ],
    );
  }
}
