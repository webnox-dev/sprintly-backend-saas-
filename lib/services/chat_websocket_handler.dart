import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../data/database/connection.dart';
import '../data/repositories/chat_repository.dart';
import '../data/repositories/fcm_token_repository.dart';
import '../data/repositories/notification_repository.dart';
import '../services/auth_service.dart';
import '../services/firebase_notification_service.dart';
import '../core/utils/logger.dart';

/// Connected client info
class ConnectedClient {
  final WebSocketChannel channel;
  final String userId;
  final String userType;
  final DateTime connectedAt;
  String? activeConversationId;

  ConnectedClient({
    required this.channel,
    required this.userId,
    required this.userType,
    required this.connectedAt,
    this.activeConversationId,
  });
}

/// WebSocket handler for real-time chat
class ChatWebSocketHandler {
  static final ChatWebSocketHandler _instance =
      ChatWebSocketHandler._internal();
  factory ChatWebSocketHandler() => _instance;
  ChatWebSocketHandler._internal();

  final AppLogger _logger = AppLogger('ChatWebSocketHandler');
  final ChatRepository _chatRepository = ChatRepository();
  final FcmTokenRepository _fcmTokenRepository = FcmTokenRepository();
  final NotificationRepository _notificationRepo = NotificationRepository();
  final AuthService _authService = AuthService();

  // Map of userId_userType -> ConnectedClient
  final Map<String, ConnectedClient> _clients = {};

  // Map of conversationId -> Set of client keys
  final Map<String, Set<String>> _conversationSubscriptions = {};

  /// Handle new WebSocket connection
  Future<void> handleConnection(WebSocketChannel channel, String? token) async {
    // _logger.info('[WS] handleConnection called - token present: ${token != null && token.isNotEmpty}');

    try {
      if (token == null || token.isEmpty) {
        _logger.warning('[WS] Connection rejected: No token provided');
        try {
          channel.sink.add(
            jsonEncode({'type': 'error', 'message': 'Authentication required'}),
          );
          await Future.delayed(const Duration(milliseconds: 100));
          await channel.sink.close();
        } catch (e) {
          _logger.error('[WS] Error closing channel (no token): $e');
        }
        return;
      }

      // Verify token
      // _logger.debug('[WS] Verifying token...');
      final user = await _authService.verifyToken(token);
      if (user == null) {
        _logger.warning(
          '[WS] Connection rejected: Invalid token or user not found',
        );
        try {
          channel.sink.add(
            jsonEncode({
              'type': 'error',
              'message': 'Invalid or expired token',
            }),
          );
          await Future.delayed(const Duration(milliseconds: 100));
          await channel.sink.close();
        } catch (e) {
          _logger.error('[WS] Error closing channel (invalid token): $e');
        }
        return;
      }

      // _logger.info('[WS] Token verified - User: ${user.employeeId}, Role: ${user.role}');

      final userId = user.employeeId;
      final userType = user.role;
      final clientKey = '${userId}_$userType';

      // Handle existing connection for this user - just remove from map, don't close
      // Closing triggers onDone on old connection which causes reconnect loops
      if (_clients.containsKey(clientKey)) {
        _logger.info(
          '[WS] Replacing existing connection for $clientKey (old connection will timeout)',
        );
        // Just remove from clients map - let the old connection die naturally
        _clients.remove(clientKey);
        // Remove from conversation subscriptions
        for (final subscriptions in _conversationSubscriptions.values) {
          subscriptions.remove(clientKey);
        }
        // No need to close the old channel - it will timeout on its own
      }

      // Register new connection
      final client = ConnectedClient(
        channel: channel,
        userId: userId,
        userType: userType,
        connectedAt: DateTime.now(),
      );
      _clients[clientKey] = client;

      _logger.info(
        '[WS] Client registered: $clientKey (${_clients.length} total connections)',
      );

      // Update presence to online (non-blocking)
      _updatePresenceAsync(userId, userType);

      // Send connection acknowledgment immediately
      try {
        final ackMessage = jsonEncode({
          'type': 'connected',
          'userId': userId,
          'userType': userType,
          'timestamp': DateTime.now().toIso8601String(),
        });
        channel.sink.add(ackMessage);
        // _logger.info('[WS] Sent connection acknowledgment to $clientKey');
      } catch (e) {
        _logger.error('[WS] Error sending connection ack: $e');
        // If we can't send the ack, the connection is likely broken
        _clients.remove(clientKey);
        return;
      }

      // Broadcast online status to others (non-blocking)
      _broadcastPresenceChangeAsync(userId, userType, true);

      // Listen for messages
      // _logger.debug('[WS] Setting up stream listener for $clientKey');
      channel.stream.listen(
        (data) {
          // _logger.debug('[WS] Received data from $clientKey: ${data.toString().substring(0, data.toString().length > 100 ? 100 : data.toString().length)}');
          _handleMessage(client, data);
        },
        onError: (error) {
          _logger.error('[WS] Stream error for $clientKey: $error');
          // Don't disconnect on stream error - let the onDone handle it
        },
        onDone: () {
          // _logger.info('[WS] Stream done for $clientKey - connection closed');
          _handleDisconnection(client, clientKey);
        },
        cancelOnError:
            false, // Don't cancel on error, let onDone handle cleanup
      );

      // _logger.info('[WS] Connection setup complete for $clientKey');
    } catch (e, stackTrace) {
      _logger.error('[WS] Error in handleConnection: $e', e, stackTrace);
      try {
        await channel.sink.close();
      } catch (_) {
        // Ignore close errors
      }
    }
  }

