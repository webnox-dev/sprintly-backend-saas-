class VersionRelease {
  final String? releaseId;
  final String versionNumber;
  final String? releaseNotes;
  final DateTime? releaseDate;
  final String? createdBy;
  final String? updatedBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  VersionRelease({
    this.releaseId,
    required this.versionNumber,
    this.releaseNotes,
    this.releaseDate,
    this.createdBy,
    this.updatedBy,
    this.createdAt,
    this.updatedAt,
  });

  factory VersionRelease.fromJson(Map<String, dynamic> json) {
    return VersionRelease(
      releaseId: json['release_id']?.toString(),
      versionNumber: json['version_number']?.toString() ?? '',
      releaseNotes: json['release_notes']?.toString(),
      releaseDate: json['release_date'] != null
          ? DateTime.tryParse(json['release_date'].toString())
          : null,
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
      if (releaseId != null) 'release_id': releaseId,
      'version_number': versionNumber,
      'release_notes': releaseNotes,
      'release_date': releaseDate?.toIso8601String().split('T')[0],
      if (createdBy != null) 'created_by': createdBy,
      if (updatedBy != null) 'updated_by': updatedBy,
      if (createdAt != null) 'created_at': createdAt?.toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt?.toIso8601String(),
    };
  }
}
