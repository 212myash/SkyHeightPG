import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_dialog.dart';
import '../../../core/widgets/app_text_field.dart';
import '../providers/auth_provider.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();

  String _selectedRole = 'TENANT';
  bool _isLoading = false;
  bool _isOwnerRegistered = false;

  @override
  void initState() {
    super.initState();
    _checkOwnerStatus();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _checkOwnerStatus() async {
    try {
      final api = ref.read(apiClientProvider);
      final res = await api.get(ApiEndpoints.ownerStatus);
      if (mounted && res.data != null) {
        setState(() {
          _isOwnerRegistered = res.data['ownerExists'] == true;
          if (_isOwnerRegistered) {
            _selectedRole = 'TENANT';
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final success = await ref.read(authProvider.notifier).register(
      name: _nameController.text.trim(),
      email: _emailController.text.trim(),
      phone: _phoneController.text.trim(),
      password: _passwordController.text,
      role: _selectedRole,
    );

    if (mounted) {
      setState(() => _isLoading = false);
      if (!success) {
        final errorMsg = ref.read(authProvider).errorMessage ?? 'Registration failed. Please try again.';
        AppDialog.showSnackBar(context, errorMsg, isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Create Account'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Join Sky Height PG',
                    style: AppTextStyles.h1.copyWith(fontSize: 24),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Enter your details to create an account',
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
                            controller: _nameController,
                            label: 'Full Name',
                            hint: 'e.g. Rahul Sharma',
                            prefixIcon: Icons.person_outline_rounded,
                            validator: (v) => Validators.required(v, 'Please enter your name'),
                            textInputAction: TextInputAction.next,
                          ),
                          const SizedBox(height: 16),
                          AppTextField(
                            controller: _emailController,
                            label: 'Email Address',
                            hint: 'e.g. rahul@example.com',
                            keyboardType: TextInputType.emailAddress,
                            prefixIcon: Icons.email_outlined,
                            validator: Validators.email,
                            textInputAction: TextInputAction.next,
                          ),
                          const SizedBox(height: 16),
                          AppTextField(
                            controller: _phoneController,
                            label: 'Phone Number',
                            hint: '10-digit mobile number',
                            keyboardType: TextInputType.phone,
                            prefixIcon: Icons.phone_outlined,
                            validator: Validators.phone,
                            textInputAction: TextInputAction.next,
                          ),
                          const SizedBox(height: 16),
                          AppTextField(
                            controller: _passwordController,
                            label: 'Password',
                            hint: 'At least 6 characters',
                            isPassword: true,
                            prefixIcon: Icons.lock_outline_rounded,
                            validator: Validators.password,
                            textInputAction: TextInputAction.done,
                          ),
                          const SizedBox(height: 20),

                          // Role selection
                          Text('Account Type', style: AppTextStyles.labelMedium),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: ChoiceChip(
                                  label: const Center(child: Text('Tenant')),
                                  selected: _selectedRole == 'TENANT',
                                  selectedColor: AppColors.primarySurface,
                                  labelStyle: TextStyle(
                                    color: _selectedRole == 'TENANT' ? AppColors.primary : AppColors.textSecondary,
                                    fontWeight: _selectedRole == 'TENANT' ? FontWeight.w700 : FontWeight.w500,
                                  ),
                                  side: BorderSide(
                                    color: _selectedRole == 'TENANT' ? AppColors.primary : AppColors.border,
                                  ),
                                  onSelected: (selected) {
                                    if (selected) setState(() => _selectedRole = 'TENANT');
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ChoiceChip(
                                  label: const Center(child: Text('Owner')),
                                  selected: _selectedRole == 'OWNER',
                                  selectedColor: AppColors.primarySurface,
                                  labelStyle: TextStyle(
                                    color: _selectedRole == 'OWNER' ? AppColors.primary : AppColors.textSecondary,
                                    fontWeight: _selectedRole == 'OWNER' ? FontWeight.w700 : FontWeight.w500,
                                  ),
                                  side: BorderSide(
                                    color: _selectedRole == 'OWNER' ? AppColors.primary : AppColors.border,
                                  ),
                                  onSelected: _isOwnerRegistered
                                      ? null
                                      : (selected) {
                                          if (selected) setState(() => _selectedRole = 'OWNER');
                                        },
                                ),
                              ),
                            ],
                          ),
                          if (_isOwnerRegistered) ...[
                            const SizedBox(height: 6),
                            Text(
                              'Note: PG Owner account is already configured.',
                              style: AppTextStyles.bodySmall.copyWith(color: AppColors.warning),
                            ),
                          ],
                          const SizedBox(height: 24),

                          AppButton(
                            label: 'Create Account',
                            isLoading: _isLoading,
                            onPressed: _handleRegister,
                            icon: Icons.person_add_alt_1_rounded,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Already have an account?',
                        style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
                      ),
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: () => context.pop(),
                        child: Text(
                          'Sign In',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
