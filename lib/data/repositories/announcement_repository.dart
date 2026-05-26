import '../../domain/models/announcement.dart';
import '../database/connection.dart';

class AnnouncementRepository {
  /// Get all announcements with server-side search, filter, and pagination
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
    // Build WHERE clauses
    final whereClauses = <String>[];
    final values = <String, dynamic>{};

    // Search filter
    if (search != null && search.isNotEmpty) {
      whereClauses.add(
        "(LOWER(a.title) LIKE @search OR LOWER(a.content) LIKE @search)",
      );
      values['search'] = '%${search.toLowerCase()}%';
    }

    // Active status filter
    if (isActive != null) {
      whereClauses.add("a.is_active = @isActive");
      values['isActive'] = isActive ? 1 : 0;
    }

    // Date range filter - Using Asia/Kolkata timezone to ensure correct day matching
    if (startDate != null) {
      whereClauses.add("(a.announcement_date AT TIME ZONE 'Asia/Kolkata')::DATE >= @startDate::DATE");
      values['startDate'] = startDate.toIso8601String().split('T')[0];
    }
    if (endDate != null) {
      whereClauses.add("(a.announcement_date AT TIME ZONE 'Asia/Kolkata')::DATE <= @endDate::DATE");
      values['endDate'] = endDate.toIso8601String().split('T')[0];
    }

    final whereClause = whereClauses.isNotEmpty
        ? 'WHERE ${whereClauses.join(' AND ')}'
        : '';
    
    // Debug logging
    print('AnnouncementRepository: Fetching announcements with filter values: $values');
    print('AnnouncementRepository: Generated WHERE clause: $whereClause');

    // Sorting
    final validSortColumns = ['title', 'announcement_date', 'created_at'];
    final sortColumn = validSortColumns.contains(sortBy)
        ? 'a.$sortBy'
        : 'a.announcement_date';
    final order = sortOrder?.toUpperCase() == 'ASC' ? 'ASC' : 'DESC';

    // Get total count
    final countResult = await DatabaseConnection.query(
      'SELECT COUNT(*) as count FROM announcements a $whereClause',
      values: values,
    );
    final totalCount = (countResult.first['count'] as int?) ?? 0;

    // Pagination
    final offset = (page - 1) * limit;
    values['limit'] = limit;
    values['offset'] = offset;

    // Get paginated results with joined creator/updater info
    final result = await DatabaseConnection.query('''
      SELECT a.*, 
             COALESCE(e.employee_name, adm.admin_name) as creator_name,
             COALESCE(e.employee_role, adm.admin_role) as creator_role,
             COALESCE(e.employee_personal_email, adm.admin_personal_email) as creator_email,
             COALESCE(e.employee_img, adm.admin_img) as creator_image,
             COALESCE(e2.employee_name, adm2.admin_name) as updater_name,
             COALESCE(e2.employee_role, adm2.admin_role) as updater_role,
             COALESCE(e2.employee_personal_email, adm2.admin_personal_email) as updater_email,
             COALESCE(e2.employee_img, adm2.admin_img) as updater_image
      FROM announcements a
      LEFT JOIN employees e ON a.created_by = e.employee_id
      LEFT JOIN admins adm ON a.created_by = adm.admin_id
      LEFT JOIN employees e2 ON a.updated_by = e2.employee_id
      LEFT JOIN admins adm2 ON a.updated_by = adm2.admin_id
      $whereClause
      ORDER BY $sortColumn $order
      LIMIT @limit OFFSET @offset
      ''', values: values);

    final announcements = result.map((row) {
      final rowMap = Map<String, dynamic>.from(row);

      // Construct creator object
      if (row['creator_name'] != null) {
        rowMap['created_by'] = {
          'id': row['created_by'],
          'name': row['creator_name'],
          'role': row['creator_role'],
          'email': row['creator_email'],
          'profile_image': row['creator_image'],
        };
      }

      // Construct updater object
      if (row['updater_name'] != null) {
        rowMap['updated_by'] = {
          'id': row['updated_by'],
          'name': row['updater_name'],
          'role': row['updater_role'],
          'email': row['updater_email'],
          'profile_image': row['updater_image'],
        };
      }

      return Announcement.fromJson(rowMap);
    }).toList();

