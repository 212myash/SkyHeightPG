import 'package:flutter_test/flutter_test.dart';
import 'package:sky_height_pg/core/network/api_endpoints.dart';
import 'package:sky_height_pg/features/tenant/models/occupancy_history_model.dart';

void main() {
  group('Phase A: Occupancy History Model Tests', () {
    test('OccupancyHistoryItem deserializes correctly from backend JSON', () {
      final json = {
        '_id': 'hist_123',
        'room': {
          '_id': 'room_456',
          'roomNumber': 'G101',
          'floor': 1,
        },
        'roomNumber': 'G101',
        'joiningDate': '2026-06-01T00:00:00.000Z',
        'leavingDate': '2026-10-31T00:00:00.000Z',
        'occupancyStatus': 'transferred',
        'monthlyRentSnapshot': 7500.0,
        'reason': 'Transferred to Room G102',
        'createdAt': '2026-06-01T00:00:00.000Z',
      };

      final item = OccupancyHistoryItem.fromJson(json);

      expect(item.id, equals('hist_123'));
      expect(item.roomId, equals('room_456'));
      expect(item.roomNumber, equals('G101'));
      expect(item.occupancyStatus, equals('transferred'));
      expect(item.isTransferred, isTrue);
      expect(item.isActive, isFalse);
      expect(item.isVacated, isFalse);
      expect(item.monthlyRentSnapshot, equals(7500.0));
      expect(item.reason, equals('Transferred to Room G102'));
      expect(item.formattedJoiningDate, equals('01 Jun 2026'));
      expect(item.formattedLeavingDate, equals('31 Oct 2026'));
      expect(item.durationString, contains('month'));
    });

    test('OccupancyHistoryItem active state handles null leavingDate gracefully', () {
      final json = {
        '_id': 'hist_active',
        'room': 'room_789',
        'roomNumber': 'G102',
        'joiningDate': DateTime.now().subtract(const Duration(days: 15)).toIso8601String(),
        'leavingDate': null,
        'occupancyStatus': 'active',
        'monthlyRentSnapshot': 8000.0,
        'reason': 'Initial room allocation',
      };

      final item = OccupancyHistoryItem.fromJson(json);

      expect(item.isActive, isTrue);
      expect(item.isVacated, isFalse);
      expect(item.isTransferred, isFalse);
      expect(item.leavingDate, isNull);
      expect(item.formattedLeavingDate, equals('Present'));
      expect(item.durationString, contains('days'));
    });

    test('OccupancyHistoryItem serialization toJson mirrors model state', () {
      final item = OccupancyHistoryItem(
        id: 'hist_vacated',
        roomId: 'room_103',
        roomNumber: 'G103',
        joiningDate: DateTime(2026, 1, 15),
        leavingDate: DateTime(2026, 7, 15),
        occupancyStatus: 'vacated',
        monthlyRentSnapshot: 9000.0,
        reason: 'Vacated apartment',
      );

      final json = item.toJson();

      expect(json['_id'], equals('hist_vacated'));
      expect(json['room'], equals('room_103'));
      expect(json['roomNumber'], equals('G103'));
      expect(json['occupancyStatus'], equals('vacated'));
      expect(json['monthlyRentSnapshot'], equals(9000.0));
      expect(json['reason'], equals('Vacated apartment'));
      expect(item.isVacated, isTrue);
    });

    test('ApiEndpoints includes Phase A occupancy history routes', () {
      expect(ApiEndpoints.myOccupancyHistory, equals('/api/tenants/me/occupancy-history'));
      expect(ApiEndpoints.tenantOccupancyHistory('tenant_abc'), equals('/api/tenants/tenant_abc/occupancy-history'));
      expect(ApiEndpoints.roomOccupancyHistory('room_xyz'), equals('/api/rooms/room_xyz/occupancy-history'));
    });
  });
}
