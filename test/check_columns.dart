
import '../lib/data/database/connection.dart';

void main() async {
  try {
    final results = await DatabaseConnection.query(
      "SELECT table_name, column_name FROM information_schema.columns WHERE column_name = 'organization_id'",
      isGlobal: true
    );
    print('Tables with organization_id: ${results.map((r) => r['table_name']).toList()}');
  } catch (e) {
    print('Error: $e');
  }
}
