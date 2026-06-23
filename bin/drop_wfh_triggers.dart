import 'package:postgres/postgres.dart';

/// Script to drop all triggers on work_from_home_requests table
void main() async {
  print('Connecting to database...');

  final connection = await Connection.open(
    Endpoint(
      host: '192.168.0.36',
      port: 5436,
      database: 'webnox_sprintly',
      username: 'postgres',
      password: '1234',
    ),
    settings: ConnectionSettings(sslMode: SslMode.disable),
  );

  print('Connected! Finding triggers...');

  try {
    // Find all triggers on the table
    final triggers = await connection.execute('''
      SELECT trigger_name FROM information_schema.triggers 
      WHERE event_object_table = 'work_from_home_requests'
      ''');

    print('Found ${triggers.length} trigger(s):');
    for (final row in triggers) {
      print('  - ${row[0]}');
    }

    if (triggers.isEmpty) {
      print('No triggers found. The issue might be in a function or view.');

      // Check for computed columns or views
      print('\nChecking for rules...');
      final rules = await connection.execute('''
        SELECT rulename FROM pg_rules 
        WHERE tablename = 'work_from_home_requests'
        ''');
      print('Found ${rules.length} rule(s)');
      for (final row in rules) {
        print('  - ${row[0]}');
      }
    } else {
      // Drop each trigger
      for (final row in triggers) {
        final triggerName = row[0] as String;
        print('Dropping trigger: $triggerName');
        await connection.execute(
          'DROP TRIGGER IF EXISTS "$triggerName" ON work_from_home_requests',
        );
        print('  ✅ Dropped');
      }
    }

    print('\nDone!');
  } catch (e) {
    print('Error: $e');
  } finally {
    await connection.close();
  }
}
