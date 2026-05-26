class Expense {
  final String? expenseId;
  final String? expenseName;
  final String? expenseTrans;
  final double? expenseAmount;
  final String? expenseType;
  final String? paidBy;
  final DateTime? expenseDate;
  final String? expenseDescription;
  final List<String>? expenseReceipts;
  final String? createdBy;
  final DateTime? createdAt;
  final String? updatedBy;
  final DateTime? updatedAt;

  Expense({
    this.expenseId,
    this.expenseName,
    this.expenseTrans,
    this.expenseAmount,
    this.expenseType,
    this.paidBy,
    this.expenseDate,
    this.expenseDescription,
    this.expenseReceipts,
    this.createdBy,
    this.createdAt,
    this.updatedBy,
    this.updatedAt,
  });

  factory Expense.fromJson(Map<String, dynamic> json) {
    return Expense(
      expenseId: json['expense_id'] as String?,
      expenseName: json['expense_name'] as String?,
      expenseTrans: json['expense_trans'] as String?,
      expenseAmount: json['expense_amount'] != null
          ? double.tryParse(json['expense_amount'].toString())
          : null,
      expenseType: json['expense_type'] as String?,
      paidBy: json['paid_by'] as String?,
      expenseDate: json['expense_date'] != null
          ? DateTime.parse(json['expense_date'].toString())
          : null,
      expenseDescription: json['expense_description'] as String?,
      expenseReceipts: (json['expense_receipts'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList(),
      createdBy: json['created_by'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'].toString())
          : null,
      updatedBy: json['updated_by'] as String?,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'expense_id': expenseId,
      'expense_name': expenseName,
      'expense_trans': expenseTrans,
      'expense_amount': expenseAmount,
      'expense_type': expenseType,
      'paid_by': paidBy,
      'expense_date': expenseDate?.toIso8601String(),
      'expense_description': expenseDescription,
      'expense_receipts': expenseReceipts,
      'created_by': createdBy,
      'created_at': createdAt?.toIso8601String(),
      'updated_by': updatedBy,
      'updated_at': updatedAt?.toIso8601String(),
    };
  }
}
