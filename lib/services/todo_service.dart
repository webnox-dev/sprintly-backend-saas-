import '../data/repositories/todo_repository.dart';
import '../domain/models/todo.dart';
import '../core/exceptions/app_exception.dart';
import '../core/utils/logger.dart';

class TodoService {
  final TodoRepository _repository = TodoRepository();
  final AppLogger _logger = AppLogger('TodoService');

  Future<(List<Todo>, int)> getAllTodos({
    String? search,
    String? status,
    String? priority,
    DateTime? startDate,
    DateTime? endDate,
    String? createdBy,
    int page = 1,
    int limit = 10,
    String? sortBy,
    String? sortOrder,
  }) async {
    try {
      return await _repository.getAllTodos(
        search: search,
        status: status,
        priority: priority,
        startDate: startDate,
        endDate: endDate,
        createdBy: createdBy,
        page: page,
        limit: limit,
        sortBy: sortBy,
        sortOrder: sortOrder,
      );
    } catch (e, stackTrace) {
      _logger.error('Error getting all todos: $e', e, stackTrace);
      rethrow;
    }
  }

  Future<List<Todo>> getTodosByEmployeeId(String employeeId) async {
    try {
      return await _repository.getTodosByEmployeeId(employeeId);
    } catch (e, stackTrace) {
      _logger.error('Error getting todos by employee: $e', e, stackTrace);
      rethrow;
    }
  }

  Future<List<Todo>> getTodosForDate(DateTime date) async {
    try {
      return await _repository.getTodosForDate(date);
    } catch (e, stackTrace) {
      _logger.error('Error getting todos for date: $e', e, stackTrace);
      rethrow;
    }
  }

  Future<Map<String, List<Todo>>> getTodosForDateRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      return await _repository.getTodosForDateRange(startDate, endDate);
    } catch (e, stackTrace) {
      _logger.error('Error getting todos for date range: $e', e, stackTrace);
      rethrow;
    }
  }

  Future<Todo> getTodoById(String id) async {
    try {
      final todo = await _repository.getTodoById(id);
      if (todo == null) {
        throw NotFoundException(resource: 'Todo', id: id);
      }
      return todo;
    } catch (e, stackTrace) {
      _logger.error('Error getting todo by ID: $e', e, stackTrace);
      rethrow;
    }
  }

  Future<Todo> createTodo(Todo todo) async {
    try {
      return await _repository.createTodo(todo);
    } catch (e, stackTrace) {
      _logger.error('Error creating todo: $e', e, stackTrace);
      rethrow;
    }
  }

  Future<Todo> updateTodo(String id, Map<String, dynamic> updates) async {
    try {
      final todo = await _repository.updateTodo(id, updates);
      if (todo == null) {
        throw NotFoundException(resource: 'Todo', id: id);
      }
      return todo;
    } catch (e, stackTrace) {
      _logger.error('Error updating todo: $e', e, stackTrace);
      rethrow;
    }
  }

  Future<bool> deleteTodo(String id) async {
    try {
      final success = await _repository.deleteTodo(id);
      if (!success) {
        throw NotFoundException(resource: 'Todo', id: id);
      }
      return success;
    } catch (e, stackTrace) {
      _logger.error('Error deleting todo: $e', e, stackTrace);
      rethrow;
    }
  }
}
