import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/config/app_config.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_dialog.dart';
import '../../../core/widgets/app_text_field.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final success = await ref.read(authProvider.notifier).login(
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );

    if (mounted) {
      setState(() => _isLoading = false);
      if (!success) {
        final errorMsg = ref.read(authProvider).errorMessage ?? 'Login failed. Please check your credentials.';
        AppDialog.showSnackBar(context, errorMsg, isError: true);
      }
    }
  }

  void _showServerConfigDialog() {
    final controller = TextEditingController(text: AppConfig.baseUrl);
    bool testing = false;
    String? testResult;
    bool testSuccess = false;

    showDialog(
      context: context,
      builder: (dlgContext) => StatefulBuilder(
        builder: (context, setDlgState) {
          return AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.dns_outlined, color: AppColors.primary),
                const SizedBox(width: 8),
                const Text('Backend Server URL', style: TextStyle(fontSize: 18)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Set the backend API host for physical device testing:',
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: controller,
                  decoration: const InputDecoration(
                    labelText: 'Base URL',
                    hintText: AppConfig.productionApiUrl,
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    ActionChip(
                      avatar: const Icon(Icons.cloud_done_rounded, size: 16, color: AppColors.primary),
                      label: const Text('Render (Live)'),
                      onPressed: () => setDlgState(() => controller.text = AppConfig.productionApiUrl),
                    ),
                    ActionChip(
                      avatar: const Icon(Icons.usb_rounded, size: 16),
                      label: const Text('127.0.0.1 (USB)'),
                      onPressed: () => setDlgState(() => controller.text = 'http://127.0.0.1:5000'),
                    ),
                    ActionChip(
                      avatar: const Icon(Icons.wifi_rounded, size: 16),
                      label: const Text('LAN Wi-Fi'),
                      onPressed: () => setDlgState(() => controller.text = 'http://${AppConfig.defaultLanHost}:5000'),
                    ),
                  ],
                ),
                if (testResult != null) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(
                        testSuccess ? Icons.check_circle : Icons.error,
                        color: testSuccess ? AppColors.success : AppColors.error,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          testResult!,
                          style: TextStyle(
                            fontSize: 12,
                            color: testSuccess ? AppColors.success : AppColors.error,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: testing
                    ? null
                    : () async {
                        setDlgState(() {
                          testing = true;
                          testResult = 'Testing server reachability...';
                          testSuccess = false;
                        });
                        try {
                          final dio = Dio(BaseOptions(
                            connectTimeout: const Duration(seconds: 25),
                            receiveTimeout: const Duration(seconds: 25),
                          ));
                          final cleanUrl = controller.text.trim().replaceAll(RegExp(r'/+$'), '');
                          final res = await dio.get('$cleanUrl/health');
                          setDlgState(() {
                            testing = false;
                            testSuccess = res.statusCode == 200;
                            testResult = 'Connected! Server is live and healthy.';
                          });
                        } catch (e) {
                          try {
                            final dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 5)));
                            final cleanUrl = controller.text.trim().replaceAll(RegExp(r'/+$'), '');
                            final res = await dio.get('$cleanUrl/');
                            setDlgState(() {
                              testing = false;
                              testSuccess = res.statusCode == 200;
                              testResult = 'Connected! Server is reachable.';
                            });
                          } catch (_) {
                            setDlgState(() {
                              testing = false;
                              testSuccess = false;
                              testResult = 'Connection failed: Cloud server may be waking up. Try again in 15 seconds.';
                            });
                          }
                        }
                      },
                child: testing
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Test Connection'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final input = controller.text.trim();
                  if (input == AppConfig.productionApiUrl || input.isEmpty) {
                    await AppConfig.resetBaseUrl();
                  } else {
                    await AppConfig.setCustomBaseUrl(input);
                  }
                  if (dlgContext.mounted) Navigator.pop(dlgContext);
                  if (mounted) {
                    AppDialog.showSnackBar(this.context, 'Base URL updated to: ${AppConfig.baseUrl}');
                  }
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_ethernet_rounded, color: AppColors.textSecondary),
            tooltip: 'Server Connection',
            onPressed: _showServerConfigDialog,
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // App Icon & Header
                  Center(
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withAlpha(60),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.apartment_rounded,
                        color: Colors.white,
                        size: 40,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Welcome to Sky Height PG',
                    style: AppTextStyles.h1.copyWith(fontSize: 24),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Sign in to manage your PG or tenant dashboard',
                    style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),

                  // Form Card
                  AppCard(
                    padding: const EdgeInsets.all(24),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          AppTextField(
                            controller: _emailController,
                            label: 'Email Address',
                            hint: 'e.g. user@skyheightpg.com',
                            keyboardType: TextInputType.emailAddress,
                            prefixIcon: Icons.email_outlined,
                            validator: Validators.email,
                            textInputAction: TextInputAction.next,
                          ),
                          const SizedBox(height: 18),
                          AppTextField(
                            controller: _passwordController,
                            label: 'Password',
                            hint: '••••••••',
                            isPassword: true,
                            prefixIcon: Icons.lock_outline_rounded,
                            validator: Validators.password,
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) => _handleLogin(),
                          ),
                          const SizedBox(height: 12),
                          if (kDebugMode) ...[
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  icon: const Icon(Icons.admin_panel_settings_outlined, size: 14),
                                  label: const Text('Fill Owner', style: TextStyle(fontSize: 12)),
                                  onPressed: () {
                                    _emailController.text = 'owner_1793511029432@skyheight-test.com';
                                    _passwordController.text = 'Password123';
                                  },
                                ),
                                OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  icon: const Icon(Icons.person_outline, size: 14),
                                  label: const Text('Fill Tenant', style: TextStyle(fontSize: 12)),
                                  onPressed: () {
                                    _emailController.text = 'tenanta_1793511055378@skyheight-test.com';
                                    _passwordController.text = 'Password123';
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                          ],
                          AppButton(
                            label: 'Sign In',
                            isLoading: _isLoading,
                            onPressed: _handleLogin,
                            icon: Icons.login_rounded,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Register Link
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Don't have an account?",
                        style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
                      ),
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: () => context.push('/register'),
                        child: Text(
                          'Register',
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
