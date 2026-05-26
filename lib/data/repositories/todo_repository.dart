import '../../domain/models/todo.dart';
import '../database/connection.dart';

class TodoRepository {
  /// Get all todos with server-side search, filter, and pagination
  Future<(List<Todo>, int)> getAllTodos({
    String? search,
    String? status, // 'pending', 'completed', 'all'
    String? priority, // 'low', 'medium', 'high', 'all'
    DateTime? startDate,
    DateTime? endDate,
    String? createdBy,
    int page = 1,
    int limit = 10,
    String? sortBy,
    String? sortOrder,
  }) async {
    // Build WHERE clauses
    final whereClauses = <String>[];
    final values = <String, dynamic>{};

    // Search filter
    if (search != null && search.isNotEmpty) {
      whereClauses.add(
        "(LOWER(todo_title) LIKE @search OR LOWER(todo_description) LIKE @search)",
      );
      values['search'] = '%${search.toLowerCase()}%';
    }

    // Status filter
    if (status != null && status != 'all') {
      whereClauses.add("todo_status = @status");
      values['status'] = status;
    }

    // Priority filter
    if (priority != null && priority != 'all') {
      whereClauses.add("todo_priority = @priority");
      values['priority'] = priority;
    }

    // Creator filter
    if (createdBy != null && createdBy.isNotEmpty) {
      whereClauses.add("created_by = @createdBy");
      values['createdBy'] = createdBy;
    }

    // Date range filter (for due_date)
    if (startDate != null) {
      whereClauses.add("due_date >= @startDate");
      values['startDate'] = startDate.toIso8601String().split('T')[0];
    }
    if (endDate != null) {
      whereClauses.add("due_date <= @endDate");
      values['endDate'] = endDate.toIso8601String().split('T')[0];
    }

    final whereClause = whereClauses.isNotEmpty
        ? 'WHERE ${whereClauses.join(' AND ')}'
        : '';

    // Sorting
    final validSortColumns = [
      'todo_title',
      'due_date',
      'todo_priority',
      'todo_status',
      'created_at',
    ];
    final sortColumn = validSortColumns.contains(sortBy)
        ? sortBy
        : 'created_at';
    final order = sortOrder?.toUpperCase() == 'ASC' ? 'ASC' : 'DESC';

    // Get total count
    final countResult = await DatabaseConnection.query(
      'SELECT COUNT(*) as count FROM todos $whereClause',
      values: values,
    );
    final totalCount = (countResult.first['count'] as int?) ?? 0;

    // Pagination
    final offset = (page - 1) * limit;
    values['limit'] = limit;
    values['offset'] = offset;

    // Get paginated results
    final result = await DatabaseConnection.query('''
      SELECT * FROM todos 
      $whereClause 
      ORDER BY $sortColumn $order 
      LIMIT @limit OFFSET @offset
      ''', values: values);

    final todos = result.map((row) => Todo.fromJson(row)).toList();
    return (todos, totalCount);
  }

  Future<List<Todo>> getTodosByEmployeeId(String employeeId) async {
    final result = await DatabaseConnection.query(
      'SELECT * FROM todos WHERE created_by = @employeeId ORDER BY created_at DESC',
      values: {'employeeId': employeeId},
    );
    return result.map((row) => Todo.fromJson(row)).toList();
  }

  /// Get todos for a specific date (for calendar view)
  Future<List<Todo>> getTodosForDate(DateTime date) async {
    final dateStr = date.toIso8601String().split('T')[0];
    final result = await DatabaseConnection.query(
      'SELECT * FROM todos WHERE due_date = @date ORDER BY due_time ASC, todo_priority DESC',
      values: {'date': dateStr},
    );
    return result.map((row) => Todo.fromJson(row)).toList();
  }

  /// Get todos for a date range (for calendar month view)
  Future<Map<String, List<Todo>>> getTodosForDateRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    final startStr = startDate.toIso8601String().split('T')[0];
    final endStr = endDate.toIso8601String().split('T')[0];

    final result = await DatabaseConnection.query(
      '''
      SELECT * FROM todos 
      WHERE due_date >= @startDate AND due_date <= @endDate 
      ORDER BY due_date ASC, due_time ASC
      ''',
      values: {'startDate': startStr, 'endDate': endStr},
    );

    // Group by date
    final Map<String, List<Todo>> grouped = {};
    for (final row in result) {
      final todo = Todo.fromJson(row);
      final dateKey = todo.dueDate ?? '';
      if (dateKey.isNotEmpty) {
        grouped.putIfAbsent(dateKey, () => []);
        grouped[dateKey]!.add(todo);
      }
    }
    return grouped;
  }

  Future<Todo?> getTodoById(String id) async {
    final result = await DatabaseConnection.query(
      'SELECT * FROM todos WHERE todo_id = @id',
      values: {'id': id},
    );
    if (result.isEmpty) return null;
    return Todo.fromJson(result.first);
  }

  Future<Todo> createTodo(Todo todo) async {
    final result = await DatabaseConnection.query(
      '''
      INSERT INTO todos (
        todo_title, todo_description, created_by, due_date, due_time, 
        is_reminder_set, todo_status, todo_priority
      ) VALUES (
        @title, @description, @createdBy, @dueDate, @dueTime, 
        @isReminder, @status, @priority
      ) RETURNING *
      ''',
      values: {
        'title': todo.todoTitle,
        'description': todo.todoDescription,
        'createdBy': todo.createdBy,
        'dueDate': todo.dueDate,
        'dueTime': todo.dueTime,
        'isReminder': todo.isReminderSet,
        'status': todo.todoStatus,
        'priority': todo.todoPriority,
      },
    );
    return Todo.fromJson(result.first);
  }

  Future<Todo?> updateTodo(String id, Map<String, dynamic> updates) async {
    final setClauses = <String>[];
    final values = <String, dynamic>{'id': id};

    updates.forEach((key, value) {
      if (key != 'todo_id' && key != 'created_at' && key != 'updated_at') {
        setClauses.add('$key = @$key');
        values[key] = value;
      }
    });

    if (setClauses.isEmpty) return await getTodoById(id);

    final query =
        '''
      UPDATE todos 
      SET ${setClauses.join(', ')} 
      WHERE todo_id = @id 
      RETURNING *
    ''';

    final result = await DatabaseConnection.query(query, values: values);
    if (result.isEmpty) return null;
    return Todo.fromJson(result.first);
  }

  Future<bool> deleteTodo(String id) async {
    final count = await DatabaseConnection.execute(
      'DELETE FROM todos WHERE todo_id = @id',
      values: {'id': id},
    );
    return count > 0;
  }
}
