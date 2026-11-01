import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_dialog.dart';
import '../../../core/widgets/app_loader.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/empty_state_view.dart';
import '../../../core/widgets/error_state_view.dart';
import '../../../core/widgets/status_badge.dart';
import '../../auth/providers/auth_provider.dart';

class OwnerComplaintsScreen extends ConsumerStatefulWidget {
  const OwnerComplaintsScreen({super.key});

  @override
  ConsumerState<OwnerComplaintsScreen> createState() => _OwnerComplaintsScreenState();
}

class _OwnerComplaintsScreenState extends ConsumerState<OwnerComplaintsScreen> {
  bool _isLoading = true;
  String? _error;
  List<dynamic> _complaints = [];
  String _selectedStatus = 'all';

  static const List<Map<String, String>> _statusFilters = [
    {'value': 'all', 'label': 'All Issues'},
    {'value': 'open', 'label': 'Open'},
    {'value': 'in_progress', 'label': 'In Progress'},
    {'value': 'resolved', 'label': 'Resolved'},
    {'value': 'rejected', 'label': 'Rejected'},
  ];

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
      String url = ApiEndpoints.complaints;
      if (_selectedStatus != 'all') {
        url += '?status=$_selectedStatus';
      }

      final res = await api.get(url);
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

  void _showResolveComplaintModal(Map<String, dynamic> c) {
    final id = c['_id'].toString();
    final title = c['title'] ?? 'Complaint';
    final currentStatus = (c['status'] ?? 'open').toString().toLowerCase();
    final resolutionController = TextEditingController(text: c['resolution'] ?? '');
    String selectedStatus = currentStatus;
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
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Update Issue Status', style: AppTextStyles.h2),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(modalContext).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text('Issue: $title', style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: selectedStatus,
                    decoration: InputDecoration(
                      labelText: 'Resolution Status *',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'open', child: Text('Open - Awaiting Action')),
                      DropdownMenuItem(value: 'in_progress', child: Text('In Progress - Technician Assigned')),
                      DropdownMenuItem(value: 'resolved', child: Text('Resolved - Problem Fixed')),
                      DropdownMenuItem(value: 'rejected', child: Text('Rejected - Not Feasible / Invalid')),
                    ],
                    onChanged: (val) {
                      if (val != null) setModalState(() => selectedStatus = val);
                    },
                  ),
                  const SizedBox(height: 16),
                  AppTextField(
                    controller: resolutionController,
                    label: 'Resolution Notes / Actions Taken',
                    hint: 'e.g. Plumber repaired the valve on 12th Nov',
                    maxLines: 3,
                  ),
                  const SizedBox(height: 24),
                  AppButton(
                    label: 'Save Status Update',
                    isLoading: isSaving,
                    onPressed: () async {
                      setModalState(() => isSaving = true);
                      try {
                        final api = ref.read(apiClientProvider);
                        final res = await api.put(
                          ApiEndpoints.updateComplaintStatus(id),
                          data: {
                            'status': selectedStatus,
                            'resolution': resolutionController.text.trim(),
                          },
                        );

                        if (modalContext.mounted) {
                          Navigator.of(modalContext).pop();
                        }
                        if (mounted) {
                          if (res.data?['success'] == true) {
                            AppDialog.showSnackBar(context, 'Complaint status updated successfully.');
                            _fetchComplaints();
                          } else {
                            AppDialog.showSnackBar(
                              context,
                              res.data?['message'] ?? 'Update failed',
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
                    icon: Icons.check_circle_rounded,
                  ),
                ],
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
        title: const Text('Complaints & Helpdesk'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _fetchComplaints,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Chips
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _statusFilters.map((f) {
                  final isSelected = _selectedStatus == f['value'];
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(f['label']!),
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
                          setState(() => _selectedStatus = f['value']!);
                          _fetchComplaints();
                        }
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          const Divider(height: 1, color: AppColors.divider),

          if (_isLoading)
            const Expanded(child: Center(child: AppLoader(text: 'Loading complaints...')))
          else if (_error != null)
            Expanded(child: ErrorStateView(message: _error!, onRetry: _fetchComplaints))
          else if (_complaints.isEmpty)
            const Expanded(
              child: EmptyStateView(
                icon: Icons.check_circle_outline_rounded,
                title: 'No Complaints Found',
                description: 'There are no complaints matching the selected filter.',
              ),
            )
          else
            Expanded(
              child: RefreshIndicator(
                onRefresh: _fetchComplaints,
                color: AppColors.primary,
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _complaints.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final c = _complaints[index] as Map<String, dynamic>;
                    return _buildComplaintCard(c);
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildComplaintCard(Map<String, dynamic> c) {
    final title = c['title'] ?? 'Complaint';
    final desc = c['description'] ?? '';
    final status = (c['status'] ?? 'open').toString();
    final priority = (c['priority'] ?? 'medium').toString().toUpperCase();
    final category = (c['category'] ?? 'other').toString().toUpperCase();
    final resolution = c['resolution'];
    final dateStr = c['createdAt'] != null ? DateFormatter.formatDate(c['createdAt'].toString()) : '-';

    final tenant = c['tenant'] is Map ? c['tenant'] : null;
    final tenantName = tenant?['fullName'] ?? 'Tenant';
    final room = c['room'] is Map ? c['room'] : null;
    final roomNumber = room?['roomNumber'] ?? 'Unknown';

    Color priorityColor;
    switch (priority) {
      case 'URGENT':
        priorityColor = AppColors.error;
        break;
      case 'HIGH':
        priorityColor = Colors.deepOrange;
        break;
      case 'MEDIUM':
        priorityColor = AppColors.warning;
        break;
      default:
        priorityColor = AppColors.info;
    }

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
                    const SizedBox(height: 2),
                    Text(
                      '$tenantName • Room $roomNumber • $dateStr',
                      style: AppTextStyles.bodySmall,
                    ),
                  ],
                ),
              ),
              StatusBadge(status: status),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: priorityColor.withAlpha(30),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'PRIORITY: $priority',
                  style: AppTextStyles.badge.copyWith(color: priorityColor, fontWeight: FontWeight.bold, fontSize: 11),
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
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.successLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.check_circle_rounded, size: 16, color: AppColors.success),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Resolution: $resolution',
                      style: AppTextStyles.bodySmall.copyWith(color: AppColors.textPrimary),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          const Divider(height: 1, color: AppColors.divider),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: AppButton(
              label: 'Update Status / Resolve',
              isOutlined: true,
              onPressed: () => _showResolveComplaintModal(c),
              icon: Icons.edit_note_rounded,
            ),
          ),
        ],
      ),
    );
  }
}
