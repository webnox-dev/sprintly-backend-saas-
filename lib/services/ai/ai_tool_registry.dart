import 'llm_provider.dart';

/// Registry of all tools/functions available to the LLM
/// Each tool maps to an existing service method in the backend
class AiToolRegistry {
  /// Get all tool definitions for the LLM
  static List<ToolDefinition> getAllTools() {
    return [
      // =============================================
      // CHAT & CONVERSATIONS (SYNC BOARD)
      // =============================================
      ToolDefinition(
        name: 'get_chat_conversations',
        description:
            'Get a list of all chat conversations for the current user. Use this to find conversation IDs for specific groups or people.',
        parameters: [],
      ),
      ToolDefinition(
        name: 'get_conversation_messages',
        description:
            'Get recent messages from a specific chat conversation. Use this to summarize discussions, find blockers, or catch up on what you missed.',
        parameters: [
          ToolParameter(
            name: 'conversation_id',
            type: 'string',
            description: 'The unique ID of the conversation.',
            required: true,
          ),
          ToolParameter(
            name: 'limit',
            type: 'string',
            description: 'Number of messages to retrieve. Defaults to 50.',
          ),
        ],
      ),

      // =============================================
      // EMPLOYEE OVERVIEW & INFORMATION
      // =============================================
      ToolDefinition(
        name: 'get_employee_overview_today',
        description:
            'Get today\'s employee overview including total employees, present count, absent count, on leave, WFH, on permission, and late arrivals. Use this when HR asks about today\'s workforce status.',
        parameters: [
          ToolParameter(
            name: 'date',
            type: 'string',
            description:
                'Optional date in YYYY-MM-DD format. Defaults to today.',
          ),
        ],
      ),
      ToolDefinition(
        name: 'get_all_employees',
        description:
            'Get list of all employees with optional filters. Use when HR asks for employee lists, searches for specific employees, or wants employee details.',
        parameters: [
          ToolParameter(
            name: 'search',
            type: 'string',
            description: 'Search by employee name, email, or ID.',
          ),
          ToolParameter(
            name: 'status',
            type: 'string',
            description: 'Filter by active status: "true" or "false".',
            enumValues: ['true', 'false'],
          ),
          ToolParameter(
            name: 'role',
            type: 'string',
            description: 'Filter by employee role.',
          ),
          ToolParameter(
            name: 'designation',
            type: 'string',
            description: 'Filter by designation.',
          ),
          ToolParameter(
            name: 'page',
            type: 'string',
            description: 'Page number for pagination. Defaults to 1.',
          ),
          ToolParameter(
            name: 'limit',
            type: 'string',
            description: 'Number of records per page. Defaults to 20.',
          ),
        ],
      ),
      ToolDefinition(
        name: 'get_employee_by_id',
        description:
            'Get detailed information about a specific employee by their ID.',
        parameters: [
          ToolParameter(
            name: 'employee_id',
            type: 'string',
            description: 'The employee ID.',
            required: true,
          ),
        ],
      ),
      ToolDefinition(
        name: 'get_present_employees',
        description:
            'Get list of employees who are present today (have punched in). Use when HR asks "who is present today?" or "who has come to office?".',
        parameters: [
          ToolParameter(
            name: 'date',
            type: 'string',
            description:
                'Optional date in YYYY-MM-DD format. Defaults to today.',
          ),
        ],
      ),
      ToolDefinition(
        name: 'get_absent_employees',
        description:
            'Get list of employees who are absent today (not present, not on leave, not on WFH). Use when HR asks "who is absent today?".',
        parameters: [
          ToolParameter(
            name: 'date',
            type: 'string',
            description:
                'Optional date in YYYY-MM-DD format. Defaults to today.',
          ),
        ],
      ),
      ToolDefinition(
        name: 'get_wfh_employees',
        description:
            'Get list of employees working from home today. Use when HR asks "who is on WFH?" or "who is working from home?".',
        parameters: [
          ToolParameter(
            name: 'date',
            type: 'string',
            description:
                'Optional date in YYYY-MM-DD format. Defaults to today.',
          ),
        ],
      ),
      ToolDefinition(
        name: 'get_permission_employees',
        description:
            'Get list of employees who are on permission today. Use when HR asks "who has permission today?" or "who is on permission?".',
        parameters: [
          ToolParameter(
            name: 'date',
            type: 'string',
            description:
                'Optional date in YYYY-MM-DD format. Defaults to today.',
          ),
        ],
      ),
      ToolDefinition(
        name: 'get_late_employees',
        description:
            'Get list of employees who arrived late. Use when HR asks "who came late?" or "late arrivals".',
        parameters: [
          ToolParameter(
            name: 'date',
            type: 'string',
            description:
                'Optional date in YYYY-MM-DD format. Defaults to today.',
          ),
        ],
      ),

      // =============================================
      // LEAVE MANAGEMENT (READ + ACTIONS)
      // =============================================
      ToolDefinition(
        name: 'submit_leave_request',
        description: 'Submit a new leave request for an employee.',
        parameters: [
          ToolParameter(
            name: 'employee_id',
            type: 'string',
            description: 'The employee ID.',
            required: true,
          ),
          ToolParameter(
            name: 'from_date',
            type: 'string',
            description: 'Start date in YYYY-MM-DD.',
            required: true,
          ),
          ToolParameter(
            name: 'to_date',
            type: 'string',
            description: 'End date in YYYY-MM-DD.',
            required: true,
          ),
          ToolParameter(
            name: 'reason',
            type: 'string',
            description: 'Reason for leave.',
            required: true,
          ),
          ToolParameter(
            name: 'leave_type',
            type: 'string',
            description: 'Casual Leave, Sick Leave, etc.',
          ),
        ],
      ),
      ToolDefinition(
        name: 'get_all_leaves',
        description:
            'Get all leave requests with filters. Use when HR wants to see leave records, people on leave, or leave history.',
        parameters: [
          ToolParameter(
            name: 'status',
            type: 'string',
            description:
                'Filter by status: "0" = Pending, "1" = Approved, "2" = Rejected.',
            enumValues: ['0', '1', '2'],
          ),
          ToolParameter(
            name: 'employee_id',
            type: 'string',
            description: 'Filter by employee ID.',
          ),
          ToolParameter(
            name: 'from_date',
            type: 'string',
            description: 'Start date filter in YYYY-MM-DD format.',
          ),
          ToolParameter(
            name: 'to_date',
            type: 'string',
            description: 'End date filter in YYYY-MM-DD format.',
          ),
          ToolParameter(
            name: 'page',
            type: 'string',
            description: 'Page number for pagination.',
          ),
          ToolParameter(
            name: 'limit',
            type: 'string',
            description: 'Records per page.',
          ),
        ],
      ),
      ToolDefinition(
        name: 'get_pending_leaves',
        description:
            'Get all pending leave requests waiting for admin approval. Use when HR asks "any pending leaves?" or "leaves to approve".',
        parameters: [],
      ),
      ToolDefinition(
        name: 'approve_leave_request',
        description:
            'Approve a pending leave request by its ID. Use when HR says "approve leave for X" or "grant leave". IMPORTANT: Always confirm with HR before approving.',
        parameters: [
          ToolParameter(
            name: 'leave_id',
            type: 'string',
            description: 'The leave request ID to approve.',
            required: true,
          ),
          ToolParameter(
            name: 'approved_by',
            type: 'string',
            description: 'ID of the admin who is approving.',
            required: true,
          ),
          ToolParameter(
            name: 'remarks',
            type: 'string',
            description: 'Optional approval remarks.',
          ),
        ],
      ),
      ToolDefinition(
        name: 'reject_leave_request',
        description:
            'Reject a pending leave request by its ID. Use when HR says "reject leave for X" or "deny leave". IMPORTANT: Always confirm with HR before rejecting.',
        parameters: [
          ToolParameter(
            name: 'leave_id',
            type: 'string',
            description: 'The leave request ID to reject.',
            required: true,
          ),
          ToolParameter(
            name: 'rejected_by',
            type: 'string',
            description: 'ID of the admin who is rejecting.',
            required: true,
          ),
          ToolParameter(
            name: 'remarks',
            type: 'string',
            description: 'Reason for rejection.',
          ),
        ],
      ),

      // =============================================
      // PERMISSION MANAGEMENT (READ + ACTIONS)
      // =============================================
      ToolDefinition(
        name: 'get_all_permissions',
        description:
            'Get all permission requests with filters. Use when HR wants to see permission records or history.',
        parameters: [
          ToolParameter(
            name: 'status',
            type: 'string',
            description:
                'Filter by status: "0" = Pending, "1" = Approved, "2" = Rejected.',
            enumValues: ['0', '1', '2'],
          ),
          ToolParameter(
            name: 'employee_id',
            type: 'string',
            description: 'Filter by employee ID.',
          ),
          ToolParameter(
            name: 'from_date',
            type: 'string',
            description: 'Start date filter in YYYY-MM-DD format.',
          ),
          ToolParameter(
            name: 'to_date',
            type: 'string',
            description: 'End date filter in YYYY-MM-DD format.',
          ),
        ],
      ),
      ToolDefinition(
        name: 'submit_permission_request',
        description:
            'Submit a new permission request (short leave) for an employee. Use when user says "I need permission" for a few hours.',
        parameters: [
          ToolParameter(
            name: 'employee_id',
            type: 'string',
            description: 'The employee ID.',
            required: true,
          ),
          ToolParameter(
            name: 'date',
            type: 'string',
            description: 'Date in YYYY-MM-DD format.',
            required: true,
          ),
          ToolParameter(
            name: 'from_time',
            type: 'string',
            description: 'Start time in HH:MM format (24h).',
            required: true,
          ),
          ToolParameter(
            name: 'to_time',
            type: 'string',
            description: 'End time in HH:MM format (24h).',
            required: true,
          ),
          ToolParameter(
            name: 'reason',
            type: 'string',
            description: 'Reason for permission.',
            required: true,
          ),
        ],
      ),
      ToolDefinition(
        name: 'get_pending_permissions',
        description: 'Get all pending permission requests awaiting approval.',
        parameters: [],
      ),
      ToolDefinition(
        name: 'approve_permission_request',
        description:
            'Approve a pending permission request. IMPORTANT: Always confirm with HR.',
        parameters: [
          ToolParameter(
            name: 'permission_id',
            type: 'string',
            description: 'The permission request ID to approve.',
            required: true,
          ),
          ToolParameter(
            name: 'approved_by',
            type: 'string',
            description: 'ID of the admin who is approving.',
            required: true,
          ),
          ToolParameter(
            name: 'remarks',
            type: 'string',
            description: 'Optional approval remarks.',
          ),
        ],
      ),
      ToolDefinition(
        name: 'reject_permission_request',
        description:
            'Reject a pending permission request. IMPORTANT: Always confirm with HR.',
        parameters: [
          ToolParameter(
            name: 'permission_id',
            type: 'string',
            description: 'The permission request ID to reject.',
            required: true,
          ),
          ToolParameter(
            name: 'rejected_by',
            type: 'string',
            description: 'ID of the admin who is rejecting.',
            required: true,
          ),
          ToolParameter(
            name: 'remarks',
            type: 'string',
            description: 'Reason for rejection.',
          ),
        ],
      ),

      // =============================================
      // WFH MANAGEMENT (READ + ACTIONS)
      // =============================================
      ToolDefinition(
        name: 'submit_wfh_request',
        description: 'Submit a new Work From Home (WFH) request.',
        parameters: [
          ToolParameter(
            name: 'employee_id',
            type: 'string',
            description: 'The employee ID.',
            required: true,
          ),
          ToolParameter(
            name: 'from_date',
            type: 'string',
            description: 'Start date in YYYY-MM-DD format.',
            required: true,
          ),
          ToolParameter(
            name: 'to_date',
            type: 'string',
            description: 'End date in YYYY-MM-DD format.',
            required: true,
          ),
          ToolParameter(
            name: 'reason',
            type: 'string',
            description: 'Reason for WFH.',
            required: true,
          ),
        ],
      ),
      ToolDefinition(
        name: 'get_all_wfh_requests',
        description: 'Get all Work From Home requests with filters.',
        parameters: [
          ToolParameter(
            name: 'status',
            type: 'string',
            description:
                'Filter by status: "0" = Pending, "1" = Approved, "2" = Rejected.',
            enumValues: ['0', '1', '2'],
          ),
          ToolParameter(
            name: 'requester_id',
            type: 'string',
            description: 'Filter by employee/requester ID.',
          ),
          ToolParameter(
            name: 'from_date',
            type: 'string',
            description: 'Start date filter in YYYY-MM-DD format.',
          ),
          ToolParameter(
            name: 'to_date',
            type: 'string',
            description: 'End date filter in YYYY-MM-DD format.',
          ),
        ],
      ),
      ToolDefinition(
        name: 'approve_reject_wfh_request',
        description:
            'Approve or reject a WFH request. IMPORTANT: Always confirm with HR.',
        parameters: [
          ToolParameter(
            name: 'wfh_id',
            type: 'string',
            description: 'The WFH request ID.',
            required: true,
          ),
          ToolParameter(
            name: 'approve',
            type: 'string',
            description: '"true" to approve, "false" to reject.',
            required: true,
            enumValues: ['true', 'false'],
          ),
          ToolParameter(
            name: 'action_by',
            type: 'string',
            description: 'ID of the admin taking action.',
            required: true,
          ),
          ToolParameter(
            name: 'remarks',
            type: 'string',
            description: 'Optional remarks.',
          ),
        ],
      ),

      // =============================================
      // ATTENDANCE
      // =============================================
      ToolDefinition(
        name: 'get_today_attendance',
        description:
            'Get today\'s attendance summary for all employees. Shows who punched in/out and work hours.',
        parameters: [],
      ),
      ToolDefinition(
        name: 'get_employee_attendance',
        description:
            'Get attendance records for a specific employee within a date range.',
        parameters: [
          ToolParameter(
            name: 'employee_id',
            type: 'string',
            description: 'The employee ID.',
            required: true,
          ),
          ToolParameter(
            name: 'from_date',
            type: 'string',
            description: 'Start date in YYYY-MM-DD format.',
            required: true,
          ),
          ToolParameter(
            name: 'to_date',
            type: 'string',
            description: 'End date in YYYY-MM-DD format.',
            required: true,
          ),
        ],
      ),

      // =============================================
      // TASK CARDS
      // =============================================
      ToolDefinition(
        name: 'get_all_task_cards',
        description:
            'Get all task cards with filters. Use when HR asks about tasks, task status, or assignments.',
        parameters: [
          ToolParameter(
            name: 'project_id',
            type: 'string',
            description: 'Filter by project ID.',
          ),
          ToolParameter(
            name: 'employee_id',
            type: 'string',
            description: 'Filter by assigned employee ID.',
          ),
          ToolParameter(
            name: 'workflow_status',
            type: 'string',
            description:
                'Filter by status: backlog, todo, in_progress, dev_completed, in_review, completed, cancelled.',
            enumValues: [
              'backlog',
              'todo',
              'in_progress',
              'dev_completed',
              'in_review',
              'completed',
              'cancelled',
            ],
          ),
          ToolParameter(
            name: 'priority_level',
            type: 'string',
            description: 'Filter by priority: low, medium, high, critical.',
            enumValues: ['low', 'medium', 'high', 'critical'],
          ),
          ToolParameter(
            name: 'search',
            type: 'string',
            description: 'Search in task title or description.',
          ),
          ToolParameter(
            name: 'page',
            type: 'string',
            description: 'Page number for pagination.',
          ),
          ToolParameter(
            name: 'limit',
            type: 'string',
            description: 'Records per page.',
          ),
        ],
      ),
      ToolDefinition(
        name: 'get_delayed_task_cards',
        description:
            'Get task cards that are delayed/overdue. Use when HR asks about overdue tasks or delayed work.',
        parameters: [],
      ),

      // =============================================
      // TASK CARD REQUESTS (READ + ACTIONS)
      // =============================================
      ToolDefinition(
        name: 'get_all_task_card_requests',
        description:
            'Get all task card requests (employee-raised task requests). Filter by status, employee, project.',
        parameters: [
          ToolParameter(
            name: 'status',
            type: 'string',
            description: 'Filter by status: pending, approved, rejected.',
            enumValues: ['pending', 'approved', 'rejected'],
          ),
          ToolParameter(
            name: 'employee_id',
            type: 'string',
            description: 'Filter by employee ID.',
          ),
          ToolParameter(
            name: 'project_id',
            type: 'string',
            description: 'Filter by project ID.',
          ),
          ToolParameter(
            name: 'search',
            type: 'string',
            description: 'Search in task card request details.',
          ),
        ],
      ),
      ToolDefinition(
        name: 'approve_task_card_request',
        description:
            'Approve a pending task card request. This creates the actual task card. IMPORTANT: Always confirm with HR.',
        parameters: [
          ToolParameter(
            name: 'request_id',
            type: 'string',
            description: 'The task card request ID.',
            required: true,
          ),
          ToolParameter(
            name: 'approved_by',
            type: 'string',
            description: 'ID of the admin approving.',
            required: true,
          ),
          ToolParameter(
            name: 'remarks',
            type: 'string',
            description: 'Optional approval remarks.',
          ),
        ],
      ),
      ToolDefinition(
        name: 'reject_task_card_request',
        description:
            'Reject a pending task card request. IMPORTANT: Always confirm with HR.',
        parameters: [
          ToolParameter(
            name: 'request_id',
            type: 'string',
            description: 'The task card request ID.',
            required: true,
          ),
          ToolParameter(
            name: 'rejected_by',
            type: 'string',
            description: 'ID of the admin rejecting.',
            required: true,
          ),
          ToolParameter(
            name: 'reason',
            type: 'string',
            description: 'Reason for rejection.',
            required: true,
          ),
        ],
      ),
      ToolDefinition(
        name: 'submit_task_card_request',
        description: 'Submit a new task card request for approval.',
        parameters: [
          ToolParameter(
            name: 'employee_id',
            type: 'string',
            description: 'The employee ID.',
            required: true,
          ),
          ToolParameter(
            name: 'project_id',
            type: 'string',
            description: 'The project ID.',
            required: true,
          ),
          ToolParameter(
            name: 'task_name',
            type: 'string',
            description: 'Title of the task.',
            required: true,
          ),
          ToolParameter(
            name: 'task_description',
            type: 'string',
            description: 'Detailed description of the task.',
            required: true,
          ),
          ToolParameter(
            name: 'task_type',
            type: 'string',
            description: 'Type of task (e.g., Development, Meeting, KT).',
            required: true,
          ),
          ToolParameter(
            name: 'priority_level',
            type: 'string',
            description: 'Priority: low, medium, high, critical.',
            enumValues: ['low', 'medium', 'high', 'critical'],
          ),
          ToolParameter(
            name: 'from_date',
            type: 'string',
            description: 'Start date (YYYY-MM-DD).',
            required: true,
          ),
          ToolParameter(
            name: 'to_date',
            type: 'string',
            description: 'End date (YYYY-MM-DD).',
            required: true,
          ),
          ToolParameter(
            name: 'task_duration',
            type: 'string',
            description: 'Estimated duration (e.g., 2 hours, 1 day).',
          ),
        ],
      ),

      // =============================================
      // PROJECTS
      // =============================================
      ToolDefinition(
        name: 'get_all_projects',
        description:
            'Get all projects with filters. Use when HR asks about project status, team assignments, or project details.',
        parameters: [
          ToolParameter(
            name: 'status',
            type: 'string',
            description:
                'Filter by project status: active, completed, on_hold, cancelled.',
          ),
          ToolParameter(
            name: 'search',
            type: 'string',
            description: 'Search by project name.',
          ),
          ToolParameter(
            name: 'priority_level',
            type: 'string',
            description: 'Filter by priority level.',
          ),
        ],
      ),
      ToolDefinition(
        name: 'get_project_statistics',
        description: 'Get project statistics - total projects, by status, etc.',
        parameters: [],
      ),

      // =============================================
      // DASHBOARD & HOME
      // =============================================
      ToolDefinition(
        name: 'get_dashboard_calendar_events',
        description:
            'Get calendar events for a specific date including leaves, WFH, tasks, holidays, permissions.',
        parameters: [
          ToolParameter(
            name: 'date',
            type: 'string',
            description: 'Date in YYYY-MM-DD format.',
            required: true,
          ),
        ],
      ),
      ToolDefinition(
        name: 'get_dashboard_task_analytics',
        description:
            'Get task analytics for charts including status breakdown, priority distribution.',
        parameters: [],
      ),
      ToolDefinition(
        name: 'get_home_overview',
        description:
            'Get home overview with task stats, chart data, and birthdays for a specific month.',
        parameters: [
          ToolParameter(
            name: 'month',
            type: 'string',
            description: 'Month number (1-12).',
            required: true,
          ),
          ToolParameter(
            name: 'year',
            type: 'string',
            description: 'Year (e.g., 2026).',
            required: true,
          ),
        ],
      ),

      // =============================================
      // ANNOUNCEMENTS
      // =============================================
      ToolDefinition(
        name: 'get_all_announcements',
        description:
            'Get all announcements. Use when HR asks about company announcements.',
        parameters: [
          ToolParameter(
            name: 'search',
            type: 'string',
            description: 'Search in announcement title or content.',
          ),
          ToolParameter(
            name: 'is_active',
            type: 'string',
            description: '"true" for active, "false" for inactive.',
            enumValues: ['true', 'false'],
          ),
        ],
      ),

      // =============================================
      // COMPANY HOLIDAYS
      // =============================================
      ToolDefinition(
        name: 'get_company_holidays',
        description:
            'Get company holidays. Use when HR asks about upcoming holidays or holiday calendar.',
        parameters: [
          ToolParameter(
            name: 'search',
            type: 'string',
            description: 'Search holiday name.',
          ),
        ],
      ),

      // =============================================
      // EMPLOYEE PERFORMANCE
      // =============================================
      ToolDefinition(
        name: 'get_employee_performance_summary',
        description:
            'Get performance summary for all employees within a date range. Shows worked hours, leave days, late count, etc.',
        parameters: [
          ToolParameter(
            name: 'from_date',
            type: 'string',
            description: 'Start date in YYYY-MM-DD format.',
            required: true,
          ),
          ToolParameter(
            name: 'to_date',
            type: 'string',
            description: 'End date in YYYY-MM-DD format.',
            required: true,
          ),
          ToolParameter(
            name: 'search',
            type: 'string',
            description: 'Search by employee name.',
          ),
        ],
      ),
      ToolDefinition(
        name: 'get_employee_performance_report',
        description:
            'Get detailed performance report for a specific employee including daily breakdown.',
        parameters: [
          ToolParameter(
            name: 'employee_id',
            type: 'string',
            description: 'The employee ID.',
            required: true,
          ),
          ToolParameter(
            name: 'from_date',
            type: 'string',
            description: 'Start date in YYYY-MM-DD format.',
            required: true,
          ),
          ToolParameter(
            name: 'to_date',
            type: 'string',
            description: 'End date in YYYY-MM-DD format.',
            required: true,
          ),
        ],
      ),

      // =============================================
      // LEAVE STATISTICS
      // =============================================
      ToolDefinition(
        name: 'get_employee_leave_statistics',
        description:
            'Get leave statistics for a specific employee. Shows total leaves, used, remaining, etc.',
        parameters: [
          ToolParameter(
            name: 'employee_id',
            type: 'string',
            description: 'The employee ID.',
            required: true,
          ),
        ],
      ),

      // =============================================
      // ASSETS
      // =============================================
      ToolDefinition(
        name: 'get_all_assets',
        description:
            'Get all company assets (laptops, phones, etc.) with filters.',
        parameters: [
          ToolParameter(
            name: 'search',
            type: 'string',
            description: 'Search asset name or serial number.',
          ),
          ToolParameter(
            name: 'asset_type',
            type: 'string',
            description: 'Filter by asset type.',
          ),
          ToolParameter(
            name: 'asset_status',
            type: 'string',
            description: 'Filter by status.',
          ),
        ],
      ),

      // =============================================
      // EXPENSES
      // =============================================
      ToolDefinition(
        name: 'get_all_expenses',
        description: 'Get all company expenses with filters.',
        parameters: [
          ToolParameter(
            name: 'search',
            type: 'string',
            description: 'Search expense description.',
          ),
          ToolParameter(
            name: 'expense_type',
            type: 'string',
            description: 'Filter by expense type.',
          ),
        ],
      ),

      // =============================================
      // TODOS
      // =============================================
      ToolDefinition(
        name: 'get_all_todos',
        description:
            'Get admin todos/tasks. Use when HR asks about their personal to-do list.',
        parameters: [
          ToolParameter(
            name: 'status',
            type: 'string',
            description: 'Filter by status: pending, in_progress, completed.',
            enumValues: ['pending', 'in_progress', 'completed'],
          ),
          ToolParameter(
            name: 'priority',
            type: 'string',
            description: 'Filter by priority: low, medium, high.',
            enumValues: ['low', 'medium', 'high'],
          ),
        ],
      ),

      // =============================================
      // BIRTHDAYS & CELEBRATIONS
      // =============================================
      ToolDefinition(
        name: 'get_birthdays_this_month',
        description:
            'Get employee birthdays for a specific month. Use when HR asks "any birthdays this month?" or "upcoming birthdays".',
        parameters: [
          ToolParameter(
            name: 'month',
            type: 'string',
            description: 'Month number (1-12). Defaults to current month.',
          ),
        ],
      ),

      // =============================================
      // EMPLOYEE TRACKER (ADVANCED)
      // =============================================
      ToolDefinition(
        name: 'get_employee_tracker_list',
        description:
            'Get all employees with their daily status (Present, Absent, Leave, WFH, Permission) for a specific date. This is the main list for the Employee Tracker screen.',
        parameters: [
          ToolParameter(
            name: 'date',
            type: 'string',
            description: 'Date in YYYY-MM-DD format. Required.',
            required: true,
          ),
          ToolParameter(
            name: 'search',
            type: 'string',
            description: 'Search by employee name or ID.',
          ),
          ToolParameter(
            name: 'status_filter',
            type: 'string',
            description:
                'Filter by status: "present", "absent", "leave", "wfh", "permission".',
          ),
        ],
      ),
      ToolDefinition(
        name: 'get_employee_tracker_detail',
        description:
            'Get detailed activity timeline for a specific employee on a specific date. Shows punch in/out, breaks, and task logs.',
        parameters: [
          ToolParameter(
            name: 'employee_id',
            type: 'string',
            description: 'The employee ID.',
            required: true,
          ),
          ToolParameter(
            name: 'date',
            type: 'string',
            description: 'Date in YYYY-MM-DD format.',
            required: true,
          ),
        ],
      ),

      // =============================================
      // EMPLOYEE OF THE MONTH (EOM)
      // =============================================
      ToolDefinition(
        name: 'get_employee_rankings',
        description:
            'Get Employee of the Month rankings and leaderboard for a specific month.',
        parameters: [
          ToolParameter(
            name: 'month',
            type: 'string',
            description: 'Month number (1-12).',
            required: true,
          ),
          ToolParameter(
            name: 'year',
            type: 'string',
            description: 'Year (e.g., 2026).',
            required: true,
          ),
          ToolParameter(
            name: 'search',
            type: 'string',
            description: 'Search by employee name.',
          ),
        ],
      ),
      ToolDefinition(
        name: 'get_eom_points_breakdown',
        description:
            'Get detailed points calculation breakdown for a specific employee for EOM. Explains how points were awarded.',
        parameters: [
          ToolParameter(
            name: 'employee_id',
            type: 'string',
            description: 'The employee ID.',
            required: true,
          ),
          ToolParameter(
            name: 'month',
            type: 'string',
            description: 'Month number (1-12).',
            required: true,
          ),
          ToolParameter(
            name: 'year',
            type: 'string',
            description: 'Year.',
            required: true,
          ),
        ],
      ),

      // =============================================
      // ADMIN MANAGEMENT
      // =============================================
      ToolDefinition(
        name: 'get_all_admins',
        description:
            'Get list of all admin users with filters. Use when HR asks about admins or roles.',
        parameters: [
          ToolParameter(
            name: 'search',
            type: 'string',
            description: 'Search by name or email.',
          ),
          ToolParameter(
            name: 'role',
            type: 'string',
            description: 'Filter by role.',
          ),
          ToolParameter(
            name: 'role_type',
            type: 'string',
            description: 'Filter by role type.',
          ),
        ],
      ),

      // =============================================
      // TEAMSYNC (CHAT)
      // =============================================
      ToolDefinition(
        name: 'get_my_conversations',
        description:
            'Get active chat conversations for the current admin. Use when HR asks about recent messages or chats.',
        parameters: [
          ToolParameter(
            name: 'admin_id',
            type: 'string',
            description: 'The current admin ID.',
            required: true,
          ),
        ],
      ),
      ToolDefinition(
        name: 'get_chat_messages',
        description:
            'Get recent messages from a specific chat conversation. Use when HR asks "what was said in X group?".',
        parameters: [
          ToolParameter(
            name: 'conversation_id',
            type: 'string',
            description: 'The conversation ID.',
            required: true,
          ),
          ToolParameter(
            name: 'limit',
            type: 'string',
            description: 'Number of messages to fetch. Defaults to 50.',
          ),
        ],
      ),

      // =============================================
      // TEAM MANAGEMENT (TEAM CARDS)
      // =============================================
      ToolDefinition(
        name: 'get_all_team_cards',
        description:
            'Get all team cards (non-project work categories like Meeting, KT, Learning, R&D).',
        parameters: [
          ToolParameter(
            name: 'card_type',
            type: 'string',
            description: 'Filter by card type.',
          ),
          ToolParameter(
            name: 'team_type',
            type: 'string',
            description: 'Filter by team type.',
          ),
          ToolParameter(
            name: 'search',
            type: 'string',
            description: 'Search by card name.',
          ),
        ],
      ),
      ToolDefinition(
        name: 'get_team_card_usage_report',
        description:
            'Get detailed usage statistics for a specific team card within a date range.',
        parameters: [
          ToolParameter(
            name: 'team_card_id',
            type: 'string',
            description: 'The team card ID.',
            required: true,
          ),
          ToolParameter(
            name: 'from_date',
            type: 'string',
            description: 'Start date in YYYY-MM-DD format.',
          ),
          ToolParameter(
            name: 'to_date',
            type: 'string',
            description: 'End date in YYYY-MM-DD format.',
          ),
        ],
      ),
    ];
  }
}
