import 'salary_component.dart';

class SalaryRange {
  final String id;
  final String? rangeName;
  final double salaryStart;
  final double salaryEnd;
  final bool isActive;
  final String? createdBy;
  final String? createdAt;
  final String? updatedBy;
  final String? updatedAt;
  final List<SalaryComponent> earnings;
  final List<SalaryComponent> deductions;

  SalaryRange({
    required this.id,
    this.rangeName,
    required this.salaryStart,
    required this.salaryEnd,
    this.isActive = true,
    this.createdBy,
    this.createdAt,
    this.updatedBy,
    this.updatedAt,
    this.earnings = const [],
    this.deductions = const [],
  });

  factory SalaryRange.fromMap(Map<String, dynamic> map) {
    return SalaryRange(
      id: map['id']?.toString() ?? '',
      rangeName: map['range_name']?.toString(),
      salaryStart:
          double.tryParse(map['salary_start']?.toString() ?? '0') ?? 0.0,
      salaryEnd: double.tryParse(map['salary_end']?.toString() ?? '0') ?? 0.0,
      isActive: map['is_active'] == true || map['is_active'] == 1,
      createdBy: map['created_by']?.toString(),
      createdAt: map['created_at']?.toString(),
      updatedBy: map['updated_by']?.toString(),
      updatedAt: map['updated_at']?.toString(),
      earnings: map['earnings'] != null
          ? List<SalaryComponent>.from(
              (map['earnings'] as List).map((x) => SalaryComponent.fromMap(x)),
            )
          : [],
      deductions: map['deductions'] != null
          ? List<SalaryComponent>.from(
              (map['deductions'] as List).map(
                (x) => SalaryComponent.fromMap(x),
              ),
            )
          : [],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'range_name': rangeName,
      'salary_start': salaryStart,
      'salary_end': salaryEnd,
      'is_active': isActive,
      'created_by': createdBy,
      'created_at': createdAt,
      'updated_by': updatedBy,
      'updated_at': updatedAt,
      'earnings': earnings.map((e) => e.toMap()).toList(),
      'deductions': deductions.map((e) => e.toMap()).toList(),
    };
  }

  double get totalEarnings =>
      earnings.fold(0, (sum, item) => sum + item.calculatedAmount);
  double get totalDeductions =>
      deductions.fold(0, (sum, item) => sum + item.calculatedAmount);
  double get netSalary => totalEarnings - totalDeductions;
}
