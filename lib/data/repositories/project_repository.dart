import 'dart:convert';
import '../../domain/models/project.dart';
import '../database/connection.dart';
import '../../core/exceptions/app_exception.dart';
import '../../core/utils/logger.dart';

/// Project repository for database operations
/// Uses relational tables for sub-resources (documents, milestones, etc.)
class ProjectRepository {
  final AppLogger _logger = AppLogger('ProjectRepository');

  // ============================================
  // CORE PROJECT CRUD
  // ============================================

  /// Get all projects with pagination, filters, and full employee/admin details
  Future<Map<String, dynamic>> getAll({
    int page = 1,
    int limit = 50,
    String? status,
    String? priorityLevel,
    String? projectType,
    String? teamLeaderId,
    String? managerId,
    String? search,
    String? sortBy,
    bool ascending = false,
    String? requestingEmployeeId,
    String? requestingRole,
  }) async {
    try {
      final offset = (page - 1) * limit;
      final whereConditions = <String>[];
      final params = <String, dynamic>{};

      // ------------------------------------------
      // ROLE-BASED ACCESS CONTROL (RBAC)
      // ------------------------------------------
      // If role is provided and NOT privileged, filter by assignment
      if (requestingRole != null && requestingEmployeeId != null) {
        final role = requestingRole.toLowerCase();
        final isPrivileged =
            role.contains('admin') ||
            role.contains('manager') ||
            role.contains('supervisor') ||
            role.contains('ceo') ||
            role.contains('director');

        if (!isPrivileged) {
          // Employee sees project ONLY if:
          // 1. They are Team Leader
          // 2. They are Project Manager (employee ID match)
          // 3. They are in Team Members list (JSONB array contains their ID)
          // 4. They are in BDE list (JSONB array contains their ID)

          // Note: using @> operator for JSONB containment.
          // We wrap ID in to_jsonb to match the array element type (string)
          whereConditions.add('''
            (
              p.project_team_leader_id = @reqEmpId OR 
              p.project_manager_id = @reqEmpId OR
              p.project_team_member_ids @> @reqEmpIdJson::jsonb OR
              p.project_followed_by_bde_employee_ids @> @reqEmpIdJson::jsonb
            )
          ''');
          params['reqEmpId'] = requestingEmployeeId;
          // Create a JSON array string containing the ID
          params['reqEmpIdJson'] = '["$requestingEmployeeId"]';
        }
      }

      if (status != null && status.isNotEmpty) {
        whereConditions.add('p.project_status = @status');
        params['status'] = status;
      }

      if (priorityLevel != null && priorityLevel.isNotEmpty) {
        whereConditions.add('p.project_priority_level = @priorityLevel');
        params['priorityLevel'] = priorityLevel;
      }

      if (projectType != null && projectType.isNotEmpty) {
        whereConditions.add('p.project_type = @projectType');
        params['projectType'] = projectType;
      }

      if (teamLeaderId != null && teamLeaderId.isNotEmpty) {
        whereConditions.add('p.project_team_leader_id = @teamLeaderId');
        params['teamLeaderId'] = teamLeaderId;
      }

      if (managerId != null && managerId.isNotEmpty) {
        whereConditions.add('p.project_manager_id = @managerId');
        params['managerId'] = managerId;
      }

      if (search != null && search.isNotEmpty) {
        whereConditions.add(
          '(LOWER(p.project_name) LIKE LOWER(@search) OR LOWER(p.project_description) LIKE LOWER(@search))',
        );
        params['search'] = '%$search%';
      }

      final whereClause = whereConditions.isNotEmpty
          ? 'WHERE ${whereConditions.join(' AND ')}'
          : '';

      // Validate sortBy to prevent SQL injection
      final allowedSortFields = [
        'project_name',
        'project_status',
        'project_priority_level',
        'project_start_date',
        'project_end_date',
        'project_created_at',
        'project_updated_at',
      ];
      final orderBy = (sortBy != null && allowedSortFields.contains(sortBy))
          ? 'ORDER BY p.$sortBy ${ascending ? 'ASC' : 'DESC'}'
          : 'ORDER BY p.project_created_at DESC';

      // Count query
      final countSql = 'SELECT COUNT(*) as total FROM projects p $whereClause';
      final countResult = await DatabaseConnection.queryOne(
        countSql,
        values: params,
      );
      final total = (countResult?['total'] as num?)?.toInt() ?? 0;

      // Data query with JOINs for employee/admin details
      final sql =
          '''
        SELECT 
          p.project_id, p.project_name, p.project_img, p.project_description,
          p.project_status, p.project_priority_level, p.project_type,
          p.project_start_date, p.project_end_date, p.project_mvp_date,
          p.project_team_leader_id, p.project_manager_id,
          p.project_team_member_ids, p.project_followed_by_bde_employee_ids,
          p.project_requirements,
          p.project_created_at, p.project_updated_at,
          p.client_name, p.company_name, p.client_type, p.client_address, p.client_country, p.client_phone,
          
          -- Team Leader (from employees)
          tl.employee_id as tl_id, tl.employee_name as tl_name, tl.employee_role as tl_role, 
          tl.employee_designation as tl_designation, tl.employee_img as tl_img,
          
          -- Project Manager (could be admin or employee - try admin first, then employee)
          COALESCE(pm_admin.admin_id, pm_emp.employee_id) as pm_id,
          COALESCE(pm_admin.admin_name, pm_emp.employee_name) as pm_name,
          COALESCE(pm_admin.admin_role, pm_emp.employee_role) as pm_role,
          COALESCE(pm_admin.admin_designation, pm_emp.employee_designation) as pm_designation,
          COALESCE(pm_admin.admin_img, pm_emp.employee_img) as pm_img,
          
          -- Counts
          (SELECT COUNT(*) FROM project_milestones WHERE project_id = p.project_id) as milestone_count,
          (SELECT COUNT(*) FROM project_releases WHERE project_id = p.project_id) as release_count,
          (SELECT COUNT(*) FROM project_documents WHERE project_id = p.project_id) as document_count,
          COALESCE(jsonb_array_length(p.project_team_member_ids::jsonb), 0) as team_member_count
          
        FROM projects p
        LEFT JOIN employees tl ON p.project_team_leader_id = tl.employee_id
        LEFT JOIN admins pm_admin ON p.project_manager_id = pm_admin.admin_id
        LEFT JOIN employees pm_emp ON p.project_manager_id = pm_emp.employee_id AND pm_admin.admin_id IS NULL
        $whereClause 
        $orderBy 
        LIMIT @limit OFFSET @offset
      ''';
      params['limit'] = limit;
      params['offset'] = offset;

      final results = await DatabaseConnection.query(sql, values: params);

      // Process results to build rich response
      final projects = <Map<String, dynamic>>[];
      for (final row in results) {
        // Fetch BDEs details
        final bdeIds = _parseStringList(
          row['project_followed_by_bde_employee_ids'],
        );
        final handledByList = await _getEmployeeDetailsList(bdeIds);

        // Fetch Team Members details
        final teamMemberIds = _parseStringList(row['project_team_member_ids']);
        final teamMembersList = await _getEmployeeDetailsList(teamMemberIds);

        projects.add({
          'project_id': row['project_id']?.toString(),
          'project_name': row['project_name']?.toString() ?? '',
          'project_img': row['project_img']?.toString(),
          'project_description': row['project_description']?.toString(),
          'project_status': row['project_status']?.toString() ?? 'NOT_STARTED',
          'project_priority_level':
              row['project_priority_level']?.toString() ?? 'MEDIUM',
          'project_type': row['project_type']?.toString(),
          'project_start_date': row['project_start_date']?.toString(),
          'project_end_date': row['project_end_date']?.toString(),
          'project_mvp_date': row['project_mvp_date']?.toString(),
          'project_requirements': _parseStringList(row['project_requirements']),
          'project_created_at': row['project_created_at']?.toString(),
          'project_updated_at': row['project_updated_at']?.toString(),

          // Counts
          'team_member_count': row['team_member_count'] ?? teamMemberIds.length,
          'milestone_count': row['milestone_count'] ?? 0,
          'release_count': row['release_count'] ?? 0,
          'document_count': row['document_count'] ?? 0,

          // Client Details (nested object)
          'client_details': {
            'client_name': row['client_name']?.toString(),
            'company_name': row['company_name']?.toString(),
            'client_type': row['client_type']?.toString(),
            'client_address': row['client_address']?.toString(),
            'client_country': row['client_country']?.toString(),
            'client_phone': row['client_phone']?.toString(),
          },

          // Team Leader (full employee object)
          'project_team_leader': row['tl_id'] != null
              ? {
                  'employee_id': row['tl_id']?.toString(),
                  'employee_name': row['tl_name']?.toString(),
                  'employee_role': row['tl_role']?.toString(),
                  'employee_designation': row['tl_designation']?.toString(),
                  'employee_img': row['tl_img']?.toString(),
                }
              : null,

          // Project Manager (full employee/admin object)
          'project_manager': row['pm_id'] != null
              ? {
                  'id': row['pm_id']?.toString(),
                  'name': row['pm_name']?.toString(),
                  'role': row['pm_role']?.toString(),
                  'designation': row['pm_designation']?.toString(),
                  'img': row['pm_img']?.toString(),
                }
              : null,

          // Handled By BDEs (array of employee objects)
          'handled_by': handledByList,

          // Project Members (array of employee objects)
          'project_members': teamMembersList,
        });
      }

      return {
        'data': projects,
        'total': total,
        'page': page,
        'limit': limit,
        'totalPages': total > 0 ? (total / limit).ceil() : 0,
      };
    } catch (e, stackTrace) {
      _logger.error('Error getting all projects: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Get project by ID with all related data (full details)
  Future<Map<String, dynamic>?> getByIdRich(String projectId) async {
    try {
      // Get base project with JOINs
      final sql = '''
        SELECT 
          p.*,
          
          -- Team Leader
          tl.employee_id as tl_id, tl.employee_name as tl_name, tl.employee_role as tl_role, 
          tl.employee_designation as tl_designation, tl.employee_img as tl_img,
          
          -- Project Manager
          COALESCE(pm_admin.admin_id, pm_emp.employee_id) as pm_id,
          COALESCE(pm_admin.admin_name, pm_emp.employee_name) as pm_name,
          COALESCE(pm_admin.admin_role, pm_emp.employee_role) as pm_role,
          COALESCE(pm_admin.admin_designation, pm_emp.employee_designation) as pm_designation,
          COALESCE(pm_admin.admin_img, pm_emp.employee_img) as pm_img,

          -- Creator (Admin)
          creator.admin_id as creator_id, creator.admin_name as creator_name, 
          creator.admin_role as creator_role, creator.admin_designation as creator_designation,
          creator.admin_img as creator_img
          
        FROM projects p
        LEFT JOIN employees tl ON p.project_team_leader_id = tl.employee_id
        LEFT JOIN admins pm_admin ON p.project_manager_id = pm_admin.admin_id
        LEFT JOIN employees pm_emp ON p.project_manager_id = pm_emp.employee_id AND pm_admin.admin_id IS NULL
        LEFT JOIN admins creator ON p.project_created_by = creator.admin_id
        WHERE p.project_id = @id
      ''';

      final row = await DatabaseConnection.queryOne(
        sql,
        values: {'id': projectId},
      );
      if (row == null) return null;

      // Fetch related data from tables in parallel
      final futures = await Future.wait([
        _getDocumentsByProjectId(projectId),
        _getFigmaUrlsByProjectId(projectId),
        _getMilestonesByProjectId(projectId),
        _getReleasesByProjectId(projectId),
        _getClientReviewsByProjectId(projectId),
        _getDiscontinuationByProjectId(projectId),
      ]);

      final documents = futures[0] as List<ProjectDocument>;
      final figmaUrls = futures[1] as List<FigmaUrl>;
      final milestones = futures[2] as List<ProjectMilestone>;
      final releases = futures[3] as List<ProjectRelease>;
      final clientReviews = futures[4] as List<ClientReview>;
      final discontinuation = futures[5] as ProjectDiscontinuation?;

      // Fetch BDEs and Team Members
      final bdeIds = _parseStringList(
        row['project_followed_by_bde_employee_ids'],
      );
      final handledByList = await _getEmployeeDetailsList(bdeIds);

      final teamMemberIds = _parseStringList(row['project_team_member_ids']);
      final teamMembersList = await _getEmployeeDetailsList(teamMemberIds);

      return {
        'project_id': row['project_id']?.toString(),
        'project_name': row['project_name']?.toString() ?? '',
        'project_img': row['project_img']?.toString(),
        'project_description': row['project_description']?.toString(),
        'project_status': row['project_status']?.toString() ?? 'NOT_STARTED',
        'project_priority_level':
            row['project_priority_level']?.toString() ?? 'MEDIUM',
        'project_type': row['project_type']?.toString(),
        'project_start_date': row['project_start_date']?.toString(),
        'project_end_date': row['project_end_date']?.toString(),
        'project_mvp_date': row['project_mvp_date']?.toString(),
        'project_requirements': _parseStringList(row['project_requirements']),
        'project_created_at': row['project_created_at']?.toString(),
        'project_updated_at': row['project_updated_at']?.toString(),
        'project_created_by': row['project_created_by']?.toString(),
        'project_updated_by': row['project_updated_by']?.toString(),

        // Counts
        'team_member_count': teamMemberIds.length,
        'milestone_count': milestones.length,
        'release_count': releases.length,
        'document_count': documents.length,

        // Client Details
        'client_details': {
          'client_name': row['client_name']?.toString(),
          'company_name': row['company_name']?.toString(),
          'client_type': row['client_type']?.toString(),
          'client_address': row['client_address']?.toString(),
          'client_country': row['client_country']?.toString(),
          'client_phone': row['client_phone']?.toString(),
        },

        // Team Leader
        'project_team_leader': row['tl_id'] != null
            ? {
                'employee_id': row['tl_id']?.toString(),
                'employee_name': row['tl_name']?.toString(),
                'employee_role': row['tl_role']?.toString(),
                'employee_designation': row['tl_designation']?.toString(),
                'employee_img': row['tl_img']?.toString(),
              }
            : null,

        // Project Manager
        'project_manager': row['pm_id'] != null
            ? {
                'id': row['pm_id']?.toString(),
                'name': row['pm_name']?.toString(),
                'role': row['pm_role']?.toString(),
                'designation': row['pm_designation']?.toString(),
                'img': row['pm_img']?.toString(),
              }
            : null,

        // Created By Info (Admin)
        'created_by_info': row['creator_id'] != null
            ? {
                'id': row['creator_id']?.toString(),
                'name': row['creator_name']?.toString(),
                'role': row['creator_role']?.toString(),
                'designation': row['creator_designation']?.toString(),
                'img': row['creator_img']?.toString(),
              }
            : null,

        // Handled By BDEs
        'handled_by': handledByList,

        // Project Members
        'project_members': teamMembersList,

        // Sub-resources as lists of objects
        'project_documents': documents.map((d) => d.toJson()).toList(),
        'project_figma_urls': figmaUrls.map((f) => f.toJson()).toList(),
        'project_milestones': milestones.map((m) => m.toJson()).toList(),
        'project_releases': releases.map((r) => r.toJson()).toList(),
        'project_client_reviews': clientReviews.map((c) => c.toJson()).toList(),
        'project_discontinuation_details': discontinuation?.toJson(),
      };
    } catch (e, stackTrace) {
      _logger.error('Error getting project by ID (rich): $e', e, stackTrace);
      rethrow;
    }
  }

  /// Helper to fetch employee details for a list of IDs
  Future<List<Map<String, dynamic>>> _getEmployeeDetailsList(
    List<String> ids,
  ) async {
    if (ids.isEmpty) return [];

    final result = <Map<String, dynamic>>[];
    for (final id in ids) {
      final emp = await DatabaseConnection.queryOne(
        'SELECT employee_id, employee_name, employee_role, employee_designation, employee_img FROM employees WHERE employee_id = @id',
        values: {'id': id},
      );
      if (emp != null) {
        result.add({
          'employee_id': emp['employee_id']?.toString(),
          'employee_name': emp['employee_name']?.toString(),
          'employee_role': emp['employee_role']?.toString(),
          'employee_designation': emp['employee_designation']?.toString(),
          'employee_img': emp['employee_img']?.toString(),
        });
      }
    }
    return result;
  }

  /// Get project by ID with all related data from tables (legacy format for updates)
  Future<Project?> getById(String projectId) async {
    try {
      // Get base project
      final projectResult = await DatabaseConnection.queryOne(
        'SELECT * FROM projects WHERE project_id = @id',
        values: {'id': projectId},
      );
      if (projectResult == null) return null;

      // Fetch related data from tables in parallel
      final futures = await Future.wait([
        _getDocumentsByProjectId(projectId),
        _getFigmaUrlsByProjectId(projectId),
        _getMilestonesByProjectId(projectId),
        _getReleasesByProjectId(projectId),
        _getClientReviewsByProjectId(projectId),
        _getDiscontinuationByProjectId(projectId),
      ]);

      final documents = futures[0] as List<ProjectDocument>;
      final figmaUrls = futures[1] as List<FigmaUrl>;
      final milestones = futures[2] as List<ProjectMilestone>;
      final releases = futures[3] as List<ProjectRelease>;
      final clientReviews = futures[4] as List<ClientReview>;
      final discontinuation = futures[5] as ProjectDiscontinuation?;

      // Construct full project
      return Project(
        projectId: projectResult['project_id']?.toString(),
        projectName: projectResult['project_name']?.toString() ?? '',
        projectImg: projectResult['project_img']?.toString(),
        projectDescription: projectResult['project_description']?.toString(),
        projectRequirements: _parseStringList(
          projectResult['project_requirements'],
        ),
        projectStartDate: projectResult['project_start_date']?.toString(),
        projectEndDate: projectResult['project_end_date']?.toString(),
        projectMvpDate: projectResult['project_mvp_date']?.toString(),
        projectDocuments: documents,
        projectFigmaUrls: figmaUrls,
        projectStatus:
            projectResult['project_status']?.toString() ?? 'NOT_STARTED',
        projectPriorityLevel:
            projectResult['project_priority_level']?.toString() ?? 'MEDIUM',
        projectType: projectResult['project_type']?.toString(),
        projectTeamLeaderId: projectResult['project_team_leader_id']
            ?.toString(),
        projectManagerId: projectResult['project_manager_id']?.toString(),
        projectTeamMemberIds: _parseStringList(
          projectResult['project_team_member_ids'],
        ),
        projectFollowedByBdeEmployeeIds: _parseStringList(
          projectResult['project_followed_by_bde_employee_ids'],
        ),
        // Client Details
        clientName: projectResult['client_name']?.toString(),
        companyName: projectResult['company_name']?.toString(),
        clientType: projectResult['client_type']?.toString(),
        clientAddress: projectResult['client_address']?.toString(),
        clientCountry: projectResult['client_country']?.toString(),
        clientPhone: projectResult['client_phone']?.toString(),
        // Sub-resources
        projectMilestones: milestones,
        projectReleases: releases,
        projectClientReviews: clientReviews,
        projectDiscontinuationDetails: discontinuation,
        projectCreatedBy: projectResult['project_created_by']?.toString(),
        projectCreatedAt: projectResult['project_created_at'] != null
            ? DateTime.tryParse(projectResult['project_created_at'].toString())
            : null,
        projectUpdatedBy: projectResult['project_updated_by']?.toString(),
        projectUpdatedAt: projectResult['project_updated_at'] != null
            ? DateTime.tryParse(projectResult['project_updated_at'].toString())
            : null,
      );
    } catch (e, stackTrace) {
      _logger.error('Error getting project by ID: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Create project with all related data in a transaction
  Future<Project> create(Map<String, dynamic> data) async {
    try {
      // Extract sub-resources before inserting main project
      final documents = data.remove('project_documents') as List? ?? [];
      final figmaUrls = data.remove('project_figma_urls') as List? ?? [];
      final milestones = data.remove('project_milestones') as List? ?? [];
      final releases = data.remove('project_releases') as List? ?? [];
      final clientReviews =
          data.remove('project_client_reviews') as List? ?? [];

      // Convert remaining arrays to JSON
      _convertToJson(data, 'project_requirements');
      _convertToJson(data, 'project_team_member_ids');
      _convertToJson(data, 'project_followed_by_bde_employee_ids');

      // Remove null values
      data.removeWhere((key, value) => value == null);

      final columns = data.keys.join(', ');
      final placeholders = data.keys.map((k) => '@$k').join(', ');

      final sql =
          '''
        INSERT INTO projects ($columns)
        VALUES ($placeholders)
        RETURNING *
      ''';

      final result = await DatabaseConnection.queryOne(sql, values: data);
      if (result == null) {
        throw DatabaseException(message: 'Failed to create project');
      }

      final projectId = result['project_id'].toString();
      final createdBy = data['project_created_by']?.toString();

      // Insert sub-resources into their respective tables
      await Future.wait([
        _insertDocuments(projectId, documents, createdBy),
        _insertFigmaUrls(projectId, figmaUrls, createdBy),
        _insertMilestones(projectId, milestones, createdBy),
        _insertReleases(projectId, releases, createdBy),
        _insertClientReviews(projectId, clientReviews, createdBy),
      ]);

      // Return fresh project with all data
      return (await getById(projectId))!;
    } catch (e, stackTrace) {
      _logger.error('Error creating project: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Update project core fields only
  Future<Project> update(String projectId, Map<String, dynamic> updates) async {
    try {
      // Remove sub-resource fields - they should be managed via helper endpoints
      updates.remove('project_documents');
      updates.remove('project_figma_urls');
      updates.remove('project_milestones');
      updates.remove('project_releases');
      updates.remove('project_client_reviews');
      updates.remove('project_discontinuation_details');

      if (updates.isEmpty) {
        final existing = await getById(projectId);
        if (existing == null) {
          throw NotFoundException(resource: 'Project', id: projectId);
        }
        return existing;
      }

      // Convert arrays to JSON
      _convertToJson(updates, 'project_requirements');
      _convertToJson(updates, 'project_team_member_ids');
      _convertToJson(updates, 'project_followed_by_bde_employee_ids');

      // Remove null values
      updates.removeWhere((key, value) => value == null);

      final setClause = updates.keys.map((k) => '$k = @$k').join(', ');
      final sql =
          '''
        UPDATE projects 
        SET $setClause, project_updated_at = CURRENT_TIMESTAMP
        WHERE project_id = @id
        RETURNING *
      ''';

      updates['id'] = projectId;
      final result = await DatabaseConnection.queryOne(sql, values: updates);

      if (result == null) {
        throw NotFoundException(resource: 'Project', id: projectId);
      }

      return (await getById(projectId))!;
    } catch (e, stackTrace) {
      _logger.error('Error updating project: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Update project status
  Future<Project> updateStatus(
    String projectId,
    String status,
    String updatedBy,
  ) async {
    try {
      return await update(projectId, {
        'project_status': status,
        'project_updated_by': updatedBy,
      });
    } catch (e, stackTrace) {
      _logger.error('Error updating status: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Add team member to project
  Future<Project> addTeamMember(
    String projectId,
    String memberId,
    String updatedBy,
  ) async {
    try {
      final project = await getById(projectId);
      if (project == null) {
        throw NotFoundException(resource: 'Project', id: projectId);
      }

      final members = List<String>.from(project.projectTeamMemberIds);
      if (!members.contains(memberId)) {
        members.add(memberId);
      }

      return await update(projectId, {
        'project_team_member_ids': members,
        'project_updated_by': updatedBy,
      });
    } catch (e, stackTrace) {
      _logger.error('Error adding team member: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Remove team member from project
  Future<Project> removeTeamMember(
    String projectId,
    String memberId,
    String updatedBy,
  ) async {
    try {
      final project = await getById(projectId);
      if (project == null) {
        throw NotFoundException(resource: 'Project', id: projectId);
      }

      final members = List<String>.from(project.projectTeamMemberIds);
      members.remove(memberId);

      return await update(projectId, {
        'project_team_member_ids': members,
        'project_updated_by': updatedBy,
      });
    } catch (e, stackTrace) {
      _logger.error('Error removing team member: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Delete project (cascades to all related tables via FK)
  Future<bool> delete(String projectId) async {
    try {
      final sql = 'DELETE FROM projects WHERE project_id = @id';
      final affectedRows = await DatabaseConnection.execute(
        sql,
        values: {'id': projectId},
      );
      return affectedRows > 0;
    } catch (e, stackTrace) {
      _logger.error('Error deleting project: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Get projects by status
  Future<List<Project>> getByStatus(String status) async {
    try {
      final sql = '''
        SELECT project_id FROM projects 
        WHERE project_status = @status 
        ORDER BY project_created_at DESC
      ''';
      final results = await DatabaseConnection.query(
        sql,
        values: {'status': status},
      );

      final projects = <Project>[];
      for (final row in results) {
        final project = await getById(row['project_id'].toString());
        if (project != null) projects.add(project);
      }
      return projects;
    } catch (e, stackTrace) {
      _logger.error('Error getting projects by status: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Get project statistics
  Future<Map<String, dynamic>> getStatistics() async {
    try {
      final sql = '''
        SELECT 
          COUNT(*) as total_projects,
          COUNT(CASE WHEN project_status = 'NOT_STARTED' THEN 1 END) as not_started,
          COUNT(CASE WHEN project_status = 'IN_PROGRESS' THEN 1 END) as in_progress,
          COUNT(CASE WHEN project_status = 'COMPLETED' THEN 1 END) as completed,
          COUNT(CASE WHEN project_status = 'ON_HOLD' THEN 1 END) as on_hold,
          COUNT(CASE WHEN project_status = 'DISCONTINUED' THEN 1 END) as discontinued,
          COUNT(CASE WHEN project_priority_level = 'CRITICAL' THEN 1 END) as critical_priority,
          COUNT(CASE WHEN project_priority_level = 'HIGH' THEN 1 END) as high_priority
        FROM projects
      ''';

      final result = await DatabaseConnection.queryOne(sql);
      return {
        'totalProjects': result?['total_projects'] ?? 0,
        'byStatus': {
          'notStarted': result?['not_started'] ?? 0,
          'inProgress': result?['in_progress'] ?? 0,
          'completed': result?['completed'] ?? 0,
          'onHold': result?['on_hold'] ?? 0,
          'discontinued': result?['discontinued'] ?? 0,
        },
        'byPriority': {
          'critical': result?['critical_priority'] ?? 0,
          'high': result?['high_priority'] ?? 0,
        },
      };
    } catch (e, stackTrace) {
      _logger.error('Error getting statistics: $e', e, stackTrace);
      rethrow;
    }
  }

  // ============================================
  // PRIVATE HELPER METHODS - Fetch from Tables
  // ============================================

  Future<List<ProjectDocument>> _getDocumentsByProjectId(
    String projectId,
  ) async {
    final results = await DatabaseConnection.query(
      'SELECT * FROM project_documents WHERE project_id = @projectId ORDER BY created_at DESC',
      values: {'projectId': projectId},
    );
    return results.map((row) => ProjectDocument.fromMap(row)).toList();
  }

  Future<List<FigmaUrl>> _getFigmaUrlsByProjectId(String projectId) async {
    final results = await DatabaseConnection.query(
      'SELECT * FROM project_figma_urls WHERE project_id = @projectId ORDER BY created_at DESC',
      values: {'projectId': projectId},
    );
    return results.map((row) => FigmaUrl.fromMap(row)).toList();
  }

  Future<List<ProjectMilestone>> _getMilestonesByProjectId(
    String projectId,
  ) async {
    final results = await DatabaseConnection.query(
      'SELECT * FROM project_milestones WHERE project_id = @projectId ORDER BY project_milestone_created_at DESC',
      values: {'projectId': projectId},
    );
    return results.map((row) => ProjectMilestone.fromMap(row)).toList();
  }

  Future<List<ProjectRelease>> _getReleasesByProjectId(String projectId) async {
    // Fetch releases with their attachments
    final releases = await DatabaseConnection.query(
      'SELECT * FROM project_releases WHERE project_id = @projectId ORDER BY project_release_planned_date DESC',
      values: {'projectId': projectId},
    );

    final result = <ProjectRelease>[];
    for (final releaseRow in releases) {
      final releaseId = releaseRow['project_release_id'].toString();
      final attachments = await DatabaseConnection.query(
        'SELECT * FROM release_attachments WHERE project_release_id = @releaseId ORDER BY release_attachment_created_at DESC',
        values: {'releaseId': releaseId},
      );

      final release = ProjectRelease(
        projectReleaseId: releaseRow['project_release_id']?.toString(),
        projectId: releaseRow['project_id']?.toString(),
        projectReleaseTitle:
            releaseRow['project_release_title']?.toString() ?? '',
        projectReleasePlannedDate: releaseRow['project_release_planned_date']
            ?.toString(),
        projectReleaseActualDate: releaseRow['project_release_actual_date']
            ?.toString(),
        projectReleaseDevCutoffDate:
            releaseRow['project_release_dev_cutoff_date']?.toString(),
        projectReleaseQcCutoffDate: releaseRow['project_release_qc_cutoff_date']
            ?.toString(),
        projectReleaseNotes: releaseRow['project_release_notes']?.toString(),
        projectReleaseAttachments: attachments
            .map((a) => ReleaseAttachment.fromMap(a))
            .toList(),
        projectReleaseCreatedBy: releaseRow['project_release_created_by']
            ?.toString(),
        projectReleaseCreatedAt:
            releaseRow['project_release_created_at'] != null
            ? DateTime.tryParse(
                releaseRow['project_release_created_at'].toString(),
              )
            : null,
        projectReleaseUpdatedBy: releaseRow['project_release_updated_by']
            ?.toString(),
        projectReleaseUpdatedAt:
            releaseRow['project_release_updated_at'] != null
            ? DateTime.tryParse(
                releaseRow['project_release_updated_at'].toString(),
              )
            : null,
      );
      result.add(release);
    }
    return result;
  }

  Future<List<ClientReview>> _getClientReviewsByProjectId(
    String projectId,
  ) async {
    final results = await DatabaseConnection.query(
      'SELECT * FROM client_reviews WHERE project_id = @projectId ORDER BY client_review_created_at DESC',
      values: {'projectId': projectId},
    );
    return results.map((row) => ClientReview.fromMap(row)).toList();
  }

  Future<ProjectDiscontinuation?> _getDiscontinuationByProjectId(
    String projectId,
  ) async {
    final result = await DatabaseConnection.queryOne(
      'SELECT * FROM project_discontinuations WHERE project_id = @projectId',
      values: {'projectId': projectId},
    );
    if (result == null) return null;
    return ProjectDiscontinuation.fromMap(result);
  }

  // ============================================
  // PRIVATE HELPER METHODS - Insert into Tables
  // ============================================

  Future<void> _insertDocuments(
    String projectId,
    List documents,
    String? createdBy,
  ) async {
    for (final doc in documents) {
      if (doc is Map<String, dynamic>) {
        await DatabaseConnection.execute(
          '''
          INSERT INTO project_documents (project_id, document_name, document_url, document_type, created_by)
          VALUES (@projectId, @name, @url, @type, @createdBy)
          ''',
          values: {
            'projectId': projectId,
            'name': doc['document_name'],
            'url': doc['document_url'],
            'type': doc['document_type'],
            'createdBy': createdBy,
          },
        );
      }
    }
  }

  Future<void> _insertFigmaUrls(
    String projectId,
    List figmaUrls,
    String? createdBy,
  ) async {
    for (final url in figmaUrls) {
      if (url is Map<String, dynamic>) {
        await DatabaseConnection.execute(
          '''
          INSERT INTO project_figma_urls (project_id, figma_url_name, figma_url, created_by)
          VALUES (@projectId, @name, @url, @createdBy)
          ''',
          values: {
            'projectId': projectId,
            'name': url['figma_url_name'],
            'url': url['figma_url'],
            'createdBy': createdBy,
          },
        );
      }
    }
  }

  Future<void> _insertMilestones(
    String projectId,
    List milestones,
    String? createdBy,
  ) async {
    for (final milestone in milestones) {
      if (milestone is Map<String, dynamic>) {
        await DatabaseConnection.execute(
          '''
          INSERT INTO project_milestones (project_id, project_milestone_title, project_milestone_achievement_description, project_milestone_created_by)
          VALUES (@projectId, @title, @description, @createdBy)
          ''',
          values: {
            'projectId': projectId,
            'title': milestone['project_milestone_title'],
            'description':
                milestone['project_milestone_achievement_description'],
            'createdBy': createdBy,
          },
        );
      }
    }
  }

  Future<void> _insertReleases(
    String projectId,
    List releases,
    String? createdBy,
  ) async {
    for (final release in releases) {
      if (release is Map<String, dynamic>) {
        final releaseResult = await DatabaseConnection.queryOne(
          '''
          INSERT INTO project_releases (
            project_id, project_release_title, project_release_planned_date,
            project_release_actual_date, project_release_dev_cutoff_date,
            project_release_qc_cutoff_date, project_release_notes, project_release_created_by
          ) VALUES (@projectId, @title, @plannedDate, @actualDate, @devCutoff, @qcCutoff, @notes, @createdBy)
          RETURNING project_release_id
          ''',
          values: {
            'projectId': projectId,
            'title': release['project_release_title'],
            'plannedDate': release['project_release_planned_date'],
            'actualDate': release['project_release_actual_date'],
            'devCutoff': release['project_release_dev_cutoff_date'],
            'qcCutoff': release['project_release_qc_cutoff_date'],
            'notes': release['project_release_notes'],
            'createdBy': createdBy,
          },
        );

        // Insert attachments if any
        final attachments =
            release['project_release_attachments'] as List? ?? [];
        if (releaseResult != null && attachments.isNotEmpty) {
          final releaseId = releaseResult['project_release_id'].toString();
          for (final attachment in attachments) {
            if (attachment is Map<String, dynamic>) {
              await DatabaseConnection.execute(
                '''
                INSERT INTO release_attachments (
                  project_release_id, project_id, release_attachment_type,
                  release_attachment_value, release_attachment_created_by
                ) VALUES (@releaseId, @projectId, @type, @value, @createdBy)
                ''',
                values: {
                  'releaseId': releaseId,
                  'projectId': projectId,
                  'type': attachment['release_attachment_type'],
                  'value': attachment['release_attachment_value'],
                  'createdBy': createdBy,
                },
              );
            }
          }
        }
      }
    }
  }

  Future<void> _insertClientReviews(
    String projectId,
    List reviews,
    String? createdBy,
  ) async {
    for (final review in reviews) {
      if (review is Map<String, dynamic>) {
        await DatabaseConnection.execute(
          '''
          INSERT INTO client_reviews (project_id, client_review_comment, client_review_rating, client_review_created_by)
          VALUES (@projectId, @comment, @rating, @createdBy)
          ''',
          values: {
            'projectId': projectId,
            'comment': review['client_review_comment'],
            'rating': review['client_review_rating'],
            'createdBy': createdBy,
          },
        );
      }
    }
  }

  // ============================================
  // UTILITY METHODS
  // ============================================

  void _convertToJson(Map<String, dynamic> data, String key) {
    if (data[key] != null && data[key] is! String) {
      data[key] = jsonEncode(data[key]);
    }
  }

  List<String> _parseStringList(dynamic value) {
    if (value == null) return [];
    if (value is List) return value.map((e) => e.toString()).toList();
    if (value is String) {
      try {
        final parsed = jsonDecode(value);
        if (parsed is List) return parsed.map((e) => e.toString()).toList();
      } catch (_) {}
    }
    return [];
  }

  /// Count active projects by organization
  Future<int> countActiveProjectsByOrg(String orgId) async {
    try {
      final sql = "SELECT COUNT(*) as count FROM projects WHERE project_status != 'DISCONTINUED' AND project_status != 'COMPLETED' AND organization_id = @orgId::uuid";
      final result = await DatabaseConnection.queryOne(sql, values: {'orgId': orgId});
      final count = result?['count'];
      if (count is num) return count.toInt();
      return 0;
    } catch (e) {
      _logger.error('Error counting active projects by org: $e');
      return 0;
    }
  }
}
