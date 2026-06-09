import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import '../data/repositories/organization_repository.dart';
import '../data/repositories/admin_repository.dart';
import '../data/repositories/user_repository.dart';
import '../core/response/api_response.dart';
import '../core/utils/logger.dart';
import '../config/app_config.dart';
import '../data/database/connection.dart';

/// All Super Admin endpoints — mounted under /super/ in the main router.
/// These routes use a SEPARATE JWT secret from the regular admin/employee routes.
class SuperAdminRoutes {
  final OrganizationRepository _repo = OrganizationRepository();
  final AdminRepository _adminRepo = AdminRepository();
  final UserRepository _userRepo = UserRepository();
  final AppLogger _log = AppLogger('SuperAdminRoutes');

  // ──────────────────────────────────────────────────────────────────────────
  // ROUTER SETUP
  // ──────────────────────────────────────────────────────────────────────────
  Router get router {
    final r = Router();

    // ── AUTH ──────────────────────────────────────────────────────────────
    r.post('/auth/login',   _login);
    r.post('/auth/logout',  _logout);
    r.get('/auth/me',       _me);

    // ── ORGANIZATIONS ─────────────────────────────────────────────────────
    r.get('/organizations',             _listOrgs);
    r.post('/organizations',            _createOrg);
    r.get('/organizations/<id>',        _getOrg);
    r.put('/organizations/<id>',        _updateOrg);
    r.put('/organizations/<id>/status', _updateOrgStatus);
    r.delete('/organizations/<id>',     _deleteOrg);

    // ── ORG DRILL-DOWN ────────────────────────────────────────────────────
    r.get('/organizations/<id>/employees', _getOrgEmployees);
    r.get('/organizations/<id>/admins',    _getOrgAdmins);
    r.post('/organizations/<id>/admins',   _createOrgAdmin);

    // ── SUBSCRIPTION PLANS ────────────────────────────────────────────────
    r.get('/plans',           _listPlans);
    r.post('/plans',          _createPlan);
    r.get('/plans/<id>',      _getPlan);
    r.put('/plans/<id>',      _updatePlan);
    r.delete('/plans/<id>',   _deletePlan);

    // ── ANALYTICS ─────────────────────────────────────────────────────────
    r.get('/analytics/overview', _analyticsOverview);
    r.get('/analytics/storage',  _storageAnalytics);

    // ── SUPER ADMINS ──────────────────────────────────────────────────────
    r.get('/admins',  _listSuperAdmins);

    // ── AUDIT LOG ─────────────────────────────────────────────────────────
    r.get('/audit-logs', _auditLogs);

    return r;
  }

  // ──────────────────────────────────────────────────────────────────────────
  // JWT HELPERS
  // ──────────────────────────────────────────────────────────────────────────

  Map<String, dynamic>? _verifySuperAdminToken(String token) {
    try {
      final jwt = JWT.verify(token, SecretKey(AppConfig.superAdminJwtSecret));
      final payload = jwt.payload as Map<String, dynamic>;
      final role = payload['role']?.toString();
      if (role != 'super_admin' && role != 'support') return null;
      return payload;
    } catch (_) {
      return null;
    }
  }

  String _generateSuperAdminToken(Map<String, dynamic> admin) {
    final now = DateTime.now();
    final exp = now.add(Duration(hours: AppConfig.superAdminJwtExpirationHours));
    final jwt = JWT({
      'id':    admin['id'],
      'email': admin['email'],
      'name':  admin['name'],
      'role':  admin['role'],
      'iat':   now.millisecondsSinceEpoch ~/ 1000,
      'exp':   exp.millisecondsSinceEpoch ~/ 1000,
    });
    return jwt.sign(SecretKey(AppConfig.superAdminJwtSecret));
  }

  String _clientIp(Request req) =>
      req.headers['x-forwarded-for'] ?? req.headers['x-real-ip'] ?? 'unknown';

  Map<String, dynamic>? _requireAuth(Request req) {
    final authHeader = req.headers['authorization'];
    if (authHeader == null || !authHeader.startsWith('Bearer ')) return null;
    return _verifySuperAdminToken(authHeader.substring(7));
  }

