import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import '../services/settings_service.dart';
import '../domain/models/role.dart';
import '../domain/models/version_release.dart';
import '../domain/models/future_plan.dart';
import '../domain/models/monthly_working_days.dart';
import '../core/response/api_response.dart';
import '../core/utils/logger.dart';

class SettingsRoutes {
  final SettingsService _service = SettingsService();
  final AppLogger _logger = AppLogger('SettingsRoutes');

  Router get router {
    final router = Router();

    // Roles & Designations
    router.get('/roles', _getAllRoles);
    router.get('/roles/<id>', _getRoleById);
    router.post('/roles', _createRole);
    router.put('/roles/<id>', _updateRole);
    router.delete('/roles/<id>', _deleteRole);

    // Version Releases
    router.get('/releases', _getAllReleases);
    router.get('/releases/<id>', _getReleaseById);
    router.post('/releases', _createRelease);
    router.put('/releases/<id>', _updateRelease);
    router.delete('/releases/<id>', _deleteRelease);

    // Future Plans
    router.get('/future-plans', _getAllPlans);
    router.get('/future-plans/<id>', _getPlanById);
    router.post('/future-plans', _createPlan);
    router.put('/future-plans/<id>', _updatePlan);
    router.delete('/future-plans/<id>', _deletePlan);

    // Monthly Working Days
    router.get('/working-days', _getAllWorkingDays);
    router.get('/working-days/<id>', _getWorkingDaysById);
    router.post('/working-days', _createWorkingDays);
    router.put('/working-days/<id>', _updateWorkingDays);
    router.delete('/working-days/<id>', _deleteWorkingDays);

    // System Task Logs
    router.get('/system-logs', _getSystemTaskLogs);

    return router;
  }

  // --- Roles Handlers ---

  Future<Response> _getAllRoles(Request request) async {
    try {
      final roles = await _service.getAllRoles();
      return ApiResponse.success(
        data: roles.map((e) => e.toJson()).toList(),
      ).toShelfResponse();
    } catch (e) {
      _logger.error('Error fetching roles', e);
      return ApiResponse.error(
        code: 'FETCH_ERROR',
        message: e.toString(),
      ).toShelfResponse(statusCode: 500);
    }
  }

  Future<Response> _getRoleById(Request request, String id) async {
    try {
      final role = await _service.getRoleById(id);
      return ApiResponse.success(data: role.toJson()).toShelfResponse();
    } catch (e) {
      _logger.error('Error fetching role $id', e);
      return ApiResponse.error(
        code: 'FETCH_ERROR',
        message: e.toString(),
      ).toShelfResponse(statusCode: 500);
    }
  }

  Future<Response> _createRole(Request request) async {
    try {
      final payload = await request.readAsString();
      final data = jsonDecode(payload);
      final role = Role.fromJson(data);
      final created = await _service.createRole(role);
      return ApiResponse.success(
        data: created.toJson(),
      ).toShelfResponse(statusCode: 201);
    } catch (e) {
      _logger.error('Error creating role', e);
      return ApiResponse.error(
        code: 'CREATE_ERROR',
        message: e.toString(),
      ).toShelfResponse(statusCode: 500);
    }
  }

  Future<Response> _updateRole(Request request, String id) async {
    try {
      final payload = await request.readAsString();
      final updates = jsonDecode(payload) as Map<String, dynamic>;
      final updated = await _service.updateRole(id, updates);
      return ApiResponse.success(data: updated.toJson()).toShelfResponse();
    } catch (e) {
      _logger.error('Error updating role $id', e);
      return ApiResponse.error(
        code: 'UPDATE_ERROR',
        message: e.toString(),
      ).toShelfResponse(statusCode: 500);
    }
  }

  Future<Response> _deleteRole(Request request, String id) async {
    try {
      await _service.deleteRole(id);
      return ApiResponse.success(
        message: 'Role deleted successfully',
      ).toShelfResponse();
    } catch (e) {
      _logger.error('Error deleting role $id', e);
      return ApiResponse.error(
        code: 'DELETE_ERROR',
        message: e.toString(),
      ).toShelfResponse(statusCode: 500);
    }
  }

