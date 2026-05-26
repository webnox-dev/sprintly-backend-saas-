import '../data/repositories/expense_repository.dart';
import '../domain/models/expense.dart';
import '../core/exceptions/app_exception.dart';
import '../core/utils/logger.dart';

class ExpenseService {
  final ExpenseRepository _repository = ExpenseRepository();
  final AppLogger _logger = AppLogger('ExpenseService');

  Future<(List<Expense>, int)> getAllExpenses({
    String? search,
    String? expenseType,
    String? paymentMethod,
    DateTime? startDate,
    DateTime? endDate,
    int page = 1,
    int limit = 10,
    String? sortBy,
    String? sortOrder,
  }) async {
    try {
      return await _repository.getAllExpenses(
        search: search,
        expenseType: expenseType,
        paymentMethod: paymentMethod,
        startDate: startDate,
        endDate: endDate,
        page: page,
        limit: limit,
        sortBy: sortBy,
        sortOrder: sortOrder,
      );
    } catch (e, stackTrace) {
      _logger.error('Error getting all expenses: $e', e, stackTrace);
      rethrow;
    }
  }

  Future<Expense> getExpenseById(String id) async {
    try {
      final expense = await _repository.getExpenseById(id);
      if (expense == null) {
        throw NotFoundException(resource: 'Expense', id: id);
      }
      return expense;
    } catch (e, stackTrace) {
      _logger.error('Error getting expense by ID: $e', e, stackTrace);
      rethrow;
    }
  }

  Future<Expense> createExpense(Expense expense) async {
    try {
      return await _repository.createExpense(expense);
    } catch (e, stackTrace) {
      _logger.error('Error creating expense: $e', e, stackTrace);
      rethrow;
    }
  }

  Future<Expense> updateExpense(String id, Map<String, dynamic> updates) async {
    try {
      final expense = await _repository.updateExpense(id, updates);
      if (expense == null) {
        throw NotFoundException(resource: 'Expense', id: id);
      }
      return expense;
    } catch (e, stackTrace) {
      _logger.error('Error updating expense: $e', e, stackTrace);
      rethrow;
    }
  }

  Future<bool> deleteExpense(String id) async {
    try {
      final success = await _repository.deleteExpense(id);
      if (!success) {
        throw NotFoundException(resource: 'Expense', id: id);
      }
      return success;
    } catch (e, stackTrace) {
      _logger.error('Error deleting expense: $e', e, stackTrace);
      rethrow;
    }
  }
}
