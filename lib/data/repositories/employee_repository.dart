import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../../domain/models/employee.dart';
import '../database/connection.dart';
import '../../core/exceptions/app_exception.dart';
import 'package:postgres/postgres.dart';
import '../../core/utils/logger.dart';

/// Employee repository for database operations
class EmployeeRepository {
  final AppLogger _logger = AppLogger('EmployeeRepository');

  /// Get all employees with pagination and filters
  Future<Map<String, dynamic>> getAll({
    int page = 1,
    int limit = 50,
    bool? status,
    String? role,
    String? designation,
    String? search,
    String? sortBy,
    bool ascending = true,
  }) async {
    try {
      final offset = (page - 1) * limit;
      var whereConditions = <String>[];
      final params = <String, dynamic>{};
      var paramIndex = 1;

      // Status filter
      if (status != null) {
        whereConditions.add('status = @status$paramIndex');
        params['status$paramIndex'] = status ? 1 : 0;
        paramIndex++;
      }

      // Role filter
      if (role != null && role.isNotEmpty) {
        whereConditions.add(
          'LOWER(employee_role) LIKE LOWER(@role$paramIndex)',
        );
        params['role$paramIndex'] = '%$role%';
        paramIndex++;
      }

      // Designation filter
      if (designation != null && designation.isNotEmpty) {
        whereConditions.add(
          'LOWER(employee_designation) LIKE LOWER(@designation$paramIndex)',
        );
        params['designation$paramIndex'] = '%$designation%';
        paramIndex++;
      }

      // Search filter
      if (search != null && search.isNotEmpty) {
        whereConditions.add(
          '(LOWER(employee_name) LIKE LOWER(@search$paramIndex) OR LOWER(employee_id) LIKE LOWER(@search$paramIndex))',
        );
        params['search$paramIndex'] = '%$search%';
        paramIndex++;
      }

      final whereClause = whereConditions.isNotEmpty
          ? 'WHERE ${whereConditions.join(' AND ')}'
          : '';

      // Sort by
      String sortColumn = 'employee_id';
      if (sortBy != null && sortBy.isNotEmpty) {
        switch (sortBy.toLowerCase()) {
          case 'id':
          case 'employee_id':
            sortColumn = 'employee_id';
            break;
          case 'name':
          case 'employee_name':
            sortColumn = 'employee_name';
            break;
          case 'designation':
          case 'employee_designation':
            sortColumn = 'employee_designation';
            break;
          case 'role':
          case 'employee_role':
            sortColumn = 'employee_role';
            break;
          default:
            // For other fields, if they start with employee_, use them, else assume they are direct columns
            sortColumn = sortBy;
        }
      }

      final orderBy = 'ORDER BY $sortColumn ${ascending ? 'ASC' : 'DESC'}';

      // Count query
      final countSql = 'SELECT COUNT(*) as total FROM employees $whereClause';
      final countResult = await DatabaseConnection.queryOne(
        countSql,
        values: params,
      );
      final total = (countResult?['total'] as num?)?.toInt() ?? 0;

      // Data query (PostgreSQL uses LIMIT/OFFSET)
      final sql =
          '''
        SELECT * FROM employees 
        $whereClause 
        $orderBy 
        LIMIT @limit OFFSET @offset
      ''';
      params['limit'] = limit;
      params['offset'] = offset;

      final results = await DatabaseConnection.query(sql, values: params);
      final employees = results.map((row) => Employee.fromMap(row)).toList();

      return {
        'data': employees,
        'total': total,
        'page': page,
        'limit': limit,
        'totalPages': (total / limit).ceil(),
      };
    } catch (e, stackTrace) {
      _logger.error('Error getting all employees: $e', e, stackTrace);
      rethrow;
    }
  }

