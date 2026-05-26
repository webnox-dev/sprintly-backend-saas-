/// Helper to convert task_duration string and date range to allocated hours.
/// Used for delayed/overtime task card calculations.
class TaskDurationHelper {
  /// Default work hours per day when deriving from date range
  static const double defaultHoursPerDay = 8.0;

  /// Parse [taskDuration] (e.g. "2 days", "4 hours", "1 day") to hours.
  /// Returns null if parsing fails.
  static double? parseTaskDurationToHours(String? taskDuration) {
    if (taskDuration == null || taskDuration.trim().isEmpty) return null;

    final s = taskDuration.trim().toLowerCase();
    final numMatch = RegExp(r'^([\d.]+)\s*').firstMatch(s);
    if (numMatch == null) return null;

    final value = double.tryParse(numMatch.group(1) ?? '');
    if (value == null || value <= 0) return null;

    if (s.contains('day')) return value * defaultHoursPerDay;
    if (s.contains('hour') || s.contains('hr') || s.contains('h ')) return value;
    if (s.contains('week')) return value * 5 * defaultHoursPerDay;

    return value;
  }

  /// Get allocated hours for a task: from [taskDuration] if parseable,
  /// otherwise from [fromDate] and [toDate] (days between * hours per day).
  static double getAllocatedHours({
    String? taskDuration,
    DateTime? fromDate,
    DateTime? toDate,
  }) {
    final parsed = parseTaskDurationToHours(taskDuration);
    if (parsed != null && parsed > 0) return parsed;

    if (fromDate != null && toDate != null && !toDate.isBefore(fromDate)) {
      final days = toDate.difference(fromDate).inDays + 1;
      return days * defaultHoursPerDay;
    }

    return 0.0;
  }
}
