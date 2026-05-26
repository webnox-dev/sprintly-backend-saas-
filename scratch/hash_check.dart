import 'dart:convert';
import 'package:crypto/crypto.dart';

void main() {
  final password = 'SuperAdmin@2024';
  final bytes = utf8.encode(password);
  final hash = sha256.convert(bytes).toString();
  print('SHA-256 of $password: $hash');
}
