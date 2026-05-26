import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import '../services/expense_service.dart';
import '../domain/models/expense.dart';
import '../core/response/api_response.dart';
import '../core/utils/logger.dart';

class ExpenseRoutes {
  final ExpenseService _service = ExpenseService();
  final AppLogger _logger = AppLogger('ExpenseRoutes');

  Router get router {
    final router = Router();
    router.get('/admin/expenses', _getAllExpenses);
    router.get('/admin/expenses/<id>', _getExpenseById);
    router.post('/admin/expenses', _createExpense);
    router.put('/admin/expenses/<id>', _updateExpense);
    router.delete('/admin/expenses/<id>', _deleteExpense);
    return router;
  }

  Future<Response> _getAllExpenses(Request request) async {
    try {
      // Parse query parameters
      final queryParams = request.url.queryParameters;
      final search = queryParams['search'];
      final expenseType =
          queryParams['expense_type'] ?? queryParams['expenseType'];
      final paymentMethod =
          queryParams['payment_method'] ?? queryParams['paymentMethod'];
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

      final (expenses, totalCount) = await _service.getAllExpenses(
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

      return ApiResponse.success(
        data: {
          'items': expenses.map((e) => e.toJson()).toList(),
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
      _logger.error('Error fetching expenses', e);
      return ApiResponse.error(
        code: 'FETCH_ERROR',
        message: e.toString(),
      ).toShelfResponse(statusCode: 500);
    }
  }

  Future<Response> _getExpenseById(Request request, String id) async {
    try {
      final item = await _service.getExpenseById(id);
      return ApiResponse.success(data: item.toJson()).toShelfResponse();
    } catch (e) {
      _logger.error('Error fetching expense $id', e);
      return ApiResponse.error(
        code: 'FETCH_ERROR',
        message: e.toString(),
      ).toShelfResponse(statusCode: 500);
    }
  }

  Future<Response> _createExpense(Request request) async {
    try {
      final payload = await request.readAsString();
      final data = jsonDecode(payload);
      final item = Expense.fromJson(data);
      final created = await _service.createExpense(item);
      return ApiResponse.success(
        data: created.toJson(),
      ).toShelfResponse(statusCode: 201);
    } catch (e) {
      _logger.error('Error creating expense', e);
      return ApiResponse.error(
        code: 'CREATE_ERROR',
        message: e.toString(),
      ).toShelfResponse(statusCode: 500);
    }
  }

  Future<Response> _updateExpense(Request request, String id) async {
    try {
      final payload = await request.readAsString();
      final updates = jsonDecode(payload) as Map<String, dynamic>;
      final updated = await _service.updateExpense(id, updates);
      return ApiResponse.success(data: updated.toJson()).toShelfResponse();
    } catch (e) {
      _logger.error('Error updating expense $id', e);
      return ApiResponse.error(
        code: 'UPDATE_ERROR',
        message: e.toString(),
      ).toShelfResponse(statusCode: 500);
    }
  }

  Future<Response> _deleteExpense(Request request, String id) async {
    try {
      await _service.deleteExpense(id);
      return ApiResponse.success(
        message: 'Expense deleted successfully',
      ).toShelfResponse();
    } catch (e) {
      _logger.error('Error deleting expense $id', e);
      return ApiResponse.error(
        code: 'DELETE_ERROR',
        message: e.toString(),
      ).toShelfResponse(statusCode: 500);
    }
  }
}
