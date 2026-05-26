
import 'dart:io';
import '../lib/data/database/connection.dart';

void main() async {
  try {
    final sql = await File('database/migrations/001_saas_multitenancy.sql').readAsString();
    final statements = parseSqlStatements(sql);
    
    print('Executing 001_saas_multitenancy.sql (${statements.length} statements)...');
    for (var i = 0; i < statements.length; i++) {
      final stmt = statements[i].trim();
      if (stmt.isEmpty) continue;
      try {
        await DatabaseConnection.execute(stmt, isGlobal: true);
      } catch (e) {
        final errorStr = e.toString().toLowerCase();
        if (!errorStr.contains('already exists') && !errorStr.contains('duplicate')) {
          print('Error in statement ${i+1}: ${stmt.substring(0, min(100, stmt.length))}... \nError: $e');
        }
      }
    }
    print('Done.');
  } catch (e) {
    print('Error: $e');
  }
}

int min(int a, int b) => a < b ? a : b;

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
    if (buffer.isNotEmpty) statements.add(buffer.toString().trim());
    return statements;
  }
