import 'dart:convert';
import '../../core/utils/logger.dart';
import '../employee_service.dart';
import '../leave_service.dart';
import '../permission_service.dart';
import '../wfh_service.dart';
import '../attendance_service.dart';
import '../task_card_service.dart';
import '../task_card_request_service.dart';
import '../project_service.dart';
import '../dashboard_service.dart';
import '../home_service.dart';
import '../announcement_service.dart';
import '../company_holiday_service.dart';
import '../team_card_service.dart';
import '../employee_performance_service.dart';
import '../asset_service.dart';
import '../expense_service.dart';
import '../todo_service.dart';
import '../employee_of_the_month_service.dart';
import '../../data/repositories/admin_repository.dart';
import '../../data/repositories/employee_tracker_repository.dart';
import '../../data/repositories/chat_repository.dart';

/// Executes tool/function calls by routing them to the appropriate service methods
class AiToolExecutor {
  static final AppLogger _logger = AppLogger('AiToolExecutor');

  // Service instances
  static final EmployeeService _employeeService = EmployeeService();
  static final LeaveService _leaveService = LeaveService();
  static final PermissionService _permissionService = PermissionService();
  static final WFHService _wfhService = WFHService();
  static final AttendanceService _attendanceService = AttendanceService();
  static final TaskCardService _taskCardService = TaskCardService();
  static final TaskCardRequestService _taskCardRequestService =
      TaskCardRequestService();
  static final ProjectService _projectService = ProjectService();
  static final DashboardService _dashboardService = DashboardService();
  static final HomeService _homeService = HomeService();
  static final AnnouncementService _announcementService = AnnouncementService();
  static final CompanyHolidayService _companyHolidayService =
      CompanyHolidayService();
  static final TeamCardService _teamCardService = TeamCardService();
  static final EmployeePerformanceService _performanceService =
      EmployeePerformanceService();
  static final AssetService _assetService = AssetService();
  static final ExpenseService _expenseService = ExpenseService();
  static final TodoService _todoService = TodoService();
  static final EmployeeOfTheMonthService _eomService =
      EmployeeOfTheMonthService();
  static final AdminRepository _adminRepository = AdminRepository();
  static final EmployeeTrackerRepository _trackerRepository =
      EmployeeTrackerRepository();
  static final ChatRepository _chatRepository = ChatRepository();

  /// Execute a tool/function call and return the result as JSON string
  static Future<String> execute(
    String functionName,
    Map<String, dynamic> arguments,
  ) async {
    _logger.info('Executing tool: $functionName with args: $arguments');

    try {
      final result = await _dispatch(functionName, arguments);
      final jsonResult = jsonEncode(result);
      _logger.info(
        'Tool $functionName executed successfully (${jsonResult.length} chars)',
      );
      return jsonResult;
    } catch (e, stackTrace) {
      _logger.error('Tool $functionName failed: $e', e, stackTrace);
      return jsonEncode({
        'error': true,
        'message': 'Failed to execute $functionName: $e',
      });
    }
  }

