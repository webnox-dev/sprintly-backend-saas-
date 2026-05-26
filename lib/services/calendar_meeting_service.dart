import '../data/repositories/calendar_meeting_repository.dart';
import '../data/repositories/leave_repository.dart';
import '../data/repositories/admin_repository.dart';
import '../data/repositories/employee_repository.dart';
import '../domain/models/calendar_meeting.dart';
import '../domain/models/leave.dart';
import '../domain/models/employee.dart';
import '../core/exceptions/app_exception.dart';
import '../core/utils/logger.dart';
import 'unified_notification_service.dart';
import 'google_meet_service.dart';

/// Service layer for calendar meeting business logic
class CalendarMeetingService {
  final CalendarMeetingRepository _repository = CalendarMeetingRepository();
  final LeaveRepository _leaveRepository = LeaveRepository();
  final AdminRepository _adminRepository = AdminRepository();
  final EmployeeRepository _employeeRepository = EmployeeRepository();
  final AppLogger _logger = AppLogger('CalendarMeetingService');

  /// Predefined venue options
  static const List<String> venueOptions = [
    'Board Room',
    'BDE Cabin',
    'HR Cabin',
    'Pantry',
    '1st Floor Developers Hub',
    '1st Floor DM\'s Hub',
    '2nd Floor DM\'s Hub',
    'Google Meet',
  ];

