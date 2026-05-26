import '../lib/data/database/connection.dart';
import '../lib/config/app_config.dart';

void main() async {
  AppConfig.initialize();
  final email = 'sprg1137webnox@gmail.com';
  
  try {
    final user = await DatabaseConnection.queryOne(
      'SELECT * FROM auth.users WHERE email = @email',
      values: {'email': email},
      isGlobal: true
    );
    
    if (user != null) {
      print('=== User Account Details ===');
      print('Email: ${user['email']}');
      print('Role: ${user['role']}');
      print('Employee ID: ${user['employee_id']}');
      print('Organization ID: ${user['organization_id']}');
      print('Password Hash: ${user['encrypted_password']}');
      print('Is Active: ${user['is_active']}');
      print('Email Confirmed At: ${user['email_confirmed_at']}');
    } else {
      print('❌ User not found for email: $email');
    }
  } catch (e) {
    print('❌ Error: $e');
  } finally {
    await DatabaseConnection.close();
  }
}
