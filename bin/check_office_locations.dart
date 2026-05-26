import 'dart:io';
import 'package:postgres/postgres.dart';

Future<void> main() async {
  print('Checking office_locations table...\n');

  final dbUrl =
      Platform.environment['DATABASE_URL'] ??
      'postgres://postgres:1234@localhost:5432/webnox_sprintly';

  final uri = Uri.parse(dbUrl);
  final host = uri.host;
  final port = uri.port;
  final database = uri.pathSegments.first;
  final username = uri.userInfo.split(':').first;
  final password = uri.userInfo.split(':').last;

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
    final result = await connection.execute('''
      SELECT location_id, location_name, address, is_active 
      FROM office_locations 
      ORDER BY location_name
    ''');

    print('Found ${result.length} office locations:\n');

    if (result.isEmpty) {
      print('  (no locations found)');
    } else {
      for (final row in result) {
        print('  - ${row[1]} (${row[3] == true ? "active" : "inactive"})');
        print('    Address: ${row[2]}');
        print('');
      }
    }
  } catch (e) {
    print('Error: $e');
  } finally {
    await connection.close();
  }
}
