import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/utils/currency_formatter.dart';
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

class OwnerRoomsScreen extends ConsumerStatefulWidget {
  const OwnerRoomsScreen({super.key});

  @override
  ConsumerState<OwnerRoomsScreen> createState() => _OwnerRoomsScreenState();
}

class _OwnerRoomsScreenState extends ConsumerState<OwnerRoomsScreen> {
  bool _isLoading = true;
  String? _error;
  List<dynamic> _rooms = [];
  String _searchQuery = '';
  String _filterStatus = 'ALL';

  @override
  void initState() {
    super.initState();
    _fetchRooms();
  }

  Future<void> _fetchRooms() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final api = ref.read(apiClientProvider);
      final response = await api.get(ApiEndpoints.rooms);
      if (mounted) {
        if (response.data != null && response.data['success'] == true) {
          setState(() {
            _rooms = response.data['data'] as List<dynamic>? ?? [];
            _isLoading = false;
          });
        } else {
          setState(() {
            _error = response.data?['message'] ?? 'Failed to load rooms';
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

  List<dynamic> get _filteredRooms {
    return _rooms.where((room) {
      final roomMap = room as Map<String, dynamic>;
      final roomNum = (roomMap['roomNumber'] ?? '').toString().toLowerCase();
      final floor = (roomMap['floor'] ?? '').toString().toLowerCase();
      final status = (roomMap['status'] ?? '').toString().toUpperCase();

      final matchesQuery = _searchQuery.isEmpty ||
          roomNum.contains(_searchQuery.toLowerCase()) ||
          floor.contains(_searchQuery.toLowerCase());

      final matchesStatus = _filterStatus == 'ALL' || status == _filterStatus;

      return matchesQuery && matchesStatus;
    }).toList();
  }

  void _showAddEditRoomDialog({Map<String, dynamic>? roomToEdit}) {
    final isEditing = roomToEdit != null;
    final formKey = GlobalKey<FormState>();
    final roomNumberController = TextEditingController(text: roomToEdit?['roomNumber']?.toString() ?? '');
    final floorController = TextEditingController(text: roomToEdit?['floor']?.toString() ?? '1');
    final rentController = TextEditingController(text: roomToEdit?['monthlyRent']?.toString() ?? '');
    final capacityController = TextEditingController(text: roomToEdit?['capacity']?.toString() ?? '2');

    String selectedType = roomToEdit?['roomType']?.toString().toLowerCase() ?? 'double';
    String selectedStatus = roomToEdit?['status']?.toString().toLowerCase() ?? 'available';

    final initialAmenities = (roomToEdit?['amenities'] as List<dynamic>?)?.map((e) => e.toString()).toList() ??
        ['WiFi', 'Geyser', 'Study Table'];
    final selectedAmenities = List<String>.from(initialAmenities);

    const allAmenities = [
      'AC',
      'WiFi',
      'Geyser',
      'Study Table',
      'Balcony',
      'Attached Washroom',
      'Cupboard',
      'TV',
      'Power Backup'
    ];

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
                        Text(
                          isEditing ? 'Edit Room ${roomToEdit['roomNumber']}' : 'Add New Room',
                          style: AppTextStyles.h2,
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.of(modalContext).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: AppTextField(
                            controller: roomNumberController,
                            label: 'Room Number',
                            hint: 'e.g. R103',
                            prefixIcon: Icons.door_front_door_outlined,
                            validator: (v) => Validators.required(v, 'Room number required'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 1,
                          child: AppTextField(
                            controller: floorController,
                            label: 'Floor',
                            hint: '1',
                            keyboardType: TextInputType.number,
                            prefixIcon: Icons.layers_outlined,
                            validator: (v) => Validators.positiveNumber(v, 'Floor required'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      initialValue: selectedType,
                      decoration: InputDecoration(
                        labelText: 'Room Type',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'single', child: Text('Single Sharing')),
                        DropdownMenuItem(value: 'double', child: Text('Double Sharing')),
                        DropdownMenuItem(value: 'triple', child: Text('Triple Sharing')),
                        DropdownMenuItem(value: 'other', child: Text('Other / Dormitory')),
                      ],
                      onChanged: (val) {
                        if (val != null) setModalState(() => selectedType = val);
                      },
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
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
                        const SizedBox(width: 12),
                        Expanded(
                          child: AppTextField(
                            controller: capacityController,
                            label: 'Bed Capacity',
                            hint: '2',
                            keyboardType: TextInputType.number,
                            prefixIcon: Icons.bed_outlined,
                            validator: (v) => Validators.positiveNumber(v, 'Valid capacity required'),
                          ),
                        ),
                      ],
                    ),
                    if (isEditing) ...[
                      const SizedBox(height: 14),
                      DropdownButtonFormField<String>(
                        initialValue: selectedStatus,
                        decoration: InputDecoration(
                          labelText: 'Room Status',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'available', child: Text('Available')),
                          DropdownMenuItem(value: 'occupied', child: Text('Occupied')),
                          DropdownMenuItem(value: 'maintenance', child: Text('Maintenance')),
                        ],
                        onChanged: (val) {
                          if (val != null) setModalState(() => selectedStatus = val);
                        },
                      ),
                    ],
                    const SizedBox(height: 16),
                    Text('Amenities', style: AppTextStyles.labelMedium),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: allAmenities.map((amenity) {
                        final isSelected = selectedAmenities.contains(amenity);
                        return FilterChip(
                          label: Text(amenity, style: TextStyle(fontSize: 12, color: isSelected ? AppColors.primary : AppColors.textPrimary)),
                          selected: isSelected,
                          selectedColor: AppColors.primarySurface,
                          checkmarkColor: AppColors.primary,
                          onSelected: (selected) {
                            setModalState(() {
                              if (selected) {
                                selectedAmenities.add(amenity);
                              } else {
                                selectedAmenities.remove(amenity);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),
                    AppButton(
                      label: isEditing ? 'Update Room' : 'Create Room',
                      isLoading: isSubmitting,
                      onPressed: () async {
                        if (!formKey.currentState!.validate()) return;
                        setModalState(() => isSubmitting = true);

                        final payload = <String, dynamic>{
                          'roomNumber': roomNumberController.text.trim().toUpperCase(),
                          'floor': int.tryParse(floorController.text.trim()) ?? 1,
                          'roomType': selectedType,
                          'monthlyRent': double.tryParse(rentController.text.trim()) ?? 0,
                          'capacity': int.tryParse(capacityController.text.trim()) ?? 1,
                          'amenities': selectedAmenities,
                        };
                        if (isEditing) {
                          payload['status'] = selectedStatus;
                        }

                        try {
                          final api = ref.read(apiClientProvider);
                          final res = isEditing
                              ? await api.put(ApiEndpoints.roomById(roomToEdit['_id'].toString()), data: payload)
                              : await api.post(ApiEndpoints.rooms, data: payload);

                          if (modalContext.mounted) {
                            Navigator.of(modalContext).pop();
                          }
                          if (mounted) {
                            if (res.data?['success'] == true) {
                              AppDialog.showSnackBar(
                                context,
                                isEditing ? 'Room updated successfully!' : 'Room created successfully!',
                              );
                              _fetchRooms();
                            } else {
                              AppDialog.showSnackBar(
                                context,
                                res.data?['message'] ?? 'Failed to save room',
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

  void _showRoomDetailsBottomSheet(Map<String, dynamic> room) {
    final roomId = room['_id']?.toString() ?? '';
    final roomNumber = room['roomNumber'] ?? 'Unknown';
    final floor = room['floor'] ?? '-';
    final type = (room['roomType'] ?? 'Single').toString().toUpperCase();
    final rent = room['monthlyRent'] ?? 0;
    final capacity = (room['capacity'] ?? 0) as num;
    final occupied = (room['occupiedBeds'] ?? 0) as num;
    final available = capacity - occupied;
    final status = (room['status'] ?? 'AVAILABLE').toString();
    final amenities = (room['amenities'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: AppColors.primarySurface, borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.room_preferences, color: AppColors.primary, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Room $roomNumber', style: AppTextStyles.h2),
                        Text('Floor $floor • $type', style: AppTextStyles.bodySmall),
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
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatItem('Monthly Rent', CurrencyFormatter.format(rent), AppColors.primary),
                  _buildStatItem('Occupied', '$occupied Beds', occupied > 0 ? AppColors.warning : AppColors.textPrimary),
                  _buildStatItem('Available', '$available Beds', available > 0 ? AppColors.success : AppColors.textLight),
                ],
              ),
            ),
            if (amenities.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text('Room Amenities', style: AppTextStyles.labelMedium),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: amenities.map((a) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Text(a, style: AppTextStyles.bodySmall.copyWith(fontSize: 12)),
                  );
                }).toList(),
              ),
            ],
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
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text('Edit Room'),
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      _showAddEditRoomDialog(roomToEdit: room);
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
                    icon: const Icon(Icons.delete_outline_rounded, size: 18),
                    label: const Text('Deactivate'),
                    onPressed: () async {
                      Navigator.of(ctx).pop();
                      final confirm = await AppDialog.showConfirmation(
                        context: context,
                        title: 'Deactivate Room $roomNumber',
                        content: 'Are you sure you want to deactivate Room $roomNumber? Rooms with active tenants or pending records cannot be deleted.',
                        confirmText: 'Deactivate',
                        isDestructive: true,
                      );
                      if (confirm == true && mounted) {
                        try {
                          final api = ref.read(apiClientProvider);
                          final res = await api.delete(ApiEndpoints.roomById(roomId));
                          if (mounted) {
                            if (res.data?['success'] == true) {
                              AppDialog.showSnackBar(context, 'Room $roomNumber deactivated.');
                              _fetchRooms();
                            } else {
                              AppDialog.showSnackBar(context, res.data?['message'] ?? 'Action blocked', isError: true);
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
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: AppTextStyles.bodySmall),
        const SizedBox(height: 4),
        Text(value, style: AppTextStyles.h3.copyWith(color: color)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Rooms Management'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _fetchRooms,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddEditRoomDialog(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Room'),
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
                    hintText: 'Search by room number or floor...',
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
                      _buildFilterChip('All', 'ALL'),
                      const SizedBox(width: 8),
                      _buildFilterChip('Available', 'AVAILABLE'),
                      const SizedBox(width: 8),
                      _buildFilterChip('Occupied', 'OCCUPIED'),
                      const SizedBox(width: 8),
                      _buildFilterChip('Maintenance', 'MAINTENANCE'),
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
                ? const AppLoader(message: 'Loading rooms...')
                : _error != null
                    ? ErrorStateView(
                        message: _error!,
                        onRetry: _fetchRooms,
                      )
                    : _filteredRooms.isEmpty
                        ? EmptyStateView(
                            title: 'No Rooms Found',
                            description: _searchQuery.isNotEmpty
                                ? 'No rooms match your search query.'
                                : 'No rooms registered yet. Tap "Add Room" to create one.',
                            icon: Icons.meeting_room_outlined,
                            actionText: _searchQuery.isNotEmpty ? 'Clear Search' : 'Add Room',
                            onAction: () {
                              if (_searchQuery.isNotEmpty) {
                                setState(() => _searchQuery = '');
                              } else {
                                _showAddEditRoomDialog();
                              }
                            },
                          )
                        : RefreshIndicator(
                            onRefresh: _fetchRooms,
                            child: ListView.separated(
                              padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 80),
                              itemCount: _filteredRooms.length,
                              separatorBuilder: (context, index) => const SizedBox(height: 12),
                              itemBuilder: (context, index) {
                                final room = _filteredRooms[index] as Map<String, dynamic>;
                                return _buildRoomCard(room);
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

  Widget _buildRoomCard(Map<String, dynamic> room) {
    final roomNumber = room['roomNumber'] ?? 'Unknown';
    final floor = room['floor'] ?? '-';
    final type = (room['roomType'] ?? 'Single').toString().toUpperCase();
    final rent = room['monthlyRent'] ?? 0;
    final capacity = (room['capacity'] ?? 0) as num;
    final occupied = (room['occupiedBeds'] ?? 0) as num;
    final available = capacity - occupied;
    final status = (room['status'] ?? 'AVAILABLE').toString();
    final amenities = (room['amenities'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];

    return AppCard(
      padding: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showRoomDetailsBottomSheet(room),
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
                        decoration: BoxDecoration(
                          color: AppColors.primarySurface,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.room_preferences, color: AppColors.primary, size: 20),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Room $roomNumber', style: AppTextStyles.h3),
                          Text('Floor $floor • $type', style: AppTextStyles.bodySmall),
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
                      Text('Monthly Rent', style: AppTextStyles.bodySmall),
                      Text(
                        CurrencyFormatter.format(rent),
                        style: AppTextStyles.labelLarge.copyWith(color: AppColors.primary),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text('Occupied', style: AppTextStyles.bodySmall),
                      Text(
                        '$occupied / $capacity Beds',
                        style: AppTextStyles.labelLarge,
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('Available', style: AppTextStyles.bodySmall),
                      Text(
                        '$available Beds',
                        style: AppTextStyles.labelLarge.copyWith(
                          color: available > 0 ? AppColors.success : AppColors.textLight,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              if (amenities.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: amenities.map((a) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Text(
                        a,
                        style: AppTextStyles.bodySmall.copyWith(fontSize: 11),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
