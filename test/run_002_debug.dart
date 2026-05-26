
import 'dart:io';
import '../lib/data/database/connection.dart';

void main() async {
  try {
    print('Running Migration 002 without exception swallowing...');
    await DatabaseConnection.getConnection();
    final session = await DatabaseConnection.getConnection();
    
    final sql = await File('database/migrations/002_add_missing_tenant_columns.sql').readAsString();
    // Remove the EXCEPTION block to see real errors
    var modifiedSql = sql.replaceFirst('EXCEPTION WHEN OTHERS THEN', '-- EXCEPTION WHEN OTHERS THEN');
    modifiedSql = modifiedSql.replaceFirst("RAISE NOTICE 'Error adding missing organization_id columns: %', SQLERRM;", '-- RAISE NOTICE');
    
    final statements = parseSqlStatements(modifiedSql);
    
    for (var stmt in statements) {
      if (stmt.trim().isEmpty) continue;
      print('Executing: ${stmt.substring(0, min(50, stmt.length))}...');
      await session.execute(stmt);
    }
    print('SUCCESS!');
  } catch (e) {
    print('FAILED: $e');
  }
}

int min(int a, int b) => a < b ? a : b;

List<String> parseSqlStatements(String schema) {
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

      if (inComment) {
        if (char == '\n') inComment = false;
        buffer.write(char);
        continue;
      }
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
        if (char == '-' && nextChar == '-') {
          inComment = true;
          buffer.write('--');
          i++;
          continue;
        }
        if (char == '/' && nextChar == '*') {
          inMultiLineComment = true;
          buffer.write('/*');
          i++;
          continue;
        }
      }
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
