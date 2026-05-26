import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../data/repositories/chat_repository.dart';
import '../services/auth_service.dart';
import '../services/chat_websocket_handler.dart';
import '../core/response/api_response.dart';
import '../core/exceptions/app_exception.dart';
import '../core/utils/logger.dart';
import '../services/unified_notification_service.dart';

/// Routes for TeamSync chat functionality
class ChatRoutes {
  final ChatRepository _chatRepository = ChatRepository();
  final AuthService _authService = AuthService();
  final ChatWebSocketHandler _wsHandler = ChatWebSocketHandler();
  final AppLogger _logger = AppLogger('ChatRoutes');

  Router get router {
    final router = Router();

    // WebSocket endpoint for real-time chat
    router.get('/chat/ws', _handleWebSocket);

    // REST API endpoints

    // Conversations
    router.get('/chat/conversations', handleGetConversations);
    router.post('/chat/conversations', handleCreateConversation);
    router.get('/chat/conversations/<conversationId>', handleGetConversation);
    router.get(
      '/chat/conversations/<conversationId>/participants',
      handleGetParticipants,
    );
    router.post(
      '/chat/conversations/<conversationId>/participants',
      handleAddMembers,
    );
    router.delete(
      '/chat/conversations/<conversationId>/participants/<userId>/<userType>',
      handleRemoveMember,
    );
    router.delete('/chat/conversations/<conversationId>', handleDeleteConversation);

    // Public Groups
    router.get('/chat/groups/public', handleGetPublicGroups);
    router.post('/chat/groups/join', handleJoinGroup);

    // Messages
    router.get(
      '/chat/conversations/<conversationId>/messages',
      handleGetMessages,
    );
    router.post('/chat/messages', handleSendMessage);
    router.put('/chat/messages/<messageId>', handleUpdateMessage);
    router.delete('/chat/messages/<messageId>', handleDeleteMessage);
    router.put('/chat/messages/<messageId>/read', handleMarkAsRead);
    router.put(
      '/chat/conversations/<conversationId>/read',
      handleMarkConversationAsRead,
    );

    // Reactions
    router.post('/chat/messages/<messageId>/reactions', handleAddReaction);
    router.delete('/chat/messages/<messageId>/reactions', handleRemoveReaction);

    // Pin & Star
    router.put(
      '/chat/conversations/<conversationId>/pin/<messageId>',
      handlePinMessage,
    );
    router.delete(
      '/chat/conversations/<conversationId>/pin',
      handleUnpinMessage,
    );
    router.post('/chat/messages/<messageId>/star', handleStarMessage);
    router.delete('/chat/messages/<messageId>/star', handleUnstarMessage);

    // Users
    router.get('/chat/users', handleGetChatUsers);

    // Presence
    router.get('/chat/presence', handleGetOnlineUsers);

    // Theme
    router.put(
      '/chat/conversations/<conversationId>/theme',
      handleUpdateConversationTheme,
    );

    return router;
  }

  // ============================================
  // WEBSOCKET
  // ============================================

  /// Handle WebSocket connection
  /// Token should be passed as query parameter: /chat/ws?token=<jwt_token>
  Handler get _handleWebSocket => (Request request) {
    // Extract token from query parameter
    final token = request.url.queryParameters['token'];
    // _logger.info(
    //   '[ChatRoutes] WebSocket connection request received, token present: ${token != null && token.isNotEmpty}',
    // );

    // Create WebSocket handler with the token
    // Note: The callback in webSocketHandler should set up stream listeners
    // but doesn't need to await the entire connection lifecycle
    // IMPORTANT: Do NOT use pingInterval here - we handle application-level pings ourselves
    // The built-in protocol-level ping can conflict with browsers that don't respond to ping frames
    final handler = webSocketHandler((
      WebSocketChannel channel,
      String? protocol,
    ) {
      // _logger.debug(
      //   '[ChatRoutes] WebSocket channel created, delegating to handler',
      // );
      // Fire and forget - the handleConnection sets up stream listeners
      // which will keep the connection alive
      _wsHandler.handleConnection(channel, token).catchError((e) {
        _logger.error('[ChatRoutes] Error in handleConnection: $e');
      });
    });

    return handler(request);
  };

  // ============================================
  // CONVERSATIONS
  // ============================================

