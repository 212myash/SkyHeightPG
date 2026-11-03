import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_dialog.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../auth/providers/auth_provider.dart';

class OwnerCreateNotificationScreen extends ConsumerStatefulWidget {
  const OwnerCreateNotificationScreen({super.key});

  @override
  ConsumerState<OwnerCreateNotificationScreen> createState() => _OwnerCreateNotificationScreenState();
}

class _OwnerCreateNotificationScreenState extends ConsumerState<OwnerCreateNotificationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _messageController = TextEditingController();

  String _selectedAudience = 'all'; // 'all', 'room', 'tenant'
  String _selectedCategory = 'general_announcement';
  String? _selectedRoomId;
  String? _selectedTenantId;
  DateTime? _selectedDueDate;
  bool _isLoading = false;

  List<Map<String, dynamic>> _rooms = [];
  List<Map<String, dynamic>> _tenants = [];

  final List<Map<String, String>> _categories = [
    {'value': 'general_announcement', 'label': 'General Announcement'},
    {'value': 'rent_reminder', 'label': 'Rent Reminder'},
    {'value': 'electricity_bill', 'label': 'Electricity Bill Notice'},
    {'value': 'maintenance', 'label': 'Maintenance / Repairs'},
    {'value': 'security_alert', 'label': 'Security Alert'},
    {'value': 'payment_reminder', 'label': 'Payment Follow-up'},
  ];

  @override
  void initState() {
    super.initState();
    _loadOptions();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _loadOptions() async {
    try {
      final api = ref.read(apiClientProvider);

      final roomsRes = await api.get(ApiEndpoints.rooms);
      if (roomsRes.data != null && roomsRes.data['data'] is List) {
        _rooms = (roomsRes.data['data'] as List).cast<Map<String, dynamic>>();
      }

      final tenantsRes = await api.get(ApiEndpoints.tenants);
      if (tenantsRes.data != null && tenantsRes.data['data'] is List) {
        _tenants = (tenantsRes.data['data'] as List).cast<Map<String, dynamic>>();
      }

      if (mounted) setState(() {});
    } catch (_) {}
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedAudience == 'room' && _selectedRoomId == null) {
      AppDialog.showSnackBar(context, 'Please select a target room.', isError: true);
      return;
    }

    if (_selectedAudience == 'tenant' && _selectedTenantId == null) {
      AppDialog.showSnackBar(context, 'Please select a target tenant.', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final api = ref.read(apiClientProvider);
      final body = <String, dynamic>{
        'title': _titleController.text.trim(),
        'message': _messageController.text.trim(),
        'category': _selectedCategory,
        'audience': _selectedAudience,
      };

      if (_selectedAudience == 'room') {
        body['targetRoom'] = _selectedRoomId;
      } else if (_selectedAudience == 'tenant') {
        body['targetTenant'] = _selectedTenantId;
      }

      if (_selectedDueDate != null) {
        body['dueDate'] = _selectedDueDate!.toIso8601String();
      }

      final res = await api.post(ApiEndpoints.notifications, data: body);

      if (mounted) {
        setState(() => _isLoading = false);
        if (res.data != null && res.data['success'] == true) {
          final count = res.data['count'] ?? 1;
          AppDialog.showSnackBar(context, 'Notification sent to $count recipient(s)!');
          context.pop(true);
        } else {
          AppDialog.showSnackBar(context, res.data?['message']?.toString() ?? 'Failed to send', isError: true);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        AppDialog.showSnackBar(context, e.toString(), isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Send Notification'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppCard(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Audience', style: AppTextStyles.labelMedium),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        _buildAudienceChip('all', 'All Tenants', Icons.groups_rounded),
                        _buildAudienceChip('room', 'Room', Icons.meeting_room_rounded),
                        _buildAudienceChip('tenant', 'Tenant', Icons.person_rounded),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (_selectedAudience == 'room') ...[
                      DropdownButtonFormField<String>(
                        initialValue: _selectedRoomId,
                        decoration: const InputDecoration(
                          labelText: 'Select Room',
                          border: OutlineInputBorder(),
                        ),
                        items: _rooms.map((r) {
                          final rNum = r['roomNumber']?.toString() ?? 'Room';
                          final occupants = (r['occupants'] as List?)?.length ?? 0;
                          return DropdownMenuItem<String>(
                            value: r['_id']?.toString(),
                            child: Text('Room $rNum ($occupants occupant(s))'),
                          );
                        }).toList(),
                        onChanged: (val) => setState(() => _selectedRoomId = val),
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (_selectedAudience == 'tenant') ...[
                      DropdownButtonFormField<String>(
                        initialValue: _selectedTenantId,
                        decoration: const InputDecoration(
                          labelText: 'Select Tenant',
                          border: OutlineInputBorder(),
                        ),
                        items: _tenants.map((t) {
                          final name = t['fullName']?.toString() ?? 'Tenant';
                          final rNum = t['room']?['roomNumber']?.toString();
                          return DropdownMenuItem<String>(
                            value: t['user']?['_id']?.toString() ?? t['_id']?.toString(),
                            child: Text('$name ${rNum != null ? "(Room $rNum)" : ""}'),
                          );
                        }).toList(),
                        onChanged: (val) => setState(() => _selectedTenantId = val),
                      ),
                      const SizedBox(height: 16),
                    ],
                    DropdownButtonFormField<String>(
                      initialValue: _selectedCategory,
                      decoration: const InputDecoration(
                        labelText: 'Notification Category',
                        border: OutlineInputBorder(),
                      ),
                      items: _categories.map((c) {
                        return DropdownMenuItem<String>(
                          value: c['value'],
                          child: Text(c['label']!),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedCategory = val);
                      },
                    ),
                    const SizedBox(height: 16),
                    AppTextField(
                      controller: _titleController,
                      label: 'Notice Title',
                      hint: 'e.g. Water Tank Maintenance Today',
                      prefixIcon: Icons.title_rounded,
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter a title' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _messageController,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Notification Message',
                        hintText: 'Enter full announcement or reminder message...',
                        border: OutlineInputBorder(),
                        alignLabelWithHint: true,
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter a message' : null,
                    ),
                    const SizedBox(height: 24),
                    AppButton(
                      label: 'Dispatch Notification',
                      icon: Icons.send_rounded,
                      isLoading: _isLoading,
                      onPressed: _handleSubmit,
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

  Widget _buildAudienceChip(String value, String label, IconData icon) {
    final isSelected = _selectedAudience == value;
    return Expanded(
      child: ChoiceChip(
        avatar: Icon(icon, size: 16, color: isSelected ? AppColors.primary : AppColors.textSecondary),
        label: Text(label),
        selected: isSelected,
        selectedColor: AppColors.primarySurface,
        labelStyle: TextStyle(
          color: isSelected ? AppColors.primary : AppColors.textSecondary,
          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          fontSize: 12,
        ),
        side: BorderSide(color: isSelected ? AppColors.primary : AppColors.border),
        onSelected: (selected) {
          if (selected) setState(() => _selectedAudience = value);
        },
      ),
    );
  }
}
