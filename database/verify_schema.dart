import 'package:postgres/postgres.dart';
import 'package:webnox_sprintly_admin_backend/config/app_config.dart';

/// Quick script to verify the employee_attendance table schema
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
    print('EMPLOYEE_ATTENDANCE TABLE SCHEMA');
    print('=' * 60);

    final result = await connection.execute('''
      SELECT column_name, data_type, is_nullable, column_default
      FROM information_schema.columns 
      WHERE table_name = 'employee_attendance'
      ORDER BY ordinal_position
    ''');

    print('');
    print(
      '${'Column Name'.padRight(25)}${'Data Type'.padRight(20)}${'Nullable'.padRight(10)}Default',
    );
    print('-' * 80);

    for (final row in result) {
      final columnName = row[0]?.toString() ?? '';
      final dataType = row[1]?.toString() ?? '';
      final nullable = row[2]?.toString() ?? '';
      final defaultVal = row[3]?.toString() ?? '';

      print(
        '${columnName.padRight(25)}${dataType.padRight(20)}${nullable.padRight(10)}${defaultVal.length > 25 ? '${defaultVal.substring(0, 25)}...' : defaultVal}',
      );
    }

    print('');
    print('Total columns: ${result.length}');
    print('');

    await connection.close();
  } catch (e, stackTrace) {
    print('Error: $e');
    print('Stack: $stackTrace');
  }
}