  /// GET /api/chat/conversations - Get all conversations for authenticated user
  Future<Response> handleGetConversations(Request request) async {
    try {
      final user = await _authenticateRequest(request);
      if (user == null) {
        return ApiResponse.error(
          code: 'UNAUTHORIZED',
          message: 'Authentication required',
        ).toShelfResponse(statusCode: 401);
      }

      final conversations = await _chatRepository.getConversationsForUser(
        user['userId']!,
        user['userType']!,
      );

      // Enrich with other participant info for direct chats
      final enrichedConversations = <Map<String, dynamic>>[];
      for (final conv in conversations) {
        final enriched = Map<String, dynamic>.from(conv);

        if (conv['type'] == 'direct') {
          // Get the other participant
          final participants = await _chatRepository.getParticipants(
            conv['id'].toString(),
          );
          final otherParticipant = participants.firstWhere(
            (p) =>
                p['user_id'] != user['userId'] ||
                p['user_type'] != user['userType'],
            orElse: () => {},
          );

          if (otherParticipant.isNotEmpty) {
            enriched['display_name'] = otherParticipant['user_name'];
            enriched['display_image'] = otherParticipant['user_image'];
            enriched['other_user_id'] = otherParticipant['user_id'];
            enriched['other_user_type'] = otherParticipant['user_type'];
            // Use live WebSocket connection check instead of potentially stale DB value
            final otherUserId = otherParticipant['user_id']?.toString() ?? '';
            final otherUserType =
                otherParticipant['user_type']?.toString() ?? '';
            final isLiveOnline = _wsHandler.isUserOnline(
              otherUserId,
              otherUserType,
            );
            enriched['other_user_online'] = isLiveOnline;
            enriched['other_user_status'] =
                otherParticipant['status'] ??
                (isLiveOnline ? 'active' : 'offline');
            enriched['other_user_designation'] =
                otherParticipant['user_designation'];
            enriched['other_user_last_seen'] = otherParticipant['last_seen_at'];
          } else {
            // Self-chat scenario - user is chatting with themselves
            // Find the participant with the same user ID (self)
            final selfParticipant = participants.firstWhere(
              (p) =>
                  p['user_id'] == user['userId'] &&
                  p['user_type'] == user['userType'],
              orElse: () => {},
            );
            if (selfParticipant.isNotEmpty) {
              enriched['display_name'] = selfParticipant['user_name'];
              enriched['display_image'] = selfParticipant['user_image'];
              enriched['other_user_id'] = selfParticipant['user_id'];
              enriched['other_user_type'] = selfParticipant['user_type'];
              enriched['other_user_online'] = true; // Self is always online
              enriched['other_user_status'] = 'Active'; // Self is active
              enriched['other_user_designation'] =
                  selfParticipant['user_designation'];
              enriched['other_user_last_seen'] =
                  null; // Self doesn't need last seen
            }
          }
        }

        enrichedConversations.add(enriched);
      }

      return ApiResponse.success(
        data: enrichedConversations,
        message: 'Conversations retrieved successfully',
      ).toShelfResponse();
    } on AppException catch (e) {
      return ApiResponse.error(
        code: e.code,
        message: e.message,
      ).toShelfResponse(statusCode: 400);
    } catch (e, stackTrace) {
      _logger.error('Error getting conversations: $e', e, stackTrace);
      return ApiResponse.error(
        code: 'INTERNAL_ERROR',
        message: 'Failed to retrieve conversations',
      ).toShelfResponse(statusCode: 500);
    }
  }

  /// POST /api/chat/conversations - Create a new conversation
  Future<Response> handleCreateConversation(Request request) async {
    try {
      final user = await _authenticateRequest(request);
      if (user == null) {
        return ApiResponse.error(
          code: 'UNAUTHORIZED',
          message: 'Authentication required',
        ).toShelfResponse(statusCode: 401);
      }

      final body = await request.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;

      final type = data['type'] as String? ?? 'direct';
      final name = data['name'] as String?;
      final description = data['description'] as String?;
      final avatarUrl = data['avatarUrl'] as String?;
      final participantsData = data['participants'] as List<dynamic>?;

      if (participantsData == null || participantsData.isEmpty) {
        return ApiResponse.error(
          code: 'VALIDATION_ERROR',
          message: 'At least one participant is required',
        ).toShelfResponse(statusCode: 400);
      }

      final participants = participantsData
          .map(
            (p) => {
              'userId': p['userId'] as String,
              'userType': p['userType'] as String,
            },
          )
          .toList();

      // For direct chat, check if conversation already exists
      if (type == 'direct' && participants.length == 1) {
        final existingConv = await _chatRepository.findDirectConversation(
          user['userId']!,
          user['userType']!,
          participants[0]['userId']!,
          participants[0]['userType']!,
        );

        if (existingConv != null) {
          final fullConv = await _chatRepository.getConversationById(
            existingConv['id'].toString(),
          );
          return ApiResponse.success(
            data: fullConv,
            message: 'Existing conversation retrieved',
          ).toShelfResponse();
        }
      }

      // Validate group chat requirements
      if (type == 'group' && (name == null || name.isEmpty)) {
        return ApiResponse.error(
          code: 'VALIDATION_ERROR',
          message: 'Group name is required',
        ).toShelfResponse(statusCode: 400);
      }

      // Get isPublic for group
      final isPublic = data['isPublic'] as bool? ?? false;

      final conversation = await _chatRepository.createConversation(
        createdBy: user['userId']!,
        createdByType: user['userType']!,
        type: type,
        name: name,
        description: description,
        avatarUrl: avatarUrl,
        participants: participants,
        isPublic: isPublic,
      );

      return ApiResponse.success(
        data: conversation,
        message: 'Conversation created successfully',
      ).toShelfResponse();
    } on AppException catch (e) {
      return ApiResponse.error(
        code: e.code,
        message: e.message,
      ).toShelfResponse(statusCode: 400);
    } catch (e, stackTrace) {
      _logger.error('Error creating conversation: $e', e, stackTrace);
      return ApiResponse.error(
        code: 'INTERNAL_ERROR',
        message: 'Failed to create conversation',
      ).toShelfResponse(statusCode: 500);
    }
  }

