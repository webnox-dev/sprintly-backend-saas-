import '../data/repositories/project_repository.dart';
import '../data/repositories/employee_repository.dart';
import '../data/repositories/admin_repository.dart';
import '../domain/models/project.dart';
import '../core/exceptions/app_exception.dart';
import '../core/utils/logger.dart';
import 'unified_notification_service.dart';
import 'email_service.dart';

/// Project service with comprehensive validation and business logic
class ProjectService {
  final ProjectRepository _repository = ProjectRepository();
  final EmployeeRepository _employeeRepository = EmployeeRepository();
  final AdminRepository _adminRepository = AdminRepository();
  final EmailService _emailService = EmailService();
  final AppLogger _logger = AppLogger('ProjectService');

  // ============================================
  // VALIDATION CONSTANTS
  // ============================================

  static const int maxProjectNameLength = 255;
  static const int maxDescriptionLength = 5000;
  static const int maxRequirementsCount = 100;
  static const int maxTeamMembersCount = 50;

  // ============================================
  // PUBLIC METHODS
  // ============================================

  /// Get all projects with pagination
  Future<Map<String, dynamic>> getAllProjects({
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
      // Validate pagination
      if (page < 1) page = 1;
      if (limit < 1) limit = 10;
      if (limit > 100) limit = 100;

      // Validate status filter if provided
      if (status != null &&
          status.isNotEmpty &&
          !ProjectStatus.isValid(status)) {
        throw ValidationException({
          'status': [
            'Invalid status. Valid values: ${ProjectStatus.values.join(', ')}',
          ],
        });
      }

      // Validate priority filter if provided
      if (priorityLevel != null &&
          priorityLevel.isNotEmpty &&
          !PriorityLevel.isValid(priorityLevel)) {
        throw ValidationException({
          'priority_level': [
            'Invalid priority. Valid values: ${PriorityLevel.values.join(', ')}',
          ],
        });
      }

      return await _repository.getAll(
        page: page,
        limit: limit,
        status: status,
        priorityLevel: priorityLevel,
        projectType: projectType,
        teamLeaderId: teamLeaderId,
        managerId: managerId,
        search: search,
        sortBy: sortBy,
        ascending: ascending,
        requestingEmployeeId: requestingEmployeeId,
        requestingRole: requestingRole,
      );
    } catch (e, stackTrace) {
      _logger.error('Error getting all projects: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Get project by ID (legacy - returns Project model)
  Future<Project> getProjectById(String projectId) async {
    try {
      _validateId(projectId, 'project_id');

      final project = await _repository.getById(projectId);
      if (project == null) {
        throw NotFoundException(resource: 'Project', id: projectId);
      }
      return project;
    } catch (e, stackTrace) {
      _logger.error('Error getting project by ID: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Get project by ID with rich details (full employee/admin data embedded)
  Future<Map<String, dynamic>> getProjectByIdRich(String projectId) async {
    try {
      _validateId(projectId, 'project_id');

      final project = await _repository.getByIdRich(projectId);
      if (project == null) {
        throw NotFoundException(resource: 'Project', id: projectId);
      }
      return project;
    } catch (e, stackTrace) {
      _logger.error('Error getting project by ID (rich): $e', e, stackTrace);
      rethrow;
    }
  }

  /// Create a new project with validation
  Future<Project> createProject(Map<String, dynamic> data) async {
    try {
      final errors = <String, List<String>>{};

      // Required field validation
      if (data['project_name'] == null ||
          data['project_name'].toString().trim().isEmpty) {
        errors['project_name'] = ['Project name is required'];
      } else {
        final name = data['project_name'].toString().trim();
        if (name.length > maxProjectNameLength) {
          errors['project_name'] = [
            'Project name cannot exceed $maxProjectNameLength characters',
          ];
        }
        data['project_name'] = name;
      }

      // Description validation
      if (data['project_description'] != null) {
        final desc = data['project_description'].toString().trim();
        if (desc.length > maxDescriptionLength) {
          errors['project_description'] = [
            'Description cannot exceed $maxDescriptionLength characters',
          ];
        }
        data['project_description'] = desc.isEmpty ? null : desc;
      }

      // Status validation
      if (data['project_status'] != null &&
          !ProjectStatus.isValid(data['project_status'])) {
        errors['project_status'] = [
          'Invalid status. Valid values: ${ProjectStatus.values.join(', ')}',
        ];
      }

      // Priority validation
      if (data['project_priority_level'] != null &&
          !PriorityLevel.isValid(data['project_priority_level'])) {
        errors['project_priority_level'] = [
          'Invalid priority. Valid values: ${PriorityLevel.values.join(', ')}',
        ];
      }

      // Date validation
      _validateDates(data, errors);

      // Requirements validation
      if (data['project_requirements'] != null) {
        final requirements = data['project_requirements'];
        if (requirements is List &&
            requirements.length > maxRequirementsCount) {
          errors['project_requirements'] = [
            'Cannot have more than $maxRequirementsCount requirements',
          ];
        }
      }

      // Team members validation
      if (data['project_team_member_ids'] != null) {
        final members = data['project_team_member_ids'];
        if (members is List && members.length > maxTeamMembersCount) {
          errors['project_team_member_ids'] = [
            'Cannot have more than $maxTeamMembersCount team members',
          ];
        }
      }

      // Sub-resource validation (Documents, Milestones, etc.)
      _validateDocuments(data['project_documents'], errors);
      _validateFigmaUrls(data['project_figma_urls'], errors);
      _validateMilestones(data['project_milestones'], errors);
      _validateReleases(data['project_releases'], errors);
      _validateClientReviews(data['project_client_reviews'], errors);

      // Validate foreign key references (project_manager_id, project_team_leader_id, team members)
      // Project Manager validation
      if (data['project_manager_id'] != null &&
          data['project_manager_id'].toString().trim().isNotEmpty) {
        final managerId = data['project_manager_id'].toString().trim();
        final managerExists = await _checkPersonExists(managerId);
        if (!managerExists) {
          errors['project_manager_id'] = [
            'Project manager with ID "$managerId" does not exist',
          ];
        }
      }

      // Team Leader validation
      if (data['project_team_leader_id'] != null &&
          data['project_team_leader_id'].toString().trim().isNotEmpty) {
        final teamLeaderId = data['project_team_leader_id'].toString().trim();
        final teamLeaderExists = await _checkPersonExists(teamLeaderId);
        if (!teamLeaderExists) {
          errors['project_team_leader_id'] = [
            'Team leader with ID "$teamLeaderId" does not exist',
          ];
        }
      }

      // Team Members validation
      if (data['project_team_member_ids'] != null) {
        final members = data['project_team_member_ids'];
        if (members is List && members.isNotEmpty) {
          final invalidMembers = <String>[];
          for (final memberId in members) {
            final memberIdStr = memberId.toString().trim();
            if (memberIdStr.isNotEmpty) {
              final memberExists = await _checkPersonExists(memberIdStr);
              if (!memberExists) {
                invalidMembers.add(memberIdStr);
              }
            }
          }
          if (invalidMembers.isNotEmpty) {
            errors['project_team_member_ids'] = [
              'The following team member IDs do not exist: ${invalidMembers.join(", ")}',
            ];
          }
        }
      }

      // BDE Employee IDs validation
      if (data['project_followed_by_bde_employee_ids'] != null) {
        final bdeIds = data['project_followed_by_bde_employee_ids'];
        if (bdeIds is List && bdeIds.isNotEmpty) {
          final invalidBdes = <String>[];
          for (final bdeId in bdeIds) {
            final bdeIdStr = bdeId.toString().trim();
            if (bdeIdStr.isNotEmpty) {
              final bdeExists = await _checkPersonExists(bdeIdStr);
              if (!bdeExists) {
                invalidBdes.add(bdeIdStr);
              }
            }
          }
          if (invalidBdes.isNotEmpty) {
            errors['project_followed_by_bde_employee_ids'] = [
              'The following BDE employee IDs do not exist: ${invalidBdes.join(", ")}',
            ];
          }
        }
      }

      if (errors.isNotEmpty) {
        throw ValidationException(errors);
      }

      // Set defaults
      data['project_status'] ??= ProjectStatus.notStarted;
      data['project_priority_level'] ??= PriorityLevel.medium;
      data['project_requirements'] ??= [];
      data['project_team_member_ids'] ??= [];
      data['project_followed_by_bde_employee_ids'] ??= [];

      final project = await _repository.create(data);

      // Send notifications for project creation in background - do not block response
      final teamMemberIds =
          (data['project_team_member_ids'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          [];
      final managerId = data['project_manager_id']?.toString();
      final teamLeaderId = data['project_team_leader_id']?.toString();
      final createdBy = data['created_by']?.toString() ?? 'system';
      final proj = project;

      Future(() async {
        try {
          await UnifiedNotificationService.notifyProjectCreated(
            projectId: proj.projectId ?? '',
            projectName: proj.projectName,
            teamMemberIds: teamMemberIds,
            projectManagerId: managerId,
            teamLeaderId: teamLeaderId,
            createdBy: createdBy,
          );
        } catch (e) {
          _logger.warning('Failed to send project creation notification: $e');
        }
        try {
          await _sendProjectCreatedEmails(proj, createdBy);
        } catch (e) {
          _logger.warning('Failed to send project creation emails: $e');
        }
      }).catchError((e, st) {
        _logger.warning('Project creation notifications error: $e');
      });

      return project;
    } catch (e, stackTrace) {
      _logger.error('Error creating project: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Update an existing project
  Future<Project> updateProject(
    String projectId,
    Map<String, dynamic> updates,
  ) async {
    try {
      _validateId(projectId, 'project_id');

      // Verify project exists
      final existing = await _repository.getById(projectId);
      if (existing == null) {
        throw NotFoundException(resource: 'Project', id: projectId);
      }

      final errors = <String, List<String>>{};

      // Validate name if being updated
      if (updates.containsKey('project_name')) {
        if (updates['project_name'] == null ||
            updates['project_name'].toString().trim().isEmpty) {
          errors['project_name'] = ['Project name cannot be empty'];
        } else {
          final name = updates['project_name'].toString().trim();
          if (name.length > maxProjectNameLength) {
            errors['project_name'] = [
              'Project name cannot exceed $maxProjectNameLength characters',
            ];
          }
          updates['project_name'] = name;
        }
      }

      // Validate description if being updated
      if (updates.containsKey('project_description') &&
          updates['project_description'] != null) {
        final desc = updates['project_description'].toString().trim();
        if (desc.length > maxDescriptionLength) {
          errors['project_description'] = [
            'Description cannot exceed $maxDescriptionLength characters',
          ];
        }
        updates['project_description'] = desc.isEmpty ? null : desc;
      }

      // Validate status if being updated
      if (updates.containsKey('project_status') &&
          updates['project_status'] != null &&
          !ProjectStatus.isValid(updates['project_status'])) {
        errors['project_status'] = [
          'Invalid status. Valid values: ${ProjectStatus.values.join(', ')}',
        ];
      }

      // Validate priority if being updated
      if (updates.containsKey('project_priority_level') &&
          updates['project_priority_level'] != null &&
          !PriorityLevel.isValid(updates['project_priority_level'])) {
        errors['project_priority_level'] = [
          'Invalid priority. Valid values: ${PriorityLevel.values.join(', ')}',
        ];
      }

      // Validate dates if being updated
      _validateDates(updates, errors, existingProject: existing);

      // Validate foreign key references if being updated
      // Project Manager validation
      if (updates.containsKey('project_manager_id') &&
          updates['project_manager_id'] != null &&
          updates['project_manager_id'].toString().trim().isNotEmpty) {
        final managerId = updates['project_manager_id'].toString().trim();
        final managerExists = await _checkPersonExists(managerId);
        if (!managerExists) {
          errors['project_manager_id'] = [
            'Project manager with ID "$managerId" does not exist',
          ];
        }
      }

      // Team Leader validation
      if (updates.containsKey('project_team_leader_id') &&
          updates['project_team_leader_id'] != null &&
          updates['project_team_leader_id'].toString().trim().isNotEmpty) {
        final teamLeaderId = updates['project_team_leader_id']
            .toString()
            .trim();
        final teamLeaderExists = await _checkPersonExists(teamLeaderId);
        if (!teamLeaderExists) {
          errors['project_team_leader_id'] = [
            'Team leader with ID "$teamLeaderId" does not exist',
          ];
        }
      }

      // Team Members validation
      if (updates.containsKey('project_team_member_ids') &&
          updates['project_team_member_ids'] != null) {
        final members = updates['project_team_member_ids'];
        if (members is List && members.isNotEmpty) {
          final invalidMembers = <String>[];
          for (final memberId in members) {
            final memberIdStr = memberId.toString().trim();
            if (memberIdStr.isNotEmpty) {
              final memberExists = await _checkPersonExists(memberIdStr);
              if (!memberExists) {
                invalidMembers.add(memberIdStr);
              }
            }
          }
          if (invalidMembers.isNotEmpty) {
            errors['project_team_member_ids'] = [
              'The following team member IDs do not exist: ${invalidMembers.join(", ")}',
            ];
          }
        }
      }

      // BDE Employee IDs validation
      if (updates.containsKey('project_followed_by_bde_employee_ids') &&
          updates['project_followed_by_bde_employee_ids'] != null) {
        final bdeIds = updates['project_followed_by_bde_employee_ids'];
        if (bdeIds is List && bdeIds.isNotEmpty) {
          final invalidBdes = <String>[];
          for (final bdeId in bdeIds) {
            final bdeIdStr = bdeId.toString().trim();
            if (bdeIdStr.isNotEmpty) {
              final bdeExists = await _checkPersonExists(bdeIdStr);
              if (!bdeExists) {
                invalidBdes.add(bdeIdStr);
              }
            }
          }
          if (invalidBdes.isNotEmpty) {
            errors['project_followed_by_bde_employee_ids'] = [
              'The following BDE employee IDs do not exist: ${invalidBdes.join(", ")}',
            ];
          }
        }
      }

      if (errors.isNotEmpty) {
        throw ValidationException(errors);
      }

      final updatedProject = await _repository.update(projectId, updates);

      // Send notifications for project update in background - do not block response
      final teamMemberIds = updatedProject.projectTeamMemberIds;
      final managerId = updatedProject.projectManagerId;
      final teamLeaderId = updatedProject.projectTeamLeaderId;
      final updatedBy = updates['updated_by']?.toString() ?? 'system';
      final proj = updatedProject;

      Future(() async {
        try {
          await UnifiedNotificationService.notifyProjectUpdated(
            projectId: proj.projectId ?? '',
            projectName: proj.projectName,
            teamMemberIds: teamMemberIds,
            projectManagerId: managerId,
            teamLeaderId: teamLeaderId,
            updatedBy: updatedBy,
          );
        } catch (e) {
          _logger.warning('Failed to send project update notification: $e');
        }
        try {
          await _sendProjectUpdatedEmails(proj, updatedBy);
        } catch (e) {
          _logger.warning('Failed to send project update emails: $e');
        }
      }).catchError((e, st) {
        _logger.warning('Project update notifications error: $e');
      });

      return updatedProject;
    } catch (e, stackTrace) {
      _logger.error('Error updating project: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Update project status with business rules
  Future<Project> updateProjectStatus(
    String projectId,
    String status,
    String updatedBy,
  ) async {
    try {
      _validateId(projectId, 'project_id');

      if (!ProjectStatus.isValid(status)) {
        throw ValidationException({
          'status': [
            'Invalid status. Valid values: ${ProjectStatus.values.join(', ')}',
          ],
        });
      }

      final existing = await _repository.getById(projectId);
      if (existing == null) {
        throw NotFoundException(resource: 'Project', id: projectId);
      }

      // Business rules for status transitions
      final currentStatus = existing.projectStatus;

      // Cannot transition from DISCONTINUED without reactivation
      if (currentStatus == ProjectStatus.discontinued &&
          status != ProjectStatus.discontinued) {
        throw ValidationException({
          'status': [
            'Discontinued projects must be reactivated first. Use the reactivation endpoint.',
          ],
        });
      }

      // Cannot transition to DISCONTINUED directly - must use discontinuation endpoint
      if (status == ProjectStatus.discontinued &&
          currentStatus != ProjectStatus.discontinued) {
        throw ValidationException({
          'status': [
            'Use the discontinuation endpoint to discontinue a project.',
          ],
        });
      }

      return await _repository.updateStatus(projectId, status, updatedBy);
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
      _validateId(projectId, 'project_id');
      _validateId(memberId, 'member_id');

      final project = await _repository.getById(projectId);
      if (project == null) {
        throw NotFoundException(resource: 'Project', id: projectId);
      }

      // Check if already a member
      if (project.projectTeamMemberIds.contains(memberId)) {
        throw ValidationException({
          'member_id': ['This employee is already a team member'],
        });
      }

      // Check team size limit
      if (project.projectTeamMemberIds.length >= maxTeamMembersCount) {
        throw ValidationException({
          'member_id': [
            'Cannot add more than $maxTeamMembersCount team members',
          ],
        });
      }

      // Check if member exists in employees or admins table
      final memberExists = await _checkPersonExists(memberId);
      if (!memberExists) {
        throw ValidationException({
          'member_id': ['Employee or admin with ID "$memberId" does not exist'],
        });
      }

      return await _repository.addTeamMember(projectId, memberId, updatedBy);
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
      _validateId(projectId, 'project_id');
      _validateId(memberId, 'member_id');

      final project = await _repository.getById(projectId);
      if (project == null) {
        throw NotFoundException(resource: 'Project', id: projectId);
      }

      if (!project.projectTeamMemberIds.contains(memberId)) {
        throw ValidationException({
          'member_id': ['This employee is not a team member'],
        });
      }

      return await _repository.removeTeamMember(projectId, memberId, updatedBy);
    } catch (e, stackTrace) {
      _logger.error('Error removing team member: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Get project statistics
  Future<Map<String, dynamic>> getStatistics() async {
    try {
      return await _repository.getStatistics();
    } catch (e, stackTrace) {
      _logger.error('Error getting statistics: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Delete project
  Future<void> deleteProject(String projectId) async {
    try {
      _validateId(projectId, 'project_id');

      final existing = await _repository.getById(projectId);
      if (existing == null) {
        throw NotFoundException(resource: 'Project', id: projectId);
      }

      // Get project details before deletion for notifications
      final teamMemberIds = existing.projectTeamMemberIds;
      final managerId = existing.projectManagerId;
      final teamLeaderId = existing.projectTeamLeaderId;
      final projectName = existing.projectName;

      await _repository.delete(projectId);

      // Send notifications for project deletion in background - do not block response
      Future(() async {
        try {
          await UnifiedNotificationService.notifyProjectDeleted(
            projectId: projectId,
            projectName: projectName,
            teamMemberIds: teamMemberIds,
            projectManagerId: managerId,
            teamLeaderId: teamLeaderId,
            deletedBy: 'system',
          );
        } catch (e) {
          _logger.warning('Failed to send project deletion notification: $e');
        }
        try {
          await _sendProjectDeletedEmails(existing, 'system');
        } catch (e) {
          _logger.warning('Failed to send project deletion emails: $e');
        }
      }).catchError((e, st) {
        _logger.warning('Project deletion notifications error: $e');
      });
    } catch (e, stackTrace) {
      _logger.error('Error deleting project: $e', e, stackTrace);
      rethrow;
    }
  }

  Future<void> _sendProjectCreatedEmails(
    Project project,
    String createdBy,
  ) async {
    final allIds = <String>{
      ...project.projectTeamMemberIds,
      if (project.projectManagerId != null &&
          project.projectManagerId!.isNotEmpty)
        project.projectManagerId!,
      if (project.projectTeamLeaderId != null &&
          project.projectTeamLeaderId!.isNotEmpty)
        project.projectTeamLeaderId!,
    };

    final managerId = project.projectManagerId;
    final teamLeaderId = project.projectTeamLeaderId;

    String managerName = 'N/A';
    String teamLeadName = 'N/A';

    if (managerId != null && managerId.isNotEmpty) {
      final details = await _getPersonNameAndEmail(managerId);
      managerName = details['name'] ?? 'Manager';
    }
    if (teamLeaderId != null && teamLeaderId.isNotEmpty) {
      final details = await _getPersonNameAndEmail(teamLeaderId);
      teamLeadName = details['name'] ?? 'Team Lead';
    }

    final projectName = project.projectName;
    final projectDescription = project.projectDescription ?? 'No description';
    final priorityLevel = project.projectPriorityLevel;
    final status = project.projectStatus;
    final startDate = project.projectStartDate ?? 'N/A';
    final endDate = project.projectEndDate ?? 'N/A';

    for (final id in allIds) {
      final details = await _getPersonNameAndEmail(id);
      final email = details['email'];
      final name = details['name'];

      if (email == null || email.isEmpty || name == null) continue;

      String role = 'Team Member';
      if (id == managerId) {
        role = 'Project Manager';
      } else if (id == teamLeaderId)
        role = 'Team Lead';

      await _emailService.sendProjectCreatedEmail(
        toEmail: email,
        recipientName: name,
        projectName: projectName,
        projectDescription: projectDescription,
        priorityLevel: priorityLevel,
        status: status,
        startDate: startDate,
        endDate: endDate,
        projectManager: managerName,
        teamLead: teamLeadName,
        createdBy: createdBy,
        recipientRole: role,
      );
    }
  }

  Future<void> _sendProjectUpdatedEmails(
    Project project,
    String updatedBy,
  ) async {
    final allIds = <String>{
      ...project.projectTeamMemberIds,
      if (project.projectManagerId != null &&
          project.projectManagerId!.isNotEmpty)
        project.projectManagerId!,
      if (project.projectTeamLeaderId != null &&
          project.projectTeamLeaderId!.isNotEmpty)
        project.projectTeamLeaderId!,
    };

    final managerId = project.projectManagerId;
    final teamLeaderId = project.projectTeamLeaderId;

    String managerName = 'N/A';
    String teamLeadName = 'N/A';

    if (managerId != null && managerId.isNotEmpty) {
      final details = await _getPersonNameAndEmail(managerId);
      managerName = details['name'] ?? 'Manager';
    }
    if (teamLeaderId != null && teamLeaderId.isNotEmpty) {
      final details = await _getPersonNameAndEmail(teamLeaderId);
      teamLeadName = details['name'] ?? 'Team Lead';
    }

    final projectName = project.projectName;
    final projectDescription = project.projectDescription ?? 'No description';
    final priorityLevel = project.projectPriorityLevel;
    final status = project.projectStatus;
    final startDate = project.projectStartDate ?? 'N/A';
    final endDate = project.projectEndDate ?? 'N/A';

    for (final id in allIds) {
      final details = await _getPersonNameAndEmail(id);
      final email = details['email'];
      final name = details['name'];

      if (email == null || email.isEmpty || name == null) continue;

      String role = 'Team Member';
      if (id == managerId) {
        role = 'Project Manager';
      } else if (id == teamLeaderId)
        role = 'Team Lead';

      await _emailService.sendProjectUpdatedEmail(
        toEmail: email,
        recipientName: name,
        projectName: projectName,
        projectDescription: projectDescription,
        priorityLevel: priorityLevel,
        status: status,
        startDate: startDate,
        endDate: endDate,
        projectManager: managerName,
        teamLead: teamLeadName,
        updatedBy: updatedBy,
        recipientRole: role,
      );
    }
  }

  Future<void> _sendProjectDeletedEmails(
    Project project,
    String deletedBy,
  ) async {
    final allIds = <String>{
      ...project.projectTeamMemberIds,
      if (project.projectManagerId != null &&
          project.projectManagerId!.isNotEmpty)
        project.projectManagerId!,
      if (project.projectTeamLeaderId != null &&
          project.projectTeamLeaderId!.isNotEmpty)
        project.projectTeamLeaderId!,
    };

    final projectName = project.projectName;

    for (final id in allIds) {
      final details = await _getPersonNameAndEmail(id);
      final email = details['email'];
      final name = details['name'];

      if (email == null || email.isEmpty || name == null) continue;

      await _emailService.sendProjectDeletedEmail(
        toEmail: email,
        recipientName: name,
        projectName: projectName,
        deletedBy: deletedBy,
      );
    }
  }

  // ============================================
  // PRIVATE VALIDATION METHODS
  // ============================================

  void _validateId(String id, String fieldName) {
    if (id.trim().isEmpty) {
      throw ValidationException({
        fieldName: ['$fieldName is required'],
      });
    }
  }

  void _validateDates(
    Map<String, dynamic> data,
    Map<String, List<String>> errors, {
    Project? existingProject,
  }) {
    DateTime? startDate;
    DateTime? endDate;
    DateTime? mvpDate;

    // Parse start date
    if (data['project_start_date'] != null) {
      startDate = DateTime.tryParse(data['project_start_date'].toString());
      if (startDate == null) {
        errors['project_start_date'] = ['Invalid date format. Use YYYY-MM-DD'];
      }
    } else if (existingProject != null &&
        existingProject.projectStartDate != null) {
      startDate = DateTime.tryParse(existingProject.projectStartDate!);
    }

    // Parse end date
    if (data['project_end_date'] != null) {
      endDate = DateTime.tryParse(data['project_end_date'].toString());
      if (endDate == null) {
        errors['project_end_date'] = ['Invalid date format. Use YYYY-MM-DD'];
      }
    } else if (existingProject != null &&
        existingProject.projectEndDate != null) {
      endDate = DateTime.tryParse(existingProject.projectEndDate!);
    }

    // Parse MVP date
    if (data['project_mvp_date'] != null) {
      mvpDate = DateTime.tryParse(data['project_mvp_date'].toString());
      if (mvpDate == null) {
        errors['project_mvp_date'] = ['Invalid date format. Use YYYY-MM-DD'];
      }
    } else if (existingProject != null &&
        existingProject.projectMvpDate != null) {
      mvpDate = DateTime.tryParse(existingProject.projectMvpDate!);
    }

    // Cross-field date validation
    if (startDate != null && endDate != null && endDate.isBefore(startDate)) {
      errors['project_end_date'] = ['End date cannot be before start date'];
    }

    if (startDate != null && mvpDate != null && mvpDate.isBefore(startDate)) {
      errors['project_mvp_date'] = ['MVP date cannot be before start date'];
    }

    if (mvpDate != null && endDate != null && mvpDate.isAfter(endDate)) {
      errors['project_mvp_date'] = ['MVP date cannot be after end date'];
    }
  }

  void _validateDocuments(dynamic documents, Map<String, List<String>> errors) {
    if (documents == null) return;
    if (documents is! List) {
      errors['project_documents'] = ['Documents must be an array'];
      return;
    }

    for (var i = 0; i < documents.length; i++) {
      final doc = documents[i];
      if (doc is! Map<String, dynamic>) continue;

      if (doc['document_name'] == null ||
          doc['document_name'].toString().trim().isEmpty) {
        errors['project_documents[$i].document_name'] = [
          'Document name is required',
        ];
      }
      if (doc['document_url'] == null ||
          doc['document_url'].toString().trim().isEmpty) {
        errors['project_documents[$i].document_url'] = [
          'Document URL is required',
        ];
      } else if (!_isValidUrl(doc['document_url'].toString())) {
        errors['project_documents[$i].document_url'] = ['Invalid URL format'];
      }
    }
  }

  void _validateFigmaUrls(dynamic figmaUrls, Map<String, List<String>> errors) {
    if (figmaUrls == null) return;
    if (figmaUrls is! List) {
      errors['project_figma_urls'] = ['Figma URLs must be an array'];
      return;
    }

    for (var i = 0; i < figmaUrls.length; i++) {
      final url = figmaUrls[i];
      if (url is! Map<String, dynamic>) continue;

      if (url['figma_url_name'] == null ||
          url['figma_url_name'].toString().trim().isEmpty) {
        errors['project_figma_urls[$i].figma_url_name'] = [
          'Figma URL name is required',
        ];
      }
      if (url['figma_url'] == null ||
          url['figma_url'].toString().trim().isEmpty) {
        errors['project_figma_urls[$i].figma_url'] = ['Figma URL is required'];
      } else if (!_isValidFigmaUrl(url['figma_url'].toString())) {
        errors['project_figma_urls[$i].figma_url'] = [
          'Invalid Figma URL. Must be a figma.com URL',
        ];
      }
    }
  }

  void _validateMilestones(
    dynamic milestones,
    Map<String, List<String>> errors,
  ) {
    if (milestones == null) return;
    if (milestones is! List) {
      errors['project_milestones'] = ['Milestones must be an array'];
      return;
    }

    for (var i = 0; i < milestones.length; i++) {
      final milestone = milestones[i];
      if (milestone is! Map<String, dynamic>) continue;

      if (milestone['project_milestone_title'] == null ||
          milestone['project_milestone_title'].toString().trim().isEmpty) {
        errors['project_milestones[$i].project_milestone_title'] = [
          'Milestone title is required',
        ];
      }
    }
  }

  void _validateReleases(dynamic releases, Map<String, List<String>> errors) {
    if (releases == null) return;
    if (releases is! List) {
      errors['project_releases'] = ['Releases must be an array'];
      return;
    }

    for (var i = 0; i < releases.length; i++) {
      final release = releases[i];
      if (release is! Map<String, dynamic>) continue;

      if (release['project_release_title'] == null ||
          release['project_release_title'].toString().trim().isEmpty) {
        errors['project_releases[$i].project_release_title'] = [
          'Release title is required',
        ];
      }

      // Validate release dates
      DateTime? plannedDate;
      DateTime? devCutoff;
      DateTime? qcCutoff;

      if (release['project_release_planned_date'] != null) {
        plannedDate = DateTime.tryParse(
          release['project_release_planned_date'].toString(),
        );
        if (plannedDate == null) {
          errors['project_releases[$i].project_release_planned_date'] = [
            'Invalid date format',
          ];
        }
      }

      if (release['project_release_dev_cutoff_date'] != null) {
        devCutoff = DateTime.tryParse(
          release['project_release_dev_cutoff_date'].toString(),
        );
        if (devCutoff == null) {
          errors['project_releases[$i].project_release_dev_cutoff_date'] = [
            'Invalid date format',
          ];
        }
      }

      if (release['project_release_qc_cutoff_date'] != null) {
        qcCutoff = DateTime.tryParse(
          release['project_release_qc_cutoff_date'].toString(),
        );
        if (qcCutoff == null) {
          errors['project_releases[$i].project_release_qc_cutoff_date'] = [
            'Invalid date format',
          ];
        }
      }

      // Cross-field validation: Dev Cutoff < QC Cutoff < Planned Date
      // Check: Dev Cutoff must be before QC Cutoff
      if (devCutoff != null &&
          qcCutoff != null &&
          !devCutoff.isBefore(qcCutoff)) {
        errors['project_releases[$i].project_release_dev_cutoff_date'] = [
          'Dev cutoff date must be before QC cutoff date',
        ];
      }

      // Check: QC Cutoff must be before Planned Date
      if (qcCutoff != null &&
          plannedDate != null &&
          !qcCutoff.isBefore(plannedDate)) {
        errors['project_releases[$i].project_release_qc_cutoff_date'] = [
          'QC cutoff date must be before planned release date',
        ];
      }

      // Check: Dev Cutoff must be before Planned Date
      if (devCutoff != null &&
          plannedDate != null &&
          !devCutoff.isBefore(plannedDate)) {
        // Only add if not already set by the first check
        errors['project_releases[$i].project_release_dev_cutoff_date'] ??= [
          'Dev cutoff date must be before planned release date',
        ];
      }
    }
  }

  void _validateClientReviews(
    dynamic reviews,
    Map<String, List<String>> errors,
  ) {
    if (reviews == null) return;
    if (reviews is! List) {
      errors['project_client_reviews'] = ['Client reviews must be an array'];
      return;
    }

    for (var i = 0; i < reviews.length; i++) {
      final review = reviews[i];
      if (review is! Map<String, dynamic>) continue;

      if (review['client_review_comment'] == null ||
          review['client_review_comment'].toString().trim().isEmpty) {
        errors['project_client_reviews[$i].client_review_comment'] = [
          'Review comment is required',
        ];
      }

      if (review['client_review_rating'] == null) {
        errors['project_client_reviews[$i].client_review_rating'] = [
          'Rating is required',
        ];
      } else {
        final rating = (review['client_review_rating'] as num?)?.toInt();
        if (rating == null || rating < 0 || rating > 5) {
          errors['project_client_reviews[$i].client_review_rating'] = [
            'Rating must be between 0 and 5',
          ];
        }
      }
    }
  }

  bool _isValidUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https');
    } catch (_) {
      return false;
    }
  }

  bool _isValidFigmaUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.hasScheme &&
          (uri.scheme == 'http' || uri.scheme == 'https') &&
          (uri.host.contains('figma.com') || uri.host.contains('figma.app'));
    } catch (_) {
      return false;
    }
  }

  /// Check if a person exists in either employees OR admins table
  /// This is used to validate that project_manager_id, project_team_leader_id,
  /// and team members exist before database insert.
  /// Since project managers/team leaders can be employees OR admins, we check both.
  Future<bool> _checkPersonExists(String personId) async {
    try {
      // First check in employees table
      final employeeExists = await _employeeRepository.existsById(personId);
      if (employeeExists) {
        _logger.info('Person "$personId" found in employees table');
        return true;
      }

      // Then check in admins table
      final admin = await _adminRepository.getById(personId);
      if (admin != null) {
        _logger.info('Person "$personId" found in admins table');
        return true;
      }

      _logger.info('Person "$personId" NOT found in employees or admins');
      return false;
    } catch (e) {
      _logger.error('Error checking person existence for ID "$personId": $e');
      return false;
    }
  }

  Future<Map<String, String?>> _getPersonNameAndEmail(String id) async {
    // Check Employee first
    final emp = await _employeeRepository.getById(id);
    if (emp != null) {
      final email = emp.employeeCompanyEmail.isNotEmpty
          ? emp.employeeCompanyEmail
          : emp.employeePersonalEmail;
      return {'name': emp.employeeName, 'email': email};
    }

    // Check Admin
    final admin = await _adminRepository.getById(id);
    if (admin != null) {
      final email = admin.adminCompanyEmail.isNotEmpty
          ? admin.adminCompanyEmail
          : admin.adminPersonalEmail;
      return {'name': admin.adminName, 'email': email};
    }

    return {'name': null, 'email': null};
  }
}
