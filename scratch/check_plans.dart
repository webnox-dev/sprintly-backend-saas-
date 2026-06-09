import 'dart:convert';
import '../lib/data/database/connection.dart';
import '../lib/config/app_config.dart';
import '../lib/services/auth_service.dart';
import 'package:crypto/crypto.dart';
import '../lib/data/repositories/user_repository.dart';

void main() async {
  AppConfig.initialize();
  
  try {
    final userRepo = UserRepository();
    final user = await userRepo.getByEmail('admin@webnox.in');
    if (user != null) {
      print('User details fetched:');
      print('Email: ${user.email}');
      print('Stored Encrypted Password: ${user.encryptedPassword}');
      final hashedInput = sha256.convert(utf8.encode('123456')).toString();
      print('Hashed Input for 123456: $hashedInput');
      print('Are they equal? ${hashedInput == user.encryptedPassword}');
    } else {
      print('❌ User not found via UserRepository!');
    }

    final authService = AuthService();
    final loginResult = await authService.login(
      'admin@webnox.in',
      '123456',
      'Admin',
    );
    print('Login Result for admin@webnox.in:');
    print(jsonEncode(loginResult));
  } catch (e) {
    print('❌ Error: $e');
  } finally {
    await DatabaseConnection.close();
  }
}
