import 'package:postgres/postgres.dart';
import 'package:webnox_sprintly_admin_backend/config/app_config.dart';

Future<void> main() async {
  AppConfig.initialize();
  final dbUrl = AppConfig.databaseUrl;

  print('📡 Connecting to: $dbUrl');

  final uri = Uri.parse(dbUrl);
  final host = uri.host;
  final port = uri.port;
  final database = uri.pathSegments.last;
  final username = uri.userInfo.split(':').first;
  final password = uri.userInfo.split(':').last;

  Connection? connection;
  try {
    connection = await Connection.open(
      Endpoint(
        host: host,
        port: port,
        database: database,
        username: username,
        password: password,
      ),
      settings: ConnectionSettings(sslMode: SslMode.disable),
    );

    print('\n🔍 --- INDEXES ON face_embeddings ---');
    final indexes = await connection.execute(
      "SELECT indexname, indexdef FROM pg_indexes WHERE tablename = 'face_embeddings'",
    );
    for (final row in indexes) {
      print('Index: ${row[0]}');
      print('Def:   ${row[1]}\n');
    }

    print('\n🔒 --- CONSTRAINTS ON face_embeddings ---');
    final constraints = await connection.execute(
      "SELECT conname, contype, pg_get_constraintdef(oid) FROM pg_constraint WHERE conrelid = 'face_embeddings'::regclass",
    );
    for (final row in constraints) {
      print('Name: ${row[0]} (Type: ${row[1]})');
      print('Def:  ${row[2]}\n');
    }
  } catch (e) {
    print('❌ Error: $e');
  } finally {
    await connection?.close();
  }
}
