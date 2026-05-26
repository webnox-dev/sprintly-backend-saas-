import 'dart:io';
import 'package:postgres/postgres.dart';

/// Script to create the office_locations table
Future<void> main() async {
  print('🔄 Running migration: Create office_locations table...\n');

  // Parse database URL from environment
  final dbUrl =
      Platform.environment['DATABASE_URL'] ??
      'postgres://postgres:1234@localhost:5432/webnox_sprintly';

  final uri = Uri.parse(dbUrl);
  final host = uri.host;
  final port = uri.port;
  final database = uri.pathSegments.first;
  final username = uri.userInfo.split(':').first;
  final password = uri.userInfo.split(':').last;

  print('📡 Connecting to database: $database@$host:$port');

  final connection = await Connection.open(
    Endpoint(
      host: host,
      port: port,
      database: database,
      username: username,
      password: password,
    ),
    settings: ConnectionSettings(sslMode: SslMode.disable),
  );

  try {
    print('✅ Connected to database\n');

    // Check if table already exists
    print('➤ Checking if office_locations table exists...');
    final checkResult = await connection.execute('''
      SELECT EXISTS (
        SELECT FROM information_schema.tables 
        WHERE table_name = 'office_locations'
      ) as table_exists
    ''');

    final exists = checkResult.first[0] as bool;
    if (exists) {
      print('  ℹ office_locations table already exists');
    } else {
      print('  Creating table...');
    }

    // Create office_locations table
    print('➤ Creating office_locations table...');
    await connection.execute('''
      CREATE TABLE IF NOT EXISTS office_locations (
        location_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        location_name VARCHAR(255) NOT NULL,
        address TEXT NOT NULL,
        latitude DOUBLE PRECISION NOT NULL,
        longitude DOUBLE PRECISION NOT NULL,
        radius_meters INTEGER NOT NULL DEFAULT 100,
        is_active BOOLEAN DEFAULT TRUE,
        public_ip VARCHAR(100),
        created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
        created_by VARCHAR(50),
        updated_by VARCHAR(50)
      )
    ''');
    print('  ✓ office_locations table created');

    // Create index for is_active
    print('➤ Creating index on is_active...');
    await connection.execute('''
      CREATE INDEX IF NOT EXISTS idx_office_locations_is_active 
      ON office_locations(is_active)
    ''');
    print('  ✓ is_active index created');

    // Create index for created_at
    print('➤ Creating index on created_at...');
    await connection.execute('''
      CREATE INDEX IF NOT EXISTS idx_office_locations_created_at 
      ON office_locations(created_at)
    ''');
    print('  ✓ created_at index created');

    // Create trigger for updated_at
    print('➤ Creating trigger for updated_at...');
    await connection.execute('''
      DROP TRIGGER IF EXISTS trigger_update_office_locations_updated_at ON office_locations
    ''');
    await connection.execute('''
      CREATE TRIGGER trigger_update_office_locations_updated_at 
        BEFORE UPDATE ON office_locations 
        FOR EACH ROW EXECUTE FUNCTION update_updated_at_column()
    ''');
    print('  ✓ updated_at trigger created');

    // Verify table was created
    print('\n➤ Verifying table structure...');
    final verifyResult = await connection.execute('''
      SELECT column_name, data_type 
      FROM information_schema.columns 
      WHERE table_name = 'office_locations'
      ORDER BY ordinal_position
    ''');

    print('  Columns in office_locations table:');
    for (final row in verifyResult) {
      print('    - ${row[0]}: ${row[1]}');
    }

    print('\n🎉 Migration completed successfully!');
    print('   - Table: office_locations');
    print(
      '   - Indexes: idx_office_locations_is_active, idx_office_locations_created_at',
    );
    print('   - Trigger: trigger_update_office_locations_updated_at');
  } catch (e, stack) {
    print('❌ Error during migration: $e');
    print('Stack trace: $stack');
  } finally {
    await connection.close();
    print('\n📡 Database connection closed');
  }
}
