import '../data/repositories/announcement_repository.dart';
import '../domain/models/announcement.dart';
import '../core/exceptions/app_exception.dart';
import '../core/utils/logger.dart';
import 'unified_notification_service.dart';

class AnnouncementService {
  final AnnouncementRepository _repository = AnnouncementRepository();
  final AppLogger _logger = AppLogger('AnnouncementService');

  Future<(List<Announcement>, int)> getAllAnnouncements({
    String? search,
    bool? isActive,
    DateTime? startDate,
    DateTime? endDate,
    int page = 1,

    int limit = 10,
    String? sortBy,
    String? sortOrder,
  }) async {
    try {
      return await _repository.getAllAnnouncements(
        search: search,
        isActive: isActive,
        startDate: startDate,
        endDate: endDate,
        page: page,
        limit: limit,
        sortBy: sortBy,
        sortOrder: sortOrder,
      );
    } catch (e, stackTrace) {
      _logger.error('Error getting all announcements: $e', e, stackTrace);
      rethrow;
    }
  }

  Future<Announcement> getAnnouncementById(String id) async {
    try {
      final announcement = await _repository.getAnnouncementById(id);
      if (announcement == null) {
        throw NotFoundException(resource: 'Announcement', id: id);
      }
      return announcement;
    } catch (e, stackTrace) {
      _logger.error('Error getting announcement by ID: $e', e, stackTrace);
      rethrow;
    }
  }

  Future<Announcement> createAnnouncement(Announcement announcement) async {
    try {
      final createdAnnouncement = await _repository.createAnnouncement(
        announcement,
      );

      // Send push notification and email in background - do not block response
      final createdById = createdAnnouncement.createdBy is Map
          ? createdAnnouncement.createdBy['id']?.toString() ?? 'system'
          : createdAnnouncement.createdBy?.toString() ?? 'system';
      UnifiedNotificationService.notifyAnnouncementCreated(
        announcementId: createdAnnouncement.announcementId ?? '',
        title: createdAnnouncement.title,
        content: createdAnnouncement.content,
        createdBy: createdById,
      ).catchError((e, st) {
        _logger.warning('Failed to send announcement notification: $e');
      });

      return createdAnnouncement;
    } catch (e, stackTrace) {
      _logger.error('Error creating announcement: $e', e, stackTrace);
      rethrow;
    }
  }

  Future<Announcement> updateAnnouncement(
    String id,
    Map<String, dynamic> updates,
  ) async {
    try {
      final updatedAnnouncement = await _repository.updateAnnouncement(
        id,
        updates,
      );
      if (updatedAnnouncement == null) {
        throw NotFoundException(resource: 'Announcement', id: id);
      }

      final updatedById = updatedAnnouncement.updatedBy is Map
          ? updatedAnnouncement.updatedBy['id']?.toString() ?? 'system'
          : updatedAnnouncement.updatedBy?.toString() ?? 'system';
      UnifiedNotificationService.notifyAnnouncementUpdated(
        announcementId: updatedAnnouncement.announcementId ?? id,
        title: updatedAnnouncement.title,
        content: updatedAnnouncement.content,
        updatedBy: updatedById,
      ).catchError((e, st) {
        _logger.warning('Failed to send announcement update notification: $e');
      });

      return updatedAnnouncement;
    } catch (e, stackTrace) {
      _logger.error('Error updating announcement: $e', e, stackTrace);
      rethrow;
    }
  }

  Future<bool> deleteAnnouncement(String id) async {
    try {
      final existing = await _repository.getAnnouncementById(id);
      if (existing == null) {
        throw NotFoundException(resource: 'Announcement', id: id);
      }
      final success = await _repository.deleteAnnouncement(id);
      if (!success) {
        throw NotFoundException(resource: 'Announcement', id: id);
      }
      UnifiedNotificationService.notifyAnnouncementDeleted(
        announcementId: id,
        title: existing.title,
        deletedBy: 'system',
      ).catchError((e, st) {
        _logger.warning('Failed to send announcement delete notification: $e');
      });
      return success;
    } catch (e, stackTrace) {
      _logger.error('Error deleting announcement: $e', e, stackTrace);
      rethrow;
    }
  }
}
