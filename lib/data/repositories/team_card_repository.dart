import '../../domain/models/team_card.dart';
import '../database/connection.dart';
import '../../core/exceptions/app_exception.dart';
import '../../core/utils/logger.dart';

/// TeamCard repository for database operations
/// Handles all Team Card CRUD operations for non-project work
class TeamCardRepository {
  final AppLogger _logger = AppLogger('TeamCardRepository');

  // ==========================================
  // ADMIN - TEAM CARD OPERATIONS
  // ==========================================

  /// Create new team card (Admin)
  /// POST /admin/team-cards
  Future<TeamCard> createNewTeamCard(
    Map<String, dynamic> data,
    String createdBy,
  ) async {
    try {
      // Validate required fields
      _validateTeamCardData(data);

      final insertData = <String, dynamic>{
        'card_name': data['card_name'],
        'card_type': data['card_type'] ?? 'Learning Card',
        'card_description': data['card_description'],
        'team_card_status': data['team_card_status'] ?? 1,
        'team_type': data['team_type'],
        'created_by': createdBy,
        'updated_by': createdBy,
      };

      final columns = insertData.keys.join(', ');
      final placeholders = insertData.keys.map((k) => '@$k').join(', ');

      final sql =
          '''
        INSERT INTO team_cards ($columns)
        VALUES ($placeholders)
        RETURNING *
      ''';

      final result = await DatabaseConnection.queryOne(sql, values: insertData);
      if (result == null) {
        throw DatabaseException(message: 'Failed to create team card');
      }

      return TeamCard.fromMap(result);
    } catch (e, stackTrace) {
      _logger.error('Error creating team card: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Update team card (Admin)
  /// PUT /admin/team-cards/{teamCardId}
  Future<TeamCard> updateTeamCard(
    String teamCardId,
    Map<String, dynamic> updates,
    String updatedBy,
  ) async {
    try {
      final existing = await getTeamCardById(teamCardId);
      if (existing == null) {
        throw NotFoundException(resource: 'TeamCard', id: teamCardId);
      }

      if (updates.isEmpty) {
        throw ValidationException({
          'updates': ['No fields to update'],
        });
      }

      final updateData = <String, dynamic>{};

      final allowedFields = [
        'card_name',
        'card_type',
        'card_description',
        'team_type',
      ];
      for (final field in allowedFields) {
        if (updates.containsKey(field)) {
          updateData[field] = updates[field];
        }
      }

      updateData['updated_by'] = updatedBy;

      final setClause = updateData.keys.map((k) => '$k = @$k').join(', ');
      final sql =
          '''
        UPDATE team_cards 
        SET $setClause
        WHERE team_card_id = @id
        RETURNING *
      ''';

      updateData['id'] = teamCardId;
      final result = await DatabaseConnection.queryOne(sql, values: updateData);

      if (result == null) {
        throw NotFoundException(resource: 'TeamCard', id: teamCardId);
      }

      return TeamCard.fromMap(result);
    } catch (e, stackTrace) {
      _logger.error('Error updating team card: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Get all team cards (Admin)
  /// GET /admin/team-cards
  Future<Map<String, dynamic>> getAllTeamCards({
    int page = 1,
    int limit = 50,
    String? cardType,
    String? teamType,
    int? status,
    String? search,
  }) async {
    try {
      final offset = (page - 1) * limit;
      var whereConditions = <String>[];
      final params = <String, dynamic>{};

      if (cardType != null && cardType.isNotEmpty) {
        whereConditions.add('card_type = @cardType');
        params['cardType'] = cardType;
      }

      if (teamType != null && teamType.isNotEmpty) {
        whereConditions.add('team_type = @teamType');
        params['teamType'] = teamType;
      }

      if (status != null) {
        whereConditions.add('team_card_status = @status');
        params['status'] = status;
      }

      if (search != null && search.isNotEmpty) {
        whereConditions.add(
          '(LOWER(card_name) LIKE LOWER(@search) OR LOWER(card_description) LIKE LOWER(@search))',
        );
        params['search'] = '%$search%';
      }

      final whereClause = whereConditions.isNotEmpty
          ? 'WHERE ${whereConditions.join(' AND ')}'
          : '';

      // Count query
      final countSql = 'SELECT COUNT(*) as total FROM team_cards $whereClause';
      final countResult = await DatabaseConnection.queryOne(
        countSql,
        values: params,
      );
      final total = (countResult?['total'] as num?)?.toInt() ?? 0;

      // Data query
      final sql =
          '''
        SELECT * FROM team_cards 
        $whereClause 
        ORDER BY created_at DESC 
        LIMIT @limit OFFSET @offset
      ''';
      params['limit'] = limit;
      params['offset'] = offset;

      final results = await DatabaseConnection.query(sql, values: params);
      final teamCards = results
          .map((row) => TeamCard.fromMap(row).toJson())
          .toList();

      return {
        'data': teamCards,
        'total': total,
        'page': page,
        'limit': limit,
        'totalPages': total > 0 ? (total / limit).ceil() : 0,
      };
    } catch (e, stackTrace) {
      _logger.error('Error getting all team cards: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Get team card by ID
  Future<TeamCard?> getTeamCardById(String teamCardId) async {
    try {
      final sql = 'SELECT * FROM team_cards WHERE team_card_id = @id';
      final result = await DatabaseConnection.queryOne(
        sql,
        values: {'id': teamCardId},
      );
      return result != null ? TeamCard.fromMap(result) : null;
    } catch (e, stackTrace) {
      _logger.error('Error getting team card by ID: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Activate/Deactivate team card (Admin)
  /// PATCH /admin/team-cards/{teamCardId}/status
  Future<TeamCard> updateTeamCardStatus(
    String teamCardId,
    int status,
    String updatedBy,
  ) async {
    try {
      final sql = '''
        UPDATE team_cards 
        SET team_card_status = @status, updated_by = @updatedBy
        WHERE team_card_id = @id
        RETURNING *
      ''';

      final result = await DatabaseConnection.queryOne(
        sql,
        values: {'id': teamCardId, 'status': status, 'updatedBy': updatedBy},
      );

      if (result == null) {
        throw NotFoundException(resource: 'TeamCard', id: teamCardId);
      }

      return TeamCard.fromMap(result);
    } catch (e, stackTrace) {
      _logger.error('Error updating team card status: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Delete team card (Admin)
  /// DELETE /admin/team-cards/{teamCardId}
  Future<bool> deleteTeamCard(String teamCardId) async {
    try {
      final sql = 'DELETE FROM team_cards WHERE team_card_id = @id';
      final affectedRows = await DatabaseConnection.execute(
        sql,
        values: {'id': teamCardId},
      );
      return affectedRows > 0;
    } catch (e, stackTrace) {
      _logger.error('Error deleting team card: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Get team card usage report (Admin)
  /// GET /admin/team-cards/{teamCardId}/usage
  Future<Map<String, dynamic>> getTeamCardUsageReport(
    String teamCardId, {
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    try {
      var whereConditions = <String>['u.team_card_id = @teamCardId'];
      final params = <String, dynamic>{'teamCardId': teamCardId};

      if (fromDate != null) {
        whereConditions.add('u.clock_in >= @fromDate');
        params['fromDate'] = fromDate.toIso8601String();
      }
      if (toDate != null) {
        whereConditions.add('u.clock_in <= @toDate');
        params['toDate'] = toDate.toIso8601String();
      }

      final whereClause = 'WHERE ${whereConditions.join(' AND ')}';

      final sql =
          '''
        SELECT 
          u.*,
          e.employee_name,
          e.employee_role,
          e.employee_img
        FROM team_card_usage u
        LEFT JOIN employees e ON u.employee_id = e.employee_id
        $whereClause
        ORDER BY u.clock_in DESC
      ''';

      final results = await DatabaseConnection.query(sql, values: params);

      // Calculate totals
      double totalHours = 0;
      for (final row in results) {
        totalHours += (row['total_hours'] as num?)?.toDouble() ?? 0.0;
      }

      final usage = results.map((row) {
        return {
          'usage_id': row['usage_id'],
          'employee_id': row['employee_id'],
          'employee_name': row['employee_name'],
          'employee_role': row['employee_role'],
          'employee_img': row['employee_img'],
          'clock_in': row['clock_in']?.toString(),
          'clock_out': row['clock_out']?.toString(),
          'total_hours': row['total_hours'],
          'notes': row['notes'],
        };
      }).toList();

      return {
        'team_card_id': teamCardId,
        'usage': usage,
        'total_usage_count': results.length,
        'total_hours': totalHours,
      };
    } catch (e, stackTrace) {
      _logger.error('Error getting team card usage report: $e', e, stackTrace);
      rethrow;
    }
  }

  // ==========================================
  // EMPLOYEE - TEAM CARD OPERATIONS
  // ==========================================

  /// Get available (active) team cards for employee
  /// GET /employee/team-cards
  Future<List<TeamCard>> getAvailableTeamCards() async {
    try {
      final sql = '''
        SELECT * FROM team_cards 
        WHERE team_card_status = 1
        ORDER BY card_name ASC
      ''';
      final results = await DatabaseConnection.query(sql, values: {});
      return results.map((row) => TeamCard.fromMap(row)).toList();
    } catch (e, stackTrace) {
      _logger.error('Error getting available team cards: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Clock-in to team card (Employee)
  /// POST /employee/team-cards/{teamCardId}/clock
  Future<TeamCardUsage> clockInToTeamCard(
    String teamCardId,
    String employeeId,
    String? notes,
  ) async {
    try {
      // Check if team card exists and is active
      final teamCard = await getTeamCardById(teamCardId);
      if (teamCard == null) {
        throw NotFoundException(resource: 'TeamCard', id: teamCardId);
      }
      if (teamCard.teamCardStatus != 1) {
        throw ValidationException({
          'team_card': ['Team card is not active'],
        });
      }

      // Check for existing active clock-in
      final activeCheckSql = '''
        SELECT * FROM team_card_usage 
        WHERE team_card_id = @teamCardId 
        AND employee_id = @employeeId 
        AND clock_out IS NULL
      ''';
      final activeUsage = await DatabaseConnection.queryOne(
        activeCheckSql,
        values: {'teamCardId': teamCardId, 'employeeId': employeeId},
      );

      if (activeUsage != null) {
        throw ValidationException({
          'clock_in': ['Already clocked in to this team card'],
        });
      }

      final sql = '''
        INSERT INTO team_card_usage (team_card_id, employee_id, clock_in, notes)
        VALUES (@teamCardId, @employeeId, @clockIn, @notes)
        RETURNING *
      ''';

      final result = await DatabaseConnection.queryOne(
        sql,
        values: {
          'teamCardId': teamCardId,
          'employeeId': employeeId,
          'clockIn': DateTime.now().toIso8601String(),
          'notes': notes,
        },
      );

      if (result == null) {
        throw DatabaseException(message: 'Failed to clock in');
      }

      return TeamCardUsage.fromMap(result);
    } catch (e, stackTrace) {
      _logger.error('Error clocking in to team card: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Clock-out from team card (Employee)
  /// POST /employee/team-cards/{teamCardId}/clock (with clock_out action)
  Future<TeamCardUsage> clockOutFromTeamCard(
    String teamCardId,
    String employeeId,
  ) async {
    try {
      // Find active clock-in record
      final sql = '''
        SELECT * FROM team_card_usage 
        WHERE team_card_id = @teamCardId 
        AND employee_id = @employeeId 
        AND clock_out IS NULL
      ''';
      final activeUsage = await DatabaseConnection.queryOne(
        sql,
        values: {'teamCardId': teamCardId, 'employeeId': employeeId},
      );

      if (activeUsage == null) {
        throw ValidationException({
          'clock_out': ['No active clock-in found for this team card'],
        });
      }

      final clockIn = DateTime.parse(activeUsage['clock_in'].toString());
      final clockOut = DateTime.now();
      final totalHours = clockOut.difference(clockIn).inMinutes / 60.0;

      final updateSql = '''
        UPDATE team_card_usage 
        SET clock_out = @clockOut, total_hours = @totalHours
        WHERE usage_id = @usageId
        RETURNING *
      ''';

      final result = await DatabaseConnection.queryOne(
        updateSql,
        values: {
          'usageId': activeUsage['usage_id'],
          'clockOut': clockOut.toIso8601String(),
          'totalHours': totalHours,
        },
      );

      if (result == null) {
        throw DatabaseException(message: 'Failed to clock out');
      }

      return TeamCardUsage.fromMap(result);
    } catch (e, stackTrace) {
      _logger.error('Error clocking out from team card: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Get employee's team card usage history
  /// GET /employee/team-cards/usage
  Future<List<TeamCardUsage>> getEmployeeTeamCardUsage(
    String employeeId, {
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    try {
      var whereConditions = <String>['u.employee_id = @employeeId'];
      final params = <String, dynamic>{'employeeId': employeeId};

      if (fromDate != null) {
        whereConditions.add('u.clock_in >= @fromDate');
        params['fromDate'] = fromDate.toIso8601String();
      }
      if (toDate != null) {
        whereConditions.add('u.clock_in <= @toDate');
        params['toDate'] = toDate.toIso8601String();
      }

      final whereClause = 'WHERE ${whereConditions.join(' AND ')}';

      final sql =
          '''
        SELECT 
          u.*,
          t.card_name,
          t.card_type,
          t.card_description
        FROM team_card_usage u
        LEFT JOIN team_cards t ON u.team_card_id = t.team_card_id
        $whereClause
        ORDER BY u.clock_in DESC
      ''';

      final results = await DatabaseConnection.query(sql, values: params);

      return results.map((row) {
        final usage = TeamCardUsage.fromMap(row);
        // Add team card details manually since fromMap doesn't handle join
        return TeamCardUsage(
          usageId: usage.usageId,
          teamCardId: usage.teamCardId,
          employeeId: usage.employeeId,
          clockIn: usage.clockIn,
          clockOut: usage.clockOut,
          totalHours: usage.totalHours,
          notes: usage.notes,
          createdAt: usage.createdAt,
          updatedAt: usage.updatedAt,
          teamCardDetails: {
            'card_name': row['card_name'],
            'card_type': row['card_type'],
            'card_description': row['card_description'],
          },
        );
      }).toList();
    } catch (e, stackTrace) {
      _logger.error(
        'Error getting employee team card usage: $e',
        e,
        stackTrace,
      );
      rethrow;
    }
  }

  // ==========================================
  // HELPER METHODS
  // ==========================================

  void _validateTeamCardData(Map<String, dynamic> data) {
    final errors = <String, List<String>>{};

    if (data['card_name'] == null || (data['card_name'] as String).isEmpty) {
      errors['card_name'] = ['Card name is required'];
    }

    if (errors.isNotEmpty) {
      throw ValidationException(errors);
    }
  }
}