  /// GET /api/chat/conversations/<conversationId> - Get conversation details
  Future<Response> handleGetConversation(
    Request request,
    String conversationId,
  ) async {
    try {
      final user = await _authenticateRequest(request);
      if (user == null) {
        return ApiResponse.error(
          code: 'UNAUTHORIZED',
          message: 'Authentication required',
        ).toShelfResponse(statusCode: 401);
      }

      final conversation = await _chatRepository.getConversationById(
        conversationId,
      );
      if (conversation == null) {
        return ApiResponse.error(
          code: 'NOT_FOUND',
          message: 'Conversation not found',
        ).toShelfResponse(statusCode: 404);
      }

      return ApiResponse.success(
        data: conversation,
        message: 'Conversation retrieved successfully',
      ).toShelfResponse();
    } catch (e, stackTrace) {
      _logger.error('Error getting conversation: $e', e, stackTrace);
      return ApiResponse.error(
        code: 'INTERNAL_ERROR',
        message: 'Failed to retrieve conversation',
      ).toShelfResponse(statusCode: 500);
    }
  }

  /// GET /api/chat/conversations/<conversationId>/participants
  Future<Response> handleGetParticipants(
    Request request,
    String conversationId,
  ) async {
    try {
      final user = await _authenticateRequest(request);
      if (user == null) {
        return ApiResponse.error(
          code: 'UNAUTHORIZED',
          message: 'Authentication required',
        ).toShelfResponse(statusCode: 401);
      }

      final participants = await _chatRepository.getParticipants(
        conversationId,
      );

      return ApiResponse.success(
        data: participants,
        message: 'Participants retrieved successfully',
      ).toShelfResponse();
    } catch (e, stackTrace) {
      _logger.error('Error getting participants: $e', e, stackTrace);
      return ApiResponse.error(
        code: 'INTERNAL_ERROR',
        message: 'Failed to retrieve participants',
      ).toShelfResponse(statusCode: 500);
    }
  }

  // ============================================
  // MESSAGES
  // ============================================

  /// GET /api/chat/conversations/<conversationId>/messages
  Future<Response> handleGetMessages(
    Request request,
    String conversationId,
  ) async {
    try {
      final user = await _authenticateRequest(request);
      if (user == null) {
        return ApiResponse.error(
          code: 'UNAUTHORIZED',
          message: 'Authentication required',
        ).toShelfResponse(statusCode: 401);
      }

      final params = request.url.queryParameters;
      final limit = int.tryParse(params['limit'] ?? '50') ?? 50;
      final beforeMessageId = params['before'];

      final messages = await _chatRepository.getMessages(
        conversationId,
        limit: limit,
        beforeMessageId: beforeMessageId,
        userId: user['userId']!,
        userType: user['userType']!,
      );

      return ApiResponse.success(
        data: messages,
        message: 'Messages retrieved successfully',
      ).toShelfResponse();
    } catch (e, stackTrace) {
      _logger.error('Error getting messages: $e', e, stackTrace);
      return ApiResponse.error(
        code: 'INTERNAL_ERROR',
        message: 'Failed to retrieve messages',
      ).toShelfResponse(statusCode: 500);
    }
  }

