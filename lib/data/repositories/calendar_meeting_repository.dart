import 'dart:convert';
import '../../domain/models/calendar_meeting.dart';
import '../database/connection.dart';

/// Repository for calendar meetings CRUD operations
class CalendarMeetingRepository {
  /// Create a new meeting
  Future<CalendarMeeting> createMeeting(CalendarMeeting meeting) async {
    final result = await DatabaseConnection.query(
      '''
      INSERT INTO calendar_meetings (
        meeting_name, meeting_description,
        host_id, host_name, host_email, host_img,
        meeting_venue,
        meeting_date, meeting_start_time, meeting_end_time, total_duration,
        meeting_members, meeting_accepted_members, meeting_declined_members,
        gmeet_link, meeting_status, reminders_sent,
        created_by, updated_by,
        postpone_reason, original_date, original_start_time, original_end_time,
        postponed_by, postponed_at
      ) VALUES (
        @meeting_name, @meeting_description,
        @host_id, @host_name, @host_email, @host_img,
        @meeting_venue,
        @meeting_date::DATE, @meeting_start_time::TIME, @meeting_end_time::TIME, @total_duration,
        @meeting_members::JSONB, @meeting_accepted_members::JSONB, @meeting_declined_members::JSONB,
        @gmeet_link, @meeting_status, @reminders_sent::JSONB,
        @created_by, @updated_by,
        @postpone_reason, @original_date::DATE, @original_start_time::TIME, @original_end_time::TIME,
        @postponed_by, @postponed_at::TIMESTAMP
      ) RETURNING *
      ''',
      values: {
        'meeting_name': meeting.meetingName,
        'meeting_description': meeting.meetingDescription,
        'host_id': meeting.hostId,
        'host_name': meeting.hostName,
        'host_email': meeting.hostEmail,
        'host_img': meeting.hostImg,
        'meeting_venue': meeting.meetingVenue,
        'meeting_date': meeting.meetingDate,
        'meeting_start_time': meeting.meetingStartTime,
        'meeting_end_time': meeting.meetingEndTime,
        'total_duration': meeting.totalDuration,
        'meeting_members': jsonEncode(meeting.meetingMembers),
        'meeting_accepted_members': jsonEncode(meeting.meetingAcceptedMembers),
        'meeting_declined_members': jsonEncode(meeting.meetingDeclinedMembers),
        'gmeet_link': meeting.gmeetLink,
        'meeting_status': meeting.meetingStatus,
        'reminders_sent': jsonEncode(meeting.remindersSent),
        'created_by': meeting.createdBy,
        'updated_by': meeting.updatedBy,
        'postpone_reason': meeting.postponeReason,
        'original_date': meeting.originalDate,
        'original_start_time': meeting.originalStartTime,
        'original_end_time': meeting.originalEndTime,
        'postponed_by': meeting.postponedBy,
        'postponed_at': meeting.postponedAt?.toIso8601String(),
      },
    );
    return CalendarMeeting.fromJson(result.first);
  }

  /// Get all meetings with optional filters (for admin - all meetings)
  Future<(List<CalendarMeeting>, int)> getAllMeetings({
    String? search,
    String? hostId,
    String? status,
    DateTime? startDate,
    DateTime? endDate,
    int page = 1,
    int limit = 20,
    String? sortBy,
    String? sortOrder,
  }) async {
    final whereClauses = <String>[];
    final values = <String, dynamic>{};

    if (search != null && search.isNotEmpty) {
      whereClauses.add(
        "(LOWER(meeting_name) LIKE @search OR LOWER(meeting_description) LIKE @search)",
      );
      values['search'] = '%${search.toLowerCase()}%';
    }

    if (hostId != null && hostId.isNotEmpty) {
      whereClauses.add("host_id = @host_id");
      values['host_id'] = hostId;
    }

    if (status != null && status.isNotEmpty) {
      whereClauses.add("meeting_status = @status");
      values['status'] = status;
    }

    if (startDate != null) {
      whereClauses.add("meeting_date >= @start_date::DATE");
      values['start_date'] = startDate.toIso8601String().split('T')[0];
    }
    if (endDate != null) {
      whereClauses.add("meeting_date <= @end_date::DATE");
      values['end_date'] = endDate.toIso8601String().split('T')[0];
    }

    final whereClause = whereClauses.isNotEmpty
        ? 'WHERE ${whereClauses.join(' AND ')}'
        : '';

    // Sorting
    final validSortColumns = [
      'meeting_name',
      'meeting_date',
      'created_at',
      'meeting_start_time',
    ];
    final sortColumn = validSortColumns.contains(sortBy)
        ? sortBy!
        : 'meeting_date';
    final order = sortOrder?.toUpperCase() == 'ASC' ? 'ASC' : 'DESC';

    // Get total count
    final countResult = await DatabaseConnection.query(
      'SELECT COUNT(*) as count FROM calendar_meetings $whereClause',
      values: values,
    );
    final totalCount = (countResult.first['count'] as int?) ?? 0;

    // Pagination
    final offset = (page - 1) * limit;
    values['limit'] = limit;
    values['offset'] = offset;

    final result = await DatabaseConnection.query('''
      SELECT * FROM calendar_meetings
      $whereClause
      ORDER BY $sortColumn $order, meeting_start_time ASC
      LIMIT @limit OFFSET @offset
      ''', values: values);

    final meetings = result.map((row) {
      return CalendarMeeting.fromJson(Map<String, dynamic>.from(row));
    }).toList();

    return (meetings, totalCount);
  }

