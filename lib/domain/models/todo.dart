class Todo {
  final String? todoId;
  final String todoTitle;
  final String? todoDescription;
  final String createdBy;
  final DateTime? createdAt;
  final String? updatedBy;
  final DateTime? updatedAt;
  final String? dueDate;
  final String? dueTime;
  final bool isReminderSet;
  final String todoStatus;
  final String todoPriority;

  Todo({
    this.todoId,
    required this.todoTitle,
    this.todoDescription,
    required this.createdBy,
    this.createdAt,
    this.updatedBy,
    this.updatedAt,
    this.dueDate,
    this.dueTime,
    this.isReminderSet = false,
    this.todoStatus = 'pending',
    this.todoPriority = 'medium',
  });

  factory Todo.fromJson(Map<String, dynamic> json) {
    return Todo(
      todoId: json['todo_id'] as String?,
      todoTitle: json['todo_title'] as String? ?? '',
      todoDescription: json['todo_description'] as String?,
      createdBy: json['created_by'] as String? ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'].toString())
          : null,
      updatedBy: json['updated_by'] as String?,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'].toString())
          : null,
      dueDate: json['due_date']?.toString(),
      dueTime: json['due_time']?.toString(),
      isReminderSet:
          json['is_reminder_set'] == true || json['is_reminder_set'] == 1,
      todoStatus: json['todo_status'] as String? ?? 'pending',
      todoPriority: json['todo_priority'] as String? ?? 'medium',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'todo_id': todoId,
      'todo_title': todoTitle,
      'todo_description': todoDescription,
      'created_by': createdBy,
      'created_at': createdAt?.toIso8601String(),
      'updated_by': updatedBy,
      'updated_at': updatedAt?.toIso8601String(),
      'due_date': dueDate,
      'due_time': dueTime,
      'is_reminder_set': isReminderSet,
      'todo_status': todoStatus,
      'todo_priority': todoPriority,
    };
  }
}
