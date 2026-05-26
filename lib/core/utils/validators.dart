/// Validation utilities
class Validators {
  /// Validate email format
  static bool isValidEmail(String email) {
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    return emailRegex.hasMatch(email);
  }

  /// Validate phone number (basic validation)
  static bool isValidPhone(String phone) {
    // Remove spaces, dashes, and plus signs for validation
    final cleaned = phone.replaceAll(RegExp(r'[\s\-+]'), '');
    return cleaned.length >= 10 && RegExp(r'^\d+$').hasMatch(cleaned);
  }

  /// Validate employee ID format (2 uppercase letters followed by digits)
  static bool isValidEmployeeId(String employeeId) {
    final regex = RegExp(r'^[A-Z]{2}\d+$');
    return regex.hasMatch(employeeId.trim().toUpperCase());
  }

  /// Validate date format (DD-MM-YYYY)
  static bool isValidDateFormat(String date) {
    final regex = RegExp(r'^\d{2}-\d{2}-\d{4}$');
    if (!regex.hasMatch(date)) return false;

    try {
      final parts = date.split('-');
      final day = int.parse(parts[0]);
      final month = int.parse(parts[1]);
      final year = int.parse(parts[2]);

      if (month < 1 || month > 12) return false;
      if (day < 1 || day > 31) return false;
      if (year < 1900 || year > 2100) return false;

      // Check if date is valid
      DateTime(year, month, day);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Validate required field
  static String? validateRequired(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }
    return null;
  }

  /// Validate string length
  static String? validateLength(String? value, String fieldName,
      {int? min, int? max}) {
    if (value == null) return null;

    if (min != null && value.length < min) {
      return '$fieldName must be at least $min characters';
    }

    if (max != null && value.length > max) {
      return '$fieldName must be at most $max characters';
    }

    return null;
  }

  /// Validate numeric range
  static String? validateRange(num? value, String fieldName,
      {num? min, num? max}) {
    if (value == null) return null;

    if (min != null && value < min) {
      return '$fieldName must be at least $min';
    }

    if (max != null && value > max) {
      return '$fieldName must be at most $max';
    }

    return null;
  }
}

