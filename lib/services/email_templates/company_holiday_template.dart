/// Company Holiday Email Templates
/// Handles: Created, Updated, Deleted
class CompanyHolidayEmailTemplate {
  static String generateCreatedSubject(String holidayName) {
    return 'Company Holiday Added: $holidayName';
  }

  static String generateUpdatedSubject(String holidayName) {
    return 'Company Holiday Updated: $holidayName';
  }

  static String generateDeletedSubject(String holidayName) {
    return 'Company Holiday Removed: $holidayName';
  }

  static String generateCreatedEmail({
    required String recipientName,
    required String holidayName,
    required String fromDate,
    required String toDate,
    required int totalDays,
    String? remarks,
    required String createdBy,
    bool isOptional = false,
  }) {
    return '''
<!DOCTYPE html><html><head><meta charset="UTF-8"/><title>Company Holiday Added</title></head>
<body style="margin:0;font-family:Poppins,sans-serif;background:#eef1f5;padding:30px 0;">
<div style="max-width:680px;margin:0 auto;background:#fff;border-radius:14px;box-shadow:0 8px 28px rgba(0,0,0,.08);overflow:hidden;">
<div style="background:linear-gradient(135deg,#1565c0,#1e88e5);padding:35px 40px;"><h1 style="margin:0;color:#fff;font-size:26px;">Company Holiday Added</h1></div>
<div style="padding:40px;">
<p style="font-size:17px;font-weight:500;">Hello $recipientName,</p>
<p>A new company holiday has been added.</p>
<div style="background:#e3f2fd;padding:22px;border-radius:10px;margin:20px 0;">
<div><strong>Holiday:</strong> $holidayName</div>
<div><strong>Date(s):</strong> $fromDate${totalDays > 1 ? ' – $toDate' : ''}</div>
<div><strong>Total days:</strong> $totalDays</div>
${isOptional ? '<div><strong>Optional:</strong> Yes</div>' : ''}
${remarks != null && remarks.isNotEmpty ? '<div style="margin-top:10px;"><strong>Remarks:</strong> $remarks</div>' : ''}
<div><strong>Created by:</strong> $createdBy</div>
</div>
<p style="font-size:13px;color:#888;">Webnox Sprintly – automated notification</p>
</div></div></body></html>''';
  }

  static String generateUpdatedEmail({
    required String recipientName,
    required String holidayName,
    required String fromDate,
    required String toDate,
    required int totalDays,
    String? remarks,
    required String updatedBy,
    bool isOptional = false,
  }) {
    return '''
<!DOCTYPE html><html><head><meta charset="UTF-8"/><title>Company Holiday Updated</title></head>
<body style="margin:0;font-family:Poppins,sans-serif;background:#eef1f5;padding:30px 0;">
<div style="max-width:680px;margin:0 auto;background:#fff;border-radius:14px;box-shadow:0 8px 28px rgba(0,0,0,.08);overflow:hidden;">
<div style="background:linear-gradient(135deg,#ff6f00,#ffa000);padding:35px 40px;"><h1 style="margin:0;color:#fff;font-size:26px;">Company Holiday Updated</h1></div>
<div style="padding:40px;">
<p style="font-size:17px;font-weight:500;">Hello $recipientName,</p>
<p>The company holiday <strong>$holidayName</strong> has been updated.</p>
<div style="background:#fff3e0;padding:22px;border-radius:10px;margin:20px 0;">
<div><strong>Date(s):</strong> $fromDate${totalDays > 1 ? ' – $toDate' : ''}</div>
<div><strong>Total days:</strong> $totalDays</div>
${isOptional ? '<div><strong>Optional:</strong> Yes</div>' : ''}
${remarks != null && remarks.isNotEmpty ? '<div style="margin-top:10px;"><strong>Remarks:</strong> $remarks</div>' : ''}
<div><strong>Updated by:</strong> $updatedBy</div>
</div>
<p style="font-size:13px;color:#888;">Webnox Sprintly – automated notification</p>
</div></div></body></html>''';
  }

  static String generateDeletedEmail({
    required String recipientName,
    required String holidayName,
    required String deletedBy,
    String? reason,
  }) {
    return '''
<!DOCTYPE html><html><head><meta charset="UTF-8"/><title>Company Holiday Removed</title></head>
<body style="margin:0;font-family:Poppins,sans-serif;background:#eef1f5;padding:30px 0;">
<div style="max-width:680px;margin:0 auto;background:#fff;border-radius:14px;box-shadow:0 8px 28px rgba(0,0,0,.08);overflow:hidden;">
<div style="background:linear-gradient(135deg,#c62828,#ef5350);padding:35px 40px;"><h1 style="margin:0;color:#fff;font-size:26px;">Company Holiday Removed</h1></div>
<div style="padding:40px;">
<p style="font-size:17px;font-weight:500;">Hello $recipientName,</p>
<p>The company holiday <strong>$holidayName</strong> has been removed.</p>
<div style="background:#ffebee;padding:22px;border-radius:10px;margin:20px 0;">
<div><strong>Removed by:</strong> $deletedBy</div>
${reason != null && reason.isNotEmpty ? '<div style="margin-top:10px;"><strong>Reason:</strong> $reason</div>' : ''}
</div>
<p style="font-size:13px;color:#888;">Webnox Sprintly – automated notification</p>
</div></div></body></html>''';
  }
}
