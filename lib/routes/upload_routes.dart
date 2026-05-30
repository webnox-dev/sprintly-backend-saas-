import 'dart:convert';
import 'dart:typed_data';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import '../services/cloudinary_service.dart';
import '../services/auth_service.dart';
import '../core/response/api_response.dart';
import '../core/exceptions/app_exception.dart';
import '../core/utils/logger.dart';
import '../data/database/connection.dart';

/// Routes for file upload operations
class UploadRoutes {
  final CloudinaryService _cloudinaryService = CloudinaryService();
  final AuthService _authService = AuthService();
  final AppLogger _logger = AppLogger('UploadRoutes');

  Router get router {
    final router = Router();

    // POST /api/uploadFileToBucket - Upload file to Cloudinary
    router.post('/uploadFileToBucket', handleUploadFile);

    return router;
  }

  /// POST /api/upload/uploadFileToBucket
  ///
  /// Multipart request with:
  /// - file: The file to upload
  /// - folder (optional): Folder name in Cloudinary
  ///
  /// Returns:
  /// - url: The secure URL of the uploaded file
  /// - publicId: The Cloudinary public ID
  Future<Response> handleUploadFile(Request request) async {
    try {
      // Check for Bearer token (authentication required)
      final authHeader = request.headers['authorization'];
      if (authHeader == null || !authHeader.startsWith('Bearer ')) {
        return ApiResponse.error(
          code: 'UNAUTHORIZED',
          message: 'Bearer token is required',
        ).toShelfResponse(statusCode: 401);
      }

      final token = authHeader.substring(7);
      final user = await _authService.verifyToken(token);
      if (user == null) {
        return ApiResponse.error(
          code: 'UNAUTHORIZED',
          message: 'Invalid or expired token',
        ).toShelfResponse(statusCode: 401);
      }

      // Parse multipart request
      final contentType = request.headers['content-type'];
      if (contentType == null || !contentType.contains('multipart/form-data')) {
        return ApiResponse.error(
          code: 'INVALID_REQUEST',
          message: 'Content-Type must be multipart/form-data',
        ).toShelfResponse(statusCode: 400);
      }

      // Extract boundary from content-type
      // Fix: stopping at first semicolon or end of string, handling quotes
      final boundaryMatch = RegExp(
        r'boundary="?([^";]+)"?',
      ).firstMatch(contentType);
      if (boundaryMatch == null) {
        return ApiResponse.error(
          code: 'INVALID_REQUEST',
          message: 'Missing boundary in multipart request',
        ).toShelfResponse(statusCode: 400);
      }

      final boundary = boundaryMatch.group(1)!;
      final body = await request.read().toList();
      final bytes = body.expand((chunk) => chunk).toList();

      // Parse multipart data
      final parsedData = _parseMultipart(Uint8List.fromList(bytes), boundary);

      if (parsedData['file'] == null) {
        return ApiResponse.error(
          code: 'VALIDATION_ERROR',
          message: 'No file provided',
        ).toShelfResponse(statusCode: 400);
      }

      final fileBytes = parsedData['file'] as Uint8List;
      final fileName = parsedData['fileName'] as String? ?? 'unknown';
      final folder = parsedData['folder'] as String? ?? 'sprintly_documents';

      // Validate file type
      if (!CloudinaryService.isAllowedFileType(fileName)) {
        return ApiResponse.error(
          code: 'INVALID_FILE_TYPE',
          message:
              'File type not allowed. Allowed types: images, PDFs, Word, Excel, videos',
        ).toShelfResponse(statusCode: 400);
      }

      // Validate file size (10MB max)
      if (fileBytes.length > CloudinaryService.maxFileSizeBytes) {
        return ApiResponse.error(
          code: 'FILE_TOO_LARGE',
          message: 'File size exceeds maximum allowed (10MB)',
        ).toShelfResponse(statusCode: 400);
      }

      // ── Storage quota check ────────────────────────────────────────────────
      // Read org_id from the user token; skip check if not available yet
      final orgId = user.organizationId;
      if (orgId != null && orgId.isNotEmpty) {
        try {
          final quotaRows = await DatabaseConnection.query(
            'SELECT check_org_storage_quota(@orgId::uuid, @bytes) AS allowed',
            values: {'orgId': orgId, 'bytes': fileBytes.length},
          );
          final allowed = quotaRows.isNotEmpty && quotaRows.first['allowed'] == true;
          if (!allowed) {
            return ApiResponse.error(
              code: 'STORAGE_QUOTA_EXCEEDED',
              message: 'Storage limit reached for your plan. Please upgrade or delete old files.',
            ).toShelfResponse(statusCode: 403);
          }
        } catch (e) {
          // If the quota function doesn't exist yet (migration not run), allow upload
          _logger.warning('Storage quota check skipped (migration not applied?): $e');
        }
      }
      // ─────────────────────────────────────────────────────────────────────────

      _logger.info('Uploading file: $fileName (${fileBytes.length} bytes)');

      // Upload to Cloudinary
      final result = await _cloudinaryService.uploadFile(
        fileBytes: fileBytes,
        fileName: fileName,
        folder: folder,
      );

      if (result['success'] == true) {
        _logger.info('File uploaded successfully: ${result['url']}');

        // ── Record storage usage ───────────────────────────────────────────
        // orgId comes from the JWT payload (set during login)
        final uploadOrgId = user.organizationId;
        if (uploadOrgId != null && uploadOrgId.isNotEmpty) {
          try {
            await DatabaseConnection.execute(
              '''
              INSERT INTO org_file_uploads
                (organization_id, uploaded_by, uploader_type, cloudinary_url,
                 public_id, file_name, file_type, bytes_used, folder)
              VALUES
                (@orgId::uuid, @uploadedBy, @uploaderType, @url,
                 @publicId, @fileName, @fileType, @bytes, @folder)
              ''',
              values: {
                'orgId':        uploadOrgId,
                'uploadedBy':   user.id,
                'uploaderType': user.role.toLowerCase() == 'admin' ? 'admin' : 'employee',
                'url':          result['url'],
                'publicId':     result['publicId'],
                'fileName':     fileName,
                'fileType':     CloudinaryService.getFileCategory(fileName),
                'bytes':        result['bytes'] ?? fileBytes.length,
                'folder':       folder,
              },
            );
            _logger.info('Recorded ${result['bytes'] ?? fileBytes.length} bytes for org $uploadOrgId');
          } catch (e) {
            // Log but don't fail the upload — file is already on Cloudinary
            _logger.warning('Failed to record storage usage: $e');
          }
        }
        // ──────────────────────────────────────────────────────────────────

        return ApiResponse.success(
          message: 'File uploaded successfully',
          data: {
            'url': result['url'],
            'publicId': result['publicId'],
            'fileName': result['originalFilename'],
            'fileType': CloudinaryService.getFileCategory(fileName),
            'format': result['format'],
            'bytes': result['bytes'],
          },
        ).toShelfResponse();
      } else {
        _logger.error('Upload failed: ${result['error']}');
        return ApiResponse.error(
          code: 'UPLOAD_FAILED',
          message: result['error'] ?? 'Failed to upload file',
        ).toShelfResponse(statusCode: 500);
      }
    } on AppException catch (e) {
      return ApiResponse.error(
        code: e.code,
        message: e.message,
        details: e.details,
      ).toShelfResponse(statusCode: 400);
    } catch (e, stackTrace) {
      _logger.error('Error in handleUploadFile: $e', e, stackTrace);
      return ApiResponse.error(
        code: 'INTERNAL_ERROR',
        message: 'Internal server error: ${e.toString()}',
      ).toShelfResponse(statusCode: 500);
    }
  }

