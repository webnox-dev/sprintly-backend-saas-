class CertificateContentTemplate {
  final String? id;
  final String certificateType;
  final String role;
  final String? designation;
  final String bodyContent;
  final String templateName;
  final bool isDefault;
  final bool isActive;
  final String? createdBy;
  final DateTime? createdAt;
  final String? updatedBy;
  final DateTime? updatedAt;

  CertificateContentTemplate({
    this.id,
    required this.certificateType,
    required this.role,
    this.designation,
    required this.bodyContent,
    required this.templateName,
    this.isDefault = false,
    this.isActive = true,
    this.createdBy,
    this.createdAt,
    this.updatedBy,
    this.updatedAt,
  });

  factory CertificateContentTemplate.fromMap(Map<String, dynamic> map) {
    return CertificateContentTemplate(
      id: map['id'],
      certificateType: map['certificate_type'],
      role: map['role'],
      designation: map['designation'],
      bodyContent: map['body_content'],
      templateName: map['template_name'],
      isDefault: map['is_default'] ?? false,
      isActive: map['is_active'] ?? true,
      createdBy: map['created_by'],
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'].toString())
          : null,
      updatedBy: map['updated_by'],
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'certificate_type': certificateType,
      'role': role,
      'designation': designation,
      'body_content': bodyContent,
      'template_name': templateName,
      'is_default': isDefault,
      'is_active': isActive,
      if (createdBy != null) 'created_by': createdBy,
      if (createdAt != null) 'created_at': createdAt?.toIso8601String(),
      if (updatedBy != null) 'updated_by': updatedBy,
      if (updatedAt != null) 'updated_at': updatedAt?.toIso8601String(),
    };
  }

  CertificateContentTemplate copyWith({
    String? id,
    String? certificateType,
    String? role,
    String? designation,
    String? bodyContent,
    String? templateName,
    bool? isDefault,
    bool? isActive,
    String? createdBy,
    DateTime? createdAt,
    String? updatedBy,
    DateTime? updatedAt,
  }) {
    return CertificateContentTemplate(
      id: id ?? this.id,
      certificateType: certificateType ?? this.certificateType,
      role: role ?? this.role,
      designation: designation ?? this.designation,
      bodyContent: bodyContent ?? this.bodyContent,
      templateName: templateName ?? this.templateName,
      isDefault: isDefault ?? this.isDefault,
      isActive: isActive ?? this.isActive,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedBy: updatedBy ?? this.updatedBy,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
