import '../database/connection.dart';
import '../../core/utils/logger.dart';
import '../../core/exceptions/app_exception.dart';
import '../../services/unified_notification_service.dart';

/// Repository for chat operations
class ChatRepository {
  final AppLogger _logger = AppLogger('ChatRepository');

  // ============================================
  // CONVERSATIONS
  // ============================================

  /// Get all conversations for a user
  Future<List<Map<String, dynamic>>> getConversationsForUser(
    String userId,
    String userType,
  ) async {
    try {
      final sql = '''
        SELECT 
          c.id,
          c.name,
          c.description,
          c.type,
          c.avatar_url,
          c.created_by,
          c.created_by_type,
          c.is_active,
          c.last_message_at,
          c.created_at,
          c.updated_at,
          c.chat_theme_id,
          p.last_read_at,
          p.last_read_message_id,
          p.is_muted,
          (
            SELECT json_build_object(
              'id', m.id,
              'content', m.content,
              'message_type', m.message_type,
              'sender_id', m.sender_id,
              'sender_type', m.sender_type,
              'created_at', m.created_at
            )
            FROM chat_messages m
            WHERE m.conversation_id = c.id AND m.is_deleted = FALSE
            ORDER BY m.created_at DESC
            LIMIT 1
          ) as last_message,
          (
             SELECT json_agg(json_build_object(
              'user_id', p.user_id,
              'user_type', p.user_type,
              'role', p.role,
              'nickname', p.nickname,
              'user_name', CASE 
                WHEN LOWER(p.user_type) = 'admin' THEN (SELECT admin_name FROM admins WHERE admin_id = p.user_id)
                WHEN LOWER(p.user_type) = 'employee' THEN (SELECT employee_name FROM employees WHERE employee_id = p.user_id)
                ELSE 'Unknown'
              END,
              'user_image', CASE 
                WHEN LOWER(p.user_type) = 'admin' THEN (SELECT admin_img FROM admins WHERE admin_id = p.user_id)
                WHEN LOWER(p.user_type) = 'employee' THEN (SELECT employee_img FROM employees WHERE employee_id = p.user_id)
                ELSE NULL
              END,
              'is_muted', p.is_muted,
              'joined_at', p.joined_at,
              'is_active', p.is_active
            ))
            FROM chat_participants p
            WHERE p.conversation_id = c.id AND p.is_active = TRUE
          ) as participants,
          (
            SELECT COUNT(*)
            FROM chat_messages m2
            LEFT JOIN chat_message_status ms ON ms.message_id = m2.id 
              AND ms.user_id = @userId AND ms.user_type = @userType
            WHERE m2.conversation_id = c.id 
              AND m2.is_deleted = FALSE
              AND m2.sender_id != @userId
              AND (ms.status IS NULL OR ms.status != 'read')
          ) as unread_count
        FROM chat_conversations c
        INNER JOIN chat_participants p ON p.conversation_id = c.id
        WHERE p.user_id = @userId 
          AND p.user_type = @userType 
          AND p.is_active = TRUE
          AND c.is_active = TRUE
        ORDER BY c.last_message_at DESC NULLS LAST, c.created_at DESC
      ''';

      final result = await DatabaseConnection.query(
        sql,
        values: {'userId': userId, 'userType': userType},
      );

      return result.map((map) {
        return map.map((key, value) {
          if (value is DateTime) {
            return MapEntry(key, value.toIso8601String());
          }
          return MapEntry(key, value);
        });
      }).toList();
    } catch (e, stackTrace) {
      _logger.error('Error getting conversations: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Get conversation by ID with participants
  Future<Map<String, dynamic>?> getConversationById(
    String conversationId,
  ) async {
    try {
      final sql = '''
        SELECT 
          c.*,
          (
            SELECT json_agg(json_build_object(
              'user_id', p.user_id,
              'user_type', p.user_type,
              'role', p.role,
              'nickname', p.nickname,
              'user_name', CASE 
                WHEN LOWER(p.user_type) = 'admin' THEN (SELECT admin_name FROM admins WHERE admin_id = p.user_id)
                WHEN LOWER(p.user_type) = 'employee' THEN (SELECT employee_name FROM employees WHERE employee_id = p.user_id)
                ELSE 'Unknown'
              END,
              'user_image', CASE 
                WHEN LOWER(p.user_type) = 'admin' THEN (SELECT admin_img FROM admins WHERE admin_id = p.user_id)
                WHEN LOWER(p.user_type) = 'employee' THEN (SELECT employee_img FROM employees WHERE employee_id = p.user_id)
                ELSE NULL
              END,
              'is_muted', p.is_muted,
              'joined_at', p.joined_at,
              'is_active', p.is_active
            ))
            FROM chat_participants p
            WHERE p.conversation_id = c.id AND p.is_active = TRUE
          ) as participants
        FROM chat_conversations c
        WHERE c.id = @conversationId::uuid
      ''';

      final result = await DatabaseConnection.queryOne(
        sql,
        values: {'conversationId': conversationId},
      );

      if (result == null) return null;

      return result.map((key, value) {
        if (value is DateTime) {
          return MapEntry(key, value.toIso8601String());
        }
        return MapEntry(key, value);
      });
    } catch (e, stackTrace) {
      _logger.error('Error getting conversation: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Find existing direct conversation between two users
  Future<Map<String, dynamic>?> findDirectConversation(
    String userId1,
    String userType1,
    String userId2,
    String userType2,
  ) async {
    try {
      final sql = '''
        SELECT c.id
        FROM chat_conversations c
        WHERE c.type = 'direct' AND c.is_active = TRUE
        AND EXISTS (
          SELECT 1 FROM chat_participants p1
          WHERE p1.conversation_id = c.id 
            AND p1.user_id = @userId1 
            AND p1.user_type = @userType1
            AND p1.is_active = TRUE
        )
        AND EXISTS (
          SELECT 1 FROM chat_participants p2
          WHERE p2.conversation_id = c.id 
            AND p2.user_id = @userId2 
            AND p2.user_type = @userType2
            AND p2.is_active = TRUE
        )
        AND (SELECT COUNT(*) FROM chat_participants p WHERE p.conversation_id = c.id AND p.is_active = TRUE) = 2
        LIMIT 1
      ''';

      final result = await DatabaseConnection.queryOne(
        sql,
        values: {
          'userId1': userId1,
          'userType1': userType1,
          'userId2': userId2,
          'userType2': userType2,
        },
      );

      if (result == null) return null;

      return result.map((key, value) {
        if (value is DateTime) {
          return MapEntry(key, value.toIso8601String());
        }
        return MapEntry(key, value);
      });
    } catch (e, stackTrace) {
      _logger.error('Error finding direct conversation: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Create a new conversation
  Future<Map<String, dynamic>> createConversation({
    required String createdBy,
    required String createdByType,
    required String type,
    String? name,
    String? description,
    String? avatarUrl,
    required List<Map<String, String>> participants,
    bool isPublic = false,
  }) async {
    try {
      // Generate invite code for groups
      String? inviteCode;
      if (type == 'group') {
        inviteCode = _generateInviteCode();
      }

      // Create conversation
      final insertSql = '''
        INSERT INTO chat_conversations (
          name, description, type, avatar_url, created_by, created_by_type, is_public, invite_code
        ) VALUES (
          @name, @description, @type, @avatarUrl, @createdBy, @createdByType, @isPublic, @inviteCode
        )
        RETURNING *
      ''';

      final result = await DatabaseConnection.query(
        insertSql,
        values: {
          'name': name,
          'description': description,
          'type': type,
          'avatarUrl': avatarUrl,
          'createdBy': createdBy,
          'createdByType': createdByType,
          'isPublic': isPublic,
          'inviteCode': inviteCode,
        },
      );

      if (result.isEmpty) {
        throw AppException(
          code: 'CREATE_FAILED',
          message: 'Failed to create conversation',
        );
      }

      final conversation = result.first;
      final conversationId = conversation['id'].toString();

      // Add creator as participant
      await addParticipant(
        conversationId: conversationId,
        userId: createdBy,
        userType: createdByType,
        role: type == 'group' ? 'admin' : 'member',
      );

      // Add other participants
      for (final participant in participants) {
        final participantUserId = participant['userId']!;
        final participantUserType = participant['userType']!;

        // Skip if same as creator
        if (participantUserId == createdBy &&
            participantUserType == createdByType) {
          continue;
        }

        await addParticipant(
          conversationId: conversationId,
          userId: participantUserId,
          userType: participantUserType,
          role: 'member',
        );
      }
      final response = conversation.map((key, value) {
        if (value is DateTime) {
          return MapEntry(key, value.toIso8601String());
        }
        return MapEntry(key, value);
      });

      // Trigger notifications for groups
      if (type == 'group') {
        _triggerGroupNotifications(
          conversationId: conversationId,
          groupName: name ?? 'New Group',
          description: description,
          createdBy: createdBy,
          createdByType: createdByType,
          participants: participants,
        );
      }

      return response;
    } catch (e, stackTrace) {
      _logger.error('Error creating conversation: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Add participant to conversation
  Future<void> addParticipant({
    required String conversationId,
    required String userId,
    required String userType,
    String role = 'member',
  }) async {
    try {
      final sql = '''
        INSERT INTO chat_participants (
          conversation_id, user_id, user_type, role
        ) VALUES (
          @conversationId::uuid, @userId, @userType, @role
        )
        ON CONFLICT (conversation_id, user_id, user_type) 
        DO UPDATE SET is_active = TRUE, left_at = NULL
      ''';

      await DatabaseConnection.execute(
        sql,
        values: {
          'conversationId': conversationId,
          'userId': userId,
          'userType': userType,
          'role': role,
        },
      );
    } catch (e, stackTrace) {
      _logger.error('Error adding participant: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Remove participant from conversation
  Future<void> removeParticipant({
    required String conversationId,
    required String userId,
    required String userType,
  }) async {
    try {
      final sql = '''
        UPDATE chat_participants 
        SET is_active = FALSE, left_at = CURRENT_TIMESTAMP
        WHERE conversation_id = @conversationId::uuid 
          AND user_id = @userId 
          AND user_type = @userType
      ''';

      await DatabaseConnection.execute(
        sql,
        values: {
          'conversationId': conversationId,
          'userId': userId,
          'userType': userType,
        },
      );
    } catch (e, stackTrace) {
      _logger.error('Error removing participant: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Delete/Archive conversation
  Future<void> deleteConversation(String conversationId) async {
    try {
      final sql = '''
        UPDATE chat_conversations
        SET is_active = FALSE, updated_at = CURRENT_TIMESTAMP
        WHERE id = @conversationId::uuid
      ''';

      await DatabaseConnection.execute(
        sql,
        values: {'conversationId': conversationId},
      );
    } catch (e, stackTrace) {
      _logger.error('Error deleting conversation: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Get participants of a conversation
  Future<List<Map<String, dynamic>>> getParticipants(
    String conversationId,
  ) async {
    try {
      final sql = '''
        SELECT 
          p.*,
          CASE 
            WHEN LOWER(p.user_type) = 'admin' THEN (SELECT admin_name FROM admins WHERE admin_id = p.user_id)
            ELSE (SELECT employee_name FROM employees WHERE employee_id = p.user_id)
          END as user_name,
          CASE 
            WHEN LOWER(p.user_type) = 'admin' THEN (SELECT admin_img FROM admins WHERE admin_id = p.user_id)
            ELSE (SELECT employee_img FROM employees WHERE employee_id = p.user_id)
          END as user_image,
          CASE 
            WHEN LOWER(p.user_type) = 'admin' THEN (SELECT admin_designation FROM admins WHERE admin_id = p.user_id)
            ELSE (SELECT employee_designation FROM employees WHERE employee_id = p.user_id)
          END as user_designation,
          (
            SELECT is_online FROM chat_user_presence 
            WHERE user_id = p.user_id AND user_type = p.user_type
          ) as is_online,
          (
            SELECT status FROM chat_user_presence 
            WHERE user_id = p.user_id AND user_type = p.user_type
          ) as status,
          (
            SELECT last_seen_at FROM chat_user_presence 
            WHERE user_id = p.user_id AND user_type = p.user_type
          ) as last_seen_at
        FROM chat_participants p
        WHERE p.conversation_id = @conversationId::uuid AND p.is_active = TRUE
      ''';

      final results = await DatabaseConnection.query(
        sql,
        values: {'conversationId': conversationId},
      );

      return results.map((map) {
        return map.map((key, value) {
          if (value is DateTime) {
            return MapEntry(key, value.toIso8601String());
          }
          return MapEntry(key, value);
        });
      }).toList();
    } catch (e, stackTrace) {
      _logger.error('Error getting participants: $e', e, stackTrace);
      rethrow;
    }
  }

  // ============================================
  // MESSAGES
  // ============================================

  /// Get messages for a conversation with pagination
  Future<List<Map<String, dynamic>>> getMessages(
    String conversationId, {
    int limit = 50,
    String? beforeMessageId,
    String? userId,
    String? userType,
  }) async {
    try {
      String sql;
      Map<String, dynamic> values = {
        'conversationId': conversationId,
        'limit': limit,
      };

      if (beforeMessageId != null) {
        sql = '''
          SELECT 
            m.*,
            CASE 
              WHEN LOWER(m.sender_type) = 'admin' THEN (SELECT admin_name FROM admins WHERE admin_id = m.sender_id)
              ELSE (SELECT employee_name FROM employees WHERE employee_id = m.sender_id)
            END as sender_name,
            CASE 
              WHEN LOWER(m.sender_type) = 'admin' THEN (SELECT admin_img FROM admins WHERE admin_id = m.sender_id)
              ELSE (SELECT employee_img FROM employees WHERE employee_id = m.sender_id)
            END as sender_image,
            (
              SELECT json_agg(json_build_object(
                'user_id', s.user_id,
                'user_type', s.user_type,
                'status', s.status,
                'delivered_at', s.delivered_at,
                'read_at', s.read_at
              ))
              FROM chat_message_status s
              WHERE s.message_id = m.id
            ) as status_list,
            COALESCE((
              SELECT json_agg(json_build_object(
                'reaction', r.reaction,
                'user_id', r.user_id,
                'user_type', r.user_type
              ))
              FROM chat_message_reactions r
              WHERE r.message_id = m.id
            ), '[]'::json) as reactions
          FROM chat_messages m
          WHERE m.conversation_id = @conversationId::uuid 
            AND m.is_deleted = FALSE
            AND m.created_at < (SELECT created_at FROM chat_messages WHERE id = @beforeMessageId::uuid)
          ORDER BY m.created_at DESC
          LIMIT @limit
        ''';
        values['beforeMessageId'] = beforeMessageId;
      } else {
        sql = '''
          SELECT 
            m.*,
            CASE 
              WHEN LOWER(m.sender_type) = 'admin' THEN (SELECT admin_name FROM admins WHERE admin_id = m.sender_id)
              ELSE (SELECT employee_name FROM employees WHERE employee_id = m.sender_id)
            END as sender_name,
            CASE 
              WHEN LOWER(m.sender_type) = 'admin' THEN (SELECT admin_img FROM admins WHERE admin_id = m.sender_id)
              ELSE (SELECT employee_img FROM employees WHERE employee_id = m.sender_id)
            END as sender_image,
            (
              SELECT json_agg(json_build_object(
                'user_id', s.user_id,
                'user_type', s.user_type,
                'status', s.status,
                'delivered_at', s.delivered_at,
                'read_at', s.read_at
              ))
              FROM chat_message_status s
              WHERE s.message_id = m.id
            ) as status_list,
            COALESCE((
              SELECT json_agg(json_build_object(
                'reaction', r.reaction,
                'user_id', r.user_id,
                'user_type', r.user_type
              ))
              FROM chat_message_reactions r
              WHERE r.message_id = m.id
            ), '[]'::json) as reactions
          FROM chat_messages m
          WHERE m.conversation_id = @conversationId::uuid AND m.is_deleted = FALSE
          ORDER BY m.created_at DESC
          LIMIT @limit
        ''';
      }

      final results = await DatabaseConnection.query(sql, values: values);

      // Return in chronological order (oldest first) and sanitize DateTimes
      return results.reversed.map((map) {
        return map.map((key, value) {
          if (value is DateTime) {
            return MapEntry(key, value.toIso8601String());
          }
          return MapEntry(key, value);
        });
      }).toList();
    } catch (e, stackTrace) {
      _logger.error('Error getting messages: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Send a message
  Future<Map<String, dynamic>> sendMessage({
    required String conversationId,
    required String senderId,
    required String senderType,
    required String messageType,
    String? content,
    String? fileUrl,
    String? fileName,
    int? fileSize,
    String? fileMimeType,
    String? thumbnailUrl,
    String? replyToId,
    String? forwardedFromId,
    String? contactName,
    String? contactPhone,
    String? contactEmail,
  }) async {
    try {
      // Insert message
      final insertSql = '''
        INSERT INTO chat_messages (
          conversation_id, sender_id, sender_type, message_type, content,
          file_url, file_name, file_size, file_mime_type, thumbnail_url,
          reply_to_id, forwarded_from_id, contact_name, contact_phone, contact_email
        ) VALUES (
          @conversationId::uuid, @senderId, @senderType, @messageType, @content,
          @fileUrl, @fileName, @fileSize, @fileMimeType, @thumbnailUrl,
          @replyToId::uuid, @forwardedFromId::uuid, @contactName, @contactPhone, @contactEmail
        )
        RETURNING *
      ''';

      final result = await DatabaseConnection.query(
        insertSql,
        values: {
          'conversationId': conversationId,
          'senderId': senderId,
          'senderType': senderType,
          'messageType': messageType,
          'content': content,
          'fileUrl': fileUrl,
          'fileName': fileName,
          'fileSize': fileSize,
          'fileMimeType': fileMimeType,
          'thumbnailUrl': thumbnailUrl,
          'replyToId': replyToId,
          'forwardedFromId': forwardedFromId,
          'contactName': contactName,
          'contactPhone': contactPhone,
          'contactEmail': contactEmail,
        },
      );

      if (result.isEmpty) {
        throw AppException(
          code: 'SEND_FAILED',
          message: 'Failed to send message',
        );
      }

      final message = result.first;
      final messageId = message['id'].toString();

      // Update conversation last_message
      await DatabaseConnection.execute(
        '''
        UPDATE chat_conversations 
        SET last_message_id = @messageId::uuid, last_message_at = CURRENT_TIMESTAMP
        WHERE id = @conversationId::uuid
      ''',
        values: {'messageId': messageId, 'conversationId': conversationId},
      );

      // Create message status for all participants (except sender)
      final participants = await getParticipants(conversationId);
      for (final participant in participants) {
        final participantId = participant['user_id'].toString();
        final participantType = participant['user_type'].toString();

        if (participantId == senderId && participantType == senderType) {
          continue;
        }

        await DatabaseConnection.execute(
          '''
          INSERT INTO chat_message_status (message_id, user_id, user_type, status)
          VALUES (@messageId::uuid, @userId, @userType, 'sent')
          ON CONFLICT (message_id, user_id, user_type) DO NOTHING
        ''',
          values: {
            'messageId': messageId,
            'userId': participantId,
            'userType': participantType,
          },
        );
      }

      // Get sender info
      message['sender_name'] = await _getSenderName(senderId, senderType);
      message['sender_image'] = await _getSenderImage(senderId, senderType);

      return message.map((key, value) {
        if (value is DateTime) {
          return MapEntry(key, value.toIso8601String());
        }
        return MapEntry(key, value);
      });
    } catch (e, stackTrace) {
      _logger.error('Error sending message: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Update/Edit a message
  Future<Map<String, dynamic>> updateMessage({
    required String messageId,
    required String userId,
    required String userType,
    required String content,
  }) async {
    try {
      // 1. Fetch message to verify ownership and time
      final query = 'SELECT * FROM chat_messages WHERE id = @id::uuid';
      final result = await DatabaseConnection.query(
        query,
        values: {'id': messageId},
      );

      if (result.isEmpty) {
        throw AppException(code: 'NOT_FOUND', message: 'Message not found');
      }

      final message = result.first;

      // 2. Ownership check
      // Handle ID vs String comparison carefully
      if (message['sender_id'].toString() != userId ||
          message['sender_type'].toString().toLowerCase() !=
              userType.toLowerCase()) {
        throw AppException(
          code: 'FORBIDDEN',
          message: 'You can only edit your own messages',
        );
      }

      // 3. Time check (1 hour)
      final createdAt = message['created_at'] is DateTime
          ? message['created_at'] as DateTime
          : DateTime.parse(message['created_at'].toString());

      final now = DateTime.now().toUtc();
      final createdUtc = createdAt.toUtc();

      _logger.info(
        'Updating message $messageId. Created: $createdUtc, Now: $now, Diff hours: ${now.difference(createdUtc).inHours}',
      );

      if (now.difference(createdUtc).inHours >= 1) {
        throw AppException(
          code: 'TIME_LIMIT',
          message: 'Message can only be edited within 1 hour',
        );
      }

      // 4. Type check
      final msgType = message['message_type'].toString();
      if (msgType != 'text' && msgType != 'contact') {
        throw AppException(
          code: 'INVALID_TYPE',
          message: 'Only text and contact messages can be edited',
        );
      }

      // 5. Update
      final updateSql = '''
        UPDATE chat_messages 
        SET content = @content, is_edited = TRUE, edited_at = CURRENT_TIMESTAMP
        WHERE id = @id::uuid
      ''';

      await DatabaseConnection.query(
        updateSql,
        values: {'content': content, 'id': messageId},
      );

      // 6. Fetch full message details
      final fetchSql = '''
          SELECT 
            m.*,
            CASE 
              WHEN LOWER(m.sender_type) = 'admin' THEN (SELECT admin_name FROM admins WHERE admin_id = m.sender_id)
              ELSE (SELECT employee_name FROM employees WHERE employee_id = m.sender_id)
            END as sender_name,
            CASE 
              WHEN LOWER(m.sender_type) = 'admin' THEN (SELECT admin_img FROM admins WHERE admin_id = m.sender_id)
              ELSE (SELECT employee_img FROM employees WHERE employee_id = m.sender_id)
            END as sender_image,
            (
              SELECT json_agg(json_build_object(
                'user_id', s.user_id,
                'user_type', s.user_type,
                'status', s.status,
                'delivered_at', s.delivered_at,
                'read_at', s.read_at
              ))
              FROM chat_message_status s
              WHERE s.message_id = m.id
            ) as status_list,
            COALESCE((
              SELECT json_agg(json_build_object(
                'reaction', r.reaction,
                'user_id', r.user_id,
                'user_type', r.user_type
              ))
              FROM chat_message_reactions r
              WHERE r.message_id = m.id
            ), '[]'::json) as reactions
          FROM chat_messages m
          WHERE m.id = @id::uuid
      ''';

      final fetchResult = await DatabaseConnection.query(
        fetchSql,
        values: {'id': messageId},
      );

      if (fetchResult.isEmpty) {
        throw AppException(
          code: 'FETCH_FAILED',
          message: 'Failed to fetch updated message',
        );
      }

      final updatedMessage = fetchResult.first;

      return updatedMessage.map((key, value) {
        if (value is DateTime) {
          return MapEntry(key, value.toIso8601String());
        }
        return MapEntry(key, value);
      });
    } catch (e, stackTrace) {
      _logger.error('Error updating message: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Delete a message and return the conversation ID
  Future<String> deleteMessage({
    required String messageId,
    required String userId,
    required String userType,
  }) async {
    try {
      // 1. Fetch message to verify ownership
      final query = 'SELECT * FROM chat_messages WHERE id = @id::uuid';
      final result = await DatabaseConnection.query(
        query,
        values: {'id': messageId},
      );

      if (result.isEmpty) {
        throw AppException(code: 'NOT_FOUND', message: 'Message not found');
      }

      final message = result.first;

      // 2. Ownership check
      if (message['sender_id'].toString() != userId ||
          message['sender_type'].toString().toLowerCase() !=
              userType.toLowerCase()) {
        throw AppException(
          code: 'FORBIDDEN',
          message: 'You can only delete your own messages',
        );
      }

      // 3. Delete
      final updateSql = '''
        UPDATE chat_messages 
        SET is_deleted = TRUE 
        WHERE id = @id::uuid
      ''';

      await DatabaseConnection.query(updateSql, values: {'id': messageId});

      return message['conversation_id'].toString();
    } catch (e, stackTrace) {
      _logger.error('Error deleting message: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Update message status to delivered
  Future<void> markAsDelivered(
    String messageId,
    String userId,
    String userType,
  ) async {
    try {
      await DatabaseConnection.execute(
        '''
        UPDATE chat_message_status 
        SET status = 'delivered', delivered_at = CURRENT_TIMESTAMP
        WHERE message_id = @messageId::uuid 
          AND user_id = @userId 
          AND user_type = @userType
          AND status = 'sent'
      ''',
        values: {
          'messageId': messageId,
          'userId': userId,
          'userType': userType,
        },
      );
    } catch (e, stackTrace) {
      _logger.error('Error marking as delivered: $e', e, stackTrace);
    }
  }

  /// Update message status to read
  Future<void> markAsRead(
    String messageId,
    String userId,
    String userType,
  ) async {
    try {
      await DatabaseConnection.execute(
        '''
        UPDATE chat_message_status 
        SET status = 'read', read_at = CURRENT_TIMESTAMP,
            delivered_at = COALESCE(delivered_at, CURRENT_TIMESTAMP)
        WHERE message_id = @messageId::uuid 
          AND user_id = @userId 
          AND user_type = @userType
          AND status != 'read'
      ''',
        values: {
          'messageId': messageId,
          'userId': userId,
          'userType': userType,
        },
      );

      // Update participant's last_read
      final message = await DatabaseConnection.queryOne(
        '''
        SELECT conversation_id FROM chat_messages WHERE id = @messageId::uuid
      ''',
        values: {'messageId': messageId},
      );

      if (message != null) {
        await DatabaseConnection.execute(
          '''
          UPDATE chat_participants 
          SET last_read_at = CURRENT_TIMESTAMP, last_read_message_id = @messageId::uuid
          WHERE conversation_id = @conversationId::uuid 
            AND user_id = @userId 
            AND user_type = @userType
        ''',
          values: {
            'messageId': messageId,
            'conversationId': message['conversation_id'].toString(),
            'userId': userId,
            'userType': userType,
          },
        );
      }
    } catch (e, stackTrace) {
      _logger.error('Error marking as read: $e', e, stackTrace);
    }
  }

  /// Mark all messages in conversation as read and return updated message details.
  /// Returns list of maps with keys: message_id, sender_id, sender_type
  /// for each message whose status was actually changed from non-read to read.
  Future<List<Map<String, dynamic>>> markConversationAsRead(
    String conversationId,
    String userId,
    String userType,
  ) async {
    try {
      // Use RETURNING to get exact message IDs + sender info that were updated.
      // This avoids a separate getMessages query and only returns NEWLY read messages.
      final updatedRows = await DatabaseConnection.query(
        '''
        UPDATE chat_message_status ms
        SET status = 'read', read_at = CURRENT_TIMESTAMP,
            delivered_at = COALESCE(delivered_at, CURRENT_TIMESTAMP)
        FROM chat_messages m
        WHERE ms.message_id = m.id
          AND m.conversation_id = @conversationId::uuid
          AND ms.user_id = @userId 
          AND ms.user_type = @userType
          AND ms.status != 'read'
        RETURNING ms.message_id, m.sender_id, m.sender_type
      ''',
        values: {
          'conversationId': conversationId,
          'userId': userId,
          'userType': userType,
        },
      );

      _logger.info(
        '[ChatRepo] Marked ${updatedRows.length} messages as read in conversation $conversationId by ${userId}_$userType',
      );

      // Update participant's last_read with latest message
      final latestMessage = await DatabaseConnection.queryOne(
        '''
        SELECT id FROM chat_messages 
        WHERE conversation_id = @conversationId::uuid AND is_deleted = FALSE
        ORDER BY created_at DESC LIMIT 1
      ''',
        values: {'conversationId': conversationId},
      );

      if (latestMessage != null) {
        await DatabaseConnection.execute(
          '''
          UPDATE chat_participants 
          SET last_read_at = CURRENT_TIMESTAMP, last_read_message_id = @messageId::uuid
          WHERE conversation_id = @conversationId::uuid 
            AND user_id = @userId 
            AND user_type = @userType
        ''',
          values: {
            'messageId': latestMessage['id'].toString(),
            'conversationId': conversationId,
            'userId': userId,
            'userType': userType,
          },
        );
      }

      return updatedRows;
    } catch (e, stackTrace) {
      _logger.error('Error marking conversation as read: $e', e, stackTrace);
      return [];
    }
  }

  // ============================================
  // PRESENCE & TYPING
  // ============================================

  /// Update user online status
  Future<void> updateUserPresence(
    String userId,
    String userType,
    bool isOnline, {
    String? deviceInfo,
    String? status,
  }) async {
    try {
      await DatabaseConnection.execute(
        '''
        INSERT INTO chat_user_presence (user_id, user_type, is_online, last_seen_at, device_info, status)
        VALUES (@userId, @userType, @isOnline, CURRENT_TIMESTAMP, @deviceInfo, COALESCE(@status, CASE WHEN @isOnline THEN 'active' ELSE 'offline' END))
        ON CONFLICT (user_id, user_type) 
        DO UPDATE SET 
          is_online = @isOnline, 
          last_seen_at = CURRENT_TIMESTAMP,
          device_info = COALESCE(@deviceInfo, chat_user_presence.device_info),
          status = COALESCE(@status, chat_user_presence.status)
      ''',
        values: {
          'userId': userId,
          'userType': userType,
          'isOnline': isOnline,
          'deviceInfo': deviceInfo,
          'status': status,
        },
      );
    } catch (e, stackTrace) {
      _logger.error('Error updating presence: $e', e, stackTrace);
    }
  }

  /// Update typing status
  Future<void> updateTypingStatus(
    String userId,
    String userType,
    String? conversationId,
  ) async {
    try {
      await DatabaseConnection.execute(
        '''
        UPDATE chat_user_presence 
        SET is_typing_in = @conversationId::uuid,
            typing_started_at = CASE WHEN @conversationId IS NOT NULL THEN CURRENT_TIMESTAMP ELSE NULL END
        WHERE user_id = @userId AND user_type = @userType
      ''',
        values: {
          'userId': userId,
          'userType': userType,
          'conversationId': conversationId,
        },
      );
    } catch (e, stackTrace) {
      _logger.error('Error updating typing status: $e', e, stackTrace);
    }
  }

  /// Get typing users in a conversation
  Future<List<Map<String, dynamic>>> getTypingUsers(
    String conversationId,
  ) async {
    try {
      return await DatabaseConnection.query(
        '''
        SELECT 
          p.user_id, 
          p.user_type,
          CASE 
            WHEN LOWER(p.user_type) = 'admin' THEN (SELECT admin_name FROM admins WHERE admin_id = p.user_id)
            ELSE (SELECT employee_name FROM employees WHERE employee_id = p.user_id)
          END as user_name
        FROM chat_user_presence p
        WHERE p.is_typing_in = @conversationId::uuid
          AND p.typing_started_at > CURRENT_TIMESTAMP - INTERVAL '10 seconds'
      ''',
        values: {'conversationId': conversationId},
      );
    } catch (e, stackTrace) {
      _logger.error('Error getting typing users: $e', e, stackTrace);
      return [];
    }
  }

  // ============================================
  // USERS LIST
  // ============================================

  /// Get all chat users (admins + employees)
  Future<List<Map<String, dynamic>>> getAllChatUsers({
    String? excludeUserId,
    String? excludeUserType,
  }) async {
    try {
      final results = <Map<String, dynamic>>[];

      // Get admins
      String adminSql = '''
        SELECT 
          admin_id as user_id,
          'Admin' as user_type,
          admin_name as name,
          admin_img as image,
          admin_designation as designation,
          admin_role as role,
          (
            SELECT is_online FROM chat_user_presence 
            WHERE user_id = admin_id AND user_type = 'Admin'
          ) as is_online,
          (
            SELECT status FROM chat_user_presence 
            WHERE user_id = admin_id AND user_type = 'Admin'
          ) as status,
          (
            SELECT last_seen_at FROM chat_user_presence 
            WHERE user_id = admin_id AND user_type = 'Admin'
          ) as last_seen_at
        FROM admins
        WHERE status = 1 OR status IS NULL
      ''';

      if (excludeUserId != null && excludeUserType == 'Admin') {
        adminSql += " AND admin_id != @excludeUserId";
      }

      final admins = await DatabaseConnection.query(
        adminSql,
        values: excludeUserId != null && excludeUserType == 'Admin'
            ? {'excludeUserId': excludeUserId}
            : null,
      );
      results.addAll(admins);

      // Get employees
      String employeeSql = '''
        SELECT 
          employee_id as user_id,
          'Employee' as user_type,
          employee_name as name,
          employee_img as image,
          employee_designation as designation,
          employee_role as role,
          (
            SELECT is_online FROM chat_user_presence 
            WHERE user_id = employee_id AND user_type = 'Employee'
          ) as is_online,
          (
            SELECT status FROM chat_user_presence 
            WHERE user_id = employee_id AND user_type = 'Employee'
          ) as status,
          (
            SELECT last_seen_at FROM chat_user_presence 
            WHERE user_id = employee_id AND user_type = 'Employee'
          ) as last_seen_at
        FROM employees
        WHERE status = 1
      ''';

      if (excludeUserId != null && excludeUserType == 'Employee') {
        employeeSql += " AND employee_id != @excludeUserId";
      }

      final employees = await DatabaseConnection.query(
        employeeSql,
        values: excludeUserId != null && excludeUserType == 'Employee'
            ? {'excludeUserId': excludeUserId}
            : null,
      );
      results.addAll(employees);

      // Sort by name
      results.sort(
        (a, b) =>
            (a['name'] as String? ?? '').compareTo(b['name'] as String? ?? ''),
      );

      return results.map((map) {
        return map.map((key, value) {
          if (value is DateTime) {
            return MapEntry(key, value.toIso8601String());
          }
          return MapEntry(key, value);
        });
      }).toList();
    } catch (e, stackTrace) {
      _logger.error('Error getting chat users: $e', e, stackTrace);
      rethrow;
    }
  }

  // ============================================
  // HELPERS
  // ============================================

  Future<String?> _getSenderName(String senderId, String senderType) async {
    try {
      if (senderType.toLowerCase() == 'admin') {
        final result = await DatabaseConnection.queryOne(
          'SELECT admin_name FROM admins WHERE admin_id = @id',
          values: {'id': senderId},
        );
        return result?['admin_name'] as String?;
      } else {
        final result = await DatabaseConnection.queryOne(
          'SELECT employee_name FROM employees WHERE employee_id = @id',
          values: {'id': senderId},
        );
        return result?['employee_name'] as String?;
      }
    } catch (e) {
      return null;
    }
  }

  Future<String?> _getSenderImage(String senderId, String senderType) async {
    try {
      if (senderType.toLowerCase() == 'admin') {
        final result = await DatabaseConnection.queryOne(
          'SELECT admin_img FROM admins WHERE admin_id = @id',
          values: {'id': senderId},
        );
        return result?['admin_img'] as String?;
      } else {
        final result = await DatabaseConnection.queryOne(
          'SELECT employee_img FROM employees WHERE employee_id = @id',
          values: {'id': senderId},
        );
        return result?['employee_img'] as String?;
      }
    } catch (e) {
      return null;
    }
  }

  /// Generate a unique invite code for group
  String _generateInviteCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = DateTime.now().millisecondsSinceEpoch;
    final buffer = StringBuffer();
    for (var i = 0; i < 8; i++) {
      buffer.write(chars[(random + i * 7) % chars.length]);
    }
    return buffer.toString();
  }

  /// Get public groups that user can join
  Future<List<Map<String, dynamic>>> getPublicGroups({
    String? excludeUserId,
    String? excludeUserType,
  }) async {
    try {
      final sql = '''
        SELECT 
          c.id,
          c.name,
          c.description,
          c.type,
          c.avatar_url,
          c.is_public,
          c.invite_code,
          c.created_at,
          (SELECT COUNT(*) FROM chat_participants p WHERE p.conversation_id = c.id AND p.is_active = TRUE) as member_count
        FROM chat_conversations c
        WHERE c.type = 'group' 
          AND c.is_public = TRUE 
          AND c.is_active = TRUE
          AND NOT EXISTS (
            SELECT 1 FROM chat_participants p 
            WHERE p.conversation_id = c.id 
              AND p.user_id = @userId 
              AND p.user_type = @userType
              AND p.is_active = TRUE
          )
        ORDER BY c.created_at DESC
      ''';

      final result = await DatabaseConnection.query(
        sql,
        values: {
          'userId': excludeUserId ?? '',
          'userType': excludeUserType ?? '',
        },
      );

      return result.map((map) {
        return map.map((key, value) {
          if (value is DateTime) {
            return MapEntry(key, value.toIso8601String());
          }
          return MapEntry(key, value);
        });
      }).toList();
    } catch (e, stackTrace) {
      _logger.error('Error getting public groups: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Find a conversation by invite code
  Future<Map<String, dynamic>?> findByInviteCode(String inviteCode) async {
    try {
      final sql = '''
        SELECT 
          c.*,
          (SELECT COUNT(*) FROM chat_participants p WHERE p.conversation_id = c.id AND p.is_active = TRUE) as member_count
        FROM chat_conversations c
        WHERE c.invite_code = @inviteCode AND c.is_active = TRUE
      ''';

      final result = await DatabaseConnection.queryOne(
        sql,
        values: {'inviteCode': inviteCode},
      );

      if (result == null) return null;

      return result.map((key, value) {
        if (value is DateTime) {
          return MapEntry(key, value.toIso8601String());
        }
        return MapEntry(key, value);
      });
    } catch (e, stackTrace) {
      _logger.error('Error finding by invite code: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Join a group via invite code
  Future<Map<String, dynamic>?> joinGroupByInviteCode({
    required String inviteCode,
    required String userId,
    required String userType,
  }) async {
    try {
      // Find the group
      final group = await findByInviteCode(inviteCode);
      if (group == null) {
        throw AppException(
          code: 'NOT_FOUND',
          message: 'Group not found or invite link expired',
        );
      }

      // Check if already a member
      final existingParticipant = await DatabaseConnection.queryOne(
        '''
        SELECT * FROM chat_participants 
        WHERE conversation_id = @conversationId::uuid 
          AND user_id = @userId 
          AND user_type = @userType
      ''',
        values: {
          'conversationId': group['id'].toString(),
          'userId': userId,
          'userType': userType,
        },
      );

      if (existingParticipant != null &&
          existingParticipant['is_active'] == true) {
        throw AppException(
          code: 'ALREADY_MEMBER',
          message: 'You are already a member of this group',
        );
      }

      // Add as participant
      await addParticipant(
        conversationId: group['id'].toString(),
        userId: userId,
        userType: userType,
        role: 'member',
      );

      // Return full conversation
      return await getConversationById(group['id'].toString());
    } catch (e, stackTrace) {
      _logger.error('Error joining group: $e', e, stackTrace);
      rethrow;
    }
  }

  // ============================================
  // REACTIONS
  // ============================================

  /// Add reaction to message
  Future<void> addReaction(
    String messageId,
    String userId,
    String userType,
    String reaction,
  ) async {
    try {
      await DatabaseConnection.execute(
        '''
        INSERT INTO chat_message_reactions (message_id, user_id, user_type, reaction)
        VALUES (@messageId::uuid, @userId, @userType, @reaction)
        ON CONFLICT (message_id, user_id, user_type)
        DO UPDATE SET reaction = @reaction
        ''',
        values: {
          'messageId': messageId,
          'userId': userId,
          'userType': userType,
          'reaction': reaction,
        },
      );
    } catch (e, stackTrace) {
      _logger.error('Error adding reaction: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Remove reaction from message
  Future<void> removeReaction(
    String messageId,
    String userId,
    String userType,
    String reaction,
  ) async {
    try {
      await DatabaseConnection.execute(
        '''
        DELETE FROM chat_message_reactions
        WHERE message_id = @messageId::uuid
          AND user_id = @userId
          AND user_type = @userType
          AND reaction = @reaction
        ''',
        values: {
          'messageId': messageId,
          'userId': userId,
          'userType': userType,
          'reaction': reaction,
        },
      );
    } catch (e, stackTrace) {
      _logger.error('Error removing reaction: $e', e, stackTrace);
      rethrow;
    }
  }

  // ============================================
  // PIN & STAR
  // ============================================

  /// Pin message globally (visible to all participants)
  Future<void> pinMessage(String conversationId, String messageId) async {
    try {
      // Update is_pinned on the message directly for global visibility
      await DatabaseConnection.execute(
        '''
        UPDATE chat_messages
        SET is_pinned = TRUE
        WHERE id = @messageId::uuid AND conversation_id = @conversationId::uuid
        ''',
        values: {'conversationId': conversationId, 'messageId': messageId},
      );
    } catch (e, stackTrace) {
      _logger.error('Error pinning message: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Unpin message globally
  Future<void> unpinMessage(String conversationId, {String? messageId}) async {
    try {
      if (messageId != null) {
        // Unpin specific message
        await DatabaseConnection.execute(
          '''
          UPDATE chat_messages
          SET is_pinned = FALSE
          WHERE id = @messageId::uuid AND conversation_id = @conversationId::uuid
          ''',
          values: {'conversationId': conversationId, 'messageId': messageId},
        );
      } else {
        // Unpin all messages in conversation (legacy behavior)
        await DatabaseConnection.execute(
          '''
          UPDATE chat_messages
          SET is_pinned = FALSE
          WHERE conversation_id = @conversationId::uuid AND is_pinned = TRUE
          ''',
          values: {'conversationId': conversationId},
        );
      }
    } catch (e, stackTrace) {
      _logger.error('Error unpinning message: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Star message globally (visible to all participants)
  Future<void> starMessage(
    String messageId,
    String userId,
    String userType,
  ) async {
    try {
      // Update is_starred on the message directly for global visibility
      await DatabaseConnection.execute(
        '''
        UPDATE chat_messages
        SET is_starred = TRUE
        WHERE id = @messageId::uuid
        ''',
        values: {'messageId': messageId},
      );
    } catch (e, stackTrace) {
      _logger.error('Error starring message: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Unstar message globally
  Future<void> unstarMessage(
    String messageId,
    String userId,
    String userType,
  ) async {
    try {
      // Update is_starred on the message directly for global visibility
      await DatabaseConnection.execute(
        '''
        UPDATE chat_messages
        SET is_starred = FALSE
        WHERE id = @messageId::uuid
        ''',
        values: {'messageId': messageId},
      );
    } catch (e, stackTrace) {
      _logger.error('Error unstarring message: $e', e, stackTrace);
      rethrow;
    }
  }

  // ============================================
  // THEME
  // ============================================

  /// Update conversation theme
  Future<bool> updateConversationTheme({
    required String conversationId,
    required String themeId,
  }) async {
    try {
      final result = await DatabaseConnection.execute(
        '''
        UPDATE chat_conversations
        SET chat_theme_id = @themeId, updated_at = CURRENT_TIMESTAMP
        WHERE id = @conversationId::uuid
        ''',
        values: {'conversationId': conversationId, 'themeId': themeId},
      );

      _logger.info(
        'Updated theme for conversation $conversationId to $themeId',
      );
      return result > 0;
    } catch (e, stackTrace) {
      _logger.error('Error updating conversation theme: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Get conversation theme ID
  Future<String> getConversationTheme(String conversationId) async {
    try {
      final result = await DatabaseConnection.query(
        '''
        SELECT chat_theme_id FROM chat_conversations WHERE id = @conversationId::uuid
        ''',
        values: {'conversationId': conversationId},
      );

      if (result.isNotEmpty && result.first['chat_theme_id'] != null) {
        return result.first['chat_theme_id'] as String;
      }
      return 'default_blue'; // Default theme
    } catch (e, stackTrace) {
      _logger.error('Error getting conversation theme: $e', e, stackTrace);
      return 'default_blue';
    }
  }

  /// Trigger group creation notifications
  void _triggerGroupNotifications({
    required String conversationId,
    required String groupName,
    String? description,
    required String createdBy,
    required String createdByType,
    required List<Map<String, String>> participants,
  }) async {
    try {
      // Fetch creator name
      String creatorName = createdBy;
      try {
        if (createdByType.toLowerCase() == 'admin' ||
            createdByType.toLowerCase() == 'superadmin') {
          final result = await DatabaseConnection.queryOne(
            'SELECT admin_name FROM admins WHERE admin_id = @id',
            values: {'id': createdBy},
          );
          creatorName = result?['admin_name'] ?? createdBy;
        } else {
          final result = await DatabaseConnection.queryOne(
            'SELECT employee_name FROM employees WHERE employee_id = @id',
            values: {'id': createdBy},
          );
          creatorName = result?['employee_name'] ?? createdBy;
        }
      } catch (e) {
        _logger.warning('Failed to fetch creator name for notifications: $e');
      }

      // Include creator in participants if not already there
      final allParticipants = List<Map<String, dynamic>>.from(participants);
      final isCreatorIncluded = allParticipants.any(
        (p) => p['userId'] == createdBy || p['user_id'] == createdBy,
      );

      if (!isCreatorIncluded) {
        allParticipants.add({'userId': createdBy, 'userType': createdByType});
      }

      // Call unified notification service
      await UnifiedNotificationService.notifyGroupCreated(
        conversationId: conversationId,
        groupName: groupName,
        creatorName: creatorName,
        description: description,
        participants: allParticipants,
      );
    } catch (e) {
      _logger.error('Failed to trigger group notifications: $e');
    }
  }

  /// Get user name by ID and type
  Future<String> getUserName(String userId, String userType) async {
    try {
      if (userType.toLowerCase() == 'admin' ||
          userType.toLowerCase() == 'superadmin') {
        final result = await DatabaseConnection.queryOne(
          'SELECT admin_name FROM admins WHERE admin_id = @id',
          values: {'id': userId},
        );
        return result?['admin_name'] ?? userId;
      } else {
        final result = await DatabaseConnection.queryOne(
          'SELECT employee_name FROM employees WHERE employee_id = @id',
          values: {'id': userId},
        );
        return result?['employee_name'] ?? userId;
      }
    } catch (e) {
      _logger.warning('Failed to fetch user name: $e');
      return userId;
    }
  }
}
