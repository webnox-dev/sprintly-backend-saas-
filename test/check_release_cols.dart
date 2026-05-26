
import '../lib/data/database/connection.dart';

void main() async {
  try {
    final results = await DatabaseConnection.query(
      "SELECT column_name FROM information_schema.columns WHERE table_name = 'release_attachments'",
      isGlobal: true
    );
    print('release_attachments columns: ${results.map((r) => r['column_name']).toList()}');
  } catch (e) {
    print('Error: $e');
  }
}
