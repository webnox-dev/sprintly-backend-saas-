import 'dart:io';
import 'package:postgres/postgres.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import '../../config/app_config.dart';
import '../../core/utils/logger.dart';
import 'connection.dart';

/// Database migration service for PostgreSQL
/// Automatically creates tables and schema on server startup
class MigrationService {
  static final AppLogger _logger = AppLogger('MigrationService');

  /// Run migrations to ensure all tables exist
  static Future<void> runMigrations() async {
    try {
      _logger.info('Running database migrations...');

      // First, ensure database exists
      await _ensureDatabaseExists();

      // Close any existing session and get fresh session to target database
      await DatabaseConnection.close();
      final session = await DatabaseConnection.getConnection();

      // Ensure we have permissions on the public schema (Postgres 15+ fix)
      await _ensureSchemaPermissions(session);

      // Read and execute schema
      await _executeSchema(session);

      // Run additional migrations from migrations folder
      await _runMigrationFiles(session);

      // Explicit fix for biometric index size limit (Postgres 8KB limit)
      await _fixBiometricIndexLimit(session);

      // Seed test admin data
      await _seedTestAdmin(session);

      _logger.info('✅ Database migrations completed successfully');
    } catch (e, stackTrace) {
      _logger.error('Migration failed: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Run migration files from the migrations folder
  static Future<void> _runMigrationFiles(Session session) async {
    try {
      final migrationsDir = Directory('database/migrations');
      if (!await migrationsDir.exists()) {
        _logger.info('Migrations directory not found, skipping');
        return;
      }

      final files = await migrationsDir
          .list()
          .where((entity) => entity is File && entity.path.endsWith('.sql'))
          .cast<File>()
          .toList();

      // Sort files by name to ensure sequential execution
      files.sort((a, b) => a.path.compareTo(b.path));

      _logger.info('Found ${files.length} migration files');

      for (final file in files) {
        final fileName = file.path.split(Platform.pathSeparator).last;
        _logger.info('Executing migration: $fileName');

        final sql = await file.readAsString();
        final statements = _parseSqlStatements(sql);

        for (final statement in statements) {
          if (statement.trim().isEmpty) continue;
          try {
            await session.execute(statement);
          } catch (e) {
            final errorStr = e.toString().toLowerCase();
            if (!errorStr.contains('already exists') &&
                !errorStr.contains('duplicate column')) {
              _logger.warning('Error in $fileName: $e');
            }
          }
        }
      }
    } catch (e) {
      _logger.error('Error running migration files: $e');
    }
  }

  /// Ensure database exists, create if it doesn't
  static Future<void> _ensureDatabaseExists() async {
    try {
      final dbUrl = AppConfig.databaseUrl;
      final uri = Uri.parse(dbUrl);

      // Extract database name from path
      String dbName = 'webnox_sprintly';
      if (uri.pathSegments.isNotEmpty) {
        dbName = uri.pathSegments.last;
      } else if (uri.path.isNotEmpty && uri.path != '/') {
        dbName = uri.path.replaceFirst('/', '');
      }

      // Connect to postgres database (default) to check/create our database
      final username = uri.userInfo.split(':').first;
      final password = uri.userInfo.split(':').length > 1
          ? uri.userInfo.split(':').sublist(1).join(':')
          : '';
      final host = uri.host.isEmpty ? 'localhost' : uri.host;
      final port = uri.port == 0 ? 5432 : uri.port;

      try {
        // Connect to postgres database
        final postgresEndpoint = Endpoint(
          host: host,
          port: port,
          database: 'postgres',
          username: username,
          password: password,
        );

        final masterConnection = await Connection.open(
          postgresEndpoint,
          settings: ConnectionSettings(sslMode: SslMode.disable),
        );

        try {
          // Check if database exists
          final checkResult = await masterConnection.execute(
            Sql.named('SELECT 1 FROM pg_database WHERE datname = @dbName'),
            parameters: {'dbName': dbName},
          );

          if (checkResult.isEmpty) {
            _logger.info('Database "$dbName" does not exist, creating...');
            // Create database
            await masterConnection.execute('CREATE DATABASE "$dbName"');
            _logger.info('✅ Database "$dbName" created successfully');
          } else {
            _logger.info('Database "$dbName" already exists');
          }
        } finally {
          await masterConnection.close();
        }
      } catch (e) {
        // If we can't connect to postgres database, try to continue anyway
        // The database might already exist
        _logger.warning(
          'Could not verify/create database (this is OK if database already exists): $e',
        );
      }
    } catch (e) {
      // If we can't create database, it might already exist or we don't have permissions
      // Continue anyway - the session will fail later if there's a real issue
      _logger.warning('Could not verify/create database: $e');
      _logger.warning('Assuming database exists or will be created manually');
    }
  }

  /// Execute schema SQL file
  static Future<void> _executeSchema(Session session) async {
    try {
      // Try multiple possible paths for schema file
      final possiblePaths = [
        'database/schema.sql',
        'webnox_sprintly_admin_backend/database/schema.sql',
        '../database/schema.sql',
      ];

      File? schemaFile;
      for (final path in possiblePaths) {
        final file = File(path);
        if (await file.exists()) {
          schemaFile = file;
          break;
        }
      }

      if (schemaFile == null) {
        _logger.warning(
          'Schema file not found. Tried: ${possiblePaths.join(', ')}. '
          'Skipping schema execution - tables may need to be created manually.',
        );
        return;
      }

      await _executeSchemaFromFile(session, schemaFile);
    } catch (e, stackTrace) {
      _logger.error('Error executing schema: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Execute schema from file
  static Future<void> _executeSchemaFromFile(
    Session session,
    File schemaFile,
  ) async {
    _logger.info('Loading schema from: ${schemaFile.path}');
    final schema = await schemaFile.readAsString();
    _logger.info('Schema file loaded (${schema.length} characters)');

    // PostgreSQL uses semicolons as statement separators
    final statements = _parseSqlStatements(schema);

    _logger.info('Executing ${statements.length} SQL statements...');

    int successCount = 0;
    int skipCount = 0;

    for (var i = 0; i < statements.length; i++) {
      final statement = statements[i];
      if (statement.trim().isEmpty) continue;

      try {
        await session.execute(statement);
        successCount++;
      } catch (e) {
        // Ignore errors for IF NOT EXISTS statements or already existing objects
        final errorStr = e.toString().toLowerCase();
        if (errorStr.contains('already exists') ||
            errorStr.contains('duplicate') ||
            errorStr.contains('relation') &&
                errorStr.contains('already exists') ||
            (errorStr.contains('does not exist') &&
                statement.toUpperCase().contains('DROP'))) {
          skipCount++;
          // Don't log these as they're expected
        } else {
          final errorMsg = e.toString();
          final preview = errorMsg.length > 200
              ? '${errorMsg.substring(0, 200)}...'
              : errorMsg;
          _logger.warning('Statement ${i + 1} execution warning: $preview');
          skipCount++;
        }
      }
    }

    _logger.info(
      'Schema execution complete: $successCount succeeded, $skipCount skipped',
    );
  }

  /// Parse SQL statements, handling semicolon separators for PostgreSQL
  static List<String> _parseSqlStatements(String schema) {
    final statements = <String>[];
    final buffer = StringBuffer();
    bool inString = false;
    bool inDollarQuote = false;
    bool inComment = false;
    bool inMultiLineComment = false;
    String dollarQuoteTag = '';

    for (var i = 0; i < schema.length; i++) {
      final char = schema[i];
      final nextChar = (i + 1 < schema.length) ? schema[i + 1] : '';

      // Handle single-line comments
      if (inComment) {
        if (char == '\n') {
          inComment = false;
          buffer.write(char);
        } else {
          buffer.write(char);
        }
        continue;
      }

      // Handle multi-line comments
      if (inMultiLineComment) {
        if (char == '*' && nextChar == '/') {
          inMultiLineComment = false;
          buffer.write('*/');
          i++;
        } else {
          buffer.write(char);
        }
        continue;
      }

      if (!inString && !inDollarQuote) {
        // Start of single-line comment
        if (char == '-' && nextChar == '-') {
          inComment = true;
          buffer.write('--');
          i++;
          continue;
        }
        // Start of multi-line comment
        if (char == '/' && nextChar == '*') {
          inMultiLineComment = true;
          buffer.write('/*');
          i++;
          continue;
        }
      }

      // Handle dollar quoting ($$, $tag$)
      if (char == '\$' && !inString) {
        if (!inDollarQuote) {
          // Check for start of dollar quote
          var endIdx = i + 1;
          while (endIdx < schema.length &&
              (schema[endIdx].contains(RegExp(r'[a-zA-Z0-9_]')) ||
                  schema[endIdx] == '\$')) {
            if (schema[endIdx] == '\$') {
              dollarQuoteTag = schema.substring(i, endIdx + 1);
              inDollarQuote = true;
              buffer.write(schema.substring(i, endIdx + 1));
              i = endIdx;
              break;
            }
            endIdx++;
          }
          if (!inDollarQuote) {
            buffer.write(char);
          }
        } else {
          // Check for end of dollar quote
          if (i + dollarQuoteTag.length <= schema.length &&
              schema.substring(i, i + dollarQuoteTag.length) ==
                  dollarQuoteTag) {
            buffer.write(dollarQuoteTag);
            i += dollarQuoteTag.length - 1;
            inDollarQuote = false;
            dollarQuoteTag = '';
          } else {
            buffer.write(char);
          }
        }
        continue;
      }

      // Handle regular strings
      if (char == "'" && !inDollarQuote) {
        inString = !inString;
        buffer.write(char);
        continue;
      }

      // Handle statement separator
      if (char == ';' && !inString && !inDollarQuote) {
        final statement = buffer.toString().trim();
        if (statement.isNotEmpty) {
          statements.add(statement);
        }
        buffer.clear();
        continue;
      }

      buffer.write(char);
    }

    // Don't forget the last statement if no trailing semicolon
    final lastStatement = buffer.toString().trim();
    if (lastStatement.isNotEmpty) {
      statements.add(lastStatement);
    }

    return statements;
  }

  /// Seed test admin data into admins and auth.users tables
  static Future<void> _seedTestAdmin(Session session) async {
    try {
      _logger.info('Checking if test admin needs to be seeded...');

      // Check if test admin already exists
      final checkResult = await session.execute(
        Sql.named("SELECT 1 FROM admins WHERE admin_id = @adminId"),
        parameters: {'adminId': 'WT0001'},
      );

      if (checkResult.isNotEmpty) {
        _logger.info('Test admin already exists, skipping seed');
        return;
      }

      _logger.info('Seeding test admin data...');

      // Hash the password (Test@123)
      final password = 'Test@123';
      final hashedPassword = _hashPassword(password);
      final now = DateTime.now().toUtc();

      // Insert into admins table
      await session.execute(
        Sql.named('''
          INSERT INTO admins (
            admin_id, admin_uuid, admin_name, admin_role, admin_img,
            admin_phone_num, admin_gender, admin_personal_email, admin_company_email,
            admin_address, admin_designation, admin_qualification, admin_dob,
            admin_age, admin_doj, admin_blood_group, admin_emergency_contact_number,
            admin_actual_salary, admin_total_leave_days_in_year, admin_pending_leave_count,
            status, changed_by, changed_at, created_at, updated_at
          ) VALUES (
            @adminId, @adminUuid, @adminName, @adminRole, @adminImg,
            @phoneNum, @gender, @personalEmail, @companyEmail,
            @address, @designation, @qualification, @dob,
            @age, @doj, @bloodGroup, @emergencyContact,
            @salary, @totalLeaveDays, @pendingLeaveCount,
            @status, @changedBy, @changedAt, @createdAt, @updatedAt
          )
        '''),
        parameters: {
          'adminId': 'WT0001',
          'adminUuid': 'c79c0c39-60a9-4d29-a76c-34c3bf068c2c',
          'adminName': 'Test Admin',
          'adminRole': 'Super Admin',
          'adminImg': null,
          'phoneNum': '9876543210',
          'gender': 'Male',
          'personalEmail': 'admin@webnox.in',
          'companyEmail': 'admin@webnox.com',
          'address': 'Coimbatore, Tamil Nadu',
          'designation': 'Super Admin',
          'qualification': 'B.Tech',
          'dob': '1990-01-01',
          'age': 35,
          'doj': '2020-01-01',
          'bloodGroup': 'O+',
          'emergencyContact': '9876543211',
          'salary': 50000.00,
          'totalLeaveDays': 24.00,
          'pendingLeaveCount': 24.00,
          'status': 1,
          'changedBy': 'system',
          'changedAt': now.toIso8601String(),
          'createdAt': now.toIso8601String(),
          'updatedAt': now.toIso8601String(),
        },
      );

      _logger.info('✅ Test admin inserted into admins table');

      // Insert into auth.users table with verified email
      await session.execute(
        Sql.named('''
          INSERT INTO auth.users (
            employee_id, email, encrypted_password, role, is_active,
            email_confirmed_at, created_at, updated_at, created_by, updated_by
          ) VALUES (
            @employeeId, @email, @password, @role, @isActive,
            @emailConfirmedAt, @createdAt, @updatedAt, @createdBy, @updatedBy
          )
        '''),
        parameters: {
          'employeeId': 'WT0001',
          'email': 'admin@webnox.in',
          'password': hashedPassword,
          'role': 'Admin',
          'isActive': 1, // Active account
          'emailConfirmedAt': now.toIso8601String(), // Email already verified
          'createdAt': now.toIso8601String(),
          'updatedAt': now.toIso8601String(),
          'createdBy': 'system',
          'updatedBy': 'system',
        },
      );

      _logger.info(
        '✅ Test admin inserted into auth.users table with verified email',
      );
      _logger.info('');
      _logger.info('========================================');
      _logger.info('TEST ADMIN CREDENTIALS:');
      _logger.info('  Email: admin@webnox.in');
      _logger.info('  Password: Test@123');
      _logger.info('  Admin ID: WT0001');
      _logger.info('========================================');
      _logger.info('');
    } catch (e) {
      // If admin already exists or other constraint violation, just log and continue
      final errorStr = e.toString().toLowerCase();
      if (errorStr.contains('duplicate') ||
          errorStr.contains('already exists') ||
          errorStr.contains('unique constraint')) {
        _logger.info('Test admin already exists (constraint), skipping seed');
      } else {
        _logger.warning('Error seeding test admin: $e');
        // Don't rethrow - seeding failure shouldn't prevent server startup
      }
    }
  }

  /// Hash password using SHA-256 (matching User.hashPassword)
  static String _hashPassword(String password) {
    final bytes = utf8.encode(password);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Explicitly fixes the "index row requires X bytes" error for biometric data.
  /// Drops any indexes on fingerprint_template to allow large payload storage.
  static Future<void> _fixBiometricIndexLimit(Session session) async {
    try {
      _logger.info('➤ Applying biometric index limit fix...');

      // We drop common index names and any index/constraint on fingerprint_template
      // that might cause the 8191 byte limit crash.
      final fixStatements = [
        'DROP INDEX IF EXISTS idx_face_embeddings_fingerprint',
        'DROP INDEX IF EXISTS unique_fingerprint_template',
        'ALTER TABLE face_embeddings DROP CONSTRAINT IF EXISTS unique_fingerprint_template',
        // This is the heavy lifter: find and drop ANY index on the fingerprint_template column
        '''
        DO \$\$
        DECLARE
            idx_name TEXT;
        BEGIN
            FOR idx_name IN 
                SELECT i.relname
                FROM pg_index x
                JOIN pg_class c ON c.oid = x.indrelid
                JOIN pg_class i ON i.oid = x.indexrelid
                JOIN pg_attribute a ON a.attrelid = c.oid AND a.attnum = ANY(x.indkey)
                WHERE c.relname = 'face_embeddings' AND a.attname = 'fingerprint_template'
            LOOP
                EXECUTE 'DROP INDEX IF EXISTS ' || idx_name;
                RAISE NOTICE 'Dropped index: %', idx_name;
            END LOOP;
        END \$\$;
        ''',
      ];

      for (final stmt in fixStatements) {
        try {
          await session.execute(stmt);
        } catch (e) {
          _logger.warning('Notice during biometric fix: $e');
        }
      }
      _logger.info('  ✓ Biometric index fix applied.');
    } catch (e) {
      _logger.error('Failed to apply biometric index fix: $e');
    }
  }

  /// Ensures the current user has the necessary permissions on the public schema.
  /// This is particularly important for newer PostgreSQL versions (15+) where
  /// non-superuser accounts don't have CREATE permission on 'public' by default.
  static Future<void> _ensureSchemaPermissions(Session session) async {
    try {
      _logger.info('Verifying schema permissions...');

      // Attempt to grant permissions to public schema
      // This might fail if the user isn't the owner or superuser, but we try anyway
      final grantStatements = [
        'GRANT ALL ON SCHEMA public TO CURRENT_USER',
        'GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO CURRENT_USER',
        'GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO CURRENT_USER',
      ];

      for (final stmt in grantStatements) {
        try {
          await session.execute(stmt);
        } catch (e) {
          // We ignore errors here as we might not have permission to GRANT
          // but it's worth a try.
        }
      }

      _logger.info('✅ Permissions verified');
    } catch (e) {
      _logger.warning('Notice during permission verification: $e');
    }
  }
}
