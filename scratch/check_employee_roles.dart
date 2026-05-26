import 'dart:io';
import 'package:webnox_sprintly_admin_backend/data/database/connection.dart';
import 'package:webnox_sprintly_admin_backend/config/app_config.dart';

void main() async {
  AppConfig.initialize();
  try {
    final results = await DatabaseConnection.query(
      'SELECT employee_role, employee_designation, organization_id FROM employees', 
      isGlobal: true
    );
    print('EMPLOYEE ROLES: $results');
    exit(0);
  } catch (e) {
    print('ERROR: $e');
    exit(1);
  }
}
