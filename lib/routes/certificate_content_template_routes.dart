import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import '../../data/repositories/certificate_content_template_repository.dart';
import '../../domain/models/certificate_content_template.dart';

class CertificateContentTemplateRoutes {
  final Router _router = Router();
  final CertificateContentTemplateRepository _repository =
      CertificateContentTemplateRepository();

  Router get router {
    _router.get('/certificate-content-templates', _getAllTemplates);
    _router.get('/certificate-content-templates/match', _findBestMatch);
    _router.get('/certificate-content-templates/roles', _getRoles);
    _router.get(
      '/certificate-content-templates/designations',
      _getDesignations,
    );
    _router.get('/certificate-content-templates/<id>', _getTemplateById);
    _router.post('/certificate-content-templates', _createTemplate);
    _router.put('/certificate-content-templates/<id>', _updateTemplate);
    _router.delete('/certificate-content-templates/<id>', _deleteTemplate);

    return _router;
  }

  Future<Response> _getAllTemplates(Request request) async {
    try {
      final type = request.url.queryParameters['type'];
      final role = request.url.queryParameters['role'];
      final designation = request.url.queryParameters['designation'];

      final templates = await _repository.getAllTemplates(
        certificateType: type,
        role: role,
        designation: designation,
      );

      return Response.ok(
        jsonEncode({
          'success': true,
          'message': 'Templates retrieved successfully',
          'data': templates.map((e) => e.toMap()).toList(),
        }),
        headers: {'content-type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({
          'success': false,
          'message': 'Failed to retrieve templates: $e',
        }),
        headers: {'content-type': 'application/json'},
      );
    }
  }

  bool _isValidUuid(String id) {
    return RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    ).hasMatch(id);
  }

  Future<Response> _getTemplateById(Request request, String id) async {
    try {
      if (!_isValidUuid(id)) {
        return Response.badRequest(
          body: jsonEncode({
            'success': false,
            'message': 'Invalid template ID',
          }),
          headers: {'content-type': 'application/json'},
        );
      }
      final template = await _repository.getTemplateById(id);

      if (template == null) {
        return Response.notFound(
          jsonEncode({'success': false, 'message': 'Template not found'}),
          headers: {'content-type': 'application/json'},
        );
      }

      return Response.ok(
        jsonEncode({
          'success': true,
          'message': 'Template retrieved successfully',
          'data': template.toMap(),
        }),
        headers: {'content-type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({
          'success': false,
          'message': 'Failed to retrieve template: $e',
        }),
        headers: {'content-type': 'application/json'},
      );
    }
  }

  Future<Response> _findBestMatch(Request request) async {
    try {
      final type = request.url.queryParameters['type'];
      final role = request.url.queryParameters['role'];
      final designation = request.url.queryParameters['designation'];

      if (type == null || role == null) {
        return Response.badRequest(
          body: jsonEncode({
            'success': false,
            'message': 'type and role are required parameters',
          }),
          headers: {'content-type': 'application/json'},
        );
      }

      final template = await _repository.findBestMatch(type, role, designation);

      if (template == null) {
        return Response.ok(
          jsonEncode({
            'success': true,
            'message': 'No match found, use fallback',
            'data': null,
          }),
          headers: {'content-type': 'application/json'},
        );
      }

      return Response.ok(
        jsonEncode({
          'success': true,
          'message': 'Best match retrieved successfully',
          'data': template.toMap(),
        }),
        headers: {'content-type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({
          'success': false,
          'message': 'Failed to find match: $e',
        }),
        headers: {'content-type': 'application/json'},
      );
    }
  }

  Future<Response> _createTemplate(Request request) async {
    try {
      final payload = await request.readAsString();
      final data = jsonDecode(payload);

      final template = CertificateContentTemplate.fromMap(data);

      // if missing fields, let fromMap or DB catch it
      final createdTemplate = await _repository.createTemplate(template);

      if (createdTemplate == null) {
        return Response.internalServerError(
          body: jsonEncode({
            'success': false,
            'message': 'Failed to create template (returned null)',
          }),
          headers: {'content-type': 'application/json'},
        );
      }

      return Response.ok(
        jsonEncode({
          'success': true,
          'message': 'Template created successfully',
          'data': createdTemplate.toMap(),
        }),
        headers: {'content-type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({
          'success': false,
          'message': 'Error creating template: $e',
        }),
        headers: {'content-type': 'application/json'},
      );
    }
  }

  Future<Response> _updateTemplate(Request request, String id) async {
    try {
      if (!_isValidUuid(id)) {
        return Response.badRequest(
          body: jsonEncode({
            'success': false,
            'message': 'Invalid template ID',
          }),
          headers: {'content-type': 'application/json'},
        );
      }
      final payload = await request.readAsString();
      final data = jsonDecode(payload);
      data['id'] = id; // Ensure ID matches

      final templateToUpdate = CertificateContentTemplate.fromMap(data);

      final updatedTemplate = await _repository.updateTemplate(
        id,
        templateToUpdate,
      );

      if (updatedTemplate == null) {
        return Response.notFound(
          jsonEncode({
            'success': false,
            'message': 'Template not found or update failed',
          }),
          headers: {'content-type': 'application/json'},
        );
      }

      return Response.ok(
        jsonEncode({
          'success': true,
          'message': 'Template updated successfully',
          'data': updatedTemplate.toMap(),
        }),
        headers: {'content-type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({
          'success': false,
          'message': 'Error updating template: $e',
        }),
        headers: {'content-type': 'application/json'},
      );
    }
  }

  Future<Response> _deleteTemplate(Request request, String id) async {
    try {
      if (!_isValidUuid(id)) {
        return Response.badRequest(
          body: jsonEncode({
            'success': false,
            'message': 'Invalid template ID',
          }),
          headers: {'content-type': 'application/json'},
        );
      }
      final success = await _repository.deleteTemplate(id);

      if (!success) {
        return Response.notFound(
          jsonEncode({
            'success': false,
            'message': 'Template not found or already deleted',
          }),
          headers: {'content-type': 'application/json'},
        );
      }

      return Response.ok(
        jsonEncode({
          'success': true,
          'message': 'Template deleted successfully',
        }),
        headers: {'content-type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({
          'success': false,
          'message': 'Error deleting template: $e',
        }),
        headers: {'content-type': 'application/json'},
      );
    }
  }

  Future<Response> _getRoles(Request request) async {
    try {
      final roles = await _repository.getDistinctRoles();
      return Response.ok(
        jsonEncode({'success': true, 'data': roles}),
        headers: {'content-type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({
          'success': false,
          'message': 'Error fetching roles: $e',
        }),
        headers: {'content-type': 'application/json'},
      );
    }
  }

  Future<Response> _getDesignations(Request request) async {
    try {
      final role = request.url.queryParameters['role'];
      final designations = await _repository.getDistinctDesignations(
        role: role,
      );
      return Response.ok(
        jsonEncode({'success': true, 'data': designations}),
        headers: {'content-type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({
          'success': false,
          'message': 'Error fetching designations: $e',
        }),
        headers: {'content-type': 'application/json'},
      );
    }
  }
}