  /// POST /api/chat/messages - Send a message (for REST API fallback)
  Future<Response> handleSendMessage(Request request) async {
    try {
      final user = await _authenticateRequest(request);
      if (user == null) {
        return ApiResponse.error(
          code: 'UNAUTHORIZED',
          message: 'Authentication required',
        ).toShelfResponse(statusCode: 401);
      }

      final body = await request.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;

      final conversationId = data['conversationId'] as String?;
      final messageType = data['messageType'] as String? ?? 'text';
      final content = data['content'] as String?;
      final fileUrl = data['fileUrl'] as String?;
      final fileName = data['fileName'] as String?;
      final fileSize = data['fileSize'] as int?;
      final fileMimeType = data['fileMimeType'] as String?;
      final thumbnailUrl = data['thumbnailUrl'] as String?;
      final replyToId = data['replyToId'] as String?;
      final forwardedFromId = data['forwardedFromId'] as String?;
      final contactName = data['contactName'] as String?;
      final contactPhone = data['contactPhone'] as String?;
      final contactEmail = data['contactEmail'] as String?;

      if (conversationId == null) {
        return ApiResponse.error(
          code: 'VALIDATION_ERROR',
          message: 'conversationId is required',
        ).toShelfResponse(statusCode: 400);
      }

      if (messageType == 'text' && (content == null || content.isEmpty)) {
        return ApiResponse.error(
          code: 'VALIDATION_ERROR',
          message: 'Message content is required',
        ).toShelfResponse(statusCode: 400);
      }

      final message = await _chatRepository.sendMessage(
        conversationId: conversationId,
        senderId: user['userId']!,
        senderType: user['userType']!,
        messageType: messageType,
        content: content,
        fileUrl: fileUrl,
        fileName: fileName,
        fileSize: fileSize,
        fileMimeType: fileMimeType,
        thumbnailUrl: thumbnailUrl,
        replyToId: replyToId,
        forwardedFromId: forwardedFromId,
        contactName: contactName,
        contactPhone: contactPhone,
        contactEmail: contactEmail,
      );

      return ApiResponse.success(
        data: message,
        message: 'Message sent successfully',
      ).toShelfResponse();
    } on AppException catch (e) {
      return ApiResponse.error(
        code: e.code,
        message: e.message,
      ).toShelfResponse(statusCode: 400);
    } catch (e, stackTrace) {
      _logger.error('Error sending message: $e', e, stackTrace);
      return ApiResponse.error(
        code: 'INTERNAL_ERROR',
        message: 'Failed to send message',
      ).toShelfResponse(statusCode: 500);
    }
  }

  /// PUT /api/chat/messages/<messageId>/read
  Future<Response> handleMarkAsRead(Request request, String messageId) async {
    try {
      final user = await _authenticateRequest(request);
      if (user == null) {
        return ApiResponse.error(
          code: 'UNAUTHORIZED',
          message: 'Authentication required',
        ).toShelfResponse(statusCode: 401);
      }

      await _chatRepository.markAsRead(
        messageId,
        user['userId']!,
        user['userType']!,
      );

      return ApiResponse.success(
        message: 'Message marked as read',
      ).toShelfResponse();
    } catch (e, stackTrace) {
      _logger.error('Error marking as read: $e', e, stackTrace);
      return ApiResponse.error(
        code: 'INTERNAL_ERROR',
        message: 'Failed to mark message as read',
      ).toShelfResponse(statusCode: 500);
    }
  }

  /// PUT /api/chat/conversations/<conversationId>/read
  Future<Response> handleMarkConversationAsRead(
    Request request,
    String conversationId,
  ) async {
    try {
      final user = await _authenticateRequest(request);
      if (user == null) {
        return ApiResponse.error(
          code: 'UNAUTHORIZED',
          message: 'Authentication required',
        ).toShelfResponse(statusCode: 401);
      }

      await _chatRepository.markConversationAsRead(
        conversationId,
        user['userId']!,
        user['userType']!,
      );

      return ApiResponse.success(
        message: 'Conversation marked as read',
      ).toShelfResponse();
    } catch (e, stackTrace) {
      _logger.error('Error marking conversation as read: $e', e, stackTrace);
      return ApiResponse.error(
        code: 'INTERNAL_ERROR',
        message: 'Failed to mark conversation as read',
      ).toShelfResponse(statusCode: 500);
    }
  }

  /// PUT /api/chat/messages/<messageId> - Update a message
  Future<Response> handleUpdateMessage(
    Request request,
    String messageId,
  ) async {
    try {
      final user = await _authenticateRequest(request);
      if (user == null) {
        return ApiResponse.error(
          code: 'UNAUTHORIZED',
          message: 'Authentication required',
        ).toShelfResponse(statusCode: 401);
      }

      final body = await request.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;
      final content = data['content'] as String?;

      if (content == null || content.isEmpty) {
        return ApiResponse.error(
          code: 'VALIDATION_ERROR',
          message: 'Message content is required',
        ).toShelfResponse(statusCode: 400);
      }

      final updatedMessage = await _chatRepository.updateMessage(
        messageId: messageId,
        content: content,
        userId: user['userId']!,
        userType: user['userType']!,
      );

      // Broadcast update via WebSocket
      _wsHandler.broadcastToConversation(
        updatedMessage['conversation_id'],
        message: {
          'type': 'message_updated',
          'conversationId': updatedMessage['conversation_id'],
          'message': updatedMessage,
        },
      );

      return ApiResponse.success(
        data: updatedMessage,
        message: 'Message updated successfully',
      ).toShelfResponse();
    } on AppException catch (e) {
      return ApiResponse.error(
        code: e.code,
        message: e.message,
      ).toShelfResponse(statusCode: 400);
    } catch (e, stackTrace) {
      _logger.error('Error updating message: $e', e, stackTrace);
      return ApiResponse.error(
        code: 'INTERNAL_ERROR',
        message: 'Failed to update message',
      ).toShelfResponse(statusCode: 500);
    }
  }

