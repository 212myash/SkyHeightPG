import 'package:intl/intl.dart';

class OccupancyHistoryItem {
  final String id;
  final String roomId;
  final String roomNumber;
  final DateTime joiningDate;
  final DateTime? leavingDate;
  final String occupancyStatus;
  final double monthlyRentSnapshot;
  final String reason;
  final DateTime? createdAt;

  OccupancyHistoryItem({
    required this.id,
    required this.roomId,
    required this.roomNumber,
    required this.joiningDate,
    this.leavingDate,
    required this.occupancyStatus,
    this.monthlyRentSnapshot = 0.0,
    this.reason = '',
    this.createdAt,
  });

  bool get isActive => occupancyStatus.toLowerCase() == 'active';
  bool get isTransferred => occupancyStatus.toLowerCase() == 'transferred';
  bool get isVacated => occupancyStatus.toLowerCase() == 'vacated';

  String get formattedJoiningDate {
    return DateFormat('dd MMM yyyy').format(joiningDate);
  }

  String get formattedLeavingDate {
    if (leavingDate == null) return 'Present';
    return DateFormat('dd MMM yyyy').format(leavingDate!);
  }

  String get durationString {
    final end = leavingDate ?? DateTime.now();
    final difference = end.difference(joiningDate);
    final days = difference.inDays;

    if (days <= 0) return 'Just joined';
    if (days < 30) return '$days days';
    final months = (days / 30).floor();
    final remDays = days % 30;
    if (remDays == 0) {
      return '$months month${months > 1 ? 's' : ''}';
    }
    return '$months month${months > 1 ? 's' : ''}, $remDays day${remDays > 1 ? 's' : ''}';
  }

  factory OccupancyHistoryItem.fromJson(Map<String, dynamic> json) {
    String rId = '';
    String rNum = json['roomNumber']?.toString() ?? '';

    if (json['room'] is Map<String, dynamic>) {
      final rMap = json['room'] as Map<String, dynamic>;
      rId = rMap['_id']?.toString() ?? '';
      if (rNum.isEmpty) {
        rNum = rMap['roomNumber']?.toString() ?? '';
      }
    } else if (json['room'] is String) {
      rId = json['room'] as String;
    }

    return OccupancyHistoryItem(
      id: json['_id']?.toString() ?? '',
      roomId: rId,
      roomNumber: rNum.isNotEmpty ? rNum : 'N/A',
      joiningDate: json['joiningDate'] != null
          ? DateTime.tryParse(json['joiningDate'].toString()) ?? DateTime.now()
          : DateTime.now(),
      leavingDate: json['leavingDate'] != null
          ? DateTime.tryParse(json['leavingDate'].toString())
          : null,
      occupancyStatus: json['occupancyStatus']?.toString() ?? 'active',
      monthlyRentSnapshot: (json['monthlyRentSnapshot'] is num)
          ? (json['monthlyRentSnapshot'] as num).toDouble()
          : 0.0,
      reason: json['reason']?.toString() ?? '',
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'room': roomId,
      'roomNumber': roomNumber,
      'joiningDate': joiningDate.toIso8601String(),
      'leavingDate': leavingDate?.toIso8601String(),
      'occupancyStatus': occupancyStatus,
      'monthlyRentSnapshot': monthlyRentSnapshot,
      'reason': reason,
      'createdAt': createdAt?.toIso8601String(),
    };
  }
}
