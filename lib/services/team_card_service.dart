import '../data/repositories/team_card_repository.dart';
import '../domain/models/team_card.dart';
import '../core/exceptions/app_exception.dart';
import '../core/utils/logger.dart';

/// TeamCard service for business logic
/// Handles non-project work cards (Meeting, KT, Learning, R&D)
class TeamCardService {
  final TeamCardRepository _repository = TeamCardRepository();
  final AppLogger _logger = AppLogger('TeamCardService');

  // ==========================================
  // ADMIN - TEAM CARD OPERATIONS
  // ==========================================

  /// Create new team card
  Future<TeamCard> createNewTeamCard(
    Map<String, dynamic> data,
    String createdBy,
  ) async {
    try {
      // Validate card type
      final validCardTypes = [
        'Learning Card',
        'R&D Card',
        'Meeting Card',
        'KT Session Card',
      ];

      if (data['card_type'] != null &&
          !validCardTypes.contains(data['card_type'])) {
        throw ValidationException({
          'card_type': [
            'Invalid card type. Valid values: ${validCardTypes.join(', ')}',
          ],
        });
      }

      return await _repository.createNewTeamCard(data, createdBy);
    } catch (e, stackTrace) {
      _logger.error('Error creating team card: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Update team card
  Future<TeamCard> updateTeamCard(
    String teamCardId,
    Map<String, dynamic> updates,
    String updatedBy,
  ) async {
    try {
      return await _repository.updateTeamCard(teamCardId, updates, updatedBy);
    } catch (e, stackTrace) {
      _logger.error('Error updating team card: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Get all team cards with filters
  Future<Map<String, dynamic>> getAllTeamCards({
    int page = 1,
    int limit = 50,
    String? cardType,
    String? teamType,
    int? status,
    String? search,
  }) async {
    try {
      return await _repository.getAllTeamCards(
        page: page,
        limit: limit,
        cardType: cardType,
        teamType: teamType,
        status: status,
        search: search,
      );
    } catch (e, stackTrace) {
      _logger.error('Error getting all team cards: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Get team card by ID
  Future<TeamCard> getTeamCardById(String teamCardId) async {
    try {
      final teamCard = await _repository.getTeamCardById(teamCardId);
      if (teamCard == null) {
        throw NotFoundException(resource: 'TeamCard', id: teamCardId);
      }
      return teamCard;
    } catch (e, stackTrace) {
      _logger.error('Error getting team card by ID: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Activate/Deactivate team card
  Future<TeamCard> updateTeamCardStatus(
    String teamCardId,
    int status,
    String updatedBy,
  ) async {
    try {
      // Validate status
      if (status != 0 && status != 1) {
        throw ValidationException({
          'status': ['Status must be 0 (inactive) or 1 (active)'],
        });
      }

      return await _repository.updateTeamCardStatus(
        teamCardId,
        status,
        updatedBy,
      );
    } catch (e, stackTrace) {
      _logger.error('Error updating team card status: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Delete team card
  Future<bool> deleteTeamCard(String teamCardId) async {
    try {
      final existing = await _repository.getTeamCardById(teamCardId);
      if (existing == null) {
        throw NotFoundException(resource: 'TeamCard', id: teamCardId);
      }

      return await _repository.deleteTeamCard(teamCardId);
    } catch (e, stackTrace) {
      _logger.error('Error deleting team card: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Get team card usage report
  Future<Map<String, dynamic>> getTeamCardUsageReport(
    String teamCardId, {
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    try {
      final existing = await _repository.getTeamCardById(teamCardId);
      if (existing == null) {
        throw NotFoundException(resource: 'TeamCard', id: teamCardId);
      }

      return await _repository.getTeamCardUsageReport(
        teamCardId,
        fromDate: fromDate,
        toDate: toDate,
      );
    } catch (e, stackTrace) {
      _logger.error('Error getting team card usage report: $e', e, stackTrace);
      rethrow;
    }
  }

  // ==========================================
  // EMPLOYEE - TEAM CARD OPERATIONS
  // ==========================================

  /// Get available (active) team cards for employees
  Future<List<TeamCard>> getAvailableTeamCards() async {
    try {
      return await _repository.getAvailableTeamCards();
    } catch (e, stackTrace) {
      _logger.error('Error getting available team cards: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Clock-in to team card
  Future<TeamCardUsage> clockInToTeamCard(
    String teamCardId,
    String employeeId,
    String? notes,
  ) async {
    try {
      return await _repository.clockInToTeamCard(teamCardId, employeeId, notes);
    } catch (e, stackTrace) {
      _logger.error('Error clocking in to team card: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Clock-out from team card
  Future<TeamCardUsage> clockOutFromTeamCard(
    String teamCardId,
    String employeeId,
  ) async {
    try {
      return await _repository.clockOutFromTeamCard(teamCardId, employeeId);
    } catch (e, stackTrace) {
      _logger.error('Error clocking out from team card: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Get employee's team card usage history
  Future<List<TeamCardUsage>> getEmployeeTeamCardUsage(
    String employeeId, {
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    try {
      return await _repository.getEmployeeTeamCardUsage(
        employeeId,
        fromDate: fromDate,
        toDate: toDate,
      );
    } catch (e, stackTrace) {
      _logger.error(
        'Error getting employee team card usage: $e',
        e,
        stackTrace,
      );
      rethrow;
    }
  }
}
