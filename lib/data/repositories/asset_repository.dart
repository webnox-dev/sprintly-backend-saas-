import '../../domain/models/asset.dart';
import '../database/connection.dart';

class AssetRepository {
  /// Get all assets with server-side search, filter, and pagination
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
    // Build WHERE clauses
    final whereClauses = <String>[];
    final values = <String, dynamic>{};

    // Search filter
    if (search != null && search.isNotEmpty) {
      whereClauses.add(
        "(LOWER(asset_name) LIKE @search OR LOWER(asset_description) LIKE @search OR LOWER(serial_number) LIKE @search OR LOWER(asset_model) LIKE @search)",
      );
      values['search'] = '%${search.toLowerCase()}%';
    }

    // Asset type filter
    if (assetType != null && assetType.isNotEmpty && assetType != 'all') {
      whereClauses.add("asset_type = @assetType");
      values['assetType'] = assetType;
    }

    // Asset status filter
    if (assetStatus != null && assetStatus.isNotEmpty && assetStatus != 'all') {
      whereClauses.add("asset_status = @assetStatus");
      values['assetStatus'] = assetStatus;
    }

    // Used by employee filter
    if (usedByEmployeeId != null && usedByEmployeeId.isNotEmpty) {
      whereClauses.add("used_by_employee_id = @usedByEmployeeId");
      values['usedByEmployeeId'] = usedByEmployeeId;
    }

    final whereClause = whereClauses.isNotEmpty
        ? 'WHERE ${whereClauses.join(' AND ')}'
        : '';

    // Sorting
    final validSortColumns = [
      'asset_name',
      'asset_type',
      'asset_status',
      'serial_number',
      'created_at',
    ];
    final sortColumn = validSortColumns.contains(sortBy)
        ? sortBy
        : 'asset_name';
    final order = sortOrder?.toUpperCase() == 'DESC' ? 'DESC' : 'ASC';

    // Get total count
    final countResult = await DatabaseConnection.query(
      'SELECT COUNT(*) as count FROM assets $whereClause',
      values: values,
    );
    final totalCount = (countResult.first['count'] as int?) ?? 0;

    // Pagination
    final offset = (page - 1) * limit;
    values['limit'] = limit;
    values['offset'] = offset;

    // Get paginated results
    final result = await DatabaseConnection.query('''
      SELECT * FROM assets 
      $whereClause 
      ORDER BY $sortColumn $order 
      LIMIT @limit OFFSET @offset
      ''', values: values);

    final assets = result.map((row) => Asset.fromJson(row)).toList();
    return (assets, totalCount);
  }

  /// Get asset statistics
  Future<Map<String, dynamic>> getAssetStatistics() async {
    final result = await DatabaseConnection.query('''
      SELECT 
        COUNT(*) as total,
        COUNT(CASE WHEN asset_status = 'Available' THEN 1 END) as available,
        COUNT(CASE WHEN asset_status = 'In Use' THEN 1 END) as in_use,
        COUNT(CASE WHEN asset_status = 'Under Repair' THEN 1 END) as under_repair,
        COUNT(CASE WHEN asset_status = 'Damaged' OR asset_status = 'Lost' THEN 1 END) as damaged_lost
      FROM assets
    ''');

    if (result.isEmpty) {
      return {
        'total': 0,
        'available': 0,
        'in_use': 0,
        'under_repair': 0,
        'damaged_lost': 0,
      };
    }

    return {
      'total': result.first['total'] ?? 0,
      'available': result.first['available'] ?? 0,
      'in_use': result.first['in_use'] ?? 0,
      'under_repair': result.first['under_repair'] ?? 0,
      'damaged_lost': result.first['damaged_lost'] ?? 0,
    };
  }

  /// Get distinct asset types for filter dropdown
  Future<List<String>> getAssetTypes() async {
    final result = await DatabaseConnection.query(
      'SELECT DISTINCT asset_type FROM assets WHERE asset_type IS NOT NULL ORDER BY asset_type ASC',
    );
    return result.map((row) => row['asset_type'] as String).toList();
  }

  Future<Asset?> getAssetById(String id) async {
    final result = await DatabaseConnection.query(
      'SELECT * FROM assets WHERE asset_id = @id',
      values: {'id': id},
    );
    if (result.isEmpty) return null;
    return Asset.fromJson(result.first);
  }

  Future<Asset> createAsset(Asset asset) async {
    final result = await DatabaseConnection.query(
      '''
      INSERT INTO assets (
        asset_name, asset_description, asset_type, asset_status, 
        asset_model, asset_configuration, used_by_employee_id, 
        serial_number, imei_number, created_by
      ) VALUES (
        @name, @description, @type, @status, 
        @model, @config, @usedBy, 
        @serial, @imei, @createdBy
      ) RETURNING *
      ''',
      values: {
        'name': asset.assetName,
        'description': asset.assetDescription,
        'type': asset.assetType,
        'status': asset.assetStatus,
        'model': asset.assetModel,
        'config': asset.assetConfiguration,
        'usedBy': asset.usedByEmployeeId,
        'serial': asset.serialNumber,
        'imei': asset.imeiNumber,
        'createdBy': asset.createdBy,
      },
    );
    return Asset.fromJson(result.first);
  }

  Future<Asset?> updateAsset(String id, Map<String, dynamic> updates) async {
    final setClauses = <String>[];
    final values = <String, dynamic>{'id': id};

    updates.forEach((key, value) {
      if (key != 'asset_id' && key != 'created_at' && key != 'updated_at') {
        setClauses.add('$key = @$key');
        values[key] = value;
      }
    });

    if (setClauses.isEmpty) return await getAssetById(id);

    final query =
        '''
      UPDATE assets 
      SET ${setClauses.join(', ')} 
      WHERE asset_id = @id 
      RETURNING *
    ''';

    final result = await DatabaseConnection.query(query, values: values);
    if (result.isEmpty) return null;
    return Asset.fromJson(result.first);
  }

  Future<bool> deleteAsset(String id) async {
    final count = await DatabaseConnection.execute(
      'DELETE FROM assets WHERE asset_id = @id',
      values: {'id': id},
    );
    return count > 0;
  }
}
