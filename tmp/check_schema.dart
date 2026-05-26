import 'dart:io';
import 'package:webnox_sprintly_admin_backend/data/database/connection.dart';

void main() async {
  try {
    final result = await DatabaseConnection.query(
      'SELECT column_name, data_type, udt_name FROM information_schema.columns WHERE table_name = \'monthly_working_days\''
    );
    print('Schema for monthly_working_days:');
    for (final row in result) {
      print('${row['column_name']}: ${row['data_type']} (${row['udt_name']})');
    }
  } catch (e) {
    print('Error: $e');
  } finally {
    await DatabaseConnection.close();
    exit(0);
  }
}
