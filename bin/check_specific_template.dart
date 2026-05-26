import 'package:webnox_sprintly_admin_backend/data/database/connection.dart';

void main() async {
  try {
    final results = await DatabaseConnection.query(
      "SELECT * FROM letter_templates WHERE id = '3dfee816-7129-450e-a130-a98e7d0db6e0'",
    );
    if (results.isEmpty) {
      print('Template not found');
      return;
    }
    final r = results.first;
    print('ID: ${r['id']}');
    print('Name: ${r['template_name']}');
    print('Header Config: ${r['header_config']}');
    print('Footer Config: ${r['footer_config']}');
    print('Watermark Config: ${r['watermark_config']}');
    print(
      'Body Content Sample: ${r['body_content'].toString().substring(0, min(100, r['body_content'].toString().length))}...',
    );
  } catch (e) {
    print('Error: $e');
  }
}

int min(int a, int b) => a < b ? a : b;
