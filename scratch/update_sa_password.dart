import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../lib/data/database/connection.dart';
import '../lib/config/app_config.dart';

void main() async {
  // 1. Initialize Configuration
  AppConfig.initialize();
  
  final password = 'SuperAdmin@2024';
  final bytes = utf8.encode(password);
  final hash = sha256.convert(bytes).toString();
  
  print('Updating super admin password to: $password');
  print('New Hash: $hash');
  
  try {
    // 2. Execute the update query with isGlobal: true to avoid tenant filtering
    final affected = await DatabaseConnection.execute(
      'UPDATE super_admins SET password_hash = @hash WHERE email = @email',
      values: {
        'hash': hash,
        'email': 'superadmin@sprintly.io'
      },
      isGlobal: true
    );
    
    if (affected > 0) {
      print('✅ Successfully updated password for superadmin@sprintly.io');
    } else {
      print('⚠️ No user found with email superadmin@sprintly.io');
    }
  } catch (e) {
    print('❌ Error updating password: $e');
  } finally {
    // 3. Close the connection pool
    await DatabaseConnection.close();
  }
}