  Response _unauthorized() =>
      ApiResponse.error(code: 'UNAUTHORIZED', message: 'Valid super admin token required')
          .toShelfResponse(statusCode: 401);

  // ──────────────────────────────────────────────────────────────────────────
  // PASSWORD VERIFICATION
  // SHA-256 matching the pattern used in UserRepository
  // ──────────────────────────────────────────────────────────────────────────

  bool _checkPassword(String plainText, String storedHash) {
    // Support both SHA-256 (existing user system) and bcrypt-style ($2a$) hashes
    // For super_admins we use bcrypt hash (stored in DB), but since we don't have
    // the bcrypt package, we store SHA-256 hashes instead.
    // The seeded password hash in migration is SHA-256 of 'SuperAdmin@2024'
    final bytes   = utf8.encode(plainText);
    final sha256Hash = sha256.convert(bytes).toString();
    return sha256Hash == storedHash || plainText == storedHash; // fallback for plain dev
  }

  // ──────────────────────────────────────────────────────────────────────────
  // AUTH HANDLERS
  // ──────────────────────────────────────────────────────────────────────────

  Future<Response> _login(Request req) async {
    try {
      final body = jsonDecode(await req.readAsString()) as Map<String, dynamic>;
      final email    = body['email']?.toString().trim();
      final password = body['password']?.toString();

      if (email == null || email.isEmpty) {
        return ApiResponse.error(code: 'VALIDATION_ERROR', message: 'Email is required').toShelfResponse(statusCode: 400);
      }
      if (password == null || password.isEmpty) {
        return ApiResponse.error(code: 'VALIDATION_ERROR', message: 'Password is required').toShelfResponse(statusCode: 400);
      }

      final admin = await _repo.getSuperAdminByEmail(email);
      if (admin == null || admin['is_active'] != true) {
        return ApiResponse.error(code: 'UNAUTHORIZED', message: 'Invalid email or password').toShelfResponse(statusCode: 401);
      }

      final storedHash = admin['password_hash']?.toString() ?? '';
      if (!_checkPassword(password, storedHash)) {
        _log.warning('Super admin login failed — wrong password for $email');
        return ApiResponse.error(code: 'UNAUTHORIZED', message: 'Invalid email or password').toShelfResponse(statusCode: 401);
      }

      final token = _generateSuperAdminToken(admin);
      await _repo.updateSuperAdminLastLogin(admin['id']?.toString() ?? '');

      await _repo.writeAuditLog(
        superAdminId:    admin['id']?.toString() ?? '',
        superAdminEmail: email,
        action:          'LOGIN',
        ipAddress:       _clientIp(req),
      );

      return ApiResponse.success(
        message: 'Login successful',
        data: {
          'token':      token,
          'expires_in': AppConfig.superAdminJwtExpirationHours * 3600,
          'admin': {
            'id':    admin['id'],
            'name':  admin['name'],
            'email': admin['email'],
            'role':  admin['role'],
          },
        },
      ).toShelfResponse();
    } catch (e, st) {
      _log.error('Super admin login error: $e', e, st);
      return ApiResponse.error(code: 'INTERNAL_ERROR', message: 'Internal server error').toShelfResponse(statusCode: 500);
    }
  }

  Future<Response> _logout(Request req) async {
    try {
      final authHeader = req.headers['authorization'];
      if (authHeader != null && authHeader.startsWith('Bearer ')) {
        final payload = _verifySuperAdminToken(authHeader.substring(7));
        if (payload != null) {
          await _repo.writeAuditLog(
            superAdminId:    payload['id']?.toString() ?? '',
            superAdminEmail: payload['email']?.toString() ?? '',
            action:          'LOGOUT',
            ipAddress:       _clientIp(req),
          );
        }
      }
    } catch (_) {}
    return ApiResponse.success(message: 'Logged out successfully').toShelfResponse();
  }

