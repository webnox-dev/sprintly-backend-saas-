import 'dart:io';
import 'package:postgres/postgres.dart';

/// Migration script to add admin_cover_img column to admins table
Future<void> main() async {
  print('🔄 Running database migration for admin cover image...\n');

  // Parse database URL from environment
  final dbUrl =
      Platform.environment['DATABASE_URL'] ??
      'postgres://postgres:1234@localhost:5432/webnox_sprintly';

  final uri = Uri.parse(dbUrl);
  final host = uri.host;
  final port = uri.port;
  final database = uri.pathSegments.first;
  final username = uri.userInfo.split(':').first;
  final password = uri.userInfo.split(':').last;

  print('📡 Connecting to database: $database@$host:$port');

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

  try {
    print('✅ Connected to database\n');

    // Add admin_cover_img column
    print('➤ Adding admin_cover_img column to admins table...');
    await connection.execute('''
      ALTER TABLE admins 
      ADD COLUMN IF NOT EXISTS admin_cover_img TEXT
    ''');
    print('  ✓ admin_cover_img column added successfully!');

    print('\n🎉 Migration completed successfully!');
    print('   - admin_cover_img: TEXT (nullable)');
  } catch (e) {
    print('❌ Error during migration: $e');
  } finally {
    await connection.close();
    print('\n📡 Database connection closed');
  }
}
