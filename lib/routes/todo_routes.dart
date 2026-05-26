import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import '../services/todo_service.dart';
import '../domain/models/todo.dart';
import '../core/response/api_response.dart';
import '../core/utils/logger.dart';

class TodoRoutes {
  final TodoService _service = TodoService();
  final AppLogger _logger = AppLogger('TodoRoutes');

  Router get router {
    final router = Router();
    router.get('/admin/todos', _getAllTodos);
    router.get('/admin/todos/employee/<employeeId>', _getTodosByEmployeeId);
    router.get('/admin/todos/date/<date>', _getTodosForDate);
    router.get('/admin/todos/calendar', _getTodosForDateRange);
    router.get('/admin/todos/<id>', _getTodoById);
    router.post('/admin/todos', _createTodo);
    router.put('/admin/todos/<id>', _updateTodo);
    router.delete('/admin/todos/<id>', _deleteTodo);
    return router;
  }

  Future<Response> _getAllTodos(Request request) async {
    try {
      // Parse query parameters
      final queryParams = request.url.queryParameters;
      final search = queryParams['search'];
      final status = queryParams['status'];
      final priority = queryParams['priority'];
      final createdBy = queryParams['created_by'] ?? queryParams['createdBy'];
      final page = int.tryParse(queryParams['page'] ?? '1') ?? 1;
      final limit = int.tryParse(queryParams['limit'] ?? '10') ?? 10;
      final sortBy = queryParams['sort_by'] ?? queryParams['sortBy'];
      final sortOrder = queryParams['sort_order'] ?? queryParams['sortOrder'];
      final startDateStr =
          queryParams['start_date'] ?? queryParams['startDate'];
      final endDateStr = queryParams['end_date'] ?? queryParams['endDate'];

      DateTime? startDate;
      DateTime? endDate;
      if (startDateStr != null) {
        startDate = DateTime.tryParse(startDateStr);
      }
      if (endDateStr != null) {
        endDate = DateTime.tryParse(endDateStr);
      }

      final (todos, totalCount) = await _service.getAllTodos(
        search: search,
        status: status,
        priority: priority,
        createdBy: createdBy,
        startDate: startDate,
        endDate: endDate,
        page: page,
        limit: limit,
        sortBy: sortBy,
        sortOrder: sortOrder,
      );

      return ApiResponse.success(
        data: {
          'items': todos.map((e) => e.toJson()).toList(),
          'pagination': {
            'page': page,
            'limit': limit,
            'total': totalCount,
            'totalPages': (totalCount / limit).ceil(),
            'hasMore': page * limit < totalCount,
          },
        },
      ).toShelfResponse();
    } catch (e) {
      _logger.error('Error fetching todos', e);
      return ApiResponse.error(
        code: 'FETCH_ERROR',
        message: e.toString(),
      ).toShelfResponse(statusCode: 500);
    }
  }

  Future<Response> _getTodosByEmployeeId(
    Request request,
    String employeeId,
  ) async {
    try {
      final list = await _service.getTodosByEmployeeId(employeeId);
      return ApiResponse.success(
        data: list.map((e) => e.toJson()).toList(),
      ).toShelfResponse();
    } catch (e) {
      _logger.error('Error fetching todos for employee $employeeId', e);
      return ApiResponse.error(
        code: 'FETCH_ERROR',
        message: e.toString(),
      ).toShelfResponse(statusCode: 500);
    }
  }

  Future<Response> _getTodosForDate(Request request, String date) async {
    try {
      final parsedDate = DateTime.tryParse(date);
      if (parsedDate == null) {
        return ApiResponse.error(
          code: 'INVALID_DATE',
          message: 'Invalid date format. Use YYYY-MM-DD.',
        ).toShelfResponse(statusCode: 400);
      }

      final todos = await _service.getTodosForDate(parsedDate);
      return ApiResponse.success(
        data: todos.map((e) => e.toJson()).toList(),
      ).toShelfResponse();
    } catch (e) {
      _logger.error('Error fetching todos for date $date', e);
      return ApiResponse.error(
        code: 'FETCH_ERROR',
        message: e.toString(),
      ).toShelfResponse(statusCode: 500);
    }
  }

