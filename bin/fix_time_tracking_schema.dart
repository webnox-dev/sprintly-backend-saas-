// Run this script to fix the task_card_time_tracking table schema
// dart run bin/fix_time_tracking_schema.dart

import 'package:postgres/postgres.dart';

Future<void> main() async {
  print('🔄 Connecting to database...');

  final connection = await Connection.open(
    Endpoint(
      host: '192.168.0.36',
      port: 5436,
      database: 'webnox_sprintly',
      username: 'postgres',
      password: '1234',
    ),
    settings: ConnectionSettings(sslMode: SslMode.disable),
  );

  print('✅ Connected to database');

  try {
    print('🔄 Altering task_card_time_tracking table...');

    // Rename id to tracking_id if it exists
    try {
      await connection.execute(
        'ALTER TABLE task_card_time_tracking RENAME COLUMN id TO tracking_id',
      );
      print('✅ Renamed id to tracking_id');
    } catch (e) {
      print('ℹ️ Column id might not exist or already renamed: $e');
    }

    // Add is_active
    await connection.execute('''
      ALTER TABLE task_card_time_tracking 
      ADD COLUMN IF NOT EXISTS is_active BOOLEAN DEFAULT true
    ''');
    print('✅ Added is_active column');

    // Add worked_hours
    await connection.execute('''
      ALTER TABLE task_card_time_tracking 
      ADD COLUMN IF NOT EXISTS worked_hours DOUBLE PRECISION
    ''');
    print('✅ Added worked_hours column');

    // Add session_duration
    await connection.execute('''
      ALTER TABLE task_card_time_tracking 
      ADD COLUMN IF NOT EXISTS session_duration TEXT
    ''');
    print('✅ Added session_duration column');

    // Add created_by
    await connection.execute('''
      ALTER TABLE task_card_time_tracking 
      ADD COLUMN IF NOT EXISTS created_by TEXT
    ''');
    print('✅ Added created_by column');

    // Add updated_by
    await connection.execute('''
      ALTER TABLE task_card_time_tracking 
      ADD COLUMN IF NOT EXISTS updated_by TEXT
    ''');
    print('✅ Added updated_by column');

    // Update existing records to have is_active based on clock_out_time
    await connection.execute('''
      UPDATE task_card_time_tracking 
      SET is_active = (clock_out_time IS NULL)
    ''');
    print('✅ Updated existing records is_active status');

    print('✅ Schema fix completed successfully!');
  } catch (e, stackTrace) {
    print('❌ Error: $e');
    print('Stack: $stackTrace');
  } finally {
    await connection.close();
    print('🔒 Database connection closed');
  }
}
