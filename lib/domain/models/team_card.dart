import 'dart:convert';

/// TeamCard model for non-project work (Meeting, KT, Learning, R&D)
class TeamCard {
  final String teamCardId;
  final String cardName;
  final String? cardType;
  final String? cardDescription;
  final int teamCardStatus; // 1 = active, 0 = inactive
  final String? teamType;
  final String? createdBy;
  final DateTime? createdAt;
  final String? updatedBy;
  final DateTime? updatedAt;

  TeamCard({
    required this.teamCardId,
    required this.cardName,
    this.cardType = 'Learning Card',
    this.cardDescription,
    this.teamCardStatus = 1,
    this.teamType,
    this.createdBy,
    this.createdAt,
    this.updatedBy,
    this.updatedAt,
  });

  factory TeamCard.fromMap(Map<String, dynamic> map) {
    return TeamCard(
      teamCardId: map['team_card_id']?.toString() ?? '',
      cardName: map['card_name']?.toString() ?? '',
      cardType: map['card_type']?.toString() ?? 'Learning Card',
      cardDescription: map['card_description']?.toString(),
      teamCardStatus: (map['team_card_status'] as num?)?.toInt() ?? 1,
      teamType: map['team_type']?.toString(),
      createdBy: map['created_by']?.toString(),
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString())
          : null,
      updatedBy: map['updated_by']?.toString(),
      updatedAt: map['updated_at'] != null
          ? DateTime.tryParse(map['updated_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'team_card_id': teamCardId,
      'card_name': cardName,
      'card_type': cardType,
      'card_description': cardDescription,
      'team_card_status': teamCardStatus,
      'team_type': teamType,
      'created_by': createdBy,
      'created_at': createdAt?.toIso8601String(),
      'updated_by': updatedBy,
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  /// Minimal JSON for list views
  Map<String, dynamic> toListJson() {
    return {
      'team_card_id': teamCardId,
      'card_name': cardName,
      'card_type': cardType,
      'team_card_status': teamCardStatus,
      'team_type': teamType,
    };
  }
}

/// TeamCardUsage model for clock-in/clock-out tracking
class TeamCardUsage {
  final String usageId;
  final String teamCardId;
  final String employeeId;
  final DateTime clockIn;
  final DateTime? clockOut;
  final double totalHours;
  final String? notes;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  // Joined fields
  final Map<String, dynamic>? teamCardDetails;
  final Map<String, dynamic>? employeeDetails;

  TeamCardUsage({
    required this.usageId,
    required this.teamCardId,
    required this.employeeId,
    required this.clockIn,
    this.clockOut,
    this.totalHours = 0.0,
    this.notes,
    this.createdAt,
    this.updatedAt,
    this.teamCardDetails,
    this.employeeDetails,
  });

  factory TeamCardUsage.fromMap(Map<String, dynamic> map) {
    dynamic parseJson(dynamic value) {
      if (value == null) return null;
      if (value is Map) return value;
      if (value is String) {
        try {
          return jsonDecode(value);
        } catch (_) {
          return null;
        }
      }
      return null;
    }

    return TeamCardUsage(
      usageId: map['usage_id']?.toString() ?? '',
      teamCardId: map['team_card_id']?.toString() ?? '',
      employeeId: map['employee_id']?.toString() ?? '',
      clockIn: map['clock_in'] != null
          ? DateTime.parse(map['clock_in'].toString())
          : DateTime.now(),
      clockOut: map['clock_out'] != null
          ? DateTime.tryParse(map['clock_out'].toString())
          : null,
      totalHours: (map['total_hours'] as num?)?.toDouble() ?? 0.0,
      notes: map['notes']?.toString(),
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString())
          : null,
      updatedAt: map['updated_at'] != null
          ? DateTime.tryParse(map['updated_at'].toString())
          : null,
      teamCardDetails:
          parseJson(map['team_card_details']) as Map<String, dynamic>?,
      employeeDetails:
          parseJson(map['employee_details']) as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'usage_id': usageId,
      'team_card_id': teamCardId,
      'employee_id': employeeId,
      'clock_in': clockIn.toIso8601String(),
      'clock_out': clockOut?.toIso8601String(),
      'total_hours': totalHours,
      'notes': notes,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'team_card_details': teamCardDetails,
      'employee_details': employeeDetails,
    };
  }
}
