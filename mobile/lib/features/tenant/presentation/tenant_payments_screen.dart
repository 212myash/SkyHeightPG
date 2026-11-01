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

class TenantPaymentsScreen extends ConsumerStatefulWidget {
  const TenantPaymentsScreen({super.key});

  @override
  ConsumerState<TenantPaymentsScreen> createState() => _TenantPaymentsScreenState();
}

class _TenantPaymentsScreenState extends ConsumerState<TenantPaymentsScreen> {
  bool _isLoading = true;
  String? _error;
  List<dynamic> _payments = [];
  List<dynamic> _pendingBills = [];

  @override
  void initState() {
    super.initState();
    _fetchPaymentsAndBills();
  }

  Future<void> _fetchPaymentsAndBills() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final api = ref.read(apiClientProvider);
      final pRes = await api.get(ApiEndpoints.myPayments);
      final bRes = await api.get(ApiEndpoints.myBills);

      if (mounted) {
        setState(() {
          _payments = (pRes.data?['data'] as List<dynamic>?) ?? [];
          final allBills = (bRes.data?['data'] as List<dynamic>?) ?? [];
          _pendingBills = allBills.where((b) {
            final st = (b['paymentStatus'] ?? '').toString().toUpperCase();
            return st != 'PAID';
          }).toList();
          _isLoading = false;
        });
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

  void _showSubmitUpiDialog() {
    if (_pendingBills.isEmpty) {
      AppDialog.showSnackBar(
        context,
        'No pending bills! You have no outstanding dues to pay.',
      );
      return;
    }

    final formKey = GlobalKey<FormState>();
    String selectedBillId = _pendingBills.first['_id'].toString();
    final firstDue = ((_pendingBills.first['totalAmount'] ?? 0) - (_pendingBills.first['paidAmount'] ?? 0)).clamp(0, double.infinity);
    final amountController = TextEditingController(text: firstDue > 0 ? firstDue.toString() : '');
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
                      'Enter your 12-digit bank UPI transaction reference (UTR) for owner verification.',
                      style: AppTextStyles.bodySmall,
                    ),
                    const SizedBox(height: 18),

                    if (_pendingBills.isNotEmpty) ...[
                      DropdownButtonFormField<String>(
                        initialValue: selectedBillId,
                        decoration: InputDecoration(
                          labelText: 'Select Bill to Pay',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        items: _pendingBills.map<DropdownMenuItem<String>>((b) {
                          final month = b['billingMonth'] ?? 'Bill';
                          final total = b['totalAmount'] ?? 0;
                          final paid = b['paidAmount'] ?? 0;
                          final due = total - paid;
                          return DropdownMenuItem<String>(
                            value: b['_id'].toString(),
                            child: Text('$month (Due: ${CurrencyFormatter.format(due)})'),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setModalState(() {
                              selectedBillId = val;
                              final match = _pendingBills.firstWhere((b) => b['_id'].toString() == val);
                              final due = ((match['totalAmount'] ?? 0) - (match['paidAmount'] ?? 0)).clamp(0, double.infinity);
                              amountController.text = due > 0 ? due.toString() : '';
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 14),
                    ],

                    AppTextField(
                      controller: amountController,
                      label: 'Amount Paid (₹)',
                      hint: 'e.g. 8500',
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      prefixIcon: Icons.currency_rupee_rounded,
                      validator: (v) => Validators.positiveNumber(v, 'Enter valid amount paid'),
                    ),
                    const SizedBox(height: 14),
                    AppTextField(
                      controller: utrController,
                      label: '12-Digit UPI Ref / UTR Number',
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
                      hint: 'e.g. Paid via Google Pay',
                      prefixIcon: Icons.notes_rounded,
                    ),
                    const SizedBox(height: 24),
                    AppButton(
                      label: 'Submit for Verification',
                      isLoading: isSubmitting,
                      onPressed: () async {
                        if (!formKey.currentState!.validate()) return;
                        setModalState(() => isSubmitting = true);

                        final payload = <String, dynamic>{
                          'billId': selectedBillId,
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
                              _fetchPaymentsAndBills();
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
        title: const Text('Payment Receipts'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _fetchPaymentsAndBills,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        onPressed: _showSubmitUpiDialog,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Submit UPI'),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: AppLoader(text: 'Loading payments...'));
    }

    if (_error != null) {
      return ErrorStateView(message: _error!, onRetry: _fetchPaymentsAndBills);
    }

    if (_payments.isEmpty) {
      return EmptyStateView(
        icon: Icons.payment_outlined,
        title: 'No Payments Yet',
        description: 'You can submit your first UPI payment receipt using the button below.',
        actionText: 'Submit Payment',
        onAction: _showSubmitUpiDialog,
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchPaymentsAndBills,
      color: AppColors.primary,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
        itemCount: _payments.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final p = _payments[index] as Map<String, dynamic>;
          final amount = p['amount'] ?? 0;
          final method = (p['paymentMethod'] ?? 'CASH').toString().toUpperCase();
          final status = (p['verificationStatus'] ?? 'PENDING').toString();
          final utr = p['transactionReference'] ?? '-';
          final dateStr = p['paymentDate'] != null ? DateFormatter.formatDateTime(p['paymentDate'].toString()) : '-';

          return AppCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          CurrencyFormatter.format(amount),
                          style: AppTextStyles.h2.copyWith(color: AppColors.primary),
                        ),
                        Text(dateStr, style: AppTextStyles.bodySmall),
                      ],
                    ),
                    StatusBadge(status: status),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(height: 1, color: AppColors.divider),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Method: $method', style: AppTextStyles.bodySmall),
                    if (method == 'UPI')
                      Text(
                        'UTR: $utr',
                        style: AppTextStyles.bodySmall.copyWith(
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
