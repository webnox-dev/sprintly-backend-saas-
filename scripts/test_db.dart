import 'dart:io';
import 'package:postgres/postgres.dart';

void main() async {
  print('TESTING DATABASE CONNECTION...');
  try {
    final connection = await Connection.open(
      Endpoint(
        host: 'localhost',
        port: 5432,
        database: 'webnox_sprintly',
        username: 'postgres',
        password: '1234',
      ),
      settings: ConnectionSettings(sslMode: SslMode.disable, connectTimeout: Duration(seconds: 5)),
    );
    print('✅ SUCCESS - CONNECTED');
    
    final migrationSql = await File('database/migrations/20260326_fix_employee_id_cascade.sql').readAsString();
    print('➤ Executing migration...');
    await connection.execute(migrationSql);
    print('✅ MIGRATION COMPLETED');
    
    await connection.close();
  } catch (e) {
    print('❌ FAILED: $e');
  }
}
