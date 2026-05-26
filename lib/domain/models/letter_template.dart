class LetterTemplate {
  final String? id;
  final String templateType;
  final String templateName;
  final Map<String, dynamic> headerConfig;
  final Map<String, dynamic> footerConfig;
  final Map<String, dynamic> watermarkConfig;
  final String bodyContent;
  final List<String> placeholders;
  final bool isDefault;
  final bool isActive;
  final String? createdBy;
  final DateTime? createdAt;
  final String? updatedBy;
  final DateTime? updatedAt;

  LetterTemplate({
    this.id,
    required this.templateType,
    required this.templateName,
    this.headerConfig = const {},
    this.footerConfig = const {},
    this.watermarkConfig = const {},
    required this.bodyContent,
    this.placeholders = const [],
    this.isDefault = false,
    this.isActive = true,
    this.createdBy,
    this.createdAt,
    this.updatedBy,
    this.updatedAt,
  });

  factory LetterTemplate.fromMap(Map<String, dynamic> map) {
    return LetterTemplate(
      id: map['id'],
      templateType: map['template_type'],
      templateName: map['template_name'],
      headerConfig: map['header_config'] ?? {},
      footerConfig: map['footer_config'] ?? {},
      watermarkConfig: map['watermark_config'] ?? {},
      bodyContent: map['body_content'],
      placeholders: List<String>.from(map['placeholders'] ?? []),
      isDefault: map['is_default'] ?? false,
      isActive: map['is_active'] ?? true,
      createdBy: map['created_by'],
      createdAt: map['created_at'],
      updatedBy: map['updated_by'],
      updatedAt: map['updated_at'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'template_type': templateType,
      'template_name': templateName,
      'header_config': headerConfig,
      'footer_config': footerConfig,
      'watermark_config': watermarkConfig,
      'body_content': bodyContent,
      'placeholders': placeholders,
      'is_default': isDefault,
      'is_active': isActive,
      'created_by': createdBy,
      'updated_by': updatedBy,
    };
  }
}
