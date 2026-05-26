
import 'dart:io';
import '../lib/data/database/connection.dart';

void main() async {
  try {
    print('Reading migration file...');
    final sql = await File('database/migrations/001_saas_multitenancy.sql').readAsString();
    
    print('Executing entire 001_saas_multitenancy.sql at once...');
    await DatabaseConnection.execute(sql, isGlobal: true);
    print('SUCCESS!');
  } catch (e) {
    print('FAILED: $e');
  }
}
