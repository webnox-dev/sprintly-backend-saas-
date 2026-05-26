import 'dart:io';
import 'package:postgres/postgres.dart';
import 'lib/config/app_config.dart';

void main() async {
  print('Checking task card requests...');

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

    print('\n--- TASK CARD REQUESTS ---');
    final requests = await conn.execute(
      'SELECT * FROM task_card_requests LIMIT 20',
    );
    if (requests.isEmpty) {
      print('No requests found.');
    } else {
      for (final row in requests) {
        final map = row.toColumnMap();
        print(
          'ID: ${map['request_id']}, Task: ${map['task_name']}, Emp: ${map['employee_id']}, Status: ${map['request_status']}',
        );
      }
    }

    await conn.close();
  } catch (e) {
    print('❌ Error: $e');
    exit(1);
  }
}
