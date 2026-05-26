class FuturePlan {
  final String? planId;
  final String title;
  final String? plan;
  final String? createdBy;
  final String? updatedBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  FuturePlan({
    this.planId,
    required this.title,
    this.plan,
    this.createdBy,
    this.updatedBy,
    this.createdAt,
    this.updatedAt,
  });

  factory FuturePlan.fromJson(Map<String, dynamic> json) {
    return FuturePlan(
      planId: json['plan_id']?.toString(),
      title: json['title']?.toString() ?? '',
      plan: json['plan']?.toString(),
      createdBy: json['created_by']?.toString(),
      updatedBy: json['updated_by']?.toString(),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (planId != null) 'plan_id': planId,
      'title': title,
      'plan': plan,
      if (createdBy != null) 'created_by': createdBy,
      if (updatedBy != null) 'updated_by': updatedBy,
      if (createdAt != null) 'created_at': createdAt?.toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt?.toIso8601String(),
    };
  }
}
