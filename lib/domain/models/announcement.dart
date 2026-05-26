class Announcement {
  final String? announcementId;
  final String title;
  final String content;
  final DateTime announcementDate;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final dynamic createdBy; // Can be String (ID) or Map (Details)
  final dynamic updatedBy; // Can be String (ID) or Map (Details)
  final bool isActive;

  Announcement({
    this.announcementId,
    required this.title,
    required this.content,
    required this.announcementDate,
    this.createdAt,
    this.updatedAt,
    required this.createdBy,
    this.updatedBy,
    this.isActive = true,
  });

  factory Announcement.fromJson(Map<String, dynamic> json) {
    return Announcement(
      announcementId: json['announcement_id'] as String?,
      title: json['title'] as String? ?? '',
      content: json['content'] as String? ?? '',
      announcementDate: json['announcement_date'] != null
          ? DateTime.parse(json['announcement_date'].toString())
          : DateTime.now(),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'].toString())
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'].toString())
          : null,
      createdBy: json['created_by'],
      updatedBy: json['updated_by'],
      isActive: json['is_active'] == true || json['is_active'] == 1,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'announcement_id': announcementId,
      'title': title,
      'content': content,
      'announcement_date': announcementDate.toIso8601String(),
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'created_by': createdBy,
      'updated_by': updatedBy,
      'is_active': isActive,
    };
  }
}
