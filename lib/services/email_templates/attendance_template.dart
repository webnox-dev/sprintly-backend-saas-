import '../../domain/models/employee.dart';

/// Email templates for attendance related notifications
class AttendanceEmailTemplate {
  /// Generate "No Status Today" notification email for admins
  static String generateNoStatusNoticeEmail({
    required List<Employee> employees,
    required String date,
  }) {
    final employeeRows = employees.map((emp) => '''
      <tr>
        <td style="padding: 12px; border-bottom: 1px solid #eee; font-weight: 600; color: #333;">${emp.employeeName}</td>
        <td style="padding: 12px; border-bottom: 1px solid #eee; color: #555;">${emp.employeeId}</td>
        <td style="padding: 12px; border-bottom: 1px solid #eee; color: #555;">${emp.employeePersonalEmail}</td>
        <td style="padding: 12px; border-bottom: 1px solid #eee; color: #555;">${emp.employeePhoneNum}</td>
        <td style="padding: 12px; border-bottom: 1px solid #eee; color: #555;">${emp.employeeRole} / ${emp.employeeDesignation}</td>
      </tr>
    ''').join('');

    return '''
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8" />
<meta name="viewport" content="width=device-width, initial-scale=1.0" />
<title>Daily Attendance Alert - No Status Today</title>
<link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&display=swap" rel="stylesheet" />
<style>
body { margin: 0; background-color: #f4f7fa; font-family: 'Inter', -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; color: #333; }
.container { max-width: 800px; margin: 40px auto; background-color: #ffffff; border-radius: 12px; overflow: hidden; box-shadow: 0 4px 20px rgba(0, 0, 0, 0.08); }
.header { background: linear-gradient(135deg, #e53935 0%, #d32f2f 100%); padding: 30px 40px; color: #ffffff; }
.header h1 { margin: 0; font-size: 24px; font-weight: 700; letter-spacing: -0.5px; }
.header p { margin: 8px 0 0; font-size: 14px; opacity: 0.9; }
.content { padding: 40px; }
.summary-box { background-color: #fff8f7; border-left: 4px solid #e53935; padding: 20px; border-radius: 4px; margin-bottom: 30px; }
.summary-box p { margin: 0; font-size: 15px; line-height: 1.6; color: #b71c1c; }
.table-container { width: 100%; overflow-x: auto; margin-top: 20px; border: 1px solid #eee; border-radius: 8px; }
table { width: 100%; border-collapse: collapse; min-width: 600px; }
th { background-color: #f8f9fa; padding: 12px; text-align: left; font-size: 13px; font-weight: 600; color: #666; border-bottom: 2px solid #eee; }
.footer { background-color: #f8f9fa; padding: 20px 40px; text-align: center; border-top: 1px solid #eee; font-size: 12px; color: #999; }
.footer p { margin: 4px 0; }
</style>
</head>
<body>
<div class="container">
    <div class="header">
        <h1>Daily Attendance Alert</h1>
        <p>No Status Today - $date</p>
    </div>
    <div class="content">
        <div class="summary-box">
            <p>The following employees have not punched in by 10:30 AM today and do not have any approved or pending Leave, Permission, or WFH requests.</p>
        </div>
        
        <h3 style="font-size: 18px; margin-bottom: 16px; color: #222;">Identified Employees (${employees.length})</h3>
        
        <div class="table-container">
            <table>
                <thead>
                    <tr>
                        <th>Employee Name</th>
                        <th>ID</th>
                        <th>Email</th>
                        <th>Phone</th>
                        <th>Role / Designation</th>
                    </tr>
                </thead>
                <tbody>
                    $employeeRows
                </tbody>
            </table>
        </div>
        
        <p style="margin-top: 30px; font-size: 14px; color: #666; line-height: 1.6;">
            Please check with the respective employees regarding their attendance status. This is a system-generated automated notification.
        </p>
    </div>
    <div class="footer">
        <p>© ${DateTime.now().year} Webnox Sprintly Admin Dashboard</p>
        <p>A Product by Mobile App Team | Webnox Technologies Pvt Ltd</p>
    </div>
</div>
</body>
</html>
    ''';
  }
}