  /// Parse multipart form data
  Map<String, dynamic> _parseMultipart(Uint8List bytes, String boundary) {
    final result = <String, dynamic>{};
    final boundaryBytes = utf8.encode('--$boundary');

    // Find all boundary positions
    final positions = <int>[];
    int pos = 0;
    while (true) {
      final p = _findSequence(bytes, boundaryBytes, pos);
      if (p == -1) break;
      positions.add(p);
      pos = p + boundaryBytes.length;
    }

    if (positions.isEmpty) return result;

    // Iterate parts
    for (int i = 0; i < positions.length - 1; i++) {
      int partStart = positions[i] + boundaryBytes.length;
      int partEnd = positions[i + 1];

      // Skip CRLF at start of part (if present)
      if (partStart + 1 < bytes.length &&
          bytes[partStart] == 13 &&
          bytes[partStart + 1] == 10) {
        partStart += 2;
      }

      // Skip CRLF at end of part (before next boundary)
      if (partEnd - 2 >= partStart &&
          bytes[partEnd - 2] == 13 &&
          bytes[partEnd - 1] == 10) {
        partEnd -= 2;
      }

      if (partStart >= partEnd) continue;

      // Isolate part bytes
      final partBytes = Uint8List.sublistView(bytes, partStart, partEnd);

      // Find double CRLF separating headers from body
      final doubleCrlfPos = _findSequence(partBytes, utf8.encode('\r\n\r\n'));
      if (doubleCrlfPos == -1) continue;

      final headerBytes = Uint8List.sublistView(partBytes, 0, doubleCrlfPos);
      final bodyBytes = Uint8List.sublistView(partBytes, doubleCrlfPos + 4);

      final headerString = utf8.decode(headerBytes, allowMalformed: true);
      _logger.info('Part Headers: $headerString');

      // Parse Content-Disposition
      final dispositionMatch = RegExp(
        r'Content-Disposition:\s*form-data;\s*name="([^"]+)"(?:;\s*filename="([^"]+)")?',
        caseSensitive: false,
      ).firstMatch(headerString);

      if (dispositionMatch != null) {
        final fieldName = dispositionMatch.group(1);
        final fileName = dispositionMatch.group(2);

        if (fileName != null) {
          // It's a file
          result['file'] = bodyBytes;
          result['fileName'] = fileName;
        } else if (fieldName != null) {
          // It's a field
          result[fieldName] = utf8.decode(bodyBytes, allowMalformed: true);
        }
      }
    }

    return result;
  }

  /// Find byte sequence in byte list
  int _findSequence(List<int> bytes, List<int> sequence, [int start = 0]) {
    for (int i = start; i <= bytes.length - sequence.length; i++) {
      bool found = true;
      for (int j = 0; j < sequence.length; j++) {
        if (bytes[i + j] != sequence[j]) {
          found = false;
          break;
        }
      }
      if (found) return i;
    }
    return -1;
  }
}
