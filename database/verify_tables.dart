import 'package:postgres/postgres.dart';
import 'package:webnox_sprintly_admin_backend/config/app_config.dart';

/// Verify all tables exist
Future<void> main() async {
  try {
    print('Connecting to database...');

    final dbUrl = AppConfig.databaseUrl;
    final uri = Uri.parse(dbUrl);
    final username = uri.userInfo.split(':').first;
    final password = uri.userInfo.split(':').length > 1
        ? uri.userInfo.split(':').sublist(1).join(':')
        : '';
    final host = uri.host.isEmpty ? 'localhost' : uri.host;
    final port = uri.port == 0 ? 5432 : uri.port;
    final database = uri.pathSegments.isNotEmpty
        ? uri.pathSegments.last
        : 'webnox_sprintly';

    final endpoint = Endpoint(
      host: host,
      port: port,
      database: database,
      username: username,
      password: password,
    );

    final connection = await Connection.open(
      endpoint,
      settings: ConnectionSettings(sslMode: SslMode.disable),
    );

    print('\n✅ Connected to database: $database\n');
    print('=' * 60);
    print('TABLES IN DATABASE');
    print('=' * 60);

    final result = await connection.execute('''
      SELECT table_name 
      FROM information_schema.tables 
      WHERE table_schema = 'public'
      ORDER BY table_name
    ''');

    print('');
    for (final row in result) {
      print('  ✓ ${row[0]}');
    }

    print('');
    print('Total tables: ${result.length}');
    print('');

    // Check new tables specifically
    final newTables = [
      'projects',
      'task_cards',
      'task_card_requests',
      'team_cards',
      'task_card_logs',
    ];
    print('Checking new tables:');
    for (final table in newTables) {
      final exists = result.any((row) => row[0] == table);
      print('  ${exists ? '✅' : '❌'} $table');
    }

    await connection.close();
  } catch (e, stackTrace) {
    print('Error: $e');
    print('Stack: $stackTrace');
  }
}
