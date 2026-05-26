class Asset {
  final String? assetId;
  final String assetName;
  final String? assetDescription;
  final String assetType;
  final String assetStatus;
  final String assetModel;
  final String? assetConfiguration;
  final String? usedByEmployeeId;
  final String serialNumber;
  final String? imeiNumber;
  final String? createdBy;
  final DateTime? createdAt;
  final String? updatedBy;
  final DateTime? updatedAt;

  Asset({
    this.assetId,
    required this.assetName,
    this.assetDescription,
    required this.assetType,
    required this.assetStatus,
    required this.assetModel,
    this.assetConfiguration,
    this.usedByEmployeeId,
    required this.serialNumber,
    this.imeiNumber,
    this.createdBy,
    this.createdAt,
    this.updatedBy,
    this.updatedAt,
  });

  factory Asset.fromJson(Map<String, dynamic> json) {
    return Asset(
      assetId: json['asset_id'] as String?,
      assetName: json['asset_name'] as String? ?? '',
      assetDescription: json['asset_description'] as String?,
      assetType: json['asset_type'] as String? ?? 'Unknown',
      assetStatus: json['asset_status'] as String? ?? 'Unknown',
      assetModel: json['asset_model'] as String? ?? '',
      assetConfiguration: json['asset_configuration'] as String?,
      usedByEmployeeId: json['used_by_employee_id'] as String?,
      serialNumber: json['serial_number'] as String? ?? '',
      imeiNumber: json['imei_number'] as String?,
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
      'asset_id': assetId,
      'asset_name': assetName,
      'asset_description': assetDescription,
      'asset_type': assetType,
      'asset_status': assetStatus,
      'asset_model': assetModel,
      'asset_configuration': assetConfiguration,
      'used_by_employee_id': usedByEmployeeId,
      'serial_number': serialNumber,
      'imei_number': imeiNumber,
      'created_by': createdBy,
      'created_at': createdAt?.toIso8601String(),
      'updated_by': updatedBy,
      'updated_at': updatedAt?.toIso8601String(),
    };
  }
}
