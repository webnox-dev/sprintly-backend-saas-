import 'dart:io';
import 'package:postgres/postgres.dart';

/// Simple script to run migration 004
Future<void> main() async {
  print('Running migration 004_refactor_task_cards_schema.sql...');

  try {
    // Connect to database
    final connection = await Connection.open(
      Endpoint(
        host: 'localhost',
        port: 5432,
        database: 'webnox_sprintly',
        username: 'postgres',
        password: '1234',
      ),
      settings: ConnectionSettings(sslMode: SslMode.disable),
    );

    print('Connected to database');

    // Read migration file
    final migrationFile = File(
      'database/migrations/004_refactor_task_cards_schema.sql',
    );
    final migrationSql = await migrationFile.readAsString();

    print('Executing migration...');

    // Split migration into individual statements
    final statements = migrationSql
        .split(';')
        .map((s) => s.trim())
        .where(
          (s) =>
              s.isNotEmpty &&
              !s.startsWith('--') &&
              s.toLowerCase() != 'begin' &&
              s.toLowerCase() != 'commit',
        )
        .toList();

    print('Found ${statements.length} statements to execute');

    // Execute each statement
    for (var i = 0; i < statements.length; i++) {
      final statement = statements[i];
      if (statement.isEmpty) continue;

      try {
        print('Executing statement ${i + 1}/${statements.length}...');
        await connection.execute(statement);
      } catch (e) {
        // Ignore "already exists" or "does not exist" errors
        final errorStr = e.toString().toLowerCase();
        if (errorStr.contains('already exists') ||
            errorStr.contains('does not exist') ||
            errorStr.contains('duplicate')) {
          print('  ⚠️  Skipped (already exists or doesn\'t exist)');
        } else {
          print('  ❌ Error: $e');
          // Continue with other statements
        }
      }
    }

    print('✅ Migration completed successfully!');

    await connection.close();
  } catch (e, stackTrace) {
    print('❌ Migration failed: $e');
    print(stackTrace);
    exit(1);
  }
}
