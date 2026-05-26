# Email Notification System Implementation Plan

## Overview
Implement comprehensive email notifications triggered automatically from backend endpoints when specific CRUD operations occur. No separate API calls from frontend - emails are triggered within the actual endpoint handlers.

## Current State Analysis

### Existing Infrastructure
- **EmailService** (`lib/services/email_service.dart`):
  - Base `sendEmail()` method using n8n webhook
  - Existing templates: OTP, Password Reset, Welcome Employee
  
- **Email Templates Folder** (`lib/services/email_templates/`):
  - `task_card_request_template.dart` - Template for task request notifications

### Template Design Standards (Based on Existing)
- Use Poppins font from Google Fonts
- Professional gradient headers with context-appropriate colors
- Clean content sections with proper spacing
- Detail boxes with borders
- Warning/Info boxes where appropriate
- Footer with copyright and automated message notice
- **NO EMOJIS** as per requirements

---

## Email Templates Required

### 1. Task Card Emails
| Template | Trigger Event | Recipients |
|----------|--------------|------------|
| Task Created | POST /admin/task-cards | Assigned Employee |
| Task Updated | PUT /admin/task-cards/:id | Assigned Employee |
| Task Deleted | DELETE /admin/task-cards/:id | Assigned Employee |
| Task Duplicated | POST /admin/task-cards/:id/duplicate | New Assigned Employee |
| Task Reassigned | PUT /admin/task-cards/:id/reassign | Both Old & New Employee |
| Task Request Approved | PATCH /task-cards/:id/request/approve | Requesting Employee |
| Task Request Rejected | PATCH /task-cards/:id/request/reject | Requesting Employee |

### 2. Leave/Permission/WFH Request Emails
| Template | Trigger Event | Recipients |
|----------|--------------|------------|
| Leave Approved | PUT /leave/:id/approve | Requesting Employee |
| Leave Rejected | PUT /leave/:id/reject | Requesting Employee |
| Permission Approved | PUT /permissions/:id/approve | Requesting Employee |
| Permission Rejected | PUT /permissions/:id/reject | Requesting Employee |
| WFH Approved | PATCH /wfh/approveRejectWFHRequest/:id | Requesting Employee |
| WFH Rejected | PATCH /wfh/approveRejectWFHRequest/:id | Requesting Employee |

### 3. Project Emails
| Template | Trigger Event | Recipients |
|----------|--------------|------------|
| Project Created | POST /projects | Project Manager + Team Lead |
| Project Updated | PUT /projects/:id | Project Manager + Team Lead |
| Project Deleted | DELETE /projects/:id | Project Manager + Team Lead |
| Project Discontinued | PATCH /projects/:id/status (status=DISCONTINUED) | All Team Members |

### 4. Admin/Employee Onboarding & Status Emails
| Template | Trigger Event | Recipients |
|----------|--------------|------------|
| Admin Welcome | POST /admins | New Admin |
| Admin Deactivated | PUT /admins/updateAdminStatusById | Admin |
| Employee Welcome | POST /employees | New Employee |
| Employee Deactivated | PUT /employees/:id/status | Employee |
| Employee Exit | POST /employees/:id/exit | Employee |

### 5. Announcement Emails
| Template | Trigger Event | Recipients |
|----------|--------------|------------|
| Announcement Created | POST /announcements | All Active Employees & Admins |
| Announcement Updated | PUT /announcements/:id | All Active Employees & Admins |

### 6. Birthday & Work Anniversary Emails
| Template | Trigger Event | Recipients |
|----------|--------------|------------|
| Birthday Wishes | Scheduled (Daily cron) | Employee on Birthday |
| Work Anniversary | Scheduled (Daily cron) | Employee on Anniversary |

---

## Implementation Steps

### Phase 1: Create Email Templates (Files in `lib/services/email_templates/`)
1. `task_card_template.dart` - Task created/updated/deleted/duplicated/reassigned
2. `task_card_request_approval_template.dart` - Request approved/rejected
3. `leave_request_template.dart` - Leave approved/rejected
4. `permission_request_template.dart` - Permission approved/rejected
5. `wfh_request_template.dart` - WFH approved/rejected
6. `project_template.dart` - Project CRUD notifications
7. `admin_template.dart` - Admin welcome/deactivated
8. `employee_template.dart` - Employee welcome/deactivated/exit
9. `announcement_template.dart` - Announcement notifications
10. `celebration_template.dart` - Birthday/Work Anniversary

### Phase 2: Update EmailService
Add convenience methods for each email type that use the templates.

### Phase 3: Integrate Email Triggers in Routes
Modify route handlers to call EmailService after successful operations.

### Phase 4: Scheduled Jobs for Birthday/Anniversary
Create a scheduled task that runs daily to check and send celebration emails.

---

## File Structure
```
lib/services/
├── email_service.dart                    # Main email service
└── email_templates/
    ├── task_card_template.dart           # Task CRUD emails
    ├── task_card_request_template.dart   # Task request (exists)
    ├── leave_request_template.dart       # Leave approval emails
    ├── permission_request_template.dart  # Permission approval emails
    ├── wfh_request_template.dart         # WFH approval emails
    ├── project_template.dart             # Project CRUD emails
    ├── admin_template.dart               # Admin welcome/status
    ├── employee_template.dart            # Employee welcome/status
    ├── announcement_template.dart        # Announcement emails
    └── celebration_template.dart         # Birthday/Anniversary
```

---

## Color Scheme for Email Headers
- **Task Cards**: Purple gradient (#4a148c to #7b1fa2)
- **Leave/Permission/WFH**: Green/Red for Approved/Rejected
  - Approved: Green gradient (#2e7d32 to #43a047)
  - Rejected: Red gradient (#c62828 to #ef5350)
- **Projects**: Blue gradient (#1565c0 to #1e88e5)
- **Admin/Employee Welcome**: Purple-Indigo gradient (#4F46E5 to #7C3AED)
- **Admin/Employee Deactivated/Exit**: Orange-Red gradient (#e65100 to #ff6d00)
- **Announcements**: Teal gradient (#00695c to #00897b)
- **Birthday**: Pink gradient (#c2185b to #e91e63)
- **Work Anniversary**: Gold gradient (#f9a825 to #ffc107)

---

## Next Steps
1. Create all email template files
2. Update EmailService with new methods
3. Integrate email triggers in route handlers
4. Test each email flow
