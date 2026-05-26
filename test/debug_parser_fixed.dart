
import 'dart:io';

void main() async {
  final sql = await File('database/migrations/001_saas_multitenancy.sql').readAsString();
  final statements = parseSqlStatements(sql);
  
  print('Found ${statements.length} statements.');
  for (var i = 0; i < statements.length; i++) {
    print('--- Statement ${i + 1} (len: ${statements[i].length}) ---');
    print(statements[i].substring(0, min(100, statements[i].length)));
    if (statements[i].length > 100) print('...');
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

      // Handle dollar quotes
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

      // Handle strings
      if (char == "'" && !inDollarQuote) {
        inString = !inString;
        buffer.write(char);
        continue;
      }

      // Handle semicolon split
      if (char == ';' && !inString && !inDollarQuote) {
        final stmt = buffer.toString().trim();
        if (stmt.isNotEmpty) statements.add(stmt);
        buffer.clear();
        continue;
      }

      buffer.write(char);
    }
    final finalStmt = buffer.toString().trim();
    if (finalStmt.isNotEmpty) statements.add(finalStmt);
    return statements;
  }
