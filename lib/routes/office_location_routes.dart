import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'dart:convert';
import '../core/response/api_response.dart';
import '../core/utils/logger.dart';
import '../data/database/connection.dart';

/// Office Location routes handler
class OfficeLocationRoutes {
  final AppLogger _logger = AppLogger('OfficeLocationRoutes');

  Router get router {
    final router = Router();

    // GET /api/office-locations - Get all office locations
    router.get('/office-locations', _getAllLocations);

    // GET /api/office-locations/active - Get only active office locations
    router.get('/office-locations/active', _getActiveLocations);

    // GET /api/office-locations/:id - Get office location by ID
    router.get('/office-locations/<id>', _getLocationById);

    // POST /api/office-locations - Create new office location
    router.post('/office-locations', _createLocation);

    // PUT /api/office-locations/:id - Update office location
    router.put('/office-locations/<id>', _updateLocation);

    // DELETE /api/office-locations/:id - Delete office location
    router.delete('/office-locations/<id>', _deleteLocation);

    return router;
  }

  /// Helper to convert DateTime objects to ISO strings
  Map<String, dynamic> _convertDateTimeToString(Map<String, dynamic> row) {
    return row.map((key, value) {
      if (value is DateTime) {
        return MapEntry(key, value.toIso8601String());
      }
      return MapEntry(key, value);
    });
  }

  /// GET /api/office-locations
  Future<Response> _getAllLocations(Request request) async {
    try {
      final sql = '''
        SELECT * FROM office_locations 
        ORDER BY location_name
      ''';

      final results = await DatabaseConnection.query(sql, values: {});

      // Convert DateTime objects to ISO strings
      final data = results.map((row) => _convertDateTimeToString(row)).toList();

      return ApiResponse.success(data: data).toShelfResponse();
    } catch (e, stackTrace) {
      _logger.error('Error in _getAllLocations: $e', e, stackTrace);
      return ApiResponse.error(
        code: 'INTERNAL_ERROR',
        message: 'Internal server error: $e',
      ).toShelfResponse(statusCode: 500);
    }
  }

  /// GET /api/office-locations/active
  Future<Response> _getActiveLocations(Request request) async {
    try {
      final sql = '''
        SELECT * FROM office_locations 
        WHERE is_active = true
        ORDER BY location_name
      ''';

      final results = await DatabaseConnection.query(sql, values: {});

      _logger.info('Found ${results.length} active office locations');

      // Convert DateTime objects to ISO strings
      final data = results.map((row) => _convertDateTimeToString(row)).toList();

      return ApiResponse.success(data: data).toShelfResponse();
    } catch (e, stackTrace) {
      _logger.error('Error in _getActiveLocations: $e', e, stackTrace);
      return ApiResponse.error(
        code: 'INTERNAL_ERROR',
        message: 'Internal server error: $e',
      ).toShelfResponse(statusCode: 500);
    }
  }

  /// GET /api/office-locations/:id
  Future<Response> _getLocationById(Request request, String id) async {
    try {
      final sql = '''
        SELECT * FROM office_locations 
        WHERE location_id = @id
      ''';

      final result = await DatabaseConnection.queryOne(sql, values: {'id': id});

      if (result == null) {
        return ApiResponse.error(
          code: 'NOT_FOUND',
          message: 'Office location not found',
        ).toShelfResponse(statusCode: 404);
      }

      // Convert DateTime objects to ISO strings
      final data = _convertDateTimeToString(result);

      return ApiResponse.success(data: data).toShelfResponse();
    } catch (e, stackTrace) {
      _logger.error('Error in _getLocationById: $e', e, stackTrace);
      return ApiResponse.error(
        code: 'INTERNAL_ERROR',
        message: 'Internal server error: $e',
      ).toShelfResponse(statusCode: 500);
    }
  }

  /// POST /api/office-locations
  Future<Response> _createLocation(Request request) async {
    try {
      final body = await request.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;

      // Validate required fields
      final locationName = data['location_name']?.toString();
      final address = data['address']?.toString();
      final latitude = data['latitude'];
      final longitude = data['longitude'];

      if (locationName == null || locationName.isEmpty) {
        return ApiResponse.error(
          code: 'VALIDATION_ERROR',
          message: 'Location name is required',
        ).toShelfResponse(statusCode: 400);
      }

      if (address == null || address.isEmpty) {
        return ApiResponse.error(
          code: 'VALIDATION_ERROR',
          message: 'Address is required',
        ).toShelfResponse(statusCode: 400);
      }

      if (latitude == null) {
        return ApiResponse.error(
          code: 'VALIDATION_ERROR',
          message: 'Latitude is required',
        ).toShelfResponse(statusCode: 400);
      }

      if (longitude == null) {
        return ApiResponse.error(
          code: 'VALIDATION_ERROR',
          message: 'Longitude is required',
        ).toShelfResponse(statusCode: 400);
      }

      final radiusMeters = data['radius_meters'] ?? 100;
      final isActive = data['is_active'] ?? true;
      final createdBy = data['created_by']?.toString();
      final publicIp = data['public_ip']?.toString();

      final sql = '''
        INSERT INTO office_locations (
          location_name, address, latitude, longitude, 
          radius_meters, is_active, created_by, public_ip,
          created_at, updated_at
        ) VALUES (
          @location_name, @address, @latitude, @longitude,
          @radius_meters, @is_active, @created_by, @public_ip,
          CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
        )
        RETURNING *
      ''';

      final result = await DatabaseConnection.queryOne(
        sql,
        values: {
          'location_name': locationName,
          'address': address,
          'latitude': latitude is double
              ? latitude
              : double.tryParse(latitude.toString()) ?? 0.0,
          'longitude': longitude is double
              ? longitude
              : double.tryParse(longitude.toString()) ?? 0.0,
          'radius_meters': radiusMeters is int
              ? radiusMeters
              : int.tryParse(radiusMeters.toString()) ?? 100,
          'is_active': isActive,
          'created_by': createdBy,
          'public_ip': publicIp,
        },
      );

      if (result == null) {
        return ApiResponse.error(
          code: 'CREATE_FAILED',
          message: 'Failed to create office location',
        ).toShelfResponse(statusCode: 500);
      }

      _logger.info('Created office location: $locationName');

      return ApiResponse.success(
        message: 'Office location created successfully',
        data: _convertDateTimeToString(result),
      ).toShelfResponse(statusCode: 201);
    } catch (e, stackTrace) {
      _logger.error('Error in _createLocation: $e', e, stackTrace);
      return ApiResponse.error(
        code: 'INTERNAL_ERROR',
        message: 'Internal server error: $e',
      ).toShelfResponse(statusCode: 500);
    }
  }

