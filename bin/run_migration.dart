import 'dart:io';
import 'package:postgres/postgres.dart';

/// Script to add is_public and invite_code columns to chat_conversations table
Future<void> main() async {
  print('🔄 Running database migration for chat group visibility...\n');

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

    // Add is_public column
    print('➤ Adding is_public column...');
    await connection.execute('''
      ALTER TABLE chat_conversations 
      ADD COLUMN IF NOT EXISTS is_public BOOLEAN DEFAULT FALSE
    ''');
    print('  ✓ is_public column added');

    // Add invite_code column
    print('➤ Adding invite_code column...');
    await connection.execute('''
      ALTER TABLE chat_conversations 
      ADD COLUMN IF NOT EXISTS invite_code VARCHAR(50) UNIQUE
    ''');
    print('  ✓ invite_code column added');

    // Create index for invite_code
    print('➤ Creating index on invite_code...');
    await connection.execute('''
      CREATE INDEX IF NOT EXISTS idx_chat_conversations_invite_code 
      ON chat_conversations(invite_code) 
      WHERE invite_code IS NOT NULL
    ''');
    print('  ✓ invite_code index created');

    // Create index for is_public
    print('➤ Creating index on is_public...');
    await connection.execute('''
      CREATE INDEX IF NOT EXISTS idx_chat_conversations_is_public 
      ON chat_conversations(is_public) 
      WHERE is_public = TRUE
    ''');
    print('  ✓ is_public index created');

    print('\n🎉 Migration completed successfully!');
    print('   - is_public: BOOLEAN DEFAULT FALSE');
    print('   - invite_code: VARCHAR(50) UNIQUE');
  } catch (e) {
    print('❌ Error during migration: $e');
  } finally {
    await connection.close();
    print('\n📡 Database connection closed');
  }
}
