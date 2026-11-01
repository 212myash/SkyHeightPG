import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_dialog.dart';
import '../../../core/widgets/app_text_field.dart';
import '../providers/auth_provider.dart';

class ChangePasswordScreen extends ConsumerStatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  ConsumerState<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends ConsumerState<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_newPasswordController.text != _confirmPasswordController.text) {
      AppDialog.showSnackBar(context, 'New passwords do not match', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final success = await ref.read(authProvider.notifier).changePassword(
        currentPassword: _currentPasswordController.text,
        newPassword: _newPasswordController.text,
      );

      if (mounted) {
        setState(() => _isLoading = false);
        if (success) {
          AppDialog.showSnackBar(context, 'Password updated successfully!');
          context.pop();
        } else {
          AppDialog.showSnackBar(context, 'Failed to update password', isError: true);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        AppDialog.showSnackBar(context, e.toString(), isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Change Password'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Update Security Credentials',
                  style: AppTextStyles.h2,
                ),
                const SizedBox(height: 6),
                Text(
                  'Enter your current password and choose a secure new password.',
                  style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 24),
                AppCard(
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        AppTextField(
                          controller: _currentPasswordController,
                          label: 'Current Password',
                          hint: '••••••••',
                          isPassword: true,
                          prefixIcon: Icons.lock_outline_rounded,
                          validator: Validators.password,
                          textInputAction: TextInputAction.next,
                        ),
                        const SizedBox(height: 16),
                        AppTextField(
                          controller: _newPasswordController,
                          label: 'New Password',
                          hint: 'At least 6 characters',
                          isPassword: true,
                          prefixIcon: Icons.lock_reset_rounded,
                          validator: Validators.password,
                          textInputAction: TextInputAction.next,
                        ),
                        const SizedBox(height: 16),
                        AppTextField(
                          controller: _confirmPasswordController,
                          label: 'Confirm New Password',
                          hint: 'Repeat new password',
                          isPassword: true,
                          prefixIcon: Icons.lock_reset_rounded,
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'Please confirm your new password';
                            if (v != _newPasswordController.text) return 'Passwords do not match';
                            return null;
                          },
                          textInputAction: TextInputAction.done,
                        ),
                        const SizedBox(height: 24),
                        AppButton(
                          label: 'Update Password',
                          isLoading: _isLoading,
                          onPressed: _handleSubmit,
                          icon: Icons.check_circle_outline_rounded,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
