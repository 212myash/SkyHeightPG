class NotificationModel {
  final String id;
  final String title;
  final String message;
  final String category;
  final String audience;
  final String? targetRoomNumber;
  final bool isRead;
  final DateTime? readAt;
  final DateTime? dueDate;
  final DateTime? createdAt;
  final String? senderName;

  const NotificationModel({
    required this.id,
    required this.title,
    required this.message,
    required this.category,
    this.audience = 'tenant',
    this.targetRoomNumber,
    this.isRead = false,
    this.readAt,
    this.dueDate,
    this.createdAt,
    this.senderName,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    String? roomNum;
    if (json['targetRoom'] is Map<String, dynamic>) {
      roomNum = json['targetRoom']['roomNumber']?.toString();
    }

    String? sName;
    if (json['sender'] is Map<String, dynamic>) {
      sName = json['sender']['name']?.toString();
    }

    return NotificationModel(
      id: json['_id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      message: json['message']?.toString() ?? '',
      category: json['category']?.toString() ?? 'general_announcement',
      audience: json['audience']?.toString() ?? 'tenant',
      targetRoomNumber: roomNum,
      isRead: json['isRead'] == true,
      readAt: json['readAt'] != null ? DateTime.tryParse(json['readAt'].toString()) : null,
      dueDate: json['dueDate'] != null ? DateTime.tryParse(json['dueDate'].toString()) : null,
      createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt'].toString()) : null,
      senderName: sName,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'title': title,
      'message': message,
      'category': category,
      'audience': audience,
      'isRead': isRead,
      'readAt': readAt?.toIso8601String(),
      'dueDate': dueDate?.toIso8601String(),
      'createdAt': createdAt?.toIso8601String(),
    };
  }
}
