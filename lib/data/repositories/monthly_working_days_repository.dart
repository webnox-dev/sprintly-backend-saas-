import 'dart:convert';
import '../../domain/models/monthly_working_days.dart';
import '../database/connection.dart';

class MonthlyWorkingDaysRepository {
  Future<List<MonthlyWorkingDays>> getAll() async {
    final result = await DatabaseConnection.query(
      'SELECT * FROM monthly_working_days ORDER BY year DESC, month DESC',
    );
    return result.map((row) => MonthlyWorkingDays.fromJson(row)).toList();
  }

  Future<MonthlyWorkingDays?> getById(String id) async {
    final result = await DatabaseConnection.query(
      'SELECT * FROM monthly_working_days WHERE working_days_id = @id',
      values: {'id': id},
    );
    if (result.isEmpty) return null;
    return MonthlyWorkingDays.fromJson(result.first);
  }

  Future<MonthlyWorkingDays?> getByMonthYear(int month, int year) async {
    final result = await DatabaseConnection.query(
      'SELECT * FROM monthly_working_days WHERE month = @month AND year = @year',
      values: {'month': month, 'year': year},
    );
    if (result.isEmpty) return null;
    return MonthlyWorkingDays.fromJson(result.first);
  }

  Future<MonthlyWorkingDays> create(MonthlyWorkingDays data) async {
    final result = await DatabaseConnection.query(
      '''
      INSERT INTO monthly_working_days (month, year, working_days, non_working_days, total_days, working_date_list, remarks, created_by, updated_by)
      VALUES (@month, @year, @workingDays, @nonWorkingDays, @totalDays, CAST(@workingDateList AS JSONB), @remarks, @createdBy, @updatedBy)
      RETURNING *
      ''',
      values: {
        'month': data.month,
        'year': data.year,
        'workingDays': data.workingDays,
        'nonWorkingDays': data.nonWorkingDays,
        'totalDays': data.totalDays,
        'workingDateList': jsonEncode(data.workingDateList),
        'remarks': data.remarks,
        'createdBy': data.createdBy,
        'updatedBy': data.updatedBy,
      },
    );
    return MonthlyWorkingDays.fromJson(result.first);
  }

  Future<MonthlyWorkingDays?> update(
    String id,
    Map<String, dynamic> updates,
  ) async {
    final setClauses = <String>[];
    final values = <String, dynamic>{'id': id};

    updates.forEach((key, value) {
      if (key != 'working_days_id' &&
          key != 'created_at' &&
          key != 'updated_at') {
        if (key == 'working_date_list' || value is List || value is Map) {
          setClauses.add('$key = CAST(@$key AS JSONB)');
          values[key] = jsonEncode(value);
        } else {
          setClauses.add('$key = @$key');
          values[key] = value;
        }
      }
    });

    if (setClauses.isEmpty) return await getById(id);

    setClauses.add('updated_at = NOW()');

    final query = '''
      UPDATE monthly_working_days 
      SET ${setClauses.join(', ')} 
      WHERE working_days_id = @id 
      RETURNING *
    ''';

    final result = await DatabaseConnection.query(query, values: values);
    if (result.isEmpty) return null;
    return MonthlyWorkingDays.fromJson(result.first);
  }

  Future<bool> delete(String id) async {
    final count = await DatabaseConnection.execute(
      'DELETE FROM monthly_working_days WHERE working_days_id = @id',
      values: {'id': id},
    );
    return count > 0;
  }
}