  Future<Employee?> getById(String employeeId) async {
    try {
      final sql = 'SELECT * FROM employees WHERE employee_id = @id';
      final result = await DatabaseConnection.queryOne(
        sql,
        values: {'id': employeeId},
      );

      return result != null ? Employee.fromMap(result) : null;
    } catch (e, stackTrace) {
      _logger.error('Error getting employee by ID: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Get employee by email and organization (Scoped login)
  Future<Employee?> getByEmailAndOrg(String email, String orgId) async {
    try {
      final sql = 'SELECT * FROM employees WHERE (employee_personal_email = @email OR employee_company_email = @email) AND organization_id = @orgId::uuid';
      final result = await DatabaseConnection.queryOne(
        sql,
        values: {'email': email, 'orgId': orgId},
      );
      return result != null ? Employee.fromMap(result) : null;
    } catch (e, stackTrace) {
      _logger.error('Error getting employee by email and org: $e', e, stackTrace);
      return null;
    }
  }

  /// Check if employee exists by ID
  Future<bool> existsById(String employeeId) async {
    try {
      final sql =
          'SELECT COUNT(*) as count FROM employees WHERE employee_id = @id';
      final result = await DatabaseConnection.queryOne(
        sql,
        values: {'id': employeeId},
      );
      final count = result?['count'];
      if (count is num) {
        return count.toInt() > 0;
      }
      return false;
    } catch (e) {
      _logger.error('Error checking employee existence: $e');
      rethrow;
    }
  }

  /// Check if employee exists by phone
  Future<bool> existsByPhone(String phoneNumber) async {
    try {
      final sql =
          'SELECT COUNT(*) as count FROM employees WHERE employee_phone_num = @phone';
      final result = await DatabaseConnection.queryOne(
        sql,
        values: {'phone': phoneNumber},
      );
      final count = result?['count'];
      if (count is num) {
        return count.toInt() > 0;
      }
      return false;
    } catch (e) {
      _logger.error('Error checking phone existence: $e');
      rethrow;
    }
  }

  /// Create employee
  Future<Employee> create(Employee employee) async {
    try {
      final data = employee.toInsertMap();

      // Calculate age from DOB if present
      if (data['employee_dob'] != null &&
          data['employee_dob'].toString().isNotEmpty) {
        final age = _calculateAge(data['employee_dob'].toString());
        if (age != null) {
          data['employee_age'] = age;
        }
      }

      // Ensure required NOT NULL fields have values
      // employee_role is NOT NULL - ensure it's not empty
      if (data['employee_role'] == null ||
          data['employee_role'].toString().isEmpty) {
        data['employee_role'] = 'Employee'; // Default role
      }

      // employee_age is NOT NULL - ensure it has a value
      if (data['employee_age'] == null) {
        // Try to calculate from DOB if available
        if (data['employee_dob'] != null &&
            data['employee_dob'].toString().isNotEmpty) {
          final age = _calculateAge(data['employee_dob'].toString());
          data['employee_age'] = age ?? 0; // Default to 0 if calculation fails
        } else {
          data['employee_age'] = 0; // Default to 0 if DOB is not available
        }
      }

      // employee_dob is NOT NULL - already validated in service
      // employee_age is NOT NULL - already calculated above
      // employee_doj is NOT NULL - already validated in service

      // Remove null values and fields that should use database defaults
      // employee_uuid has DEFAULT gen_random_uuid(), so we can omit it if null
      // This allows the database to generate the UUID automatically
      data.removeWhere((key, value) => value == null);

      // Ensure status is set (defaults to 1 in schema, but set explicitly)
      if (!data.containsKey('status')) {
        data['status'] = 1;
      }

      final columns = data.keys.join(', ');
      final placeholders = data.keys.map((k) => '@$k').join(', ');

      final sql =
          '''
        INSERT INTO employees ($columns)
        VALUES ($placeholders)
        RETURNING *
      ''';

      final result = await DatabaseConnection.queryOne(sql, values: data);
      if (result == null) {
        throw DatabaseException(message: 'Failed to create employee');
      }

      return Employee.fromMap(result);
    } catch (e, stackTrace) {
      _logger.error('Error creating employee: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Update employee
  Future<Employee> update(
    String employeeId,
    Map<String, dynamic> updates,
  ) async {
    try {
      if (updates.isEmpty) {
        throw ValidationException({
          'updates': ['No fields to update'],
        });
      }

      // Define valid fields that exist in the database
      final validFields = {
        'employee_id',
        'employee_name',
        'employee_personal_email',
        'employee_phone_num',
        'employee_gender',
        'employee_doj',
        'employee_role',
        'employee_dob',
        'employee_age',
        'employee_company_email',
        'employee_address',
        'employee_designation',
        'employee_qualification',
        'employee_specialization',
        'employee_blood_group',
        'employee_emergency_contact_number',
        'employee_actual_salary',
        'employee_total_leave_days_in_year',
        'employee_pending_leave_count',
        'employee_img',
        'status',
      };

      // Filter out invalid fields
      final filteredUpdates = <String, dynamic>{};
      updates.forEach((key, value) {
        if (validFields.contains(key)) {
          filteredUpdates[key] = value;
        } else {
          _logger.warning('Ignoring invalid field in update: $key');
        }
      });

      if (filteredUpdates.isEmpty) {
        throw ValidationException({
          'updates': ['No valid fields to update'],
        });
      }

      // Calculate age if DOB is updated
      if (filteredUpdates.containsKey('employee_dob')) {
        final age = _calculateAge(filteredUpdates['employee_dob'].toString());
        if (age != null) {
          filteredUpdates['employee_age'] = age;
        }
      }


      // Sync relevant fields to auth.users
      final authFieldsToUpdate = <String, dynamic>{};
      if (filteredUpdates.containsKey('employee_personal_email')) {
        authFieldsToUpdate['email'] = filteredUpdates['employee_personal_email'];
      } else if (filteredUpdates.containsKey('employee_company_email')) {
        authFieldsToUpdate['email'] = filteredUpdates['employee_company_email'];
      }

      if (filteredUpdates.containsKey('employee_id')) {
        authFieldsToUpdate['employee_id'] = filteredUpdates['employee_id'];
        authFieldsToUpdate['reference_id'] = filteredUpdates['employee_id'];
      }
      
      if (filteredUpdates.containsKey('employee_role')) {
        authFieldsToUpdate['role'] = filteredUpdates['employee_role']
                .toString()
                .toLowerCase()
                .contains('admin')
            ? 'admin'
            : 'employee';
      }

      // Use a transaction for both employees and auth.users updates
      final updatedEmployee = await DatabaseConnection.transaction((connection) async {
        // 1. Update employees table
        final setClause = filteredUpdates.keys.map((k) => '$k = @$k').join(', ');
        final sql = '''
          UPDATE employees 
          SET $setClause, updated_at = CURRENT_TIMESTAMP
          WHERE employee_id = @id
          RETURNING *
        ''';

        final result = await connection.execute(
          Sql.named(sql),
          parameters: {...filteredUpdates, 'id': employeeId},
        );

        if (result.isEmpty) {
          throw NotFoundException(resource: 'Employee', id: employeeId);
        }

        // 2. Sync with auth.users if needed
        if (authFieldsToUpdate.isNotEmpty) {
          try {
            final authSetClauses = authFieldsToUpdate.keys
                .map((k) => '$k = @$k')
                .toList();
            final authValues = <String, dynamic>{'old_ref_id': employeeId};
            authValues.addAll(authFieldsToUpdate);

            final authSql =
                'UPDATE auth.users SET ${authSetClauses.join(', ')} WHERE reference_id = @old_ref_id';
            
            await connection.execute(
              Sql.named(authSql),
              parameters: authValues,
            );
            _logger.info('Synced update to auth.users for $employeeId');
          } catch (e) {
            _logger.warning('Failed to sync employee update to auth.users table: $e');
            // Inside a transaction, we might want to fail the whole thing 
            // if it's an ID change, but for other fields we could be lenient.
            // If it's an employee_id change, we should definitely fail if sync fails.
            if (filteredUpdates.containsKey('employee_id')) {
              rethrow;
            }
          }
        }

        // Convert result to map
        final row = result.first;
        final Map<String, dynamic> rowMap = {};
        for (final column in result.schema.columns) {
          rowMap[column.columnName!] = row.toColumnMap()[column.columnName];
        }
        return rowMap;
      });

      return Employee.fromMap(updatedEmployee);
    } catch (e, stackTrace) {
      _logger.error('Error updating employee: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Delete employee
  Future<bool> delete(String employeeId) async {
    try {
      final sql = 'DELETE FROM employees WHERE employee_id = @id';
      final affectedRows = await DatabaseConnection.execute(
        sql,
        values: {'id': employeeId},
      );
      return affectedRows > 0;
    } catch (e, stackTrace) {
      _logger.error('Error deleting employee: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Get employees by role
  Future<List<Employee>> getByRole(String role) async {
    try {
      final sql =
          'SELECT * FROM employees WHERE employee_role = @role ORDER BY employee_name';
      final results = await DatabaseConnection.query(
        sql,
        values: {'role': role},
      );
      return results.map((row) => Employee.fromMap(row)).toList();
    } catch (e, stackTrace) {
      _logger.error('Error getting employees by role: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Get employees with birthdays in month
  Future<List<Employee>> getBirthdaysInMonth(int month) async {
    try {
      // DOB format is DD-MM-YYYY, so we extract month from the string
      final sql = '''
        SELECT * FROM employees 
        WHERE SUBSTRING(employee_dob, CHARINDEX('-', employee_dob) + 1, CHARINDEX('-', employee_dob, CHARINDEX('-', employee_dob) + 1) - CHARINDEX('-', employee_dob) - 1) = @month
        AND status = 1
        ORDER BY CAST(SUBSTRING(employee_dob, 1, CHARINDEX('-', employee_dob) - 1) AS INT)
      ''';
      final results = await DatabaseConnection.query(
        sql,
        values: {'month': month.toString().padLeft(2, '0')},
      );
      return results.map((row) => Employee.fromMap(row)).toList();
    } catch (e, stackTrace) {
      _logger.error('Error getting birthdays: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Get employees with anniversaries today
  Future<List<Employee>> getAnniversariesToday() async {
    try {
      final today = DateTime.now();
      final day = today.day.toString().padLeft(2, '0');
      final month = today.month.toString().padLeft(2, '0');

      // DOJ format is DD-MM-YYYY
      final sql = '''
        SELECT * FROM employees 
        WHERE SUBSTRING(employee_doj, 1, CHARINDEX('-', employee_doj) - 1) = @day
        AND SUBSTRING(employee_doj, CHARINDEX('-', employee_doj) + 1, CHARINDEX('-', employee_doj, CHARINDEX('-', employee_doj) + 1) - CHARINDEX('-', employee_doj) - 1) = @month
        AND YEAR(GETDATE()) - CAST(SUBSTRING(employee_doj, CHARINDEX('-', employee_doj, CHARINDEX('-', employee_doj) + 1) + 1, LEN(employee_doj)) AS INT) >= 1
        AND status = 1
        ORDER BY CAST(SUBSTRING(employee_doj, CHARINDEX('-', employee_doj, CHARINDEX('-', employee_doj) + 1) + 1, LEN(employee_doj)) AS INT)
      ''';
      final results = await DatabaseConnection.query(
        sql,
        values: {'day': day, 'month': month},
      );
      return results.map((row) => Employee.fromMap(row)).toList();
    } catch (e, stackTrace) {
      _logger.error('Error getting anniversaries: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Get all employees (for overview)
  Future<List<Employee>> getAllActive() async {
    try {
      final sql =
          'SELECT * FROM employees WHERE status = 1 ORDER BY employee_name';
      final results = await DatabaseConnection.query(sql);
      return results.map((row) => Employee.fromMap(row)).toList();
    } catch (e, stackTrace) {
      _logger.error('Error getting all active employees: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Count active employees by organization
  Future<int> countActiveByOrg(String orgId) async {
    try {
      final sql = 'SELECT COUNT(*) as count FROM employees WHERE status = 1 AND organization_id = @orgId::uuid';
      final result = await DatabaseConnection.queryOne(sql, values: {'orgId': orgId});
      final count = result?['count'];
      if (count is num) return count.toInt();
      return 0;
    } catch (e) {
      _logger.error('Error counting active employees by org: $e');
      return 0;
    }
  }

  /// Get present employees (who actually punched in)
  Future<List<Map<String, dynamic>>> getPresentEmployees(String date) async {
    try {
      // Get all active employees
      final allEmployees = await getAllActive();
      final allEmployeeIds = allEmployees.map((e) => e.employeeId).toSet();

      // Get IDs of employees who actually punched in today
      final attendanceListSql = '''
        SELECT DISTINCT employee_id 
        FROM employee_attendance 
        WHERE work_date = @date
      ''';
      final attendanceListResults = await DatabaseConnection.query(
        attendanceListSql,
        values: {'date': date},
      );
      final presentIds = attendanceListResults
          .map((r) => r['employee_id']?.toString())
          .whereType<String>()
          .toSet()
          .intersection(allEmployeeIds); // Must be active

      // Get attendance data for present employees
      if (presentIds.isEmpty) {
        return [];
      }

      final employeeIdsList = presentIds.toList();
      final placeholders = List.generate(
        employeeIdsList.length,
        (i) => '@id$i',
      ).join(', ');
      final attendanceSql =
          '''
        SELECT * FROM employee_attendance 
        WHERE work_date = @date 
        AND employee_id IN ($placeholders)
      ''';
      final attendanceValues = <String, dynamic>{'date': date};
      for (var i = 0; i < employeeIdsList.length; i++) {
        attendanceValues['id$i'] = employeeIdsList[i];
      }
      final attendanceResults = await DatabaseConnection.query(
        attendanceSql,
        values: attendanceValues,
      );

      // Map attendance by employee ID
      final attendanceMap = <String, Map<String, dynamic>>{};
      for (var att in attendanceResults) {
        final empId = att['employee_id']?.toString();
        if (empId != null) {
          attendanceMap[empId] = att;
        }
      }

      // Build result with employee and attendance data
      final presentEmployees = <Map<String, dynamic>>[];
      for (var emp in allEmployees) {
        if (presentIds.contains(emp.employeeId)) {
          final attendance = attendanceMap[emp.employeeId];
          presentEmployees.add({
            'employee': emp.toJson(),
            'clockInTime': attendance?['clock_on_time']?.toString(),
            'clockOutTime': attendance?['clock_off_time']?.toString(),
            'workedHours': attendance?['worked_hrs'] != null
                ? (attendance!['worked_hrs'] as num).toDouble()
                : null,
          });
        }
      }

      return presentEmployees;
    } catch (e, stackTrace) {
      _logger.error('Error getting present employees: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Get absent employees (not present, not on WFH, not on permission, not on leave)
  Future<List<Map<String, dynamic>>> getAbsentEmployees(String date) async {
    try {
      final allEmployees = await getAllActive();
      final allEmployeeIds = allEmployees.map((e) => e.employeeId).toSet();

      // Get present IDs
      final presentSql = '''
        SELECT DISTINCT employee_id FROM employee_attendance WHERE work_date = @date
      ''';
      final presentResults = await DatabaseConnection.query(
        presentSql,
        values: {'date': date},
      );
      final presentIds = presentResults
          .map((r) => r['employee_id']?.toString())
          .whereType<String>()
          .toSet();

      // Get leave IDs
      final leaveSql = '''
        SELECT DISTINCT employee_id FROM leave_zone 
        WHERE leave_from_date <= @date AND leave_to_date >= @date AND leave_status = 1
      ''';
      final leaveResults = await DatabaseConnection.query(
        leaveSql,
        values: {'date': date},
      );
      final leaveIds = leaveResults
          .map((r) => r['employee_id']?.toString())
          .whereType<String>()
          .toSet();

      // Get WFH IDs
      final wfhSql = '''
        SELECT DISTINCT employee_id FROM work_from_home_requests 
        WHERE start_date <= @date AND end_date >= @date AND wfh_status = 1
      ''';
      final wfhResults = await DatabaseConnection.query(
        wfhSql,
        values: {'date': date},
      );
      final wfhIds = wfhResults
          .map((r) => r['employee_id']?.toString())
          .whereType<String>()
          .toSet();

      // Get Permission IDs
      final permSql = '''
        SELECT DISTINCT employee_id FROM permissions 
        WHERE permission_date = @date AND permission_status = 1
      ''';
      final permResults = await DatabaseConnection.query(
        permSql,
        values: {'date': date},
      );
      final permIds = permResults
          .map((r) => r['employee_id']?.toString())
          .whereType<String>()
          .toSet();

      // Absent = All Active - (Present + Leave + WFH + Permission)
      final allAway = presentIds.union(leaveIds).union(wfhIds).union(permIds);
      final absentIds = allEmployeeIds.difference(allAway);

      final absentEmployees = <Map<String, dynamic>>[];
      for (var emp in allEmployees) {
        if (absentIds.contains(emp.employeeId)) {
          absentEmployees.add({'employee': emp.toJson()});
        }
      }

      return absentEmployees;
    } catch (e, stackTrace) {
      _logger.error('Error getting absent employees: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Get WFH employees
  Future<List<Map<String, dynamic>>> getWFHEmployees(String date) async {
    try {
      final sql = '''
        SELECT w.*, e.*
        FROM work_from_home_requests w
        INNER JOIN employees e ON w.employee_id = e.employee_id
        WHERE w.start_date <= @date 
        AND w.end_date >= @date 
        AND w.wfh_status = 1
        AND e.status = 1
        ORDER BY e.employee_name
      ''';
      final results = await DatabaseConnection.query(
        sql,
        values: {'date': date},
      );

      return results.map((row) {
        final employee = Employee.fromMap(row);
        return {
          'employee': employee.toJson(),
          'wfhRequest': {
            'startDate': row['start_date']?.toString(),
            'endDate': row['end_date']?.toString(),
            'approvedBy': row['approved_by']?.toString(),
            'approvedAt': row['approved_at']?.toString(),
          },
        };
      }).toList();
    } catch (e, stackTrace) {
      _logger.error('Error getting WFH employees: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Get employees on permission
  Future<List<Map<String, dynamic>>> getPermissionEmployees(String date) async {
    try {
      final sql = '''
        SELECT p.*, e.*
        FROM permissions p
        INNER JOIN employees e ON p.employee_id = e.employee_id
        WHERE p.permission_date = @date 
        AND p.permission_status = 1
        AND e.status = 1
        ORDER BY e.employee_name
      ''';
      final results = await DatabaseConnection.query(
        sql,
        values: {'date': date},
      );

      return results.map((row) {
        final employee = Employee.fromMap(row);
        return {
          'employee': employee.toJson(),
          'permission': {
            'permissionDate': row['permission_date']?.toString(),
            'permissionTime': row['permission_time']?.toString(),
            'permissionReason': row['permission_reason']?.toString(),
            'approvedBy': row['approved_by']?.toString(),
          },
        };
      }).toList();
    } catch (e, stackTrace) {
      _logger.error('Error getting permission employees: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Get late employees (clocked in after 9:15 AM)
  Future<List<Map<String, dynamic>>> getLateEmployees(String date) async {
    try {
      // Get attendance records for the date
      final attendanceSql = '''
        SELECT a.*, e.*
        FROM employee_attendance a
        INNER JOIN employees e ON a.employee_id = e.employee_id
        WHERE a.work_date = @date
        AND a.clock_on_time IS NOT NULL
        AND e.status = 1
        ORDER BY a.clock_on_time
      ''';
      final attendanceResults = await DatabaseConnection.query(
        attendanceSql,
        values: {'date': date},
      );

      final lateEmployees = <Map<String, dynamic>>[];

      for (var att in attendanceResults) {
        final clockOnTime = att['clock_on_time']?.toString();
        if (clockOnTime == null) continue;

        // Parse clock in time (format: HH:MM:SS or HH:MM)
        final timeParts = clockOnTime.split(':');
        if (timeParts.length < 2) continue;

        final hour = int.tryParse(timeParts[0]) ?? 0;
        final minute = int.tryParse(timeParts[1]) ?? 0;

        // Check if late (after 9:15 AM)
        if (hour > 9 || (hour == 9 && minute > 15)) {
          final employee = Employee.fromMap(att);
          final lateMinutes = (hour - 9) * 60 + (minute - 15);

          lateEmployees.add({
            'employee': employee.toJson(),
            'clockInTime': clockOnTime,
            'lateMinutes': lateMinutes,
          });
        }
      }

      return lateEmployees;
    } catch (e, stackTrace) {
      _logger.error('Error getting late employees: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Get all memberships for an email (Multi-tenancy discovery)
  Future<List<Employee>> listByEmail(String email) async {
    try {
      final sql = 'SELECT * FROM employees WHERE employee_personal_email = @email OR employee_company_email = @email';
      final results = await DatabaseConnection.query(
        sql,
        values: {'email': email},
      );
      return results.map((row) => Employee.fromMap(row)).toList();
    } catch (e, stackTrace) {
      _logger.error('Error listing employees by email: $e', e, stackTrace);
      return [];
    }
  }

  /// Get employee by email
  Future<Employee?> getByEmail(String email) async {
    try {
      final sql =
          'SELECT * FROM employees WHERE employee_personal_email = @email OR employee_company_email = @email';
      final result = await DatabaseConnection.queryOne(
        sql,
        values: {'email': email},
      );

      return result != null ? Employee.fromMap(result) : null;
    } catch (e, stackTrace) {
      _logger.error('Error getting employee by email: $e', e, stackTrace);
      throw AppException(
        code: 'DATABASE_ERROR',
        message: 'Failed to retrieve employee. Please try again.',
        details: {'error': e.toString()},
      );
    }
  }

  /// Get employee by phone
  Future<Employee?> getByPhone(String phone) async {
    try {
      final sql = 'SELECT * FROM employees WHERE employee_phone_num = @phone';
      final result = await DatabaseConnection.queryOne(
        sql,
        values: {'phone': phone},
      );

      return result != null ? Employee.fromMap(result) : null;
    } catch (e, stackTrace) {
      _logger.error('Error getting employee by phone: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Get "No Status Today" employees
  /// Employees who:
  /// 1. Haven't punched in before 10:30 AM
  /// 2. Don't have an approved/pending Leave, Permission, or WFH for the given date
  Future<List<Employee>> getNoStatusEmployees(String date) async {
    try {
      final sql = '''
        SELECT DISTINCT e.*
        FROM employees e
        WHERE e.status = 1
        -- Not punched in at all for today
        AND NOT EXISTS (
            SELECT 1 FROM employee_attendance a 
            WHERE a.employee_id = e.employee_id 
            AND a.work_date = @date 
        )
        -- No Leave (Approved or Pending)
        AND NOT EXISTS (
            SELECT 1 FROM leave_zone l 
            WHERE l.employee_id = e.employee_id 
            AND l.leave_from_date <= @date::DATE 
            AND l.leave_to_date >= @date::DATE 
            AND l.leave_status IN (0, 1)
        )
        -- No Permission (Approved or Pending)
        AND NOT EXISTS (
            SELECT 1 FROM permissions p 
            WHERE p.employee_id = e.employee_id 
            AND p.permission_date = @date::DATE 
            AND p.permission_status IN (0, 1)
        )
        -- No WFH (Approved or Pending)
        AND NOT EXISTS (
            SELECT 1 FROM work_from_home_requests w 
            WHERE w.employee_id = e.employee_id 
            AND w.start_date <= @date::DATE 
            AND w.end_date >= @date::DATE 
            AND w.wfh_status IN (0, 1)
        )
        ORDER BY e.employee_name
      ''';

      final results = await DatabaseConnection.query(
        sql,
        values: {'date': date},
      );

      return results.map((row) => Employee.fromMap(row)).toList();
    } catch (e, stackTrace) {
      _logger.error('Error getting no status employees: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Update employee status (active/inactive)
  Future<void> updateStatus(String employeeId, bool isActive) async {
    try {
      final sql = '''
        UPDATE employees SET 
          status = @status,
          changed_by = @changed_by,
          changed_at = @changed_at
        WHERE employee_id = @employee_id
      ''';

      final values = {
        'employee_id': employeeId,
        'status': isActive ? 1 : 0,
        'changed_by': 'system',
        'changed_at': DateTime.now().toIso8601String(),
      };

      await DatabaseConnection.execute(sql, values: values);

      // Also update auth.users table
      final authSql = '''
        UPDATE auth.users SET 
          is_active = @is_active,
          updated_at = @changed_at,
          updated_by = @changed_by
        WHERE employee_id = @employee_id
      ''';

      final authValues = {
        'employee_id': employeeId,
        'is_active': isActive ? 1 : 0,
        'changed_by': 'system',
        'changed_at': DateTime.now().toIso8601String(),
      };

      await DatabaseConnection.execute(authSql, values: authValues);
    } catch (e, stackTrace) {
      _logger.error('Error updating employee status: $e', e, stackTrace);
      throw AppException(
        code: 'DATABASE_ERROR',
        message: 'Failed to update employee status. Please try again.',
        details: {'error': e.toString()},
      );
    }
  }

  /// Create auth user for employee
  Future<void> createAuthUser({
    required String email,
    required String name,
    required String employeeId,
    String defaultPassword = '123456',
  }) async {
    try {
      // Hash the default password using SHA256 (same as User.hashPassword)
      final passwordBytes = utf8.encode(defaultPassword);
      final passwordHash = sha256.convert(passwordBytes).toString();

      final sql = '''
        INSERT INTO auth.users (employee_id, email, encrypted_password, role, reference_id, is_active, created_at)
        VALUES (@employee_id, @email, @encrypted_password, 'Employee', @reference_id, 1, @created_at)
        ON CONFLICT (email) DO UPDATE SET
          encrypted_password = COALESCE(auth.users.encrypted_password, @encrypted_password),
          role = 'Employee',
          employee_id = @employee_id,
          is_active = 1,
          updated_at = @created_at,
          updated_by = @created_by
      ''';

      await DatabaseConnection.execute(
        sql,
        values: {
          'employee_id': employeeId,
          'email': email,
          'encrypted_password': passwordHash,
          'reference_id': employeeId,
          'created_at': DateTime.now().toIso8601String(),
          'created_by': 'System',
        },
      );

      _logger.info(
        'Auth user created for employee: $employeeId with email: $email',
      );
    } catch (e, stackTrace) {
      _logger.error('Error creating auth user: $e', e, stackTrace);
      // Don't throw - auth user creation is secondary
    }
  }

  /// Hash password using SHA256
  String _hashPassword(String password) {
    final bytes = password.codeUnits;
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Delete auth user
  Future<void> deleteAuthUser(String email) async {
    try {
      final sql = 'DELETE FROM auth.users WHERE email = @email';
      await DatabaseConnection.execute(sql, values: {'email': email});
    } catch (e, stackTrace) {
      _logger.error('Error deleting auth user: $e', e, stackTrace);
      // Don't throw - auth user deletion is secondary
    }
  }

  /// Exit employee (set inactive + exit details)
  Future<Employee> exitEmployee({
    required String employeeId,
    required String exitDate,
    required String exitReason,
    required String exitedBy,
  }) async {
    try {
      final sql = '''
        UPDATE employees SET 
          status = 0,
          employee_doe = @exit_date,
          reason_of_exit = @exit_reason,
          exited_by = @exited_by,
          exited_at = @exited_at,
          changed_by = @changed_by,
          changed_at = @changed_at
        WHERE employee_id = @employee_id
        RETURNING *
      ''';

      final values = {
        'employee_id': employeeId,
        'exit_date': exitDate,
        'exit_reason': exitReason,
        'exited_by': exitedBy,
        'exited_at': DateTime.now().toIso8601String(),
        'changed_by': exitedBy,
        'changed_at': DateTime.now().toIso8601String(),
      };

      final result = await DatabaseConnection.queryOne(sql, values: values);

      if (result == null) {
        throw NotFoundException(resource: 'Employee', id: employeeId);
      }

      // Also update auth.users
      final authSql = '''
        UPDATE auth.users SET 
          is_active = 0,
          updated_at = @changed_at,
          updated_by = @changed_by
        WHERE employee_id = @employee_id
      ''';

      await DatabaseConnection.execute(
        authSql,
        values: {
          'employee_id': employeeId,
          'changed_by': exitedBy,
          'changed_at': DateTime.now().toIso8601String(),
        },
      );

      return Employee.fromMap(result);
    } catch (e, stackTrace) {
      _logger.error('Error exiting employee: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Calculate age from DOB string (DD-MM-YYYY)
  int? _calculateAge(String dobStr) {
    try {
      final parts = dobStr.split('-');
      if (parts.length != 3) return null;

      final dob = DateTime(
        int.parse(parts[2]),
        int.parse(parts[1]),
        int.parse(parts[0]),
      );

      final now = DateTime.now();
      int age = now.year - dob.year;

      if (now.month < dob.month ||
          (now.month == dob.month && now.day < dob.day)) {
        age--;
      }

      return age;
    } catch (e) {
      _logger.warning('Error calculating age from $dobStr: $e');
      return null;
    }
  }
}
