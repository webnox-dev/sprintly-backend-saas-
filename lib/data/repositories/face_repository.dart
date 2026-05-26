import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../database/connection.dart';
import '../../core/utils/logger.dart';

/// Face embedding repository for biometric kiosk operations
class FaceRepository {
  final AppLogger _logger = AppLogger('FaceRepository');

  /// Hash a PIN using SHA256 for secure storage and comparison
  String _hashPin(String pin) {
    final bytes = utf8.encode(pin);
    return sha256.convert(bytes).toString();
  }

  /// Helper to convert DateTime fields to ISO strings for JSON encoding
  Map<String, dynamic> _toJsonSafe(Map<String, dynamic> row) {
    final result = Map<String, dynamic>.from(row);
    for (final key in result.keys.toList()) {
      if (result[key] is DateTime) {
        result[key] = (result[key] as DateTime).toIso8601String();
      }
    }
    return result;
  }

  /// Get all employees with face embeddings enrolled
  Future<List<Map<String, dynamic>>> getAllEnrolled() async {
    try {
      final results = await DatabaseConnection.query('''
        SELECT 
          f.id,
          f.employee_id,
          e.employee_name,
          f.department,
          f.embedding,
          f.fingerprint_template,
          f.enrolled_at,
          f.is_active
        FROM face_embeddings f
        JOIN employees e ON f.employee_id = e.employee_id
        WHERE f.is_active = true AND e.status = 1
        ORDER BY e.employee_name ASC
      ''');

      return results.map((r) => _toJsonSafe(r)).toList();
    } catch (e, stackTrace) {
      _logger.error('Error getting enrolled faces: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Get face embedding for specific employee
  Future<Map<String, dynamic>?> getByEmployeeId(String employeeId) async {
    try {
      final result = await DatabaseConnection.queryOne(
        '''
        SELECT 
          f.id,
          f.employee_id,
          e.employee_name,
          f.department,
          f.embedding,
          f.fingerprint_template,
          f.enrolled_at,
          f.is_active
        FROM face_embeddings f
        JOIN employees e ON f.employee_id = e.employee_id
        WHERE f.employee_id = @employeeId AND f.is_active = true
      ''',
        values: {'employeeId': employeeId},
      );

      return result != null ? _toJsonSafe(result) : null;
    } catch (e, stackTrace) {
      _logger.error('Error getting face embedding: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Check if a PIN is already taken by another employee
  Future<bool> isPinTaken(String pin, {String? excludeEmployeeId}) async {
    try {
      final Map<String, dynamic> values = {'pin': _hashPin(pin)};
      String excludeClause = '';
      if (excludeEmployeeId != null) {
        excludeClause = 'AND employee_id != @excludeEmployeeId';
        values['excludeEmployeeId'] = excludeEmployeeId;
      }
      final result = await DatabaseConnection.queryOne('''
        SELECT employee_id FROM face_embeddings
        WHERE pin = @pin
          AND is_active = true
          $excludeClause
        LIMIT 1
      ''', values: values);
      return result != null;
    } catch (e, stackTrace) {
      _logger.error('Error checking PIN uniqueness: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Enroll or update face/fingerprint/PIN for employee
  Future<Map<String, dynamic>> enrollFace({
    required String employeeId,
    String? embedding,
    String? fingerprintTemplate,
    String? pin,
    String? department,
    String? enrolledBy,
  }) async {
    try {
      // Check if employee exists
      final employeeCheck = await DatabaseConnection.queryOne(
        'SELECT employee_id FROM employees WHERE employee_id = @employeeId',
        values: {'employeeId': employeeId},
      );

      if (employeeCheck == null) {
        throw Exception('Employee not found: $employeeId');
      }

      // Duplicate PIN check — only if a new PIN is being set
      if (pin != null && pin.isNotEmpty) {
        final taken = await isPinTaken(pin, excludeEmployeeId: employeeId);
        if (taken) {
          throw Exception(
            'DUPLICATE_PIN: This PIN is already in use by another employee.',
          );
        }
      }

      // Upsert face embedding
      // Note: We use COALESCE to keep existing values if passing null (partial update support)
      final result = await DatabaseConnection.queryOne(
        '''
        INSERT INTO face_embeddings (employee_id, embedding, fingerprint_template, pin, department, enrolled_by)
        VALUES (@employeeId, @embedding, @fingerprintTemplate, @pin, @department, @enrolledBy)
        ON CONFLICT (employee_id)
        DO UPDATE SET
          embedding = COALESCE(@embedding, face_embeddings.embedding),
          fingerprint_template = COALESCE(@fingerprintTemplate, face_embeddings.fingerprint_template),
          pin = COALESCE(@pin, face_embeddings.pin),
          department = COALESCE(@department, face_embeddings.department),
          updated_at = CURRENT_TIMESTAMP,
          is_active = true
        RETURNING id, employee_id, enrolled_at, updated_at
      ''',
        values: {
          'employeeId': employeeId,
          'embedding': embedding,
          'fingerprintTemplate': fingerprintTemplate,
          'pin': (pin != null && pin.isNotEmpty) ? _hashPin(pin) : null,
          'department': department,
          'enrolledBy': enrolledBy,
        },
      );

      if (result == null) {
        throw Exception('Failed to enroll biometric data');
      }

      _logger.info('Biometric data enrolled for employee: $employeeId');
      return _toJsonSafe(result);
    } catch (e, stackTrace) {
      _logger.error('Error enrolling face: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Verify a kiosk PIN and return the matching employee
  Future<Map<String, dynamic>?> verifyPin(String pin) async {
    try {
      if (pin.isEmpty) return null;
      final hashedPin = _hashPin(pin);
      final result = await DatabaseConnection.queryOne(
        '''
        SELECT
          f.employee_id,
          e.employee_name
        FROM face_embeddings f
        JOIN employees e ON f.employee_id = e.employee_id
        WHERE f.pin = @pin
          AND f.is_active = true
          AND e.status = 1
        LIMIT 1
      ''',
        values: {'pin': hashedPin},
      );
      return result;
    } catch (e, stackTrace) {
      _logger.error('Error verifying PIN: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Match fingerprint against stored templates (Option A: Server-side)
  Future<Map<String, dynamic>?> findFingerprintMatch(
    String capturedTemplate,
  ) async {
    try {
      // 1. Get all active enrollments with a fingerprint
      final employees = await DatabaseConnection.query('''
        SELECT 
          f.employee_id,
          e.employee_name,
          f.fingerprint_template
        FROM face_embeddings f
        JOIN employees e ON f.employee_id = e.employee_id
        WHERE f.is_active = true 
        AND f.fingerprint_template IS NOT NULL 
        AND f.fingerprint_template != ''
      ''');

      if (employees.isEmpty) return null;

      _logger.info(
        'Comparing capture against ${employees.length} enrolled fingerprints',
      );

      // 2. Perform matching
      // Note: Because Mantra RD Service uses encrypted PID blocks that change every scan,
      // a standard string comparison will NOT work.
      // High-end server-side matching requires the Mantra SDK to decrypt and compare ISO templates.

      for (final emp in employees) {
        final stored = emp['fingerprint_template'] as String;

        // DEBUG: Log first 30 chars for visual comparison
        _logger.info('--- Comparing with ${emp['employee_name']} ---');
        _logger.info(
          '  Stored prefix:   "${stored.length > 30 ? stored.substring(0, 30) : stored}..."',
        );
        _logger.info(
          '  Captured prefix: "${capturedTemplate.length > 30 ? capturedTemplate.substring(0, 30) : capturedTemplate}..."',
        );

        if (stored == capturedTemplate) {
          _logger.info('✅ MATCH FOUND!');
          return emp;
        }
      }

      _logger.warning('❌ No matching fingerprint found in database');
      return null;
    } catch (e, stackTrace) {
      _logger.error('Error in findFingerprintMatch: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Deactivate face embedding (soft delete)
  Future<bool> deactivateFace(String employeeId) async {
    try {
      final affectedRows = await DatabaseConnection.execute(
        '''
        UPDATE face_embeddings 
        SET is_active = false, updated_at = CURRENT_TIMESTAMP
        WHERE employee_id = @employeeId
      ''',
        values: {'employeeId': employeeId},
      );

      return affectedRows > 0;
    } catch (e, stackTrace) {
      _logger.error('Error deactivating face: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Delete face embedding permanently
  Future<bool> deleteFace(String employeeId) async {
    try {
      final affectedRows = await DatabaseConnection.execute(
        '''
        DELETE FROM face_embeddings 
        WHERE employee_id = @employeeId
      ''',
        values: {'employeeId': employeeId},
      );

      return affectedRows > 0;
    } catch (e, stackTrace) {
      _logger.error('Error deleting face: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Get all employees (for enrollment UI)
  /// Returns status of face and fingerprint enrollment
  Future<List<Map<String, dynamic>>> getAllEmployeesForEnrollment() async {
    try {
      final results = await DatabaseConnection.query('''
        SELECT 
          e.employee_id,
          e.employee_name,
          e.employee_designation as department,
          CASE 
            WHEN f.embedding IS NOT NULL AND f.embedding != '' THEN true 
            ELSE false 
          END as has_face_enrolled,
          CASE 
            WHEN f.fingerprint_template IS NOT NULL AND f.fingerprint_template != '' THEN true 
            ELSE false 
          END as has_fingerprint_enrolled
        FROM employees e
        LEFT JOIN face_embeddings f ON e.employee_id = f.employee_id AND f.is_active = true
        WHERE e.status = 1
        ORDER BY e.employee_name ASC
      ''');

      return results;
    } catch (e, stackTrace) {
      _logger.error(
        'Error getting employees for enrollment: $e',
        e,
        stackTrace,
      );
      rethrow;
    }
  }
}
