import '../../domain/models/role.dart';
import '../database/connection.dart';

class RoleRepository {
  Future<List<Role>> getAllRoles() async {
    final result = await DatabaseConnection.query(
      'SELECT * FROM roles ORDER BY role_name ASC',
    );
    return result.map((row) => Role.fromJson(row)).toList();
  }

  Future<Role?> getRoleById(String id) async {
    final result = await DatabaseConnection.query(
      'SELECT * FROM roles WHERE role_id = @id',
      values: {'id': id},
    );
    if (result.isEmpty) return null;
    return Role.fromJson(result.first);
  }

  Future<Role> createRole(Role role) async {
    final result = await DatabaseConnection.query(
      '''
      INSERT INTO roles (role_name, designations, is_active, created_by, updated_by)
      VALUES (@name, @designations, @isActive, @createdBy, @updatedBy)
      RETURNING *
      ''',
      values: {
        'name': role.roleName,
        'designations': role.designations,
        'isActive': role.isActive,
        'createdBy': role.createdBy,
        'updatedBy': role.updatedBy,
      },
    );
    return Role.fromJson(result.first);
  }

  Future<Role?> updateRole(String id, Map<String, dynamic> updates) async {
    final setClauses = <String>[];
    final values = <String, dynamic>{'id': id};

    updates.forEach((key, value) {
      if (key != 'role_id' && key != 'created_at' && key != 'updated_at') {
        setClauses.add('$key = @$key');
        values[key] = value;
      }
    });

    if (setClauses.isEmpty) return await getRoleById(id);

    setClauses.add('updated_at = NOW()');

    final query =
        '''
      UPDATE roles 
      SET ${setClauses.join(', ')} 
      WHERE role_id = @id 
      RETURNING *
    ''';

    final result = await DatabaseConnection.query(query, values: values);
    if (result.isEmpty) return null;
    return Role.fromJson(result.first);
  }

  Future<bool> deleteRole(String id) async {
    final count = await DatabaseConnection.execute(
      'DELETE FROM roles WHERE role_id = @id',
      values: {'id': id},
    );
    return count > 0;
  }
}
