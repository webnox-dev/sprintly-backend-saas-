import 'package:webnox_sprintly_admin_backend/data/database/connection.dart';

void main() async {
  try {
    // Initialize connection if needed (assuming it uses env or defaults)
    // We might need to load .env first.

    final contentTemplates = await DatabaseConnection.query(
      'SELECT certificate_type, role, designation, template_name FROM certificate_content_templates',
    );

    print('--- CONTENT TEMPLATES ---');
    for (var t in contentTemplates) {
      print(
        'Type: ${t['certificate_type']}, Role: ${t['role']}, Desig: ${t['designation']}, Name: ${t['template_name']}',
      );
    }

    final employees = await DatabaseConnection.query(
      'SELECT employee_name, employee_role, employee_designation FROM employees LIMIT 5',
    );

    print('\n--- EMPLOYEES ---');
    for (var e in employees) {
      print(
        'Name: ${e['employee_name']}, Role: ${e['employee_role']}, Desig: ${e['employee_designation']}',
      );
    }

    final letterTemplates = await DatabaseConnection.query(
      'SELECT template_name, template_type FROM letter_templates',
    );

    print('\n--- LETTER TEMPLATES ---');
    for (var l in letterTemplates) {
      print('Name: ${l['template_name']}, Type: ${l['template_type']}');
    }
  } catch (e) {
    print('Error: $e');
  }
}
