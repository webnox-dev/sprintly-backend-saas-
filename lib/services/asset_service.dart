import '../data/repositories/asset_repository.dart';
import '../domain/models/asset.dart';
import '../core/exceptions/app_exception.dart';
import '../core/utils/logger.dart';

class AssetService {
  final AssetRepository _repository = AssetRepository();
  final AppLogger _logger = AppLogger('AssetService');

  Future<(List<Asset>, int)> getAllAssets({
    String? search,
    String? assetType,
    String? assetStatus,
    String? usedByEmployeeId,
    int page = 1,
    int limit = 10,
    String? sortBy,
    String? sortOrder,
  }) async {
    try {
      return await _repository.getAllAssets(
        search: search,
        assetType: assetType,
        assetStatus: assetStatus,
        usedByEmployeeId: usedByEmployeeId,
        page: page,
        limit: limit,
        sortBy: sortBy,
        sortOrder: sortOrder,
      );
    } catch (e, stackTrace) {
      _logger.error('Error getting all assets: $e', e, stackTrace);
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getAssetStatistics() async {
    try {
      return await _repository.getAssetStatistics();
    } catch (e, stackTrace) {
      _logger.error('Error getting asset statistics: $e', e, stackTrace);
      rethrow;
    }
  }

  Future<List<String>> getAssetTypes() async {
    try {
      return await _repository.getAssetTypes();
    } catch (e, stackTrace) {
      _logger.error('Error getting asset types: $e', e, stackTrace);
      rethrow;
    }
  }

  Future<Asset> getAssetById(String id) async {
    try {
      final asset = await _repository.getAssetById(id);
      if (asset == null) {
        throw NotFoundException(resource: 'Asset', id: id);
      }
      return asset;
    } catch (e, stackTrace) {
      _logger.error('Error getting asset by ID: $e', e, stackTrace);
      rethrow;
    }
  }

  Future<Asset> createAsset(Asset asset) async {
    try {
      return await _repository.createAsset(asset);
    } catch (e, stackTrace) {
      _logger.error('Error creating asset: $e', e, stackTrace);
      rethrow;
    }
  }

  Future<Asset> updateAsset(String id, Map<String, dynamic> updates) async {
    try {
      final asset = await _repository.updateAsset(id, updates);
      if (asset == null) {
        throw NotFoundException(resource: 'Asset', id: id);
      }
      return asset;
    } catch (e, stackTrace) {
      _logger.error('Error updating asset: $e', e, stackTrace);
      rethrow;
    }
  }

  Future<bool> deleteAsset(String id) async {
    try {
      final success = await _repository.deleteAsset(id);
      if (!success) {
        throw NotFoundException(resource: 'Asset', id: id);
      }
      return success;
    } catch (e, stackTrace) {
      _logger.error('Error deleting asset: $e', e, stackTrace);
      rethrow;
    }
  }
}
