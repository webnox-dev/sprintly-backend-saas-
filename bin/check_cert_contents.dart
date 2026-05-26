import 'package:webnox_sprintly_admin_backend/data/database/connection.dart';

void main() async {
  try {
    final results = await DatabaseConnection.query(
      "SELECT * FROM certificate_content_templates",
    );
    for (var r in results) {
      print('--- ID: ${r['id']} ---');
      print('Type: ${r['certificate_type']}');
      print('Role: ${r['role']}');
      print('Designation: ${r['designation']}');
      print('Content: ${r['body_content']}');
      print('---');
    }
  } catch (e) {
    print('Error: $e');
  }
}
