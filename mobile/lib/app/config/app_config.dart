import 'package:shared_preferences/shared_preferences.dart';

/// Centralized Application and API Configuration
class AppConfig {
  AppConfig._();

  static const String appName = 'Sky Height PG';
  static const String appVersion = '1.0.0';

  // Live Production Render Backend URL
  static const String productionApiUrl = 'https://skyheightpg.onrender.com';

  // Default API Ports and Hosts for Local Development
  static const int defaultPort = 5000;
  static const String androidEmulatorHost = '10.0.2.2';
  static const String iosSimulatorHost = '127.0.0.1';
  static const String localhostHost = 'localhost';
  static const String defaultLanHost = '10.20.178.62';

  // Compile-time environment override via --dart-define=API_URL=...
  static const String _envApiUrl = String.fromEnvironment('API_URL');

  // Configurable base URL (can be updated at runtime for testing/switching)
  static String? _customBaseUrl;
  static const String _prefKeyBaseUrl = 'skyheight_custom_base_url';

  static Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedUrl = prefs.getString(_prefKeyBaseUrl);
      if (savedUrl != null && savedUrl.trim().isNotEmpty) {
        final clean = savedUrl.trim().replaceAll(RegExp(r'/+$'), '');
        // Auto-migrate legacy local development URLs to live Render production
        if (clean == 'http://127.0.0.1:$defaultPort' ||
            clean == 'http://localhost:$defaultPort' ||
            clean == 'http://$androidEmulatorHost:$defaultPort') {
          await prefs.remove(_prefKeyBaseUrl);
          _customBaseUrl = null;
        } else {
          _customBaseUrl = clean;
        }
      }
    } catch (_) {}
  }

  static Future<void> setCustomBaseUrl(String url) async {
    final cleanUrl = url.trim().replaceAll(RegExp(r'/+$'), '');
    _customBaseUrl = cleanUrl;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKeyBaseUrl, cleanUrl);
    } catch (_) {}
  }

  static Future<void> resetBaseUrl() async {
    _customBaseUrl = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefKeyBaseUrl);
    } catch (_) {}
  }

  static String get baseUrl {
    // 1. Runtime custom URL (user/QA configured)
    if (_customBaseUrl != null && _customBaseUrl!.isNotEmpty) {
      return _customBaseUrl!;
    }

    // 2. Compile-time --dart-define=API_URL=...
    if (_envApiUrl.isNotEmpty) {
      return _envApiUrl.replaceAll(RegExp(r'/+$'), '');
    }

    // 3. Live Production Render Backend by default
    return productionApiUrl;
  }

  static bool get isProduction => baseUrl == productionApiUrl;

  // Network Timeouts (Extended to 60s to accommodate Render Free tier instance cold starts)
  static const Duration connectTimeout = Duration(seconds: 60);
  static const Duration receiveTimeout = Duration(seconds: 60);
}
