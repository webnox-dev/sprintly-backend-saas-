import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';
import '../core/utils/logger.dart';

/// Service for uploading files to Cloudinary
class CloudinaryService {
  final AppLogger _logger = AppLogger('CloudinaryService');

  // Cloudinary configuration from environment
  String get _cloudName => 'dnkdrre1g'; // Hardcoded for debugging
  String get _apiKey => '372636514621377'; // Hardcoded for debugging
  String get _apiSecret =>
      'mvTJg_ksWnhbcJoxCSIpZZcgO_I'; // Hardcoded for debugging
  String get _uploadPreset => 'ml_default'; // Hardcoded for debugging

  /// Upload a file to Cloudinary
  ///
  /// [fileBytes] - The file content as bytes
  /// [fileName] - Original filename
  /// [resourceType] - 'auto', 'image', 'video', or 'raw' (for PDFs, documents)
  ///
  /// Returns a Map containing:
  /// - success: bool
  /// - url: String (secure URL)
  /// - publicId: String
  /// - format: String
  /// - resourceType: String
  Future<Map<String, dynamic>> uploadFile({
    required Uint8List fileBytes,
    required String fileName,
    String resourceType = 'auto',
    String? folder,
  }) async {
    try {
      _logger.info('Starting Cloudinary upload for: $fileName');

      // Determine resource type based on file extension
      final extension = fileName.split('.').last.toLowerCase();
      String effectiveResourceType = resourceType;

      if ([
        'pdf',
        'doc',
        'docx',
        'xls',
        'xlsx',
        'txt',
        'csv',
      ].contains(extension)) {
        effectiveResourceType = 'raw';
      } else if ([
        'jpg',
        'jpeg',
        'png',
        'gif',
        'webp',
        'svg',
      ].contains(extension)) {
        effectiveResourceType = 'image';
      } else if (['mp4', 'mov', 'avi', 'webm'].contains(extension)) {
        effectiveResourceType = 'video';
      } else {
        effectiveResourceType = 'auto';
      }

      final uploadUrl =
          'https://api.cloudinary.com/v1_1/$_cloudName/$effectiveResourceType/upload';

      final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      // Create multipart request
      final request = http.MultipartRequest('POST', Uri.parse(uploadUrl));

      // Add file
      request.files.add(
        http.MultipartFile.fromBytes('file', fileBytes, filename: fileName),
      );

      // Add required fields
      final Map<String, String> paramsToSign = {};

      paramsToSign['timestamp'] = timestamp.toString();

      // Add optional folder to signature params if present
      if (folder != null && folder.isNotEmpty) {
        request.fields['folder'] = folder;
        paramsToSign['folder'] = folder;
      }

      // Add public_id based on filename (without extension)
      final publicId =
          '${folder ?? 'sprintly'}/${DateTime.now().millisecondsSinceEpoch}_${fileName.split('.').first}';
      request.fields['public_id'] = publicId;
      paramsToSign['public_id'] = publicId;

      // Only include upload_preset if it's set and we want to use it
      // Note: If using signed upload, you typically don't strictly need one unless it defines transformations
      // But if we include it in fields, we MUST include it in signature
      if (_uploadPreset.isNotEmpty) {
        request.fields['upload_preset'] = _uploadPreset;
        paramsToSign['upload_preset'] = _uploadPreset;
      }

      // Generate signature
      final signature = _generateSignature(paramsToSign);

      request.fields['api_key'] = _apiKey;
      request.fields['timestamp'] = timestamp.toString();
      request.fields['signature'] = signature;

      _logger.info('Sending upload request to Cloudinary...');

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;

        _logger.info('Upload successful! URL: ${data['secure_url']}');

        return {
          'success': true,
          'url': data['secure_url'],
          'publicId': data['public_id'],
          'format': data['format'],
          'resourceType': data['resource_type'],
          'bytes': data['bytes'],
          'originalFilename': fileName,
        };
      } else {
        _logger.error('Cloudinary upload failed: ${response.body}');

        final errorData = jsonDecode(response.body) as Map<String, dynamic>;
        return {
          'success': false,
          'error': errorData['error']?['message'] ?? 'Upload failed',
          'statusCode': response.statusCode,
        };
      }
    } catch (e, stackTrace) {
      _logger.error('Error uploading to Cloudinary: $e', e, stackTrace);
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Get file type category for preview purposes
  static String getFileCategory(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();

    if ([
      'jpg',
      'jpeg',
      'png',
      'gif',
      'webp',
      'svg',
      'bmp',
    ].contains(extension)) {
      return 'image';
    } else if (['pdf'].contains(extension)) {
      return 'pdf';
    } else if (['doc', 'docx'].contains(extension)) {
      return 'word';
    } else if (['xls', 'xlsx'].contains(extension)) {
      return 'excel';
    } else if (['mp4', 'mov', 'avi', 'webm'].contains(extension)) {
      return 'video';
    } else {
      return 'other';
    }
  }

  /// Validate file type is allowed
  static bool isAllowedFileType(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    final allowedExtensions = [
      // Images
      'jpg', 'jpeg', 'png', 'gif', 'webp', 'svg', 'bmp',
      // Documents
      'pdf', 'doc', 'docx', 'xls', 'xlsx', 'txt', 'csv',
      // Videos
      'mp4', 'mov', 'avi', 'webm',
    ];
    return allowedExtensions.contains(extension);
  }

  /// Generate signature for Cloudinary upload
  String _generateSignature(Map<String, String> params) {
    // Sort keys alphabetically
    final sortedKeys = params.keys.toList()..sort();

    // Create parameter string
    final paramString = sortedKeys
        .map((key) => '$key=${params[key]}')
        .join('&');

    // Add API secret
    final stringToSign = '$paramString$_apiSecret';

    // Generate SHA-1 hash
    final bytes = utf8.encode(stringToSign);
    final digest = sha1.convert(bytes);

    return digest.toString();
  }

  /// Get max file size in bytes (10MB default)
  static int get maxFileSizeBytes => 10 * 1024 * 1024; // 10MB
}
