import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_dialog.dart';
import '../../../core/widgets/app_loader.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/empty_state_view.dart';
import '../../../core/widgets/error_state_view.dart';
import '../../../core/widgets/status_badge.dart';
import '../../auth/providers/auth_provider.dart';

class TenantBillsScreen extends ConsumerStatefulWidget {
  const TenantBillsScreen({super.key});

  @override
  ConsumerState<TenantBillsScreen> createState() => _TenantBillsScreenState();
}

class _TenantBillsScreenState extends ConsumerState<TenantBillsScreen> {
  bool _isLoading = true;
  String? _error;
  List<dynamic> _bills = [];

  @override
  void initState() {
    super.initState();
    _fetchBills();
  }

  Future<void> _fetchBills() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final api = ref.read(apiClientProvider);
      final res = await api.get(ApiEndpoints.myBills);
      if (mounted) {
        if (res.data != null && res.data['success'] == true) {
          setState(() {
            _bills = res.data['data'] as List<dynamic>? ?? [];
            _isLoading = false;
          });
        } else {
          setState(() {
            _error = res.data?['message'] ?? 'Failed to load bills';
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

  void _showSubmitUpiModal(Map<String, dynamic> bill) {
    final formKey = GlobalKey<FormState>();
    final billId = bill['_id'].toString();
    final month = bill['billingMonth'] ?? '';
    final total = (bill['totalAmount'] ?? 0) as num;
    final paid = (bill['paidAmount'] ?? 0) as num;
    final due = (total - paid).clamp(0, double.infinity);

    final amountController = TextEditingController(text: due.toString());
    final utrController = TextEditingController();
    final notesController = TextEditingController();
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (modalContext, setModalState) {
          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 24,
              bottom: MediaQuery.of(modalContext).viewInsets.bottom + 24,
            ),
            child: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Submit UPI Payment', style: AppTextStyles.h2),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.of(modalContext).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Bill: $month • Outstanding Balance: ${CurrencyFormatter.format(due)}',
                      style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 18),
                    AppTextField(
                      controller: amountController,
                      label: 'Amount Paid (₹) *',
                      hint: 'e.g. 5000',
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      prefixIcon: Icons.currency_rupee_rounded,
                      validator: (v) => Validators.positiveNumber(v, 'Enter valid amount paid'),
                    ),
                    const SizedBox(height: 14),
                    AppTextField(
                      controller: utrController,
                      label: '12-Digit UPI Ref / UTR Number *',
                      hint: 'e.g. 123456789012',
                      prefixIcon: Icons.receipt_long_rounded,
                      validator: (v) {
                        if (v == null || v.trim().length < 6) {
                          return 'Enter valid UPI transaction reference';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    AppTextField(
                      controller: notesController,
                      label: 'Notes / Remarks (Optional)',
                      hint: 'e.g. Paid via PhonePe / GPay',
                      prefixIcon: Icons.notes_rounded,
                    ),
                    const SizedBox(height: 24),
                    AppButton(
                      label: 'Submit for Verification',
                      isLoading: isSubmitting,
                      onPressed: () async {
                        if (!formKey.currentState!.validate()) return;
                        setModalState(() => isSubmitting = true);

                        final payload = {
                          'billId': billId,
                          'amount': double.tryParse(amountController.text.trim()) ?? 0,
                          'transactionReference': utrController.text.trim(),
                          'notes': notesController.text.trim(),
                        };

                        try {
                          final api = ref.read(apiClientProvider);
                          final res = await api.post(
                            ApiEndpoints.submitUpi,
                            data: payload,
                          );

                          if (modalContext.mounted) {
                            Navigator.of(modalContext).pop();
                          }
                          if (mounted) {
                            if (res.data?['success'] == true) {
                              AppDialog.showSnackBar(
                                context,
                                'Payment submitted! It will reflect once verified by the owner.',
                              );
                              _fetchBills();
                            } else {
                              AppDialog.showSnackBar(
                                context,
                                res.data?['message'] ?? 'Submission failed',
                                isError: true,
                              );
                            }
                          }
                        } catch (e) {
                          if (modalContext.mounted) {
                            setModalState(() => isSubmitting = false);
                            AppDialog.showSnackBar(modalContext, e.toString(), isError: true);
                          }
                        }
                      },
                      icon: Icons.send_rounded,
                    ),
                  ],
                ),
              ),
            ),
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
        title: const Text('My Invoices & Bills'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _fetchBills,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: AppLoader(text: 'Loading invoices...'));
    }

    if (_error != null) {
      return ErrorStateView(message: _error!, onRetry: _fetchBills);
    }

    if (_bills.isEmpty) {
      return const EmptyStateView(
        icon: Icons.receipt_long_outlined,
        title: 'No Bills Yet',
        description: 'Monthly bills generated by your PG owner will appear here.',
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchBills,
      color: AppColors.primary,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _bills.length,
        separatorBuilder: (context, index) => const SizedBox(height: 14),
        itemBuilder: (context, index) {
          final b = _bills[index] as Map<String, dynamic>;
          final month = b['billingMonth'] ?? 'Monthly Bill';
          final dueDate = b['dueDate'] != null ? DateFormatter.formatDate(b['dueDate'].toString()) : '-';
          final rent = b['monthlyRent'] ?? 0;
          final electricity = b['electricityAmount'] ?? 0;
          final other = b['otherCharges'] ?? 0;
          final adjustments = b['adjustments'] ?? 0;
          final total = b['totalAmount'] ?? 0;
          final paid = b['paidAmount'] ?? 0;
          final status = (b['paymentStatus'] ?? 'UNPAID').toString();
          final balance = (total - paid).clamp(0, double.infinity);

          final units = b['unitsConsumed'] ?? 0;

          return AppCard(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(month, style: AppTextStyles.h2.copyWith(fontSize: 18)),
                        Text('Due Date: $dueDate', style: AppTextStyles.bodySmall),
                      ],
                    ),
                    StatusBadge(status: status),
                  ],
                ),
                const SizedBox(height: 14),
                const Divider(height: 1, color: AppColors.divider),
                const SizedBox(height: 12),

                // Itemized breakdown
                _buildBillRow('Monthly Room Rent', rent),
                const SizedBox(height: 6),
                _buildBillRow('Electricity ($units Units)', electricity),
                if (other > 0) ...[
                  const SizedBox(height: 6),
                  _buildBillRow('Other Charges', other),
                ],
                if (adjustments != 0) ...[
                  const SizedBox(height: 6),
                  _buildBillRow('Adjustments', adjustments),
                ],

                const SizedBox(height: 10),
                const Divider(height: 1, color: AppColors.divider),
                const SizedBox(height: 10),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Total Amount', style: AppTextStyles.labelLarge),
                    Text(
                      CurrencyFormatter.format(total),
                      style: AppTextStyles.h3.copyWith(color: AppColors.textPrimary),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Paid So Far', style: AppTextStyles.bodySmall),
                    Text(CurrencyFormatter.format(paid), style: AppTextStyles.bodySmall),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Outstanding Balance',
                      style: AppTextStyles.labelLarge.copyWith(
                        color: balance > 0 ? AppColors.error : AppColors.success,
                      ),
                    ),
                    Text(
                      CurrencyFormatter.format(balance),
                      style: AppTextStyles.h2.copyWith(
                        fontSize: 18,
                        color: balance > 0 ? AppColors.error : AppColors.success,
                      ),
                    ),
                  ],
                ),
                if (balance > 0) ...[
                  const SizedBox(height: 14),
                  AppButton(
                    label: 'Pay via UPI',
                    onPressed: () => _showSubmitUpiModal(b),
                    icon: Icons.qr_code_2_rounded,
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildBillRow(String label, dynamic amount) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: AppTextStyles.bodyMedium),
        Text(CurrencyFormatter.format(amount), style: AppTextStyles.labelLarge),
      ],
    );
  }
}
