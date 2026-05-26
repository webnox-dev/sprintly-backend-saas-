import 'dart:convert';

/// TaskCardRequest model for task card request flow
class TaskCardRequest {
  final String requestId;
  final String? taskId;
  final String employeeId;
  final String? projectId;
  // Task request data
  final String? taskName;
  final String? taskDescription;
  final String? taskDuration;
  final String? taskType;
  final String? priorityLevel;
  final String? workflowStatus;
  final DateTime? fromDate;
  final DateTime? toDate;
  final List<dynamic>? taskAttachments;
  final Map<String, dynamic>? projectDetails;
  final Map<String, dynamic>? employeeDetails;
  // Request flow fields
  final String requestedBy;
  final DateTime? requestedOn;
  final String? approvedRejectedBy;
  final DateTime? approvedRejectedAt;
  final String? approvedRejectedReason;
  final String requestStatus;
  // Audit
  final DateTime? createdAt;
  final DateTime? updatedAt;

  TaskCardRequest({
    required this.requestId,
    this.taskId,
    required this.employeeId,
    this.projectId,
    this.taskName,
    this.taskDescription,
    this.taskDuration,
    this.taskType,
    this.priorityLevel,
    this.workflowStatus = 'TODO',
    this.fromDate,
    this.toDate,
    this.taskAttachments,
    this.projectDetails,
    this.employeeDetails,
    required this.requestedBy,
    this.requestedOn,
    this.approvedRejectedBy,
    this.approvedRejectedAt,
    this.approvedRejectedReason,
    this.requestStatus = 'pending',
    this.createdAt,
    this.updatedAt,
  });

  factory TaskCardRequest.fromMap(Map<String, dynamic> map) {
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

    return TaskCardRequest(
      requestId: map['request_id']?.toString() ?? '',
      taskId: map['task_id']?.toString(),
      employeeId: map['employee_id']?.toString() ?? '',
      projectId: map['project_id']?.toString(),
      taskName: map['task_name']?.toString(),
      taskDescription: map['task_description']?.toString(),
      taskDuration: map['task_duration']?.toString(),
      taskType: map['task_type']?.toString(),
      priorityLevel: map['priority_level']?.toString(),
      workflowStatus: map['workflow_status']?.toString() ?? 'TODO',
      fromDate: map['from_date'] != null
          ? DateTime.tryParse(map['from_date'].toString())
          : null,
      toDate: map['to_date'] != null
          ? DateTime.tryParse(map['to_date'].toString())
          : null,
      taskAttachments: parseJsonArray(map['task_attachments']),
      projectDetails:
          parseJson(map['project_details']) as Map<String, dynamic>?,
      employeeDetails:
          parseJson(map['employee_details']) as Map<String, dynamic>?,
      requestedBy: map['requested_by']?.toString() ?? '',
      requestedOn: map['requested_on'] != null
          ? DateTime.tryParse(map['requested_on'].toString())
          : null,
      approvedRejectedBy: map['approved_rejected_by']?.toString(),
      approvedRejectedAt: map['approved_rejected_at'] != null
          ? DateTime.tryParse(map['approved_rejected_at'].toString())
          : null,
      approvedRejectedReason: map['approved_rejected_reason']?.toString(),
      requestStatus: map['request_status']?.toString() ?? 'pending',
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
      'request_id': requestId,
      'task_id': taskId,
      'employee_id': employeeId,
      'project_id': projectId,
      'task_name': taskName,
      'task_description': taskDescription,
      'task_duration': taskDuration,
      'task_type': taskType,
      'priority_level': priorityLevel,
      'workflow_status': workflowStatus,
      'from_date': fromDate?.toIso8601String().split('T')[0],
      'to_date': toDate?.toIso8601String().split('T')[0],
      'task_attachments': taskAttachments,
      'project_details': projectDetails,
      'employee_details': employeeDetails,
      'requested_by': requestedBy,
      'requested_on': requestedOn?.toIso8601String(),
      'approved_rejected_by': approvedRejectedBy,
      'approved_rejected_at': approvedRejectedAt?.toIso8601String(),
      'approved_rejected_reason': approvedRejectedReason,
      'request_status': requestStatus,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  /// Check if request is approved
  bool get isApproved => requestStatus.toLowerCase() == 'approved';

  /// Check if request is rejected
  bool get isRejected => requestStatus.toLowerCase() == 'rejected';

  /// Check if request is pending
  bool get isPending => requestStatus.toLowerCase() == 'pending';
}
