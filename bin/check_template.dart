import 'package:webnox_sprintly_admin_backend/data/database/connection.dart';

void main() async {
  try {
    final template = await DatabaseConnection.queryOne(
      "SELECT * FROM letter_templates WHERE template_name = 'Standard Internship Certificate'",
    );

    if (template == null) {
      print('Template not found');
      return;
    }

    print('--- TEMPLATE: ${template['template_name']} ---');
    print('Body Content: ${template['body_content']}');
  } catch (e) {
    print('Error: $e');
  }
}
