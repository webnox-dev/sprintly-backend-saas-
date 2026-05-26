import 'package:webnox_sprintly_admin_backend/data/database/connection.dart';
import 'package:dotenv/dotenv.dart';

void main() async {
  // Load environment variables if needed
  DotEnv(includePlatformEnvironment: true).load();
  try {
    final result = await DatabaseConnection.query(
      "SELECT column_name FROM information_schema.columns WHERE table_schema = 'auth' AND table_name = 'users';",
    );
    print(result.map((e) => e['column_name']).toList());
  } catch (e) {
    print('ERROR: \$e');
  }
}
