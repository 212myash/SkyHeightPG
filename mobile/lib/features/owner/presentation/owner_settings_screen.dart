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
import '../../../core/widgets/app_loader.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/error_state_view.dart';
import '../../../core/widgets/keyboard_aware_view.dart';
import '../../auth/providers/auth_provider.dart';

class OwnerSettingsScreen extends ConsumerStatefulWidget {
  const OwnerSettingsScreen({super.key});

  @override
  ConsumerState<OwnerSettingsScreen> createState() => _OwnerSettingsScreenState();
}

class _OwnerSettingsScreenState extends ConsumerState<OwnerSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _pgNameController = TextEditingController();
  final _addressController = TextEditingController();
  final _contactController = TextEditingController();
  final _electricityRateController = TextEditingController();
  final _dueDateController = TextEditingController();
  final _upiIdController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchSettings();
  }

  @override
  void dispose() {
    _pgNameController.dispose();
    _addressController.dispose();
    _contactController.dispose();
    _electricityRateController.dispose();
    _dueDateController.dispose();
    _upiIdController.dispose();
    super.dispose();
  }

  Future<void> _fetchSettings() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final api = ref.read(apiClientProvider);
      final res = await api.get(ApiEndpoints.settings);
      if (mounted) {
        if (res.data != null && res.data['success'] == true) {
          final s = res.data['data'] as Map<String, dynamic>? ?? {};
          _pgNameController.text = s['pgName'] ?? '';
          final rawAddress = s['address'];
          if (rawAddress is Map) {
            final parts = [
              rawAddress['street'],
              rawAddress['city'],
              rawAddress['state'],
              rawAddress['pincode'],
            ].where((p) => p != null && p.toString().trim().isNotEmpty).join(', ');
            _addressController.text = parts;
          } else {
            _addressController.text = rawAddress?.toString() ?? '';
          }
          _contactController.text = s['contactNumber'] ?? '';
          _electricityRateController.text = (s['electricityRatePerUnit'] ?? 10).toString();
          _dueDateController.text = (s['defaultDueDateDay'] ?? s['defaultDueDate'] ?? 5).toString();
          _upiIdController.text = s['upiId'] ?? '';
          setState(() => _isLoading = false);
        } else {
          setState(() {
            _error = res.data?['message'] ?? 'Failed to load settings';
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

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final api = ref.read(apiClientProvider);
      final res = await api.put(
        ApiEndpoints.settings,
        data: {
          'pgName': _pgNameController.text.trim(),
          'address': {'street': _addressController.text.trim()},
          'contactNumber': _contactController.text.trim(),
          'electricityRatePerUnit': double.tryParse(_electricityRateController.text.trim()) ?? 10,
          'defaultDueDateDay': int.tryParse(_dueDateController.text.trim()) ?? 5,
          'upiId': _upiIdController.text.trim(),
        },
      );

      if (mounted) {
        setState(() => _isSaving = false);
        if (res.data?['success'] == true) {
          AppDialog.showSnackBar(context, 'Settings saved successfully!');
          context.pop();
        } else {
          AppDialog.showSnackBar(context, res.data?['message'] ?? 'Failed to save', isError: true);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        AppDialog.showSnackBar(context, e.toString(), isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: const Text('PG Configuration'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: _isLoading
          ? const Center(child: AppLoader(text: 'Loading configuration...'))
          : _error != null
              ? ErrorStateView(message: _error!, onRetry: _fetchSettings)
              : KeyboardDismissible(
                  child: SingleChildScrollView(
                    keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.all(20),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 500),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            AppCard(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Property Information', style: AppTextStyles.h3),
                                  const SizedBox(height: 16),
                                  AppTextField(
                                    controller: _pgNameController,
                                    label: 'PG Name',
                                    hint: 'Sky Height PG',
                                    isRequired: true,
                                    prefixIcon: Icons.apartment_rounded,
                                    validator: (v) => Validators.required(v, 'PG Name is required'),
                                  ),
                                  const SizedBox(height: 14),
                                  AppTextField(
                                    controller: _addressController,
                                    label: 'Complete Address',
                                    hint: 'Street, Landmark, City',
                                    isRequired: true,
                                    prefixIcon: Icons.location_on_outlined,
                                    validator: (v) => Validators.required(v, 'Address is required'),
                                  ),
                                  const SizedBox(height: 14),
                                  AppTextField(
                                    controller: _contactController,
                                    label: 'Contact Phone Number',
                                    hint: '10-digit mobile number',
                                    isRequired: true,
                                    keyboardType: TextInputType.phone,
                                    prefixIcon: Icons.phone_outlined,
                                    validator: Validators.phone,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            AppCard(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Billing & Payments', style: AppTextStyles.h3),
                                  const SizedBox(height: 16),
                                  AppTextField(
                                    controller: _electricityRateController,
                                    label: 'Electricity Rate (₹ / Unit)',
                                    hint: '10',
                                    isRequired: true,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    prefixIcon: Icons.bolt_rounded,
                                    validator: (v) => Validators.positiveNumber(v, 'Enter a valid rate'),
                                  ),
                                  const SizedBox(height: 14),
                                  AppTextField(
                                    controller: _dueDateController,
                                    label: 'Default Monthly Due Date (Day of Month)',
                                    hint: '5',
                                    isRequired: true,
                                    keyboardType: TextInputType.number,
                                    prefixIcon: Icons.calendar_today_outlined,
                                    validator: (v) {
                                      final n = int.tryParse(v ?? '');
                                      if (n == null || n < 1 || n > 28) {
                                        return 'Enter a day between 1 and 28';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 14),
                                  AppTextField(
                                    controller: _upiIdController,
                                    label: 'PG UPI VPA ID',
                                    hint: 'e.g. skyheightpg@okaxis',
                                    isRequired: true,
                                    prefixIcon: Icons.qr_code_2_rounded,
                                    validator: (v) => Validators.required(v, 'UPI ID is required'),
                                  ),
                                ],
                              ),
                            ),
                          const SizedBox(height: 24),
                          AppButton(
                            label: 'Save Configuration',
                            isLoading: _isSaving,
                            onPressed: _handleSave,
                            icon: Icons.save_rounded,
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
