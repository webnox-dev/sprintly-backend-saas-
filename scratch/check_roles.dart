import 'dart:io';
import 'package:webnox_sprintly_admin_backend/data/database/connection.dart';
import 'package:webnox_sprintly_admin_backend/config/app_config.dart';

void main() async {
  AppConfig.initialize();
  try {
    final results = await DatabaseConnection.query('SELECT count(*) as count FROM roles', isGlobal: true);
    print('TOTAL ROLES: ${results.first['count']}');
    
    final allRoles = await DatabaseConnection.query('SELECT * FROM roles', isGlobal: true);
    print('ROLES DATA: $allRoles');
    
    exit(0);
  } catch (e) {
    print('ERROR: $e');
    exit(1);
  }
}
