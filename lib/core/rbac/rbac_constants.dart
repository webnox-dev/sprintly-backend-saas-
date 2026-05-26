// Role-Based Access Control (RBAC) Constants & Helper
//
// Centralizes all permission strings and default role-permission mappings.
// This file is the single source of truth for access control logic.

/// All available permission strings in the system
class RbacPermissions {
  // ─── Menu / General ───
  static const String viewDashboard = 'view_dashboard';
  static const String viewTodo = 'view_todo';

  // ─── HRMS ───
  static const String manageAdmins = 'manage_admins';
  static const String viewEmployees = 'view_employees';
  static const String manageEmployees = 'manage_employees';
  static const String viewLeaveTracker = 'view_leave_tracker';
  static const String viewAttendance = 'view_attendance';
  static const String viewExpenses = 'view_expenses';
  static const String viewAssetManagement = 'view_asset_management';
  static const String viewAnnouncements = 'view_announcements';
  static const String viewCompanyHolidays = 'view_company_holidays';
  static const String viewEmployeeTracker = 'view_employee_tracker';
  static const String viewEmployeeReports = 'view_employee_reports';
  static const String viewEmployeePerformance = 'view_employee_performance';
  static const String viewSalaryCalculation = 'view_salary_calculation';
  static const String viewLetterTemplates = 'view_letter_templates';

  // ─── Projects & Tasks ───
  static const String viewProjects = 'view_projects';
  static const String viewTaskCards = 'view_task_cards';
  static const String viewTaskCardRequests = 'view_task_card_requests';

  // ─── Communication ───
  static const String viewTeamSync = 'view_teamsync';

  // ─── Others ───
  static const String viewSettings = 'view_settings';
  static const String viewNotifications = 'view_notifications';

  /// Returns every permission string (for Super Admin grant-all logic)
  static List<String> get all => [
    viewDashboard,
    viewTodo,
    manageAdmins,
    viewEmployees,
    manageEmployees,
    viewLeaveTracker,
    viewAttendance,
    viewExpenses,
    viewAssetManagement,
    viewAnnouncements,
    viewCompanyHolidays,
    viewEmployeeTracker,
    viewEmployeeReports,
    viewEmployeePerformance,
    viewSalaryCalculation,
    viewLetterTemplates,
    viewProjects,
    viewTaskCards,
    viewTaskCardRequests,
    viewTeamSync,
    viewSettings,
    viewNotifications,
  ];
}

/// Predefined admin roles
class AdminRoles {
  static const String superAdmin = 'Super Admin';
  static const String hr = 'HR';
  static const String bde = 'BDE';
  static const String teamLeader = 'Team Leader';
  static const String tester = 'Tester';

  static List<String> get all => [superAdmin, hr, bde, teamLeader, tester];
}

/// Default permissions for each role.
/// These are used when an admin's `access_permissions` is NULL.
class RoleDefaultPermissions {
  static const Map<String, List<String>> _defaults = {
    // Super Admin → full access (represented as all permissions)
    'Super Admin': [], // Empty means "all" — checked via isSuperAdmin
    'HR': [
      RbacPermissions.viewDashboard,
      RbacPermissions.viewTodo,
      RbacPermissions.manageAdmins,
      RbacPermissions.viewEmployees,
      RbacPermissions.manageEmployees,
      RbacPermissions.viewLeaveTracker,
      RbacPermissions.viewAttendance,
      RbacPermissions.viewExpenses,
      RbacPermissions.viewAssetManagement,
      RbacPermissions.viewAnnouncements,
      RbacPermissions.viewCompanyHolidays,
      RbacPermissions.viewEmployeeTracker,
      RbacPermissions.viewEmployeeReports,
      RbacPermissions.viewEmployeePerformance,
      RbacPermissions.viewSalaryCalculation,
      RbacPermissions.viewLetterTemplates,
      RbacPermissions.viewSettings,
      RbacPermissions.viewNotifications,
    ],
    'BDE': [
      RbacPermissions.viewDashboard,
      RbacPermissions.viewTodo,
      RbacPermissions.viewProjects,
      RbacPermissions.viewTaskCards,
      RbacPermissions.viewTaskCardRequests,
      RbacPermissions.viewTeamSync,
      RbacPermissions.viewSettings,
      RbacPermissions.viewNotifications,
    ],
    'Team Leader': [
      RbacPermissions.viewDashboard,
      RbacPermissions.viewTodo,
      RbacPermissions.viewProjects,
      RbacPermissions.viewTaskCards,
      RbacPermissions.viewTaskCardRequests,
      RbacPermissions.viewTeamSync,
      RbacPermissions.viewSettings,
      RbacPermissions.viewNotifications,
    ],
    'Tester': [
      RbacPermissions.viewDashboard,
      RbacPermissions.viewTeamSync,
      RbacPermissions.viewSettings,
      RbacPermissions.viewProjects,
      RbacPermissions.viewTaskCards,
      RbacPermissions.viewTaskCardRequests,
    ],
  };

  /// Returns the default permissions list for a given role.
  static List<String> forRole(String role) {
    return _defaults[role] ?? [];
  }
}

/// RBAC helper to resolve the effective permissions for an admin.
class RbacHelper {
  /// Check if a role is Super Admin (full access).
  static bool isSuperAdmin(String role) {
    return role == AdminRoles.superAdmin;
  }

  /// Check if admin has a specific permission
  static bool hasPermission(
    String permission,
    String role,
    List<String>? accessPermissions,
  ) {
    // Super Admin always gets full access
    if (isSuperAdmin(role)) {
      return true;
    }

    // Resolve permissions and check
    final perms = resolvePermissions(role, accessPermissions);
    return perms.contains(permission);
  }

  /// Resolve the final effective permissions for an admin.
  ///
  /// Logic:
  /// - If [role] is Super Admin → returns ALL permissions.
  /// - If [accessPermissions] is non-null → returns it (overrides defaults).
  /// - If [accessPermissions] is null → returns defaults for [role].
  static List<String> resolvePermissions(
    String role,
    List<String>? accessPermissions,
  ) {
    // Super Admin always gets full access
    if (isSuperAdmin(role)) {
      return RbacPermissions.all;
    }

    // If custom permissions are set, use them
    if (accessPermissions != null) {
      return accessPermissions;
    }

    // Otherwise, fall back to role defaults
    return RoleDefaultPermissions.forRole(role);
  }
}
