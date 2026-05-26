import 'dart:convert';
import '../database/connection.dart';
import '../../core/utils/logger.dart';
import '../../core/exceptions/app_exception.dart';

/// Repository for Organizations — scoped to Super Admin use only.
/// All public-facing admin/employee calls go through standard routes + middleware.
class OrganizationRepository {
  final AppLogger _log = AppLogger('OrganizationRepository');

  // ──────────────────────────────────────────────────────────────────────────
  // ORGANIZATION QUERIES
  // ──────────────────────────────────────────────────────────────────────────

  /// Get all organizations (paginated + searchable)
  Future<Map<String, dynamic>> getAll({
    String? search,
    String? status,
    String? planSlug,
    int page = 1,
    int limit = 20,
    String sortBy = 'created_at',
    String sortOrder = 'desc',
  }) async {
    try {
      final offset = (page - 1) * limit;
      final conditions = <String>[];
      final values = <String, dynamic>{};

      if (search != null && search.isNotEmpty) {
        conditions.add("(o.name ILIKE @search OR o.slug ILIKE @search OR o.contact_email ILIKE @search)");
        values['search'] = '%$search%';
      }
      if (status != null && status.isNotEmpty) {
        conditions.add("o.status = @status");
        values['status'] = status;
      }
      if (planSlug != null && planSlug.isNotEmpty) {
        conditions.add("sp.slug = @planSlug");
        values['planSlug'] = planSlug;
      }

      final whereClause = conditions.isEmpty ? '' : 'WHERE ${conditions.join(' AND ')}';
      final allowedSort = {'created_at', 'name', 'status', 'updated_at'};
      final safeSort = allowedSort.contains(sortBy) ? sortBy : 'created_at';
      final safeOrder = sortOrder.toLowerCase() == 'asc' ? 'ASC' : 'DESC';

      values['limit'] = limit;
      values['offset'] = offset;

      final rows = await DatabaseConnection.query('''
          SELECT
            o.id::text, o.slug, o.name, o.display_name, o.logo_url, o.industry,
            o.size_range, o.country, o.timezone, o.contact_email, o.contact_phone,
            o.status, o.is_active, o.suspension_reason,
            o.max_employees, o.max_admins, o.max_projects,
            o.max_storage_gb::text, o.created_at, o.updated_at, o.created_by, o.notes,
            o.trial_ends_at, o.subscription_starts_at, o.subscription_ends_at,
            o.plan_id::text, sp.name AS plan_name, sp.slug AS plan_slug,
            sp.features::text AS plan_features,
            COALESCE((SELECT COUNT(*) FROM employees e WHERE e.organization_id = o.id AND e.status = 1), 0) AS employee_count,
            COALESCE((SELECT COUNT(*) FROM admins a   WHERE a.organization_id = o.id AND a.status = 1), 0) AS admin_count,
            COALESCE((SELECT COUNT(*) FROM projects p  WHERE p.organization_id = o.id), 0)                 AS project_count
          FROM organizations o
          LEFT JOIN subscription_plans sp ON o.plan_id = sp.id
          $whereClause
          ORDER BY o.$safeSort $safeOrder
          LIMIT @limit OFFSET @offset
        ''', values: values);

      final countResult = await DatabaseConnection.queryOne(
        'SELECT COUNT(*)::int AS total FROM organizations o LEFT JOIN subscription_plans sp ON o.plan_id = sp.id $whereClause',
        values: Map.from(values)..remove('limit')..remove('offset'),
      );
      final total = (countResult?['total'] as int?) ?? 0;

      return {
        'data': rows,
        'total': total,
        'page': page,
        'limit': limit,
        'total_pages': (total / limit).ceil(),
      };
    } catch (e, st) {
      _log.error('getAll error: $e', e, st);
      throw AppException(code: 'DB_ERROR', message: 'Failed to list organizations');
    }
  }

