import 'dart:async';
import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:go_router/go_router.dart';
import '../network/api_client.dart';
import '../network/api_endpoints.dart';
import '../storage/secure_storage_service.dart';
import 'app_notification_service.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Silent/background handler
  debugPrint('[PushNotificationService] Background message received: ${message.messageId}');
}

class PushNotificationService {
  PushNotificationService._();

  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static GlobalKey<NavigatorState>? navigatorKey;

  static bool _isInitialized = false;
  static bool _firebaseAvailable = false;
  static String? _currentToken;

  // 5 Dedicated Android Notification Channels
  static const AndroidNotificationChannel channelAnnouncements =
      AndroidNotificationChannel(
    'announcements',
    'Announcements',
    description: 'General PG announcements and public notices',
    importance: Importance.high,
    playSound: true,
  );

  static const AndroidNotificationChannel channelBilling =
      AndroidNotificationChannel(
    'billing',
    'Billing & Payments',
    description: 'Monthly rent, electricity bills, and payment receipts',
    importance: Importance.high,
    playSound: true,
  );

  static const AndroidNotificationChannel channelMaintenance =
      AndroidNotificationChannel(
    'maintenance',
    'Maintenance & Complaints',
    description: 'Maintenance schedules and complaint status updates',
    importance: Importance.defaultImportance,
    playSound: true,
  );

  static const AndroidNotificationChannel channelMessages =
      AndroidNotificationChannel(
    'messages',
    'Chat Messages',
    description: 'Community and room chat notifications',
    importance: Importance.high,
    playSound: true,
  );

  static const AndroidNotificationChannel channelAlerts =
      AndroidNotificationChannel(
    'alerts',
    'Security & System Alerts',
    description: 'Critical security and urgent system alerts',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
  );

  static bool get isFirebaseAvailable => _firebaseAvailable;

  /// Initialize the push notification system, notification channels, and listeners
  static Future<void> initialize({GlobalKey<NavigatorState>? navKey}) async {
    if (_isInitialized) return;
    if (navKey != null) navigatorKey = navKey;

    // 1. Initialize local notifications
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initSettings =
        InitializationSettings(android: androidSettings);

    try {
      await _localNotifications.initialize(
        settings: initSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          if (response.payload != null && response.payload!.isNotEmpty) {
            _handleNotificationPayload(response.payload!);
          }
        },
      );

      // Create Android Notification Channels
      final androidPlugin = _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      if (androidPlugin != null) {
        await androidPlugin.createNotificationChannel(channelAnnouncements);
        await androidPlugin.createNotificationChannel(channelBilling);
        await androidPlugin.createNotificationChannel(channelMaintenance);
        await androidPlugin.createNotificationChannel(channelMessages);
        await androidPlugin.createNotificationChannel(channelAlerts);

        // Request runtime permission for Android 13+
        await androidPlugin.requestNotificationsPermission();
      }
    } catch (e) {
      debugPrint('[PushNotificationService] Local notification init error: $e');
    }

