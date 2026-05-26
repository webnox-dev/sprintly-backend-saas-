import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import '../data/repositories/face_repository.dart';
import '../data/repositories/attendance_repository.dart';
import '../core/response/api_response.dart';
import '../core/utils/logger.dart';

/// Face recognition API routes for biometric kiosk
class FaceRoutes {
  final FaceRepository _faceRepository = FaceRepository();
  final AttendanceRepository _attendanceRepository = AttendanceRepository();
  final AppLogger _logger = AppLogger('FaceRoutes');

  Router get router {
    final router = Router();

    // Get all enrolled employees with face embeddings
    router.get('/face/employees', _getAllEnrolled);

    // Get single employee face embedding
    router.get('/face/employees/<employeeId>', _getByEmployeeId);

    // Enroll face for employee
    router.post('/face/enroll', _enrollFace);

    // Punch in/out via face recognition
    router.post('/face/punch', _punchViaFace);

    // Verify fingerprint and punch (Server-side match)
    router.post('/face/verify-fingerprint', _verifyFingerprint);

    // Verify employee PIN (biometric kiosk)
    router.post('/face/verify-pin', _verifyPin);

    // Check if PIN is already taken (enrollment validation)
    router.post('/face/check-pin', _checkPin);

    // Get all employees for enrollment UI
    router.get('/face/employees-for-enrollment', _getEmployeesForEnrollment);

    // Delete face enrollment
    router.delete('/face/employees/<employeeId>', _deleteFace);

    return router;
  }

  /// POST /face/check-pin - Check if a PIN is already in use
  Future<Response> _checkPin(Request request) async {
    try {
      final body = await request.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;

      final pin = (data['pin'] as String?)?.trim();
      final excludeEmployeeId = data['exclude_employee_id'] as String?;

      if (pin == null || pin.isEmpty) {
        return ApiResponse.error(
          code: 'VALIDATION_ERROR',
          message: 'pin is required',
        ).toShelfResponse(statusCode: 400);
      }

      final taken = await _faceRepository.isPinTaken(
        pin,
        excludeEmployeeId: excludeEmployeeId,
      );

      return ApiResponse.success(
        data: {'available': !taken},
        message: taken ? 'PIN is already in use' : 'PIN is available',
      ).toShelfResponse();
    } catch (e, stackTrace) {
      _logger.error('Error in checkPin: $e', e, stackTrace);
      return ApiResponse.error(
        code: 'INTERNAL_ERROR',
        message: 'Internal server error',
      ).toShelfResponse(statusCode: 500);
    }
  }

  /// GET /face/employees - Get all enrolled employees with embeddings
  Future<Response> _getAllEnrolled(Request request) async {
    try {
      final employees = await _faceRepository.getAllEnrolled();
      return ApiResponse.success(
        data: {'count': employees.length, 'employees': employees},
      ).toShelfResponse();
    } catch (e, stackTrace) {
      _logger.error('Error in getAllEnrolled: $e', e, stackTrace);
      return ApiResponse.error(
        code: 'INTERNAL_ERROR',
        message: 'Internal server error',
      ).toShelfResponse(statusCode: 500);
    }
  }

  /// GET /face/employees/<employeeId> - Get face embedding for employee
  Future<Response> _getByEmployeeId(Request request, String employeeId) async {
    try {
      final employee = await _faceRepository.getByEmployeeId(employeeId);
      if (employee == null) {
        return ApiResponse.error(
          code: 'NOT_FOUND',
          message: 'Employee not enrolled',
        ).toShelfResponse(statusCode: 404);
      }
      return ApiResponse.success(data: employee).toShelfResponse();
    } catch (e, stackTrace) {
      _logger.error('Error in getByEmployeeId: $e', e, stackTrace);
      return ApiResponse.error(
        code: 'INTERNAL_ERROR',
        message: 'Internal server error',
      ).toShelfResponse(statusCode: 500);
    }
  }

