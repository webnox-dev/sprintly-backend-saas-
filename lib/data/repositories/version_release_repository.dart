import '../../domain/models/version_release.dart';
import '../database/connection.dart';

class VersionReleaseRepository {
  Future<List<VersionRelease>> getAllReleases() async {
    final result = await DatabaseConnection.query(
      'SELECT * FROM version_releases ORDER BY release_date DESC, created_at DESC',
    );
    return result.map((row) => VersionRelease.fromJson(row)).toList();
  }

  Future<VersionRelease?> getReleaseById(String id) async {
    final result = await DatabaseConnection.query(
      'SELECT * FROM version_releases WHERE release_id = @id',
      values: {'id': id},
    );
    if (result.isEmpty) return null;
    return VersionRelease.fromJson(result.first);
  }

  Future<VersionRelease> createRelease(VersionRelease release) async {
    final result = await DatabaseConnection.query(
      '''
      INSERT INTO version_releases (version_number, release_notes, release_date, created_by, updated_by)
      VALUES (@version, @notes, @date, @createdBy, @updatedBy)
      RETURNING *
      ''',
      values: {
        'version': release.versionNumber,
        'notes': release.releaseNotes,
        'date':
            release.releaseDate?.toIso8601String().split('T')[0] ??
            DateTime.now().toIso8601String().split('T')[0],
        'createdBy': release.createdBy,
        'updatedBy': release.updatedBy,
      },
    );
    return VersionRelease.fromJson(result.first);
  }

  Future<VersionRelease?> updateRelease(
    String id,
    Map<String, dynamic> updates,
  ) async {
    final setClauses = <String>[];
    final values = <String, dynamic>{'id': id};

    updates.forEach((key, value) {
      if (key != 'release_id' && key != 'created_at' && key != 'updated_at') {
        setClauses.add('$key = @$key');
        values[key] = value;
      }
    });

    if (setClauses.isEmpty) return await getReleaseById(id);

    setClauses.add('updated_at = NOW()');

    final query =
        '''
      UPDATE version_releases 
      SET ${setClauses.join(', ')} 
      WHERE release_id = @id 
      RETURNING *
    ''';

    final result = await DatabaseConnection.query(query, values: values);
    if (result.isEmpty) return null;
    return VersionRelease.fromJson(result.first);
  }

  Future<bool> deleteRelease(String id) async {
    final count = await DatabaseConnection.execute(
      'DELETE FROM version_releases WHERE release_id = @id',
      values: {'id': id},
    );
    return count > 0;
  }
}
