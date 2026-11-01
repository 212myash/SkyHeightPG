import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/network/api_exceptions.dart';
import '../../../core/storage/secure_storage_service.dart';
import '../models/user_model.dart';

enum AuthStatus {
  initial,
  loading,
  authenticated,
  unauthenticated,
  error,
}

class AuthState {
  final AuthStatus status;
  final UserModel? user;
  final String? token;
  final String? errorMessage;

  const AuthState({
    this.status = AuthStatus.initial,
    this.user,
    this.token,
    this.errorMessage,
  });

  bool get isAuthenticated => status == AuthStatus.authenticated && user != null;
  bool get isLoading => status == AuthStatus.loading;
  bool get isOwner => user?.isOwner ?? false;
  bool get isTenant => user?.isTenant ?? false;

  AuthState copyWith({
    AuthStatus? status,
    UserModel? user,
    String? token,
    String? errorMessage,
    bool clearError = false,
    bool clearUser = false,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: clearUser ? null : (user ?? this.user),
      token: clearUser ? null : (token ?? this.token),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

// Core dependency providers
final secureStorageProvider = Provider<SecureStorageService>((ref) {
  return SecureStorageService();
});

final apiClientProvider = Provider<ApiClient>((ref) {
  final storage = ref.watch(secureStorageProvider);
  return ApiClient(storageService: storage);
});

// Auth notifier provider
final authProvider = NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);

class AuthNotifier extends Notifier<AuthState> {
  late final SecureStorageService _storage;
  late final ApiClient _api;

  @override
  AuthState build() {
    _storage = ref.watch(secureStorageProvider);
    _api = ref.watch(apiClientProvider);
    return const AuthState();
  }

  Future<void> checkAuth() async {
    state = state.copyWith(status: AuthStatus.loading, clearError: true);
    try {
      final token = await _storage.getToken();
      if (token == null || token.isEmpty) {
        state = state.copyWith(status: AuthStatus.unauthenticated, clearUser: true);
        return;
      }

      // Verify token with backend /api/auth/profile
      final response = await _api.get(ApiEndpoints.profile);
      if (response.data != null && response.data['success'] == true && response.data['user'] != null) {
        final user = UserModel.fromJson(response.data['user'] as Map<String, dynamic>);
        state = state.copyWith(
          status: AuthStatus.authenticated,
          user: user,
          token: token,
        );
      } else {
        await _storage.clearAll();
        state = state.copyWith(status: AuthStatus.unauthenticated, clearUser: true);
      }
    } catch (e) {
      // If unauthorized or network error with invalid token, reset
      await _storage.clearAll();
      state = state.copyWith(status: AuthStatus.unauthenticated, clearUser: true);
    }
  }

  Future<bool> login({required String email, required String password}) async {
    state = state.copyWith(status: AuthStatus.loading, clearError: true);
    try {
      final response = await _api.post(
        ApiEndpoints.login,
        data: {
          'email': email.trim().toLowerCase(),
          'password': password,
        },
      );

      final data = response.data;
      if (data != null && data['success'] == true && data['token'] != null) {
        final token = data['token'].toString();
        final user = UserModel.fromJson(data['user'] as Map<String, dynamic>);

        await _storage.saveToken(token);
        await _storage.saveRole(user.role);
        await _storage.saveUserId(user.id);

        state = state.copyWith(
          status: AuthStatus.authenticated,
          user: user,
          token: token,
        );
        return true;
      } else {
        final message = data?['message'] ?? 'Login failed. Please try again.';
        state = state.copyWith(status: AuthStatus.error, errorMessage: message.toString());
        return false;
      }
    } on ApiException catch (e) {
      state = state.copyWith(status: AuthStatus.error, errorMessage: e.message);
      return false;
    } catch (e) {
      state = state.copyWith(status: AuthStatus.error, errorMessage: e.toString());
      return false;
    }
  }

  Future<bool> register({
    required String name,
    required String email,
    required String password,
    required String phone,
    String role = 'TENANT',
  }) async {
    state = state.copyWith(status: AuthStatus.loading, clearError: true);
    try {
      final response = await _api.post(
        ApiEndpoints.register,
        data: {
          'name': name.trim(),
          'email': email.trim().toLowerCase(),
          'password': password,
          'phone': phone.trim(),
          'role': role.toUpperCase(),
        },
      );

      final data = response.data;
      if (data != null && data['success'] == true && data['token'] != null) {
        final token = data['token'].toString();
        final user = UserModel.fromJson(data['user'] as Map<String, dynamic>);

        await _storage.saveToken(token);
        await _storage.saveRole(user.role);
        await _storage.saveUserId(user.id);

        state = state.copyWith(
          status: AuthStatus.authenticated,
          user: user,
          token: token,
        );
        return true;
      } else {
        final message = data?['message'] ?? 'Registration failed. Please try again.';
        state = state.copyWith(status: AuthStatus.error, errorMessage: message.toString());
        return false;
      }
    } on ApiException catch (e) {
      state = state.copyWith(status: AuthStatus.error, errorMessage: e.message);
      return false;
    } catch (e) {
      state = state.copyWith(status: AuthStatus.error, errorMessage: e.toString());
      return false;
    }
  }

  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final response = await _api.put(
        ApiEndpoints.changePassword,
        data: {
          'currentPassword': currentPassword,
          'newPassword': newPassword,
        },
      );
      return response.data?['success'] == true;
    } on ApiException catch (e) {
      state = state.copyWith(errorMessage: e.message);
      rethrow;
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
      rethrow;
    }
  }

  Future<void> logout() async {
    await _storage.clearAll();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }
}

// User-friendly convenience selectors
final currentUserProvider = Provider<UserModel?>((ref) => ref.watch(authProvider).user);
final isOwnerProvider = Provider<bool>((ref) => ref.watch(authProvider).isOwner);
final isTenantProvider = Provider<bool>((ref) => ref.watch(authProvider).isTenant);
