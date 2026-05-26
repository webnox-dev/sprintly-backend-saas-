import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import '../services/asset_service.dart';
import '../domain/models/asset.dart';
import '../core/response/api_response.dart';
import '../core/utils/logger.dart';

class AssetRoutes {
  final AssetService _service = AssetService();
  final AppLogger _logger = AppLogger('AssetRoutes');

  Router get router {
    final router = Router();
    router.get('/admin/assets', _getAllAssets);
    router.get('/admin/assets/statistics', _getAssetStatistics);
    router.get('/admin/assets/types', _getAssetTypes);
    router.get('/admin/assets/<id>', _getAssetById);
    router.post('/admin/assets', _createAsset);
    router.put('/admin/assets/<id>', _updateAsset);
    router.delete('/admin/assets/<id>', _deleteAsset);
    return router;
  }

  Future<Response> _getAllAssets(Request request) async {
    try {
      // Parse query parameters
      final queryParams = request.url.queryParameters;
      final search = queryParams['search'];
      final assetType = queryParams['asset_type'] ?? queryParams['assetType'];
      final assetStatus =
          queryParams['asset_status'] ?? queryParams['assetStatus'];
      final usedByEmployeeId =
          queryParams['used_by_employee_id'] ?? queryParams['usedByEmployeeId'];
      final page = int.tryParse(queryParams['page'] ?? '1') ?? 1;
      final limit = int.tryParse(queryParams['limit'] ?? '10') ?? 10;
      final sortBy = queryParams['sort_by'] ?? queryParams['sortBy'];
      final sortOrder = queryParams['sort_order'] ?? queryParams['sortOrder'];

      final (assets, totalCount) = await _service.getAllAssets(
        search: search,
        assetType: assetType,
        assetStatus: assetStatus,
        usedByEmployeeId: usedByEmployeeId,
        page: page,
        limit: limit,
        sortBy: sortBy,
        sortOrder: sortOrder,
      );

      return ApiResponse.success(
        data: {
          'items': assets.map((e) => e.toJson()).toList(),
          'pagination': {
            'page': page,
            'limit': limit,
            'total': totalCount,
            'totalPages': (totalCount / limit).ceil(),
            'hasMore': page * limit < totalCount,
          },
        },
      ).toShelfResponse();
    } catch (e) {
      _logger.error('Error fetching assets', e);
      return ApiResponse.error(
        code: 'FETCH_ERROR',
        message: e.toString(),
      ).toShelfResponse(statusCode: 500);
    }
  }

  Future<Response> _getAssetStatistics(Request request) async {
    try {
      final stats = await _service.getAssetStatistics();
      return ApiResponse.success(data: stats).toShelfResponse();
    } catch (e) {
      _logger.error('Error fetching asset statistics', e);
      return ApiResponse.error(
        code: 'FETCH_ERROR',
        message: e.toString(),
      ).toShelfResponse(statusCode: 500);
    }
  }

  Future<Response> _getAssetTypes(Request request) async {
    try {
      final types = await _service.getAssetTypes();
      return ApiResponse.success(data: types).toShelfResponse();
    } catch (e) {
      _logger.error('Error fetching asset types', e);
      return ApiResponse.error(
        code: 'FETCH_ERROR',
        message: e.toString(),
      ).toShelfResponse(statusCode: 500);
    }
  }

  Future<Response> _getAssetById(Request request, String id) async {
    try {
      final item = await _service.getAssetById(id);
      return ApiResponse.success(data: item.toJson()).toShelfResponse();
    } catch (e) {
      _logger.error('Error fetching asset $id', e);
      return ApiResponse.error(
        code: 'FETCH_ERROR',
        message: e.toString(),
      ).toShelfResponse(statusCode: 500);
    }
  }

  Future<Response> _createAsset(Request request) async {
    try {
      final payload = await request.readAsString();
      final data = jsonDecode(payload);
      final item = Asset.fromJson(data);
      final created = await _service.createAsset(item);
      return ApiResponse.success(
        data: created.toJson(),
      ).toShelfResponse(statusCode: 201);
    } catch (e) {
      _logger.error('Error creating asset', e);
      return ApiResponse.error(
        code: 'CREATE_ERROR',
        message: e.toString(),
      ).toShelfResponse(statusCode: 500);
    }
  }

  Future<Response> _updateAsset(Request request, String id) async {
    try {
      final payload = await request.readAsString();
      final updates = jsonDecode(payload) as Map<String, dynamic>;
      final updated = await _service.updateAsset(id, updates);
      return ApiResponse.success(data: updated.toJson()).toShelfResponse();
    } catch (e) {
      _logger.error('Error updating asset $id', e);
      return ApiResponse.error(
        code: 'UPDATE_ERROR',
        message: e.toString(),
      ).toShelfResponse(statusCode: 500);
    }
  }

  Future<Response> _deleteAsset(Request request, String id) async {
    try {
      await _service.deleteAsset(id);
      return ApiResponse.success(
        message: 'Asset deleted successfully',
      ).toShelfResponse();
    } catch (e) {
      _logger.error('Error deleting asset $id', e);
      return ApiResponse.error(
        code: 'DELETE_ERROR',
        message: e.toString(),
      ).toShelfResponse(statusCode: 500);
    }
  }
}
