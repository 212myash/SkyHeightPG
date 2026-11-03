import 'package:flutter_test/flutter_test.dart';
import 'package:sky_height_pg/core/network/api_endpoints.dart';
import 'package:sky_height_pg/features/owner/models/registration_request_model.dart';
import 'package:sky_height_pg/features/notifications/models/notification_model.dart';
import 'package:sky_height_pg/features/chat/models/conversation_model.dart';
import 'package:sky_height_pg/features/chat/models/chat_message_model.dart';

void main() {
  group('Phase 8 Models & Endpoints Tests', () {
    test('ApiEndpoints includes registrations, notifications, and chat routes', () {
      expect(ApiEndpoints.registrations, '/api/owner/registrations');
      expect(ApiEndpoints.approveRegistration('123'), '/api/owner/registrations/123/approve');
      expect(ApiEndpoints.rejectRegistration('123'), '/api/owner/registrations/123/reject');
      expect(ApiEndpoints.notifications, '/api/notifications');
      expect(ApiEndpoints.unreadNotificationCount, '/api/notifications/unread-count');
      expect(ApiEndpoints.conversations, '/api/conversations');
      expect(ApiEndpoints.conversationMessages('conv_1'), '/api/conversations/conv_1/messages');
      expect(ApiEndpoints.sendMessage('conv_1'), '/api/conversations/conv_1/messages');
      expect(ApiEndpoints.markConversationRead('conv_1'), '/api/conversations/conv_1/read');
    });

    test('RegistrationRequestModel parses JSON with tenant and room details', () {
      final json = {
        '_id': 'user_123',
        'name': 'Rahul Sharma',
        'email': 'rahul@example.com',
        'phone': '9876543210',
        'role': 'tenant',
        'approvalStatus': 'pending',
        'createdAt': '2026-11-02T10:00:00.000Z',
        'tenant': {
          '_id': 'tenant_123',
          'monthlyRent': 8000,
          'securityDeposit': 10000,
          'room': {
            '_id': 'room_123',
            'roomNumber': 'G101',
          }
        }
      };

      final model = RegistrationRequestModel.fromJson(json);
      expect(model.id, 'user_123');
      expect(model.name, 'Rahul Sharma');
      expect(model.approvalStatus, 'pending');
      expect(model.assignedRoomNumber, 'G101');
      expect(model.monthlyRent, 8000.0);
      expect(model.securityDeposit, 10000.0);
    });

    test('NotificationModel parses JSON and formats categories', () {
      final json = {
        '_id': 'notif_123',
        'title': 'Rent Reminder',
        'message': 'Your rent is due soon',
        'category': 'rent_reminder',
        'audience': 'all',
        'isRead': false,
        'createdAt': '2026-11-02T10:00:00.000Z',
      };

      final notif = NotificationModel.fromJson(json);
      expect(notif.id, 'notif_123');
      expect(notif.title, 'Rent Reminder');
      expect(notif.isRead, false);
      expect(notif.category, 'rent_reminder');
      expect(notif.audience, 'all');
    });

    test('ConversationModel parses types and unread counts', () {
      final json = {
        '_id': 'conv_123',
        'type': 'room',
        'name': 'Room G101 Group',
        'displayName': 'Room G101 Group',
        'lastMessage': {
          'text': 'Hello roommate',
          'sentAt': '2026-11-02T10:00:00.000Z',
        },
        'unreadCount': 2,
      };

      final conv = ConversationModel.fromJson(json);
      expect(conv.id, 'conv_123');
      expect(conv.type, 'room');
      expect(conv.unreadCount, 2);
      expect(conv.lastMessageText, 'Hello roommate');
    });

    test('ChatMessageModel identifies current user sender correctly', () {
      final json = {
        '_id': 'msg_123',
        'conversation': 'conv_123',
        'sender': {
          '_id': 'user_me',
          'name': 'Yash Raj',
          'role': 'owner',
        },
        'content': 'Welcome everyone!',
        'createdAt': '2026-11-02T10:00:00.000Z',
      };

      final myMsg = ChatMessageModel.fromJson(json, currentUserId: 'user_me');
      expect(myMsg.isMe, true);
      expect(myMsg.senderRole, 'owner');
      expect(myMsg.content, 'Welcome everyone!');

      final otherMsg = ChatMessageModel.fromJson(json, currentUserId: 'user_other');
      expect(otherMsg.isMe, false);
      expect(otherMsg.senderName, 'Yash Raj');
    });
  });
}
