
import 'dart:io';
import '../lib/data/database/connection.dart';

void main() async {
  try {
    final sql = await File('database/migrations/001_saas_multitenancy.sql').readAsString();
    final statements = sql.split(';');
    
    print('Executing 001_saas_multitenancy.sql...');
    for (var stmt in statements) {
      if (stmt.trim().isEmpty) continue;
      try {
        await DatabaseConnection.execute(stmt, isGlobal: true);
      } catch (e) {
        if (!e.toString().contains('already exists')) {
          print('Error in statement: ${stmt.substring(0, min(50, stmt.length))}... \nError: $e');
        }
      }
    }
    print('Done.');
  } catch (e) {
    print('Error: $e');
  }
}

int min(int a, int b) => a < b ? a : b;