  /// Get single org by ID
  Future<Map<String, dynamic>?> getById(String id) async {
    try {
      return await DatabaseConnection.queryOne('''
          SELECT
            o.id::text, o.slug, o.name, o.display_name, o.logo_url, o.industry,
            o.size_range, o.country, o.timezone, o.contact_email, o.contact_phone,
            o.status, o.is_active, o.suspension_reason,
            o.max_employees, o.max_admins, o.max_projects,
            o.max_storage_gb::text,
            o.created_at, o.updated_at, o.created_by, o.notes,
            o.trial_ends_at, o.subscription_starts_at, o.subscription_ends_at,
            o.plan_id::text, sp.name AS plan_name, sp.slug AS plan_slug,
            sp.features::text AS plan_features,
            COALESCE((SELECT COUNT(*) FROM employees e WHERE e.organization_id = o.id AND e.status = 1), 0) AS employee_count,
            COALESCE((SELECT COUNT(*) FROM admins a   WHERE a.organization_id = o.id AND a.status = 1), 0) AS admin_count,
            COALESCE((SELECT COUNT(*) FROM projects p  WHERE p.organization_id = o.id), 0)                 AS project_count,
            COALESCE((SELECT COUNT(*) FROM task_cards t WHERE t.organization_id = o.id AND t.is_deleted = FALSE), 0) AS task_count
          FROM organizations o
          LEFT JOIN subscription_plans sp ON o.plan_id = sp.id
          WHERE o.id = @id
        ''', values: {'id': id});
    } catch (e, st) {
      _log.error('getById error: $e', e, st);
      return null;
    }
  }

  /// Get org by slug
  Future<Map<String, dynamic>?> getBySlug(String slug) async {
    return DatabaseConnection.queryOne(
      'SELECT id::text, slug, name, status, is_active FROM organizations WHERE slug = @slug',
      values: {'slug': slug},
    );
  }

  /// Create a new organization
  Future<Map<String, dynamic>> create(Map<String, dynamic> data) async {
    try {
      String? planIdRaw = data['plan_id']?.toString();
      String? planId = (planIdRaw != null && planIdRaw.isNotEmpty) ? planIdRaw : null;
      int maxEmp = 10, maxAdm = 2, maxProj = 5;
      double maxStorage = 1.0;

      if (planId != null) {
        final planRow = await DatabaseConnection.queryOne(
          'SELECT max_employees, max_admins, max_projects, max_storage_gb::text FROM subscription_plans WHERE id = @id',
          values: {'id': planId},
        );
        if (planRow != null) {
          maxEmp     = (planRow['max_employees'] as int?) ?? maxEmp;
          maxAdm     = (planRow['max_admins'] as int?) ?? maxAdm;
          maxProj    = (planRow['max_projects'] as int?) ?? maxProj;
          maxStorage = double.tryParse(planRow['max_storage_gb']?.toString() ?? '1') ?? maxStorage;
        }
      }

      final slug = _generateSlug(data['name']?.toString() ?? 'org');

      final result = await DatabaseConnection.queryOne('''
          INSERT INTO organizations (
            slug, name, display_name, logo_url, industry, size_range, country,
            timezone, contact_email, contact_phone, status, is_active, plan_id,
            trial_ends_at, max_employees, max_admins, max_projects, max_storage_gb,
            created_by, notes
          ) VALUES (
            @slug, @name, @displayName, @logoUrl, @industry, @sizeRange, @country,
            @timezone, @contactEmail, @contactPhone, @status, TRUE, @planId::uuid,
            @trialEndsAt, @maxEmp, @maxAdm, @maxProj, @maxStorage,
            @createdBy, @notes
          )
          RETURNING id::text
        ''', values: {
        'slug':        slug,
        'name':        data['name']?.toString() ?? '',
        'displayName': data['display_name']?.toString(),
        'logoUrl':     data['logo_url']?.toString(),
        'industry':    data['industry']?.toString(),
        'sizeRange':   data['size_range']?.toString(),
        'country':     data['country']?.toString(),
        'timezone':    data['timezone']?.toString() ?? 'Asia/Kolkata',
        'contactEmail': data['contact_email']?.toString(),
        'contactPhone': data['contact_phone']?.toString(),
        'status':      data['status']?.toString() ?? 'active',
        'planId':      planId,
        'trialEndsAt': (data['trial_ends_at']?.toString().isNotEmpty ?? false) ? data['trial_ends_at'].toString() : null,
        'maxEmp':      maxEmp,
        'maxAdm':      maxAdm,
        'maxProj':     maxProj,
        'maxStorage':  maxStorage,
        'createdBy':   data['created_by']?.toString() ?? 'super_admin',
        'notes':       data['notes']?.toString(),
      });

      final id = result?['id']?.toString();
      if (id == null) throw AppException(code: 'INSERT_FAILED', message: 'Failed to create organization');
      return (await getById(id))!;
    } catch (e, st) {
      _log.error('❌ Failed to create organization. Data: $data', e, st);
      if (e is AppException) rethrow;
      throw AppException(
        code: 'DB_ERROR', 
        message: 'Failed to create organization: $e'
      );
    }
  }