  /// Route function calls to the correct service method
  static Future<dynamic> _dispatch(
    String functionName,
    Map<String, dynamic> args,
  ) async {
    switch (functionName) {
      // =============================================
      // EMPLOYEE OVERVIEW & INFORMATION
      // =============================================
      case 'get_employee_overview_today':
        return await _employeeService.getOverviewToday();

      case 'get_all_employees':
        return await _employeeService.getAllEmployees(
          search: args['search'],
          status: args['status'] != null ? args['status'] == 'true' : null,
          role: args['role'],
          designation: args['designation'],
          page: int.tryParse(args['page']?.toString() ?? '1') ?? 1,
          limit: int.tryParse(args['limit']?.toString() ?? '20') ?? 20,
        );

      case 'get_employee_by_id':
        final employee = await _employeeService.getEmployeeById(
          args['employee_id'],
        );
        return employee.toJson();

      case 'get_present_employees':
        return await _employeeService.getPresentEmployees(args['date']);

      case 'get_absent_employees':
        return await _employeeService.getAbsentEmployees(args['date']);

      case 'get_wfh_employees':
        return await _employeeService.getWFHEmployees(args['date']);

      case 'get_permission_employees':
        return await _employeeService.getPermissionEmployees(args['date']);

      case 'get_late_employees':
        return await _employeeService.getLateEmployees(args['date']);

      // =============================================
      // LEAVE MANAGEMENT
      // =============================================
      case 'submit_leave_request':
        // NEW: Submit leave request directly
        final result = await _leaveService.createLeaveRequest(
          employeeId: args['employee_id'],
          leaveFromDate: args['from_date'],
          leaveToDate: args['to_date'],
          leaveRemarks: args['reason'],
          leaveType: args['leave_type'] ?? 'Casual Leave',
        );
        return {
          'success': true,
          'message': 'Leave request submitted successfully.',
          'leave_id': result.leaveId,
        };

      case 'get_all_leaves':
        return await _leaveService.getAllLeaves(
          status: args['status'],
          employeeId: args['employee_id'],
          fromDate: args['from_date'],
          toDate: args['to_date'],
          page: int.tryParse(args['page']?.toString() ?? '1') ?? 1,
          limit: int.tryParse(args['limit']?.toString() ?? '20') ?? 20,
        );

      case 'get_pending_leaves':
        final leaves = await _leaveService.getPendingLeaveRequests();
        return {
          'pending_leaves': leaves.map((l) => l.toJson()).toList(),
          'count': leaves.length,
        };

      case 'approve_leave_request':
        final approved = await _leaveService.approveLeaveRequest(
          leaveId: args['leave_id'],
          approvedBy: args['approved_by'],
          leaveApprovalRejectionRemarks: args['remarks'],
        );
        return {
          'success': true,
          'message': 'Leave request approved successfully.',
          'leave': approved?.toJson(),
        };

      case 'reject_leave_request':
        final rejected = await _leaveService.rejectLeaveRequest(
          leaveId: args['leave_id'],
          rejectedBy: args['rejected_by'],
          leaveApprovalRejectionRemarks: args['remarks'],
        );
        return {
          'success': true,
          'message': 'Leave request rejected.',
          'leave': rejected?.toJson(),
        };

      // =============================================
      // PERMISSION MANAGEMENT
      // =============================================
      case 'submit_permission_request':
        // NEW: Submit permission request
        final result = await _permissionService.createPermissionRequest(
          employeeId: args['employee_id'],
          permissionDate: args['date'],
          permissionFromTime: args['from_time'],
          permissionToTime: args['to_time'],
          permissionRemarks: args['reason'],
        );
        return {
          'success': true,
          'message': 'Permission request submitted successfully.',
          'permission_id': result.permissionId,
        };

      case 'get_all_permissions':
        return await _permissionService.getAllPermissions(
          status: args['status'],
          employeeId: args['employee_id'],
          fromDate: args['from_date'],
          toDate: args['to_date'],
        );

      case 'get_pending_permissions':
        final perms = await _permissionService.getPendingPermissionRequests();
        return {
          'pending_permissions': perms.map((p) => p.toJson()).toList(),
          'count': perms.length,
        };

      case 'approve_permission_request':
        final result = await _permissionService.approvePermissionRequest(
          permissionId: args['permission_id'],
          approvedBy: args['approved_by'],
          permissionApprovalRejectionRemarks: args['remarks'],
        );
        return {
          'success': true,
          'message': 'Permission request approved successfully.',
          'permission': result?.toJson(),
        };

      case 'reject_permission_request':
        final result = await _permissionService.rejectPermissionRequest(
          permissionId: args['permission_id'],
          rejectedBy: args['rejected_by'],
          permissionApprovalRejectionRemarks: args['remarks'],
        );
        return {
          'success': true,
          'message': 'Permission request rejected.',
          'permission': result?.toJson(),
        };

      // =============================================
      // WFH MANAGEMENT
      // =============================================
      case 'submit_wfh_request':
        // NEW: Submit WFH request
        final result = await _wfhService.createWFHRequest({
          'employee_id': args['employee_id'],
          'start_date': args['from_date'],
          'end_date': args['to_date'],
          'reason': args['reason'],
        });
        return {
          'success': true,
          'message': 'WFH request submitted successfully.',
          'wfh_id': result.wfhId,
        };

      case 'get_all_wfh_requests':
        return await _wfhService.getAllWFHRequests(
          status: args['status'] != null
              ? int.tryParse(args['status'].toString())
              : null,
          requesterId: args['requester_id'],
          fromDate: args['from_date'],
          toDate: args['to_date'],
        );

      case 'approve_reject_wfh_request':
        final result = await _wfhService.approveRejectWFHRequest(
          wfhId: args['wfh_id'],
          approve: args['approve'] == 'true',
          actionBy: args['action_by'],
          remarks: args['remarks'],
        );
        return {
          'success': true,
          'message': args['approve'] == 'true'
              ? 'WFH request approved successfully.'
              : 'WFH request rejected.',
          'wfh_request': result.toJson(),
        };

      // =============================================
      // ATTENDANCE
      // =============================================
      case 'get_today_attendance':
        final attendance = await _attendanceService.getTodayAttendance();
        return {
          'attendance': attendance.map((a) => a.toJson()).toList(),
          'count': attendance.length,
        };

      case 'get_employee_attendance':
        final records = await _attendanceService.getEmployeeAttendanceRange(
          args['employee_id'],
          args['from_date'],
          args['to_date'],
        );
        return {
          'attendance_records': records.map((a) => a.toJson()).toList(),
          'count': records.length,
        };

      // =============================================
      // TASK CARDS
      // =============================================
      case 'get_all_task_cards':
        String? status = args['workflow_status']?.toString();
        if (status != null) {
          final mapping = {
            'todo': 'TODO',
            'in_progress': 'In Progress',
            'dev_completed': 'Dev Completed',
            'in_qc': 'In QC',
            'work_done': 'Work Done',
            'completed': 'Work Done',
            'redo': 'Redo',
          };
          status = mapping[status.toLowerCase()] ?? status;
        }
        return await _taskCardService.getAllTaskCards(
          projectId: args['project_id']?.toString(),
          employeeId: args['employee_id']?.toString(),
          workflowStatus: status,
          priorityLevel: args['priority_level']?.toString(),
          search: args['search']?.toString(),
          page: int.tryParse(args['page']?.toString() ?? '1') ?? 1,
          limit: int.tryParse(args['limit']?.toString() ?? '20') ?? 20,
        );

      case 'get_delayed_task_cards':
        return await _taskCardService.getDelayedTaskCardsWithDetails();

      // =============================================
      // TASK CARD REQUESTS
      // =============================================
      case 'get_all_task_card_requests':
        return await _taskCardRequestService.getAllTaskCardRequests(
          status: args['status'],
          employeeId: args['employee_id'],
          projectId: args['project_id'],
          search: args['search'],
        );

      case 'approve_task_card_request':
        final result = await _taskCardRequestService.approveTaskCardRequest(
          args['request_id'],
          args['approved_by'],
          args['remarks'],
        );
        return {
          'success': true,
          'message': 'Task card request approved and task created.',
          'data': result.toJson(),
        };

      case 'reject_task_card_request':
        final result = await _taskCardRequestService.rejectTaskCardRequest(
          args['request_id'],
          args['rejected_by'],
          args['reason'],
        );
        return {
          'success': true,
          'message': 'Task card request rejected.',
          'data': result.toJson(),
        };

      case 'submit_task_card_request':
        final result = await _taskCardRequestService.createTaskCardRequest({
          'project_id': args['project_id'],
          'task_name': args['task_name'],
          'task_description': args['task_description'],
          'task_type': args['task_type'],
          'priority_level': args['priority_level'],
          'from_date': args['from_date'],
          'to_date': args['to_date'],
          'task_duration': args['task_duration'],
        }, args['employee_id']);
        return {
          'success': true,
          'message': 'Task card request submitted successfully.',
          'request_id': result.requestId,
        };

      // =============================================
      // PROJECTS
      // =============================================
      case 'get_all_projects':
        return await _projectService.getAllProjects(
          status: args['status'],
          search: args['search'],
          priorityLevel: args['priority_level'],
        );

      case 'get_project_statistics':
        return await _projectService.getStatistics();

      // =============================================
      // DASHBOARD & HOME
      // =============================================
      case 'get_dashboard_calendar_events':
        return await _dashboardService.getCalendarEvents(args['date']);

      case 'get_dashboard_task_analytics':
        return await _dashboardService.getTaskAnalytics();

      case 'get_home_overview':
        return await _homeService.getHomeOverview(
          month: int.parse(args['month'].toString()),
          year: int.parse(args['year'].toString()),
        );

      // =============================================
      // ANNOUNCEMENTS
      // =============================================
      case 'get_all_announcements':
        final result = await _announcementService.getAllAnnouncements(
          search: args['search'],
          isActive: args['is_active'] != null
              ? args['is_active'] == 'true'
              : null,
        );
        return {
          'announcements': result.$1.map((a) => a.toJson()).toList(),
          'total': result.$2,
        };

      // =============================================
      // COMPANY HOLIDAYS
      // =============================================
      case 'get_company_holidays':
        final result = await _companyHolidayService.getAllHolidays(
          search: args['search'],
        );
        return {
          'holidays': result.$1.map((h) => h.toJson()).toList(),
          'total': result.$2,
        };

      // =============================================
      // EMPLOYEE PERFORMANCE
      // =============================================
      case 'get_employee_performance_summary':
        return await _performanceService.getAllEmployeesSummary(
          fromDate: args['from_date'],
          toDate: args['to_date'],
          search: args['search'],
        );

      case 'get_employee_performance_report':
        final result = await _performanceService.getEmployeePerformanceReport(
          employeeId: args['employee_id'],
          fromDate: args['from_date'],
          toDate: args['to_date'],
        );
        return result.toJson();

      // =============================================
      // LEAVE STATISTICS
      // =============================================
      case 'get_employee_leave_statistics':
        return await _leaveService.getEmployeeLeaveStatistics(
          args['employee_id'],
        );

      // =============================================
      // ASSETS
      // =============================================
      case 'get_all_assets':
        final result = await _assetService.getAllAssets(
          search: args['search'],
          assetType: args['asset_type'],
          assetStatus: args['asset_status'],
        );
        return {
          'assets': result.$1.map((a) => a.toJson()).toList(),
          'total': result.$2,
        };

      // =============================================
      // EXPENSES
      // =============================================
      case 'get_all_expenses':
        final result = await _expenseService.getAllExpenses(
          search: args['search'],
          expenseType: args['expense_type'],
        );
        return {
          'expenses': result.$1.map((e) => e.toJson()).toList(),
          'total': result.$2,
        };

      // =============================================
      // TODOS
      // =============================================
      case 'get_all_todos':
        final result = await _todoService.getAllTodos(
          status: args['status'],
          priority: args['priority'],
        );
        return {
          'todos': result.$1.map((t) => t.toJson()).toList(),
          'total': result.$2,
        };

      // =============================================
      // BIRTHDAYS
      // =============================================
      case 'get_birthdays_this_month':
        final month = args['month'] != null
            ? int.tryParse(args['month'].toString())
            : null;
        final birthdays = await _employeeService.getBirthdaysInMonth(month);
        return {
          'birthdays': birthdays.map((e) => e.toJson()).toList(),
          'count': birthdays.length,
        };

      // =============================================
      // EMPLOYEE TRACKER (ADVANCED)
      // =============================================
      case 'get_employee_tracker_list':
        return await _trackerRepository.getEmployeeTrackerList(
          date: args['date'],
          search: args['search'],
          statusFilter: args['status_filter'],
          page: int.tryParse(args['page']?.toString() ?? '1') ?? 1,
          limit: int.tryParse(args['limit']?.toString() ?? '20') ?? 20,
        );

      case 'get_employee_tracker_detail':
        return await _trackerRepository.getEmployeeTrackerDetail(
          employeeId: args['employee_id'],
          date: args['date'],
        );

      // =============================================
      // EMPLOYEE OF THE MONTH
      // =============================================
      case 'get_employee_rankings':
        return await _eomService.getEmployeeRankings(
          month: int.parse(args['month'].toString()),
          year: int.parse(args['year'].toString()),
          search: args['search'],
        );

      case 'get_eom_points_breakdown':
        return await _eomService.getEmployeePointsBreakdown(
          employeeId: args['employee_id'],
          month: int.parse(args['month'].toString()),
          year: int.parse(args['year'].toString()),
        );

      // =============================================
      // ADMIN MANAGEMENT
      // =============================================
      case 'get_all_admins':
        final admins = await _adminRepository.getAll(
          search: args['search'],
          role: args['role'],
          roleType: args['role_type'],
        );
        return {
          'admins': admins.map((a) => a.toJson()).toList(),
          'count': admins.length,
        };

      // =============================================
      // TEAMSYNC (CHAT)
      // =============================================
      case 'get_chat_conversations':
      case 'get_my_conversations':
        final userId =
            args['employee_id'] ?? args['admin_id'] ?? args['user_id'];
        final userType =
            args['user_role'] ??
            (args['employee_id'] != null ? 'Employee' : 'Admin');

        if (userId == null) {
          throw Exception('User ID is required for get_chat_conversations');
        }

        final conversations = await _chatRepository.getConversationsForUser(
          userId.toString(),
          userType.toString(),
        );
        return {'conversations': conversations, 'count': conversations.length};

      case 'get_conversation_messages':
      case 'get_chat_messages':
        return await _chatRepository.getMessages(
          args['conversation_id'],
          limit: int.tryParse(args['limit']?.toString() ?? '50') ?? 50,
        );

      // =============================================
      // TEAM MANAGEMENT (TEAM CARDS)
      // =============================================
      case 'get_all_team_cards':
        return await _teamCardService.getAllTeamCards(
          cardType: args['card_type'],
          teamType: args['team_type'],
          search: args['search'],
          page: int.tryParse(args['page']?.toString() ?? '1') ?? 1,
          limit: int.tryParse(args['limit']?.toString() ?? '50') ?? 50,
        );

      case 'get_team_card_usage_report':
        return await _teamCardService.getTeamCardUsageReport(
          args['team_card_id'],
          fromDate: args['from_date'] != null
              ? DateTime.tryParse(args['from_date'].toString())
              : null,
          toDate: args['to_date'] != null
              ? DateTime.tryParse(args['to_date'].toString())
              : null,
        );

      default:
        return {'error': true, 'message': 'Unknown tool: $functionName'};
    }
  }
}
