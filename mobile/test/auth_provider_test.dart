import 'package:flutter_test/flutter_test.dart';
import 'package:sky_height_pg/core/storage/secure_storage_service.dart';
import 'package:sky_height_pg/features/auth/models/user_model.dart';
import 'package:sky_height_pg/features/auth/providers/auth_provider.dart';

void main() {
  group('Auth State & Storage Tests', () {
    test('SecureStorageService in-memory caching', () async {
      final storage = SecureStorageService();

      expect(await storage.getToken(), isNull);
      await storage.saveToken('test_jwt_token_xyz');
      expect(await storage.getToken(), 'test_jwt_token_xyz');

      expect(await storage.getRole(), isNull);
      await storage.saveRole('OWNER');
      expect(await storage.getRole(), 'OWNER');

      await storage.saveUserId('usr_123');
      expect(await storage.getUserId(), 'usr_123');

      await storage.clearAll();
      expect(await storage.getToken(), isNull);
      expect(await storage.getRole(), isNull);
      expect(await storage.getUserId(), isNull);
    });

    test('AuthState status flags and role getters', () {
      const initial = AuthState();
      expect(initial.status, AuthStatus.initial);
      expect(initial.isAuthenticated, isFalse);
      expect(initial.isLoading, isFalse);
      expect(initial.isOwner, isFalse);
      expect(initial.isTenant, isFalse);

      const ownerUser = UserModel(
        id: '1',
        name: 'Owner Name',
        email: 'owner@pg.com',
        phone: '9876543210',
        role: 'OWNER',
      );

      final authedOwner = initial.copyWith(
        status: AuthStatus.authenticated,
        user: ownerUser,
        token: 'token_123',
      );

      expect(authedOwner.isAuthenticated, isTrue);
      expect(authedOwner.isOwner, isTrue);
      expect(authedOwner.isTenant, isFalse);

      const tenantUser = UserModel(
        id: '2',
        name: 'Tenant Name',
        email: 'tenant@pg.com',
        phone: '9876543211',
        role: 'TENANT',
      );

      final authedTenant = initial.copyWith(
        status: AuthStatus.authenticated,
        user: tenantUser,
        token: 'token_456',
      );

      expect(authedTenant.isAuthenticated, isTrue);
      expect(authedTenant.isOwner, isFalse);
      expect(authedTenant.isTenant, isTrue);
    });
  });
}