  /// Update organization fields
  Future<Map<String, dynamic>?> update(String id, Map<String, dynamic> data) async {
    try {
      final setClauses = <String>[];
      final values = <String, dynamic>{'id': id};

      final fields = {
        'name': 'name', 'display_name': 'displayName', 'logo_url': 'logoUrl',
        'industry': 'industry', 'size_range': 'sizeRange', 'country': 'country',
        'timezone': 'timezone', 'contact_email': 'contactEmail',
        'contact_phone': 'contactPhone', 'notes': 'notes',
      };

      for (final entry in fields.entries) {
        if (data.containsKey(entry.key)) {
          setClauses.add('${entry.key} = @${entry.value}');
          values[entry.value] = data[entry.key];
        }
      }

      if (data.containsKey('plan_id')) {
        setClauses.add('plan_id = @planId::uuid');
        values['planId'] = data['plan_id']?.toString();
        final planRow = await DatabaseConnection.queryOne(
          'SELECT max_employees, max_admins, max_projects, max_storage_gb::text FROM subscription_plans WHERE id = @id',
          values: {'id': data['plan_id']},
        );
        if (planRow != null) {
          setClauses.addAll(['max_employees = @maxEmp', 'max_admins = @maxAdm', 'max_projects = @maxProj', 'max_storage_gb = @maxStorage']);
          values['maxEmp']     = planRow['max_employees'];
          values['maxAdm']     = planRow['max_admins'];
          values['maxProj']    = planRow['max_projects'];
          values['maxStorage'] = double.tryParse(planRow['max_storage_gb']?.toString() ?? '1') ?? 1.0;
        }
      }

      if (setClauses.isEmpty) return await getById(id);

      await DatabaseConnection.execute(
        'UPDATE organizations SET ${setClauses.join(', ')} WHERE id = @id::uuid',
        values: values,
      );
      return await getById(id);
    } catch (e, st) {
      _log.error('update error: $e', e, st);
      return null;
    }
  }

  /// Change org status
  Future<bool> updateStatus(String id, String status, {String? reason}) async {
    try {
      await DatabaseConnection.execute(
        'UPDATE organizations SET status = @status, is_active = @isActive, suspension_reason = @reason WHERE id = @id::uuid',
        values: {
          'id':       id,
          'status':   status,
          'isActive': status == 'active',
          'reason':   reason,
        },
      );
      return true;
    } catch (e, st) {
      _log.error('updateStatus error: $e', e, st);
      return false;
    }
  }

  /// Soft delete (cancel)
  Future<bool> delete(String id) async {
    try {
      await DatabaseConnection.execute(
        "UPDATE organizations SET status = 'cancelled', is_active = FALSE WHERE id = @id::uuid",
        values: {'id': id},
      );
      return true;
    } catch (e, st) {
      _log.error('delete error: $e', e, st);
      return false;
    }
  }