  /// Get meetings for a specific user (admin or employee) - only meetings they are a member of
  Future<(List<CalendarMeeting>, int)> getMeetingsForUser({
    required String userId,
    String? search,
    String? status,
    DateTime? startDate,
    DateTime? endDate,
    int page = 1,
    int limit = 20,
    String? sortBy,
    String? sortOrder,
  }) async {
    final whereClauses = <String>[];
    final values = <String, dynamic>{'user_id': userId};

    // User must be host OR a member
    whereClauses.add(
      "(host_id = @user_id OR meeting_members @> @user_id_jsonb::JSONB)",
    );
    values['user_id_jsonb'] = jsonEncode([
      {'user_id': userId},
    ]);

    if (search != null && search.isNotEmpty) {
      whereClauses.add(
        "(LOWER(meeting_name) LIKE @search OR LOWER(meeting_description) LIKE @search)",
      );
      values['search'] = '%${search.toLowerCase()}%';
    }

    if (status != null && status.isNotEmpty) {
      whereClauses.add("meeting_status = @status");
      values['status'] = status;
    }

    if (startDate != null) {
      whereClauses.add("meeting_date >= @start_date::DATE");
      values['start_date'] = startDate.toIso8601String().split('T')[0];
    }
    if (endDate != null) {
      whereClauses.add("meeting_date <= @end_date::DATE");
      values['end_date'] = endDate.toIso8601String().split('T')[0];
    }

    final whereClause = 'WHERE ${whereClauses.join(' AND ')}';

    final validSortColumns = [
      'meeting_name',
      'meeting_date',
      'created_at',
      'meeting_start_time',
    ];
    final sortColumn = validSortColumns.contains(sortBy)
        ? sortBy!
        : 'meeting_date';
    final order = sortOrder?.toUpperCase() == 'ASC' ? 'ASC' : 'DESC';

    // Get total count
    final countResult = await DatabaseConnection.query(
      'SELECT COUNT(*) as count FROM calendar_meetings $whereClause',
      values: values,
    );
    final totalCount = (countResult.first['count'] as int?) ?? 0;

    // Pagination
    final offset = (page - 1) * limit;
    values['limit'] = limit;
    values['offset'] = offset;

    final result = await DatabaseConnection.query('''
      SELECT * FROM calendar_meetings
      $whereClause
      ORDER BY $sortColumn $order, meeting_start_time ASC
      LIMIT @limit OFFSET @offset
      ''', values: values);

    final meetings = result.map((row) {
      return CalendarMeeting.fromJson(Map<String, dynamic>.from(row));
    }).toList();

    return (meetings, totalCount);
  }

  /// Get a meeting by ID
  Future<CalendarMeeting?> getMeetingById(String meetingId) async {
    final result = await DatabaseConnection.query(
      'SELECT * FROM calendar_meetings WHERE meeting_id = @meeting_id',
      values: {'meeting_id': meetingId},
    );
    if (result.isEmpty) return null;
    return CalendarMeeting.fromJson(Map<String, dynamic>.from(result.first));
  }

