/// Calendar Meeting domain model
class CalendarMeeting {
  final String? meetingId;
  final String meetingName;
  final String? meetingDescription;
  final String hostId;
  final String? hostName;
  final String? hostEmail;
  final String? hostImg;
  final String meetingVenue;
  final String meetingDate;
  final String meetingStartTime;
  final String meetingEndTime;
  final String? totalDuration;
  final List<Map<String, dynamic>> meetingMembers;
  final List<String> meetingAcceptedMembers;
  final List<String> meetingDeclinedMembers;
  final String? gmeetLink;
  final String meetingStatus;
  final Map<String, dynamic> remindersSent;
  final String createdBy;
  final DateTime? createdAt;
  final String? updatedBy;
  final DateTime? updatedAt;
  // Postpone tracking fields
  final String? postponeReason;
  final String? originalDate;
  final String? originalStartTime;
  final String? originalEndTime;
  final String? postponedBy;
  final DateTime? postponedAt;

  CalendarMeeting({
    this.meetingId,
    required this.meetingName,
    this.meetingDescription,
    required this.hostId,
    this.hostName,
    this.hostEmail,
    this.hostImg,
    required this.meetingVenue,
    required this.meetingDate,
    required this.meetingStartTime,
    required this.meetingEndTime,
    this.totalDuration,
    this.meetingMembers = const [],
    this.meetingAcceptedMembers = const [],
    this.meetingDeclinedMembers = const [],
    this.gmeetLink,
    this.meetingStatus = 'scheduled',
    this.remindersSent = const {
      '15min': false,
      '10min': false,
      '5min': false,
      '2min': false,
    },
    required this.createdBy,
    this.createdAt,
    this.updatedBy,
    this.updatedAt,
    this.postponeReason,
    this.originalDate,
    this.originalStartTime,
    this.originalEndTime,
    this.postponedBy,
    this.postponedAt,
  });

  factory CalendarMeeting.fromJson(Map<String, dynamic> json) {
    // Parse meeting_members - can be a List or a JSON string
    List<Map<String, dynamic>> parseMembers(dynamic value) {
      if (value == null) return [];
      if (value is List) {
        return value.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
      return [];
    }

    // Parse accepted/declined members - list of user IDs
    List<String> parseStringList(dynamic value) {
      if (value == null) return [];
      if (value is List) {
        return value.map((e) => e.toString()).toList();
      }
      return [];
    }

    // Parse reminders_sent
    Map<String, dynamic> parseReminders(dynamic value) {
      if (value == null) {
        return {'15min': false, '10min': false, '5min': false, '2min': false};
      }
      if (value is Map) {
        return Map<String, dynamic>.from(value);
      }
      return {'15min': false, '10min': false, '5min': false, '2min': false};
    }

    // Parse PostgreSQL TIME type - handles "Time(HH:MM:SS.mmm)" format
    String parseTime(dynamic value) {
      if (value == null) return '';
      final str = value.toString();
      // Handle "Time(HH:MM:SS.mmm)" format from PostgreSQL driver
      final timeMatch = RegExp(
        r'Time\((\d{2}:\d{2}(?::\d{2})?(?:\.\d+)?)\)',
      ).firstMatch(str);
      if (timeMatch != null) {
        final t = timeMatch.group(1)!;
        return t.length >= 5 ? t.substring(0, 5) : t; // Return HH:MM
      }
      // Already clean HH:MM or HH:MM:SS
      if (str.contains(':')) {
        return str.length >= 5 ? str.substring(0, 5) : str;
      }
      return str;
    }

    // Parse PostgreSQL DATE type - handles "YYYY-MM-DD HH:MM:SS.mmmZ" format
    String parseDate(dynamic value) {
      if (value == null) return '';
      final str = value.toString();
      // Extract YYYY-MM-DD from any datetime format
      final dateMatch = RegExp(r'(\d{4}-\d{2}-\d{2})').firstMatch(str);
      return dateMatch?.group(1) ?? str;
    }

    return CalendarMeeting(
      meetingId: json['meeting_id']?.toString(),
      meetingName: json['meeting_name'] as String? ?? '',
      meetingDescription: json['meeting_description'] as String?,
      hostId: json['host_id'] as String? ?? '',
      hostName: json['host_name'] as String?,
      hostEmail: json['host_email'] as String?,
      hostImg: json['host_img'] as String?,
      meetingVenue: json['meeting_venue'] as String? ?? '',
      meetingDate: parseDate(json['meeting_date']),
      meetingStartTime: parseTime(json['meeting_start_time']),
      meetingEndTime: parseTime(json['meeting_end_time']),
      totalDuration: json['total_duration'] as String?,
      meetingMembers: parseMembers(json['meeting_members']),
      meetingAcceptedMembers: parseStringList(json['meeting_accepted_members']),
      meetingDeclinedMembers: parseStringList(json['meeting_declined_members']),
      gmeetLink: json['gmeet_link'] as String?,
      meetingStatus: json['meeting_status'] as String? ?? 'scheduled',
      remindersSent: parseReminders(json['reminders_sent']),
      createdBy: json['created_by'] as String? ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'].toString())
          : null,
      updatedBy: json['updated_by'] as String?,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'].toString())
          : null,
      postponeReason: json['postpone_reason'] as String?,
      originalDate: json['original_date'] != null
          ? parseDate(json['original_date'])
          : null,
      originalStartTime: json['original_start_time'] != null
          ? parseTime(json['original_start_time'])
          : null,
      originalEndTime: json['original_end_time'] != null
          ? parseTime(json['original_end_time'])
          : null,
      postponedBy: json['postponed_by'] as String?,
      postponedAt: json['postponed_at'] != null
          ? DateTime.parse(json['postponed_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'meeting_id': meetingId,
      'meeting_name': meetingName,
      'meeting_description': meetingDescription,
      'host_id': hostId,
      'host_name': hostName,
      'host_email': hostEmail,
      'host_img': hostImg,
      'meeting_venue': meetingVenue,
      'meeting_date': meetingDate,
      'meeting_start_time': meetingStartTime,
      'meeting_end_time': meetingEndTime,
      'total_duration': totalDuration,
      'meeting_members': meetingMembers,
      'meeting_accepted_members': meetingAcceptedMembers,
      'meeting_declined_members': meetingDeclinedMembers,
      'gmeet_link': gmeetLink,
      'meeting_status': meetingStatus,
      'reminders_sent': remindersSent,
      'created_by': createdBy,
      'created_at': createdAt?.toIso8601String(),
      'updated_by': updatedBy,
      'updated_at': updatedAt?.toIso8601String(),
      'postpone_reason': postponeReason,
      'original_date': originalDate,
      'original_start_time': originalStartTime,
      'original_end_time': originalEndTime,
      'postponed_by': postponedBy,
      'postponed_at': postponedAt?.toIso8601String(),
    };
  }
}
