import 'package:flutter_test/flutter_test.dart';
import 'package:sky_height_pg/features/auth/models/user_model.dart';

void main() {
  group('UserModel Serialization Tests', () {
    test('fromJson and toJson with Owner role', () {
      final json = {
        '_id': 'user_owner_123',
        'name': 'Sky Height Owner',
        'email': 'owner@skyheightpg.com',
        'phone': '9876543210',
        'role': 'OWNER',
        'isActive': true,
      };

      final user = UserModel.fromJson(json);

      expect(user.id, 'user_owner_123');
      expect(user.name, 'Sky Height Owner');
      expect(user.email, 'owner@skyheightpg.com');
      expect(user.phone, '9876543210');
      expect(user.role, 'OWNER');
      expect(user.isOwner, isTrue);
      expect(user.isTenant, isFalse);
      expect(user.isActive, isTrue);

      final exported = user.toJson();
      expect(exported['_id'], 'user_owner_123');
      expect(exported['role'], 'OWNER');
    });

    test('fromJson and toJson with Tenant role', () {
      final json = {
        'id': 'user_tenant_456',
        'name': 'Rahul Verma',
        'email': 'rahul@gmail.com',
        'phone': '9123456789',
        'role': 'TENANT',
        'isActive': true,
      };

      final user = UserModel.fromJson(json);

      expect(user.id, 'user_tenant_456');
      expect(user.isOwner, isFalse);
      expect(user.isTenant, isTrue);
    });

    test('copyWith updates fields correctly', () {
      const user = UserModel(
        id: '1',
        name: 'Initial Name',
        email: 'test@test.com',
        phone: '1234567890',
        role: 'TENANT',
      );

      final updated = user.copyWith(name: 'Updated Name', role: 'OWNER');

      expect(updated.id, '1');
      expect(updated.name, 'Updated Name');
      expect(updated.role, 'OWNER');
      expect(updated.isOwner, isTrue);
      expect(updated.email, 'test@test.com');
    });
  });
}
