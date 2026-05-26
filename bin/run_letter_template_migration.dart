import 'dart:io';
import 'package:postgres/postgres.dart';
import 'package:webnox_sprintly_admin_backend/config/app_config.dart';
import 'package:webnox_sprintly_admin_backend/data/database/connection.dart';

void main() async {
  print('🔄 Running letter template migration...');
  try {
    // Force AppConfig to load env
    AppConfig.initialize();

    final connection = await DatabaseConnection.getConnection();
    print('✅ Connected to database');

    final file = File('database/migrations/create_letter_templates_table.sql');
    final sql = await file.readAsString();

    // Split by semicolons for basic parsing
    final statements = sql
        .split(';')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    for (var stmt in statements) {
      if (stmt.isNotEmpty) {
        print(
          '➤ Executing: \n${stmt.substring(0, stmt.length > 50 ? 50 : stmt.length)}...',
        );
        try {
          await connection.execute(stmt);
          print('  ✓ Success');
        } catch (e) {
          if (e.toString().contains('already exists')) {
            print('  ✓ Skipped (already exists)');
          } else {
            print('  ❌ Error: $e');
          }
        }
      }
    }

    // Insert mock default templates
    await _seedDefaults(connection);

    print('\n🎉 Letter templates migration completed successfully!');
    await DatabaseConnection.close();
    exit(0);
  } catch (e) {
    print('❌ Migration failed: $e');
    exit(1);
  }
}

Future<void> _seedDefaults(Session conn) async {
  print('➤ Seeding default templates...');
  try {
    final checkSql = 'SELECT COUNT(*) FROM letter_templates';
    final result = await conn.execute(checkSql);
    final count = result[0][0] as int;

    if (count > 0) {
      print('  ✓ Templates already seeded');
      return;
    }

    final templates = [
      {
        'type': 'payslip',
        'name': 'Standard Payslip',
        'body':
            '<h2 style="text-align: center;">PAYSLIP</h2><p><strong>Month:</strong> {{payslip_month}}</p><p><strong>Employee:</strong> {{employee_name}} ({{employee_id}})</p><p><strong>Designation:</strong> {{designation}}</p><br>{{earnings_table}}<br>{{deductions_table}}',
      },
      {
        'type': 'offer_letter',
        'name': 'Standard Offer Letter',
        'body':
            '<h2 style="text-align: center;">OFFER LETTER</h2><p><strong>Date:</strong> {{current_date}}</p><p><strong>To:</strong> {{employee_name}}</p><p>Dear {{employee_name}},</p><p>We are pleased to offer you the position of <strong>{{designation}}</strong> at <strong>{{company_name}}</strong>, effective from <strong>{{date_of_joining}}</strong>.</p><p>Your compensation details are as follows:</p><ul><li>Annual CTC: ₹{{gross_salary}}</li><li>Department: {{department}}</li></ul><p>Please confirm your acceptance by signing and returning this letter.</p><p>Warm Regards,</p>',
      },
      {
        'type': 'internship_offer',
        'name': 'Standard Internship Offer',
        'body':
            '<h2 style="text-align: center;">INTERNSHIP OFFER</h2><p><strong>Date:</strong> {{current_date}}</p><p><strong>To:</strong> {{employee_name}}</p><p>Dear {{employee_name}},</p><p>We are pleased to offer you an internship as a <strong>{{internship_domain}} Intern</strong> at <strong>{{company_name}}</strong>. Your internship will commence on <strong>{{internship_start_date}}</strong> and end on <strong>{{internship_end_date}}</strong>.</p><p>Warm Regards,</p>',
      },
      {
        'type': 'internship_certificate',
        'name': 'Standard Internship Certificate',
        'body':
            '<h2 style="text-align: center;">CERTIFICATE OF COMPLETION</h2><p>This is to certify that <strong>{{employee_name}}</strong> has successfully completed their internship at <strong>{{company_name}}</strong> in the domain of <strong>{{internship_domain}}</strong>.</p><p>The duration of the internship was <strong>{{internship_duration}}</strong>, from <strong>{{internship_start_date}}</strong> to <strong>{{internship_end_date}}</strong>.</p><p>We wish them the very best in their future endeavors.</p>',
      },
      {
        'type': 'relieving',
        'name': 'Standard Relieving Letter',
        'body':
            '<h2 style="text-align: center;">RELIEVING LETTER</h2><p><strong>Date:</strong> {{current_date}}</p><p><strong>To:</strong> {{employee_name}}</p><p>Dear {{employee_name}},</p><p>This is to confirm that your resignation from the position of <strong>{{designation}}</strong> has been accepted, and you are being relieved from your duties at <strong>{{company_name}}</strong> as of the closing of business hours on <strong>{{date_of_relieving}}</strong>.</p><p>We wish you the best in your career.</p>',
      },
      {
        'type': 'termination',
        'name': 'Standard Termination Letter',
        'body':
            '<h2 style="text-align: center;">TERMINATION LETTER</h2><p><strong>Date:</strong> {{current_date}}</p><p><strong>To:</strong> {{employee_name}}</p><p>Dear {{employee_name}},</p><p>This letter is to inform you that your employment with <strong>{{company_name}}</strong> as a <strong>{{designation}}</strong> is terminated effective <strong>{{current_date}}</strong>.</p><p>Sincerely,</p>',
      },
    ];

    final sql = '''
      INSERT INTO letter_templates (template_type, template_name, body_content, is_default, created_by)
      VALUES (@type, @name, @body, true, 'system')
    ''';

    for (var t in templates) {
      await conn.execute(
        Sql.named(sql),
        parameters: {'type': t['type'], 'name': t['name'], 'body': t['body']},
      );
    }

    print('  ✓ Seeded ${templates.length} default templates');
  } catch (e) {
    print('  ❌ Seeding failed: $e');
  }
}
