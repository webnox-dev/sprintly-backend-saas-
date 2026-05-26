import 'package:webnox_sprintly_admin_backend/data/database/connection.dart';
import 'package:webnox_sprintly_admin_backend/config/app_config.dart';

Future<void> main() async {
  print('🚀 Starting force database migration...');

  // Initialize config
  AppConfig.initialize();

  try {
    print('📦 Connecting to database: ${AppConfig.databaseUrl}...');
    final conn = await DatabaseConnection.getConnection();

    // Add tasks_for_the_day column
    print('🛠️ Adding tasks_for_the_day column...');
    await conn.execute(
      "ALTER TABLE employee_attendance ADD COLUMN IF NOT EXISTS tasks_for_the_day JSONB;",
    );

    print('✅ Column added successfully!');
  } catch (e) {
    print('❌ Migration failed: $e');
  } finally {
    await DatabaseConnection.close();
    print('👋 Connection closed');
  }
}