  /// Platform-wide stats for analytics dashboard
  Future<Map<String, dynamic>> getPlatformStats() async {
    final result = await DatabaseConnection.queryOne('''
        SELECT
          COUNT(*)::int                                                                    AS total_orgs,
          COUNT(*) FILTER (WHERE status = 'active')::int                                  AS active_orgs,
          COUNT(*) FILTER (WHERE status = 'trial')::int                                   AS trial_orgs,
          COUNT(*) FILTER (WHERE status = 'suspended')::int                               AS suspended_orgs,
          COUNT(*) FILTER (WHERE status = 'cancelled')::int                               AS cancelled_orgs,
          COUNT(*) FILTER (WHERE DATE_TRUNC('month', created_at) = DATE_TRUNC('month', NOW()))::int AS new_this_month,
          (SELECT COUNT(*)::int FROM employees WHERE status = 1)                          AS total_employees,
          (SELECT COUNT(*)::int FROM admins    WHERE status = 1)                          AS total_admins,
          (SELECT COUNT(*)::int FROM projects)                                            AS total_projects,
          (SELECT COUNT(*)::int FROM task_cards WHERE is_deleted = FALSE)                 AS total_tasks
        FROM organizations
      ''');
    return result ?? {};
  }

  /// List employees in an org
  Future<List<Map<String, dynamic>>> getOrgEmployees(
    String orgId, {
    String? search,
    int limit = 50,
    int offset = 0,
  }) async {
    return DatabaseConnection.query('''
        SELECT employee_id, employee_name, employee_role, employee_personal_email,
               employee_designation, status, created_at
        FROM employees
        WHERE organization_id = @orgId::uuid
          AND (@search::text IS NULL OR employee_name ILIKE @searchLike OR employee_personal_email ILIKE @searchLike)
        ORDER BY employee_name
        LIMIT @limit OFFSET @offset
      ''', values: {
      'orgId':      orgId,
      'search':     search,
      'searchLike': search != null ? '%$search%' : null,
      'limit':      limit,
      'offset':     offset,
    });
  }

  /// List admins in an org
  Future<List<Map<String, dynamic>>> getOrgAdmins(String orgId) async {
    return DatabaseConnection.query('''
        SELECT admin_id, admin_name, admin_role, admin_personal_email,
               admin_designation, status, role_type, created_at
        FROM admins
        WHERE organization_id = @orgId::uuid
        ORDER BY admin_name
      ''', values: {'orgId': orgId});
  }