  /// Update a meeting
  Future<CalendarMeeting?> updateMeeting(
    String meetingId,
    Map<String, dynamic> updates,
  ) async {
    final setClauses = <String>[];
    final values = <String, dynamic>{'meeting_id': meetingId};

    updates.forEach((key, value) {
      if (key != 'meeting_id' && key != 'created_at') {
        // Handle JSONB fields
        if (key == 'meeting_members' ||
            key == 'meeting_accepted_members' ||
            key == 'meeting_declined_members' ||
            key == 'reminders_sent') {
          values[key] = value is String ? value : jsonEncode(value);
          setClauses.add('$key = @$key::JSONB');
        } else if (key == 'meeting_date') {
          values[key] = value;
          setClauses.add('$key = @$key::DATE');
        } else if (key == 'meeting_start_time' || key == 'meeting_end_time') {
          values[key] = value;
          setClauses.add('$key = @$key::TIME');
        } else if (key == 'postponed_at') {
          values[key] = value;
          setClauses.add('$key = @$key::TIMESTAMP');
        } else if (key == 'original_date') {
          values[key] = value;
          setClauses.add('$key = @$key::DATE');
        } else if (key == 'original_start_time' || key == 'original_end_time') {
          values[key] = value;
          setClauses.add('$key = @$key::TIME');
        } else {
          values[key] = value;
          setClauses.add('$key = @$key');
        }
      }
    });

    if (setClauses.isEmpty) return await getMeetingById(meetingId);

    final query =
        '''
      UPDATE calendar_meetings
      SET ${setClauses.join(', ')}
      WHERE meeting_id = @meeting_id
      RETURNING meeting_id
    ''';

    final result = await DatabaseConnection.query(query, values: values);
    if (result.isEmpty) return null;
    return await getMeetingById(result.first['meeting_id'].toString());
  }

  /// Delete a meeting
  Future<bool> deleteMeeting(String meetingId) async {
    final count = await DatabaseConnection.execute(
      'DELETE FROM calendar_meetings WHERE meeting_id = @meeting_id',
      values: {'meeting_id': meetingId},
    );
    return count > 0;
  }

  /// Get upcoming meetings for reminder checks (meetings starting within next X minutes)
  Future<List<CalendarMeeting>> getUpcomingMeetingsForReminders() async {
    // Get meetings that are scheduled for today and haven't had all reminders sent
    final now = DateTime.now();
    final result = await DatabaseConnection.query(
      '''
      SELECT * FROM calendar_meetings
      WHERE meeting_date = @today::DATE
        AND meeting_status = 'scheduled'
        AND (
          (reminders_sent->>'15min')::BOOLEAN = FALSE
          OR (reminders_sent->>'10min')::BOOLEAN = FALSE
          OR (reminders_sent->>'5min')::BOOLEAN = FALSE
          OR (reminders_sent->>'2min')::BOOLEAN = FALSE
        )
      ORDER BY meeting_start_time ASC
      ''',
      values: {'today': now.toIso8601String().split('T')[0]},
    );

    return result.map((row) {
      return CalendarMeeting.fromJson(Map<String, dynamic>.from(row));
    }).toList();
  }

  /// Update reminder status for a meeting
  Future<void> updateReminderStatus(
    String meetingId,
    String reminderType,
  ) async {
    await DatabaseConnection.execute(
      '''
      UPDATE calendar_meetings
      SET reminders_sent = jsonb_set(reminders_sent, @path::TEXT[], 'true'::JSONB)
      WHERE meeting_id = @meeting_id
      ''',
      values: {'meeting_id': meetingId, 'path': '{$reminderType}'},
    );
  }

  /// Mark meeting as completed
  Future<void> completeMeeting(String meetingId) async {
    await DatabaseConnection.execute(
      '''
      UPDATE calendar_meetings
      SET meeting_status = 'completed'
      WHERE meeting_id = @meeting_id
      ''',
      values: {'meeting_id': meetingId},
    );
  }

  /// Respond to a meeting (accept/decline)
  Future<CalendarMeeting?> respondToMeeting({
    required String meetingId,
    required String userId,
    required String response, // 'accepted' or 'declined'
  }) async {
    final meeting = await getMeetingById(meetingId);
    if (meeting == null) return null;

    List<String> acceptedMembers = List<String>.from(
      meeting.meetingAcceptedMembers,
    );
    List<String> declinedMembers = List<String>.from(
      meeting.meetingDeclinedMembers,
    );

    if (response == 'accepted') {
      if (!acceptedMembers.contains(userId)) {
        acceptedMembers.add(userId);
      }
      declinedMembers.remove(userId);
    } else if (response == 'declined') {
      if (!declinedMembers.contains(userId)) {
        declinedMembers.add(userId);
      }
      acceptedMembers.remove(userId);
    }

    return await updateMeeting(meetingId, {
      'meeting_accepted_members': jsonEncode(acceptedMembers),
      'meeting_declined_members': jsonEncode(declinedMembers),
    });
  }

