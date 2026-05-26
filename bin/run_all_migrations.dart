import 'dart:io';
import 'package:webnox_sprintly_admin_backend/config/app_config.dart';
import 'package:webnox_sprintly_admin_backend/data/database/migration_service.dart';
import 'package:webnox_sprintly_admin_backend/data/database/connection.dart';

/// Script to run all migrations, including the employee_id cascade fix.
Future<void> main() async {
  print('🔄 Starting Sprintly Database Migration Runner...\n');

  try {
    // 1. Initialize configuration
    print('➤ Initializing environment configuration...');
    AppConfig.initialize();
    print('  ✓ Configuration initialized (Environment: ${AppConfig.environment})');

    // 2. Run migrations
    print('➤ Running all pending database migrations...');
    await MigrationService.runMigrations();
    print('  ✓ All migrations processed');

    // 3. Close connection
    print('➤ Closing database connection...');
    await DatabaseConnection.close();
    
    print('\n🎉 Database setup and migrations completed successfully!');
  } catch (e, stackTrace) {
    print('\n❌ Migration failed with error: $e');
    print('Stack trace:');
    print(stackTrace);
    exit(1);
  }
}
