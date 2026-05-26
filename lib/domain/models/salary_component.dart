class SalaryComponent {
  final String id;
  final String salaryRangeId;
  final String componentType;
  final String componentName;
  final double percentage;
  final double calculatedAmount;
  final int sortOrder;
  final bool isActive;
  final String? createdAt;
  final String? updatedAt;

  SalaryComponent({
    required this.id,
    required this.salaryRangeId,
    required this.componentType,
    required this.componentName,
    required this.percentage,
    required this.calculatedAmount,
    this.sortOrder = 0,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
  });

  factory SalaryComponent.fromMap(Map<String, dynamic> map) {
    return SalaryComponent(
      id: map['id']?.toString() ?? '',
      salaryRangeId: map['salary_range_id']?.toString() ?? '',
      componentType: map['component_type']?.toString() ?? '',
      componentName: map['component_name']?.toString() ?? '',
      percentage: double.tryParse(map['percentage']?.toString() ?? '0') ?? 0.0,
      calculatedAmount:
          double.tryParse(map['calculated_amount']?.toString() ?? '0') ?? 0.0,
      sortOrder: int.tryParse(map['sort_order']?.toString() ?? '0') ?? 0,
      isActive: map['is_active'] == true || map['is_active'] == 1,
      createdAt: map['created_at']?.toString(),
      updatedAt: map['updated_at']?.toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'salary_range_id': salaryRangeId,
      'component_type': componentType,
      'component_name': componentName,
      'percentage': percentage,
      'calculated_amount': calculatedAmount,
      'sort_order': sortOrder,
      'is_active': isActive,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }
}