  /// POST /face/enroll - Enroll face/fingerprint for employee
  Future<Response> _enrollFace(Request request) async {
    try {
      final body = await request.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;

      final employeeId = data['employee_id'] as String?;
      final embedding = data['embedding'] as String?;
      final fingerprintTemplate = data['fingerprint_template'] as String?;
      final pin = data['pin'] as String?;
      final department = data['department'] as String?;
      final enrolledBy = data['enrolled_by'] as String?;

      if (employeeId == null || employeeId.isEmpty) {
        return ApiResponse.error(
          code: 'VALIDATION_ERROR',
          message: 'employee_id is required',
        ).toShelfResponse(statusCode: 400);
      }

      if ((embedding == null || embedding.isEmpty) &&
          (fingerprintTemplate == null || fingerprintTemplate.isEmpty) &&
          (pin == null || pin.isEmpty)) {
        return ApiResponse.error(
          code: 'VALIDATION_ERROR',
          message:
              'At least one of embedding, fingerprint_template, or pin is required',
        ).toShelfResponse(statusCode: 400);
      }

      final result = await _faceRepository.enrollFace(
        employeeId: employeeId,
        embedding: embedding,
        fingerprintTemplate: fingerprintTemplate,
        pin: pin,
        department: department,
        enrolledBy: enrolledBy,
      );

      return ApiResponse.success(
        data: result,
        message: 'Biometric data enrolled successfully',
      ).toShelfResponse(statusCode: 201);
    } on Exception catch (e) {
      // Duplicate PIN — return 409 Conflict
      if (e.toString().contains('DUPLICATE_PIN')) {
        return ApiResponse.error(
          code: 'DUPLICATE_PIN',
          message:
              'This PIN is already used by another employee. Please choose a different PIN.',
        ).toShelfResponse(statusCode: 409);
      }
      _logger.error('Error in enrollFace: $e', e);
      // Include actual error for debugging
      return ApiResponse.error(
        code: 'INTERNAL_ERROR',
        message: e.toString(),
      ).toShelfResponse(statusCode: 500);
    }
  }

  /// POST /face/verify-pin - Verify employee PIN and return employee info
  Future<Response> _verifyPin(Request request) async {
    try {
      final body = await request.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;

      final pin = (data['pin'] as String?)?.trim();

      if (pin == null || pin.isEmpty) {
        return ApiResponse.error(
          code: 'VALIDATION_ERROR',
          message: 'pin is required',
        ).toShelfResponse(statusCode: 400);
      }

      final employee = await _faceRepository.verifyPin(pin);

      if (employee == null) {
        return ApiResponse.error(
          code: 'INVALID_PIN',
          message: 'Invalid PIN',
        ).toShelfResponse(statusCode: 401);
      }

      return ApiResponse.success(
        data: {
          'employee_id': employee['employee_id'],
          'employee_name': employee['employee_name'],
        },
        message: 'PIN verified',
      ).toShelfResponse();
    } catch (e, stackTrace) {
      _logger.error('Error in verifyPin: $e', e, stackTrace);
      return ApiResponse.error(
        code: 'INTERNAL_ERROR',
        message: 'Internal server error',
      ).toShelfResponse(statusCode: 500);
    }
  }

  /// POST /face/verify-fingerprint - Match fingerprint and record attendance
  Future<Response> _verifyFingerprint(Request request) async {
    try {
      final body = await request.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;

      final capturedTemplate = data['captured_template'] as String?;
      final clockTimestamp = data['clock_timestamp'] as String?;

      if (capturedTemplate == null || capturedTemplate.isEmpty) {
        return ApiResponse.error(
          code: 'VALIDATION_ERROR',
          message: 'captured_template is required',
        ).toShelfResponse(statusCode: 400);
      }

      // 1. Find the matching employee on the server
      final match = await _faceRepository.findFingerprintMatch(
        capturedTemplate,
      );

      if (match == null) {
        return ApiResponse.error(
          code: 'NOT_FOUND',
          message: 'Fingerprint not recognized',
        ).toShelfResponse(statusCode: 401);
      }

      final employeeId = match['employee_id'] as String;
      final employeeName = match['employee_name'] as String;

      // 2. Perform the punch logic (similar to face punch)
      // Extract local work date
      String workDate = (clockTimestamp ?? DateTime.now().toIso8601String())
          .split('T')[0];
      String timeNow = clockTimestamp ?? DateTime.now().toIso8601String();

      final existingAttendance = await _attendanceRepository
          .getByEmployeeAndDate(employeeId, workDate);

      String punchType;
      String message;

      if (existingAttendance == null) {
        punchType = 'IN';
        await _attendanceRepository.punchIn(
          employeeId: employeeId,
          workDate: workDate,
          clockOnForTheDay: timeNow,
          createdBy: 'kiosk_fingerprint',
          remoteReason: 'Fingerprint Match (Server-side)',
        );
        message = 'Welcome, $employeeName! Punched IN.';
      } else {
        punchType = 'OUT';
        // Simplified punch out for this verification
        await _attendanceRepository.punchOut(
          attendanceId: existingAttendance.attendanceId,
          clockOffForTheDay: timeNow,
          workedHrs: 0.0, // Should calculate properly in real app
          updatedBy: 'kiosk_fingerprint',
        );
        message = 'Goodbye, $employeeName! Punched OUT.';
      }

      return ApiResponse.success(
        data: {
          'employee_id': employeeId,
          'employee_name': employeeName,
          'punch_type': punchType,
          'timestamp': timeNow,
        },
        message: message,
      ).toShelfResponse();
    } catch (e, stackTrace) {
      _logger.error('Error in verifyFingerprint: $e', e, stackTrace);
      return ApiResponse.error(
        code: 'INTERNAL_ERROR',
        message: 'Fingerprint matching failed: $e',
      ).toShelfResponse(statusCode: 500);
    }
  }

