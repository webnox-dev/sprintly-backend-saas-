import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import '../services/ai/ai_service.dart';
import '../core/response/api_response.dart';
import '../core/utils/logger.dart';

/// API routes for AI Chat functionality
class AiRoutes {
  final AppLogger _logger = AppLogger('AiRoutes');

  Router get router {
    final router = Router();

    // POST /api/ai/chat - Send a message to AI
    router.post('/ai/chat', _chat);

    // GET /api/ai/status - Check AI service status
    router.get('/ai/status', _status);

    // GET /api/ai/history/<sessionId> - Get chat history
    router.get('/ai/history/<sessionId>', _getHistory);

    // DELETE /api/ai/session/<sessionId> - Clear chat session
    router.delete('/ai/session/<sessionId>', _clearSession);

    return router;
  }

  /// Extract user ID from request context (set by auth middleware)
  String _getUserId(Request request) {
    // Auth middleware adds 'employeeId' (or 'user') to context
    final employeeId = request.context['employeeId'];
    if (employeeId != null) return employeeId.toString();

    // Fallback: try the user object
    final user = request.context['user'];
    if (user != null) {
      // User is a model with employeeId property
      try {
        return (user as dynamic).employeeId?.toString() ?? 'unknown';
      } catch (_) {}
    }

    return 'unknown';
  }

  /// Extract user role from request context
  String _getUserRole(Request request) {
    final role = request.context['role'];
    if (role != null) return role.toString();
    return 'Employee'; // Default to Employee for safety
  }

  /// POST /api/ai/chat
  /// Body: { message, session_id?, current_tab? }
  Future<Response> _chat(Request request) async {
    try {
      final userId = _getUserId(request);
      final role = _getUserRole(request);

      // Parse body
      final body =
          jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final message = body['message'] as String?;
      final sessionId =
          body['session_id'] as String? ??
          'session_${userId}_${DateTime.now().millisecondsSinceEpoch}';
      final currentTab = body['current_tab'] as String?;

      if (message == null || message.trim().isEmpty) {
        return ApiResponse.error(
          code: 'VALIDATION_ERROR',
          message: 'Message is required.',
        ).toShelfResponse(statusCode: 400);
      }

      _logger.info(
        'AI chat request from $role $userId: ${message.substring(0, message.length > 50 ? 50 : message.length)}...',
      );

      // Process the chat message
      final result = await AiService.processChat(
        sessionId: sessionId,
        message: message,
        userId: userId,
        role: role,
        currentTab: currentTab,
      );

      if (result['success'] == true) {
        // HACK: Frontend expects 'message' or 'reply' key in 'data' map!
        final data = {
          'response': result['response'],
          'message':
              result['response'] ?? result['message'], // Frontend fallback
          'reply': result['response'] ?? result['reply'], // Frontend fallback
          'action': result['action'], // Pass action to frontend
          'session_id': result['session_id'],
          'provider': result['provider'],
        };

        return ApiResponse.success(
          data: data,
          message: 'AI response generated.',
        ).toShelfResponse();
      } else {
        return ApiResponse.error(
          code: 'AI_ERROR',
          message: result['error'] ?? 'Failed to generate AI response.',
        ).toShelfResponse(statusCode: 500);
      }
    } catch (e, stackTrace) {
      _logger.error('AI chat error: $e', e, stackTrace);
      return ApiResponse.error(
        code: 'INTERNAL_ERROR',
        message: 'An error occurred: $e',
      ).toShelfResponse(statusCode: 500);
    }
  }

  /// GET /api/ai/status
  Future<Response> _status(Request request) async {
    try {
      final status = AiService.getStatus();
      return ApiResponse.success(
        data: status,
        message: 'AI service status.',
      ).toShelfResponse();
    } catch (e) {
      return ApiResponse.error(
        code: 'INTERNAL_ERROR',
        message: 'Failed to get AI status: $e',
      ).toShelfResponse(statusCode: 500);
    }
  }

  /// GET /api/ai/history/<sessionId>
  Future<Response> _getHistory(Request request, String sessionId) async {
    try {
      final history = AiService.getHistory(sessionId);
      return ApiResponse.success(
        data: {'history': history, 'session_id': sessionId},
        message: 'Chat history retrieved.',
      ).toShelfResponse();
    } catch (e) {
      return ApiResponse.error(
        code: 'INTERNAL_ERROR',
        message: 'Failed to get history: $e',
      ).toShelfResponse(statusCode: 500);
    }
  }

  /// DELETE /api/ai/session/<sessionId>
  Future<Response> _clearSession(Request request, String sessionId) async {
    try {
      AiService.clearSession(sessionId);
      return ApiResponse.success(
        message: 'Chat session cleared.',
      ).toShelfResponse();
    } catch (e) {
      return ApiResponse.error(
        code: 'INTERNAL_ERROR',
        message: 'Failed to clear session: $e',
      ).toShelfResponse(statusCode: 500);
    }
  }
}
