class ConversationModel {
  final String id;
  final String type; // 'private', 'room', 'community'
  final String name;
  final String displayName;
  final String? roomId;
  final String? roomNumber;
  final String lastMessageText;
  final DateTime? lastMessageAt;
  final int unreadCount;

  const ConversationModel({
    required this.id,
    required this.type,
    required this.name,
    required this.displayName,
    this.roomId,
    this.roomNumber,
    this.lastMessageText = '',
    this.lastMessageAt,
    this.unreadCount = 0,
  });

  factory ConversationModel.fromJson(Map<String, dynamic> json) {
    String? rId;
    String? rNum;
    if (json['room'] is Map<String, dynamic>) {
      rId = json['room']['_id']?.toString();
      rNum = json['room']['roomNumber']?.toString();
    } else if (json['room'] != null) {
      rId = json['room'].toString();
    }

    String lastTxt = '';
    DateTime? lastAt;
    if (json['lastMessage'] is Map<String, dynamic>) {
      lastTxt = json['lastMessage']['text']?.toString() ?? '';
      if (json['lastMessage']['sentAt'] != null) {
        lastAt = DateTime.tryParse(json['lastMessage']['sentAt'].toString());
      }
    }
    if (lastAt == null && json['lastMessageAt'] != null) {
      lastAt = DateTime.tryParse(json['lastMessageAt'].toString());
    }

    final dName = json['displayName']?.toString() ?? json['name']?.toString() ?? 'Conversation';

    return ConversationModel(
      id: json['_id']?.toString() ?? '',
      type: json['type']?.toString() ?? 'private',
      name: json['name']?.toString() ?? '',
      displayName: dName,
      roomId: rId,
      roomNumber: rNum,
      lastMessageText: lastTxt,
      lastMessageAt: lastAt,
      unreadCount: (json['unreadCount'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'type': type,
      'name': name,
      'displayName': displayName,
      'room': roomId,
      'lastMessageAt': lastMessageAt?.toIso8601String(),
      'unreadCount': unreadCount,
    };
  }
}
