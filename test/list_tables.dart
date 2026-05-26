
import '../lib/data/database/connection.dart';

void main() async {
  try {
    final results = await DatabaseConnection.query(
      "SELECT table_name FROM information_schema.tables WHERE table_schema = 'public'",
      isGlobal: true
    );
    print('Tables: ${results.map((r) => r['table_name']).toList()}');
  } catch (e) {
    print('Error: $e');
  }
}
