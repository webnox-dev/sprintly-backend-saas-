class EmployeeDocumentEmailTemplate {
  /// Generate email template for document request
  static String generateDocumentRequestEmail({
    required String employeeName,
    required String adminName,
    required String documentList,
    required int documentCount,
  }) {
    return '''
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>Document Request</title>
    <link href="https://fonts.googleapis.com/css2?family=Poppins:wght@300;400;500;600;700&display=swap" rel="stylesheet" />
    <style>
        body { margin: 0; background: #eef1f5; padding: 30px 0; font-family: 'Poppins', sans-serif; color: #2b2d33; }
        .email-wrapper { max-width: 680px; margin: 0 auto; background: #ffffff; border-radius: 14px; overflow: hidden; box-shadow: 0 8px 28px rgba(0, 0, 0, 0.08); }
        .header { background: linear-gradient(135deg, #2563EB, #3B82F6); padding: 35px 40px; }
        .header h1 { margin: 0; font-size: 26px; font-weight: 600; color: #ffffff; }
        .content { padding: 40px; }
        .greeting { font-size: 17px; font-weight: 500; margin-bottom: 15px; color: #222; }
        p { font-size: 15px; line-height: 1.7; margin: 0 0 16px 0; color: #4a4e57; }
        .doc-list { margin: 20px 0; padding: 20px; background: #f8fafc; border-radius: 10px; border-left: 4px solid #2563EB; }
        .doc-list strong { color: #2563EB; }
        .info-box { margin: 20px 0; background: #e7f3ff; border-left: 4px solid #2563EB; padding: 18px; border-radius: 10px; font-size: 14px; color: #004085; line-height: 1.6; }
        .signature { margin-top: 20px; font-size: 14px; color: #4a4e57; font-weight: 500; }
        .footer { margin-top: 40px; text-align: center; padding: 24px 35px; background: #f0f2f6; border-top: 1px solid #e4e7ed; }
        .footer p { margin: 5px 0; font-size: 13px; color: #7a7e87; }
    </style>
</head>
<body>
    <div class="email-wrapper">
        <div class="header">
            <h1>📋 Document Request</h1>
        </div>
        <div class="content">
            <div class="greeting">Hello <strong>$employeeName</strong>,</div>
            <p>$adminName has requested you to submit the following document(s) for verification:</p>
            <div class="doc-list">
                <strong>Requested Documents ($documentCount):</strong><br><br>
                $documentList
            </div>
            <div class="info-box">
                <strong>Action Required:</strong> Please log in to the Sprintly Admin portal and upload the requested documents at your earliest convenience.
            </div>
            <div class="signature">
                Best regards,<br>
                <strong>Webnox Sprintly Admin Team</strong><br>
                Webnox Technologies Pvt Ltd
            </div>
        </div>
        <div class="footer">
            <p>This is an automated message. Please do not reply.</p>
            <p>© Webnox Technologies Pvt Ltd</p>
        </div>
    </div>
</body>
</html>
''';
  }

  /// Generate email template for document submission
  static String generateDocumentSubmittedEmail({
    required String adminName,
    required String employeeName,
    required String documentName,
  }) {
    return '''
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>Document Submitted</title>
    <link href="https://fonts.googleapis.com/css2?family=Poppins:wght@300;400;500;600;700&display=swap" rel="stylesheet" />
    <style>
        body { margin: 0; background: #eef1f5; padding: 30px 0; font-family: 'Poppins', sans-serif; color: #2b2d33; }
        .email-wrapper { max-width: 680px; margin: 0 auto; background: #ffffff; border-radius: 14px; overflow: hidden; box-shadow: 0 8px 28px rgba(0, 0, 0, 0.08); }
        .header { background: linear-gradient(135deg, #059669, #10B981); padding: 35px 40px; }
        .header h1 { margin: 0; font-size: 26px; font-weight: 600; color: #ffffff; }
        .content { padding: 40px; }
        .greeting { font-size: 17px; font-weight: 500; margin-bottom: 15px; color: #222; }
        p { font-size: 15px; line-height: 1.7; margin: 0 0 16px 0; color: #4a4e57; }
        .highlight-box { margin: 20px 0; padding: 20px; background: #ecfdf5; border-radius: 10px; border-left: 4px solid #059669; }
        .info-box { margin: 20px 0; background: #fef3c7; border-left: 4px solid #f59e0b; padding: 18px; border-radius: 10px; font-size: 14px; color: #92400e; line-height: 1.6; }
        .signature { margin-top: 20px; font-size: 14px; color: #4a4e57; font-weight: 500; }
        .footer { margin-top: 40px; text-align: center; padding: 24px 35px; background: #f0f2f6; border-top: 1px solid #e4e7ed; }
        .footer p { margin: 5px 0; font-size: 13px; color: #7a7e87; }
    </style>
</head>
<body>
    <div class="email-wrapper">
        <div class="header">
            <h1>✅ Document Submitted</h1>
        </div>
        <div class="content">
            <div class="greeting">Hello <strong>$adminName</strong>,</div>
            <p>An employee has submitted a document for your review.</p>
            <div class="highlight-box">
                <strong>Employee:</strong> $employeeName<br>
                <strong>Document:</strong> $documentName
            </div>
            <div class="info-box">
                <strong>Action Required:</strong> Please log in to the Sprintly Admin portal to review and approve/reject this document.
            </div>
            <div class="signature">
                Best regards,<br>
                <strong>Webnox Sprintly Admin System</strong>
            </div>
        </div>
        <div class="footer">
            <p>This is an automated message. Please do not reply.</p>
            <p>© Webnox Technologies Pvt Ltd</p>
        </div>
    </div>
</body>
</html>
''';
  }

  /// Generate email template for document review completion
  static String generateDocumentReviewedEmail({
    required String employeeName,
    required String documentName,
    required String status,
    String? adminComments,
  }) {
    final isApproved = status.toLowerCase() == 'approved';
    final headerColor = isApproved
        ? 'background: linear-gradient(135deg, #059669, #10B981);'
        : 'background: linear-gradient(135deg, #DC2626, #EF4444);';
    final boxColor = isApproved
        ? 'background: #ecfdf5; border-left: 4px solid #059669;'
        : 'background: #fef2f2; border-left: 4px solid #DC2626;';
    final statusText = isApproved ? '✅ Approved' : '❌ Rejected';
    final statusLabel = isApproved ? 'Approved' : 'Rejected';

    return '''
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>Document $statusLabel</title>
    <link href="https://fonts.googleapis.com/css2?family=Poppins:wght@300;400;500;600;700&display=swap" rel="stylesheet" />
    <style>
        body { margin: 0; background: #eef1f5; padding: 30px 0; font-family: 'Poppins', sans-serif; color: #2b2d33; }
        .email-wrapper { max-width: 680px; margin: 0 auto; background: #ffffff; border-radius: 14px; overflow: hidden; box-shadow: 0 8px 28px rgba(0, 0, 0, 0.08); }
        .header { $headerColor padding: 35px 40px; }
        .header h1 { margin: 0; font-size: 26px; font-weight: 600; color: #ffffff; }
        .content { padding: 40px; }
        .greeting { font-size: 17px; font-weight: 500; margin-bottom: 15px; color: #222; }
        p { font-size: 15px; line-height: 1.7; margin: 0 0 16px 0; color: #4a4e57; }
        .status-box { margin: 20px 0; padding: 20px; $boxColor border-radius: 10px; }
        .comments-box { margin: 20px 0; padding: 18px; background: #f8fafc; border-radius: 10px; border: 1px dashed #cbd5e1; }
        .signature { margin-top: 20px; font-size: 14px; color: #4a4e57; font-weight: 500; }
        .footer { margin-top: 40px; text-align: center; padding: 24px 35px; background: #f0f2f6; border-top: 1px solid #e4e7ed; }
        .footer p { margin: 5px 0; font-size: 13px; color: #7a7e87; }
    </style>
</head>
<body>
    <div class="email-wrapper">
        <div class="header">
            <h1>Document $statusLabel</h1>
        </div>
        <div class="content">
            <div class="greeting">Hello <strong>$employeeName</strong>,</div>
            <p>Your submitted document has been reviewed.</p>
            <div class="status-box">
                <strong>Document:</strong> $documentName<br>
                <strong>Status:</strong> $statusText
            </div>
            ${adminComments != null && adminComments.isNotEmpty ? '''
            <div class="comments-box">
                <strong>Admin Comments:</strong><br>
                $adminComments
            </div>
            ''' : ''}
            ${!isApproved ? '''
            <p><strong>Note:</strong> Please review the admin comments and resubmit the document with the required corrections if needed.</p>
            ''' : ''}
            <div class="signature">
                Best regards,<br>
                <strong>Webnox Sprintly Admin Team</strong>
            </div>
        </div>
        <div class="footer">
            <p>This is an automated message. Please do not reply.</p>
            <p>© Webnox Technologies Pvt Ltd</p>
        </div>
    </div>
</body>
</html>
''';
  }
}
