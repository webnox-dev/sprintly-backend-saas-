
import 'dart:io';
import '../lib/data/database/connection.dart';

void main() async {
  try {
    print('Running Unified Migration Runner...');
    await DatabaseConnection.getConnection();
    final session = await DatabaseConnection.getConnection();
    
    final files = [
      'database/migrations/001_saas_multitenancy.sql',
      'database/migrations/002_add_missing_tenant_columns.sql'
    ];

    for (final filePath in files) {
      print('Processing $filePath...');
      final file = File(filePath);
      if (!await file.exists()) {
        print('File $filePath not found, skipping.');
        continue;
      }
      
      final sql = await file.readAsString();
      final statements = parseSqlStatements(sql);
      print('Executing ${statements.length} statements from ${filePath.split("/").last}...');
      
      int success = 0;
      int alreadyExists = 0;
      int failed = 0;

      for (var i = 0; i < statements.length; i++) {
        final stmt = statements[i].trim();
        if (stmt.isEmpty) continue;
        try {
          await session.execute(stmt);
          success++;
        } catch (e) {
          final errorStr = e.toString().toLowerCase();
          if (errorStr.contains('already exists') || errorStr.contains('duplicate')) {
            alreadyExists++;
          } else {
            failed++;
            print('Error in statement ${i+1}: ${stmt.substring(0, min(100, stmt.length))}... \nError: $e');
          }
        }
      }
      print('Result for ${filePath.split("/").last}: $success succeeded, $alreadyExists already exists, $failed failed.');
    }
    
    print('Done.');
    exit(0);
  } catch (e) {
    print('GLOBAL ERROR: $e');
    exit(1);
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
