import 'package:postgres/postgres.dart';
import 'package:webnox_sprintly_admin_backend/config/app_config.dart';

/// Script to add chat_theme_id to chat_conversations table
Future<void> main() async {
  print('🔄 Running database migration for chat theme...\n');

  // Initialize AppConfig to get the correct DB URL
  AppConfig.initialize();
  final dbUrl = AppConfig.databaseUrl;
  print('ℹ️ Using Database URL: $dbUrl');

  // Parse DB URL
  final uri = Uri.parse(dbUrl);
  final host = uri.host;
  final port = uri.port;
  final database = uri.pathSegments.first;
  // Handle case where userInfo might be empty or partial
  final userInfo = uri.userInfo.split(':');
  final username = userInfo.isNotEmpty ? userInfo.first : 'postgres';
  final password = userInfo.length > 1 ? userInfo.last : '';

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

    // Add chat_theme_id column
    print('➤ Adding chat_theme_id column...');
    await connection.execute('''
      ALTER TABLE chat_conversations 
      ADD COLUMN IF NOT EXISTS chat_theme_id VARCHAR(50) DEFAULT 'default_blue'
    ''');
    print('  ✓ chat_theme_id column added');

    print('\n🎉 Migration completed successfully!');
    print("   - chat_theme_id: VARCHAR(50) DEFAULT 'default_blue'");
  } catch (e) {
    print('❌ Error during migration: $e');
  } finally {
    await connection.close();
    print('\n📡 Database connection closed');
  }
}
