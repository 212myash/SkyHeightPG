class ChatMessageModel {
  final String id;
  final String conversationId;
  final String senderId;
  final String senderName;
  final String senderRole;
  final String content;
  final DateTime? createdAt;
  final bool isMe;

  const ChatMessageModel({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.senderName,
    required this.senderRole,
    required this.content,
    this.createdAt,
    this.isMe = false,
  });

  factory ChatMessageModel.fromJson(Map<String, dynamic> json, {String? currentUserId}) {
    String sId = '';
    String sName = 'User';
    String sRole = 'tenant';

    if (json['sender'] is Map<String, dynamic>) {
      final s = json['sender'] as Map<String, dynamic>;
      sId = s['_id']?.toString() ?? '';
      sName = s['name']?.toString() ?? 'User';
      sRole = s['role']?.toString() ?? 'tenant';
    } else if (json['sender'] != null) {
      sId = json['sender'].toString();
    }

    final isCurrentUser = currentUserId != null && currentUserId.isNotEmpty && sId == currentUserId;

    return ChatMessageModel(
      id: json['_id']?.toString() ?? '',
      conversationId: json['conversation']?.toString() ?? '',
      senderId: sId,
      senderName: sName,
      senderRole: sRole,
      content: json['content']?.toString() ?? '',
      createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt'].toString()) : null,
      isMe: isCurrentUser,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'conversation': conversationId,
      'sender': senderId,
      'content': content,
      'createdAt': createdAt?.toIso8601String(),
    };
  }
}
