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

    test('Phase 6: Offline cached session preserves credentials without server-verified status', () {
      const initial = AuthState();

      const cachedUser = UserModel(
        id: 'user_cached_1',
        name: 'Cached Tenant',
        email: 'cached@pg.com',
        phone: '9876543212',
        role: 'TENANT',
      );

      final offlineState = initial.copyWith(
        status: AuthStatus.offlineCached,
        user: cachedUser,
        token: 'cached_token_789',
        isServerVerified: false,
        errorMessage: 'Network unavailable. Operating in offline mode.',
      );

      // Verifies condition 3: has active session for navigation, but NOT treated as server-authenticated
      expect(offlineState.isOfflineCached, isTrue);
      expect(offlineState.isServerVerified, isFalse);
      expect(offlineState.isAuthenticated, isFalse);
      expect(offlineState.hasActiveSession, isTrue);
      expect(offlineState.user?.name, 'Cached Tenant');
      expect(offlineState.token, 'cached_token_789');
    });

    test('Phase 6: Server authenticated session verifies flags correctly', () {
      const initial = AuthState();

      const serverUser = UserModel(
        id: 'user_server_1',
        name: 'Verified Owner',
        email: 'owner@pg.com',
        phone: '9876543210',
        role: 'OWNER',
      );

      final verifiedState = initial.copyWith(
        status: AuthStatus.authenticated,
        user: serverUser,
        token: 'verified_token_999',
        isServerVerified: true,
      );

      expect(verifiedState.isAuthenticated, isTrue);
      expect(verifiedState.isServerVerified, isTrue);
      expect(verifiedState.isOfflineCached, isFalse);
      expect(verifiedState.hasActiveSession, isTrue);
      expect(verifiedState.isOwner, isTrue);
    });
  });
}