  /// POST /face/punch - Record attendance via face recognition
  Future<Response> _punchViaFace(Request request) async {
    try {
      final body = await request.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;

      final employeeId = data['employee_id'] as String?;
      final matchConfidence = data['match_confidence'] as num?;
      final clockTimestamp = data['clock_timestamp'] as String?;

      if (employeeId == null || employeeId.isEmpty) {
        return ApiResponse.error(
          code: 'VALIDATION_ERROR',
          message: 'employee_id is required',
        ).toShelfResponse(statusCode: 400);
      }

      // Use timestamp from client - Extract local time components to avoid UTC conversion
      // When timestamp has timezone (e.g., +05:30), extract the local time part before storing
      String timeNow;
      String workDate;

      if (clockTimestamp != null) {
        _logger.info('📥 Received clock_timestamp: "$clockTimestamp"');

        // Extract local time by removing timezone suffix if present
        // Format: 2026-01-27T14:38:42.208481+05:30 -> 2026-01-27T14:38:42.208481
        String timeWithoutTz = clockTimestamp;

        // Remove timezone suffix: +05:30, -05:00, or Z
        if (timeWithoutTz.endsWith('Z')) {
          timeWithoutTz = timeWithoutTz.substring(0, timeWithoutTz.length - 1);
        } else {
          // Match timezone pattern at the end: +HH:MM or -HH:MM
          final tzMatch = RegExp(
            r'([+-]\d{2}:\d{2})$',
          ).firstMatch(timeWithoutTz);
          if (tzMatch != null) {
            timeWithoutTz = timeWithoutTz.substring(0, tzMatch.start);
          }
        }

        // Use the extracted time string (local time, no timezone) for storage
        timeNow = timeWithoutTz;
        // Extract work_date from timestamp (YYYY-MM-DD part)
        workDate = timeWithoutTz.split('T')[0];

        _logger.info('📦 Extracted time without timezone: "$timeNow"');
        _logger.info('📅 Extracted work_date: "$workDate"');
      } else {
        // Fallback to server time (shouldn't happen in normal flow)
        final now = DateTime.now();
        timeNow = now.toIso8601String();
        workDate = now.toIso8601String().split('T')[0];
      }

      // Check for existing attendance to determine punch type
      final existingAttendance = await _attendanceRepository
          .getByEmployeeAndDate(employeeId, workDate);

      if (existingAttendance == null) {
        // No attendance today - Punch IN
        _logger.info('No existing attendance for $employeeId, punching IN');

        final result = await _attendanceRepository.punchIn(
          employeeId: employeeId,
          workDate: workDate,
          clockOnForTheDay: timeNow,
          createdBy: employeeId,
          isRemoteOverride: false,
          remoteReason:
              'Face recognition punch (confidence: ${matchConfidence?.toStringAsFixed(1)}%)',
        );

        // Parse timestamp for display (extract time part)
        final timePart = timeNow.split('T').length > 1
            ? timeNow.split('T')[1].split('.')[0]
            : timeNow;

        return ApiResponse.success(
          data: {
            'punch_type': 'IN',
            'attendance_id': result.attendanceId,
            'timestamp': timeNow,
          },
          message: 'Punched IN at $timePart',
        ).toShelfResponse(statusCode: 201);
      } else if (existingAttendance.clockOffForTheDay == null) {
        // Has open session - Punch OUT
        _logger.info('Open session found for $employeeId, punching OUT');

        // Calculate worked hours - parse timestamps as local time
        final clockInStr = existingAttendance.clockOnForTheDay;
        final clockIn = DateTime.parse(clockInStr);
        final clockOut = DateTime.parse(timeNow);
        final workedDuration = clockOut.difference(clockIn);
        final workedHrs = workedDuration.inMinutes / 60.0;
        final sessionDuration = _formatDuration(workedDuration);

        await _attendanceRepository.punchOut(
          attendanceId: existingAttendance.attendanceId,
          clockOffForTheDay: timeNow,
          workedHrs: workedHrs,
          updatedBy: employeeId,
          sessionDuration: sessionDuration,
        );

        // Extract time part for display
        final timePart = timeNow.split('T').length > 1
            ? timeNow.split('T')[1].split('.')[0]
            : timeNow;

        return ApiResponse.success(
          data: {
            'punch_type': 'OUT',
            'session_duration': sessionDuration,
            'worked_hours': workedHrs.toStringAsFixed(2),
            'timestamp': timeNow,
          },
          message: 'Punched OUT at $timePart',
        ).toShelfResponse();
      } else {
        // Previous session already closed - Start a new session (Punch IN)
        _logger.info(
          'Previous session closed for $employeeId, starting new session',
        );

        final result = await _attendanceRepository.punchIn(
          employeeId: employeeId,
          workDate: workDate,
          clockOnForTheDay: timeNow,
          createdBy: employeeId,
          isRemoteOverride: false,
          remoteReason:
              'Face recognition punch - Session ${2} (confidence: ${matchConfidence?.toStringAsFixed(1)}%)',
        );

        // Extract time part for display
        final timePart = timeNow.split('T').length > 1
            ? timeNow.split('T')[1].split('.')[0]
            : timeNow;

        return ApiResponse.success(
          data: {
            'punch_type': 'IN',
            'attendance_id': result.attendanceId,
            'timestamp': timeNow,
            'session': 'new',
          },
          message: 'Started new session - Punched IN at $timePart',
        ).toShelfResponse(statusCode: 201);
      }
    } catch (e, stackTrace) {
      _logger.error('Error in punchViaFace: $e', e, stackTrace);
      return ApiResponse.error(
        code: 'INTERNAL_ERROR',
        message: 'Internal server error: $e',
      ).toShelfResponse(statusCode: 500);
    }
  }