  /// Update presence asynchronously (non-blocking)
  void _updatePresenceAsync(String userId, String userType) {
    Future(() async {
      try {
        await _chatRepository.updateUserPresence(userId, userType, true);
        // _logger.debug('[WS] Presence updated for ${userId}_$userType');
      } catch (e) {
        _logger.error('[WS] Error updating presence: $e');
        // Non-blocking - presence update failure shouldn't affect connection
      }
    });
  }

  /// Broadcast presence change asynchronously (non-blocking)
  void _broadcastPresenceChangeAsync(
    String userId,
    String userType,
    bool isOnline,
  ) {
    Future(() {
      _broadcastPresenceChange(userId, userType, isOnline);
    });
  }

  /// Handle incoming WebSocket message
  Future<void> _handleMessage(ConnectedClient client, dynamic data) async {
    try {
      final message = jsonDecode(data as String) as Map<String, dynamic>;
      final type = message['type'] as String?;

      switch (type) {
        case 'send_message':
          await _handleSendMessage(client, message);
          break;
        case 'typing_start':
          await _handleTypingStart(client, message);
          break;
        case 'typing_stop':
          await _handleTypingStop(client);
          break;
        case 'message_delivered':
          await _handleMessageDelivered(client, message);
          break;
        case 'message_read':
          await _handleMessageRead(client, message);
          break;
        case 'conversation_read':
          await _handleConversationRead(client, message);
          break;
        case 'subscribe_conversation':
          await _handleSubscribeConversation(client, message);
          break;
        case 'unsubscribe_conversation':
          await _handleUnsubscribeConversation(client, message);
          break;
        case 'star_message':
          await _handleStarMessage(client, message);
          break;
        case 'unstar_message':
          await _handleUnstarMessage(client, message);
          break;
        case 'pin_message':
          await _handlePinMessage(client, message);
          break;
        case 'unpin_message':
          await _handleUnpinMessage(client, message);
          break;
        case 'edit_message':
          await _handleEditMessage(client, message);
          break;
        case 'update_presence':
          await _handleUpdatePresence(client, message);
          break;
        case 'chess_challenge':
          await _handleChessChallenge(client, message);
          break;
        case 'chess_challenge_accept':
          await _handleChessChallengeAccept(client, message);
          break;
        case 'chess_challenge_decline':
          await _handleChessChallengeDecline(client, message);
          break;
        case 'chess_move':
          await _handleChessMove(client, message);
          break;
        case 'chess_game_over':
          await _handleChessGameOver(client, message);
          break;
        case 'ping':
          client.channel.sink.add(jsonEncode({'type': 'pong'}));
          break;
        default:
          _logger.warning('Unknown message type: $type');
      }
    } catch (e, stackTrace) {
      _logger.error('Error handling message: $e', e, stackTrace);
      client.channel.sink.add(
        jsonEncode({
          'type': 'error',
          'message': 'Failed to process message: $e',
        }),
      );
    }
  }

