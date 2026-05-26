import 'package:webnox_sprintly_admin_backend/data/repositories/attendance_repository.dart';
import 'package:webnox_sprintly_admin_backend/core/utils/logger.dart';
import 'package:webnox_sprintly_admin_backend/data/database/connection.dart';
import 'package:webnox_sprintly_admin_backend/config/app_config.dart';

Future<void> main() async {
  // Load config
  AppConfig.initialize();
  // DatabaseConnection connects lazily

  final repository = AttendanceRepository();
  final logger = AppLogger('TestRunner');

  try {
    // 1. Get the latest active attendance for today (to mimic the failing scenario)
    // We can use a hardcoded active one from logs: 08aa41ba-def0-49a7-b4cb-802a15aa9815 or f51d2a40-117c-41ff-95a2-a874fb9715c5
    // But better to fetch dynamically.

    print('Fetching today active attendance for WT1147...');
    final attendances = await repository.getAll(
      employeeId: 'WT1147',
      date: '2026-01-13',
      page: 1,
      limit: 10,
    );

    final list = attendances['data'] as List;
    print('Found ${list.length} records.');

    if (list.isEmpty) {
      print('No records found. Cannot test addTask.');
      return;
    }

    // Find the active one
    // Find the active one
    dynamic active;
    for (final item in list) {
      if (item.clockOffForTheDay == null) {
        active = item;
        break;
      }
    }

    if (active != null) {
      print('Testing addTask on active attendance: ${active.attendanceId}');

      final task = {
        'task_id': 'test_task_${DateTime.now().millisecondsSinceEpoch}',
        'task_name': 'Test Task Debug',
        'clock_in_time': DateTime.now().toIso8601String(),
      };

      try {
        await repository.addTask(
          attendanceId: active.attendanceId,
          task: task,
          updatedBy: 'WT1147',
        );
        print('✅ addTask Success!');
      } catch (e) {
        print(
          '❌ addTask Failed: $e',
        ); // This will print the exact backend error!
      }
    } else {
      print('No active attendance found to test.');
    }
  } catch (e) {
    print('Script Error: $e');
  } finally {
    await DatabaseConnection.close();
  }
}
