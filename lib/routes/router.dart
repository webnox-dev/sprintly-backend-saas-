import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'employee_routes.dart';
import 'auth_routes.dart';
import 'organization_routes.dart';
import 'attendance_routes.dart';
import 'task_card_routes.dart';
import 'task_card_request_routes.dart';
import 'team_card_routes.dart';
import 'project_routes.dart';
import 'project_helper_routes.dart';
import 'admin_routes.dart';
import 'employee_document_routes.dart';
import 'leave_routes.dart';
import 'permission_routes.dart';
import 'wfh_routes.dart';
import 'upload_routes.dart';
import 'company_holiday_routes.dart';
import 'announcement_routes.dart';
import 'expense_routes.dart';
import 'asset_routes.dart';
import 'todo_routes.dart';
import 'time_tracking_routes.dart';
import 'office_location_routes.dart';
import 'chat_routes.dart';
import 'dashboard_routes.dart';
import 'home_routes.dart';
import 'face_routes.dart';
import 'settings_routes.dart';

import 'report_routes.dart';
import 'admin_report_routes.dart';
import 'employee_tracker_routes.dart';
import 'notification_routes.dart';
import 'leave_report_routes.dart';
import 'leave_policy_routes.dart';
import 'employee_performance_routes.dart';
import 'employee_of_the_month_routes.dart';
import 'ai_routes.dart';
import 'calendar_meeting_routes.dart';
import 'swagger_routes.dart';
import 'salary_calculation_routes.dart';
import 'letter_template_routes.dart';
import 'certificate_content_template_routes.dart';
import 'super_admin_routes.dart';
import 'billing_routes.dart';
import '../core/middleware/feature_middleware.dart';

/// Main application router
class AppRouter {
  final Router _router = Router();
  final EmployeeRoutes _employeeRoutes = EmployeeRoutes();
  final AuthRoutes _authRoutes = AuthRoutes();
  final OrganizationRoutes _organizationRoutes = OrganizationRoutes();
  final AttendanceRoutes _attendanceRoutes = AttendanceRoutes();
  final TaskCardRoutes _taskCardRoutes = TaskCardRoutes();
  final TaskCardRequestRoutes _taskCardRequestRoutes = TaskCardRequestRoutes();
  final TeamCardRoutes _teamCardRoutes = TeamCardRoutes();
  final ProjectRoutes _projectRoutes = ProjectRoutes();
  final ProjectHelperRoutes _projectHelperRoutes = ProjectHelperRoutes();
  final AdminRoutes _adminRoutes = AdminRoutes();
  final EmployeeDocumentRoutes _employeeDocumentRoutes =
      EmployeeDocumentRoutes();
  final LeaveRoutes _leaveRoutes = LeaveRoutes();
  final PermissionRoutes _permissionRoutes = PermissionRoutes();
  final WFHRoutes _wfhRoutes = WFHRoutes();
  final UploadRoutes _uploadRoutes = UploadRoutes();
  final CompanyHolidayRoutes _companyHolidayRoutes = CompanyHolidayRoutes();
  final AnnouncementRoutes _announcementRoutes = AnnouncementRoutes();
  final ExpenseRoutes _expenseRoutes = ExpenseRoutes();
  final AssetRoutes _assetRoutes = AssetRoutes();
  final TodoRoutes _todoRoutes = TodoRoutes();
  final TimeTrackingRoutes _timeTrackingRoutes = TimeTrackingRoutes();
  final OfficeLocationRoutes _officeLocationRoutes = OfficeLocationRoutes();
  final ChatRoutes _chatRoutes = ChatRoutes();
  final DashboardRoutes _dashboardRoutes = DashboardRoutes();
  final HomeRoutes _homeRoutes = HomeRoutes();
  final ReportRoutes _reportRoutes = ReportRoutes();
  final FaceRoutes _faceRoutes = FaceRoutes();
  final AdminReportRoutes _adminReportRoutes = AdminReportRoutes();
  final EmployeeTrackerRoutes _employeeTrackerRoutes = EmployeeTrackerRoutes();
  final NotificationRoutes _notificationRoutes = NotificationRoutes();
  final LeaveReportRoutes _leaveReportRoutes = LeaveReportRoutes();
  final LeavePolicyRoutes _leavePolicyRoutes = LeavePolicyRoutes();
  final EmployeePerformanceRoutes _performanceRoutes =
      EmployeePerformanceRoutes();
  final EmployeeOfTheMonthRoutes _eomRoutes = EmployeeOfTheMonthRoutes();
  final SettingsRoutes _settingsRoutes = SettingsRoutes();
  final AiRoutes _aiRoutes = AiRoutes();
  final CalendarMeetingRoutes _calendarMeetingRoutes = CalendarMeetingRoutes();
  final SwaggerRoutes _swaggerRoutes = SwaggerRoutes();
  final SalaryCalculationRoutes _salaryRoutes = SalaryCalculationRoutes();
  final LetterTemplateRoutes _letterTemplateRoutes = LetterTemplateRoutes();
  final CertificateContentTemplateRoutes _certificateContentRoutes =
      CertificateContentTemplateRoutes();
  final SuperAdminRoutes _superAdminRoutes = SuperAdminRoutes();
  final BillingRoutes _billingRoutes = BillingRoutes();

