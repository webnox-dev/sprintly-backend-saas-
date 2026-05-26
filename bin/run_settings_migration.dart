import 'dart:io';
import 'package:webnox_sprintly_admin_backend/data/database/connection.dart';
import 'package:webnox_sprintly_admin_backend/config/app_config.dart';

void main() async {
  print('Initializng config...');
  AppConfig.initialize();

  print('Connecting to DB...');
  try {
    await DatabaseConnection.getConnection();
    print('Connected.');

    final migrationFile = File(
      'database/migrations/create_settings_crud_tables.sql',
    );
    if (!migrationFile.existsSync()) {
      print('Migration file not found!');
      return;
    }

    print('Reading migration file...');
    final sql = migrationFile.readAsStringSync();

    print('Executing migration...');
    final lines = sql.split('\n');
    final cleanSql = lines
        .where((line) => !line.trim().startsWith('--'))
        .join('\n');
    final commands = cleanSql
        .split(';')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    int count = 0;
    for (var command in commands) {
      count++;
      print('Executing command $count of ${commands.length}...');
      try {
        await DatabaseConnection.execute(command);
        print('✅ Command $count success.');
      } catch (e) {
        print('❌ Command $count failed: $e');
        print('SQL: $command');
        rethrow;
      }
    }

    print('Migration executed successfully!');
    await DatabaseConnection.close();
  } catch (e, st) {
    print('Error executing migration: $e');
    print(st);
  }
}