  /// DELETE /api/chat/messages/<messageId>
  Future<Response> handleDeleteMessage(
    Request request,
    String messageId,
  ) async {
    try {
      final user = await _authenticateRequest(request);
      if (user == null) {
        return ApiResponse.error(
          code: 'UNAUTHORIZED',
          message: 'Authentication required',
        ).toShelfResponse(statusCode: 401);
      }

      final conversationId = await _chatRepository.deleteMessage(
        messageId: messageId,
        userId: user['userId']!,
        userType: user['userType']!,
      );

      // Broadcast update via WebSocket
      _wsHandler.broadcastToConversation(
        conversationId,
        message: {
          'type': 'message_deleted',
          'conversationId': conversationId,
          'messageId': messageId,
        },
      );

      return ApiResponse.success(
        data: null,
        message: 'Message deleted successfully',
      ).toShelfResponse();
    } on AppException catch (e) {
      return ApiResponse.error(
        code: e.code,
        message: e.message,
      ).toShelfResponse(statusCode: 400);
    } catch (e, stackTrace) {
      _logger.error('Error deleting message: $e', e, stackTrace);
      return ApiResponse.error(
        code: 'INTERNAL_ERROR',
        message: 'Failed to delete message',
      ).toShelfResponse(statusCode: 500);
    }
  }

  // ============================================
  // USERS
  // ============================================

  /// GET /api/chat/users - Get all users available for chat
  Future<Response> handleGetChatUsers(Request request) async {
    try {
      final user = await _authenticateRequest(request);
      if (user == null) {
        return ApiResponse.error(
          code: 'UNAUTHORIZED',
          message: 'Authentication required',
        ).toShelfResponse(statusCode: 401);
      }

      final users = await _chatRepository.getAllChatUsers(
        excludeUserId: user['userId'],
        excludeUserType: user['userType'],
      );

      // Override DB is_online with live WebSocket connection status
      final enrichedUsers = users.map((u) {
        final userId = u['user_id']?.toString() ?? '';
        final userType = u['user_type']?.toString() ?? '';
        final isLiveOnline = _wsHandler.isUserOnline(userId, userType);
        return {
          ...u,
          'is_online': isLiveOnline,
          'status': isLiveOnline ? (u['status'] ?? 'active') : 'offline',
        };
      }).toList();

      return ApiResponse.success(
        data: enrichedUsers,
        message: 'Users retrieved successfully',
      ).toShelfResponse();
    } catch (e, stackTrace) {
      _logger.error('Error getting chat users: $e', e, stackTrace);
      return ApiResponse.error(
        code: 'INTERNAL_ERROR',
        message: 'Failed to retrieve users',
      ).toShelfResponse(statusCode: 500);
    }
  }

  /// GET /api/chat/presence - Get online users
  Future<Response> handleGetOnlineUsers(Request request) async {
    try {
      final user = await _authenticateRequest(request);
      if (user == null) {
        return ApiResponse.error(
          code: 'UNAUTHORIZED',
          message: 'Authentication required',
        ).toShelfResponse(statusCode: 401);
      }

      // Get online users from WebSocket handler
      final onlineCount = _wsHandler.onlineUsersCount;

      return ApiResponse.success(
        data: {'onlineCount': onlineCount},
        message: 'Presence info retrieved successfully',
      ).toShelfResponse();
    } catch (e, stackTrace) {
      _logger.error('Error getting presence: $e', e, stackTrace);
      return ApiResponse.error(
        code: 'INTERNAL_ERROR',
        message: 'Failed to retrieve presence info',
      ).toShelfResponse(statusCode: 500);
    }
  }

  // ============================================
  // PUBLIC GROUPS
  // ============================================

  /// GET /api/chat/groups/public - Get public groups user can join
  Future<Response> handleGetPublicGroups(Request request) async {
    try {
      final user = await _authenticateRequest(request);
      if (user == null) {
        return ApiResponse.error(
          code: 'UNAUTHORIZED',
          message: 'Authentication required',
        ).toShelfResponse(statusCode: 401);
      }

      final groups = await _chatRepository.getPublicGroups(
        excludeUserId: user['userId'],
        excludeUserType: user['userType'],
      );

      return ApiResponse.success(
        data: groups,
        message: 'Public groups retrieved successfully',
      ).toShelfResponse();
    } catch (e, stackTrace) {
      _logger.error('Error getting public groups: $e', e, stackTrace);
      return ApiResponse.error(
        code: 'INTERNAL_ERROR',
        message: 'Failed to retrieve public groups',
      ).toShelfResponse(statusCode: 500);
    }
  }