  Router get router {
    // Mount auth routes (public endpoints)
    // SWAGGER UI - Specific routes to allow /api to serve docs
    // These must be defined to handle the exact path /api and /api/
    _router.get('/api', _swaggerRoutes.uiHandler);
    _router.get('/api/', _swaggerRoutes.uiHandler);
    _router.get('/api/index.html', _swaggerRoutes.uiHandler);
    _router.get('/api/swagger.yaml', _swaggerRoutes.yamlHandler);
    // Also keep /spi for backward compatibility or alternative access
    _router.mount('/spi', _swaggerRoutes.router.call);

    _router.mount('/api/', _authRoutes.router.call);
    _router.mount('/api/organizations', _organizationRoutes.router.call);

    // Mount employee routes
    _router.mount('/api/', _employeeRoutes.router.call);

    // Mount admin routes
    _router.mount('/api/', _adminRoutes.router.call);

    // Mount attendance routes
    _router.mount('/api/', _attendanceRoutes.router.call);

    // Mount task card routes
    _router.mount('/api/', _taskCardRoutes.router.call);

    // Mount task card request routes
    _router.mount('/api/', _taskCardRequestRoutes.router.call);

    // Mount team card routes
    _router.mount('/api/', _teamCardRoutes.router.call);

    // Mount project routes
    _router.mount('/api/', _projectRoutes.router.call);

    // Mount project helper routes (documents, figma-urls, releases, milestones, reviews, discontinuation)
    _router.mount('/api/projects', _projectHelperRoutes.router.call);

    // Mount employee document routes (document request & verification workflow)
    _router.mount('/api/', _employeeDocumentRoutes.router.call);

    // Mount leave tracker routes (leaves, permissions, WFH)
    final leaveTrackerHandler = Pipeline()
        .addMiddleware(FeatureMiddleware.requireFeature('leave_tracker'))
        .addHandler(_leaveRoutes.router.call);
    _router.mount('/api/', leaveTrackerHandler);

    final permissionHandler = Pipeline()
        .addMiddleware(FeatureMiddleware.requireFeature('leave_tracker'))
        .addHandler(_permissionRoutes.router.call);
    _router.mount('/api/', permissionHandler);

    final wfhHandler = Pipeline()
        .addMiddleware(FeatureMiddleware.requireFeature('wfh_requests'))
        .addHandler(_wfhRoutes.router.call);
    _router.mount('/api/', wfhHandler);

    final leavePolicyHandler = Pipeline()
        .addMiddleware(FeatureMiddleware.requireFeature('leave_tracker'))
        .addHandler(_leavePolicyRoutes.router.call);
    _router.mount('/api/', leavePolicyHandler);

    // Mount file upload routes
    _router.mount('/api/', _uploadRoutes.router.call);

    // Mount Company Holidays routes
    _router.mount('/api/', _companyHolidayRoutes.router.call);

    // Mount Announcements routes
    _router.mount('/api/', _announcementRoutes.router.call);

    // Mount Expenses routes
    _router.mount('/api/', _expenseRoutes.router.call);

    // Mount Assets routes
    _router.mount('/api/', _assetRoutes.router.call);

    // Mount Todos routes
    _router.mount('/api/', _todoRoutes.router.call);

    // Mount time tracking routes (task clock in/out)
    _router.mount('/api/time-tracking', _timeTrackingRoutes.router.call);

    // Mount office location routes
    _router.mount('/api/', _officeLocationRoutes.router.call);

    // Mount TeamSync chat routes (includes WebSocket endpoint)
    final teamSyncHandler = Pipeline()
        .addMiddleware(FeatureMiddleware.requireFeature('team_sync_chat'))
        .addHandler(_chatRoutes.router.call);
    _router.mount('/api/', teamSyncHandler);

    // Mount report routes (daily reports)
    _router.mount('/api/', _reportRoutes.router.call);

    // Mount admin report routes (employee report management)
    _router.mount('/api/', _adminReportRoutes.router.call);

    // Mount dashboard routes (calendar events, birthdays, task analytics)
    _router.mount('/api/dashboard', _dashboardRoutes.router.call);

    // Mount home routes (consolidated home screen APIs)
    _router.mount('/api/home', _homeRoutes.router.call);

    // Mount face recognition routes (biometric kiosk)
    final faceRecognitionHandler = Pipeline()
        .addMiddleware(FeatureMiddleware.requireFeature('face_recognition'))
        .addHandler(_faceRoutes.router.call);
    _router.mount('/api/', faceRecognitionHandler);

    // Mount employee tracker routes (admin employee tracking)
    _router.mount('/api/', _employeeTrackerRoutes.router.call);

    // Mount performance report routes
    _router.mount('/api/performance', _performanceRoutes.router.call);

    // Mount Employee of the Month routes (admin)
    _router.mount('/api/admin/employee-of-the-month', _eomRoutes.router.call);

    // Mount notification routes (in-app notifications)
    _router.mount('/api/', _notificationRoutes.router.call);

    // Mount leave report routes (consolidated leave reports)
    _router.mount('/api/admin/', _leaveReportRoutes.router.call);

    // Mount Settings routes
    _router.mount('/api/settings/', _settingsRoutes.router.call);

    // Mount AI Chat routes (LLM-powered assistant)
    final aiChatHandler = Pipeline()
        .addMiddleware(FeatureMiddleware.requireFeature('ai_assistant'))
        .addHandler(_aiRoutes.router.call);
    _router.mount('/api/', aiChatHandler);

    // Mount Calendar Meeting routes (scheduling, venue, participants)
    _router.mount('/api/', _calendarMeetingRoutes.router.call);

    // Mount Salary Calculation routes (HRMS)
    final salaryHandler = Pipeline()
        .addMiddleware(FeatureMiddleware.requireFeature('salary_module'))
        .addHandler(_salaryRoutes.router.call);
    _router.mount('/api/', salaryHandler);

    // Mount Letter Template routes
    _router.mount('/api/', _letterTemplateRoutes.router.call);

    // Mount Certificate Content Template routes
    _router.mount('/api/', _certificateContentRoutes.router.call);

    // ── SUPER ADMIN ROUTES (Separate JWT, mounted under /super/) ──────────
    _router.mount('/super/', _superAdminRoutes.router.call);

    // Mount Billing routes (Subscription plans, Razorpay)
    _router.mount('/api/billing', _billingRoutes.router.call);

    // Health check endpoint
    _router.get('/health', _healthCheck);

    // Root endpoint
    _router.get('/', _root);

    return _router;
  }

  /// Health check endpoint
  Response _healthCheck(Request request) {
    return Response.ok(
      jsonEncode({
        'status': 'running',
        'message': 'Server is running',
        'timestamp': DateTime.now().toIso8601String(),
      }),
      headers: {'content-type': 'application/json'},
    );
  }

  /// Root endpoint
  Response _root(Request request) {
    return Response.ok(
      jsonEncode({
        'status': 'running',
        'message': 'Webnox Sprintly Backend API is running',
        'version': '1.3.2',
        'release_notes':
            'Bug fixes in api related to leave, permissions fetching',
        'lastly_updated_on': '2026-03-30 Monday 12:00 PM IST',
        'endpoints': {
          'health': '/health',
          'api': '/api',
          'swagger': '/api#',
          'docs': 'See API documentation for available endpoints',
        },
        'timestamp': DateTime.now().toIso8601String(),
      }),
      headers: {'content-type': 'application/json'},
    );
  }
}
