import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';

/// Centralized Application and API Configuration
class AppConfig {
  AppConfig._();

  static const String appName = 'Sky Height PG';
  static const String appVersion = '1.0.0';

  // Default API Ports and Hosts
  static const int defaultPort = 5000;
  static const String androidEmulatorHost = '10.0.2.2';
  static const String iosSimulatorHost = '127.0.0.1';
  static const String localhostHost = 'localhost';

  // Configurable base URL (can be updated at runtime for physical devices)
  static String? _customBaseUrl;

  static void setCustomBaseUrl(String url) {
    _customBaseUrl = url.trim().replaceAll(RegExp(r'/+$'), '');
  }

  static void resetBaseUrl() {
    _customBaseUrl = null;
  }

  static String get baseUrl {
    if (_customBaseUrl != null && _customBaseUrl!.isNotEmpty) {
      return _customBaseUrl!;
    }

    // Auto-detect development host based on platform
    if (!kIsWeb) {
      if (Platform.isAndroid) {
        return 'http://$androidEmulatorHost:$defaultPort';
      } else if (Platform.isIOS) {
        return 'http://$iosSimulatorHost:$defaultPort';
      }
    }
    return 'http://$localhostHost:$defaultPort';
  }

  // Network Timeouts
  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 15);
}
