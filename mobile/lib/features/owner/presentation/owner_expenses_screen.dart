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
import '../../auth/providers/auth_provider.dart';

class OwnerExpensesScreen extends ConsumerStatefulWidget {
  const OwnerExpensesScreen({super.key});

  @override
  ConsumerState<OwnerExpensesScreen> createState() => _OwnerExpensesScreenState();
}

class _OwnerExpensesScreenState extends ConsumerState<OwnerExpensesScreen> {
  bool _isLoading = true;
  String? _error;
  List<dynamic> _expenses = [];
  Map<String, dynamic>? _summary;
  late String _selectedMonth; // YYYY-MM
  String _selectedCategory = 'all';

  static const List<Map<String, String>> _categories = [
    {'value': 'maintenance', 'label': 'Maintenance', 'icon': 'build'},
    {'value': 'utilities', 'label': 'Utilities', 'icon': 'bolt'},
    {'value': 'cleaning', 'label': 'Cleaning', 'icon': 'cleaning_services'},
    {'value': 'repairs', 'label': 'Repairs', 'icon': 'handyman'},
    {'value': 'supplies', 'label': 'Supplies', 'icon': 'shopping_basket'},
    {'value': 'wifi', 'label': 'WiFi', 'icon': 'wifi'},
    {'value': 'taxes', 'label': 'Taxes', 'icon': 'receipt_long'},
    {'value': 'salary', 'label': 'Salary', 'icon': 'badge'},
    {'value': 'other', 'label': 'Other', 'icon': 'more_horiz'},
  ];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    _fetchExpenses();
  }

  void _changeMonth(int delta) {
    final parts = _selectedMonth.split('-').map(_parseNumber).toList();
    var year = parts[0];
    var month = parts[1] + delta;
    if (month > 12) {
      month = 1;
      year++;
    } else if (month < 1) {
      month = 12;
      year--;
    }
    setState(() {
      _selectedMonth = '$year-${month.toString().padLeft(2, '0')}';
    });
    _fetchExpenses();
  }

  static int _parseNumber(dynamic v) => int.parse(v.toString());

  Future<void> _fetchExpenses() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final api = ref.read(apiClientProvider);

      String url = '${ApiEndpoints.expenses}?month=$_selectedMonth';
      if (_selectedCategory != 'all') {
        url += '&category=$_selectedCategory';
      }

      final responses = await Future.wait([
        api.get(url),
        api.get('${ApiEndpoints.expenseSummary}?month=$_selectedMonth'),
      ]);

      if (mounted) {
        final expRes = responses[0];
        final sumRes = responses[1];

        setState(() {
          _expenses = (expRes.data?['data'] as List<dynamic>?) ?? [];
          _summary = sumRes.data as Map<String, dynamic>?;
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

  void _showAddOrEditExpenseModal({Map<String, dynamic>? expense}) {
    final isEditing = expense != null;
    final formKey = GlobalKey<FormState>();
    final titleController = TextEditingController(text: expense?['title'] ?? '');
    final amountController = TextEditingController(
      text: expense != null ? (expense['amount'] ?? '').toString() : '',
    );
    final descController = TextEditingController(text: expense?['description'] ?? '');
    String category = expense?['category'] ?? 'maintenance';
    DateTime selectedDate = expense?['date'] != null
        ? DateTime.tryParse(expense!['date'].toString()) ?? DateTime.now()
        : DateTime.now();
    bool isSaving = false;

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
                        Text(
                          isEditing ? 'Edit Expense' : 'Record New Expense',
                          style: AppTextStyles.h2,
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.of(modalContext).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    AppTextField(
                      controller: titleController,
                      label: 'Expense Title *',
                      hint: 'e.g. RO Filter Replacement',
                      prefixIcon: Icons.title_rounded,
                      validator: (v) => Validators.required(v, 'Please enter a title'),
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      initialValue: category,
                      decoration: InputDecoration(
                        labelText: 'Category *',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      items: _categories.map((c) {
                        return DropdownMenuItem<String>(
                          value: c['value'],
                          child: Text(c['label']!),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setModalState(() => category = val);
                      },
                    ),
                    const SizedBox(height: 14),
                    AppTextField(
                      controller: amountController,
                      label: 'Amount (₹) *',
                      hint: 'e.g. 1500',
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      prefixIcon: Icons.currency_rupee_rounded,
                      validator: (v) => Validators.positiveNumber(v, 'Enter valid amount'),
                    ),
                    const SizedBox(height: 14),
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: modalContext,
                          initialDate: selectedDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now().add(const Duration(days: 30)),
                        );
                        if (picked != null) {
                          setModalState(() => selectedDate = picked);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                        decoration: BoxDecoration(
                          border: Border.all(color: AppColors.border),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Date: ${DateFormatter.formatDate(selectedDate.toIso8601String())}',
                              style: AppTextStyles.bodyMedium,
                            ),
                            const Icon(Icons.calendar_today_rounded, size: 18, color: AppColors.textSecondary),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    AppTextField(
                      controller: descController,
                      label: 'Description / Vendor (Optional)',
                      hint: 'Vendor name, invoice number or notes',
                      maxLines: 2,
                    ),
                    const SizedBox(height: 24),
                    AppButton(
                      label: isEditing ? 'Update Expense' : 'Save Expense',
                      isLoading: isSaving,
                      onPressed: () async {
                        if (!formKey.currentState!.validate()) return;
                        setModalState(() => isSaving = true);

                        final payload = {
                          'title': titleController.text.trim(),
                          'category': category,
                          'amount': double.tryParse(amountController.text.trim()) ?? 0,
                          'date': selectedDate.toIso8601String(),
                          'description': descController.text.trim(),
                        };

                        try {
                          final api = ref.read(apiClientProvider);
                          final res = isEditing
                              ? await api.put(
                                  ApiEndpoints.expenseById(expense['_id'].toString()),
                                  data: payload,
                                )
                              : await api.post(
                                  ApiEndpoints.expenses,
                                  data: payload,
                                );

                          if (modalContext.mounted) {
                            Navigator.of(modalContext).pop();
                          }
                          if (mounted) {
                            if (res.data?['success'] == true) {
                              AppDialog.showSnackBar(
                                context,
                                isEditing ? 'Expense updated successfully.' : 'Expense recorded successfully.',
                              );
                              _fetchExpenses();
                            } else {
                              AppDialog.showSnackBar(
                                context,
                                res.data?['message'] ?? 'Operation failed',
                                isError: true,
                              );
                            }
                          }
                        } catch (e) {
                          if (modalContext.mounted) {
                            setModalState(() => isSaving = false);
                            AppDialog.showSnackBar(modalContext, e.toString(), isError: true);
                          }
                        }
                      },
                      icon: isEditing ? Icons.check_rounded : Icons.save_rounded,
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

  Future<void> _deleteExpense(String id, String title) async {
    final confirm = await AppDialog.showConfirmation(
      context: context,
      title: 'Delete Expense',
      content: 'Are you sure you want to delete "$title"? This will affect financial reports.',
      confirmText: 'Delete',
      isDestructive: true,
    );

    if (confirm != true || !mounted) return;

    try {
      final api = ref.read(apiClientProvider);
      final res = await api.delete(ApiEndpoints.expenseById(id));
      if (mounted) {
        if (res.data?['success'] == true) {
          AppDialog.showSnackBar(context, 'Expense deleted successfully.');
          _fetchExpenses();
        } else {
          AppDialog.showSnackBar(context, res.data?['message'] ?? 'Delete failed', isError: true);
        }
      }
    } catch (e) {
      if (mounted) {
        AppDialog.showSnackBar(context, e.toString(), isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Expenses & Maintenance'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _fetchExpenses,
            tooltip: 'Refresh',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        onPressed: () => _showAddOrEditExpenseModal(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Expense'),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    return Column(
      children: [
        // Month Selector Header
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left_rounded),
                onPressed: () => _changeMonth(-1),
                tooltip: 'Previous Month',
              ),
              Row(
                children: [
                  const Icon(Icons.calendar_month_rounded, size: 20, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Text(
                    _selectedMonth,
                    style: AppTextStyles.h3.copyWith(color: AppColors.textPrimary),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right_rounded),
                onPressed: () => _changeMonth(1),
                tooltip: 'Next Month',
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: AppColors.divider),

        if (_isLoading)
          const Expanded(child: Center(child: AppLoader(text: 'Loading expenses...')))
        else if (_error != null)
          Expanded(child: ErrorStateView(message: _error!, onRetry: _fetchExpenses))
        else
          Expanded(
            child: RefreshIndicator(
              onRefresh: _fetchExpenses,
              color: AppColors.primary,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                children: [
                  // Monthly Summary KPI Card
                  _buildSummaryCard(),
                  const SizedBox(height: 16),

                  // Category Filter Chips
                  _buildCategoryFilterBar(),
                  const SizedBox(height: 16),

                  // Expense List
                  if (_expenses.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 24),
                      child: EmptyStateView(
                        icon: Icons.receipt_long_outlined,
                        title: 'No Expenses Recorded',
                        description: 'No operational expenses logged for this period.',
                      ),
                    )
                  else
                    ..._expenses.map((e) => _buildExpenseCard(e as Map<String, dynamic>)),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSummaryCard() {
    final totalSpent = (_summary?['totalSpent'] ?? 0) as num;
    final breakdown = (_summary?['breakdown'] as List<dynamic>?) ?? [];

    return AppCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Monthly Expenditure', style: AppTextStyles.labelMedium),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primarySurface,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${_expenses.length} Records',
                  style: AppTextStyles.badge.copyWith(color: AppColors.primary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            CurrencyFormatter.format(totalSpent),
            style: AppTextStyles.h1.copyWith(color: AppColors.error, fontSize: 26),
          ),
          if (breakdown.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Divider(height: 1, color: AppColors.divider),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: breakdown.map<Widget>((b) {
                final catName = (b['_id'] ?? 'other').toString().toUpperCase();
                final amt = (b['totalAmount'] ?? 0) as num;
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Text(
                    '$catName: ${CurrencyFormatter.format(amt)}',
                    style: AppTextStyles.badge.copyWith(fontWeight: FontWeight.w600, fontSize: 11),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCategoryFilterBar() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildFilterChip('all', 'All'),
          ..._categories.map((c) => _buildFilterChip(c['value']!, c['label']!)),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String value, String label) {
    final isSelected = _selectedCategory == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        selectedColor: AppColors.primary,
        backgroundColor: Colors.white,
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : AppColors.textPrimary,
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
        onSelected: (selected) {
          if (selected) {
            setState(() => _selectedCategory = value);
            _fetchExpenses();
          }
        },
      ),
    );
  }

  Widget _buildExpenseCard(Map<String, dynamic> e) {
    final id = e['_id'].toString();
    final title = e['title'] ?? 'Expense';
    final amount = (e['amount'] ?? 0) as num;
    final cat = (e['category'] ?? 'other').toString().toUpperCase();
    final dateStr = e['date'] != null ? DateFormatter.formatDate(e['date'].toString()) : '-';
    final desc = e['description'] ?? '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: AppTextStyles.h3),
                      const SizedBox(height: 2),
                      Text('Recorded on $dateStr', style: AppTextStyles.bodySmall),
                    ],
                  ),
                ),
                Text(
                  CurrencyFormatter.format(amount),
                  style: AppTextStyles.h2.copyWith(color: AppColors.error),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.primarySurface,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    cat,
                    style: AppTextStyles.badge.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 11),
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.primary),
                      onPressed: () => _showAddOrEditExpenseModal(expense: e),
                      tooltip: 'Edit',
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.error),
                      onPressed: () => _deleteExpense(id, title),
                      tooltip: 'Delete',
                    ),
                  ],
                ),
              ],
            ),
            if (desc.toString().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                desc.toString(),
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