  /// POST /api/chat/groups/join - Join a group via invite code
  Future<Response> handleJoinGroup(Request request) async {
    try {
      final user = await _authenticateRequest(request);
      if (user == null) {
        return ApiResponse.error(
          code: 'UNAUTHORIZED',
          message: 'Authentication required',
        ).toShelfResponse(statusCode: 401);
      }

      final body = await request.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;

      final inviteCode = data['inviteCode'] as String?;
      if (inviteCode == null || inviteCode.isEmpty) {
        return ApiResponse.error(
          code: 'VALIDATION_ERROR',
          message: 'Invite code is required',
        ).toShelfResponse(statusCode: 400);
      }

      final conversation = await _chatRepository.joinGroupByInviteCode(
        inviteCode: inviteCode,
        userId: user['userId']!,
        userType: user['userType']!,
      );

      return ApiResponse.success(
        data: conversation,
        message: 'Successfully joined group',
      ).toShelfResponse();
    } on AppException catch (e) {
      return ApiResponse.error(
        code: e.code,
        message: e.message,
      ).toShelfResponse(statusCode: 400);
    } catch (e, stackTrace) {
      _logger.error('Error joining group: $e', e, stackTrace);
      return ApiResponse.error(
        code: 'INTERNAL_ERROR',
        message: 'Failed to join group',
      ).toShelfResponse(statusCode: 500);
    }
  }

  // ============================================
  // REACTIONS, PIN, STAR
  // ============================================

  /// POST /api/chat/messages/<messageId>/reactions
  Future<Response> handleAddReaction(Request request, String messageId) async {
    try {
      final user = await _authenticateRequest(request);
      if (user == null) {
        return ApiResponse.error(
          code: 'UNAUTHORIZED',
          message: 'Authentication required',
        ).toShelfResponse(statusCode: 401);
      }

      final body = await request.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;
      final reaction = data['reaction'] as String? ?? '';

      if (reaction.isEmpty) {
        return ApiResponse.error(
          code: 'VALIDATION_ERROR',
          message: 'Reaction is required',
        ).toShelfResponse(statusCode: 400);
      }

      await _chatRepository.addReaction(
        messageId,
        user['userId']!,
        user['userType']!,
        reaction,
      );

      return ApiResponse.success(message: 'Reaction added').toShelfResponse();
    } catch (e, stackTrace) {
      _logger.error('Error adding reaction: $e', e, stackTrace);
      return ApiResponse.error(
        code: 'INTERNAL_ERROR',
        message: 'Failed to add reaction',
      ).toShelfResponse(statusCode: 500);
    }
  }

  /// DELETE /api/chat/messages/<messageId>/reactions
  Future<Response> handleRemoveReaction(
    Request request,
    String messageId,
  ) async {
    try {
      final user = await _authenticateRequest(request);
      if (user == null) {
        return ApiResponse.error(
          code: 'UNAUTHORIZED',
          message: 'Authentication required',
        ).toShelfResponse(statusCode: 401);
      }

      String reaction = '';
      try {
        final body = await request.readAsString();
        if (body.isNotEmpty) {
          final data = jsonDecode(body) as Map<String, dynamic>;
          reaction = data['reaction']?.toString() ?? '';
        }
      } catch (_) {}
      if (reaction.isEmpty) {
        final reactionParam = request.url.queryParameters['reaction'];
        reaction = reactionParam ?? '';
      }
      if (reaction.isEmpty) {
        return ApiResponse.error(
          code: 'VALIDATION_ERROR',
          message: 'Reaction is required (body or query param)',
        ).toShelfResponse(statusCode: 400);
      }

      await _chatRepository.removeReaction(
        messageId,
        user['userId']!,
        user['userType']!,
        reaction,
      );

      return ApiResponse.success(message: 'Reaction removed').toShelfResponse();
    } catch (e, stackTrace) {
      _logger.error('Error removing reaction: $e', e, stackTrace);
      return ApiResponse.error(
        code: 'INTERNAL_ERROR',
        message: 'Failed to remove reaction',
      ).toShelfResponse(statusCode: 500);
    }
  }

  /// PUT /api/chat/conversations/<conversationId>/pin/<messageId>
  Future<Response> handlePinMessage(
    Request request,
    String conversationId,
    String messageId,
  ) async {
    try {
      final user = await _authenticateRequest(request);
      if (user == null) {
        return ApiResponse.error(
          code: 'UNAUTHORIZED',
          message: 'Authentication required',
        ).toShelfResponse(statusCode: 401);
      }

      await _chatRepository.pinMessage(conversationId, messageId);

      return ApiResponse.success(message: 'Message pinned').toShelfResponse();
    } catch (e, stackTrace) {
      _logger.error('Error pinning message: $e', e, stackTrace);
      return ApiResponse.error(
        code: 'INTERNAL_ERROR',
        message: 'Failed to pin message',
      ).toShelfResponse(statusCode: 500);
    }
  }

