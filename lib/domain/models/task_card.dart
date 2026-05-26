import 'dart:convert';

/// TaskCard model matching Flutter app structure
class TaskCard {
  final String taskId;
  final String? taskName;
  final String? taskDescription;
  final String? taskDuration;
  final String? taskType;
  final String? priorityLevel;
  final String? projectId;
  final Map<String, dynamic>? projectDetails;
  final String? employeeId;
  final Map<String, dynamic>? employeeDetails;
  final String? workflowStatus;
  final DateTime? assignedAt;
  final Map<String, dynamic>?
  assignedBy; // Valid JSON object with admin/employee details
  final DateTime? fromDate;
  final DateTime? toDate;
  // Dev tracking
  final DateTime? devStartedAt;
  final DateTime? devCompletedAt;
  final double? totalDevHours;
  final String? devNotes;
  final List<dynamic>? devCompletedAttachments;
  // QC tracking
  final DateTime? qcStartedAt;
  final DateTime? qcCompletedAt;
  final double? qcTotalHours;
  final String? qcNotes;
  final List<dynamic>? qcCompletedAttachments;
  // Attachments
  final List<dynamic>? taskAttachments;
  // Reassignment
  final bool? isTaskReassigned;
  final String? reassignedBy;
  final DateTime? reassignedOn;
  final String? reassignedReason;
  // Status & Audit
  final String? statusReason;
  final bool? isDeleted;
  final String? createdBy;
  final DateTime? createdAt;
  final String? updatedBy;
  final DateTime? updatedAt;

  TaskCard({
    required this.taskId,
    this.taskName,
    this.taskDescription,
    this.taskDuration,
    this.taskType,
    this.priorityLevel,
    this.projectId,
    this.projectDetails,
    this.employeeId,
    this.employeeDetails,
    this.workflowStatus,
    this.assignedAt,
    this.assignedBy,
    this.fromDate,
    this.toDate,
    this.devStartedAt,
    this.devCompletedAt,
    this.totalDevHours,
    this.devNotes,
    this.devCompletedAttachments,
    this.qcStartedAt,
    this.qcCompletedAt,
    this.qcTotalHours,
    this.qcNotes,
    this.qcCompletedAttachments,
    this.taskAttachments,
    this.isTaskReassigned,
    this.reassignedBy,
    this.reassignedOn,
    this.reassignedReason,
    this.statusReason,
    this.isDeleted,
    this.createdBy,
    this.createdAt,
    this.updatedBy,
    this.updatedAt,
  });