  /// Create a new meeting (Admin only)
  Future<CalendarMeeting> createMeeting(CalendarMeeting meeting) async {
    try {
      // Validate venue
      if (!venueOptions.contains(meeting.meetingVenue)) {
        throw ValidationException({
          'meeting_venue': [
            'Invalid venue. Choose from: ${venueOptions.join(", ")}',
          ],
        });
      }

      // Check for conflicts
      final participants = meeting.meetingMembers
          .map((m) => m['user_id'] as String?)
          .where((id) => id != null)
          .cast<String>()
          .toList();

      // Add host to participants check
      if (!participants.contains(meeting.hostId)) {
        participants.add(meeting.hostId);
      }

      final conflicts = await checkConflicts(
        venue: meeting.meetingVenue,
        date: meeting.meetingDate,
        startTime: meeting.meetingStartTime,
        endTime: meeting.meetingEndTime,
        participantIds: participants,
      );

      if (conflicts['venue_conflict'] != null) {
        final vc = conflicts['venue_conflict'];
        throw AppException(
          code: 'CONFLICT',
          message: 'Venue is already booked: ${vc['message']}',
        );
      }

      if ((conflicts['participant_conflicts'] as List).isNotEmpty) {
        final pc = conflicts['participant_conflicts'] as List;
        final messages = pc.map((c) => c['message'] as String).join('; ');
        throw AppException(
          code: 'CONFLICT',
          message: 'Participant conflict: $messages',
        );
      }

      if ((conflicts['participant_status'] as List).isNotEmpty) {
        final ps = conflicts['participant_status'] as List;
        // Block if on Leave
        final leaveConflicts = ps.where((s) => s['status'] == 'Leave').toList();
        if (leaveConflicts.isNotEmpty) {
          final msgs = leaveConflicts
              .map((s) => s['message'] as String)
              .join('; ');
          throw AppException(
            code: 'CONFLICT',
            message: 'Participant on leave: $msgs',
          );
        }
      }

      // Validate date is not in the past
      final today = DateTime.now();
      final meetingDate = DateTime.tryParse(meeting.meetingDate);
      if (meetingDate != null &&
          meetingDate.isBefore(DateTime(today.year, today.month, today.day))) {
        throw ValidationException({
          'meeting_date': ['Meeting date cannot be in the past'],
        });
      }

      // Calculate total duration
      final startParts = meeting.meetingStartTime.split(':');
      final endParts = meeting.meetingEndTime.split(':');
      if (startParts.length >= 2 && endParts.length >= 2) {
        final startMinutes =
            int.parse(startParts[0]) * 60 + int.parse(startParts[1]);
        final endMinutes = int.parse(endParts[0]) * 60 + int.parse(endParts[1]);
        final durationMinutes = endMinutes - startMinutes;

        if (durationMinutes <= 0) {
          throw ValidationException({
            'meeting_end_time': ['End time must be after start time'],
          });
        }

        final hours = durationMinutes ~/ 60;
        final minutes = durationMinutes % 60;
        final durationStr = hours > 0 ? '${hours}h ${minutes}m' : '${minutes}m';

        // If venue is "Google Meet", handle link generation logic
        String? resolvedGmeetLink = meeting.gmeetLink;

        // Only generate link if venue is Google Meet AND no link was provided manually
        if (meeting.meetingVenue == 'Google Meet' &&
            (resolvedGmeetLink == null || resolvedGmeetLink.isEmpty) &&
            GoogleMeetService.isAvailable) {
          // Collect attendee emails from meeting members
          final attendeeEmails = meeting.meetingMembers
              .map((m) => (m['user_email'] ?? '').toString())
              .where((e) => e.isNotEmpty)
              .toList();

          final realLink = await GoogleMeetService.createMeetLink(
            meetingName: meeting.meetingName,
            meetingDate: meeting.meetingDate,
            startTime: meeting.meetingStartTime,
            endTime: meeting.meetingEndTime,
            description: meeting.meetingDescription,
            attendeeEmails: attendeeEmails,
          );

          if (realLink != null) {
            resolvedGmeetLink = realLink;
            _logger.info('Using real Google Meet link: $realLink');
          } else {
            _logger.warning(
              'Could not create real Meet link, using frontend-provided link',
            );
          }
        }

        // Create meeting with calculated duration
        final meetingWithDuration = CalendarMeeting(
          meetingName: meeting.meetingName,
          meetingDescription: meeting.meetingDescription,
          hostId: meeting.hostId,
          hostName: meeting.hostName,
          hostEmail: meeting.hostEmail,
          hostImg: meeting.hostImg,
          meetingVenue: meeting.meetingVenue,
          meetingDate: meeting.meetingDate,
          meetingStartTime: meeting.meetingStartTime,
          meetingEndTime: meeting.meetingEndTime,
          totalDuration: durationStr,
          meetingMembers: meeting.meetingMembers,
          meetingAcceptedMembers: meeting.meetingAcceptedMembers,
          meetingDeclinedMembers: meeting.meetingDeclinedMembers,
          gmeetLink: resolvedGmeetLink,
          meetingStatus: meeting.meetingStatus,
          remindersSent: meeting.remindersSent,
          createdBy: meeting.createdBy,
          updatedBy: meeting.updatedBy,
        );

        final created = await _repository.createMeeting(meetingWithDuration);
        _logger.info(
          'Meeting "${created.meetingName}" created by ${created.hostId}',
        );

        // Send notifications to all members in background
        _sendMeetingInvitations(created).catchError((e, st) {
          _logger.warning('Failed to send meeting invitations: $e');
        });

        return created;
      }

      // If time parsing fails, create without duration calculation
      final created = await _repository.createMeeting(meeting);
      _logger.info(
        'Meeting "${created.meetingName}" created by ${created.hostId}',
      );

      // Send notifications to all members in background
      _sendMeetingInvitations(created).catchError((e, st) {
        _logger.warning('Failed to send meeting invitations: $e');
      });

      return created;
    } catch (e, stackTrace) {
      _logger.error('Error creating meeting: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Send meeting invitation notifications to all members
  Future<void> _sendMeetingInvitations(CalendarMeeting meeting) async {
    for (final member in meeting.meetingMembers) {
      final memberId = member['user_id'] as String?;
      final memberName = member['user_name'] as String? ?? '';
      final memberEmail = member['user_email'] as String? ?? '';
      final memberType = member['user_type'] as String? ?? 'Employee';

      if (memberId == null || memberId.isEmpty) continue;

      try {
        await UnifiedNotificationService.notifyMeetingScheduled(
          meetingId: meeting.meetingId ?? '',
          meetingName: meeting.meetingName,
          meetingDescription: meeting.meetingDescription ?? '',
          hostName: meeting.hostName ?? '',
          venue: meeting.meetingVenue,
          meetingDate: meeting.meetingDate,
          startTime: meeting.meetingStartTime,
          endTime: meeting.meetingEndTime,
          gmeetLink: meeting.gmeetLink,
          participantId: memberId,
          participantName: memberName,
          participantEmail: memberEmail,
          participantType: memberType,
        );
      } catch (e) {
        _logger.warning('Failed to send invitation to $memberId: $e');
      }
    }
  }

  /// Get all meetings (admin overview)
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
    try {
      return await _repository.getAllMeetings(
        search: search,
        hostId: hostId,
        status: status,
        startDate: startDate,
        endDate: endDate,
        page: page,
        limit: limit,
        sortBy: sortBy,
        sortOrder: sortOrder,
      );
    } catch (e, stackTrace) {
      _logger.error('Error getting all meetings: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Get meetings for a specific user
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
    try {
      return await _repository.getMeetingsForUser(
        userId: userId,
        search: search,
        status: status,
        startDate: startDate,
        endDate: endDate,
        page: page,
        limit: limit,
        sortBy: sortBy,
        sortOrder: sortOrder,
      );
    } catch (e, stackTrace) {
      _logger.error('Error getting user meetings: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Get meeting by ID
  Future<CalendarMeeting> getMeetingById(String meetingId) async {
    try {
      final meeting = await _repository.getMeetingById(meetingId);
      if (meeting == null) {
        throw NotFoundException(resource: 'Meeting', id: meetingId);
      }
      return meeting;
    } catch (e, stackTrace) {
      _logger.error('Error getting meeting by ID: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Update meeting (Admin only)
  Future<CalendarMeeting> updateMeeting(
    String meetingId,
    Map<String, dynamic> updates,
  ) async {
    try {
      // Validate venue if being updated
      if (updates.containsKey('meeting_venue')) {
        if (!venueOptions.contains(updates['meeting_venue'])) {
          throw ValidationException({
            'meeting_venue': [
              'Invalid venue. Choose from: ${venueOptions.join(", ")}',
            ],
          });
        }
      }

      // Recalculate duration if times are being updated
      final startTime = updates['meeting_start_time'] as String?;
      final endTime = updates['meeting_end_time'] as String?;
      if (startTime != null && endTime != null) {
        final startParts = startTime.split(':');
        final endParts = endTime.split(':');
        if (startParts.length >= 2 && endParts.length >= 2) {
          final startMinutes =
              int.parse(startParts[0]) * 60 + int.parse(startParts[1]);
          final endMinutes =
              int.parse(endParts[0]) * 60 + int.parse(endParts[1]);
          final durationMinutes = endMinutes - startMinutes;
          if (durationMinutes > 0) {
            final hours = durationMinutes ~/ 60;
            final minutes = durationMinutes % 60;
            updates['total_duration'] = hours > 0
                ? '${hours}h ${minutes}m'
                : '${minutes}m';
          }
        }
      }

      final updated = await _repository.updateMeeting(meetingId, updates);
      if (updated == null) {
        throw NotFoundException(resource: 'Meeting', id: meetingId);
      }

      _logger.info('Meeting "$meetingId" updated');

      // Notify members about updates
      UnifiedNotificationService.notifyMeetingUpdated(
        meetingId: meetingId,
        meetingName: updated.meetingName,
        hostName: updated.hostName ?? 'Admin',
        venue: updated.meetingVenue,
        meetingDate: updated.meetingDate,
        startTime: updated.meetingStartTime,
        endTime: updated.meetingEndTime,
        gmeetLink: updated.gmeetLink,
        participants: List<Map<String, dynamic>>.from(updated.meetingMembers),
      ).catchError(
        (e) => _logger.warning('Failed to send update notifications: $e'),
      );

      return updated;
    } catch (e, stackTrace) {
      _logger.error('Error updating meeting: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Delete meeting (Admin only)
  Future<bool> deleteMeeting(String meetingId) async {
    try {
      final existing = await _repository.getMeetingById(meetingId);
      if (existing == null) {
        throw NotFoundException(resource: 'Meeting', id: meetingId);
      }
      final success = await _repository.deleteMeeting(meetingId);
      if (!success) {
        throw NotFoundException(resource: 'Meeting', id: meetingId);
      }
      _logger.info('Meeting "$meetingId" deleted');

      // Notify members about cancellation
      UnifiedNotificationService.notifyMeetingCancelled(
        meetingId: meetingId,
        meetingName: existing.meetingName,
        hostName: existing.hostName ?? 'Admin',
        meetingDate: existing.meetingDate,
        startTime: existing.meetingStartTime,
        participants: List<Map<String, dynamic>>.from(existing.meetingMembers),
      ).catchError(
        (e) => _logger.warning('Failed to send cancellation notifications: $e'),
      );

      return success;
    } catch (e, stackTrace) {
      _logger.error('Error deleting meeting: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Respond to meeting invitation (Accept/Decline)
  Future<CalendarMeeting> respondToMeeting({
    required String meetingId,
    required String userId,
    required String response, // 'accepted' or 'declined'
  }) async {
    try {
      if (response != 'accepted' && response != 'declined') {
        throw ValidationException({
          'response': ['Response must be "accepted" or "declined"'],
        });
      }

      final updated = await _repository.respondToMeeting(
        meetingId: meetingId,
        userId: userId,
        response: response,
      );

      if (updated == null) {
        throw NotFoundException(resource: 'Meeting', id: meetingId);
      }

      _logger.info('User $userId $response meeting $meetingId');

      // Notify host about the response
      UnifiedNotificationService.notifyMeetingResponse(
        meetingId: meetingId,
        meetingName: updated.meetingName,
        responderId: userId,
        response: response,
        hostId: updated.hostId,
      ).catchError((e, st) {
        _logger.warning('Failed to notify host about response: $e');
      });

      return updated;
    } catch (e, stackTrace) {
      _logger.error('Error responding to meeting: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Postpone a meeting
  Future<CalendarMeeting> postponeMeeting({
    required String meetingId,
    required String newDate,
    required String newStartTime,
    required String newEndTime,
    required String reason,
    required String postponedBy,
  }) async {
    try {
      final meeting = await getMeetingById(meetingId);

      // Validate new date (must be in future relative to now, or at least today)
      final today = DateTime.now();
      final parsedDate = DateTime.tryParse(newDate);
      if (parsedDate != null &&
          parsedDate.isBefore(DateTime(today.year, today.month, today.day))) {
        throw ValidationException({
          'new_date': ['New meeting date cannot be in the past'],
        });
      }

      // Calculate new duration
      String? newDuration;
      final startParts = newStartTime.split(':');
      final endParts = newEndTime.split(':');
      if (startParts.length >= 2 && endParts.length >= 2) {
        final startMinutes =
            int.parse(startParts[0]) * 60 + int.parse(startParts[1]);
        final endMinutes = int.parse(endParts[0]) * 60 + int.parse(endParts[1]);
        final durationMinutes = endMinutes - startMinutes;

        if (durationMinutes <= 0) {
          throw ValidationException({
            'new_end_time': ['End time must be after start time'],
          });
        }

        final hours = durationMinutes ~/ 60;
        final minutes = durationMinutes % 60;
        newDuration = hours > 0 ? '${hours}h ${minutes}m' : '${minutes}m';
      }

      // Prepare updates
      // Store original details if not already stored (first postponement)
      // If already postponed, we keep the FIRST original date/time as the reference "original"
      // OR we update original to be the "previous" schedule.
      // Typically "original" means the one before THIS change.
      // Let's store the CURRENT meeting state as "original" before update.
      final updates = {
        'meeting_date': newDate,
        'meeting_start_time': newStartTime,
        'meeting_end_time': newEndTime,
        'total_duration': newDuration ?? meeting.totalDuration,
        'postpone_reason': reason,
        'postponed_by': postponedBy,
        'postponed_at': DateTime.now().toIso8601String(),
        'meeting_status':
            'rescheduled', // or just keep 'scheduled'? Using 'rescheduled' might be better for UI
        // Store previous schedule
        'original_date': meeting.meetingDate,
        'original_start_time': meeting.meetingStartTime,
        'original_end_time': meeting.meetingEndTime,

        // Reset reminders
        'reminders_sent': {
          '15min': false,
          '10min': false,
          '5min': false,
          '2min': false,
        },
        // Reset responses? Maybe. usually if time changes, people need to re-accept.
        // For now, let's reset confirmations
        'meeting_accepted_members': [],
        'meeting_declined_members': [],
      };

      final updated = await _repository.updateMeeting(meetingId, updates);
      if (updated == null) {
        throw NotFoundException(resource: 'Meeting', id: meetingId);
      }

      _logger.info('Meeting "$meetingId" postponed to $newDate');

      // Notify members
      UnifiedNotificationService.notifyMeetingPostponed(
        meetingId: meetingId,
        meetingName: meeting.meetingName,
        hostName: meeting.hostName ?? 'Admin',
        oldDate: meeting.meetingDate,
        oldStartTime: meeting.meetingStartTime,
        newDate: newDate,
        newStartTime: newStartTime,
        newEndTime: newEndTime,
        reason: reason,
        participants: meeting.meetingMembers,
      ).catchError((e, st) {
        _logger.warning('Failed to send postponement notifications: $e');
      });

      return updated;
    } catch (e, stackTrace) {
      _logger.error('Error postponing meeting: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Get predefined venue list
  List<String> getVenueOptions() {
    return venueOptions;
  }

  /// Check for scheduling conflicts
  /// Returns a map with conflict details
  Future<Map<String, dynamic>> checkConflicts({
    required String venue,
    required String date,
    required String startTime,
    required String endTime,
    required List<String> participantIds,
    String? excludeMeetingId,
  }) async {
    final conflicts = <String, dynamic>{
      'venue_conflict': null,
      'participant_conflicts': [],
      'participant_status': [],
    };

    // 1. Check Venue
    if (venue != 'Google Meet') {
      final venueMeetings = await _repository.checkVenueAvailability(
        venue: venue,
        date: date,
        startTime: startTime,
        endTime: endTime,
        excludeMeetingId: excludeMeetingId,
      );

      if (venueMeetings.isNotEmpty) {
        final existing = venueMeetings.first;
        conflicts['venue_conflict'] = {
          'meeting_name': existing.meetingName,
          'host_name': existing.hostName,
          'start_time': existing.meetingStartTime,
          'end_time': existing.meetingEndTime,
          'message':
              'Booked by ${existing.hostName} (${existing.meetingStartTime} - ${existing.meetingEndTime})',
        };
      }
    }

    // 2. Check Participants Meetings
    if (participantIds.isNotEmpty) {
      final userMeetings = await _repository.checkParticipantAvailability(
        userIds: participantIds,
        date: date,
        startTime: startTime,
        endTime: endTime,
        excludeMeetingId: excludeMeetingId,
      );

      // Map meetings back to users
      for (final userId in participantIds) {
        final conflicting = userMeetings.where((m) {
          final isHost = m.hostId == userId;
          final isMember = m.meetingMembers.any(
            (mem) => mem['user_id'] == userId,
          );
          return isHost || isMember;
        }).toList();

        if (conflicting.isNotEmpty) {
          final m = conflicting.first;
          (conflicts['participant_conflicts'] as List).add({
            'user_id': userId,
            'meeting_name': m.meetingName,
            'start_time': m.meetingStartTime,
            'end_time': m.meetingEndTime,
            'message':
                'In meeting: ${m.meetingName} (${m.meetingStartTime} - ${m.meetingEndTime})',
          });
        }
      }
    }

    // 3. Check Participant Leaves
    if (participantIds.isNotEmpty) {
      final leaves = await _leaveRepository.getActiveLeavesForUsers(
        participantIds,
        date,
      );
      for (final leave in leaves) {
        (conflicts['participant_status'] as List).add({
          'user_id': leave.employeeId,
          'status': 'Leave',
          'type': leave.leaveType,
          'message': 'On Leave (${leave.leaveType})',
        });
      }
    }

    return conflicts;
  }

  /// Get venue availability for a specific time slot
  Future<List<Map<String, dynamic>>> getVenueAvailability({
    required String date,
    required String startTime,
    required String endTime,
    String? excludeMeetingId,
  }) async {
    try {
      final meetings = await _repository.getMeetingsInTimeSlot(
        date: date,
        startTime: startTime,
        endTime: endTime,
        excludeMeetingId: excludeMeetingId,
      );

      return venueOptions.map((venue) {
        if (venue == 'Google Meet') {
          return {'venue': venue, 'is_available': true};
        }
        final conflicting = meetings
            .where((m) => m.meetingVenue == venue)
            .toList();
        return {
          'venue': venue,
          'is_available': conflicting.isEmpty,
          'current_meeting': conflicting.isNotEmpty
              ? conflicting.first.toJson()
              : null,
        };
      }).toList();
    } catch (e, stackTrace) {
      _logger.error('Error getting venue availability', e, stackTrace);
      rethrow;
    }
  }

  /// Get participant availability for a specific time slot
  Future<List<Map<String, dynamic>>> getParticipantAvailability({
    required String date,
    required String startTime,
    required String endTime,
    String? excludeMeetingId,
  }) async {
    try {
      // 1. Fetch all potential participants (Admins + Employees)
      // fetch Admins
      final admins = await _adminRepository.getAll();

      // fetch Employees (Map<String, dynamic> result)
      final empResult = await _employeeRepository.getAll(limit: 1000);
      final List<Employee> empList = empResult['data'] as List<Employee>? ?? [];

      final allParticipants = <Map<String, dynamic>>[];

      for (var a in admins) {
        allParticipants.add({
          'user_id': a.adminId,
          'display_id': a.adminId,
          'user_name': a.adminName,
          'user_email': a.adminCompanyEmail.isNotEmpty
              ? a.adminCompanyEmail
              : a.adminPersonalEmail,
          'user_type': 'Admin',
          'role': a.adminRole,
          'designation': a.adminRole,
          'user_img': a.adminImg,
        });
      }

      for (var e in empList) {
        allParticipants.add({
          'user_id': e.employeeId,
          'display_id': e.employeeId,
          'user_name': e.employeeName,
          'user_email': e.employeeCompanyEmail.isNotEmpty
              ? e.employeeCompanyEmail
              : e.employeePersonalEmail,
          'user_type': 'Employee',
          'role': e.employeeRole,
          'designation': e.employeeDesignation,
          'user_img': e.employeeImg,
        });
      }

      // 2. Fetch meetings in slot
      final meetings = await _repository.getMeetingsInTimeSlot(
        date: date,
        startTime: startTime,
        endTime: endTime,
        excludeMeetingId: excludeMeetingId,
      );

      // 3. Fetch leaves in slot
      final leaves = await _leaveRepository.getAllActiveLeaves(date);

      // 4. Check availability
      return allParticipants.map((p) {
        final userId = p['user_id'];

        // Check for meeting conflict
        CalendarMeeting? meetingConflict;
        try {
          meetingConflict = meetings.firstWhere((m) {
            final isHost = m.hostId == userId;
            final isMember = m.meetingMembers.any(
              (mem) => mem['user_id'] == userId,
            );
            return isHost || isMember;
          });
        } catch (_) {}

        // Check for leave conflict
        Leave? leaveConflict;
        try {
          leaveConflict = leaves.firstWhere((l) => l.employeeId == userId);
        } catch (_) {}

        // Determine status
        final isAvailable = meetingConflict == null && leaveConflict == null;
        String? conflictType;
        Map<String, dynamic>? conflictDetails;

        if (meetingConflict != null) {
          conflictType = 'meeting';
          conflictDetails = {
            'meeting_name': meetingConflict.meetingName,
            'start_time': meetingConflict.meetingStartTime,
            'end_time': meetingConflict.meetingEndTime,
          };
        } else if (leaveConflict != null) {
          conflictType = 'leave';
          conflictDetails = {
            'leave_type': leaveConflict.leaveType,
            'is_half_day': leaveConflict.isHalfDay,
          };
        }

        return {
          ...p,
          'is_available': isAvailable,
          'conflict_type': conflictType,
          'conflict_details': conflictDetails,
        };
      }).toList();
    } catch (e, stackTrace) {
      _logger.error('Error getting participant availability', e, stackTrace);
      rethrow;
    }
  }
}
