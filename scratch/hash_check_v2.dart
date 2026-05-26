import 'dart:convert';
import 'package:crypto/crypto.dart';

void main() {
  final passwords = [
    'SuperAdmin@2024',
    'password',
    'admin',
    'sprintly',
    'SuperAdmin',
    'superadmin',
    'Superadmin@2024',
    'Sprintly@2024',
    'SprintlyAdmin@2024'
  ];
  for (var password in passwords) {
    final bytes = utf8.encode(password);
    final hash = sha256.convert(bytes).toString();
    print('SHA-256 of $password: $hash');
  }
}