  /// DELETE /api/chat/conversations/<conversationId>/pin
  Future<Response> handleUnpinMessage(
    Request request,
    String conversationId,
  ) async {
    try {
      final user = await _authenticateRequest(request);
      if (user == null) {
        return ApiResponse.error(
          code: 'UNAUTHORIZED',
          message: 'Authentication required',
        ).toShelfResponse(statusCode: 401);
      }

      await _chatRepository.unpinMessage(conversationId);

      return ApiResponse.success(message: 'Message unpinned').toShelfResponse();
    } catch (e, stackTrace) {
      _logger.error('Error unpinning message: $e', e, stackTrace);
      return ApiResponse.error(
        code: 'INTERNAL_ERROR',
        message: 'Failed to unpin message',
      ).toShelfResponse(statusCode: 500);
    }
  }

  /// POST /api/chat/messages/<messageId>/star
  Future<Response> handleStarMessage(Request request, String messageId) async {
    try {
      final user = await _authenticateRequest(request);
      if (user == null) {
        return ApiResponse.error(
          code: 'UNAUTHORIZED',
          message: 'Authentication required',
        ).toShelfResponse(statusCode: 401);
      }

      await _chatRepository.starMessage(
        messageId,
        user['userId']!,
        user['userType']!,
      );

      return ApiResponse.success(message: 'Message starred').toShelfResponse();
    } catch (e, stackTrace) {
      _logger.error('Error starring message: $e', e, stackTrace);
      return ApiResponse.error(
        code: 'INTERNAL_ERROR',
        message: 'Failed to star message',
      ).toShelfResponse(statusCode: 500);
    }
  }

  /// DELETE /api/chat/messages/<messageId>/star
  Future<Response> handleUnstarMessage(
    Request request,
    String messageId,
  ) async {
    try {
      final user = await _authenticateRequest(request);
      if (user == null) {
        return ApiResponse.error(
          code: 'UNAUTHORIZED',
          message: 'Authentication required',
        ).toShelfResponse(statusCode: 401);
      }

      await _chatRepository.unstarMessage(
        messageId,
        user['userId']!,
        user['userType']!,
      );

      return ApiResponse.success(
        message: 'Message unstarred',
      ).toShelfResponse();
    } catch (e, stackTrace) {
      _logger.error('Error unstarring message: $e', e, stackTrace);
      return ApiResponse.error(
        code: 'INTERNAL_ERROR',
        message: 'Failed to unstar message',
      ).toShelfResponse(statusCode: 500);
    }
  }

  // ============================================
  // THEME
  // ============================================

  /// PUT /api/chat/conversations/<conversationId>/theme - Update conversation theme
  Future<Response> handleUpdateConversationTheme(
    Request request,
    String conversationId,
  ) async {
    try {
      final user = await _authenticateRequest(request);
      if (user == null) {
        return ApiResponse.error(
          code: 'UNAUTHORIZED',
          message: 'Authentication required',
        ).toShelfResponse(statusCode: 401);
      }

      final bodyStr = await request.readAsString();
      final body = jsonDecode(bodyStr) as Map<String, dynamic>;
      final themeId = body['themeId'] as String?;

      if (themeId == null || themeId.isEmpty) {
        return ApiResponse.error(
          code: 'INVALID_REQUEST',
          message: 'themeId is required',
        ).toShelfResponse(statusCode: 400);
      }

      // Validate theme ID (optional - could add list of valid themes)
      final validThemes = [
        'default_blue',
        'midnight_purple',
        'ocean_teal',
        'sunset_orange',
        'forest_green',
      ];
      if (!validThemes.contains(themeId)) {
        return ApiResponse.error(
          code: 'INVALID_THEME',
          message: 'Invalid theme ID: $themeId',
        ).toShelfResponse(statusCode: 400);
      }

      final updated = await _chatRepository.updateConversationTheme(
        conversationId: conversationId,
        themeId: themeId,
      );

      if (!updated) {
        return ApiResponse.error(
          code: 'NOT_FOUND',
          message: 'Conversation not found',
        ).toShelfResponse(statusCode: 404);
      }

      _logger.info(
        'Theme updated for conversation $conversationId to $themeId by ${user['userType']}:${user['userId']}',
      );

      // Broadcast theme update via WebSocket
      _wsHandler.broadcastToConversation(
        conversationId,
        message: {
          'type': 'theme_updated',
          'conversationId': conversationId,
          'themeId': themeId,
        },
      );

      return ApiResponse.success(
        data: {'themeId': themeId},
        message: 'Theme updated successfully',
      ).toShelfResponse();
    } catch (e, stackTrace) {
      _logger.error('Error updating conversation theme: $e', e, stackTrace);
      return ApiResponse.error(
        code: 'INTERNAL_ERROR',
        message: 'Failed to update conversation theme',
      ).toShelfResponse(statusCode: 500);
    }
  }

