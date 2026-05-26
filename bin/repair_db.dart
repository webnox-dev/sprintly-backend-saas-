import 'package:webnox_sprintly_admin_backend/data/database/connection.dart';
import 'package:dotenv/dotenv.dart';

void main() async {
  print('Loading environment...');
  var env = DotEnv(includePlatformEnvironment: true)..load();

  print('Connecting to DB...');
  try {
    final conn = await DatabaseConnection.getConnection();
    print('Connected.');

    // 1. Check password_reset_helper columns
    print('Checking password_reset_helper columns...');
    var result = await DatabaseConnection.query(
      "SELECT column_name FROM information_schema.columns WHERE table_name = 'password_reset_helper'",
    );
    var columns = result.map((row) => row['column_name'].toString()).toSet();
    print('Columns found: $columns');

    // 2. Fix if missing
    if (!columns.contains('otp_type')) {
      print('Adding otp_type column...');
      await DatabaseConnection.execute(
        "ALTER TABLE password_reset_helper ADD COLUMN otp_type VARCHAR(50) DEFAULT 'email_verification'",
      );
      print('otp_type added.');
    } else {
      print('otp_type exists.');
    }

    if (!columns.contains('user_type')) {
      print('Adding user_type column...');
      await DatabaseConnection.execute(
        "ALTER TABLE password_reset_helper ADD COLUMN user_type VARCHAR(20) DEFAULT 'Employee'",
      );
      print('user_type added.');
    } else {
      print('user_type exists.');
    }

    // 3. Check auth.users columns (just in case)
    print('Checking auth.users columns...');
    result = await DatabaseConnection.query(
      "SELECT column_name FROM information_schema.columns WHERE table_name = 'users' AND table_schema = 'auth'",
    );
    columns = result.map((row) => row['column_name'].toString()).toSet();
    print('Auth Users Columns found: $columns');

    // Check for otp and otp_generated_at
    if (!columns.contains('otp')) {
      print('Adding otp to auth.users...');
      await DatabaseConnection.execute(
        "ALTER TABLE auth.users ADD COLUMN otp VARCHAR(10)",
      );
    }
    if (!columns.contains('otp_generated_at')) {
      print('Adding otp_generated_at to auth.users...');
      await DatabaseConnection.execute(
        "ALTER TABLE auth.users ADD COLUMN otp_generated_at TIMESTAMPTZ",
      );
    }

    await DatabaseConnection.close();
    print('Done.');
  } catch (e, st) {
    print('Error: $e');
    print(st);
  }
}
