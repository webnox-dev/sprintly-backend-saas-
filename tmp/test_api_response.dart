import 'dart:io';
import 'package:webnox_sprintly_admin_backend/data/database/connection.dart';
import 'package:webnox_sprintly_admin_backend/domain/models/monthly_working_days.dart';

void main() async {
  try {
    final result = await DatabaseConnection.query(
      'SELECT * FROM monthly_working_days'
    );
    print('Raw Database Rows:');
    for (final row in result) {
      print('Row working_date_list type: ${row['working_date_list'].runtimeType}');
      print('Row working_date_list value: ${row['working_date_list']}');
      
      final model = MonthlyWorkingDays.fromJson(row);
      print('Model workingDateList: ${model.workingDateList}');
      
      final json = model.toJson();
      print('ToJson output working_date_list: ${json['working_date_list']}');
      print('---');
    }
  } catch (e) {
    print('Error: $e');
  } finally {
    await DatabaseConnection.close();
    exit(0);
  }
}
