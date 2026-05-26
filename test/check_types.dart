
import '../lib/data/database/connection.dart';

void main() async {
  try {
    final results = await DatabaseConnection.query(
      "SELECT table_name, column_name, data_type FROM information_schema.columns WHERE table_name IN ('project_documents', 'projects', 'task_cards', 'task_card_time_tracking')",
      isGlobal: true
    );
    for (var r in results) {
      print("${r['table_name']}.${r['column_name']}: ${r['data_type']}");
    }
  } catch (e) {
    print('Error: $e');
  }
}