  Future<Response> _me(Request req) async {
    final payload = _requireAuth(req);
    if (payload == null) return _unauthorized();
    return ApiResponse.success(data: {
      'id':    payload['id'],
      'email': payload['email'],
      'name':  payload['name'],
      'role':  payload['role'],
    }).toShelfResponse();
  }

  // ──────────────────────────────────────────────────────────────────────────
  // ORGANIZATION HANDLERS
  // ──────────────────────────────────────────────────────────────────────────

  Future<Response> _listOrgs(Request req) async {
    if (_requireAuth(req) == null) return _unauthorized();
    try {
      final q = req.url.queryParameters;
      final result = await _repo.getAll(
        search:    q['search'],
        status:    q['status'],
        planSlug:  q['plan'],
        page:      int.tryParse(q['page'] ?? '1') ?? 1,
        limit:     int.tryParse(q['limit'] ?? '20') ?? 20,
        sortBy:    q['sort_by'] ?? 'created_at',
        sortOrder: q['sort_order'] ?? 'desc',
      );
      return ApiResponse.success(data: result, message: 'Organizations fetched').toShelfResponse();
    } catch (e, st) {
      _log.error('listOrgs error: $e', e, st);
      return ApiResponse.error(code: 'INTERNAL_ERROR', message: 'Failed to fetch organizations').toShelfResponse(statusCode: 500);
    }
  }

