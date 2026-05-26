import 'package:webnox_sprintly_admin_backend/data/database/connection.dart';

void main() async {
  try {
    final certs = await DatabaseConnection.query(
      "SELECT id, certificate_type, role, body_content FROM certificate_content_templates",
    );
    for (var c in certs) {
      print('CERT ID: ${c['id']}');
      print('Role: ${c['role']}');
      print(
        'Content Prefix: ${c['body_content'].toString().substring(0, 50)}...',
      );
      print('---');
    }
  } catch (e) {
    print('Error: $e');
  }
}