  /// GET /face/employees-for-enrollment - Get all employees for enrollment UI
  Future<Response> _getEmployeesForEnrollment(Request request) async {
    try {
      final employees = await _faceRepository.getAllEmployeesForEnrollment();
      return ApiResponse.success(
        data: {'count': employees.length, 'employees': employees},
      ).toShelfResponse();
    } catch (e, stackTrace) {
      _logger.error('Error in getEmployeesForEnrollment: $e', e, stackTrace);
      return ApiResponse.error(
        code: 'INTERNAL_ERROR',
        message: 'Internal server error',
      ).toShelfResponse(statusCode: 500);
    }
  }

  /// DELETE /face/employees/<employeeId> - Delete face enrollment
  Future<Response> _deleteFace(Request request, String employeeId) async {
    try {
      final deleted = await _faceRepository.deleteFace(employeeId);
      if (!deleted) {
        return ApiResponse.error(
          code: 'NOT_FOUND',
          message: 'Face enrollment not found',
        ).toShelfResponse(statusCode: 404);
      }
      return ApiResponse.success(
        message: 'Face enrollment deleted successfully',
      ).toShelfResponse();
    } catch (e, stackTrace) {
      _logger.error('Error in deleteFace: $e', e, stackTrace);
      return ApiResponse.error(
        code: 'INTERNAL_ERROR',
        message: 'Internal server error',
      ).toShelfResponse(statusCode: 500);
    }
  }

  /// Format time for display
  String _formatTime(DateTime time) {
    final hour = time.hour > 12
        ? time.hour - 12
        : (time.hour == 0 ? 12 : time.hour);
    final amPm = time.hour >= 12 ? 'PM' : 'AM';
    return '$hour:${time.minute.toString().padLeft(2, '0')} $amPm';
  }

  /// Format duration for display
  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }
}