    // 2. Initialize Firebase Cloud Messaging with graceful fallback
    try {
      await Firebase.initializeApp();
      _firebaseAvailable = true;

      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      // Request FCM permission
      await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      // Foreground message listener
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        _handleForegroundMessage(message);
      });

      // Background notification tap listener
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        _handleRemoteMessageTap(message);
      });

      // Terminated state initial message
      final initialMessage =
          await FirebaseMessaging.instance.getInitialMessage();
      if (initialMessage != null) {
        _handleRemoteMessageTap(initialMessage);
      }

      // Token refresh listener
      // ignore: deprecated_member_use
      FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
        _currentToken = newToken;
      });

      debugPrint('[PushNotificationService] Firebase Cloud Messaging initialized successfully.');
    } catch (e) {
      _firebaseAvailable = false;
      debugPrint('[PushNotificationService] Firebase not configured ($e). Operating in graceful local/in-app mode.');
    }

    _isInitialized = true;
  }

  /// Retrieve the active device push token (FCM or local fallback token)
  static Future<String?> getDeviceToken(SecureStorageService storage) async {
    if (_currentToken != null && _currentToken!.isNotEmpty) {
      return _currentToken;
    }

    if (_firebaseAvailable) {
      try {
        // ignore: deprecated_member_use
        final token = await FirebaseMessaging.instance.getToken();
        if (token != null && token.isNotEmpty) {
          _currentToken = token;
          await storage.saveDeviceToken(token);
          return token;
        }
      } catch (e) {
        debugPrint('[PushNotificationService] getToken error: $e');
      }
    }

    // Graceful fallback: generate a deterministic device-bound token
    final deviceId = await storage.getOrCreateDeviceId();
    final fallbackToken = 'local-device-$deviceId';
    _currentToken = fallbackToken;
    await storage.saveDeviceToken(fallbackToken);
    return fallbackToken;
  }

  /// Register current device token with backend
  static Future<void> registerDeviceToken({
    required ApiClient apiClient,
    required SecureStorageService storage,
  }) async {
    try {
      final token = await getDeviceToken(storage);
      final deviceId = await storage.getOrCreateDeviceId();

      if (token == null || token.isEmpty) return;

      await apiClient.post(
        ApiEndpoints.deviceToken,
        data: {
          'token': token,
          'platform': 'android',
          'deviceId': deviceId,
        },
      );
      debugPrint('[PushNotificationService] Device token registered with backend.');
    } catch (e) {
      debugPrint('[PushNotificationService] Failed to register device token: $e');
    }
  }

  /// Deregister device token from backend on logout
  static Future<void> deregisterDeviceToken({
    required ApiClient apiClient,
    required SecureStorageService storage,
  }) async {
    try {
      final token = await storage.getDeviceToken();
      if (token != null && token.isNotEmpty) {
        await apiClient.delete(
          ApiEndpoints.deviceToken,
          data: {'token': token},
        );
        await storage.clearDeviceToken();
        _currentToken = null;
        debugPrint('[PushNotificationService] Device token deregistered on logout.');
      }
    } catch (e) {
      debugPrint('[PushNotificationService] Failed to deregister device token: $e');
    }
  }

  /// Display a foreground notification as both a system status notification and in-app banner
  static void _handleForegroundMessage(RemoteMessage message) {
    final title = message.notification?.title ?? message.data['title'] ?? 'Sky Height PG';
    final body = message.notification?.body ?? message.data['body'] ?? message.data['message'] ?? '';
    final category = message.data['category'] ?? 'alerts';

    // Show immediate in-app top banner for instant visibility
    AppNotificationService.showTopBanner(
      message: '$title: $body',
      type: NotificationType.info,
      actionLabel: 'View',
      onAction: () => _handleRemoteMessageTap(message),
    );

    // Show system tray notification
    final channel = _resolveChannel(category);
    final androidDetails = AndroidNotificationDetails(
      channel.id,
      channel.name,
      channelDescription: channel.description,
      importance: channel.importance,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    final notificationDetails = NotificationDetails(android: androidDetails);
    final payloadString = jsonEncode(message.data);

    _localNotifications.show(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: title,
      body: body,
      notificationDetails: notificationDetails,
      payload: payloadString,
    );
  }

  /// Handle tap on remote message
  static void _handleRemoteMessageTap(RemoteMessage message) {
    final data = message.data;
    _dispatchNavigation(data);
  }

  /// Handle tap on local notification payload
  static void _handleNotificationPayload(String payload) {
    try {
      final map = jsonDecode(payload) as Map<String, dynamic>;
      _dispatchNavigation(map);
    } catch (e) {
      debugPrint('[PushNotificationService] Payload parse error: $e');
    }
  }

  /// Route user based on notification payload data
  static void _dispatchNavigation(Map<String, dynamic> data) {
    final targetScreen = data['screen'] as String?;
    final category = data['category'] as String?;
    final conversationId = data['conversationId'] as String?;

    final context = navigatorKey?.currentContext;
    if (context == null) {
      debugPrint('[PushNotificationService] Navigation context unavailable.');
      return;
    }

    try {
      if (conversationId != null && conversationId.isNotEmpty) {
        GoRouter.of(context).push('/chat/$conversationId');
        return;
      }

      if (targetScreen != null && targetScreen.isNotEmpty) {
        GoRouter.of(context).push(targetScreen);
        return;
      }

      // Default routing based on category
      switch (category) {
        case 'chat_message':
          GoRouter.of(context).push('/chat');
          break;
        case 'electricity_bill':
        case 'rent_reminder':
        case 'payment_reminder':
        case 'payment_received':
          GoRouter.of(context).push('/notifications');
          break;
        default:
          GoRouter.of(context).push('/notifications');
          break;
      }
    } catch (e) {
      debugPrint('[PushNotificationService] Deep-link navigation error: $e');
      try {
        GoRouter.of(context).push('/notifications');
      } catch (_) {}
    }
  }

  static AndroidNotificationChannel _resolveChannel(String? category) {
    switch (category) {
      case 'general_announcement':
        return channelAnnouncements;
      case 'rent_reminder':
      case 'electricity_bill':
      case 'payment_reminder':
      case 'payment_received':
        return channelBilling;
      case 'maintenance':
      case 'complaint_update':
        return channelMaintenance;
      case 'chat_message':
        return channelMessages;
      case 'security_alert':
      case 'registration_update':
      case 'system':
      default:
        return channelAlerts;
    }
  }
}