  /// POST /chat/conversations/<conversationId>/participants - Add members to group
  Future<Response> handleAddMembers(
    Request request,
    String conversationId,
  ) async {
    try {
      final user = await _authenticateRequest(request);
      if (user == null) {
        return ApiResponse.error(
          code: 'UNAUTHORIZED',
          message: 'Authentication required',
        ).toShelfResponse(statusCode: 401);
      }

      final body = await request.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;
      final participantsData = data['participants'] as List<dynamic>?;

      if (participantsData == null || participantsData.isEmpty) {
        return ApiResponse.error(
          code: 'VALIDATION_ERROR',
          message: 'At least one participant is required',
        ).toShelfResponse(statusCode: 400);
      }

      final newlyAdded = <Map<String, dynamic>>[];
      for (final p in participantsData) {
        final userId = p['userId'] as String;
        final userType = p['userType'] as String;
        await _chatRepository.addParticipant(
          conversationId: conversationId,
          userId: userId,
          userType: userType,
        );
        newlyAdded.add({'userId': userId, 'userType': userType});
      }

      // Trigger notifications for group members if it's a group
      try {
        final conversation = await _chatRepository.getConversationById(conversationId);
        if (conversation != null && conversation['type'] == 'group') {
          final groupName = conversation['name'] ?? 'Group';
          final description = conversation['description'];
          final adderName = await _chatRepository.getUserName(
            user['userId']!,
            user['userType']!,
          );

          await UnifiedNotificationService.notifyGroupCreated(
            conversationId: conversationId,
            groupName: groupName,
            creatorName: adderName,
            description: description,
            participants: newlyAdded,
          );
        }
      } catch (e) {
        _logger.warning('Failed to trigger add member notifications: $e');
      }

      return ApiResponse.success(
        message: 'Members added successfully',
      ).toShelfResponse();
    } catch (e, stackTrace) {
      _logger.error('Error adding members: $e', e, stackTrace);
      return ApiResponse.error(
        code: 'INTERNAL_ERROR',
        message: 'Failed to add members',
      ).toShelfResponse(statusCode: 500);
    }
  }

  /// DELETE /chat/conversations/<conversationId>/participants/<userId>/<userType> - Remove member from group
  Future<Response> handleRemoveMember(
    Request request,
    String conversationId,
    String userId,
    String userType,
  ) async {
    try {
      final user = await _authenticateRequest(request);
      if (user == null) {
        return ApiResponse.error(
          code: 'UNAUTHORIZED',
          message: 'Authentication required',
        ).toShelfResponse(statusCode: 401);
      }

      // Fetch details before removal for notification
      try {
        final conversation = await _chatRepository.getConversationById(conversationId);
        if (conversation != null && conversation['type'] == 'group') {
          final groupName = conversation['name'] ?? 'Group';
          final removerName = await _chatRepository.getUserName(
            user['userId']!,
            user['userType']!,
          );

          // Add local notification for removed user
          await UnifiedNotificationService.notifyMemberRemoved(
            conversationId: conversationId,
            groupName: groupName,
            removerName: removerName,
            removedUserId: userId,
            removedUserType: userType,
          );
        }
      } catch (e) {
        _logger.warning('Failed to trigger removal notification: $e');
      }

      await _chatRepository.removeParticipant(
        conversationId: conversationId,
        userId: userId,
        userType: userType,
      );

      return ApiResponse.success(
        message: 'Member removed successfully',
      ).toShelfResponse();
    } catch (e, stackTrace) {
      _logger.error('Error removing member: $e', e, stackTrace);
      return ApiResponse.error(
        code: 'INTERNAL_ERROR',
        message: 'Failed to remove member',
      ).toShelfResponse(statusCode: 500);
    }
  }

  /// DELETE /chat/conversations/<conversationId> - Delete/Archive group
  Future<Response> handleDeleteConversation(
    Request request,
    String conversationId,
  ) async {
    try {
      final user = await _authenticateRequest(request);
      if (user == null) {
        return ApiResponse.error(
          code: 'UNAUTHORIZED',
          message: 'Authentication required',
        ).toShelfResponse(statusCode: 401);
      }

      await _chatRepository.deleteConversation(conversationId);

      return ApiResponse.success(
        message: 'Group deleted successfully',
      ).toShelfResponse();
    } catch (e, stackTrace) {
      _logger.error('Error deleting conversation: $e', e, stackTrace);
      return ApiResponse.error(
        code: 'INTERNAL_ERROR',
        message: 'Failed to delete group',
      ).toShelfResponse(statusCode: 500);
    }
  }

  // ============================================
  // HELPERS
  // ============================================

  /// Authenticate request and return user info
  Future<Map<String, String>?> _authenticateRequest(Request request) async {
    final authHeader = request.headers['authorization'];
    if (authHeader == null || !authHeader.startsWith('Bearer ')) {
      return null;
    }

    final token = authHeader.substring(7);
    final user = await _authService.verifyToken(token);
    if (user == null) {
      return null;
    }

    return {'userId': user.employeeId, 'userType': user.role};
  }
}
