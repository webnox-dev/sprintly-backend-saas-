import 'dart:io';
// import 'package:googleapis/calendar/v3.dart' as calendar;
// import 'package:googleapis_auth/auth_io.dart';
import '../core/utils/logger.dart';
import '../config/app_config.dart';

/// Service for creating real Google Meet links via Google Calendar API.
///
/// Requires a Google Cloud service account with:
/// 1. Google Calendar API enabled
/// 2. Domain-wide delegation (if using Google Workspace)
/// 3. Service account JSON key file at the path specified in .env
///
/// Environment variables:
///   GOOGLE_SERVICE_ACCOUNT_PATH - Path to service account JSON file
///   GOOGLE_CALENDAR_ID          - Calendar ID to create events in (default: primary)
class GoogleMeetService {
  static final AppLogger _logger = AppLogger('GoogleMeetService');
  // static AutoRefreshingAuthClient? _authClient;
  static bool _initialized = false;
  static bool _available = false;

  /// Initialize the service with the service account credentials.
  static Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    try {
      final saPath = AppConfig.googleServiceAccountPath;

      final file = File(saPath);
      if (!await file.exists()) {
        _logger.warning(
          'Google service account file not found at "$saPath". '
          'Google Meet link generation will be disabled. '
          'To enable: place your service account JSON at "$saPath" '
          'or set GOOGLE_SERVICE_ACCOUNT_PATH env variable.',
        );
        return;
      }

      // final jsonStr = await file.readAsString();
      // final credentials = ServiceAccountCredentials.fromJson(jsonStr);

      // _authClient = await clientViaServiceAccount(credentials, [
      //   calendar.CalendarApi.calendarScope,
      // ]);

      _available = false; // Forced false due to missing dependencies
      _logger.info('Google Meet service disabled (dependencies missing)');
    } catch (e, st) {
      _logger.error('Failed to initialize Google Meet service: $e', e, st);
      _available = false;
    }
  }

  /// Whether the Google Meet service is available (credentials configured).
  static bool get isAvailable => _available;

  /// Create a real Google Meet link by creating a Google Calendar event.
  ///
  /// Returns the Google Meet link string, or null if creation failed.
  static Future<String?> createMeetLink({
    required String meetingName,
    required String meetingDate, // YYYY-MM-DD
    required String startTime, // HH:mm
    required String endTime, // HH:mm
    String? description,
    List<String>? attendeeEmails,
  }) async {
    _logger.warning('Google Meet service disabled — skipping link generation');
    return null;

    /*
    if (!_available || _authClient == null) {
      _logger.warning(
        'Google Meet service not available — skipping link generation',
      );
      return null;
    }

    try {
      final calendarApi = calendar.CalendarApi(_authClient!);
      final calendarId = AppConfig.googleCalendarId;

      // Parse date & time into DateTime
      final dateParts = meetingDate.split('-');
      final startParts = startTime.split(':');
      final endParts = endTime.split(':');

      final startDateTime = DateTime(
        int.parse(dateParts[0]),
        int.parse(dateParts[1]),
        int.parse(dateParts[2]),
        int.parse(startParts[0]),
        int.parse(startParts[1]),
      );

      final endDateTime = DateTime(
        int.parse(dateParts[0]),
        int.parse(dateParts[1]),
        int.parse(dateParts[2]),
        int.parse(endParts[0]),
        int.parse(endParts[1]),
      );

      // Build attendee list
      final attendees = attendeeEmails
          ?.where((e) => e.isNotEmpty)
          .map((email) => calendar.EventAttendee(email: email))
          .toList();

      // Create event with conference data (Google Meet)
      final event = calendar.Event(
        summary: meetingName,
        description: description ?? 'Created by Sprintly Admin',
        start: calendar.EventDateTime(
          dateTime: startDateTime,
          timeZone: 'Asia/Kolkata',
        ),
        end: calendar.EventDateTime(
          dateTime: endDateTime,
          timeZone: 'Asia/Kolkata',
        ),
        attendees: attendees,
        conferenceData: calendar.ConferenceData(
          createRequest: calendar.CreateConferenceRequest(
            requestId:
                '${meetingName.hashCode}-${DateTime.now().millisecondsSinceEpoch}',
            conferenceSolutionKey: calendar.ConferenceSolutionKey(
              type: 'hangoutsMeet',
            ),
          ),
        ),
      );

      final createdEvent = await calendarApi.events.insert(
        event,
        calendarId,
        conferenceDataVersion: 1,
        sendUpdates:
            'none', // Don't send Google Calendar invites (we handle our own)
      );

      final meetLink =
          createdEvent.hangoutLink ??
          createdEvent.conferenceData?.entryPoints
              ?.firstWhere(
                (ep) => ep.entryPointType == 'video',
                orElse: () => calendar.EntryPoint(),
              )
              .uri;

      if (meetLink != null && meetLink.isNotEmpty) {
        _logger.info('Created Google Meet link: $meetLink for "$meetingName"');
        return meetLink;
      }

      _logger.warning('Event created but no Meet link returned');
      return null;
    } catch (e, st) {
      _logger.error('Failed to create Google Meet link: $e', e, st);
      return null;
    }
    */
  }

  /// Dispose the auth client when shutting down.
  static void dispose() {
    // _authClient?.close();
    // _authClient = null;
    _initialized = false;
    _available = false;
  }
}
