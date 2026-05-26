/// SQL Query Builder for Task Cards
/// Centralizes all SQL queries with JOINs for employee and project details
class TaskCardQueryBuilder {
  /// Base SELECT clause with JOINs for employee and project details
  /// Includes team lead and project manager employee info
  static const String baseSelectWithJoins = '''
    SELECT 
      tc.*,
      json_build_object(
        'employee_id', e.employee_id,
        'employee_name', e.employee_name,
        'employee_personal_email', e.employee_personal_email,
        'employee_role', e.employee_role,
        'employee_img', e.employee_img
      ) as employee_details,
      json_build_object(
        'project_id', p.project_id,
        'project_name', p.project_name,
        'project_status', p.project_status,
        'client_name', p.client_name,
        'team_lead', json_build_object(
          'id', COALESCE(tl.employee_id, tl_admin.admin_id),
          'name', COALESCE(tl.employee_name, tl_admin.admin_name),
          'email', COALESCE(tl.employee_personal_email, tl_admin.admin_personal_email),
          'role', COALESCE(tl.employee_role, tl_admin.admin_role),
          'profile_image', COALESCE(tl.employee_img, tl_admin.admin_img)
        ),
        'project_manager', json_build_object(
          'id', COALESCE(pm.employee_id, pm_admin.admin_id),
          'name', COALESCE(pm.employee_name, pm_admin.admin_name),
          'email', COALESCE(pm.employee_personal_email, pm_admin.admin_personal_email),
          'role', COALESCE(pm.employee_role, pm_admin.admin_role),
          'profile_image', COALESCE(pm.employee_img, pm_admin.admin_img)
        ),
        'handled_by', (
          SELECT json_agg(json_build_object(
            'id', bde.employee_id,
            'name', bde.employee_name,
            'email', bde.employee_personal_email,
            'role', bde.employee_role,
            'profile_image', bde.employee_img
          ))
          FROM employees bde
          WHERE bde.employee_id IN (
            SELECT jsonb_array_elements_text(COALESCE(p.project_followed_by_bde_employee_ids, '[]'::jsonb))
          )
        )
      ) as project_details,
      json_build_object(
        'id', COALESCE(ab_admin.admin_id, ab_emp.employee_id),
        'name', COALESCE(ab_admin.admin_name, ab_emp.employee_name),
        'email', COALESCE(ab_admin.admin_personal_email, ab_emp.employee_personal_email),
        'role', COALESCE(ab_admin.admin_role, ab_emp.employee_role),
        'profile_image', COALESCE(ab_admin.admin_img, ab_emp.employee_img)
      ) as assigned_by,
      json_build_object(
        'id', COALESCE(rb_admin.admin_id, rb_emp.employee_id),
        'name', COALESCE(rb_admin.admin_name, rb_emp.employee_name),
        'email', COALESCE(rb_admin.admin_personal_email, rb_emp.employee_personal_email),
        'role', COALESCE(rb_admin.admin_role, rb_emp.employee_role),
        'profile_image', COALESCE(rb_admin.admin_img, rb_emp.employee_img)
      ) as reassigned_by_details,
      json_build_object(
        'id', COALESCE(ub_admin.admin_id, ub_emp.employee_id),
        'name', COALESCE(ub_admin.admin_name, ub_emp.employee_name),
        'email', COALESCE(ub_admin.admin_personal_email, ub_emp.employee_personal_email),
        'role', COALESCE(ub_admin.admin_role, ub_emp.employee_role),
        'profile_image', COALESCE(ub_admin.admin_img, ub_emp.employee_img)
      ) as updated_by_details,
      (
        SELECT json_agg(json_build_object(
          'id', ta.attachment_id,
          'url', ta.url,
          'name', ta.title,
          'type', ta.attachment_type,
          'created_by', ta.created_by,
          'created_at', ta.created_at
        ))
        FROM task_attachments ta
        WHERE ta.task_id = tc.task_id
      ) as fetched_attachments
    FROM task_cards tc
    LEFT JOIN employees e ON tc.employee_id = e.employee_id
    LEFT JOIN projects p ON tc.project_id = p.project_id
    LEFT JOIN employees tl ON p.project_team_leader_id = tl.employee_id
    LEFT JOIN admins tl_admin ON p.project_team_leader_id = tl_admin.admin_id
    LEFT JOIN employees pm ON p.project_manager_id = pm.employee_id
    LEFT JOIN admins pm_admin ON p.project_manager_id = pm_admin.admin_id
    LEFT JOIN admins ab_admin ON tc.created_by = ab_admin.admin_id
    LEFT JOIN employees ab_emp ON tc.created_by = ab_emp.employee_id
    LEFT JOIN admins rb_admin ON tc.reassigned_by = rb_admin.admin_id
    LEFT JOIN employees rb_emp ON tc.reassigned_by = rb_emp.employee_id
    LEFT JOIN admins ub_admin ON tc.updated_by = ub_admin.admin_id
    LEFT JOIN employees ub_emp ON tc.updated_by = ub_emp.employee_id
  ''';

  /// Get all task cards with filters and JOINs
  static String getAllTaskCardsQuery({
    required String whereClause,
    required String orderBy,
  }) {
    return '''
      $baseSelectWithJoins
      $whereClause
      $orderBy
      LIMIT @limit OFFSET @offset
    ''';
  }

  /// Get single task card by ID with JOINs
  static String getTaskCardByIdQuery() {
    return '''
      $baseSelectWithJoins
      WHERE tc.task_id = @id AND tc.is_deleted = FALSE
    ''';
  }

  /// Get task cards by employee ID with JOINs
  static String getTaskCardsByEmployeeIdQuery() {
    return '''
      $baseSelectWithJoins
      WHERE tc.employee_id = @employeeId AND tc.is_deleted = FALSE
      ORDER BY tc.created_at DESC
    ''';
  }

