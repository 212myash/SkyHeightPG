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

class OwnerPaymentsScreen extends ConsumerStatefulWidget {
  const OwnerPaymentsScreen({super.key});

  @override
  ConsumerState<OwnerPaymentsScreen> createState() => _OwnerPaymentsScreenState();
}

class _OwnerPaymentsScreenState extends ConsumerState<OwnerPaymentsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  String? _error;
  List<dynamic> _allPayments = [];
  List<dynamic> _pendingPayments = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchPayments();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchPayments() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final api = ref.read(apiClientProvider);
      final allRes = await api.get(ApiEndpoints.payments);

      if (mounted) {
        final list = (allRes.data?['data'] as List<dynamic>?) ?? [];
        final pending = list.where((p) {
          final st = (p['verificationStatus'] ?? '').toString().toUpperCase();
          return st == 'PENDING';
        }).toList();

        setState(() {
          _allPayments = list;
          _pendingPayments = pending;
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

  Future<void> _verifyPayment(String paymentId, String status) async {
    final confirm = await AppDialog.showConfirmation(
      context: context,
      title: status == 'VERIFIED' ? 'Verify Payment' : 'Reject Payment',
      content: status == 'VERIFIED'
          ? 'Are you sure you want to verify this payment? The tenant bill will be credited.'
          : 'Are you sure you want to reject this payment?',
      confirmText: status == 'VERIFIED' ? 'Verify' : 'Reject',
      isDestructive: status != 'VERIFIED',
    );

    if (confirm != true || !mounted) return;

    try {
      final api = ref.read(apiClientProvider);
      final res = await api.put(
        ApiEndpoints.verifyPayment(paymentId),
        data: {'status': status.toLowerCase()},
      );

      if (mounted) {
        if (res.data?['success'] == true) {
          AppDialog.showSnackBar(
            context,
            status == 'VERIFIED' ? 'Payment verified successfully!' : 'Payment marked as rejected.',
          );
          _fetchPayments();
        } else {
          AppDialog.showSnackBar(context, res.data?['message'] ?? 'Action failed', isError: true);
        }
      }
    } catch (e) {
      if (mounted) {
        AppDialog.showSnackBar(context, e.toString(), isError: true);
      }
    }
  }

  Future<void> _showRecordCashModal() async {
    try {
      final api = ref.read(apiClientProvider);
      final billsRes = await api.get(ApiEndpoints.pendingBills);

      final pendingBills = (billsRes.data?['data'] as List<dynamic>?) ?? [];
      if (pendingBills.isEmpty) {
        if (mounted) {
          AppDialog.showSnackBar(context, 'No pending bills found. All tenant dues are cleared!');
        }
        return;
      }

      if (!mounted) return;

      final formKey = GlobalKey<FormState>();
      String selectedBillId = pendingBills.first['_id'].toString();
      num initialDue = (pendingBills.first['totalAmount'] ?? 0) - (pendingBills.first['paidAmount'] ?? 0);
      final amountController = TextEditingController(text: initialDue.toString());
      final notesController = TextEditingController(text: 'Cash payment received');
      final refController = TextEditingController(text: 'CASH-${DateTime.now().millisecondsSinceEpoch}');
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
                          Text('Record Cash Payment', style: AppTextStyles.h2),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.of(modalContext).pop(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Directly record cash collected from a tenant and credit their bill immediately.',
                        style: AppTextStyles.bodySmall,
                      ),
                      const SizedBox(height: 18),
                      DropdownButtonFormField<String>(
                        initialValue: selectedBillId,
                        decoration: InputDecoration(
                          labelText: 'Select Tenant Pending Bill *',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        isExpanded: true,
                        items: pendingBills.map((b) {
                          final t = b['tenant'] is Map ? b['tenant'] : null;
                          final tName = t?['fullName'] ?? 'Tenant';
                          final r = b['room'] is Map ? b['room'] : null;
                          final rNum = r?['roomNumber'] ?? '';
                          final month = b['billingMonth'] ?? '';
                          final due = ((b['totalAmount'] ?? 0) - (b['paidAmount'] ?? 0)).clamp(0, double.infinity);

                          return DropdownMenuItem<String>(
                            value: b['_id'].toString(),
                            child: Text(
                              '$tName (Rm $rNum) • $month • Due: ${CurrencyFormatter.format(due)}',
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 13),
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setModalState(() {
                              selectedBillId = val;
                              final match = pendingBills.firstWhere((b) => b['_id'].toString() == val);
                              final due = ((match['totalAmount'] ?? 0) - (match['paidAmount'] ?? 0)).clamp(0, double.infinity);
                              amountController.text = due.toString();
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 14),
                      AppTextField(
                        controller: amountController,
                        label: 'Cash Amount (₹) *',
                        hint: 'e.g. 5000',
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        prefixIcon: Icons.currency_rupee_rounded,
                        validator: (v) => Validators.positiveNumber(v, 'Enter valid payment amount'),
                      ),
                      const SizedBox(height: 14),
                      AppTextField(
                        controller: refController,
                        label: 'Receipt / Reference (Optional)',
                        hint: 'e.g. CASH-12345',
                        prefixIcon: Icons.tag_rounded,
                      ),
                      const SizedBox(height: 14),
                      AppTextField(
                        controller: notesController,
                        label: 'Notes / Remarks',
                        hint: 'e.g. Handed over at office',
                        prefixIcon: Icons.notes_rounded,
                      ),
                      const SizedBox(height: 24),
                      AppButton(
                        label: 'Confirm Cash Received',
                        isLoading: isSubmitting,
                        onPressed: () async {
                          if (!formKey.currentState!.validate()) return;
                          setModalState(() => isSubmitting = true);

                          final payload = {
                            'billId': selectedBillId,
                            'amount': double.tryParse(amountController.text.trim()) ?? 0,
                            'notes': notesController.text.trim(),
                            'transactionReference': refController.text.trim(),
                          };

                          try {
                            final res = await api.post(
                              ApiEndpoints.cashPayment,
                              data: payload,
                            );

                            if (modalContext.mounted) {
                              Navigator.of(modalContext).pop();
                            }
                            if (mounted) {
                              if (res.data?['success'] == true) {
                                AppDialog.showSnackBar(context, res.data?['message'] ?? 'Cash payment recorded.');
                                _fetchPayments();
                              } else {
                                AppDialog.showSnackBar(
                                  context,
                                  res.data?['message'] ?? 'Recording failed',
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
                        icon: Icons.check_circle_rounded,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      );
    } catch (e) {
      if (mounted) {
        AppDialog.showSnackBar(context, 'Failed to fetch pending bills: $e', isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Payments & Ledger'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _fetchPayments,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          indicatorWeight: 3,
          tabs: [
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Pending UPI'),
                  if (_pendingPayments.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.warning,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${_pendingPayments.length}',
                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Tab(text: 'All Payments (${_allPayments.length})'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        onPressed: _showRecordCashModal,
        icon: const Icon(Icons.payments_rounded),
        label: const Text('Record Cash'),
      ),
      body: _isLoading
          ? const Center(child: AppLoader(text: 'Loading payments...'))
          : _error != null
              ? ErrorStateView(message: _error!, onRetry: _fetchPayments)
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildPaymentList(_pendingPayments, isPendingTab: true),
                    _buildPaymentList(_allPayments, isPendingTab: false),
                  ],
                ),
    );
  }

  Widget _buildPaymentList(List<dynamic> list, {required bool isPendingTab}) {
    if (list.isEmpty) {
      return EmptyStateView(
        icon: Icons.payments_outlined,
        title: isPendingTab ? 'No Pending Verifications' : 'No Payments Recorded',
        description: isPendingTab
            ? 'All incoming tenant payments have been verified.'
            : 'Payment records will appear here as tenants pay bills.',
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchPayments,
      color: AppColors.primary,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
        itemCount: list.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final p = list[index] as Map<String, dynamic>;
          final id = (p['_id'] ?? '').toString();
          final amount = p['amount'] ?? 0;
          final method = (p['paymentMethod'] ?? 'CASH').toString().toUpperCase();
          final status = (p['verificationStatus'] ?? 'PENDING').toString();
          final utr = p['transactionReference'] ?? '-';
          final dateStr = p['paymentDate'] != null ? DateFormatter.formatDateTime(p['paymentDate'].toString()) : '-';

          final tenantObj = p['tenant'];
          final tenantName = tenantObj is Map ? (tenantObj['fullName'] ?? 'Tenant') : 'Tenant';

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
                        Text(tenantName, style: AppTextStyles.h3),
                        Text(dateStr, style: AppTextStyles.bodySmall),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          CurrencyFormatter.format(amount),
                          style: AppTextStyles.h2.copyWith(color: AppColors.primary),
                        ),
                        StatusBadge(status: status),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(height: 1, color: AppColors.divider),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          method == 'UPI' ? Icons.qr_code_2_rounded : Icons.payments_outlined,
                          size: 16,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Text('Method: $method', style: AppTextStyles.bodySmall),
                      ],
                    ),
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
                if (status.toUpperCase() == 'PENDING') ...[
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: AppButton(
                          label: 'Reject',
                          isOutlined: true,
                          onPressed: () => _verifyPayment(id, 'REJECTED'),
                          icon: Icons.close_rounded,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: AppButton(
                          label: 'Verify & Credit',
                          backgroundColor: AppColors.success,
                          onPressed: () => _verifyPayment(id, 'VERIFIED'),
                          icon: Icons.check_circle_outline_rounded,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}
