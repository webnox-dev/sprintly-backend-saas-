
import 'dart:io';
import '../lib/data/database/connection.dart';
import '../lib/data/database/migration_service.dart';

void main() async {
  try {
    print('Running MigrationService logic...');
    // Manual setup to avoid port conflicts and only run what we need
    await DatabaseConnection.getConnection();
    
    // Use the internal method via a custom runner if needed, 
    // or just copy the parsing logic correctly.
    
    final sql = await File('database/migrations/001_saas_multitenancy.sql').readAsString();
    // Use the SAME parsing logic as the service
    final statements = parseSqlStatements(sql);
    
    print('Executing 001_saas_multitenancy.sql (${statements.length} statements)...');
    final session = await DatabaseConnection.getConnection();
    
    for (var i = 0; i < statements.length; i++) {
      final stmt = statements[i].trim();
      if (stmt.isEmpty) continue;
      try {
        await session.execute(stmt);
      } catch (e) {
        final errorStr = e.toString().toLowerCase();
        if (!errorStr.contains('already exists') && !errorStr.contains('duplicate')) {
          print('Error in statement ${i+1}: ${stmt.substring(0, min(100, stmt.length))}... \nError: $e');
        }
      }
    }
    
    // Also run 002
    final sql2 = await File('database/migrations/002_add_missing_tenant_columns.sql').readAsString();
    final statements2 = parseSqlStatements(sql2);
    print('Executing 002_add_missing_tenant_columns.sql (${statements2.length} statements)...');
    for (var stmt in statements2) {
      if (stmt.trim().isEmpty) continue;
      try {
        await session.execute(stmt);
      } catch (e) {
        if (!e.toString().contains('already exists')) {
          print('Error in 002: $e');
        }
      }
    }
    
    print('Done.');
    exit(0);
  } catch (e) {
    print('FAILED: $e');
    exit(1);
  }
}

int min(int a, int b) => a < b ? a : b;

// Copy-pasted from MigrationService to ensure identical behavior
List<String> parseSqlStatements(String schema) {
    final statements = <String>[];
    final buffer = StringBuffer();
    bool inString = false;
    bool inDollarQuote = false;
    String dollarQuoteTag = '';

    for (var i = 0; i < schema.length; i++) {
      final char = schema[i];
      if (char == '\$' && !inString) {
        if (!inDollarQuote) {
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
          if (!inDollarQuote) buffer.write(char);
        } else {
          if (i + dollarQuoteTag.length <= schema.length &&
              schema.substring(i, i + dollarQuoteTag.length) == dollarQuoteTag) {
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
      if (char == "'" && !inDollarQuote) {
        inString = !inString;
        buffer.write(char);
        continue;
      }
      if (char == ';' && !inString && !inDollarQuote) {
        statements.add(buffer.toString().trim());
        buffer.clear();
        continue;
      }
      buffer.write(char);
    }
    if (buffer.toString().trim().isNotEmpty) statements.add(buffer.toString().trim());
    return statements;
  }
