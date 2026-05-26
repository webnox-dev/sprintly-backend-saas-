import 'dart:io';
import 'package:webnox_sprintly_admin_backend/data/database/connection.dart';
import 'package:webnox_sprintly_admin_backend/domain/models/monthly_working_days.dart';

void main() async {
  try {
    final result = await DatabaseConnection.query(
      'SELECT * FROM monthly_working_days LIMIT 1'
    );
    if (result.isNotEmpty) {
      final row = result.first;
      final model = MonthlyWorkingDays.fromJson(row);
      print('JSON KEYS: ${model.toJson().keys}');
      print('working_date_list value: ${model.toJson()['working_date_list']}');
    }
  } catch (e) {
    print('Error: $e');
  } finally {
    await DatabaseConnection.close();
    exit(0);
  }
}
