import 'dart:io';
import 'package:webnox_sprintly_admin_backend/data/database/connection.dart';
import 'package:webnox_sprintly_admin_backend/config/app_config.dart';

void main() async {
  AppConfig.initialize();
  try {
    final results = await DatabaseConnection.query(
      'SELECT admin_id, organization_id FROM admins WHERE admin_id = @id', 
      values: {'id': 'PUD002'},
      isGlobal: true
    );
    print('ADMIN DATA: $results');
    
    final orgs = await DatabaseConnection.query('SELECT id, slug, name FROM organizations', isGlobal: true);
    print('ALL ORGS: $orgs');
    
    exit(0);
  } catch (e) {
    print('ERROR: $e');
    exit(1);
  }
}