  /// Get task cards by project ID with JOINs
  static String getTaskCardsByProjectIdQuery() {
    return '''
      $baseSelectWithJoins
      WHERE tc.project_id = @projectId AND tc.is_deleted = FALSE
      ORDER BY tc.created_at DESC
    ''';
  }

  /// Search task cards across task name, employee name, project name
  static String searchTaskCardsQuery() {
    return '''
      $baseSelectWithJoins
      WHERE tc.is_deleted = FALSE
        AND (
          LOWER(tc.task_name) LIKE LOWER(@query)
          OR LOWER(e.employee_name) LIKE LOWER(@query)
          OR LOWER(p.project_name) LIKE LOWER(@query)
        )
      ORDER BY tc.created_at DESC
      LIMIT @limit
    ''';
  }

  /// Get task cards for a specific date (calendar view)
  static String getTaskCardsByDateQuery() {
    return '''
      $baseSelectWithJoins
      WHERE tc.is_deleted = FALSE
        AND (
          (tc.from_date <= @date AND tc.to_date >= @date)
          OR DATE(tc.from_date) = @date
          OR DATE(tc.to_date) = @date
        )
      ORDER BY tc.from_date ASC
    ''';
  }

  /// Get task count by status (for kanban headers)
  static String getTaskCountByStatusQuery() {
    return '''
      SELECT 
        workflow_status,
        COUNT(*) as count
      FROM task_cards
      WHERE is_deleted = FALSE
      GROUP BY workflow_status
    ''';
  }

  /// Count query for pagination
  static String getCountQuery(String whereClause) {
    return '''
      SELECT COUNT(*) as total 
      FROM task_cards tc
      LEFT JOIN employees e ON tc.employee_id = e.employee_id
      LEFT JOIN projects p ON tc.project_id = p.project_id
      $whereClause
    ''';
  }

  /// Build WHERE clause from filters
  static Map<String, dynamic> buildWhereClause({
    String? projectId,
    String? employeeId,
    String? workflowStatus,
    String? priorityLevel,
    String? search,
    String? employeeName,
    String? projectName,
    String? excludeWorkflowStatus,
    List<String>? workflowStatusIn,
    bool isDevStarted = false,
    String? excludeTaskId,
  }) {
    final conditions = <String>['tc.is_deleted = FALSE'];
    final params = <String, dynamic>{};

    if (projectId != null && projectId.isNotEmpty) {
      conditions.add('tc.project_id = @projectId');
      params['projectId'] = projectId;
    }

    if (employeeId != null && employeeId.isNotEmpty) {
      conditions.add('tc.employee_id = @employeeId');
      params['employeeId'] = employeeId;
    }

    if (workflowStatus != null && workflowStatus.isNotEmpty) {
      conditions.add('tc.workflow_status = @workflowStatus');
      params['workflowStatus'] = workflowStatus;
    }

    if (priorityLevel != null && priorityLevel.isNotEmpty) {
      conditions.add('tc.priority_level = @priorityLevel');
      params['priorityLevel'] = priorityLevel;
    }

    if (search != null && search.isNotEmpty) {
      conditions.add(
        '(LOWER(tc.task_name) LIKE LOWER(@search) OR LOWER(tc.task_description) LIKE LOWER(@search))',
      );
      params['search'] = '%$search%';
    }

    if (employeeName != null && employeeName.isNotEmpty) {
      conditions.add('LOWER(e.employee_name) LIKE LOWER(@employeeName)');
      params['employeeName'] = '%$employeeName%';
    }

    if (projectName != null && projectName.isNotEmpty) {
      conditions.add('LOWER(p.project_name) LIKE LOWER(@projectName)');
      params['projectName'] = '%$projectName%';
    }

    if (excludeWorkflowStatus != null && excludeWorkflowStatus.isNotEmpty) {
      conditions.add('tc.workflow_status != @excludeWorkflowStatus');
      params['excludeWorkflowStatus'] = excludeWorkflowStatus;
    }

    if (workflowStatusIn != null && workflowStatusIn.isNotEmpty) {
      // Create separate params for each status to avoid SQL injection
      final statusConditions = <String>[];
      for (var i = 0; i < workflowStatusIn.length; i++) {
        final paramName = 'statusIn$i';
        statusConditions.add('tc.workflow_status = @$paramName');
        params[paramName] = workflowStatusIn[i];
      }
      conditions.add('(${statusConditions.join(' OR ')})');
    }

    if (isDevStarted) {
      // Logic for started tasks: In Progress OR dev_started_at is not null
      // We use OR logic here because a task might be 'Done' but we want to see it if we are looking for "started" tasks history?
      // Or typically "Started Tasks" view means currently active?
      // Based on TaskViewModel legacy logic: .or('workflow_status.eq.In Progress,dev_started_at.not.is.null')
      conditions.add(
        '(tc.workflow_status = \'In Progress\' OR tc.dev_started_at IS NOT NULL)',
      );
    }

    if (excludeTaskId != null && excludeTaskId.isNotEmpty) {
      conditions.add('tc.task_id != @excludeTaskId');
      params['excludeTaskId'] = excludeTaskId;
    }

    final whereClause = conditions.isNotEmpty
        ? 'WHERE ${conditions.join(' AND ')}'
        : '';

    return {'whereClause': whereClause, 'params': params};
  }

  /// Build ORDER BY clause
  static String buildOrderBy({String? sortBy, bool ascending = false}) {
    if (sortBy != null && sortBy.isNotEmpty) {
      return 'ORDER BY tc.$sortBy ${ascending ? 'ASC' : 'DESC'}';
    }
    return 'ORDER BY tc.created_at DESC';
  }
}
