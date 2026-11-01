import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_dialog.dart';
import '../../auth/providers/auth_provider.dart';

class OwnerMoreScreen extends ConsumerWidget {
  const OwnerMoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Menu & Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        children: [
          // Profile Card
          AppCard(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: AppColors.primary,
                  child: Text(
                    (user?.name.isNotEmpty ?? false) ? user!.name[0].toUpperCase() : 'O',
                    style: AppTextStyles.h1.copyWith(color: Colors.white, fontSize: 24),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user?.name ?? 'PG Owner', style: AppTextStyles.h3),
                      const SizedBox(height: 2),
                      Text(user?.email ?? '', style: AppTextStyles.bodySmall),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primarySurface,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'PG OWNER',
                          style: AppTextStyles.badge.copyWith(color: AppColors.primary, fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // PG Configuration
          Text('Configuration', style: AppTextStyles.labelMedium),
          const SizedBox(height: 8),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _buildTile(
                  icon: Icons.storefront_outlined,
                  title: 'PG Profile & UPI Settings',
                  subtitle: 'PG name, address, electricity rates & UPI ID',
                  onTap: () => context.push('/owner/settings'),
                ),
                const Divider(height: 1, color: AppColors.divider),
                _buildTile(
                  icon: Icons.lock_reset_rounded,
                  title: 'Change Password',
                  subtitle: 'Update your security credentials',
                  onTap: () => context.push('/change-password'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Operations (Shortcuts)
          Text('Operations Modules', style: AppTextStyles.labelMedium),
          const SizedBox(height: 8),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _buildTile(
                  icon: Icons.bolt_rounded,
                  title: 'Electricity Meter Readings',
                  subtitle: 'Log monthly room sub-meter units',
                  onTap: () => AppDialog.showSnackBar(context, 'Meter management active in Phase 5'),
                ),
                const Divider(height: 1, color: AppColors.divider),
                _buildTile(
                  icon: Icons.receipt_long_outlined,
                  title: 'Expenses & Maintenance',
                  subtitle: 'Log repairs, cleaner bills & supplies',
                  onTap: () => AppDialog.showSnackBar(context, 'Expenses active in Phase 5'),
                ),
                const Divider(height: 1, color: AppColors.divider),
                _buildTile(
                  icon: Icons.report_problem_outlined,
                  title: 'Complaints Desk',
                  subtitle: 'Review and resolve tenant issues',
                  onTap: () => AppDialog.showSnackBar(context, 'Complaints active in Phase 5'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Logout Button
          AppCard(
            padding: EdgeInsets.zero,
            child: _buildTile(
              icon: Icons.logout_rounded,
              title: 'Sign Out',
              subtitle: 'Log out from Sky Height PG',
              iconColor: AppColors.error,
              textColor: AppColors.error,
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
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color? iconColor,
    Color? textColor,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: (iconColor ?? AppColors.primary).withAlpha(20),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: iconColor ?? AppColors.primary, size: 22),
      ),
      title: Text(
        title,
        style: AppTextStyles.labelLarge.copyWith(color: textColor ?? AppColors.textPrimary),
      ),
      subtitle: Text(subtitle, style: AppTextStyles.bodySmall),
      trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textLight),
      onTap: onTap,
    );
  }
}
