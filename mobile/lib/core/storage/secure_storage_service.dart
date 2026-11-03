import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageService {
  final FlutterSecureStorage _storage;

  // In-memory cache for fast sync access and test environments
  final Map<String, String> _memoryCache = {};

  static const String _keyToken = 'skyheight_jwt_token';
  static const String _keyUser = 'skyheight_user_profile';
  static const String _keyRole = 'skyheight_user_role';
  static const String _keyUserId = 'skyheight_user_id';
  static const String _keyDeviceId = 'skyheight_device_id';
  static const String _keyDeviceToken = 'skyheight_fcm_token';

  SecureStorageService({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(),
              iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
            );

  Future<void> saveToken(String token) async {
    _memoryCache[_keyToken] = token;
    try {
      await _storage.write(key: _keyToken, value: token);
    } catch (_) {
      // In-memory fallback
    }
  }

  Future<String?> getToken() async {
    if (_memoryCache.containsKey(_keyToken)) {
      return _memoryCache[_keyToken];
    }
    try {
      final token = await _storage.read(key: _keyToken);
      if (token != null) {
        _memoryCache[_keyToken] = token;
      }
      return token;
    } catch (_) {
      return _memoryCache[_keyToken];
    }
  }

  Future<void> saveRole(String role) async {
    _memoryCache[_keyRole] = role;
    try {
      await _storage.write(key: _keyRole, value: role);
    } catch (_) {}
  }

  Future<String?> getRole() async {
    if (_memoryCache.containsKey(_keyRole)) {
      return _memoryCache[_keyRole];
    }
    try {
      final role = await _storage.read(key: _keyRole);
      if (role != null) {
        _memoryCache[_keyRole] = role;
      }
      return role;
    } catch (_) {
      return _memoryCache[_keyRole];
    }
  }

  Future<void> saveUserId(String id) async {
    _memoryCache[_keyUserId] = id;
    try {
      await _storage.write(key: _keyUserId, value: id);
    } catch (_) {}
  }

  Future<String?> getUserId() async {
    if (_memoryCache.containsKey(_keyUserId)) {
      return _memoryCache[_keyUserId];
    }
    try {
      final id = await _storage.read(key: _keyUserId);
      if (id != null) {
        _memoryCache[_keyUserId] = id;
      }
      return id;
    } catch (_) {
      return _memoryCache[_keyUserId];
    }
  }

  Future<void> saveUserData(Map<String, dynamic> userMap) async {
    final userJson = jsonEncode(userMap);
    _memoryCache[_keyUser] = userJson;
    try {
      await _storage.write(key: _keyUser, value: userJson);
    } catch (_) {}
  }

  Future<Map<String, dynamic>?> getUserData() async {
    String? rawJson;
    if (_memoryCache.containsKey(_keyUser)) {
      rawJson = _memoryCache[_keyUser];
    } else {
      try {
        rawJson = await _storage.read(key: _keyUser);
        if (rawJson != null) {
          _memoryCache[_keyUser] = rawJson;
        }
      } catch (_) {
        rawJson = _memoryCache[_keyUser];
      }
    }

    if (rawJson == null) return null;
    try {
      return jsonDecode(rawJson) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<String> getOrCreateDeviceId() async {
    if (_memoryCache.containsKey(_keyDeviceId)) {
      return _memoryCache[_keyDeviceId]!;
    }
    try {
      final existing = await _storage.read(key: _keyDeviceId);
      if (existing != null && existing.isNotEmpty) {
        _memoryCache[_keyDeviceId] = existing;
        return existing;
      }
    } catch (_) {}

    final newId = 'dev_${DateTime.now().millisecondsSinceEpoch}_${(DateTime.now().microsecondsSinceEpoch % 100000)}';
    _memoryCache[_keyDeviceId] = newId;
    try {
      await _storage.write(key: _keyDeviceId, value: newId);
    } catch (_) {}
    return newId;
  }

  Future<void> saveDeviceToken(String token) async {
    _memoryCache[_keyDeviceToken] = token;
    try {
      await _storage.write(key: _keyDeviceToken, value: token);
    } catch (_) {}
  }

  Future<String?> getDeviceToken() async {
    if (_memoryCache.containsKey(_keyDeviceToken)) {
      return _memoryCache[_keyDeviceToken];
    }
    try {
      final token = await _storage.read(key: _keyDeviceToken);
      if (token != null) {
        _memoryCache[_keyDeviceToken] = token;
      }
      return token;
    } catch (_) {
      return _memoryCache[_keyDeviceToken];
    }
  }

  Future<void> clearDeviceToken() async {
    _memoryCache.remove(_keyDeviceToken);
    try {
      await _storage.delete(key: _keyDeviceToken);
    } catch (_) {}
  }

  Future<void> clearAll() async {
    _memoryCache.clear();
    try {
      await _storage.deleteAll();
    } catch (_) {}
  }
}
