import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_dialog.dart';
import '../../../core/widgets/empty_state_view.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/registration_request_model.dart';

class OwnerRegistrationsScreen extends ConsumerStatefulWidget {
  const OwnerRegistrationsScreen({super.key});

  @override
  ConsumerState<OwnerRegistrationsScreen> createState() => _OwnerRegistrationsScreenState();
}

class _OwnerRegistrationsScreenState extends ConsumerState<OwnerRegistrationsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  List<RegistrationRequestModel> _registrations = [];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        _fetchRegistrations();
      }
    });
    _fetchRegistrations();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String get _currentStatusFilter {
    switch (_tabController.index) {
      case 0:
        return 'pending';
      case 1:
        return 'approved';
      case 2:
        return 'all';
      default:
        return 'pending';
    }
  }

  Future<void> _fetchRegistrations() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final api = ref.read(apiClientProvider);
      final res = await api.get(
        ApiEndpoints.registrations,
        queryParameters: {'status': _currentStatusFilter},
      );

      if (res.data != null && res.data['success'] == true) {
        final list = (res.data['data'] as List<dynamic>?) ?? [];
        if (mounted) {
          setState(() {
            _registrations = list.map((item) => RegistrationRequestModel.fromJson(item as Map<String, dynamic>)).toList();
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _errorMessage = res.data?['message']?.toString() ?? 'Failed to load registrations';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleApprove(RegistrationRequestModel req) async {
    // Fetch available rooms first
    List<Map<String, dynamic>> rooms = [];
    try {
      final api = ref.read(apiClientProvider);
      final roomRes = await api.get(ApiEndpoints.rooms);
      if (roomRes.data != null && roomRes.data['data'] is List) {
        rooms = (roomRes.data['data'] as List).cast<Map<String, dynamic>>();
      }
    } catch (_) {}

    if (!mounted) return;

    String? selectedRoomId;
    double? rentAmount;
    final rentController = TextEditingController();
    final depositController = TextEditingController(text: '0');

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (modalCtx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.check_circle_outline_rounded, color: AppColors.success, size: 28),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Approve ${req.name}',
                            style: AppTextStyles.h2.copyWith(fontSize: 18),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.of(modalCtx).pop(),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    Text(
                      'Assign a Room (Occupancy-based, No Beds):',
                      style: AppTextStyles.labelMedium,
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: selectedRoomId,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: 'Select Room (Optional)',
                      ),
                      items: [
                        const DropdownMenuItem<String>(
                          value: null,
                          child: Text('Unassigned (Assign Later)'),
                        ),
                        ...rooms.map((r) {
                          final rNum = r['roomNumber']?.toString() ?? 'Room';
                          final maxOcc = r['maxOccupancy'] ?? r['capacity'] ?? 2;
                          final currOcc = r['currentOccupancy'] ?? r['occupiedBeds'] ?? 0;
                          final isFull = currOcc >= maxOcc;
                          return DropdownMenuItem<String>(
                            value: r['_id']?.toString(),
                            enabled: !isFull,
                            child: Text(
                              'Room $rNum  ($currOcc/$maxOcc occupants)${isFull ? " — FULL" : ""}',
                              style: TextStyle(
                                color: isFull ? AppColors.textLight : AppColors.textPrimary,
                                fontWeight: isFull ? FontWeight.normal : FontWeight.w600,
                              ),
                            ),
                          );
                        }),
                      ],
                      onChanged: (val) {
                        setModalState(() {
                          selectedRoomId = val;
                          if (val != null) {
                            final chosen = rooms.firstWhere((r) => r['_id']?.toString() == val, orElse: () => {});
                            if (chosen['monthlyRent'] != null) {
                              rentAmount = (chosen['monthlyRent'] as num).toDouble();
                              rentController.text = rentAmount!.toStringAsFixed(0);
                            }
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: rentController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Monthly Rent (Rs.)',
                        border: OutlineInputBorder(),
                        prefixText: 'Rs. ',
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: depositController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Security Deposit (Rs.)',
                        border: OutlineInputBorder(),
                        prefixText: 'Rs. ',
                      ),
                    ),
                    const SizedBox(height: 20),
                    AppButton(
                      label: 'Confirm Approval',
                      icon: Icons.check_rounded,
                      onPressed: () async {
                        Navigator.of(modalCtx).pop();
                        _submitApprove(
                          req.id,
                          roomId: selectedRoomId,
                          rent: double.tryParse(rentController.text),
                          deposit: double.tryParse(depositController.text),
                        );
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _submitApprove(String userId, {String? roomId, double? rent, double? deposit}) async {
    try {
      final api = ref.read(apiClientProvider);
      final body = <String, dynamic>{};
      if (roomId != null) body['roomId'] = roomId;
      if (rent != null) body['monthlyRent'] = rent;
      if (deposit != null) body['securityDeposit'] = deposit;

      final res = await api.put(ApiEndpoints.approveRegistration(userId), data: body);
      if (mounted) {
        if (res.data != null && res.data['success'] == true) {
          AppDialog.showSnackBar(context, res.data['message']?.toString() ?? 'Registration approved successfully!');
          _fetchRegistrations();
        } else {
          AppDialog.showSnackBar(context, res.data?['message']?.toString() ?? 'Failed to approve', isError: true);
        }
      }
    } catch (e) {
      if (mounted) {
        AppDialog.showSnackBar(context, e.toString(), isError: true);
      }
    }
  }

  Future<void> _handleReject(RegistrationRequestModel req) async {
    final reasonController = TextEditingController(text: 'Application requirements not met.');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Reject ${req.name}?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Please provide a reason for rejecting this registration. The applicant will be notified.',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Rejection Reason',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Reject Application'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final api = ref.read(apiClientProvider);
        final res = await api.put(
          ApiEndpoints.rejectRegistration(req.id),
          data: {'reason': reasonController.text.trim()},
        );
        if (mounted) {
          if (res.data != null && res.data['success'] == true) {
            AppDialog.showSnackBar(context, 'Registration rejected.');
            _fetchRegistrations();
          } else {
            AppDialog.showSnackBar(context, res.data?['message']?.toString() ?? 'Failed to reject', isError: true);
          }
        }
      } catch (e) {
        if (mounted) {
          AppDialog.showSnackBar(context, e.toString(), isError: true);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Registration Requests'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Pending'),
            Tab(text: 'Approved'),
            Tab(text: 'All'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _errorMessage != null
              ? EmptyStateView(
                  icon: Icons.error_outline_rounded,
                  title: 'Unable to Load Requests',
                  description: _errorMessage!,
                  actionText: 'Retry',
                  onAction: _fetchRegistrations,
                )
              : _registrations.isEmpty
                  ? EmptyStateView(
                      icon: Icons.assignment_turned_in_outlined,
                      title: 'No Registrations',
                      description: _tabController.index == 0
                          ? 'No pending tenant registration requests right now.'
                          : 'No registrations found in this category.',
                      actionText: 'Refresh',
                      onAction: _fetchRegistrations,
                    )
                  : RefreshIndicator(
                      onRefresh: _fetchRegistrations,
                      color: AppColors.primary,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _registrations.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final req = _registrations[index];
                          return _buildRegistrationCard(req);
                        },
                      ),
                    ),
    );
  }

  Widget _buildRegistrationCard(RegistrationRequestModel req) {
    Color statusColor;
    String statusLabel;
    switch (req.approvalStatus) {
      case 'approved':
        statusColor = AppColors.success;
        statusLabel = 'Approved';
        break;
      case 'rejected':
        statusColor = AppColors.error;
        statusLabel = 'Rejected';
        break;
      default:
        statusColor = AppColors.warning;
        statusLabel = 'Pending Approval';
    }

    final isPending = req.approvalStatus == 'pending';

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: AppColors.primarySurface,
                child: Text(
                  req.name.isNotEmpty ? req.name[0].toUpperCase() : 'T',
                  style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(req.name, style: AppTextStyles.h3),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        const Icon(Icons.email_outlined, size: 14, color: AppColors.textSecondary),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            req.email,
                            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    if (req.phone.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(Icons.phone_outlined, size: 14, color: AppColors.textSecondary),
                          const SizedBox(width: 4),
                          Text(req.phone, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          if (req.assignedRoomNumber != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.meeting_room_outlined, size: 16, color: AppColors.primary),
                const SizedBox(width: 6),
                Text(
                  'Assigned Room: ${req.assignedRoomNumber}',
                  style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ],
          if (req.rejectionReason != null && req.rejectionReason!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.errorLight,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'Reason: ${req.rejectionReason}',
                style: const TextStyle(color: AppColors.error, fontSize: 12),
              ),
            ),
          ],
          if (isPending) ...[
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _handleReject(req),
                    icon: const Icon(Icons.close_rounded, size: 18),
                    label: const Text('Reject'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: const BorderSide(color: AppColors.error),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _handleApprove(req),
                    icon: const Icon(Icons.check_rounded, size: 18),
                    label: const Text('Approve'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.success,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
