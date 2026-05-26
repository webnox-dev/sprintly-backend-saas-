import '../data/repositories/company_holiday_repository.dart';
import '../domain/models/company_holiday.dart';
import '../core/exceptions/app_exception.dart';
import '../core/utils/logger.dart';
import 'unified_notification_service.dart';

class CompanyHolidayService {
  final CompanyHolidayRepository _repository = CompanyHolidayRepository();
  final AppLogger _logger = AppLogger('CompanyHolidayService');

  Future<(List<CompanyHoliday>, int)> getAllHolidays({
    String? search,
    String? filterType,
    int page = 1,
    int limit = 10,
    String? sortBy,
    String? sortOrder,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      return await _repository.getAllHolidays(
        search: search,
        filterType: filterType,
        page: page,
        limit: limit,
        sortBy: sortBy,
        sortOrder: sortOrder,
        startDate: startDate,
        endDate: endDate,
      );
    } catch (e, stackTrace) {
      _logger.error('Error getting all holidays: $e', e, stackTrace);
      rethrow;
    }
  }

  Future<CompanyHoliday> getHolidayById(String id) async {
    try {
      final holiday = await _repository.getHolidayById(id);
      if (holiday == null) {
        throw NotFoundException(resource: 'CompanyHoliday', id: id);
      }
      return holiday;
    } catch (e, stackTrace) {
      _logger.error('Error getting holiday by ID: $e', e, stackTrace);
      rethrow;
    }
  }

  Future<CompanyHoliday> createHoliday(CompanyHoliday holiday) async {
    try {
      final created = await _repository.createHoliday(holiday);
      UnifiedNotificationService.notifyCompanyHolidayCreated(
        holidayId: created.holidayId ?? '',
        holidayName: created.holidayName,
        fromDate: created.fromDate,
        toDate: created.toDate,
        totalDays: created.totalDays,
        remarks: created.holidayRemarks,
        createdBy: created.createdBy ?? 'system',
        isOptional: created.isOptional,
      ).catchError((e, st) {
        _logger.warning('Failed to send company holiday creation notifications: $e');
      });
      return created;
    } catch (e, stackTrace) {
      _logger.error('Error creating holiday: $e', e, stackTrace);
      rethrow;
    }
  }

  Future<CompanyHoliday> updateHoliday(
    String id,
    Map<String, dynamic> updates,
  ) async {
    try {
      final holiday = await _repository.updateHoliday(id, updates);
      if (holiday == null) {
        throw NotFoundException(resource: 'CompanyHoliday', id: id);
      }
      UnifiedNotificationService.notifyCompanyHolidayUpdated(
        holidayId: holiday.holidayId ?? id,
        holidayName: holiday.holidayName,
        fromDate: holiday.fromDate,
        toDate: holiday.toDate,
        totalDays: holiday.totalDays,
        remarks: holiday.holidayRemarks,
        updatedBy: holiday.updatedBy ?? 'system',
        isOptional: holiday.isOptional,
      ).catchError((e, st) {
        _logger.warning('Failed to send company holiday update notifications: $e');
      });
      return holiday;
    } catch (e, stackTrace) {
      _logger.error('Error updating holiday: $e', e, stackTrace);
      rethrow;
    }
  }

  Future<bool> deleteHoliday(String id) async {
    try {
      final existing = await _repository.getHolidayById(id);
      if (existing == null) {
        throw NotFoundException(resource: 'CompanyHoliday', id: id);
      }
      final success = await _repository.deleteHoliday(id);
      if (!success) {
        throw NotFoundException(resource: 'CompanyHoliday', id: id);
      }
      UnifiedNotificationService.notifyCompanyHolidayDeleted(
        holidayId: id,
        holidayName: existing.holidayName,
        deletedBy: 'system',
      ).catchError((e, st) {
        _logger.warning('Failed to send company holiday deletion notifications: $e');
      });
      return success;
    } catch (e, stackTrace) {
      _logger.error('Error deleting holiday: $e', e, stackTrace);
      rethrow;
    }
  }
}
