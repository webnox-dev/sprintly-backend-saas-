import 'dart:io';
import 'package:postgres/postgres.dart';
import 'lib/config/app_config.dart';

void main() async {
  print('Checking projects detailed...');

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

    print('\n--- PROJECTS ---');
    final projects = await conn.execute(
      'SELECT project_id, project_name, project_team_leader_id, project_manager_id, project_team_member_ids FROM projects',
    );
    if (projects.isEmpty) {
      print('No projects found.');
    } else {
      for (final row in projects) {
        print(row.toColumnMap());
      }
    }

    await conn.close();
  } catch (e) {
    print('❌ Error: $e');
    exit(1);
  }
}
