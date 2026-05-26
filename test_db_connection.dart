import 'dart:io';
import 'package:postgres/postgres.dart';
import 'lib/config/app_config.dart';

void main() async {
  print('Testing database connection...');
  print('Connection string: ${AppConfig.databaseUrl.replaceAll(RegExp(r':[^:@]+@'), ':****@')}');
  
  try {
    // Try connecting to postgres database first
    final dbUrl = AppConfig.databaseUrl;
    final uri = Uri.parse(dbUrl);
    final dbName = uri.pathSegments.isNotEmpty ? uri.pathSegments.last : 'webnox_sprintly';
    
    final username = uri.userInfo.split(':').first;
    final password = uri.userInfo.split(':').length > 1 
        ? uri.userInfo.split(':').sublist(1).join(':') 
        : '';
    final host = uri.host.isEmpty ? 'localhost' : uri.host;
    final port = uri.port == 0 ? 5432 : uri.port;
    
    // Connect to postgres database
    print('\n1. Testing connection to "postgres" database...');
    
    try {
      final postgresEndpoint = Endpoint(
        host: host,
        port: port,
        database: 'postgres',
        username: username,
        password: password,
      );
      
      final conn = await Connection.open(
        postgresEndpoint,
        settings: ConnectionSettings(sslMode: SslMode.disable),
      );
      print('✅ Connected to postgres database');
      
      // Check if our database exists
      print('\n2. Checking if "$dbName" database exists...');
      final result = await conn.execute(
        Sql.named('SELECT 1 FROM pg_database WHERE datname = @dbName'),
        parameters: {'dbName': dbName},
      );
      
      if (result.isEmpty) {
        print('❌ Database "$dbName" does not exist');
        print('\n3. Creating database "$dbName"...');
        try {
          await conn.execute(Sql.indexed('CREATE DATABASE "$dbName"'));
          print('✅ Database "$dbName" created successfully');
        } catch (e) {
          print('❌ Failed to create database: $e');
        }
      } else {
        print('✅ Database "$dbName" exists');
      }
      
      await conn.close();
    } catch (e) {
      print('❌ Failed to connect to postgres database: $e');
      print('\nPossible issues:');
      print('1. Wrong username/password');
      print('2. PostgreSQL not configured to accept connections');
      print('3. Check pg_hba.conf file');
      exit(1);
    }
    
    // Now try connecting to our database
    print('\n4. Testing connection to "$dbName" database...');
    try {
      final dbEndpoint = Endpoint(
        host: host,
        port: port,
        database: dbName,
        username: username,
        password: password,
      );
      
      final conn = await Connection.open(
        dbEndpoint,
        settings: ConnectionSettings(sslMode: SslMode.disable),
      );
      print('✅ Connected to "$dbName" database successfully!');
      await conn.close();
      print('\n✅ All connection tests passed!');
    } catch (e) {
      print('❌ Failed to connect to "$dbName" database: $e');
      exit(1);
    }
  } catch (e, stackTrace) {
    print('❌ Error: $e');
    print('Stack: $stackTrace');
    exit(1);
  }
}
