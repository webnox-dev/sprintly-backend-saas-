import 'dart:convert';
import '../lib/data/database/connection.dart';
import '../lib/config/app_config.dart';

void main() async {
  AppConfig.initialize();
  
  try {
    final plans = await DatabaseConnection.query(
      'SELECT id, name, slug, features::text FROM subscription_plans',
      isGlobal: true
    );
    print('--- PLANS ---');
    for (var p in plans) {
      print('Plan: ${p['name']} (${p['slug']})');
      print('Features: ${p['features']}');
      print('');
    }

    final orgs = await DatabaseConnection.query(
      'SELECT id, name, slug, plan_id FROM organizations',
      isGlobal: true
    );
    print('--- ORGANIZATIONS ---');
    for (var o in orgs) {
      print('Org: ${o['name']} (${o['slug']})');
      print('Plan ID: ${o['plan_id']}');
      print('');
    }
  } catch (e) {
    print('Error: $e');
  } finally {
    await DatabaseConnection.close();
  }
}
