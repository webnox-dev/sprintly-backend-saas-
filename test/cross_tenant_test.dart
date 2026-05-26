
import 'dart:async';
import 'dart:io';
import '../lib/data/database/connection.dart';
import '../lib/data/repositories/project_repository.dart';

void main() async {
  print('--- CROSS-TENANT TESTING START ---');

  try {
    // 1. Setup Organizations
    print('1. Setting up Organizations...');
    // Clean up old test data
    await DatabaseConnection.execute('DELETE FROM projects WHERE project_name LIKE \'Secret Project%\'', isGlobal: true);
    await DatabaseConnection.execute('DELETE FROM organizations WHERE name LIKE \'Test Org%\'', isGlobal: true);
    
    final orgAResult = await DatabaseConnection.query(
      'INSERT INTO organizations (name, slug) VALUES (@name, @slug) RETURNING id',
      values: {'name': 'Test Org A', 'slug': 'test-org-a'},
      isGlobal: true,
    );
    final orgAId = orgAResult.first['id'].toString();

    final orgBResult = await DatabaseConnection.query(
      'INSERT INTO organizations (name, slug) VALUES (@name, @slug) RETURNING id',
      values: {'name': 'Test Org B', 'slug': 'test-org-b'},
      isGlobal: true,
    );
    final orgBId = orgBResult.first['id'].toString();

    print('Org A ID: $orgAId');
    print('Org B ID: $orgBId');

    // 2. Setup Data
    print('2. Setting up Isolated Data...');
    // Seed project in Org A
    await runWithTenant(orgAId, () async {
      await DatabaseConnection.execute(
        'INSERT INTO projects (project_name) VALUES (@name)',
        values: {'name': 'Secret Project Alpha'}
      );
    });

    // Seed project in Org B
    await runWithTenant(orgBId, () async {
      await DatabaseConnection.execute(
        'INSERT INTO projects (project_name) VALUES (@name)',
        values: {'name': 'Secret Project Beta'}
      );
    });

    // 3. Test Switching
    print('3. Testing Access Isolation...');
    
    print('Fetching projects for Org A...');
    await runWithTenant(orgAId, () async {
      final repo = ProjectRepository();
      final projects = await repo.getAll();
      final List data = projects['data'] ?? [];
      print('Org A Projects: ${data.map((p) => p['project_name']).toList()}');
      
      final hasBeta = data.any((p) => p['project_name'].toString().contains('Beta'));
      final hasAlpha = data.any((p) => p['project_name'].toString().contains('Alpha'));
      
      if (hasBeta) throw Exception('SECURITY BREACH: Org A saw Org B data!');
      if (!hasAlpha) throw Exception('ERROR: Org A could not see its own data!');
      print('✅ Org A isolation verified.');
    });

    print('Fetching projects for Org B...');
    await runWithTenant(orgBId, () async {
      final repo = ProjectRepository();
      final projects = await repo.getAll();
      final List data = projects['data'] ?? [];
      print('Org B Projects: ${data.map((p) => p['project_name']).toList()}');
      
      final hasAlpha = data.any((p) => p['project_name'].toString().contains('Alpha'));
      final hasBeta = data.any((p) => p['project_name'].toString().contains('Beta'));

      if (hasAlpha) throw Exception('SECURITY BREACH: Org B saw Org A data!');
      if (!hasBeta) throw Exception('ERROR: Org B could not see its own data!');
      print('✅ Org B isolation verified.');
    });

    print('--- CROSS-TENANT TESTING SUCCESS ---');
    
    // Cleanup
    print('Cleaning up...');
    await DatabaseConnection.execute('DELETE FROM projects WHERE project_name LIKE \'Secret Project%\'', isGlobal: true);
    await DatabaseConnection.execute('DELETE FROM organizations WHERE name LIKE \'Test Org%\'', isGlobal: true);
    
    exit(0);
  } catch (e, st) {
    print('--- CROSS-TENANT TESTING FAILED ---');
    print('Error: $e');
    print(st);
    exit(1);
  }
}

Future<void> runWithTenant(String orgId, FutureOr<void> Function() body) async {
  // Use the same symbol key as defined in tenant_middleware.dart
  const Symbol organizationIdKey = #organizationId;
  return runZoned(
    () async => await body(),
    zoneValues: {organizationIdKey: orgId},
  );
}
