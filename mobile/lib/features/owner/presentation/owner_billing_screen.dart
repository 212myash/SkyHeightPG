import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_dialog.dart';
import '../../../core/widgets/app_loader.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/empty_state_view.dart';
import '../../../core/widgets/keyboard_aware_view.dart';
import '../../../core/widgets/error_state_view.dart';
import '../../../core/widgets/status_badge.dart';
import '../../auth/providers/auth_provider.dart';

class OwnerBillingScreen extends ConsumerStatefulWidget {
  const OwnerBillingScreen({super.key});

  @override
  ConsumerState<OwnerBillingScreen> createState() => _OwnerBillingScreenState();
}

class _OwnerBillingScreenState extends ConsumerState<OwnerBillingScreen> {
  bool _isLoading = true;
  String? _error;
  String _selectedMonth = '';
  String _filterStatus = 'ALL';
  List<dynamic> _bills = [];
  List<dynamic> _tenants = [];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    _fetchBillsAndTenants();
  }

  void _changeMonth(int delta) {
    final parts = _selectedMonth.split('-').map(int.parse).toList();
    var year = parts[0];
    var month = parts[1] + delta;
    if (month > 12) {
      year++;
      month = 1;
    } else if (month < 1) {
      year--;
      month = 12;
    }
    setState(() {
      _selectedMonth = '$year-${month.toString().padLeft(2, '0')}';
    });
    _fetchBillsAndTenants();
  }

  Future<void> _fetchBillsAndTenants() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final api = ref.read(apiClientProvider);
      final billsRes = await api.get('${ApiEndpoints.bills}?billingMonth=$_selectedMonth');
      final tenantsRes = await api.get(ApiEndpoints.tenants);

      if (mounted) {
        if (billsRes.data?['success'] == true) {
          _bills = (billsRes.data['data'] as List<dynamic>?) ?? [];
        }
        _tenants = (tenantsRes.data?['data'] as List<dynamic>?) ?? [];
        setState(() => _isLoading = false);
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

  List<dynamic> get _filteredBills {
    return _bills.where((b) {
      final st = (b['paymentStatus'] ?? '').toString().toUpperCase();
      if (_filterStatus == 'ALL') return true;
      return st == _filterStatus;
    }).toList();
  }

  double get _totalBilled => _bills.fold(0.0, (sum, b) => sum + ((b['totalAmount'] ?? 0) as num).toDouble());
  double get _totalPaid => _bills.fold(0.0, (sum, b) => sum + ((b['paidAmount'] ?? 0) as num).toDouble());
  double get _totalDue => _totalBilled - _totalPaid;

  void _showGenerateBillsDialog() {
    bool isBulk = true;
    String? selectedTenantId = _tenants.isNotEmpty ? _tenants.first['_id'].toString() : null;
    final otherChargesController = TextEditingController(text: '0');
    final adjustmentsController = TextEditingController(text: '0');
    final notesController = TextEditingController();
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (modalContext, setModalState) {
          return KeyboardDismissible(
            child: Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 24,
                bottom: MediaQuery.of(modalContext).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Generate Monthly Bills', style: AppTextStyles.h2),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.of(modalContext).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.primarySurface,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today_rounded, size: 20, color: AppColors.primary),
                        const SizedBox(width: 10),
                        Text(
                          'Billing Month: ${DateFormatter.formatMonth(_selectedMonth)}',
                          style: AppTextStyles.labelLarge.copyWith(color: AppColors.primary),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('Generation Scope', style: AppTextStyles.labelMedium),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          label: const Center(child: Text('All Active Tenants')),
                          selected: isBulk,
                          selectedColor: AppColors.primarySurface,
                          labelStyle: TextStyle(
                            color: isBulk ? AppColors.primary : AppColors.textSecondary,
                            fontWeight: isBulk ? FontWeight.w700 : FontWeight.w500,
                          ),
                          side: BorderSide(color: isBulk ? AppColors.primary : AppColors.border),
                          onSelected: (val) {
                            if (val) setModalState(() => isBulk = true);
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ChoiceChip(
                          label: const Center(child: Text('Specific Tenant')),
                          selected: !isBulk,
                          selectedColor: AppColors.primarySurface,
                          labelStyle: TextStyle(
                            color: !isBulk ? AppColors.primary : AppColors.textSecondary,
                            fontWeight: !isBulk ? FontWeight.w700 : FontWeight.w500,
                          ),
                          side: BorderSide(color: !isBulk ? AppColors.primary : AppColors.border),
                          onSelected: (val) {
                            if (val) setModalState(() => isBulk = false);
                          },
                        ),
                      ),
                    ],
                  ),
                  if (!isBulk) ...[
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      initialValue: selectedTenantId,
                      decoration: InputDecoration(
                        labelText: 'Select Tenant',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      items: _tenants.map((t) {
                        final name = t['fullName'] ?? 'Tenant';
                        final room = t['room'] is Map ? t['room']['roomNumber'] ?? '-' : '-';
                        return DropdownMenuItem<String>(
                          value: t['_id'].toString(),
                          child: Text('$name (Room $room)'),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setModalState(() => selectedTenantId = val);
                      },
                    ),
                  ],
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: AppTextField(
                          controller: otherChargesController,
                          label: 'Other Charges (₹)',
                          hint: 'e.g. 200',
                          keyboardType: TextInputType.number,
                          prefixIcon: Icons.add_circle_outline_rounded,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: AppTextField(
                          controller: adjustmentsController,
                          label: 'Adjustments (₹)',
                          hint: 'Discount or extra',
                          keyboardType: const TextInputType.numberWithOptions(signed: true),
                          prefixIcon: Icons.tune_rounded,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  AppTextField(
                    controller: notesController,
                    label: 'Notes / Remarks (Optional)',
                    hint: 'e.g. Maintenance fee included',
                    prefixIcon: Icons.notes_rounded,
                  ),
                  const SizedBox(height: 24),
                  AppButton(
                    label: isBulk ? 'Generate All Bills' : 'Generate Bill',
                    isLoading: isSubmitting,
                    onPressed: () async {
                      setModalState(() => isSubmitting = true);

                      final payload = <String, dynamic>{
                        'billingMonth': _selectedMonth,
                        'otherCharges': double.tryParse(otherChargesController.text.trim()) ?? 0,
                        'adjustments': double.tryParse(adjustmentsController.text.trim()) ?? 0,
                        'notes': notesController.text.trim(),
                        'bulk': isBulk,
                      };
                      if (!isBulk && selectedTenantId != null) {
                        payload['tenantId'] = selectedTenantId;
                      }

                      try {
                        final api = ref.read(apiClientProvider);
                        final res = await api.post(ApiEndpoints.generateBills, data: payload);

                        if (modalContext.mounted) {
                          Navigator.of(modalContext).pop();
                        }
                        if (mounted) {
                          if (res.data?['success'] == true) {
                            AppDialog.showSnackBar(
                              context,
                              res.data?['message'] ?? 'Monthly bills generated successfully!',
                            );
                            _fetchBillsAndTenants();
                          } else {
                            AppDialog.showSnackBar(
                              context,
                              res.data?['message'] ?? 'Failed to generate bills',
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

  void _showAdjustmentsDialog(Map<String, dynamic> bill) {
    final billId = bill['_id']?.toString() ?? '';
    final tenantName = bill['tenant'] is Map ? bill['tenant']['fullName'] ?? 'Tenant' : 'Tenant';
    final currentAdj = (bill['adjustments'] ?? 0).toString();
    final currentOther = (bill['otherCharges'] ?? 0).toString();

    final adjController = TextEditingController(text: currentAdj);
    final otherController = TextEditingController(text: currentOther);
    final notesController = TextEditingController(text: bill['notes'] ?? '');
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (modalContext, setModalState) {
          return KeyboardDismissible(
            child: Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 24,
                bottom: MediaQuery.of(modalContext).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text('Update Charges: $tenantName', style: AppTextStyles.h2),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.of(modalContext).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                AppTextField(
                  controller: otherController,
                  label: 'Other Charges (₹)',
                  hint: 'e.g. 200',
                  keyboardType: TextInputType.number,
                  prefixIcon: Icons.add_circle_outline,
                ),
                const SizedBox(height: 12),
                AppTextField(
                  controller: adjController,
                  label: 'Adjustments (₹)',
                  hint: 'Discount or fine',
                  keyboardType: const TextInputType.numberWithOptions(signed: true),
                  prefixIcon: Icons.tune_rounded,
                ),
                const SizedBox(height: 12),
                AppTextField(
                  controller: notesController,
                  label: 'Adjustment Reason / Notes',
                  hint: 'e.g. Late fee / festival discount',
                  prefixIcon: Icons.notes_rounded,
                ),
                const SizedBox(height: 24),
                AppButton(
                  label: 'Save Adjustments',
                  isLoading: isSubmitting,
                  onPressed: () async {
                    setModalState(() => isSubmitting = true);

                    try {
                      final api = ref.read(apiClientProvider);
                      final res = await api.put(
                        ApiEndpoints.billAdjustments(billId),
                        data: {
                          'otherCharges': double.tryParse(otherController.text.trim()) ?? 0,
                          'adjustments': double.tryParse(adjController.text.trim()) ?? 0,
                          'notes': notesController.text.trim(),
                        },
                      );

                      if (modalContext.mounted) {
                        Navigator.of(modalContext).pop();
                      }
                      if (mounted) {
                        if (res.data?['success'] == true) {
                          AppDialog.showSnackBar(context, 'Bill adjustments updated.');
                          _fetchBillsAndTenants();
                        } else {
                          AppDialog.showSnackBar(context, res.data?['message'] ?? 'Update failed', isError: true);
                        }
                      }
                    } catch (e) {
                      if (modalContext.mounted) {
                        setModalState(() => isSubmitting = false);
                        AppDialog.showSnackBar(modalContext, e.toString(), isError: true);
                      }
                    }
                  },
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
        title: const Text('Monthly Billing & Invoices'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _fetchBillsAndTenants,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showGenerateBillsDialog,
        icon: const Icon(Icons.receipt_long_rounded),
        label: const Text('Generate Bills'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Month Selector
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.white,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left_rounded),
                  onPressed: () => _changeMonth(-1),
                ),
                Row(
                  children: [
                    const Icon(Icons.calendar_month_outlined, size: 18, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Text(
                      DateFormatter.formatMonth(_selectedMonth),
                      style: AppTextStyles.h3,
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right_rounded),
                  onPressed: () => _changeMonth(1),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),

          // Overview Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: AppCard(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildHeaderMetric('Total Billed', CurrencyFormatter.format(_totalBilled), Icons.receipt_rounded, AppColors.textPrimary),
                  _buildHeaderMetric('Collected', CurrencyFormatter.format(_totalPaid), Icons.check_circle_outline, AppColors.success),
                  _buildHeaderMetric('Pending Due', CurrencyFormatter.format(_totalDue), Icons.schedule_rounded, _totalDue > 0 ? AppColors.error : AppColors.textLight),
                ],
              ),
            ),
          ),

          // Status Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _buildFilterChip('All (${_bills.length})', 'ALL'),
                const SizedBox(width: 8),
                _buildFilterChip('Unpaid', 'UNPAID'),
                const SizedBox(width: 8),
                _buildFilterChip('Partially Paid', 'PARTIALLY_PAID'),
                const SizedBox(width: 8),
                _buildFilterChip('Paid', 'PAID'),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Bill List
          Expanded(
            child: _isLoading
                ? const AppLoader(message: 'Loading bills...')
                : _error != null
                    ? ErrorStateView(message: _error!, onRetry: _fetchBillsAndTenants)
                    : _filteredBills.isEmpty
                        ? EmptyStateView(
                            title: 'No Bills for this Month',
                            description: 'Tap "Generate Bills" to calculate monthly rent and electricity for tenants.',
                            icon: Icons.receipt_long_outlined,
                            actionText: 'Generate Bills',
                            onAction: _showGenerateBillsDialog,
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.only(left: 16, right: 16, bottom: 80),
                            itemCount: _filteredBills.length,
                            separatorBuilder: (context, index) => const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final bill = _filteredBills[index] as Map<String, dynamic>;
                              return _buildBillCard(bill);
                            },
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _filterStatus == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: AppColors.primarySurface,
      labelStyle: TextStyle(
        color: isSelected ? AppColors.primary : AppColors.textSecondary,
        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
        fontSize: 12,
      ),
      side: BorderSide(
        color: isSelected ? AppColors.primary : AppColors.border,
      ),
      onSelected: (selected) {
        if (selected) setState(() => _filterStatus = value);
      },
    );
  }

  Widget _buildHeaderMetric(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(height: 4),
        Text(value, style: AppTextStyles.h3.copyWith(fontSize: 15)),
        const SizedBox(height: 2),
        Text(label, style: AppTextStyles.bodySmall.copyWith(fontSize: 11)),
      ],
    );
  }

  Widget _buildBillCard(Map<String, dynamic> bill) {
    final tenant = bill['tenant'] is Map ? bill['tenant'] as Map<String, dynamic> : null;
    final tenantName = tenant?['fullName'] ?? 'Unknown Tenant';
    final room = bill['room'] is Map ? bill['room'] as Map<String, dynamic> : null;
    final roomNum = room?['roomNumber'] ?? '-';

    final rent = bill['monthlyRent'] ?? 0;
    final elec = bill['electricityAmount'] ?? 0;
    final other = bill['otherCharges'] ?? 0;
    final adj = bill['adjustments'] ?? 0;
    final total = (bill['totalAmount'] ?? 0) as num;
    final paid = (bill['paidAmount'] ?? 0) as num;
    final due = total - paid;
    final status = (bill['paymentStatus'] ?? 'UNPAID').toString();
    final dueDate = bill['dueDate'] != null ? DateFormatter.formatDate(bill['dueDate'].toString()) : '-';

    return AppCard(
      padding: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showAdjustmentsDialog(bill),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: AppColors.primarySurface, borderRadius: BorderRadius.circular(8)),
                        child: const Icon(Icons.person_outline, color: AppColors.primary, size: 20),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(tenantName, style: AppTextStyles.h3),
                          Text('Room $roomNum • Due: $dueDate', style: AppTextStyles.bodySmall),
                        ],
                      ),
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
                  Text('Rent: ${CurrencyFormatter.format(rent)}', style: AppTextStyles.bodySmall),
                  Text('Electricity: ${CurrencyFormatter.format(elec)}', style: AppTextStyles.bodySmall),
                  if (other > 0) Text('Other: ${CurrencyFormatter.format(other)}', style: AppTextStyles.bodySmall),
                  if (adj != 0) Text('Adj: ${CurrencyFormatter.format(adj)}', style: AppTextStyles.bodySmall),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(8)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Total Bill', style: AppTextStyles.bodySmall),
                        Text(CurrencyFormatter.format(total), style: AppTextStyles.labelLarge),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text('Paid So Far', style: AppTextStyles.bodySmall),
                        Text(CurrencyFormatter.format(paid), style: AppTextStyles.labelLarge.copyWith(color: AppColors.success)),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('Outstanding', style: AppTextStyles.bodySmall),
                        Text(
                          CurrencyFormatter.format(due),
                          style: AppTextStyles.labelLarge.copyWith(color: due > 0 ? AppColors.error : AppColors.textPrimary),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
