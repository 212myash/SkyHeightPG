import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_loader.dart';
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
  String _searchQuery = '';
  String _filterStatus = 'ALL';

  @override
  void initState() {
    super.initState();
    _fetchTenants();
  }

  Future<void> _fetchTenants() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final api = ref.read(apiClientProvider);
      final response = await api.get(ApiEndpoints.tenants);
      if (mounted) {
        if (response.data != null && response.data['success'] == true) {
          setState(() {
            _tenants = response.data['data'] as List<dynamic>? ?? [];
            _isLoading = false;
          });
        } else {
          setState(() {
            _error = response.data?['message'] ?? 'Failed to load tenants';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Tenants Directory'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _fetchTenants,
          ),
        ],
      ),
      body: Column(
        children: [
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
                      _buildFilterChip('Notice', 'NOTICE'),
                      const SizedBox(width: 8),
                      _buildFilterChip('Vacated', 'VACATED'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
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
      return const Center(child: AppLoader(text: 'Loading tenants...'));
    }

    if (_error != null) {
      return ErrorStateView(message: _error!, onRetry: _fetchTenants);
    }

    final list = _filteredTenants;
    if (list.isEmpty) {
      return EmptyStateView(
        icon: Icons.people_outline_rounded,
        title: 'No Tenants Found',
        description: _searchQuery.isNotEmpty
            ? 'No tenants matched your query.'
            : 'No tenants enrolled yet.',
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchTenants,
      color: AppColors.primary,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: list.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final t = list[index] as Map<String, dynamic>;
          final name = t['fullName'] ?? 'Unnamed Tenant';
          final phone = t['phone'] ?? '-';
          final roomObj = t['room'];
          final roomNum = roomObj is Map ? (roomObj['roomNumber'] ?? '-') : '-';
          final bed = t['assignedBed'] ?? '-';
          final rent = t['monthlyRent'] ?? 0;
          final status = (t['status'] ?? 'ACTIVE').toString();
          final joiningDate = t['joiningDate'] != null ? DateFormatter.formatDate(t['joiningDate'].toString()) : '-';

          final initials = name.isNotEmpty
              ? name.trim().split(' ').map((p) => p.isNotEmpty ? p[0] : '').take(2).join('').toUpperCase()
              : 'T';

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
          );
        },
      ),
    );
  }
}
