import 'dart:io';
import 'package:webnox_sprintly_admin_backend/data/database/connection.dart';

void main() async {
  try {
    final result = await DatabaseConnection.query(
      'SELECT * FROM monthly_working_days'
    );
    print('Monthly Working Days Records:');
    for (final row in result) {
      print('ID: ${row['working_days_id']} | Month: ${row['month']} | Year: ${row['year']} | Working: ${row['working_days']} | Dates: ${row['working_date_list']}');
    }
  } catch (e) {
    print('Error: $e');
  } finally {
    await DatabaseConnection.close();
    exit(0);
  }
}
