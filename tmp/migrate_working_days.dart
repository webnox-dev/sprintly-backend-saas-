import 'dart:io';
import 'package:webnox_sprintly_admin_backend/data/database/connection.dart';

void main() async {
  print('--- Database Migration ---');
  
  try {
    // 1. Add working_date_list column
    print('Adding working_date_list column...');
    await DatabaseConnection.execute(
      'ALTER TABLE monthly_working_days ADD COLUMN IF NOT EXISTS working_date_list JSONB DEFAULT \'[]\'::jsonb;'
    );
    
    // 2. Add non_working_days column
    print('Adding non_working_days column...');
    await DatabaseConnection.execute(
      'ALTER TABLE monthly_working_days ADD COLUMN IF NOT EXISTS non_working_days DOUBLE PRECISION DEFAULT 0;'
    );
    
    // 3. Update non_working_days for existing records
    print('Updating non_working_days for existing records...');
    await DatabaseConnection.execute(
      'UPDATE monthly_working_days SET non_working_days = total_days - working_days WHERE non_working_days = 0 OR non_working_days IS NULL;'
    );
    
    print('✅ Migration completed successfully!');
  } catch (e) {
    print('❌ Migration failed: $e');
    exit(1);
  } finally {
    await DatabaseConnection.close();
    exit(0);
  }
}