  /// PUT /api/office-locations/:id
  Future<Response> _updateLocation(Request request, String id) async {
    try {
      // Check if location exists
      final checkSql = 'SELECT * FROM office_locations WHERE location_id = @id';
      final existing = await DatabaseConnection.queryOne(
        checkSql,
        values: {'id': id},
      );

      if (existing == null) {
        return ApiResponse.error(
          code: 'NOT_FOUND',
          message: 'Office location not found',
        ).toShelfResponse(statusCode: 404);
      }

      final body = await request.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;

      // Build dynamic update query
      final updates = <String>[];
      final values = <String, dynamic>{'id': id};

      if (data.containsKey('location_name')) {
        updates.add('location_name = @location_name');
        values['location_name'] = data['location_name'];
      }
      if (data.containsKey('address')) {
        updates.add('address = @address');
        values['address'] = data['address'];
      }
      if (data.containsKey('latitude')) {
        updates.add('latitude = @latitude');
        final lat = data['latitude'];
        values['latitude'] = lat is double
            ? lat
            : double.tryParse(lat.toString()) ?? 0.0;
      }
      if (data.containsKey('longitude')) {
        updates.add('longitude = @longitude');
        final lng = data['longitude'];
        values['longitude'] = lng is double
            ? lng
            : double.tryParse(lng.toString()) ?? 0.0;
      }
      if (data.containsKey('radius_meters')) {
        updates.add('radius_meters = @radius_meters');
        final radius = data['radius_meters'];
        values['radius_meters'] = radius is int
            ? radius
            : int.tryParse(radius.toString()) ?? 100;
      }
      if (data.containsKey('is_active')) {
        updates.add('is_active = @is_active');
        values['is_active'] = data['is_active'];
      }
      if (data.containsKey('public_ip')) {
        updates.add('public_ip = @public_ip');
        values['public_ip'] = data['public_ip'];
      }
      if (data.containsKey('updated_by')) {
        updates.add('updated_by = @updated_by');
        values['updated_by'] = data['updated_by'];
      }

      // Always update updated_at
      updates.add('updated_at = CURRENT_TIMESTAMP');

      if (updates.isEmpty) {
        return ApiResponse.error(
          code: 'VALIDATION_ERROR',
          message: 'No fields to update',
        ).toShelfResponse(statusCode: 400);
      }

      final sql =
          '''
        UPDATE office_locations 
        SET ${updates.join(', ')}
        WHERE location_id = @id
        RETURNING *
      ''';

      final result = await DatabaseConnection.queryOne(sql, values: values);

      if (result == null) {
        return ApiResponse.error(
          code: 'UPDATE_FAILED',
          message: 'Failed to update office location',
        ).toShelfResponse(statusCode: 500);
      }

      _logger.info('Updated office location: $id');

      return ApiResponse.success(
        message: 'Office location updated successfully',
        data: _convertDateTimeToString(result),
      ).toShelfResponse();
    } catch (e, stackTrace) {
      _logger.error('Error in _updateLocation: $e', e, stackTrace);
      return ApiResponse.error(
        code: 'INTERNAL_ERROR',
        message: 'Internal server error: $e',
      ).toShelfResponse(statusCode: 500);
    }
  }

  /// DELETE /api/office-locations/:id
  Future<Response> _deleteLocation(Request request, String id) async {
    try {
      // Check if location exists
      final checkSql = 'SELECT * FROM office_locations WHERE location_id = @id';
      final existing = await DatabaseConnection.queryOne(
        checkSql,
        values: {'id': id},
      );

      if (existing == null) {
        return ApiResponse.error(
          code: 'NOT_FOUND',
          message: 'Office location not found',
        ).toShelfResponse(statusCode: 404);
      }

      final sql = 'DELETE FROM office_locations WHERE location_id = @id';
      await DatabaseConnection.execute(sql, values: {'id': id});

      _logger.info('Deleted office location: $id');

      return ApiResponse.success(
        message: 'Office location deleted successfully',
      ).toShelfResponse();
    } catch (e, stackTrace) {
      _logger.error('Error in _deleteLocation: $e', e, stackTrace);
      return ApiResponse.error(
        code: 'INTERNAL_ERROR',
        message: 'Internal server error: $e',
      ).toShelfResponse(statusCode: 500);
    }
  }
}