  // --- Releases Handlers ---

  Future<Response> _getAllReleases(Request request) async {
    try {
      final releases = await _service.getAllReleases();
      return ApiResponse.success(
        data: releases.map((e) => e.toJson()).toList(),
      ).toShelfResponse();
    } catch (e) {
      _logger.error('Error fetching releases', e);
      return ApiResponse.error(
        code: 'FETCH_ERROR',
        message: e.toString(),
      ).toShelfResponse(statusCode: 500);
    }
  }

  Future<Response> _getReleaseById(Request request, String id) async {
    try {
      final release = await _service.getReleaseById(id);
      return ApiResponse.success(data: release.toJson()).toShelfResponse();
    } catch (e) {
      _logger.error('Error fetching release $id', e);
      return ApiResponse.error(
        code: 'FETCH_ERROR',
        message: e.toString(),
      ).toShelfResponse(statusCode: 500);
    }
  }

  Future<Response> _createRelease(Request request) async {
    try {
      final payload = await request.readAsString();
      final data = jsonDecode(payload);
      final release = VersionRelease.fromJson(data);
      final created = await _service.createRelease(release);
      return ApiResponse.success(
        data: created.toJson(),
      ).toShelfResponse(statusCode: 201);
    } catch (e) {
      _logger.error('Error creating release', e);
      return ApiResponse.error(
        code: 'CREATE_ERROR',
        message: e.toString(),
      ).toShelfResponse(statusCode: 500);
    }
  }

  Future<Response> _updateRelease(Request request, String id) async {
    try {
      final payload = await request.readAsString();
      final updates = jsonDecode(payload) as Map<String, dynamic>;
      final updated = await _service.updateRelease(id, updates);
      return ApiResponse.success(data: updated.toJson()).toShelfResponse();
    } catch (e) {
      _logger.error('Error updating release $id', e);
      return ApiResponse.error(
        code: 'UPDATE_ERROR',
        message: e.toString(),
      ).toShelfResponse(statusCode: 500);
    }
  }

  Future<Response> _deleteRelease(Request request, String id) async {
    try {
      await _service.deleteRelease(id);
      return ApiResponse.success(
        message: 'Release deleted successfully',
      ).toShelfResponse();
    } catch (e) {
      _logger.error('Error deleting release $id', e);
      return ApiResponse.error(
        code: 'DELETE_ERROR',
        message: e.toString(),
      ).toShelfResponse(statusCode: 500);
    }
  }

  // --- Future Plans Handlers ---

  Future<Response> _getAllPlans(Request request) async {
    try {
      final plans = await _service.getAllPlans();
      return ApiResponse.success(
        data: plans.map((e) => e.toJson()).toList(),
      ).toShelfResponse();
    } catch (e) {
      _logger.error('Error fetching future plans', e);
      return ApiResponse.error(
        code: 'FETCH_ERROR',
        message: e.toString(),
      ).toShelfResponse(statusCode: 500);
    }
  }

  Future<Response> _getPlanById(Request request, String id) async {
    try {
      final plan = await _service.getPlanById(id);
      return ApiResponse.success(data: plan.toJson()).toShelfResponse();
    } catch (e) {
      _logger.error('Error fetching future plan $id', e);
      return ApiResponse.error(
        code: 'FETCH_ERROR',
        message: e.toString(),
      ).toShelfResponse(statusCode: 500);
    }
  }

  Future<Response> _createPlan(Request request) async {
    try {
      final payload = await request.readAsString();
      final data = jsonDecode(payload);
      final plan = FuturePlan.fromJson(data);
      final created = await _service.createPlan(plan);
      return ApiResponse.success(
        data: created.toJson(),
      ).toShelfResponse(statusCode: 201);
    } catch (e) {
      _logger.error('Error creating future plan', e);
      return ApiResponse.error(
        code: 'CREATE_ERROR',
        message: e.toString(),
      ).toShelfResponse(statusCode: 500);
    }
  }

