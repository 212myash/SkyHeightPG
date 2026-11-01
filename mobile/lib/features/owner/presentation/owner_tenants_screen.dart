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

class OwnerTenantsScreen extends ConsumerStatefulWidget {
  const OwnerTenantsScreen({super.key});

  @override
  ConsumerState<OwnerTenantsScreen> createState() => _OwnerTenantsScreenState();
}

class _OwnerTenantsScreenState extends ConsumerState<OwnerTenantsScreen> {
  bool _isLoading = true;
  String? _error;
  List<dynamic> _tenants = [];
  List<dynamic> _rooms = [];
  String _searchQuery = '';
  String _filterStatus = 'ALL';

  @override
  void initState() {
    super.initState();
    _fetchTenantsAndRooms();
  }

  Future<void> _fetchTenantsAndRooms() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final api = ref.read(apiClientProvider);
      final tenantRes = await api.get(ApiEndpoints.tenants);
      final roomsRes = await api.get(ApiEndpoints.rooms);

      if (mounted) {
        if (tenantRes.data != null && tenantRes.data['success'] == true) {
          setState(() {
            _tenants = tenantRes.data['data'] as List<dynamic>? ?? [];
            _rooms = (roomsRes.data?['data'] as List<dynamic>?) ?? [];
            _isLoading = false;
          });
        } else {
          setState(() {
            _error = tenantRes.data?['message'] ?? 'Failed to load tenants';
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

  List<dynamic> get _filteredTenants {
    return _tenants.where((t) {
      final map = t as Map<String, dynamic>;
      final name = (map['fullName'] ?? '').toString().toLowerCase();
      final phone = (map['phone'] ?? '').toString().toLowerCase();
      final room = map['room'] is Map ? (map['room']['roomNumber'] ?? '').toString().toLowerCase() : '';
      final status = (map['status'] ?? 'ACTIVE').toString().toUpperCase();

      final matchesQuery = _searchQuery.isEmpty ||
          name.contains(_searchQuery.toLowerCase()) ||
          phone.contains(_searchQuery.toLowerCase()) ||
          room.contains(_searchQuery.toLowerCase());

      final matchesStatus = _filterStatus == 'ALL' || status == _filterStatus;

      return matchesQuery && matchesStatus;
    }).toList();
  }

  void _showRegisterTenantDialog() {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final phoneController = TextEditingController();
    final passwordController = TextEditingController(text: 'Tenant123!');
    final bedController = TextEditingController(text: 'Bed 1');
    final rentController = TextEditingController();
    final depositController = TextEditingController(text: '10000');
    final streetController = TextEditingController();
    final cityController = TextEditingController();
    final emNameController = TextEditingController();
    final emPhoneController = TextEditingController();

    String? selectedRoomId = _rooms.isNotEmpty ? _rooms.first['_id'].toString() : null;
    if (selectedRoomId != null) {
      final r = _rooms.firstWhere((e) => e['_id'].toString() == selectedRoomId, orElse: () => null);
      if (r != null && r['monthlyRent'] != null) {
        rentController.text = r['monthlyRent'].toString();
      }
    }

    DateTime selectedJoiningDate = DateTime.now();
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
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
                        Text('Register Tenant', style: AppTextStyles.h2),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.of(modalContext).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    AppTextField(
                      controller: nameController,
                      label: 'Full Name',
                      hint: 'e.g. Rahul Sharma',
                      prefixIcon: Icons.person_outline,
                      validator: (v) => Validators.required(v, 'Full name required'),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: AppTextField(
                            controller: emailController,
                            label: 'Email Address',
                            hint: 'rahul@example.com',
                            keyboardType: TextInputType.emailAddress,
                            prefixIcon: Icons.email_outlined,
                            validator: Validators.email,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: AppTextField(
                            controller: phoneController,
                            label: 'Phone Number',
                            hint: '10 digits',
                            keyboardType: TextInputType.phone,
                            prefixIcon: Icons.phone_outlined,
                            validator: Validators.phone,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    AppTextField(
                      controller: passwordController,
                      label: 'Initial Login Password',
                      hint: 'At least 6 chars',
                      isPassword: true,
                      prefixIcon: Icons.lock_outline,
                      validator: Validators.password,
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      initialValue: selectedRoomId,
                      decoration: InputDecoration(
                        labelText: 'Assign Room',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      items: _rooms.map((r) {
                        final rMap = r as Map<String, dynamic>;
                        final num = rMap['roomNumber'] ?? 'Room';
                        final cap = rMap['capacity'] ?? 1;
                        final occ = rMap['occupiedBeds'] ?? 0;
                        final rent = rMap['monthlyRent'] ?? 0;
                        return DropdownMenuItem<String>(
                          value: rMap['_id'].toString(),
                          child: Text('$num ($occ/$cap beds) - ₹$rent/mo'),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setModalState(() {
                            selectedRoomId = val;
                            final r = _rooms.firstWhere((e) => e['_id'].toString() == val, orElse: () => null);
                            if (r != null && r['monthlyRent'] != null) {
                              rentController.text = r['monthlyRent'].toString();
                            }
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: AppTextField(
                            controller: bedController,
                            label: 'Assigned Bed',
                            hint: 'e.g. Bed 1',
                            prefixIcon: Icons.bed_outlined,
                            validator: (v) => Validators.required(v, 'Bed label required'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: AppTextField(
                            controller: rentController,
                            label: 'Monthly Rent (₹)',
                            hint: '8500',
                            keyboardType: TextInputType.number,
                            prefixIcon: Icons.currency_rupee,
                            validator: (v) => Validators.positiveNumber(v, 'Valid rent required'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    AppTextField(
                      controller: depositController,
                      label: 'Security Deposit (₹)',
                      hint: '10000',
                      keyboardType: TextInputType.number,
                      prefixIcon: Icons.account_balance_wallet_outlined,
                      validator: (v) => Validators.positiveNumber(v, 'Valid deposit required'),
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Joining Date', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      subtitle: Text(DateFormatter.formatDate(selectedJoiningDate.toIso8601String())),
                      trailing: const Icon(Icons.calendar_today_outlined, size: 20),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: modalContext,
                          initialDate: selectedJoiningDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2035),
                        );
                        if (picked != null) {
                          setModalState(() => selectedJoiningDate = picked);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    Text('Emergency Contact', style: AppTextStyles.labelMedium),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: AppTextField(
                            controller: emNameController,
                            label: 'Contact Name',
                            hint: 'e.g. Father/Guardian',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: AppTextField(
                            controller: emPhoneController,
                            label: 'Contact Phone',
                            hint: '10 digits',
                            keyboardType: TextInputType.phone,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text('Address', style: AppTextStyles.labelMedium),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: AppTextField(
                            controller: streetController,
                            label: 'Street / Area',
                            hint: 'Permanent address',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 1,
                          child: AppTextField(
                            controller: cityController,
                            label: 'City',
                            hint: 'e.g. Jaipur',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    AppButton(
                      label: 'Complete Registration',
                      isLoading: isSubmitting,
                      onPressed: () async {
                        if (!formKey.currentState!.validate()) return;
                        if (selectedRoomId == null) {
                          AppDialog.showSnackBar(modalContext, 'Please select a room', isError: true);
                          return;
                        }

                        setModalState(() => isSubmitting = true);

                        final payload = <String, dynamic>{
                          'name': nameController.text.trim(),
                          'email': emailController.text.trim().toLowerCase(),
                          'phone': phoneController.text.trim(),
                          'password': passwordController.text,
                          'roomId': selectedRoomId,
                          'assignedBed': bedController.text.trim(),
                          'monthlyRent': double.tryParse(rentController.text.trim()) ?? 0,
                          'securityDeposit': double.tryParse(depositController.text.trim()) ?? 0,
                          'joiningDate': selectedJoiningDate.toIso8601String(),
                          'address': {
                            'street': streetController.text.trim(),
                            'city': cityController.text.trim(),
                          },
                          'emergencyContact': {
                            'name': emNameController.text.trim(),
                            'phone': emPhoneController.text.trim(),
                            'relation': 'Guardian',
                          },
                        };

                        try {
                          final api = ref.read(apiClientProvider);
                          final res = await api.post(ApiEndpoints.tenants, data: payload);

                          if (modalContext.mounted) {
                            Navigator.of(modalContext).pop();
                          }
                          if (mounted) {
                            if (res.data?['success'] == true) {
                              AppDialog.showSnackBar(context, 'Tenant registered and assigned to room!');
                              _fetchTenantsAndRooms();
                            } else {
                              AppDialog.showSnackBar(
                                context,
                                res.data?['message'] ?? 'Registration failed',
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

  void _showTenantDetailsBottomSheet(Map<String, dynamic> tenant) {
    final tenantId = tenant['_id']?.toString() ?? '';
    final name = tenant['fullName'] ?? 'Unknown Tenant';
    final email = tenant['email'] ?? '-';
    final phone = tenant['phone'] ?? '-';
    final room = tenant['room'] is Map ? tenant['room'] as Map<String, dynamic> : null;
    final roomNum = room?['roomNumber'] ?? 'Not Assigned';
    final bed = tenant['assignedBed'] ?? '-';
    final rent = tenant['monthlyRent'] ?? 0;
    final deposit = tenant['securityDeposit'] ?? 0;
    final status = (tenant['status'] ?? 'ACTIVE').toString();
    final joiningDate = tenant['joiningDate'] != null ? DateFormatter.formatDate(tenant['joiningDate'].toString()) : '-';

    final address = tenant['address'] is Map ? tenant['address'] as Map<String, dynamic> : null;
    final street = address?['street'] ?? '';
    final city = address?['city'] ?? '';
    final fullAddress = [street, city].where((e) => e.toString().trim().isNotEmpty).join(', ');

    final em = tenant['emergencyContact'] is Map ? tenant['emergencyContact'] as Map<String, dynamic> : null;
    final emName = em?['name'] ?? '-';
    final emPhone = em?['phone'] ?? '-';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: AppColors.primarySurface,
                        child: Text(
                          name.isNotEmpty ? name[0].toUpperCase() : 'T',
                          style: AppTextStyles.h2.copyWith(color: AppColors.primary),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name, style: AppTextStyles.h2),
                          Text('$phone • $email', style: AppTextStyles.bodySmall),
                        ],
                      ),
                    ],
                  ),
                  StatusBadge(status: status),
                ],
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(12)),
                child: Column(
                  children: [
                    _buildRow('Assigned Room & Bed', 'Room $roomNum ($bed)'),
                    const Divider(height: 16, color: AppColors.divider),
                    _buildRow('Monthly Rent', CurrencyFormatter.format(rent)),
                    const Divider(height: 16, color: AppColors.divider),
                    _buildRow('Security Deposit', CurrencyFormatter.format(deposit)),
                    const Divider(height: 16, color: AppColors.divider),
                    _buildRow('Joining Date', joiningDate),
                    if (fullAddress.isNotEmpty) ...[
                      const Divider(height: 16, color: AppColors.divider),
                      _buildRow('Address', fullAddress),
                    ],
                    if (emName != '-') ...[
                      const Divider(height: 16, color: AppColors.divider),
                      _buildRow('Emergency Contact', '$emName ($emPhone)'),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: const BorderSide(color: AppColors.primary),
                        foregroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                      label: const Text('Transfer Room'),
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        _showTransferRoomDialog(tenantId, name, room?['_id']?.toString());
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: const BorderSide(color: AppColors.error),
                        foregroundColor: AppColors.error,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.logout_rounded, size: 18),
                      label: const Text('Vacate Tenant'),
                      onPressed: () async {
                        Navigator.of(ctx).pop();
                        final confirm = await AppDialog.showConfirmation(
                          context: context,
                          title: 'Vacate Tenant $name',
                          content: 'Are you sure you want to mark $name as vacated? Their assigned bed in Room $roomNum will be released and marked available.',
                          confirmText: 'Mark Vacated',
                          isDestructive: true,
                        );
                        if (confirm == true && mounted) {
                          try {
                            final api = ref.read(apiClientProvider);
                            final res = await api.put(ApiEndpoints.vacateTenant(tenantId));
                            if (mounted) {
                              if (res.data?['success'] == true) {
                                AppDialog.showSnackBar(context, '$name marked as vacated. Bed released.');
                                _fetchTenantsAndRooms();
                              } else {
                                AppDialog.showSnackBar(context, res.data?['message'] ?? 'Action failed', isError: true);
                              }
                            }
                          } catch (e) {
                            if (mounted) AppDialog.showSnackBar(context, e.toString(), isError: true);
                          }
                        }
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showTransferRoomDialog(String tenantId, String tenantName, String? currentRoomId) {
    String? newRoomId = _rooms.where((r) => r['_id'].toString() != currentRoomId).isNotEmpty
        ? _rooms.firstWhere((r) => r['_id'].toString() != currentRoomId)['_id'].toString()
        : null;

    final bedController = TextEditingController(text: 'Bed 1');
    final rentController = TextEditingController();

    if (newRoomId != null) {
      final r = _rooms.firstWhere((e) => e['_id'].toString() == newRoomId, orElse: () => null);
      if (r != null && r['monthlyRent'] != null) {
        rentController.text = r['monthlyRent'].toString();
      }
    }

    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (modalContext, setModalState) {
          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 24,
              bottom: MediaQuery.of(modalContext).viewInsets.bottom + 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Transfer Room for $tenantName', style: AppTextStyles.h2),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: newRoomId,
                  decoration: InputDecoration(
                    labelText: 'Select New Room',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  items: _rooms.where((r) => r['_id'].toString() != currentRoomId).map((r) {
                    final num = r['roomNumber'] ?? 'Room';
                    final cap = r['capacity'] ?? 1;
                    final occ = r['occupiedBeds'] ?? 0;
                    final rent = r['monthlyRent'] ?? 0;
                    return DropdownMenuItem<String>(
                      value: r['_id'].toString(),
                      child: Text('$num ($occ/$cap beds) - ₹$rent'),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setModalState(() {
                        newRoomId = val;
                        final r = _rooms.firstWhere((e) => e['_id'].toString() == val, orElse: () => null);
                        if (r != null && r['monthlyRent'] != null) {
                          rentController.text = r['monthlyRent'].toString();
                        }
                      });
                    }
                  },
                ),
                const SizedBox(height: 12),
                AppTextField(
                  controller: bedController,
                  label: 'New Assigned Bed',
                  hint: 'e.g. Bed 2',
                  prefixIcon: Icons.bed_outlined,
                ),
                const SizedBox(height: 12),
                AppTextField(
                  controller: rentController,
                  label: 'New Monthly Rent (₹)',
                  hint: '8500',
                  keyboardType: TextInputType.number,
                  prefixIcon: Icons.currency_rupee,
                ),
                const SizedBox(height: 24),
                AppButton(
                  label: 'Confirm Transfer',
                  isLoading: isSubmitting,
                  onPressed: () async {
                    if (newRoomId == null) {
                      AppDialog.showSnackBar(modalContext, 'Please select a new room', isError: true);
                      return;
                    }
                    setModalState(() => isSubmitting = true);

                    try {
                      final api = ref.read(apiClientProvider);
                      final res = await api.put(
                        ApiEndpoints.changeRoom(tenantId),
                        data: {
                          'newRoomId': newRoomId,
                          'assignedBed': bedController.text.trim(),
                          'monthlyRent': double.tryParse(rentController.text.trim()) ?? 0,
                        },
                      );

                      if (modalContext.mounted) {
                        Navigator.of(modalContext).pop();
                      }
                      if (mounted) {
                        if (res.data?['success'] == true) {
                          AppDialog.showSnackBar(context, 'Room transfer completed successfully!');
                          _fetchTenantsAndRooms();
                        } else {
                          AppDialog.showSnackBar(context, res.data?['message'] ?? 'Transfer failed', isError: true);
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
          );
        },
      ),
    );
  }

  Widget _buildRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: AppTextStyles.bodySmall),
        Flexible(child: Text(value, style: AppTextStyles.labelLarge, textAlign: TextAlign.end)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Tenants Directory'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _fetchTenantsAndRooms,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showRegisterTenantDialog,
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text('Register Tenant'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Search & Filter header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Colors.white,
            child: Column(
              children: [
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Search by tenant name, phone, or room...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                  ),
                  onChanged: (val) => setState(() => _searchQuery = val.trim()),
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip('All Tenants', 'ALL'),
                      const SizedBox(width: 8),
                      _buildFilterChip('Active', 'ACTIVE'),
                      const SizedBox(width: 8),
                      _buildFilterChip('Notice', 'NOTICE_PERIOD'),
                      const SizedBox(width: 8),
                      _buildFilterChip('Vacated', 'VACATED'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),

          // Content
          Expanded(
            child: _isLoading
                ? const AppLoader(message: 'Loading tenants...')
                : _error != null
                    ? ErrorStateView(
                        message: _error!,
                        onRetry: _fetchTenantsAndRooms,
                      )
                    : _filteredTenants.isEmpty
                        ? EmptyStateView(
                            title: 'No Tenants Found',
                            description: _searchQuery.isNotEmpty
                                ? 'No tenants match your search query.'
                                : 'No tenants registered yet. Tap "Register Tenant" to onboard one.',
                            icon: Icons.people_outline,
                            actionText: _searchQuery.isNotEmpty ? 'Clear Search' : 'Register Tenant',
                            onAction: () {
                              if (_searchQuery.isNotEmpty) {
                                setState(() => _searchQuery = '');
                              } else {
                                _showRegisterTenantDialog();
                              }
                            },
                          )
                        : RefreshIndicator(
                            onRefresh: _fetchTenantsAndRooms,
                            child: ListView.separated(
                              padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 80),
                              itemCount: _filteredTenants.length,
                              separatorBuilder: (context, index) => const SizedBox(height: 12),
                              itemBuilder: (context, index) {
                                final tenant = _filteredTenants[index] as Map<String, dynamic>;
                                return _buildTenantCard(tenant);
                              },
                            ),
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

  Widget _buildTenantCard(Map<String, dynamic> t) {
    final name = t['fullName'] ?? 'Unknown Tenant';
    final phone = t['phone'] ?? '-';
    final room = t['room'] is Map ? t['room'] as Map<String, dynamic> : null;
    final roomNum = room?['roomNumber'] ?? '-';
    final bed = t['assignedBed'] ?? '-';
    final rent = t['monthlyRent'] ?? 0;
    final status = (t['status'] ?? 'ACTIVE').toString();
    final joiningDate = t['joiningDate'] != null ? DateFormatter.formatDate(t['joiningDate'].toString()) : '-';

    final initials = name.isNotEmpty
        ? name.trim().split(' ').map((p) => p.isNotEmpty ? p[0] : '').take(2).join('').toUpperCase()
        : 'T';

    return AppCard(
      padding: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showTenantDetailsBottomSheet(t),
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
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: AppColors.primarySurface,
                        child: Text(
                          initials,
                          style: AppTextStyles.h3.copyWith(color: AppColors.primary),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name, style: AppTextStyles.h3),
                          Text(phone, style: AppTextStyles.bodySmall),
                        ],
                      ),
                    ],
                  ),
                  StatusBadge(status: status),
                ],
              ),
              const SizedBox(height: 14),
              const Divider(height: 1, color: AppColors.divider),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Room / Bed', style: AppTextStyles.bodySmall),
                      Text(
                        'Room $roomNum (Bed $bed)',
                        style: AppTextStyles.labelLarge,
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text('Joined', style: AppTextStyles.bodySmall),
                      Text(joiningDate, style: AppTextStyles.labelLarge),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('Monthly Rent', style: AppTextStyles.bodySmall),
                      Text(
                        CurrencyFormatter.format(rent),
                        style: AppTextStyles.labelLarge.copyWith(color: AppColors.primary),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
