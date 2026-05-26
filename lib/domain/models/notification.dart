class Notification {
  final String notificationId;
  final String userId;
  final String userType;
  final String title;
  final String body;
  final String notificationType;
  final String? relatedEntityType;
  final String? relatedEntityId;
  final Map<String, dynamic>? data;
  final bool isRead;
  final DateTime? readAt;
  final DateTime createdAt;
  final String? createdBy;

  Notification({
    required this.notificationId,
    required this.userId,
    required this.userType,
    required this.title,
    required this.body,
    required this.notificationType,
    this.relatedEntityType,
    this.relatedEntityId,
    this.data,
    required this.isRead,
    this.readAt,
    required this.createdAt,
    this.createdBy,
  });

  factory Notification.fromJson(Map<String, dynamic> json) {
    return Notification(
      notificationId: json['notification_id'],
      userId: json['user_id'],
      userType: json['user_type'],
      title: json['title'],
      body: json['body'],
      notificationType: json['notification_type'],
      relatedEntityType: json['related_entity_type'],
      relatedEntityId: json['related_entity_id'],
      data: json['data'] as Map<String, dynamic>?,
      isRead: json['is_read'] ?? false,
      readAt: json['read_at'] is DateTime
          ? json['read_at']
          : (json['read_at'] != null ? DateTime.parse(json['read_at']) : null),
      createdAt: json['created_at'] is DateTime
          ? json['created_at']
          : DateTime.parse(json['created_at']),
      createdBy: json['created_by'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'notification_id': notificationId,
      'user_id': userId,
      'user_type': userType,
      'title': title,
      'body': body,
      'notification_type': notificationType,
      'related_entity_type': relatedEntityType,
      'related_entity_id': relatedEntityId,
      'data': data,
      'is_read': isRead,
      'read_at': readAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'created_by': createdBy,
    };
  }
}