  Future<Response> _getTodosForDateRange(Request request) async {
    try {
      final queryParams = request.url.queryParameters;
      final startDateStr =
          queryParams['start_date'] ?? queryParams['startDate'];
      final endDateStr = queryParams['end_date'] ?? queryParams['endDate'];

      if (startDateStr == null || endDateStr == null) {
        return ApiResponse.error(
          code: 'MISSING_PARAMS',
          message: 'start_date and end_date are required.',
        ).toShelfResponse(statusCode: 400);
      }

      final startDate = DateTime.tryParse(startDateStr);
      final endDate = DateTime.tryParse(endDateStr);

      if (startDate == null || endDate == null) {
        return ApiResponse.error(
          code: 'INVALID_DATE',
          message: 'Invalid date format. Use YYYY-MM-DD.',
        ).toShelfResponse(statusCode: 400);
      }

      final grouped = await _service.getTodosForDateRange(startDate, endDate);

      // Convert to JSON-friendly format
      final data = <String, dynamic>{};
      grouped.forEach((date, todos) {
        data[date] = todos.map((e) => e.toJson()).toList();
      });

      return ApiResponse.success(data: data).toShelfResponse();
    } catch (e) {
      _logger.error('Error fetching todos for date range', e);
      return ApiResponse.error(
        code: 'FETCH_ERROR',
        message: e.toString(),
      ).toShelfResponse(statusCode: 500);
    }
  }

  Future<Response> _getTodoById(Request request, String id) async {
    try {
      final item = await _service.getTodoById(id);
      return ApiResponse.success(data: item.toJson()).toShelfResponse();
    } catch (e) {
      _logger.error('Error fetching todo $id', e);
      return ApiResponse.error(
        code: 'FETCH_ERROR',
        message: e.toString(),
      ).toShelfResponse(statusCode: 500);
    }
  }

  Future<Response> _createTodo(Request request) async {
    try {
      final payload = await request.readAsString();
      final data = jsonDecode(payload) as Map<String, dynamic>;

      // Validation: todo_title is required
      final title = data['todo_title'] ?? data['title'];
      if (title == null || (title as String).trim().isEmpty) {
        return ApiResponse.error(
          code: 'VALIDATION_ERROR',
          message: 'Title is required',
        ).toShelfResponse(statusCode: 400);
      }

      // Validation: due_date is required
      final dueDate = data['due_date'];
      if (dueDate == null || (dueDate as String).isEmpty) {
        return ApiResponse.error(
          code: 'VALIDATION_ERROR',
          message: 'Due date is required',
        ).toShelfResponse(statusCode: 400);
      }

      final item = Todo.fromJson(data);
      final created = await _service.createTodo(item);
      return ApiResponse.success(
        data: created.toJson(),
      ).toShelfResponse(statusCode: 201);
    } catch (e) {
      _logger.error('Error creating todo', e);
      return ApiResponse.error(
        code: 'CREATE_ERROR',
        message: e.toString(),
      ).toShelfResponse(statusCode: 500);
    }
  }

  Future<Response> _updateTodo(Request request, String id) async {
    try {
      final payload = await request.readAsString();
      final updates = jsonDecode(payload) as Map<String, dynamic>;
      final updated = await _service.updateTodo(id, updates);
      return ApiResponse.success(data: updated.toJson()).toShelfResponse();
    } catch (e) {
      _logger.error('Error updating todo $id', e);
      return ApiResponse.error(
        code: 'UPDATE_ERROR',
        message: e.toString(),
      ).toShelfResponse(statusCode: 500);
    }
  }

  Future<Response> _deleteTodo(Request request, String id) async {
    try {
      await _service.deleteTodo(id);
      return ApiResponse.success(
        message: 'Todo deleted successfully',
      ).toShelfResponse();
    } catch (e) {
      _logger.error('Error deleting todo $id', e);
      return ApiResponse.error(
        code: 'DELETE_ERROR',
        message: e.toString(),
      ).toShelfResponse(statusCode: 500);
    }
  }
}