  Future<Response> _updatePlan(Request request, String id) async {
    try {
      final payload = await request.readAsString();
      final updates = jsonDecode(payload) as Map<String, dynamic>;
      final updated = await _service.updatePlan(id, updates);
      return ApiResponse.success(data: updated.toJson()).toShelfResponse();
    } catch (e) {
      _logger.error('Error updating future plan $id', e);
      return ApiResponse.error(
        code: 'UPDATE_ERROR',
        message: e.toString(),
      ).toShelfResponse(statusCode: 500);
    }
  }

  Future<Response> _deletePlan(Request request, String id) async {
    try {
      await _service.deletePlan(id);
      return ApiResponse.success(
        message: 'Future plan deleted successfully',
      ).toShelfResponse();
    } catch (e) {
      _logger.error('Error deleting future plan $id', e);
      return ApiResponse.error(
        code: 'DELETE_ERROR',
        message: e.toString(),
      ).toShelfResponse(statusCode: 500);
    }
  }

  // --- Monthly Working Days Handlers ---

  Future<Response> _getAllWorkingDays(Request request) async {
    try {
      final days = await _service.getAllWorkingDays();
      final data = days.map((e) => e.toJson()).toList();
      print('DEBUG: SENDING WORKING DAYS DATA: $data');
      return ApiResponse.success(
        data: data,
      ).toShelfResponse();
    } catch (e) {
      _logger.error('Error fetching working days', e);
      return ApiResponse.error(
        code: 'FETCH_ERROR',
        message: e.toString(),
      ).toShelfResponse(statusCode: 500);
    }
  }

  Future<Response> _getWorkingDaysById(Request request, String id) async {
    try {
      final days = await _service.getWorkingDaysById(id);
      return ApiResponse.success(data: days.toJson()).toShelfResponse();
    } catch (e) {
      _logger.error('Error fetching working days $id', e);
      return ApiResponse.error(
        code: 'FETCH_ERROR',
        message: e.toString(),
      ).toShelfResponse(statusCode: 500);
    }
  }

  Future<Response> _createWorkingDays(Request request) async {
    try {
      final payload = await request.readAsString();
      final data = jsonDecode(payload);
      final workingDays = MonthlyWorkingDays.fromJson(data);
      final created = await _service.createWorkingDays(workingDays);
      return ApiResponse.success(
        data: created.toJson(),
      ).toShelfResponse(statusCode: 201);
    } catch (e) {
      _logger.error('Error creating working days', e);
      return ApiResponse.error(
        code: 'CREATE_ERROR',
        message: e.toString(),
      ).toShelfResponse(statusCode: 500);
    }
  }

  Future<Response> _updateWorkingDays(Request request, String id) async {
    try {
      final payload = await request.readAsString();
      final updates = jsonDecode(payload) as Map<String, dynamic>;
      final updated = await _service.updateWorkingDays(id, updates);
      return ApiResponse.success(data: updated.toJson()).toShelfResponse();
    } catch (e) {
      _logger.error('Error updating working days $id', e);
      return ApiResponse.error(
        code: 'UPDATE_ERROR',
        message: e.toString(),
      ).toShelfResponse(statusCode: 500);
    }
  }

  Future<Response> _deleteWorkingDays(Request request, String id) async {
    try {
      await _service.deleteWorkingDays(id);
      return ApiResponse.success(
        message: 'Working days deleted successfully',
      ).toShelfResponse();
    } catch (e) {
      _logger.error('Error deleting working days $id', e);
      return ApiResponse.error(
        code: 'DELETE_ERROR',
        message: e.toString(),
      ).toShelfResponse(statusCode: 500);
    }
  }

  // --- System Task Logs Handlers ---

  Future<Response> _getSystemTaskLogs(Request request) async {
    try {
      final logs = await _service.getSystemTaskLogs();
      return ApiResponse.success(data: logs).toShelfResponse();
    } catch (e) {
      _logger.error('Error fetching system logs', e);
      return ApiResponse.error(
        code: 'FETCH_ERROR',
        message: e.toString(),
      ).toShelfResponse(statusCode: 500);
    }
  }
}
