import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../lib/data/database/connection.dart';
import '../lib/config/app_config.dart';

void main() async {
  // 1. Initialize Configuration
  AppConfig.initialize();
  
  final email = 'hbpudhinraj@gmail.com';
  final newPassword = '123456';
  final bytes = utf8.encode(newPassword);
  final hash = sha256.convert(bytes).toString();
  
  print('Updating password for: $email');
  print('New Password: $newPassword');
  print('New Hash: $hash');
  
  try {
    // 2. Update auth.users table
    final affected = await DatabaseConnection.execute(
      'UPDATE auth.users SET encrypted_password = @hash WHERE email = @email',
      values: {
        'hash': hash,
        'email': email
      },
      isGlobal: true
    );
    
    if (affected > 0) {
      print('✅ Successfully updated password for $email');
    } else {
      print('⚠️ No user found in auth.users with email $email');
    }
  } catch (e) {
    print('❌ Error updating password: $e');
  } finally {
    // 3. Close the connection pool
    await DatabaseConnection.close();
  }
}