    return (announcements, totalCount);
  }

  Future<Announcement?> getAnnouncementById(String id) async {
    final result = await DatabaseConnection.query(
      '''
      SELECT a.*, 
             COALESCE(e.employee_name, adm.admin_name) as creator_name,
             COALESCE(e.employee_role, adm.admin_role) as creator_role,
             COALESCE(e.employee_personal_email, adm.admin_personal_email) as creator_email,
             COALESCE(e.employee_img, adm.admin_img) as creator_image,
             COALESCE(e2.employee_name, adm2.admin_name) as updater_name,
             COALESCE(e2.employee_role, adm2.admin_role) as updater_role,
             COALESCE(e2.employee_personal_email, adm2.admin_personal_email) as updater_email,
             COALESCE(e2.employee_img, adm2.admin_img) as updater_image
      FROM announcements a
      LEFT JOIN employees e ON a.created_by = e.employee_id
      LEFT JOIN admins adm ON a.created_by = adm.admin_id
      LEFT JOIN employees e2 ON a.updated_by = e2.employee_id
      LEFT JOIN admins adm2 ON a.updated_by = adm2.admin_id
      WHERE a.announcement_id = @id
      ''',
      values: {'id': id},
    );
    if (result.isEmpty) return null;

    final row = result.first;
    final rowMap = Map<String, dynamic>.from(row);

    if (row['creator_name'] != null) {
      rowMap['created_by'] = {
        'id': row['created_by'],
        'name': row['creator_name'],
        'role': row['creator_role'],
        'email': row['creator_email'],
        'profile_image': row['creator_image'],
      };
    }

    if (row['updater_name'] != null) {
      rowMap['updated_by'] = {
        'id': row['updated_by'],
        'name': row['updater_name'],
        'role': row['updater_role'],
        'email': row['updater_email'],
        'profile_image': row['updater_image'],
      };
    }

    return Announcement.fromJson(rowMap);
  }

  Future<Announcement> createAnnouncement(Announcement announcement) async {
    final createdById = announcement.createdBy is Map
        ? announcement.createdBy['id']
        : announcement.createdBy;

    final result = await DatabaseConnection.query(
      '''
      INSERT INTO announcements (
        title, content, announcement_date, created_by, is_active
      ) VALUES (
        @title, @content, @date, @createdBy, @isActive
      ) RETURNING *
      ''',
      values: {
        'title': announcement.title,
        'content': announcement.content,
        'date': announcement.announcementDate,
        'createdBy': createdById,
        'isActive': announcement.isActive ? 1 : 0,
      },
    );
    // Return the created announcement with enriched details by fetching it again
    return (await getAnnouncementById(result.first['announcement_id']))!;
  }

  Future<Announcement?> updateAnnouncement(
    String id,
    Map<String, dynamic> updates,
  ) async {
    final setClauses = <String>[];
    final values = <String, dynamic>{'id': id};

    updates.forEach((key, value) {
      if (key != 'announcement_id' &&
          key != 'created_at' &&
          key != 'updated_at') {
        // Handle Map values for createdBy/updatedBy (extract ID)
        if ((key == 'created_by' || key == 'updated_by') && value is Map) {
          values[key] = value['id'];
          setClauses.add('$key = @$key');
        } else if (key == 'is_active' && value is bool) {
          values[key] = value ? 1 : 0;
          setClauses.add('$key = @$key');
        } else {
          values[key] = value;
          setClauses.add('$key = @$key');
        }
      }
    });

    if (setClauses.isEmpty) return await getAnnouncementById(id);

    final query =
        '''
      UPDATE announcements 
      SET ${setClauses.join(', ')} 
      WHERE announcement_id = @id 
      RETURNING announcement_id
    '''; // Return ID to fetch full details

    final result = await DatabaseConnection.query(query, values: values);
    if (result.isEmpty) return null;

    return await getAnnouncementById(result.first['announcement_id']);
  }

  Future<bool> deleteAnnouncement(String id) async {
    final count = await DatabaseConnection.execute(
      'DELETE FROM announcements WHERE announcement_id = @id',
      values: {'id': id},
    );
    return count > 0;
  }
}