  factory TaskCard.fromMap(Map<String, dynamic> map) {
    dynamic parseJson(dynamic value) {
      if (value == null) return null;
      if (value is Map) return value;
      if (value is String) {
        try {
          return jsonDecode(value);
        } catch (_) {
          return null;
        }
      }
      return null;
    }

    List<dynamic> parseJsonArray(dynamic value) {
      if (value == null) return [];
      if (value is List) return value;
      if (value is String) {
        try {
          final decoded = jsonDecode(value);
          return decoded is List ? decoded : [];
        } catch (_) {
          return [];
        }
      }
      return [];
    }

    // Helper to safely parse numeric values that might come as String or num
    double? parseDouble(dynamic value) {
      if (value == null) return null;
      if (value is num) return value.toDouble();
      if (value is String) {
        return double.tryParse(value);
      }
      return null;
    }

    return TaskCard(
      taskId: map['task_id']?.toString() ?? '',
      taskName: map['task_name']?.toString(),
      taskDescription: map['task_description']?.toString(),
      taskDuration: map['task_duration']?.toString(),
      taskType: map['task_type']?.toString() ?? 'Task',
      priorityLevel: map['priority_level']?.toString() ?? 'Medium',
      projectId: map['project_id']?.toString(),
      projectDetails:
          parseJson(map['project_details']) as Map<String, dynamic>?,
      employeeId: map['employee_id']?.toString(),
      employeeDetails:
          parseJson(map['employee_details']) as Map<String, dynamic>?,
      workflowStatus: map['workflow_status']?.toString() ?? 'TODO',
      assignedAt: map['assigned_at'] != null
          ? DateTime.tryParse(map['assigned_at'].toString())
          : null,
      assignedBy: parseJson(map['assigned_by']) as Map<String, dynamic>?,
      fromDate: map['from_date'] != null
          ? DateTime.tryParse(map['from_date'].toString())
          : null,
      toDate: map['to_date'] != null
          ? DateTime.tryParse(map['to_date'].toString())
          : null,
      devStartedAt: map['dev_started_at'] != null
          ? DateTime.tryParse(map['dev_started_at'].toString())
          : null,
      devCompletedAt: map['dev_completed_at'] != null
          ? DateTime.tryParse(map['dev_completed_at'].toString())
          : null,
      totalDevHours: parseDouble(map['total_dev_hours']),
      devNotes: map['dev_notes']?.toString(),
      devCompletedAttachments: parseJsonArray(map['dev_completed_attachments']),
      qcStartedAt: map['qc_started_at'] != null
          ? DateTime.tryParse(map['qc_started_at'].toString())
          : null,
      qcCompletedAt: map['qc_completed_at'] != null
          ? DateTime.tryParse(map['qc_completed_at'].toString())
          : null,
      qcTotalHours: parseDouble(map['qc_total_hours']),
      qcNotes: map['qc_notes']?.toString(),
      qcCompletedAttachments: parseJsonArray(map['qc_completed_attachments']),
      taskAttachments: parseJsonArray(
        map['fetched_attachments'] ?? map['task_attachments'],
      ),
      isTaskReassigned:
          map['is_task_reassigned'] == true || map['is_task_reassigned'] == 1,
      reassignedBy: map['reassigned_by']?.toString(),
      reassignedOn: map['reassigned_on'] != null
          ? DateTime.tryParse(map['reassigned_on'].toString())
          : null,
      reassignedReason: map['reassigned_reason']?.toString(),
      statusReason: map['status_reason']?.toString(),
      isDeleted: map['is_deleted'] == true || map['is_deleted'] == 1,
      createdBy: map['created_by']?.toString(),
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString())
          : null,
      updatedBy: map['updated_by']?.toString(),
      updatedAt: map['updated_at'] != null
          ? DateTime.tryParse(map['updated_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'task_id': taskId,
      'task_name': taskName,
      'task_description': taskDescription,
      'task_duration': taskDuration,
      'task_type': taskType,
      'priority_level': priorityLevel,
      'project_id': projectId,
      'project_details': projectDetails,
      'employee_id': employeeId,
      'employee_details': employeeDetails,
      'workflow_status': workflowStatus,
      'assigned_at': assignedAt?.toIso8601String(),
      'assigned_by': assignedBy,
      'from_date': fromDate?.toIso8601String().split('T')[0],
      'to_date': toDate?.toIso8601String().split('T')[0],
      'dev_started_at': devStartedAt?.toIso8601String(),
      'dev_completed_at': devCompletedAt?.toIso8601String(),
      'total_dev_hours': totalDevHours,
      'dev_notes': devNotes,
      'dev_completed_attachments': devCompletedAttachments,
      'qc_started_at': qcStartedAt?.toIso8601String(),
      'qc_completed_at': qcCompletedAt?.toIso8601String(),
      'qc_total_hours': qcTotalHours,
      'qc_notes': qcNotes,
      'qc_completed_attachments': qcCompletedAttachments,
      'task_attachments': taskAttachments,
      'is_task_reassigned': isTaskReassigned,
      'reassigned_by': reassignedBy,
      'reassigned_on': reassignedOn?.toIso8601String(),
      'reassigned_reason': reassignedReason,
      'status_reason': statusReason,
      'is_deleted': isDeleted,
      'created_by': createdBy,
      'created_at': createdAt?.toIso8601String(),
      'updated_by': updatedBy,
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  /// Minimal JSON for list views
  Map<String, dynamic> toListJson() {
    return {
      'task_id': taskId,
      'task_name': taskName,
      'task_description': taskDescription,
      'task_type': taskType,
      'priority_level': priorityLevel,
      'project_id': projectId,
      'project_details': projectDetails,
      'employee_id': employeeId,
      'employee_details': employeeDetails,
      'workflow_status': workflowStatus,
      'assigned_by': assignedBy,
      'from_date': fromDate?.toIso8601String().split('T')[0],
      'to_date': toDate?.toIso8601String().split('T')[0],
      'is_task_reassigned': isTaskReassigned,
      'created_at': createdAt?.toIso8601String(),
    };
  }
}

/// Task Card Log model
class TaskCardLog {
  final String logId;
  final String taskId;
  final String actionName;
  final String? actionDescription;
  final String actionedBy;
  final DateTime actionedDatetime;
  final Map<String, dynamic>? oldValue;
  final Map<String, dynamic>? newValue;

  TaskCardLog({
    required this.logId,
    required this.taskId,
    required this.actionName,
    this.actionDescription,
    required this.actionedBy,
    required this.actionedDatetime,
    this.oldValue,
    this.newValue,
  });

  factory TaskCardLog.fromMap(Map<String, dynamic> map) {
    dynamic parseJson(dynamic value) {
      if (value == null) return null;
      if (value is Map) return value;
      if (value is String) {
        try {
          return jsonDecode(value);
        } catch (_) {
          return null;
        }
      }
      return null;
    }

    return TaskCardLog(
      logId: map['log_id']?.toString() ?? '',
      taskId: map['task_id']?.toString() ?? '',
      actionName: map['action_name']?.toString() ?? '',
      actionDescription: map['action_description']?.toString(),
      actionedBy: map['actioned_by']?.toString() ?? '',
      actionedDatetime: map['actioned_datetime'] != null
          ? DateTime.parse(map['actioned_datetime'].toString())
          : DateTime.now(),
      oldValue: parseJson(map['old_value']) as Map<String, dynamic>?,
      newValue: parseJson(map['new_value']) as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'log_id': logId,
      'task_id': taskId,
      'action_name': actionName,
      'action_description': actionDescription,
      'actioned_by': actionedBy,
      'actioned_datetime': actionedDatetime.toIso8601String(),
      'old_value': oldValue,
      'new_value': newValue,
    };
  }
}

/// Task Attachment model
class TaskAttachment {
  final String attachmentId;
  final String taskId;
  final String attachmentType;
  final String title;
  final String url;
  final String? createdBy;
  final DateTime? createdAt;
  final String? updatedBy;
  final DateTime? updatedAt;

  TaskAttachment({
    required this.attachmentId,
    required this.taskId,
    this.attachmentType = 'file',
    required this.title,
    required this.url,
    this.createdBy,
    this.createdAt,
    this.updatedBy,
    this.updatedAt,
  });

  factory TaskAttachment.fromMap(Map<String, dynamic> map) {
    return TaskAttachment(
      attachmentId: map['attachment_id']?.toString() ?? '',
      taskId: map['task_id']?.toString() ?? '',
      attachmentType: map['attachment_type']?.toString() ?? 'file',
      title: map['title']?.toString() ?? '',
      url: map['url']?.toString() ?? '',
      createdBy: map['created_by']?.toString(),
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString())
          : null,
      updatedBy: map['updated_by']?.toString(),
      updatedAt: map['updated_at'] != null
          ? DateTime.tryParse(map['updated_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'attachment_id': attachmentId,
      'task_id': taskId,
      'attachment_type': attachmentType,
      'title': title,
      'url': url,
      'created_by': createdBy,
      'created_at': createdAt?.toIso8601String(),
      'updated_by': updatedBy,
      'updated_at': updatedAt?.toIso8601String(),
    };
  }
}

/// Employee Task Tracking model (for clock-in/out)
class EmployeeTaskTracking {
  final String trackingId;
  final String taskId;
  final String employeeId;
  final int employeeTaskStatus;
  final DateTime? startedAt;
  final DateTime? pausedAt;
  final DateTime? completedAt;
  final double totalHours;
  final String? sessionNotes;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  EmployeeTaskTracking({
    required this.trackingId,
    required this.taskId,
    required this.employeeId,
    this.employeeTaskStatus = 0,
    this.startedAt,
    this.pausedAt,
    this.completedAt,
    this.totalHours = 0.0,
    this.sessionNotes,
    this.createdAt,
    this.updatedAt,
  });

  factory EmployeeTaskTracking.fromMap(Map<String, dynamic> map) {
    // Helper to safely parse int values that might come as String or num
    int parseInt(dynamic value, [int defaultValue = 0]) {
      if (value == null) return defaultValue;
      if (value is num) return value.toInt();
      if (value is String) {
        return int.tryParse(value) ?? defaultValue;
      }
      return defaultValue;
    }

    // Helper to safely parse double values that might come as String or num
    double parseDouble(dynamic value, [double defaultValue = 0.0]) {
      if (value == null) return defaultValue;
      if (value is num) return value.toDouble();
      if (value is String) {
        return double.tryParse(value) ?? defaultValue;
      }
      return defaultValue;
    }

    return EmployeeTaskTracking(
      trackingId: map['tracking_id']?.toString() ?? '',
      taskId: map['task_id']?.toString() ?? '',
      employeeId: map['employee_id']?.toString() ?? '',
      employeeTaskStatus: parseInt(map['employee_task_status']),
      startedAt: map['started_at'] != null
          ? DateTime.tryParse(map['started_at'].toString())
          : null,
      pausedAt: map['paused_at'] != null
          ? DateTime.tryParse(map['paused_at'].toString())
          : null,
      completedAt: map['completed_at'] != null
          ? DateTime.tryParse(map['completed_at'].toString())
          : null,
      totalHours: parseDouble(map['total_hours']),
      sessionNotes: map['session_notes']?.toString(),
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString())
          : null,
      updatedAt: map['updated_at'] != null
          ? DateTime.tryParse(map['updated_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'tracking_id': trackingId,
      'task_id': taskId,
      'employee_id': employeeId,
      'employee_task_status': employeeTaskStatus,
      'started_at': startedAt?.toIso8601String(),
      'paused_at': pausedAt?.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
      'total_hours': totalHours,
      'session_notes': sessionNotes,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }
}