  /// Handle send message
  Future<void> _handleSendMessage(
    ConnectedClient client,
    Map<String, dynamic> data,
  ) async {
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
    final tempId = data['tempId'] as String?; // Client-side temporary ID

    if (conversationId == null) {
      client.channel.sink.add(
        jsonEncode({'type': 'error', 'message': 'conversationId is required'}),
      );
      return;
    }

    // Save message to database
    final message = await _chatRepository.sendMessage(
      conversationId: conversationId,
      senderId: client.userId,
      senderType: client.userType,
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

    // Auto-clear typing status when message is sent
    if (client.activeConversationId == conversationId) {
      await _chatRepository.updateTypingStatus(
        client.userId,
        client.userType,
        null,
      );
      // Broadcast typing stop to other participants
      broadcastToConversation(
        conversationId,
        excludeClientKey: '${client.userId}_${client.userType}',
        message: {
          'type': 'typing',
          'userId': client.userId,
          'userType': client.userType,
          'conversationId': conversationId,
          'isTyping': false,
        },
      );
    }

    // Confirm message sent to sender FIRST (before any delivered status)
    client.channel.sink.add(
      jsonEncode({
        'type': 'message_sent',
        'tempId': tempId,
        'message': message,
      }),
    );

    // Get all participants
    final participants = await _chatRepository.getParticipants(conversationId);
    _logger.info(
      '[PUSH] Chat message sent in conversation $conversationId | Notifying ${participants.length} participant(s) (push + WS as applicable)',
    );

    // Collect delivered statuses to send AFTER all participants are notified
    final deliveredStatuses = <Map<String, dynamic>>[];

    // Send to online participants via WebSocket; always attempt push so user gets notification (e.g. on another device or when app in background)
    for (final participant in participants) {
      final participantId = participant['user_id'].toString();
      final participantType = participant['user_type'].toString();

      // Skip sender
      if (participantId == client.userId &&
          participantType == client.userType) {
        continue;
      }

      final participantKey = '${participantId}_$participantType';
      final participantClient = _clients[participantKey];
      final isSubscribed =
          _conversationSubscriptions[conversationId]?.contains(
            participantKey,
          ) ??
          false;

      if (participantClient != null) {
        // User is online - send via WebSocket
        participantClient.channel.sink.add(
          jsonEncode({
            'type': 'new_message',
            'message': message,
            'conversationId': conversationId,
          }),
        );

        await _chatRepository.markAsDelivered(
          message['id'].toString(),
          participantId,
          participantType,
        );

        // Queue delivered status to send back to sender AFTER message_sent
        deliveredStatuses.add({
          'type': 'message_status',
          'messageId': message['id'].toString(),
          'conversationId': conversationId,
          'userId': participantId,
          'userType': participantType,
          'status': 'delivered',
          'deliveredAt': DateTime.now().toIso8601String(),
        });
      }

      // Always send push notification so recipient gets it on other devices / when app in background
      _logger.info(
        '[PUSH] Chat push → $participantType:$participantId (online: ${participantClient != null}, subscribed: $isSubscribed)',
      );

      // Send Push Notification
      await _sendPushNotification(
        userId: participantId,
        userType: participantType,
        title: message['sender_name'] ?? 'New Message',
        body: _getNotificationBody(messageType, content, fileName),
        data: {
          'type': 'chat_message',
          'conversationId': conversationId,
          'messageId': message['id'].toString(),
          'senderId': client.userId,
          'senderType': client.userType,
        },
      );

      // Create Local App Notification (Database)
      // This ensures the notification appears in the notification center within the app
      try {
        await _notificationRepo.createNotification(
          userId: participantId,
          userType: participantType,
          title: message['sender_name'] ?? 'New Message',
          body: _getNotificationBody(messageType, content, fileName),
          notificationType: 'chat_message',
          relatedEntityType: 'conversation',
          relatedEntityId: conversationId,
          data: {
            'conversation_id': conversationId,
            'sender_id': client.userId,
            'sender_type': client.userType,
            'message_id': message['id'].toString(),
          },
          createdBy: client.userId,
        );
      } catch (e) {
        _logger.error('[WS] Error creating local notification for chat: $e');
      }
    }

    // Now send all delivered statuses to the sender
    // This ensures message_sent is always processed before message_status:delivered
    for (final deliveredStatus in deliveredStatuses) {
      client.channel.sink.add(jsonEncode(deliveredStatus));
    }
  }

  /// Handle typing start
  Future<void> _handleTypingStart(
    ConnectedClient client,
    Map<String, dynamic> data,
  ) async {
    final conversationId = data['conversationId'] as String?;
    if (conversationId == null) return;

    client.activeConversationId = conversationId;
    await _chatRepository.updateTypingStatus(
      client.userId,
      client.userType,
      conversationId,
    );

    // Broadcast to other participants
    broadcastToConversation(
      conversationId,
      excludeClientKey: '${client.userId}_${client.userType}',
      message: {
        'type': 'typing',
        'userId': client.userId,
        'userType': client.userType,
        'conversationId': conversationId,
        'isTyping': true,
      },
    );
  }

  /// Handle typing stop
  Future<void> _handleTypingStop(ConnectedClient client) async {
    final conversationId = client.activeConversationId;
    if (conversationId == null) return;

    await _chatRepository.updateTypingStatus(
      client.userId,
      client.userType,
      null,
    );

    // Broadcast to other participants
    broadcastToConversation(
      conversationId,
      excludeClientKey: '${client.userId}_${client.userType}',
      message: {
        'type': 'typing',
        'userId': client.userId,
        'userType': client.userType,
        'conversationId': conversationId,
        'isTyping': false,
      },
    );
  }

  /// Handle message delivered acknowledgment
  Future<void> _handleMessageDelivered(
    ConnectedClient client,
    Map<String, dynamic> data,
  ) async {
    final messageId = data['messageId'] as String?;
    if (messageId == null) return;

    await _chatRepository.markAsDelivered(
      messageId,
      client.userId,
      client.userType,
    );

    // Look up sender info and notify them directly
    final message = await DatabaseConnection.queryOne(
      '''
      SELECT sender_id, sender_type, conversation_id FROM chat_messages WHERE id = @messageId::uuid
    ''',
      values: {'messageId': messageId},
    );

    if (message != null) {
      _notifySenderOfStatus(
        messageId: messageId,
        conversationId: message['conversation_id'].toString(),
        senderId: message['sender_id'].toString(),
        senderType: message['sender_type'].toString(),
        readerId: client.userId,
        readerType: client.userType,
        status: 'delivered',
      );
    }
  }

  // ============================================
  // HELPER: Send status event directly to message sender
  // ============================================

  /// Send a message_status event directly to the original sender's WebSocket client.
  /// This bypasses broadcastToConversation (which only sends to subscribers)
  /// to ensure the sender always receives status updates in real-time.
  void _notifySenderOfStatus({
    required String messageId,
    required String conversationId,
    required String senderId,
    required String senderType,
    required String readerId,
    required String readerType,
    required String status,
  }) {
    final senderKey = '${senderId}_$senderType';
    final senderClient = _clients[senderKey];

    if (senderClient != null) {
      try {
        senderClient.channel.sink.add(
          jsonEncode({
            'type': 'message_status',
            'messageId': messageId,
            'conversationId': conversationId,
            'userId': readerId,
            'userType': readerType,
            'status': status,
            '${status}At': DateTime.now().toIso8601String(),
          }),
        );
      } catch (e) {
        _logger.error('Error sending status to sender $senderKey: $e');
      }
    }
  }

  /// Handle single message read acknowledgment
  Future<void> _handleMessageRead(
    ConnectedClient client,
    Map<String, dynamic> data,
  ) async {
    final messageId = data['messageId'] as String?;
    if (messageId == null) return;

    await _chatRepository.markAsRead(messageId, client.userId, client.userType);

    // Look up the original sender of this message
    final message = await DatabaseConnection.queryOne(
      '''
      SELECT sender_id, sender_type, conversation_id FROM chat_messages WHERE id = @messageId::uuid
    ''',
      values: {'messageId': messageId},
    );

    if (message != null) {
      final conversationId = message['conversation_id'].toString();
      final senderId = message['sender_id'].toString();
      final senderType = message['sender_type'].toString();

      // Send directly to the original sender (bypasses subscription check)
      _notifySenderOfStatus(
        messageId: messageId,
        conversationId: conversationId,
        senderId: senderId,
        senderType: senderType,
        readerId: client.userId,
        readerType: client.userType,
        status: 'read',
      );

      // Also broadcast to other conversation subscribers (for group chats)
      broadcastToConversation(
        conversationId,
        excludeClientKey: '${client.userId}_${client.userType}',
        message: {
          'type': 'message_status',
          'messageId': messageId,
          'conversationId': conversationId,
          'userId': client.userId,
          'userType': client.userType,
          'status': 'read',
          'readAt': DateTime.now().toIso8601String(),
        },
      );
    }
  }

  /// Handle mark entire conversation as read
  Future<void> _handleConversationRead(
    ConnectedClient client,
    Map<String, dynamic> data,
  ) async {
    final conversationId = data['conversationId'] as String?;
    if (conversationId == null) return;

    // markConversationAsRead now returns ONLY the rows that were actually updated
    // (via RETURNING clause), giving us exact message IDs + sender info.
    final updatedMessages = await _chatRepository.markConversationAsRead(
      conversationId,
      client.userId,
      client.userType,
    );

    _logger.info(
      '[WS] Conversation $conversationId read by ${client.userId}_${client.userType} | ${updatedMessages.length} messages updated',
    );

    // Broadcast the conversation_read event to conversation subscribers
    broadcastToConversation(
      conversationId,
      excludeClientKey: '${client.userId}_${client.userType}',
      message: {
        'type': 'conversation_read',
        'conversationId': conversationId,
        'userId': client.userId,
        'userType': client.userType,
        'readAt': DateTime.now().toIso8601String(),
      },
    );

    // Send individual message_status:read events DIRECTLY to each sender.
    // Uses the exact list of newly-read messages from the RETURNING clause —
    // no separate getMessages query, no 100-msg limit, no duplicates.
    for (final row in updatedMessages) {
      final messageId = row['message_id'].toString();
      final senderId = row['sender_id'].toString();
      final senderType = row['sender_type'].toString();

      // Skip if the sender is the reader (shouldn't happen, but defensive)
      if (senderId == client.userId && senderType == client.userType) {
        continue;
      }

      _notifySenderOfStatus(
        messageId: messageId,
        conversationId: conversationId,
        senderId: senderId,
        senderType: senderType,
        readerId: client.userId,
        readerType: client.userType,
        status: 'read',
      );
    }
  }

  /// Handle subscribe to conversation
  Future<void> _handleSubscribeConversation(
    ConnectedClient client,
    Map<String, dynamic> data,
  ) async {
    final conversationId = data['conversationId'] as String?;
    if (conversationId == null) return;

    final clientKey = '${client.userId}_${client.userType}';
    _conversationSubscriptions
        .putIfAbsent(conversationId, () => {})
        .add(clientKey);
    client.activeConversationId = conversationId;

    // Mark all messages as delivered
    final messages = await _chatRepository.getMessages(
      conversationId,
      limit: 100,
    );
    for (final message in messages) {
      if (message['sender_id'] != client.userId ||
          message['sender_type'] != client.userType) {
        final messageId = message['id'].toString();
        await _chatRepository.markAsDelivered(
          messageId,
          client.userId,
          client.userType,
        );

        // Notify sender that message was delivered (direct, bypasses subscription)
        _notifySenderOfStatus(
          messageId: messageId,
          conversationId: conversationId,
          senderId: message['sender_id'].toString(),
          senderType: message['sender_type'].toString(),
          readerId: client.userId,
          readerType: client.userType,
          status: 'delivered',
        );
      }
    }
  }

  /// Handle unsubscribe from conversation
  Future<void> _handleUnsubscribeConversation(
    ConnectedClient client,
    Map<String, dynamic> data,
  ) async {
    final conversationId = data['conversationId'] as String?;
    if (conversationId == null) return;

    final clientKey = '${client.userId}_${client.userType}';
    _conversationSubscriptions[conversationId]?.remove(clientKey);

    if (client.activeConversationId == conversationId) {
      client.activeConversationId = null;
      await _chatRepository.updateTypingStatus(
        client.userId,
        client.userType,
        null,
      );
    }
  }

  /// Handle star message - globally visible to all participants
  Future<void> _handleStarMessage(
    ConnectedClient client,
    Map<String, dynamic> data,
  ) async {
    final messageId = data['messageId'] as String?;
    final conversationId = data['conversationId'] as String?;
    if (messageId == null || conversationId == null) return;

    // Star the message in database
    await _chatRepository.starMessage(
      messageId,
      client.userId,
      client.userType,
    );

    // Broadcast to all participants in the conversation
    broadcastToConversation(
      conversationId,
      excludeClientKey: null, // Include sender so they get confirmation
      message: {
        'type': 'message_starred',
        'messageId': messageId,
        'conversationId': conversationId,
        'isStarred': true,
        'starredBy': {'userId': client.userId, 'userType': client.userType},
      },
    );
  }

  /// Handle unstar message - globally visible to all participants
  Future<void> _handleUnstarMessage(
    ConnectedClient client,
    Map<String, dynamic> data,
  ) async {
    final messageId = data['messageId'] as String?;
    final conversationId = data['conversationId'] as String?;
    if (messageId == null || conversationId == null) return;

    // Unstar the message in database
    await _chatRepository.unstarMessage(
      messageId,
      client.userId,
      client.userType,
    );

    // Broadcast to all participants in the conversation
    broadcastToConversation(
      conversationId,
      excludeClientKey: null, // Include sender so they get confirmation
      message: {
        'type': 'message_starred',
        'messageId': messageId,
        'conversationId': conversationId,
        'isStarred': false,
        'unstarredBy': {'userId': client.userId, 'userType': client.userType},
      },
    );
  }

  /// Handle pin message - globally visible to all participants
  Future<void> _handlePinMessage(
    ConnectedClient client,
    Map<String, dynamic> data,
  ) async {
    final messageId = data['messageId'] as String?;
    final conversationId = data['conversationId'] as String?;
    if (messageId == null || conversationId == null) return;

    // Pin the message in database
    await _chatRepository.pinMessage(conversationId, messageId);

    // Broadcast to all participants in the conversation
    broadcastToConversation(
      conversationId,
      excludeClientKey: null, // Include sender so they get confirmation
      message: {
        'type': 'message_pinned',
        'messageId': messageId,
        'conversationId': conversationId,
        'isPinned': true,
        'pinnedBy': {'userId': client.userId, 'userType': client.userType},
      },
    );
  }

  /// Handle message edit
  Future<void> _handleEditMessage(
    ConnectedClient client,
    Map<String, dynamic> data,
  ) async {
    final messageId = data['messageId'] as String?;
    final newContent = data['content'] as String?;
    final conversationId = data['conversationId'] as String?;

    if (messageId == null || newContent == null || conversationId == null) {
      client.channel.sink.add(
        jsonEncode({
          'type': 'error',
          'message': 'messageId, conversationId and content are required',
        }),
      );
      return;
    }

    try {
      final updatedMessage = await _chatRepository.updateMessage(
        messageId: messageId,
        userId: client.userId,
        userType: client.userType,
        content: newContent,
      );

      // Broadcast update to all participants (including sender for confirmation)
      broadcastToConversation(
        conversationId,
        excludeClientKey: null,
        message: {
          'type': 'message_updated',
          'conversationId': conversationId,
          'message': updatedMessage,
        },
      );
    } catch (e) {
      client.channel.sink.add(
        jsonEncode({'type': 'error', 'message': e.toString()}),
      );
    }
  }

  /// Handle update user presence / status
  Future<void> _handleUpdatePresence(
    ConnectedClient client,
    Map<String, dynamic> data,
  ) async {
    final status = data['status'] as String?;
    if (status == null) return;

    // Update presence in database
    await _chatRepository.updateUserPresence(
      client.userId,
      client.userType,
      true, // still online
      status: status,
    );

    // Broadcast presence change to all clients
    for (final connectedClient in _clients.values) {
      if (connectedClient.userId == client.userId &&
          connectedClient.userType == client.userType) {
        continue;
      }
      try {
        connectedClient.channel.sink.add(
          jsonEncode({
            'type': 'presence',
            'userId': client.userId,
            'userType': client.userType,
            'isOnline': true,
            'status': status,
            'lastSeenAt': DateTime.now().toIso8601String(),
          }),
        );
      } catch (e) {
        // ignore
      }
    }
  }

  /// Handle unpin message - globally visible to all participants
  Future<void> _handleUnpinMessage(
    ConnectedClient client,
    Map<String, dynamic> data,
  ) async {
    final messageId = data['messageId'] as String?;
    final conversationId = data['conversationId'] as String?;
    if (messageId == null || conversationId == null) return;

    // Unpin the message in database
    await _chatRepository.unpinMessage(conversationId, messageId: messageId);

    // Broadcast to all participants in the conversation
    broadcastToConversation(
      conversationId,
      excludeClientKey: null, // Include sender so they get confirmation
      message: {
        'type': 'message_pinned',
        'messageId': messageId,
        'conversationId': conversationId,
        'isPinned': false,
        'unpinnedBy': {'userId': client.userId, 'userType': client.userType},
      },
    );
  }

  Future<void> _handleDisconnection(
    ConnectedClient client,
    String clientKey,
  ) async {
    // Only clean up if this is the current active client for this key
    // This prevents a stale connection's onDone from marking a newly reconnected user as offline
    if (_clients[clientKey] != client) {
      _logger.info(
        '[WS] Stale connection closed for $clientKey (new connection already active)',
      );
      return;
    }

    _logger.info('[WS] Active connection closed for $clientKey');

    // Remove from clients
    _clients.remove(clientKey);

    // Remove from all conversation subscriptions
    for (final subscriptions in _conversationSubscriptions.values) {
      subscriptions.remove(clientKey);
    }

    // Update presence to offline
    try {
      await _chatRepository.updateUserPresence(
        client.userId,
        client.userType,
        false,
      );
    } catch (e) {
      _logger.error(
        '[WS] Error updating presence on disconnect for $clientKey: $e',
      );
    }

    try {
      await _chatRepository.updateTypingStatus(
        client.userId,
        client.userType,
        null,
      );
    } catch (e) {
      _logger.error(
        '[WS] Error updating typing status on disconnect for $clientKey: $e',
      );
    }

    // Broadcast offline status
    _broadcastPresenceChange(client.userId, client.userType, false);
  }

  /// Broadcast message to all participants in a conversation
  void broadcastToConversation(
    String conversationId, {
    String? excludeClientKey,
    required Map<String, dynamic> message,
  }) {
    final subscribers = _conversationSubscriptions[conversationId] ?? {};

    for (final clientKey in subscribers) {
      if (clientKey == excludeClientKey) continue;

      final client = _clients[clientKey];
      if (client != null) {
        try {
          client.channel.sink.add(jsonEncode(message));
        } catch (e) {
          _logger.error('Error broadcasting to $clientKey: $e');
        }
      }
    }
  }

  /// Broadcast presence change to all connected clients
  void _broadcastPresenceChange(String userId, String userType, bool isOnline) {
    final message = jsonEncode({
      'type': 'presence',
      'userId': userId,
      'userType': userType,
      'isOnline': isOnline,
      'lastSeenAt': DateTime.now().toIso8601String(),
    });

    for (final client in _clients.values) {
      if (client.userId == userId && client.userType == userType) continue;
      try {
        client.channel.sink.add(message);
      } catch (e) {
        // Ignore broadcast errors
      }
    }
  }

  /// Send push notification
  Future<void> _sendPushNotification({
    required String userId,
    required String userType,
    required String title,
    required String body,
    required Map<String, dynamic> data,
  }) async {
    _logger.info(
      '[PUSH] Attempting to send push notification to $userType: $userId',
    );
    _logger.debug('[PUSH] Title: $title, Body: $body');

    try {
      final tokens = await _fcmTokenRepository.getTokensForUser(
        userId,
        userType,
      );

      if (tokens.isEmpty) {
        _logger.warning(
          '[PUSH] No FCM tokens found for $userType: $userId - skipping push notification',
        );
        return;
      }

      _logger.info(
        '[PUSH] Found ${tokens.length} FCM token(s) for $userType: $userId - sending notifications',
      );

      for (final token in tokens) {
        try {
          // Convert dynamic data to String for FCM
          final stringData = data.map((k, v) => MapEntry(k, v.toString()));
          _logger.debug(
            '[PUSH] Sending to token: ${token.substring(0, 20)}...',
          );

          final success = await FirebaseNotificationService.sendToToken(
            token: token,
            title: title,
            body: body,
            data: stringData,
          );

          if (success) {
            _logger.info(
              '[PUSH] ✅ Push notification sent successfully to $userType: $userId',
            );
          } else {
            _logger.warning(
              '[PUSH] ⚠️ Push notification failed for $userType: $userId',
            );
          }
        } catch (e) {
          _logger.error('[PUSH] Error sending push notification to token: $e');
          // Continue with other tokens
        }
      }
    } catch (e, stackTrace) {
      _logger.error(
        '[PUSH] Error sending push notification: $e',
        e,
        stackTrace,
      );
    }
  }

  /// Get notification body based on message type
  String _getNotificationBody(
    String messageType,
    String? content,
    String? fileName,
  ) {
    switch (messageType) {
      case 'text':
        return content ?? 'New message';
      case 'image':
        return '📷 Image';
      case 'file':
      case 'document':
        return '📎 ${fileName ?? 'Document'}';
      case 'audio':
        return '🎵 Audio message';
      case 'video':
        return '🎥 Video';
      case 'contact':
        return '👤 Contact';
      default:
        return 'New message';
    }
  }

  /// Check if user is online
  bool isUserOnline(String userId, String userType) {
    return _clients.containsKey('${userId}_$userType');
  }

  /// Get online users count
  int get onlineUsersCount => _clients.length;

  ConnectedClient? _findClientByUserId(String userId) {
    for (final key in _clients.keys) {
      if (key.startsWith('${userId}_')) {
        return _clients[key];
      }
    }
    return null;
  }

  /// Handle chess challenge
  Future<void> _handleChessChallenge(
    ConnectedClient client,
    Map<String, dynamic> data,
  ) async {
    final targetId = data['targetId'] as String?;
    final challengerName = data['challengerName'] as String?;

    if (targetId == null) return;

    final targetClient = _findClientByUserId(targetId);
    if (targetClient != null) {
      targetClient.channel.sink.add(
        jsonEncode({
          'type': 'chess_challenge_received',
          'challengerId': client.userId,
          'challengerType': client.userType,
          'challengerName': challengerName ?? 'An employee',
        }),
      );
    }
  }

  /// Handle chess challenge acceptance
  Future<void> _handleChessChallengeAccept(
    ConnectedClient client,
    Map<String, dynamic> data,
  ) async {
    final challengerId = data['challengerId'] as String?;
    final challengerType = data['challengerType'] as String? ?? 'Employee';

    if (challengerId == null) return;

    final challengerKey = '${challengerId}_$challengerType';
    final challengerClient = _clients[challengerKey];

    if (challengerClient != null) {
      final gameId = '${challengerId}_${client.userId}';

      // Notify challenger (White)
      challengerClient.channel.sink.add(
        jsonEncode({
          'type': 'chess_game_started',
          'gameId': gameId,
          'opponentId': client.userId,
          'opponentType': client.userType,
          'color': 'white',
        }),
      );

      // Notify acceptor (Black)
      client.channel.sink.add(
        jsonEncode({
          'type': 'chess_game_started',
          'gameId': gameId,
          'opponentId': challengerId,
          'opponentType': challengerType,
          'color': 'black',
        }),
      );
    }
  }

  /// Handle chess challenge decline
  Future<void> _handleChessChallengeDecline(
    ConnectedClient client,
    Map<String, dynamic> data,
  ) async {
    final challengerId = data['challengerId'] as String?;
    if (challengerId == null) return;

    final challengerClient = _findClientByUserId(challengerId);
    if (challengerClient != null) {
      challengerClient.channel.sink.add(
        jsonEncode({
          'type': 'chess_challenge_declined',
          'opponentId': client.userId,
        }),
      );
    }
  }

  /// Handle chess move propagation
  Future<void> _handleChessMove(
    ConnectedClient client,
    Map<String, dynamic> data,
  ) async {
    final gameId = data['gameId'] as String?;
    final opponentId = data['opponentId'] as String?;
    final opponentType = data['opponentType'] as String? ?? 'Employee';
    final move = data['move'];

    if (opponentId == null || move == null) return;

    final opponentKey = '${opponentId}_$opponentType';
    final opponentClient = _clients[opponentKey];

    if (opponentClient != null) {
      opponentClient.channel.sink.add(
        jsonEncode({
          'type': 'chess_move_received',
          'gameId': gameId,
          'move': move,
        }),
      );
    }
  }

  /// Handle chess game over propagation
  Future<void> _handleChessGameOver(
    ConnectedClient client,
    Map<String, dynamic> data,
  ) async {
    final gameId = data['gameId'] as String?;
    final opponentId = data['opponentId'] as String?;
    final opponentType = data['opponentType'] as String? ?? 'Employee';
    final reason = data['reason'] as String? ?? 'resigned';

    if (opponentId == null) return;

    final opponentKey = '${opponentId}_$opponentType';
    final opponentClient = _clients[opponentKey];

    if (opponentClient != null) {
      opponentClient.channel.sink.add(
        jsonEncode({
          'type': 'chess_game_over_received',
          'gameId': gameId,
          'reason': reason,
        }),
      );
    }
  }
}
