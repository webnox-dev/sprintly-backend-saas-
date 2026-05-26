import 'dart:io';
import 'package:postgres/postgres.dart';

Future<void> main() async {
  print('🔄 Running database migration to fix fingerprint index limit...\n');

  // Connection settings from app_config.dart defaults
  // We'll try the "live" one first since that's what seems to be in use
  final host = '192.168.0.32';
  final port = 5435;
  final database = 'webnox_sprintly';
  final username = 'postgres';
  final password = '1234';

  print('📡 Connecting to database: $database@$host:$port');

  Connection? connection;
  try {
    connection = await Connection.open(
      Endpoint(
        host: host,
        port: port,
        database: database,
        username: username,
        password: password,
      ),
      settings: ConnectionSettings(
        sslMode: SslMode.disable,
        connectTimeout: Duration(seconds: 5),
      ),
    );
  } catch (e) {
    print('⚠️ Could not connect to $host, trying localhost...');
    try {
      connection = await Connection.open(
        Endpoint(
          host: 'localhost',
          port: 5435,
          database: database,
          username: username,
          password: password,
        ),
        settings: ConnectionSettings(
          sslMode: SslMode.disable,
          connectTimeout: Duration(seconds: 5),
        ),
      );
    } catch (e2) {
      print('❌ Failed to connect to localhost:5435 as well: $e2');
      return;
    }
  }

  try {
    print('✅ Connected to database\n');

    final sqlFile = File('database/migrations/fix_fingerprint_index_limit.sql');
    if (!sqlFile.existsSync()) {
      print('❌ Migration file not found: ${sqlFile.path}');
      return;
    }

    final sql = await sqlFile.readAsString();
    print('➤ Executing migration SQL...');

    // Split by semicolon if there are multiple statements,
    // but our file uses DO block which is one statement.
    // For safety with DO blocks, we usually execute the whole thing.
    await connection.execute(sql);

    print('\n🎉 Migration completed successfully!');
    print('   - Biometric data size limit fixed.');
  } catch (e) {
    print('❌ Error during migration: $e');
  } finally {
    await connection.close();
    print('\n📡 Database connection closed');
  }
}
