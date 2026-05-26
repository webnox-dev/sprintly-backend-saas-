class Role {
  final String? roleId;
  final String roleName;
  final List<String> designations;
  final bool isActive;
  final String? createdBy;
  final String? updatedBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Role({
    this.roleId,
    required this.roleName,
    this.designations = const [],
    this.isActive = true,
    this.createdBy,
    this.updatedBy,
    this.createdAt,
    this.updatedAt,
  });

  factory Role.fromJson(Map<String, dynamic> json) {
    // Handle designations which could be a PostgreSQL array string or dynamic list
    List<String> parseDesignations(dynamic d) {
      if (d == null) return [];
      if (d is List) return d.cast<String>();
      if (d is String) {
        // Handle postgres array format {item1,item2} if needed,
        // though the driver usually handles this.
        return d
            .replaceAll('{', '')
            .replaceAll('}', '')
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();
      }
      return [];
    }

    return Role(
      roleId: json['role_id']?.toString(),
      roleName: json['role_name']?.toString() ?? '',
      designations: parseDesignations(json['designations']),
      isActive: json['is_active'] == true || json['is_active'] == 1,
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
      if (roleId != null) 'role_id': roleId,
      'role_name': roleName,
      'designations': designations,
      'is_active': isActive,
      if (createdBy != null) 'created_by': createdBy,
      if (updatedBy != null) 'updated_by': updatedBy,
      if (createdAt != null) 'created_at': createdAt?.toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt?.toIso8601String(),
    };
  }
}
