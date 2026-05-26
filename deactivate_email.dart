import 'dart:io';
import 'package:postgres/postgres.dart';
import 'lib/config/app_config.dart';

void main() async {
  final email = 'hbpudhinraj@gmail.com';
  print('Deactivating email verification for $email...');

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

    final result = await conn.execute(
      'UPDATE auth.users SET email_confirmed_at = NULL WHERE email = \$1',
      parameters: [email],
    );

    print('Updated ${result.affectedRows} row(s).');

    await conn.close();
  } catch (e) {
    print('❌ Error: $e');
    exit(1);
  }
}
