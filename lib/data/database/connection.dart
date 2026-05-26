import 'dart:async';
import 'package:postgres/postgres.dart';
import '../../config/app_config.dart';
import '../../core/exceptions/app_exception.dart';
import '../../core/utils/logger.dart';
import '../../core/middleware/tenant_middleware.dart';

/// Database connection manager for PostgreSQL using Connection Pooling
class DatabaseConnection {
  static Pool? _pool;
  static final AppLogger _logger = AppLogger('DatabaseConnection');

  /// Get database pool (singleton)
  static Pool getPool() {
    if (_pool != null) {
      return _pool!;
    }
    return _initPool();
  }

  /// Get current organization ID from zone context
  static String? getCurrentOrganizationId() {
    try {
      return Zone.current[#organizationId] as String?;
    } catch (_) {
      return null;
    }
  }

  static Pool _initPool() {

    final dbUrl = AppConfig.databaseUrl;
    final safeUrl = _maskPassword(dbUrl);
    _logger.info('Initializing database pool: $safeUrl');

    try {
      final uri = Uri.parse(dbUrl);
      final userInfo = uri.userInfo.split(':');
      final username = userInfo.first;
      final password = userInfo.length > 1 ? userInfo.sublist(1).join(':') : '';
      final host = uri.host.isEmpty ? 'localhost' : uri.host;
      final port = uri.port == 0 ? 5432 : uri.port;
      final database = uri.pathSegments.isNotEmpty
          ? uri.pathSegments.last
          : (uri.path.isNotEmpty && uri.path != '/'
                 ? uri.path.replaceFirst('/', '')
                 : 'webnox_sprintly');

      final endpoint = Endpoint(
        host: host,
        port: port,
        database: database,
        username: username,
        password: password,
      );

      // Initialize pool with reasonable concurrency
      _pool = Pool.withEndpoints(
        [endpoint],
        settings: PoolSettings(
          maxConnectionCount: AppConfig.isProduction ? 10 : 3,
          sslMode: SslMode.disable,
        ),
      );

      _logger.info('✅ Database pool initialized successfully');

      return _pool!;
    } catch (e, stackTrace) {
      _logger.error('❌ Failed to initialize database pool', e, stackTrace);
      throw DatabaseException(
        message: 'Failed to initialize database pool. Error: $e',
      );
    }
  }

  /// COMPATIBILITY: Get a single database connection.
  /// Note: In v3, the Pool handles connections automatically.
  /// For checking connectivity or long-lived tasks like migrations.
  static Future<Session> getConnection() async {
    return getPool();
  }

  /// Mask password in connection string for logging
  static String _maskPassword(String url) {
    try {
      final uri = Uri.parse(url);
      if (uri.userInfo.isNotEmpty) {
        final parts = uri.userInfo.split(':');
        if (parts.length >= 2) {
          final password = parts.sublist(1).join(':');
          return url.replaceFirst(password, '***');
        }
      }
      return url;
    } catch (e) {
      return url;
    }
  }

  /// Close database pool
  static Future<void> close() async {
    if (_pool != null) {
      await _pool!.close();
      _pool = null;
      _logger.info('Database pool closed');
    }
  }

  static Future<List<Map<String, dynamic>>> query(
    String sql, {
    Map<String, dynamic>? values,
    bool isGlobal = false,
  }) async {
    final pool = getPool();
    final organizationId = getCurrentOrganizationId();

    String finalSql = sql;
    Map<String, dynamic> finalValues = values ?? {};

    if (!isGlobal && organizationId != null) {
      finalSql = _applyTenantFilter(sql);
      // Only add the parameter if the resulting SQL actually uses it
      // This avoids "superfluous variables" error in postgres v3
      if (finalSql.contains('@organizationId')) {
        finalValues['organizationId'] = organizationId;
      }
    }

    try {
      Result result;

      if (finalValues.isNotEmpty) {
        result = await pool.execute(Sql.named(finalSql), parameters: finalValues);
      } else {
        result = await pool.execute(finalSql);
      }

      // Convert Result to list of maps
      if (result.isEmpty) {
        return [];
      }

      final List<Map<String, dynamic>> rows = [];
      for (final row in result) {
        final Map<String, dynamic> rowMap = {};
        for (final column in result.schema.columns) {
          rowMap[column.columnName!] = row.toColumnMap()[column.columnName];
        }
        rows.add(rowMap);
      }

      return rows;
    } catch (e, stackTrace) {
      // Don't log SQL or values to avoid info leakage if it propagates
      _logger.error('Database query error: $e', stackTrace);
      throw DatabaseException(
        message: 'Database query failed.',
        // Only keep original error for internal logging/debugging if needed
        // but hide it from the message that might go to the client
      );
    }
  }

  /// Execute a query and return single row
  static Future<Map<String, dynamic>?> queryOne(
    String sql, {
    Map<String, dynamic>? values,
    bool isGlobal = false,
  }) async {
    final results = await query(sql, values: values, isGlobal: isGlobal);
    return results.isNotEmpty ? results.first : null;
  }

  /// Execute an insert/update/delete query
  static Future<int> execute(
    String sql, {
    Map<String, dynamic>? values,
    bool isGlobal = false,
  }) async {
    final pool = getPool();
    final organizationId = getCurrentOrganizationId();

    String finalSql = sql;
    Map<String, dynamic> finalValues = values ?? {};

    if (!isGlobal && organizationId != null) {
      finalSql = _applyTenantFilter(sql);
      // Only add the parameter if the resulting SQL actually uses it
      if (finalSql.contains('@organizationId')) {
        finalValues['organizationId'] = organizationId;
      }
    }

    try {
      Result result;

      if (finalValues.isNotEmpty) {
        result = await pool.execute(Sql.named(finalSql), parameters: finalValues);
      } else {
        result = await pool.execute(finalSql);
      }

      return result.affectedRows;
    } catch (e, stackTrace) {
      _logger.error('Database execute error: $e', stackTrace);
      throw DatabaseException(
        message: 'Database operation failed.',
      );
    }
  }

  /// Execute a transaction safely using individual session
  static Future<T> transaction<T>(
    Future<T> Function(Session) callback,
  ) async {
    final pool = getPool();

    try {
       return await pool.withConnection((connection) async {
         return await connection.runTx((session) async {
           return await callback(session);
         });
       });
    } catch (e, stackTrace) {
      _logger.error('Transaction error: $e', stackTrace);
      // Re-throw formatted if it's already an AppException, or wrap it
      if (e is AppException) rethrow;
      throw DatabaseException(message: 'Database transaction failed.');
    }
  }

  /// Robust SQL injection for tenant filtering that handles subqueries
  static String _applyTenantFilter(String sql) {
    // Avoid double filtering
    if (sql.contains('organization_id')) {
      return sql;
    }

    // Strip comments for detection to avoid false positives (like words inside comments)
    final commentRegex = RegExp(r'--.*$', multiLine: true);
    final sqlWithoutComments = sql.replaceAll(commentRegex, '');
    final upperSql = sqlWithoutComments.trim().toUpperCase();

    // Tables that should NEVER be filtered
    final globalTables = [
      'ORGANIZATIONS',
      'SUBSCRIPTION_PLANS',
      'SUPER_ADMINS',
      'SUPER_ADMIN_AUDIT_LOGS',
      'VERSION_RELEASES',
      'FUTURE_PLANS',
      'SYSTEM_TASK_LOGS'
    ];

    for (final table in globalTables) {
      if (upperSql.contains('FROM $table') ||
          upperSql.contains('UPDATE $table') ||
          upperSql.contains('INTO $table') ||
          upperSql.contains('JOIN $table')) {
        return sql;
      }
    }

    // Handle INSERT
    if (upperSql.startsWith('INSERT')) {
      final matches = RegExp(r'\(([^)]*)\)').allMatches(sqlWithoutComments).toList();
      if (matches.length >= 2) {
        var newSql = sqlWithoutComments;
        final valMatch = matches[1];
        final valPos = valMatch.start + 1;
        newSql = newSql.replaceRange(valPos, valPos, '@organizationId, ');
        final colMatch = matches[0];
        final colPos = colMatch.start + 1;
        newSql = newSql.replaceRange(colPos, colPos, 'organization_id, ');
        return newSql;
      }
      return sqlWithoutComments;
    }

    // Find top-level WHERE and tail
    int wherePos = -1;
    int tailPos = -1;
    int depth = 0;
    
    for (var i = 0; i < sqlWithoutComments.length; i++) {
      final char = sqlWithoutComments[i];
      if (char == '(') depth++;
      if (char == ')') depth--;
      
      if (depth == 0 && i + 5 <= sqlWithoutComments.length) {
        final substring = sqlWithoutComments.substring(i, i + 5).toUpperCase();
        if (substring.startsWith('WHERE') && (i + 5 == sqlWithoutComments.length || RegExp(r'\s').hasMatch(sqlWithoutComments[i+5]))) {
          if (wherePos == -1) wherePos = i;
        }
      }
      
      if (depth == 0 && i + 8 <= sqlWithoutComments.length) {
        final substring = sqlWithoutComments.substring(i, i + 8).toUpperCase();
        if ((substring.startsWith('ORDER BY') || substring.startsWith('LIMIT') || substring.startsWith('GROUP BY'))) {
          if (tailPos == -1) tailPos = i;
        }
      }
    }

    // Detect prefix from top-level FROM
    String prefix = '';
    int fromPos = -1;
    depth = 0;
    for (var i = 0; i < sqlWithoutComments.length; i++) {
      if (sqlWithoutComments[i] == '(') depth++;
      if (sqlWithoutComments[i] == ')') depth--;
      if (depth == 0 && i + 4 <= sqlWithoutComments.length && sqlWithoutComments.substring(i, i + 4).toUpperCase() == 'FROM') {
        fromPos = i;
        break;
      }
    }

    if (fromPos != -1) {
      final fromTail = sqlWithoutComments.substring(fromPos);
      final fromMatch = RegExp(r'\bFROM\s+(\w+)\s+([a-zA-Z_]\w*)\b', caseSensitive: false).firstMatch(fromTail);
      if (fromMatch != null) {
        final alias = fromMatch.group(2)!;
        if (!['WHERE', 'JOIN', 'GROUP', 'ORDER', 'LIMIT', 'LEFT', 'RIGHT', 'INNER', 'OUTER'].contains(alias.toUpperCase())) {
          prefix = '$alias.';
        }
      }
    }

    String result;
    if (wherePos != -1) {
      // Insert after WHERE at top level
      final insertPos = wherePos + 5;
      result = sqlWithoutComments.replaceRange(insertPos, insertPos, ' ${prefix}organization_id = @organizationId AND ');
    } else if (tailPos != -1) {
      // Insert before tail at top level
      result = sqlWithoutComments.replaceRange(tailPos, tailPos, ' WHERE ${prefix}organization_id = @organizationId ');
    } else {
      // Append to end
      result = '$sqlWithoutComments WHERE ${prefix}organization_id = @organizationId';
    }

    return result;
  }
}