  // ──────────────────────────────────────────────────────────────────────────
  // SUBSCRIPTION PLANS
  // ──────────────────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getAllPlans() async {
    return DatabaseConnection.query(
      'SELECT id::text, name, slug, description, max_employees, max_admins, max_projects, max_storage_gb::text, features::text, is_active, is_public, sort_order, created_at FROM subscription_plans ORDER BY sort_order',
    );
  }

  Future<Map<String, dynamic>?> getPlanById(String id) async {
    return DatabaseConnection.queryOne(
      'SELECT id::text, name, slug, description, max_employees, max_admins, max_projects, max_storage_gb::text, features::text, is_active, is_public, sort_order FROM subscription_plans WHERE id = @id::uuid',
      values: {'id': id},
    );
  }

  Future<Map<String, dynamic>> createPlan(Map<String, dynamic> data) async {
    final result = await DatabaseConnection.queryOne('''
        INSERT INTO subscription_plans (name, slug, description, max_employees, max_admins, max_projects, max_storage_gb, features, is_active, is_public, sort_order)
        VALUES (@name, @slug, @desc, @maxEmp, @maxAdm, @maxProj, @maxStorage, @features::jsonb, @isActive, @isPublic, @sortOrder)
        RETURNING id::text
      ''', values: {
      'name':      data['name'],
      'slug':      data['slug'],
      'desc':      data['description'],
      'maxEmp':    data['max_employees'] ?? 10,
      'maxAdm':    data['max_admins'] ?? 2,
      'maxProj':   data['max_projects'] ?? 5,
      'maxStorage': data['max_storage_gb'] ?? 1.0,
      'features':  jsonEncode(data['features'] ?? {}),
      'isActive':  data['is_active'] ?? true,
      'isPublic':  data['is_public'] ?? true,
      'sortOrder': data['sort_order'] ?? 0,
    });
    return (await getPlanById(result?['id']?.toString() ?? ''))!;
  }

  Future<bool> updatePlan(String id, Map<String, dynamic> data) async {
    try {
      final setClauses = <String>[];
      final values = <String, dynamic>{'id': id};
      final fields = {
        'name': 'name', 'description': 'desc', 'max_employees': 'maxEmp',
        'max_admins': 'maxAdm', 'max_projects': 'maxProj', 'max_storage_gb': 'maxStorage',
        'is_active': 'isActive', 'is_public': 'isPublic', 'sort_order': 'sortOrder',
      };
      for (final e in fields.entries) {
        if (data.containsKey(e.key)) {
          setClauses.add('${e.key} = @${e.value}');
          values[e.value] = data[e.key];
        }
      }
      if (data.containsKey('features')) {
        setClauses.add('features = @features::jsonb');
        values['features'] = jsonEncode(data['features']);
      }
      if (setClauses.isEmpty) return true;
      await DatabaseConnection.execute(
        'UPDATE subscription_plans SET ${setClauses.join(', ')} WHERE id = @id::uuid',
        values: values,
      );
      return true;
    } catch (e, st) {
      _log.error('updatePlan error: $e', e, st);
      return false;
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // SUPER ADMINS
  // ──────────────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>?> getSuperAdminByEmail(String email) async {
    return DatabaseConnection.queryOne(
      'SELECT id::text, name, email, password_hash, role, is_active FROM super_admins WHERE email = @email',
      values: {'email': email},
    );
  }

  Future<void> updateSuperAdminLastLogin(String id) async {
    await DatabaseConnection.execute(
      'UPDATE super_admins SET last_login_at = NOW() WHERE id = @id::uuid',
      values: {'id': id},
    );
  }

  Future<List<Map<String, dynamic>>> getAllSuperAdmins() async {
    return DatabaseConnection.query(
      'SELECT id::text, name, email, role, is_active, last_login_at, created_at FROM super_admins ORDER BY created_at',
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // AUDIT LOG
  // ──────────────────────────────────────────────────────────────────────────

  Future<void> writeAuditLog({
    required String superAdminId,
    required String superAdminEmail,
    required String action,
    String? targetType,
    String? targetId,
    String? targetName,
    Map<String, dynamic>? details,
    String? ipAddress,
  }) async {
    try {
      await DatabaseConnection.execute('''
          INSERT INTO super_admin_audit_logs
            (super_admin_id, super_admin_email, action, target_type, target_id, target_name, details, ip_address)
          VALUES
            (@saId::uuid, @saEmail, @action, @targetType, @targetId, @targetName, @details::jsonb, @ip)
        ''', values: {
        'saId':       superAdminId,
        'saEmail':    superAdminEmail,
        'action':     action,
        'targetType': targetType,
        'targetId':   targetId,
        'targetName': targetName,
        'details':    details != null ? jsonEncode(details) : null,
        'ip':         ipAddress,
      });
    } catch (e) {
      _log.warning('Failed to write audit log: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getAuditLogs({int limit = 50, int offset = 0}) async {
    return DatabaseConnection.query('''
        SELECT id::text, super_admin_email, action, target_type, target_id, target_name, details::text, ip_address, created_at
        FROM super_admin_audit_logs
        ORDER BY created_at DESC
        LIMIT @limit OFFSET @offset
      ''', values: {'limit': limit, 'offset': offset});
  }

  // ──────────────────────────────────────────────────────────────────────────
  // HELPERS
  // ──────────────────────────────────────────────────────────────────────────

  String _generateSlug(String name) {
    return name
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s-]'), '')
        .trim()
        .replaceAll(RegExp(r'\s+'), '-')
        .replaceAll(RegExp(r'-+'), '-');
  }
}
