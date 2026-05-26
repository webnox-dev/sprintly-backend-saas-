import 'dart:io';
import 'package:postgres/postgres.dart';
import 'lib/config/app_config.dart';

void main() async {
  print('Checking auth users...');

  try {
    final dbUrl = AppConfig.databaseUrl;
    final uri = Uri.parse(dbUrl);
    final dbName = uri.pathSegments.isNotEmpty
        ? uri.pathSegments.last
        : 'webnox_sprintly';
    final username = uri.userInfo.split(':').first;
    final password = uri.userInfo.split(':').length > 1
        ? uri.userInfo.split(':').sublist(1).join(':')
        : '';
    final host = uri.host.isEmpty ? 'localhost' : uri.host;
    final port = uri.port == 0 ? 5432 : uri.port;

    final dbEndpoint = Endpoint(
      host: host,
      port: port,
      database: dbName,
      username: username,
      password: password,
    );

    final conn = await Connection.open(
      dbEndpoint,
      settings: ConnectionSettings(sslMode: SslMode.disable),
    );

    print('\n--- AUTH USERS ---');
    final users = await conn.execute(
      'SELECT email, employee_id, email_confirmed_at, is_active FROM auth.users',
    );
    if (users.isEmpty) {
      print('No users found in auth.users.');
    } else {
      for (final row in users) {
        print(row.toColumnMap());
      }
    }

    await conn.close();
  } catch (e) {
    print('❌ Error: $e');
    exit(1);
  }
}
