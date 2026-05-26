import '../../domain/models/future_plan.dart';
import '../database/connection.dart';

class FuturePlanRepository {
  Future<List<FuturePlan>> getAllPlans() async {
    final result = await DatabaseConnection.query(
      'SELECT * FROM future_plans ORDER BY created_at DESC',
    );
    return result.map((row) => FuturePlan.fromJson(row)).toList();
  }

  Future<FuturePlan?> getPlanById(String id) async {
    final result = await DatabaseConnection.query(
      'SELECT * FROM future_plans WHERE plan_id = @id',
      values: {'id': id},
    );
    if (result.isEmpty) return null;
    return FuturePlan.fromJson(result.first);
  }

  Future<FuturePlan> createPlan(FuturePlan plan) async {
    final result = await DatabaseConnection.query(
      '''
      INSERT INTO future_plans (title, plan, created_by, updated_by)
      VALUES (@title, @plan, @createdBy, @updatedBy)
      RETURNING *
      ''',
      values: {
        'title': plan.title,
        'plan': plan.plan,
        'createdBy': plan.createdBy,
        'updatedBy': plan.updatedBy,
      },
    );
    return FuturePlan.fromJson(result.first);
  }

  Future<FuturePlan?> updatePlan(
    String id,
    Map<String, dynamic> updates,
  ) async {
    final setClauses = <String>[];
    final values = <String, dynamic>{'id': id};

    updates.forEach((key, value) {
      if (key != 'plan_id' && key != 'created_at' && key != 'updated_at') {
        setClauses.add('$key = @$key');
        values[key] = value;
      }
    });

    if (setClauses.isEmpty) return await getPlanById(id);

    setClauses.add('updated_at = NOW()');

    final query =
        '''
      UPDATE future_plans 
      SET ${setClauses.join(', ')} 
      WHERE plan_id = @id 
      RETURNING *
    ''';

    final result = await DatabaseConnection.query(query, values: values);
    if (result.isEmpty) return null;
    return FuturePlan.fromJson(result.first);
  }

  Future<bool> deletePlan(String id) async {
    final count = await DatabaseConnection.execute(
      'DELETE FROM future_plans WHERE plan_id = @id',
      values: {'id': id},
    );
    return count > 0;
  }
}
