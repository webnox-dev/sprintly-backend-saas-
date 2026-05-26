import 'dart:convert';
import 'package:crypto/crypto.dart';

/// User model for authentication and OTP verification
class User {
  final String id;
  final String employeeId;
  final String email;
  final String? encryptedPassword;
  final String? otp;
  final DateTime? otpGeneratedAt;
  final DateTime? emailConfirmedAt;
  final String role; // 'Admin' or 'Employee'
  final DateTime? createdAt;
  final String? createdBy;
  final DateTime? updatedAt;
  final String? updatedBy;
  final bool isActive;
  final String? organizationId;

  User({
    required this.id,
    required this.employeeId,
    required this.email,
    this.encryptedPassword,
    this.otp,
    this.otpGeneratedAt,
    this.emailConfirmedAt,
    required this.role,
    this.isActive = true,
    this.createdAt,
    this.createdBy,
    this.updatedAt,
    this.updatedBy,
    this.organizationId,
  });

  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      id: map['id']?.toString() ?? '',
      employeeId: map['employee_id']?.toString() ?? '',
      email: map['email']?.toString() ?? '',
      encryptedPassword: map['encrypted_password']?.toString(),
      otp: map['otp']?.toString(),
      otpGeneratedAt: map['otp_generated_at'] != null
          ? DateTime.tryParse(map['otp_generated_at'].toString())
          : null,
      emailConfirmedAt: map['email_confirmed_at'] != null
          ? DateTime.tryParse(map['email_confirmed_at'].toString())
          : null,
      role: map['role']?.toString() ?? 'Employee',
      // Default to true if is_active column doesn't exist or is null
      isActive:
          map['is_active'] == null ||
          map['is_active'] == 1 ||
          map['is_active'] == true,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString())
          : null,
      createdBy: map['created_by']?.toString(),
      updatedAt: map['updated_at'] != null
          ? DateTime.tryParse(map['updated_at'].toString())
          : null,
      updatedBy: map['updated_by']?.toString(),
      organizationId: map['organization_id']?.toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'employee_id': employeeId,
      'email': email,
      'encrypted_password': encryptedPassword,
      'otp': otp,
      'otp_generated_at': otpGeneratedAt?.toIso8601String(),
      'email_confirmed_at': emailConfirmedAt?.toIso8601String(),
      'role': role,
      'is_active': isActive,
      'created_at': createdAt?.toIso8601String(),
      'created_by': createdBy,
      'updated_at': updatedAt?.toIso8601String(),
      'updated_by': updatedBy,
      'organization_id': organizationId,
    };
  }

  User copyWith({
    String? id,
    String? employeeId,
    String? email,
    String? encryptedPassword,
    String? otp,
    DateTime? otpGeneratedAt,
    DateTime? emailConfirmedAt,
    String? role,
    bool? isActive,
    DateTime? createdAt,
    String? createdBy,
    DateTime? updatedAt,
    String? updatedBy,
    String? organizationId,
  }) {
    return User(
      id: id ?? this.id,
      employeeId: employeeId ?? this.employeeId,
      email: email ?? this.email,
      encryptedPassword: encryptedPassword ?? this.encryptedPassword,
      otp: otp ?? this.otp,
      otpGeneratedAt: otpGeneratedAt ?? this.otpGeneratedAt,
      emailConfirmedAt: emailConfirmedAt ?? this.emailConfirmedAt,
      role: role ?? this.role,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      createdBy: createdBy ?? this.createdBy,
      updatedAt: updatedAt ?? this.updatedAt,
      updatedBy: updatedBy ?? this.updatedBy,
      organizationId: organizationId ?? this.organizationId,
    );
  }

  /// Check if email is confirmed
  bool get isEmailConfirmed => emailConfirmedAt != null;

  /// Check if OTP is valid (not expired - 15 minutes)
  bool isOtpValid() {
    if (otp == null || otpGeneratedAt == null) return false;
    final now = DateTime.now();
    final difference = now.difference(otpGeneratedAt!);
    return difference.inMinutes < 15;
  }

  /// Verify password against stored encrypted password
  bool verifyPassword(String password) {
    if (encryptedPassword == null) return false;
    final hashedInput = sha256.convert(utf8.encode(password)).toString();
    return hashedInput == encryptedPassword;
  }

  /// Hash a plain text password
  static String hashPassword(String password) {
    return sha256.convert(utf8.encode(password)).toString();
  }
}