  /// Check venue availability for a given time slot
  Future<List<CalendarMeeting>> checkVenueAvailability({
    required String venue,
    required String date,
    required String startTime,
    required String endTime,
    String? excludeMeetingId,
  }) async {
    final values = <String, dynamic>{
      'venue': venue,
      'date': date,
      'start': startTime,
      'end': endTime,
    };

    String excludeClause = '';
    if (excludeMeetingId != null) {
      excludeClause = "AND meeting_id != @exclude_id";
      values['exclude_id'] = excludeMeetingId;
    }

    // Default status is 'scheduled' or 'rescheduled'. We should ignore 'cancelled' or 'completed' if relevant.
    // Assuming 'scheduled' and 'rescheduled' are the active ones.
    // Or simpler: status != 'cancelled'
    final sql =
        '''
      SELECT * FROM calendar_meetings
      WHERE meeting_venue = @venue
        AND meeting_date = @date::DATE
        AND meeting_status IN ('scheduled', 'rescheduled')
        AND (
          (meeting_start_time < @end::TIME AND meeting_end_time > @start::TIME)
        )
        $excludeClause
    ''';

    final result = await DatabaseConnection.query(sql, values: values);
    return result
        .map((row) => CalendarMeeting.fromJson(Map<String, dynamic>.from(row)))
        .toList();
  }

  /// Check participant availability for a given time slot
  Future<List<CalendarMeeting>> checkParticipantAvailability({
    required List<String> userIds,
    required String date,
    required String startTime,
    required String endTime,
    String? excludeMeetingId,
  }) async {
    if (userIds.isEmpty) return [];

    final values = <String, dynamic>{
      'date': date,
      'start': startTime,
      'end': endTime,
    };

    String excludeClause = '';
    if (excludeMeetingId != null) {
      excludeClause = "AND meeting_id != @exclude_id";
      values['exclude_id'] = excludeMeetingId;
    }

    // Build placeholders for user IDs
    final placeholders = List.generate(
      userIds.length,
      (i) => '@id$i',
    ).join(', ');
    for (var i = 0; i < userIds.length; i++) {
      values['id$i'] = userIds[i];
    }

    // Logic:
    // 1. Host is one of the users
    // 2. One of the users is in meeting_members

    final sql =
        '''
      SELECT DISTINCT m.*
      FROM calendar_meetings m
      WHERE m.meeting_date = @date::DATE
        AND m.meeting_status IN ('scheduled', 'rescheduled')
        AND (
          (m.meeting_start_time < @end::TIME AND m.meeting_end_time > @start::TIME)
        )
        AND (
          m.host_id IN ($placeholders)
          OR EXISTS (
             SELECT 1 FROM jsonb_array_elements(m.meeting_members) as member 
             WHERE member->>'user_id' IN ($placeholders)
          )
        )
        $excludeClause
    ''';

    final result = await DatabaseConnection.query(sql, values: values);
    return result
        .map((row) => CalendarMeeting.fromJson(Map<String, dynamic>.from(row)))
        .toList();
  }

  /// Get all meetings in a time slot (any venue, any participant)
  Future<List<CalendarMeeting>> getMeetingsInTimeSlot({
    required String date,
    required String startTime,
    required String endTime,
    String? excludeMeetingId,
  }) async {
    final values = <String, dynamic>{
      'date': date,
      'start': startTime,
      'end': endTime,
    };

    String excludeClause = '';
    if (excludeMeetingId != null) {
      excludeClause = "AND meeting_id != @exclude_id";
      values['exclude_id'] = excludeMeetingId;
    }

    final sql =
        '''
      SELECT * FROM calendar_meetings
      WHERE meeting_date = @date::DATE
        AND meeting_status IN ('scheduled', 'rescheduled')
        AND (
          (meeting_start_time < @end::TIME AND meeting_end_time > @start::TIME)
        )
        $excludeClause
    ''';

    final result = await DatabaseConnection.query(sql, values: values);
    return result
        .map((row) => CalendarMeeting.fromJson(Map<String, dynamic>.from(row)))
        .toList();
  }
}
