// Run this script to insert office location data
// dart run bin/insert_office_location.dart

import 'package:postgres/postgres.dart';

Future<void> main() async {
  print('🔄 Connecting to database...');

  final connection = await Connection.open(
    Endpoint(
      host: '192.168.0.32',
      port: 5435,
      database: 'webnox_sprintly',
      username: 'postgres',
      password: '1234',
    ),
    settings: ConnectionSettings(sslMode: SslMode.disable),
  );

  print('✅ Connected to database');

  try {
    // First check if table exists
    print('🔄 Checking if office_locations table exists...');

    final tableCheck = await connection.execute('''
      SELECT EXISTS (
        SELECT FROM information_schema.tables 
        WHERE table_schema = 'public' 
        AND table_name = 'office_locations'
      )
    ''');

    final tableExists = tableCheck.first[0] as bool;

    if (!tableExists) {
      print('🔄 Creating office_locations table...');

      await connection.execute('''
        CREATE TABLE IF NOT EXISTS office_locations (
          location_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
          location_name text NOT NULL,
          address text NOT NULL,
          latitude double precision NOT NULL,
          longitude double precision NOT NULL,
          radius_meters integer NOT NULL DEFAULT 100,
          is_active boolean DEFAULT true,
          created_at timestamp with time zone DEFAULT now(),
          updated_at timestamp with time zone DEFAULT now(),
          created_by text,
          updated_by text,
          public_ip text
        )
      ''');

      print('✅ office_locations table created');
    } else {
      print('✅ office_locations table already exists');
    }

    // Check if record already exists
    print('🔄 Checking if office location already exists...');

    final existingCheck = await connection.execute(
      Sql.named(
        'SELECT location_id FROM office_locations WHERE location_id = @id',
      ),
      parameters: {'id': 'c8147753-9753-4bd7-a235-05484f908b4e'},
    );

    if (existingCheck.isNotEmpty) {
      print('⚠️ Office location already exists, skipping insert');
    } else {
      print('🔄 Inserting office location...');

      await connection.execute(
        Sql.named('''
          INSERT INTO office_locations (
            location_id, location_name, address, latitude, longitude, 
            radius_meters, is_active, created_at, updated_at, created_by, public_ip
          ) VALUES (
            @location_id, @location_name, @address, @latitude, @longitude,
            @radius_meters, @is_active, @created_at, @updated_at, @created_by, @public_ip
          )
        '''),
        parameters: {
          'location_id': 'c8147753-9753-4bd7-a235-05484f908b4e',
          'location_name': 'webnox',
          'address':
              'No.721/2, Venky complex, Second floor, Cross Cut Rd, Seth Narang Das Layout, Coimbatore, Tamil Nadu 641012',
          'latitude': 11.017,
          'longitude': 76.9574444444444,
          'radius_meters': 100,
          'is_active': true,
          'created_at': DateTime.parse('2025-12-30T10:02:21.051317Z'),
          'updated_at': DateTime.parse('2025-12-30T10:02:21.051317Z'),
          'created_by': 'WT0001',
          'public_ip': '49.204.233.0',
        },
      );

      print('✅ Office location inserted');
    }

    // Verify
    print('🔄 Verifying...');
    final verify = await connection.execute(
      'SELECT location_name, is_active, public_ip FROM office_locations',
    );
    for (var row in verify) {
      print('   📍 ${row[0]} - Active: ${row[1]} - IP: ${row[2]}');
    }

    print('✅ Migration completed successfully!');
  } catch (e, stackTrace) {
    print('❌ Error: $e');
    print('Stack: $stackTrace');
  } finally {
    await connection.close();
    print('🔒 Database connection closed');
  }
}