  Future<Response> _createOrg(Request req) async {
    final payload = _requireAuth(req);
    if (payload == null) return _unauthorized();
    try {
      final data    = jsonDecode(await req.readAsString()) as Map<String, dynamic>;
      final saId    = payload['id']?.toString() ?? '';
      final saEmail = payload['email']?.toString() ?? '';

      if (data['name'] == null || data['name'].toString().trim().isEmpty) {
        return ApiResponse.error(code: 'VALIDATION_ERROR', message: 'Organization name is required').toShelfResponse(statusCode: 400);
      }

      final slug = (data['name'] as String)
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9\s-]'), '')
          .trim()
          .replaceAll(RegExp(r'\s+'), '-');
      final existing = await _repo.getBySlug(slug);
      if (existing != null) {
        return ApiResponse.error(code: 'CONFLICT', message: 'An organization with this name already exists').toShelfResponse(statusCode: 409);
      }

      data['created_by'] = saEmail;
      final org = await _repo.create(data);

      await _repo.writeAuditLog(
        superAdminId:    saId,
        superAdminEmail: saEmail,
        action:          'CREATE_ORG',
        targetType:      'organization',
        targetId:        org['id']?.toString(),
        targetName:      org['name']?.toString(),
        ipAddress:       _clientIp(req),
      );

      return ApiResponse.success(data: org, message: 'Organization created successfully').toShelfResponse(statusCode: 201);
    } catch (e, st) {
      _log.error('createOrg error: $e', e, st);
      return ApiResponse.error(code: 'INTERNAL_ERROR', message: 'Failed to create organization').toShelfResponse(statusCode: 500);
    }
  }

  Future<Response> _getOrg(Request req, String id) async {
    if (_requireAuth(req) == null) return _unauthorized();
    try {
      final org = await _repo.getById(id);
      if (org == null) {
        return ApiResponse.error(code: 'NOT_FOUND', message: 'Organization not found').toShelfResponse(statusCode: 404);
      }
      return ApiResponse.success(data: org).toShelfResponse();
    } catch (e, st) {
      _log.error('getOrg error: $e', e, st);
      return ApiResponse.error(code: 'INTERNAL_ERROR', message: 'Failed to fetch organization').toShelfResponse(statusCode: 500);
    }
  }

  Future<Response> _updateOrg(Request req, String id) async {
    final payload = _requireAuth(req);
    if (payload == null) return _unauthorized();
    try {
      final data    = jsonDecode(await req.readAsString()) as Map<String, dynamic>;
      final saId    = payload['id']?.toString() ?? '';
      final saEmail = payload['email']?.toString() ?? '';

      final existing = await _repo.getById(id);
      if (existing == null) {
        return ApiResponse.error(code: 'NOT_FOUND', message: 'Organization not found').toShelfResponse(statusCode: 404);
      }

      final updated = await _repo.update(id, data);
      await _repo.writeAuditLog(
        superAdminId:    saId,
        superAdminEmail: saEmail,
        action:          'UPDATE_ORG',
        targetType:      'organization',
        targetId:        id,
        targetName:      existing['name']?.toString(),
        details:         data,
        ipAddress:       _clientIp(req),
      );

      return ApiResponse.success(data: updated, message: 'Organization updated').toShelfResponse();
    } catch (e, st) {
      _log.error('updateOrg error: $e', e, st);
      return ApiResponse.error(code: 'INTERNAL_ERROR', message: 'Failed to update organization').toShelfResponse(statusCode: 500);
    }
  }

  Future<Response> _updateOrgStatus(Request req, String id) async {
    final payload = _requireAuth(req);
    if (payload == null) return _unauthorized();
    try {
      final data    = jsonDecode(await req.readAsString()) as Map<String, dynamic>;
      final saId    = payload['id']?.toString() ?? '';
      final saEmail = payload['email']?.toString() ?? '';
      final status  = data['status']?.toString();
      const allowed = {'active', 'trial', 'suspended', 'cancelled'};

      if (status == null || !allowed.contains(status)) {
        return ApiResponse.error(
          code: 'VALIDATION_ERROR',
          message: 'status must be one of: ${allowed.join(', ')}',
        ).toShelfResponse(statusCode: 400);
      }

      final existing = await _repo.getById(id);
      if (existing == null) {
        return ApiResponse.error(code: 'NOT_FOUND', message: 'Organization not found').toShelfResponse(statusCode: 404);
      }

      await _repo.updateStatus(id, status, reason: data['reason']?.toString());
      await _repo.writeAuditLog(
        superAdminId:    saId,
        superAdminEmail: saEmail,
        action:          'UPDATE_ORG_STATUS',
        targetType:      'organization',
        targetId:        id,
        targetName:      existing['name']?.toString(),
        details:         {'old_status': existing['status'], 'new_status': status, 'reason': data['reason']},
        ipAddress:       _clientIp(req),
      );

      return ApiResponse.success(
        data: {'id': id, 'status': status},
        message: 'Organization status updated to $status',
      ).toShelfResponse();
    } catch (e, st) {
      _log.error('updateOrgStatus error: $e', e, st);
      return ApiResponse.error(code: 'INTERNAL_ERROR', message: 'Failed to update status').toShelfResponse(statusCode: 500);
    }
  }

  Future<Response> _deleteOrg(Request req, String id) async {
    final payload = _requireAuth(req);
    if (payload == null) return _unauthorized();
    try {
      final saId    = payload['id']?.toString() ?? '';
      final saEmail = payload['email']?.toString() ?? '';

      final existing = await _repo.getById(id);
      if (existing == null) {
        return ApiResponse.error(code: 'NOT_FOUND', message: 'Organization not found').toShelfResponse(statusCode: 404);
      }

      await _repo.delete(id);
      await _repo.writeAuditLog(
        superAdminId:    saId,
        superAdminEmail: saEmail,
        action:          'DELETE_ORG',
        targetType:      'organization',
        targetId:        id,
        targetName:      existing['name']?.toString(),
        ipAddress:       _clientIp(req),
      );

      return ApiResponse.success(message: 'Organization cancelled and deactivated').toShelfResponse();
    } catch (e, st) {
      _log.error('deleteOrg error: $e', e, st);
      return ApiResponse.error(code: 'INTERNAL_ERROR', message: 'Failed to delete organization').toShelfResponse(statusCode: 500);
    }
  }

  Future<Response> _getOrgEmployees(Request req, String id) async {
    if (_requireAuth(req) == null) return _unauthorized();
    try {
      final q = req.url.queryParameters;
      final employees = await _repo.getOrgEmployees(
        id,
        search: q['search'],
        limit:  int.tryParse(q['limit'] ?? '50') ?? 50,
        offset: int.tryParse(q['offset'] ?? '0') ?? 0,
      );
      return ApiResponse.success(data: employees, message: 'Employees fetched').toShelfResponse();
    } catch (e, st) {
      _log.error('getOrgEmployees error: $e', e, st);
      return ApiResponse.error(code: 'INTERNAL_ERROR', message: 'Failed to fetch employees').toShelfResponse(statusCode: 500);
    }
  }

  Future<Response> _getOrgAdmins(Request req, String id) async {
    if (_requireAuth(req) == null) return _unauthorized();
    try {
      final admins = await _repo.getOrgAdmins(id);
      return ApiResponse.success(data: admins, message: 'Admins fetched').toShelfResponse();
    } catch (e, st) {
      _log.error('getOrgAdmins error: $st', e, st);
      return ApiResponse.error(code: 'INTERNAL_ERROR', message: 'Failed to fetch admins').toShelfResponse(statusCode: 500);
    }
  }

  Future<Response> _createOrgAdmin(Request req, String id) async {
    final payload = _requireAuth(req);
    if (payload == null) return _unauthorized();
    try {
      final data    = jsonDecode(await req.readAsString()) as Map<String, dynamic>;
      final saId    = payload['id']?.toString() ?? '';
      final saEmail = payload['email']?.toString() ?? '';

      final required = ['admin_id', 'admin_name', 'admin_personal_email', 'password'];
      for (final field in required) {
        if (data[field] == null || data[field].toString().isEmpty) {
          return ApiResponse.error(code: 'VALIDATION_ERROR', message: '$field is required').toShelfResponse(statusCode: 400);
        }
      }

      final org = await _repo.getById(id);
      if (org == null) {
        return ApiResponse.error(code: 'NOT_FOUND', message: 'Organization not found').toShelfResponse(statusCode: 404);
      }

      final adminId = data['admin_id']?.toString().trim();
      final email = data['admin_personal_email']?.toString().trim();

      // Check if admin with same admin_id exists
      final existingById = await _adminRepo.getById(adminId!);
      if (existingById != null) {
        return ApiResponse.error(
          code: 'CONFLICT',
          message: 'Admin ID "$adminId" already exists. Please use a different Admin ID.',
        ).toShelfResponse(statusCode: 409);
      }

      // Check if admin with same email exists
      final existingByEmail = await _adminRepo.getByEmail(email!);
      if (existingByEmail != null) {
        return ApiResponse.error(
          code: 'CONFLICT',
          message: 'Email "$email" is already registered with another admin.',
        ).toShelfResponse(statusCode: 409);
      }

      // 1. Create the Admin record with Super Admin role
      final adminData = Map<String, dynamic>.from(data);
      adminData['admin_role'] = 'Super Admin';
      adminData['role_type']  = 'Super Admin';
      
      final admin = await _adminRepo.create(adminData, organizationId: id);

      // 2. Create the Auth User record
      await _userRepo.ensureAuthUserExists(
        email: data['admin_personal_email'],
        employeeId: data['admin_id'],
        role: 'admin', // This is the auth-level role (admin vs employee)
        password: data['password'],
        createdBy: 'super_admin:$saId',
        organizationId: id,
      );

      // 3. Log it
      await _repo.writeAuditLog(
        superAdminId:    saId,
        superAdminEmail: saEmail,
        action:          'CREATE_ORG_ADMIN',
        targetType:      'admin',
        targetId:        admin.adminId,
        targetName:      data['admin_name']?.toString(),
        ipAddress:       _clientIp(req),
      );

      return ApiResponse.success(data: admin.toJson(), message: 'Admin created successfully').toShelfResponse(statusCode: 201);
    } catch (e, st) {
      _log.error('createOrgAdmin error: $st', e, st);
      return ApiResponse.error(code: 'INTERNAL_ERROR', message: 'Failed to create admin').toShelfResponse(statusCode: 500);
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // SUBSCRIPTION PLANS
  // ──────────────────────────────────────────────────────────────────────────

  Future<Response> _listPlans(Request req) async {
    if (_requireAuth(req) == null) return _unauthorized();
    try {
      final plans = await _repo.getAllPlans();
      return ApiResponse.success(data: plans, message: 'Plans fetched').toShelfResponse();
    } catch (e, st) {
      _log.error('listPlans error: $e', e, st);
      return ApiResponse.error(code: 'INTERNAL_ERROR', message: 'Failed to fetch plans').toShelfResponse(statusCode: 500);
    }
  }

  Future<Response> _createPlan(Request req) async {
    final payload = _requireAuth(req);
    if (payload == null) return _unauthorized();
    try {
      final data    = jsonDecode(await req.readAsString()) as Map<String, dynamic>;
      final saId    = payload['id']?.toString() ?? '';
      final saEmail = payload['email']?.toString() ?? '';

      if (data['name'] == null || data['slug'] == null) {
        return ApiResponse.error(code: 'VALIDATION_ERROR', message: 'name and slug are required').toShelfResponse(statusCode: 400);
      }

      final plan = await _repo.createPlan(data);
      await _repo.writeAuditLog(
        superAdminId: saId, superAdminEmail: saEmail,
        action: 'CREATE_PLAN', targetType: 'plan', targetName: data['name']?.toString(),
        ipAddress: _clientIp(req),
      );
      return ApiResponse.success(data: plan, message: 'Plan created').toShelfResponse(statusCode: 201);
    } catch (e, st) {
      _log.error('createPlan error: $e', e, st);
      return ApiResponse.error(code: 'INTERNAL_ERROR', message: 'Failed to create plan').toShelfResponse(statusCode: 500);
    }
  }

  Future<Response> _updatePlan(Request req, String id) async {
    final payload = _requireAuth(req);
    if (payload == null) return _unauthorized();
    try {
      final data = jsonDecode(await req.readAsString()) as Map<String, dynamic>;
      final saId = payload['id']?.toString() ?? '';
      final saEmail = payload['email']?.toString() ?? '';

      // Load existing plan to merge features
      final existing = await _repo.getPlanById(id);
      if (existing == null) {
        return ApiResponse.error(code: 'NOT_FOUND', message: 'Plan not found').toShelfResponse(statusCode: 404);
      }

      // Merge features: keep existing unless overridden
      Map<String, dynamic> mergedFeatures = {};
      if (existing['features'] != null) {
        try {
          mergedFeatures = jsonDecode(existing['features'] as String) as Map<String, dynamic>;
        } catch (_) {}
      }
      if (data.containsKey('features')) {
        final incoming = data['features'] as Map<String, dynamic>;
        mergedFeatures.addAll(incoming);
      }
      data['features'] = mergedFeatures;

      await _repo.updatePlan(id, data);
      await _repo.writeAuditLog(
        superAdminId: saId,
        superAdminEmail: saEmail,
        action: 'UPDATE_PLAN',
        targetType: 'plan',
        targetId: id,
        targetName: existing['name']?.toString(),
        details: data,
        ipAddress: _clientIp(req),
      );
      return ApiResponse.success(data: await _repo.getPlanById(id), message: 'Plan updated').toShelfResponse();
    } catch (e, st) {
      _log.error('updatePlan error: $e', e, st);
      return ApiResponse.error(code: 'INTERNAL_ERROR', message: 'Failed to update plan').toShelfResponse(statusCode: 500);
    }
  }

  Future<Response> _getPlan(Request req, String id) async {
    if (_requireAuth(req) == null) return _unauthorized();
    try {
      final plan = await _repo.getPlanById(id);
      if (plan == null) {
        return ApiResponse.error(code: 'NOT_FOUND', message: 'Plan not found').toShelfResponse(statusCode: 404);
      }
      return ApiResponse.success(data: plan).toShelfResponse();
    } catch (e, st) {
      _log.error('getPlan error: $e', e, st);
      return ApiResponse.error(code: 'INTERNAL_ERROR', message: 'Failed to fetch plan').toShelfResponse(statusCode: 500);
    }
  }

  Future<Response> _deletePlan(Request req, String id) async {
    final payload = _requireAuth(req);
    if (payload == null) return _unauthorized();
    try {
      final saId    = payload['id']?.toString() ?? '';
      final saEmail = payload['email']?.toString() ?? '';
      final existing = await _repo.getPlanById(id);
      if (existing == null) {
        return ApiResponse.error(code: 'NOT_FOUND', message: 'Plan not found').toShelfResponse(statusCode: 404);
      }
      await _repo.deletePlan(id);
      await _repo.writeAuditLog(
        superAdminId: saId, superAdminEmail: saEmail,
        action: 'DELETE_PLAN', targetType: 'plan', targetId: id, targetName: existing['name']?.toString(),
        ipAddress: _clientIp(req),
      );
      return ApiResponse.success(message: 'Plan deleted').toShelfResponse();
    } catch (e, st) {
      _log.error('deletePlan error: $e', e, st);
      return ApiResponse.error(code: 'INTERNAL_ERROR', message: 'Failed to delete plan').toShelfResponse(statusCode: 500);
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // ANALYTICS
  // ──────────────────────────────────────────────────────────────────────────

  Future<Response> _analyticsOverview(Request req) async {
    if (_requireAuth(req) == null) return _unauthorized();
    try {
      final stats = await _repo.getPlatformStats();
      return ApiResponse.success(data: stats, message: 'Platform stats fetched').toShelfResponse();
    } catch (e, st) {
      _log.error('analyticsOverview error: $e', e, st);
      return ApiResponse.error(code: 'INTERNAL_ERROR', message: 'Failed to fetch analytics').toShelfResponse(statusCode: 500);
    }
  }

  Future<Response> _storageAnalytics(Request req) async {
    if (_requireAuth(req) == null) return _unauthorized();
    try {
      // Reads from the org_storage_summary VIEW created in migration 003
      final rows = await DatabaseConnection.query(
        '''
        SELECT
          organization_id::text,
          organization_name,
          plan_slug,
          plan_max_gb::text,
          used_bytes,
          used_gb::text,
          remaining_bytes,
          usage_percent::text
        FROM org_storage_summary
        ORDER BY used_bytes DESC
        ''',
      );
      return ApiResponse.success(data: rows, message: 'Storage analytics fetched').toShelfResponse();
    } catch (e, st) {
      _log.error('storageAnalytics error: $e', e, st);
      return ApiResponse.error(code: 'INTERNAL_ERROR', message: 'Failed to fetch storage analytics').toShelfResponse(statusCode: 500);
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // SUPER ADMINS
  // ──────────────────────────────────────────────────────────────────────────

  Future<Response> _listSuperAdmins(Request req) async {
    if (_requireAuth(req) == null) return _unauthorized();
    try {
      final admins = await _repo.getAllSuperAdmins();
      return ApiResponse.success(data: admins, message: 'Super admins fetched').toShelfResponse();
    } catch (e, st) {
      _log.error('listSuperAdmins error: $e', e, st);
      return ApiResponse.error(code: 'INTERNAL_ERROR', message: 'Failed to fetch super admins').toShelfResponse(statusCode: 500);
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // AUDIT LOGS
  // ──────────────────────────────────────────────────────────────────────────

  Future<Response> _auditLogs(Request req) async {
    if (_requireAuth(req) == null) return _unauthorized();
    try {
      final q      = req.url.queryParameters;
      final limit  = int.tryParse(q['limit'] ?? '50') ?? 50;
      final offset = int.tryParse(q['offset'] ?? '0') ?? 0;
      final logs   = await _repo.getAuditLogs(limit: limit, offset: offset);
      return ApiResponse.success(data: logs, message: 'Audit logs fetched').toShelfResponse();
    } catch (e, st) {
      _log.error('auditLogs error: $e', e, st);
      return ApiResponse.error(code: 'INTERNAL_ERROR', message: 'Failed to fetch audit logs').toShelfResponse(statusCode: 500);
    }
  }
}
