import 'dart:convert';
import '../../domain/models/expense.dart';
import '../database/connection.dart';

class ExpenseRepository {
  /// Get all expenses with server-side search, filter, and pagination
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
    // Build WHERE clauses
    final whereClauses = <String>[];
    final values = <String, dynamic>{};

    // Search filter
    if (search != null && search.isNotEmpty) {
      whereClauses.add(
        "(LOWER(expense_name) LIKE @search OR LOWER(expense_description) LIKE @search OR LOWER(paid_by) LIKE @search)",
      );
      values['search'] = '%${search.toLowerCase()}%';
    }

    // Expense type filter
    if (expenseType != null && expenseType.isNotEmpty) {
      whereClauses.add("expense_type = @expenseType");
      values['expenseType'] = expenseType;
    }

    // Payment method filter
    if (paymentMethod != null && paymentMethod.isNotEmpty) {
      whereClauses.add("expense_trans = @paymentMethod");
      values['paymentMethod'] = paymentMethod;
    }

    // Date range filter
    if (startDate != null) {
      whereClauses.add("expense_date >= @startDate");
      values['startDate'] = startDate.toIso8601String().split('T')[0];
    }
    if (endDate != null) {
      whereClauses.add("expense_date <= @endDate");
      values['endDate'] = endDate.toIso8601String().split('T')[0];
    }

    final whereClause = whereClauses.isNotEmpty
        ? 'WHERE ${whereClauses.join(' AND ')}'
        : '';

    // Sorting
    final validSortColumns = [
      'expense_name',
      'expense_date',
      'expense_amount',
      'expense_type',
      'created_at',
    ];
    final sortColumn = validSortColumns.contains(sortBy)
        ? sortBy
        : 'expense_date';
    final order = sortOrder?.toUpperCase() == 'ASC' ? 'ASC' : 'DESC';

    // Get total count
    final countResult = await DatabaseConnection.query(
      'SELECT COUNT(*) as count FROM expenses $whereClause',
      values: values,
    );
    final totalCount = (countResult.first['count'] as int?) ?? 0;

    // Pagination
    final offset = (page - 1) * limit;
    values['limit'] = limit;
    values['offset'] = offset;

    // Get paginated results
    final result = await DatabaseConnection.query('''
      SELECT * FROM expenses 
      $whereClause 
      ORDER BY $sortColumn $order 
      LIMIT @limit OFFSET @offset
      ''', values: values);

    final expenses = result.map((row) => Expense.fromJson(row)).toList();
    return (expenses, totalCount);
  }

  Future<Expense?> getExpenseById(String id) async {
    final result = await DatabaseConnection.query(
      'SELECT * FROM expenses WHERE expense_id = @id',
      values: {'id': id},
    );
    if (result.isEmpty) return null;
    return Expense.fromJson(result.first);
  }

  Future<Expense> createExpense(Expense expense) async {
    final result = await DatabaseConnection.query(
      '''
      INSERT INTO expenses (
        expense_name, expense_trans, expense_amount, expense_type, 
        paid_by, expense_date, expense_description, expense_receipts, 
        created_by
      ) VALUES (
        @name, @trans, @amount, @type, 
        @paidBy, @date, @description, @receipts, 
        @createdBy
      ) RETURNING *
      ''',
      values: {
        'name': expense.expenseName,
        'trans': expense.expenseTrans,
        'amount': expense.expenseAmount,
        'type': expense.expenseType,
        'paidBy': expense.paidBy,
        'date': expense.expenseDate,
        'description': expense.expenseDescription,
        'receipts': jsonEncode(expense.expenseReceipts ?? []),
        'createdBy': expense.createdBy,
      },
    );
    return Expense.fromJson(result.first);
  }

  Future<Expense?> updateExpense(
    String id,
    Map<String, dynamic> updates,
  ) async {
    final setClauses = <String>[];
    final values = <String, dynamic>{'id': id};

    updates.forEach((key, value) {
      if (key != 'expense_id' && key != 'created_at' && key != 'updated_at') {
        setClauses.add('$key = @$key');
        if (key == 'expense_receipts' && value is List) {
          values[key] = jsonEncode(value);
        } else {
          values[key] = value;
        }
      }
    });

    if (setClauses.isEmpty) return await getExpenseById(id);

    final query =
        '''
      UPDATE expenses 
      SET ${setClauses.join(', ')} 
      WHERE expense_id = @id 
      RETURNING *
    ''';

    final result = await DatabaseConnection.query(query, values: values);
    if (result.isEmpty) return null;
    return Expense.fromJson(result.first);
  }

  Future<bool> deleteExpense(String id) async {
    final count = await DatabaseConnection.execute(
      'DELETE FROM expenses WHERE expense_id = @id',
      values: {'id': id},
    );
    return count > 0;
  }
}
