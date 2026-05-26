import 'dart:io';
import 'package:webnox_sprintly_admin_backend/data/database/connection.dart';
import 'package:webnox_sprintly_admin_backend/config/app_config.dart';

void main() async {
  AppConfig.initialize();
  try {
    final results = await DatabaseConnection.query(
      "SELECT table_schema, table_name FROM information_schema.tables WHERE table_name = 'roles'", 
      isGlobal: true
    );
    print('TABLES FOUND: $results');
    
    final allTables = await DatabaseConnection.query(
      "SELECT table_name FROM information_schema.tables WHERE table_schema = 'public'", 
      isGlobal: true
    );
    print('ALL PUBLIC TABLES: ${allTables.map((t) => t['table_name']).toList()}');
    
    exit(0);
  } catch (e) {
    print('ERROR: $e');
    exit(1);
  }
}
