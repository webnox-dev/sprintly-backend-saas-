import 'dart:io';
import 'package:postgres/postgres.dart';

/// Script to run the cascade migration for employee_id updates
Future<void> main() async {
  print('🔄 Running employee_id cascade migration...\n');

  try {
    // 1. Load database configuration from .env
    final envFile = File('.env');
    if (!await envFile.exists()) {
      print('❌ .env file not found!');
      return;
    }

    final envLines = await envFile.readAsLines();
    String? dbUrl;
    for (var line in envLines) {
      if (line.trim().startsWith('DATABASE_URL=')) {
        dbUrl = line.split('=')[1].trim();
        break;
      }
    }

    if (dbUrl == null) {
      print('❌ DATABASE_URL not found in .env!');
      return;
    }

    print('📡 Database configuration found.');

    // 2. Parse database URL
    final uri = Uri.parse(dbUrl);
    final host = uri.host;
    final port = uri.port;
    final database = uri.pathSegments.last;
    final username = uri.userInfo.split(':').first;
    final password = uri.userInfo.split(':').last;

    print('📡 Connecting to: $database @ $host:$port');

    // 3. Open connection
    final connection = await Connection.open(
      Endpoint(
        host: host,
        port: port,
        database: database,
        username: username,
        password: password,
      ),
      settings: ConnectionSettings(sslMode: SslMode.disable),
    );

    print('✅ Connected to database\n');

    // 4. Read migration file
    final migrationFile = File('database/migrations/20260326_fix_employee_id_cascade.sql');
    if (!await migrationFile.exists()) {
      print('❌ Migration file not found!');
      await connection.close();
      return;
    }

    final migrationSql = await migrationFile.readAsString();

    print('➤ Executing migration PL/pgSQL block...');
    
    // For PL/pgSQL blocks, we execute as a single statement
    await connection.execute(migrationSql);
    
    print('✅ Migration completed successfully!');
    print('  - All foreign keys referencing employees(employee_id) updated to ON UPDATE CASCADE');

    await connection.close();
  } catch (e, stackTrace) {
    print('❌ Error during migration: $e');
    print(stackTrace);
    exit(1);
  } finally {
    print('\n📡 Database connection closed');
  }
}
