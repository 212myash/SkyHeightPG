import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_loader.dart';
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

          // Room List
          Expanded(child: _buildList()),
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
      onSelected: (_) => setState(() => _filterStatus = value),
    );
  }

  Widget _buildList() {
    if (_isLoading) {
      return const Center(child: AppLoader(text: 'Loading rooms...'));
    }

    if (_error != null) {
      return ErrorStateView(message: _error!, onRetry: _fetchRooms);
    }

    final list = _filteredRooms;
    if (list.isEmpty) {
      return EmptyStateView(
        icon: Icons.meeting_room_outlined,
        title: 'No Rooms Found',
        description: _searchQuery.isNotEmpty
            ? 'No rooms matched your search criteria.'
            : 'No rooms added yet.',
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchRooms,
      color: AppColors.primary,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: list.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final room = list[index] as Map<String, dynamic>;
          final roomNumber = room['roomNumber'] ?? 'Unknown';
          final floor = room['floor'] ?? '-';
          final type = room['roomType'] ?? 'Standard';
          final rent = room['monthlyRent'] ?? 0;
          final capacity = (room['capacity'] ?? 0) as num;
          final occupied = (room['occupiedBeds'] ?? 0) as num;
          final status = (room['status'] ?? 'AVAILABLE').toString();
          final amenities = (room['amenities'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];

          return AppCard(
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
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('Bed Occupancy', style: AppTextStyles.bodySmall),
                        Text(
                          '$occupied / $capacity Beds',
                          style: AppTextStyles.labelLarge,
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
          );
        },
      ),
    );
  }
}
