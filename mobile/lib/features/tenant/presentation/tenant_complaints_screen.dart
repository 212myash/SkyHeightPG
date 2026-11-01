import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/network/api_endpoints.dart';
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

class TenantComplaintsScreen extends ConsumerStatefulWidget {
  const TenantComplaintsScreen({super.key});

  @override
  ConsumerState<TenantComplaintsScreen> createState() => _TenantComplaintsScreenState();
}

class _TenantComplaintsScreenState extends ConsumerState<TenantComplaintsScreen> {
  bool _isLoading = true;
  String? _error;
  List<dynamic> _complaints = [];

  @override
  void initState() {
    super.initState();
    _fetchComplaints();
  }

  Future<void> _fetchComplaints() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final api = ref.read(apiClientProvider);
      final res = await api.get(ApiEndpoints.myComplaints);
      if (mounted) {
        if (res.data != null && res.data['success'] == true) {
          setState(() {
            _complaints = (res.data['data'] as List<dynamic>?) ?? [];
            _isLoading = false;
          });
        } else {
          setState(() {
            _error = res.data?['message'] ?? 'Failed to load complaints';
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

  void _showRaiseComplaintDialog() {
    final formKey = GlobalKey<FormState>();
    final titleController = TextEditingController();
    final descController = TextEditingController();
    String selectedPriority = 'medium';
    String selectedCategory = 'other';
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
                        Text('Raise a Complaint', style: AppTextStyles.h2),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.of(modalContext).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Report room maintenance, plumbing, wifi, or cleanliness issues directly to the owner.',
                      style: AppTextStyles.bodySmall,
                    ),
                    const SizedBox(height: 18),
                    AppTextField(
                      controller: titleController,
                      label: 'Complaint Title *',
                      hint: 'e.g. Geyser not heating water',
                      prefixIcon: Icons.title_rounded,
                      validator: (v) => Validators.required(v, 'Please enter a title'),
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      initialValue: selectedCategory,
                      decoration: InputDecoration(
                        labelText: 'Category *',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'electricity', child: Text('Electricity / Appliances')),
                        DropdownMenuItem(value: 'plumbing', child: Text('Plumbing / Water')),
                        DropdownMenuItem(value: 'wifi', child: Text('WiFi & Internet')),
                        DropdownMenuItem(value: 'cleaning', child: Text('Room / PG Cleaning')),
                        DropdownMenuItem(value: 'furniture', child: Text('Furniture / Bedding')),
                        DropdownMenuItem(value: 'noise', child: Text('Noise / Disturbance')),
                        DropdownMenuItem(value: 'other', child: Text('Other Issue')),
                      ],
                      onChanged: (val) {
                        if (val != null) setModalState(() => selectedCategory = val);
                      },
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      initialValue: selectedPriority,
                      decoration: InputDecoration(
                        labelText: 'Priority Level *',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'low', child: Text('Low - General Maintenance')),
                        DropdownMenuItem(value: 'medium', child: Text('Medium - Standard Request')),
                        DropdownMenuItem(value: 'high', child: Text('High - Urgent Attention')),
                        DropdownMenuItem(value: 'urgent', child: Text('Critical - Emergency')),
                      ],
                      onChanged: (val) {
                        if (val != null) setModalState(() => selectedPriority = val);
                      },
                    ),
                    const SizedBox(height: 14),
                    AppTextField(
                      controller: descController,
                      label: 'Detailed Description *',
                      hint: 'Describe the issue clearly...',
                      maxLines: 4,
                      validator: (v) => Validators.required(v, 'Please describe the issue'),
                    ),
                    const SizedBox(height: 24),
                    AppButton(
                      label: 'Submit Complaint',
                      isLoading: isSubmitting,
                      onPressed: () async {
                        if (!formKey.currentState!.validate()) return;
                        setModalState(() => isSubmitting = true);

                        try {
                          final api = ref.read(apiClientProvider);
                          final res = await api.post(
                            ApiEndpoints.complaints,
                            data: {
                              'title': titleController.text.trim(),
                              'description': descController.text.trim(),
                              'category': selectedCategory,
                              'priority': selectedPriority,
                            },
                          );

                          if (modalContext.mounted) {
                            Navigator.of(modalContext).pop();
                          }
                          if (mounted) {
                            if (res.data?['success'] == true) {
                              AppDialog.showSnackBar(context, 'Complaint registered successfully.');
                              _fetchComplaints();
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
        title: const Text('Maintenance & Helpdesk'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _fetchComplaints,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        onPressed: _showRaiseComplaintDialog,
        icon: const Icon(Icons.add_comment_rounded),
        label: const Text('Raise Issue'),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: AppLoader(text: 'Loading complaints...'));
    }

    if (_error != null) {
      return ErrorStateView(message: _error!, onRetry: _fetchComplaints);
    }

    if (_complaints.isEmpty) {
      return EmptyStateView(
        icon: Icons.chat_bubble_outline_rounded,
        title: 'No Active Issues',
        description: 'Everything looks good! If you ever face an issue, tap below to report it.',
        actionText: 'Raise Complaint',
        onAction: _showRaiseComplaintDialog,
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchComplaints,
      color: AppColors.primary,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
        itemCount: _complaints.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final c = _complaints[index] as Map<String, dynamic>;
          final title = c['title'] ?? 'Complaint';
          final desc = c['description'] ?? '';
          final status = (c['status'] ?? 'open').toString();
          final priority = (c['priority'] ?? 'medium').toString().toUpperCase();
          final category = (c['category'] ?? 'other').toString().toUpperCase();
          final resolution = c['resolution'];
          final dateStr = c['createdAt'] != null ? DateFormatter.formatDate(c['createdAt'].toString()) : '-';

          return AppCard(
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
                          Text('Logged on $dateStr', style: AppTextStyles.bodySmall),
                        ],
                      ),
                    ),
                    StatusBadge(status: status),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primarySurface,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'PRIORITY: $priority',
                        style: AppTextStyles.badge.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 11),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Text(
                        category,
                        style: AppTextStyles.badge.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 11),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(desc, style: AppTextStyles.bodyMedium),
                if (resolution != null && resolution.toString().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.successLight,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.success.withAlpha(50)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.check_circle_rounded, size: 16, color: AppColors.success),
                            const SizedBox(width: 6),
                            Text(
                              'Resolution Notes',
                              style: AppTextStyles.labelMedium.copyWith(color: AppColors.success),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          resolution.toString(),
                          style: AppTextStyles.bodySmall.copyWith(color: AppColors.textPrimary),
                        ),
                      ],
                    ),
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
