import '../lib/data/database/connection.dart';
import '../lib/config/app_config.dart';

void main() async {
  AppConfig.initialize();
  
  try {
    final plans = await DatabaseConnection.query(
      'SELECT id, name, slug FROM subscription_plans',
      isGlobal: true
    );
    
    print('Current Plans in Database:');
    if (plans.isEmpty) {
      print('❌ No plans found!');
    } else {
      for (var plan in plans) {
        print('- ${plan['name']} (ID: ${plan['id']}, Slug: ${plan['slug']})');
      }
    }
  } catch (e) {
    print('❌ Error fetching plans: $e');
  } finally {
    await DatabaseConnection.close();
  }
}
