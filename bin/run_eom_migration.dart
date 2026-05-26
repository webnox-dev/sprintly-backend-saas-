import 'dart:io';
import 'package:postgres/postgres.dart';
import 'package:webnox_sprintly_admin_backend/config/app_config.dart';

/// Runs the Employee of the Month (EOM) tables migration.
/// Execute from project root: dart run bin/run_eom_migration.dart
Future<void> main() async {
  print('🔄 Running Employee of the Month (EOM) database migration...\n');

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

  print('📡 Connecting to database: $database@$host:$port');

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
      settings: ConnectionSettings(
        sslMode: SslMode.disable,
        connectTimeout: const Duration(seconds: 10),
      ),
    );
  } catch (e) {
    print('❌ Failed to connect: $e');
    exit(1);
  }

  try {
    print('✅ Connected\n');

    final sqlFile = File('database/migrations/create_employee_of_the_month_tables.sql');
    if (!await sqlFile.exists()) {
      print('❌ Migration file not found: ${sqlFile.path}');
      print('   Run this script from the backend project root (webnox_sprintly_backend).');
      exit(1);
    }

    final sql = await sqlFile.readAsString();
    final statements = _parseSqlStatements(sql);
    print('➤ Executing ${statements.length} statement(s)...\n');

    for (final stmt in statements) {
      final t = stmt.trim();
      if (t.isEmpty) continue;
      try {
        final result = await connection.execute(stmt);
        if (t.toUpperCase().startsWith('CREATE TABLE')) {
          final name = t.contains('eom_points_config')
              ? 'eom_points_config'
              : t.contains('employee_eom_points_daily')
                  ? 'employee_eom_points_daily'
                  : t.contains('employee_monthly_rankings')
                      ? 'employee_monthly_rankings'
                      : t.contains('employee_of_the_month')
                          ? 'employee_of_the_month'
                          : 'table';
          print('  ✓ $name');
        } else if (t.toUpperCase().startsWith('INSERT INTO')) {
          print('  ✓ eom_points_config default row');
        } else if (t.toUpperCase().startsWith('CREATE INDEX')) {
          print('  ✓ index');
        } else if (t.toUpperCase().startsWith('COMMENT ON')) {
          print('  ✓ comment');
        } else if (t.toUpperCase().startsWith('SELECT') &&
            result.isNotEmpty &&
            result.first.isNotEmpty) {
          print('  ✓ ${result.first[0]}');
        }
      } catch (e) {
        final err = e.toString().toLowerCase();
        if (err.contains('already exists') || err.contains('duplicate')) {
          print('  ⏭ skipped (already exists)');
        } else {
          print('  ❌ Error: $e');
          rethrow;
        }
      }
    }

    print('\n🎉 EOM migration completed successfully.');
    print('   Tables: eom_points_config, employee_eom_points_daily,');
    print('           employee_monthly_rankings, employee_of_the_month');
  } catch (e) {
    print('❌ Migration failed: $e');
    exit(1);
  } finally {
    await connection.close();
    print('\n📡 Database connection closed.');
  }
}

/// Split SQL into statements (semicolon-separated). Strip leading comment lines so
/// that CREATE TABLE is not skipped when the file starts with -- comments.
List<String> _parseSqlStatements(String sql) {
  final list = <String>[];
  final buffer = StringBuffer();
  bool inSingleQuote = false;

  for (var i = 0; i < sql.length; i++) {
    final c = sql[i];
    if (c == "'" && (i == 0 || sql[i - 1] != '\\')) {
      inSingleQuote = !inSingleQuote;
      buffer.write(c);
      continue;
    }
    if (!inSingleQuote && c == ';') {
      final s = _stripLeadingComments(buffer.toString().trim());
      if (s.isNotEmpty) {
        list.add(s);
      }
      buffer.clear();
      continue;
    }
    buffer.write(c);
  }
  final last = _stripLeadingComments(buffer.toString().trim());
  if (last.isNotEmpty) {
    list.add(last);
  }
  return list;
}

String _stripLeadingComments(String statement) {
  final lines = statement.split('\n');
  final kept = <String>[];
  bool foundNonComment = false;
  for (final line in lines) {
    final t = line.trim();
    if (foundNonComment) {
      kept.add(line);
    } else if (t.isNotEmpty && !t.startsWith('--')) {
      foundNonComment = true;
      kept.add(line);
    }
  }
  return kept.join('\n').trim();
}
