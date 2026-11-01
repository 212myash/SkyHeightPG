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
import '../../../core/widgets/error_state_view.dart';
import '../../../core/widgets/status_badge.dart';
import '../../auth/providers/auth_provider.dart';

class OwnerMeterScreen extends ConsumerStatefulWidget {
  const OwnerMeterScreen({super.key});

  @override
  ConsumerState<OwnerMeterScreen> createState() => _OwnerMeterScreenState();
}

class _OwnerMeterScreenState extends ConsumerState<OwnerMeterScreen> {
  bool _isLoading = true;
  String? _error;
  String _selectedMonth = '';
  Map<String, dynamic> _usageReport = {};
  List<dynamic> _rooms = [];
  double _electricityRate = 10.0;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    _fetchData();
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
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final api = ref.read(apiClientProvider);
      final usageRes = await api.get('${ApiEndpoints.monthlyUsage}?month=$_selectedMonth');
      final roomsRes = await api.get(ApiEndpoints.rooms);
      final settingsRes = await api.get(ApiEndpoints.settings);

      if (mounted) {
        if (usageRes.data?['success'] == true) {
          final resData = usageRes.data;
          _usageReport = {
            'totalUnits': resData['totalUnitsConsumed'] ?? 0,
            'totalAmount': resData['totalElectricityAmount'] ?? 0,
            'readings': (resData['data'] as List<dynamic>?) ?? [],
          };
        }
        _rooms = (roomsRes.data?['data'] as List<dynamic>?) ?? [];
        if (settingsRes.data?['data']?['electricityRatePerUnit'] != null) {
          _electricityRate = (settingsRes.data['data']['electricityRatePerUnit'] as num).toDouble();
        }
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

  Future<void> _showAddReadingDialog() async {
    if (_rooms.isEmpty) {
      AppDialog.showSnackBar(context, 'No rooms registered yet. Please add a room first.', isError: true);
      return;
    }

    final formKey = GlobalKey<FormState>();
    String selectedRoomId = _rooms.first['_id'].toString();
    final currentController = TextEditingController();
    final remarksController = TextEditingController();
    double previousReading = 0.0;
    bool isFetchingPrev = true;
    bool isSubmitting = false;

    // Helper to fetch last reading for selected room
    Future<void> fetchPrev(StateSetter setModalState, String roomId) async {
      setModalState(() => isFetchingPrev = true);
      try {
        final api = ref.read(apiClientProvider);
        final res = await api.get(ApiEndpoints.roomMeterHistory(roomId));
        if (res.data?['success'] == true) {
          final history = (res.data['data'] as List<dynamic>?) ?? [];
          if (history.isNotEmpty) {
            previousReading = (history.first['currentReading'] as num?)?.toDouble() ?? 0.0;
          } else {
            previousReading = 0.0;
          }
        }
      } catch (_) {
        previousReading = 0.0;
      } finally {
        setModalState(() => isFetchingPrev = false);
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (modalContext, setModalState) {
          if (isFetchingPrev) {
            fetchPrev(setModalState, selectedRoomId);
          }

          final currentVal = double.tryParse(currentController.text.trim()) ?? previousReading;
          final units = (currentVal >= previousReading) ? (currentVal - previousReading) : 0.0;
          final estAmount = units * _electricityRate;

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
                        Text('Log Meter Reading', style: AppTextStyles.h2),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.of(modalContext).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: selectedRoomId,
                      decoration: InputDecoration(
                        labelText: 'Select Room',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      items: _rooms.map((r) {
                        final num = r['roomNumber'] ?? 'Room';
                        final floor = r['floor'] ?? '-';
                        return DropdownMenuItem<String>(
                          value: r['_id'].toString(),
                          child: Text('Room $num (Floor $floor)'),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setModalState(() {
                            selectedRoomId = val;
                            isFetchingPrev = true;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Previous Meter Reading', style: AppTextStyles.bodySmall),
                              const SizedBox(height: 2),
                              Text(
                                isFetchingPrev ? 'Fetching...' : '${previousReading.toStringAsFixed(1)} kWh',
                                style: AppTextStyles.labelLarge,
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text('Rate per Unit', style: AppTextStyles.bodySmall),
                              const SizedBox(height: 2),
                              Text('₹$_electricityRate / Unit', style: AppTextStyles.labelLarge.copyWith(color: AppColors.primary)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    AppTextField(
                      controller: currentController,
                      label: 'Current Meter Reading (kWh)',
                      hint: 'e.g. ${(previousReading + 50).toStringAsFixed(0)}',
                      keyboardType: TextInputType.number,
                      prefixIcon: Icons.speed_rounded,
                      validator: (v) {
                        final numVal = double.tryParse(v ?? '');
                        if (numVal == null) return 'Please enter a valid reading';
                        if (numVal < previousReading) {
                          return 'Cannot be less than previous (${previousReading.toStringAsFixed(1)})';
                        }
                        return null;
                      },
                      onChanged: (_) => setModalState(() {}),
                    ),
                    const SizedBox(height: 14),
                    // Live Calculation Display
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.primarySurface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Column(
                            children: [
                              Text('Units Consumed', style: AppTextStyles.bodySmall),
                              const SizedBox(height: 2),
                              Text('${units.toStringAsFixed(1)} Units', style: AppTextStyles.h3.copyWith(color: AppColors.primary)),
                            ],
                          ),
                          Column(
                            children: [
                              Text('Electricity Charge', style: AppTextStyles.bodySmall),
                              const SizedBox(height: 2),
                              Text(CurrencyFormatter.format(estAmount), style: AppTextStyles.h3.copyWith(color: AppColors.primary)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    AppTextField(
                      controller: remarksController,
                      label: 'Remarks (Optional)',
                      hint: 'e.g. End of month reading',
                      prefixIcon: Icons.notes_rounded,
                    ),
                    const SizedBox(height: 24),
                    AppButton(
                      label: 'Save Meter Reading',
                      isLoading: isSubmitting,
                      onPressed: () async {
                        if (!formKey.currentState!.validate()) return;
                        setModalState(() => isSubmitting = true);

                        final payload = <String, dynamic>{
                          'roomId': selectedRoomId,
                          'currentReading': double.parse(currentController.text.trim()),
                          'readingMonth': _selectedMonth,
                          'ratePerUnit': _electricityRate,
                          'remarks': remarksController.text.trim(),
                        };

                        try {
                          final api = ref.read(apiClientProvider);
                          final res = await api.post(ApiEndpoints.meters, data: payload);

                          if (modalContext.mounted) {
                            Navigator.of(modalContext).pop();
                          }
                          if (mounted) {
                            if (res.data?['success'] == true) {
                              AppDialog.showSnackBar(context, 'Meter reading recorded successfully!');
                              _fetchData();
                            } else {
                              AppDialog.showSnackBar(
                                context,
                                res.data?['message'] ?? 'Failed to record meter reading',
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

  void _showRoomHistorySheet(Map<String, dynamic> room) {
    final roomId = room['_id']?.toString() ?? '';
    final roomNum = room['roomNumber'] ?? 'Unknown';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => FutureBuilder(
        future: ref.read(apiClientProvider).get(ApiEndpoints.roomMeterHistory(roomId)),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Padding(
              padding: EdgeInsets.all(40),
              child: AppLoader(message: 'Loading reading history...'),
            );
          }

          if (snapshot.hasError) {
            return Padding(
              padding: const EdgeInsets.all(24),
              child: ErrorStateView(message: snapshot.error.toString(), onRetry: () {}),
            );
          }

          final data = snapshot.data?.data;
          final history = (data?['data'] as List<dynamic>?) ?? [];

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Room $roomNum Meter History', style: AppTextStyles.h2),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (history.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: Center(child: Text('No meter readings recorded for this room yet.')),
                  )
                else
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: history.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final item = history[index] as Map<String, dynamic>;
                        final month = item['readingMonth'] ?? '-';
                        final prev = item['previousReading'] ?? 0;
                        final curr = item['currentReading'] ?? 0;
                        final units = item['unitsConsumed'] ?? 0;
                        final amt = item['electricityAmount'] ?? 0;
                        final date = item['readingDate'] != null ? DateFormatter.formatDate(item['readingDate'].toString()) : '-';

                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(month, style: AppTextStyles.h3),
                                  Text(CurrencyFormatter.format(amt), style: AppTextStyles.h3.copyWith(color: AppColors.primary)),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Reading: $prev → $curr kWh ($units Units)', style: AppTextStyles.bodySmall),
                                  Text(date, style: AppTextStyles.bodySmall.copyWith(fontSize: 11)),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalUnits = _usageReport['totalUnits'] ?? 0;
    final totalAmount = _usageReport['totalAmount'] ?? 0;
    final readRooms = (_usageReport['readings'] as List<dynamic>?) ?? [];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Electricity Sub-Meters'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _fetchData,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddReadingDialog,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Log Reading'),
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
                  _buildHeaderMetric('Total Usage', '$totalUnits kWh', Icons.bolt_rounded, AppColors.warning),
                  _buildHeaderMetric('Total Cost', CurrencyFormatter.format(totalAmount), Icons.currency_rupee, AppColors.primary),
                  _buildHeaderMetric('PG Rate', '₹$_electricityRate / Unit', Icons.tune_rounded, AppColors.info),
                ],
              ),
            ),
          ),

          // Rooms Sub-meter List
          Expanded(
            child: _isLoading
                ? const AppLoader(message: 'Loading electricity usage...')
                : _error != null
                    ? ErrorStateView(message: _error!, onRetry: _fetchData)
                    : _rooms.isEmpty
                        ? const EmptyStateView(
                            title: 'No Rooms Registered',
                            description: 'Add rooms to begin monitoring electricity sub-meters.',
                            icon: Icons.bolt_rounded,
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.only(left: 16, right: 16, bottom: 80),
                            itemCount: _rooms.length,
                            separatorBuilder: (context, index) => const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final room = _rooms[index] as Map<String, dynamic>;
                              final roomId = room['_id']?.toString();
                              final roomNum = room['roomNumber'] ?? 'Unknown';
                              final floor = room['floor'] ?? '-';

                              // Check if reading exists for this month
                              final match = readRooms.firstWhere(
                                (r) => r['room']?['_id']?.toString() == roomId || r['room']?.toString() == roomId,
                                orElse: () => null,
                              );

                              final hasReading = match != null;
                              final units = match?['unitsConsumed'] ?? 0;
                              final amt = match?['electricityAmount'] ?? 0;

                              return AppCard(
                                padding: EdgeInsets.zero,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(16),
                                  onTap: () => _showRoomHistorySheet(room),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(10),
                                              decoration: BoxDecoration(
                                                color: hasReading ? AppColors.primarySurface : AppColors.background,
                                                borderRadius: BorderRadius.circular(10),
                                              ),
                                              child: Icon(
                                                Icons.speed_rounded,
                                                color: hasReading ? AppColors.primary : AppColors.textLight,
                                                size: 22,
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text('Room $roomNum', style: AppTextStyles.h3),
                                                Text('Floor $floor', style: AppTextStyles.bodySmall),
                                              ],
                                            ),
                                          ],
                                        ),
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          children: [
                                            if (hasReading) ...[
                                              Text(CurrencyFormatter.format(amt), style: AppTextStyles.labelLarge.copyWith(color: AppColors.primary)),
                                              Text('$units Units Consumed', style: AppTextStyles.bodySmall),
                                            ] else ...[
                                              const StatusBadge(status: 'pending', customLabel: 'Pending Reading'),
                                            ],
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
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
}
