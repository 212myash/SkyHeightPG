import 'package:flutter_test/flutter_test.dart';
import 'package:sky_height_pg/core/notifications/push_notification_service.dart';
import 'package:sky_height_pg/core/storage/secure_storage_service.dart';

void main() {
  group('Push Notification System Tests', () {
    test('Configures 5 required Android Notification Channels', () {
      expect(PushNotificationService.channelAnnouncements.id, 'announcements');
      expect(PushNotificationService.channelAnnouncements.name, 'Announcements');

      expect(PushNotificationService.channelBilling.id, 'billing');
      expect(PushNotificationService.channelBilling.name, 'Billing & Payments');

      expect(PushNotificationService.channelMaintenance.id, 'maintenance');
      expect(PushNotificationService.channelMaintenance.name, 'Maintenance & Complaints');

      expect(PushNotificationService.channelMessages.id, 'messages');
      expect(PushNotificationService.channelMessages.name, 'Chat Messages');

      expect(PushNotificationService.channelAlerts.id, 'alerts');
      expect(PushNotificationService.channelAlerts.name, 'Security & System Alerts');
    });

    test('Graceful Token Fallback when Firebase unconfigured', () async {
      final storage = SecureStorageService();
      final token = await PushNotificationService.getDeviceToken(storage);
      expect(token, isNotNull);
      expect(token!.startsWith('local-device-dev_'), isTrue);

      final savedToken = await storage.getDeviceToken();
      expect(savedToken, token);
    });

    test('Device Id persistence in SecureStorageService', () async {
      final storage = SecureStorageService();
      final devId1 = await storage.getOrCreateDeviceId();
      final devId2 = await storage.getOrCreateDeviceId();
      expect(devId1, equals(devId2));
      expect(devId1.startsWith('dev_'), isTrue);
    });
  });
}
