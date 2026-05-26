import 'dart:convert';
import '../../core/utils/logger.dart';
import '../../config/app_config.dart';
import 'llm_provider.dart';
import 'ai_tool_registry.dart';
import 'ai_tool_executor.dart';

/// Main AI Service that orchestrates LLM interactions with function calling
class AiService {
  static final AppLogger _logger = AppLogger('AiService');

  // In-memory chat history per session (keyed by session ID)
  static final Map<String, List<ChatMessage>> _chatHistories = {};

  /// Base System prompt for the LLM
  static const String _baseSystemPrompt = '''
You are Sprintly AI, a helpful and highly contextual assistant (like GPT).

BEHAVIOR & PERSONALITY:
- Be conversational, friendly, and professional.
- ALWAYS refer to previous chat history to maintain a continuous conversation flow.
- If the user follows up on a previous topic (e.g., "What about tomorrow?"), refer back to what they were asking about.
- Avoid repeating the same questions if the information was already provided earlier in the chat.

USER CONTEXT:
- You will receive the `Current User ID` and `Current User Role` in the `[System Context]`.
- ALWAYS use the `Current User ID` as the `employee_id` when the user refers to themselves ("I", "my", "me").
- NEVER ask the user for their ID.

ROLE-BASED CAPABILITIES:
1. **Employee Role**:
   - Access ONLY to their own data.
   - Can check THEIR OWN leave, WFH, and permission statuses.
   - Can apply for leave, WFH, and permission for THEMSELVES.
   - Can check THEIR OWN tasks (Todo, In Progress, Completed, etc.).
   - Can REQUEST a new task (task card request).
   - Can check their own performance and attendance.
   - CANNOT approve/reject requests.
   - CANNOT see other employees' details.

2. **Admin/HR Role**:
   - Access to all employee data.
   - Can approve/reject leaves, WFH, and permissions.
   - Can see workforce overviews.
   - Can manage all tasks and projects.

TASK WORKFLOW STATUSES:
- `backlog`, `todo`, `in_progress`, `dev_completed`, `in_qc`, `work_done`, `completed`, `cancelled`.

CHAT ANALYSIS (SYNC BOARD):
- You can summarize conversations, find decision points, and identify blockers.
- When asked "What did I miss?" or "Give me a catch-up", fetch recent messages using `get_conversation_messages`.
- **Action Items**: If someone says they will do something (e.g., "I'll fix the bug"), identify it as an action item.
- **Tone**: Maintain the context of the chat. If it's a group chat, speak in that context.

TASK REQUESTS (EMPLOYEE):
- To submit a task request, you ideally need: `project_id`, `task_name`, `task_description`, `task_type`, `from_date`, `to_date`.
- **BE PROACTIVE**: 
  - If a project name is mentioned (e.g., "Taxiby"), call `get_all_projects` immediately to find the `project_id`. 
  - If multiple projects match, ask for clarification.
  - If no project is mentioned, ask which project it's for.
  - **DEFAULTS**:
    - If `from_date` or `to_date` are not mentioned, assume "today" (use `Current Date` from context).
    - If `task_type` is not mentioned, use "Development".
    - If `priority_level` is not mentioned, use "medium".
    - If `task_description` is not mentioned, use the `task_name` as the description.
- **Goal**: Minimize the number of questions you ask the user. Try to gather enough information in one go.

IMPORTANT RULES:
- If an **Employee** asks for "my tasks", use `get_all_task_cards` with their `employee_id`.
- If an **Employee** wants to request a task, use `submit_task_card_request`.

EXAMPLES (Employee Perspective):
- User: "I want to request a task 'Design Review' for Alpha project." -> Response: "Fetching Project ID for Alpha... [Tool Call: get_all_projects] ... Understood, I've submitted a 'Design Review' task request for Project Alpha for today." [Tool Call: submit_task_card_request]
- User: "Request task 'Bug Fix' for tomorrow." -> Response: "Which project is this for?"

UI ACTIONS:
- `open_leave_request`, `open_task_request`, `nav_attendance`, `nav_reports`, `nav_dashboard`.
- Format: `||ACTION:action_code||` at the end of response.
''';

  /// Process a chat message from the user
  static Future<Map<String, dynamic>> processChat({
    required String sessionId,
    required String message,
    required String userId,
    required String role,
    String? currentTab,
  }) async {
    _logger.info(
      'Processing chat for session $sessionId ($role: $userId, tab: $currentTab)',
    );

    // Get or create chat history for this session
    final history = _chatHistories.putIfAbsent(sessionId, () => []);

    // Add context about current user and date
    final now = DateTime.now().toIso8601String().split('T')[0];
    final contextualMessage =
        '''
[System Context]
Current Date: $now
Current User ID: $userId
Current User Role: $role
Current Tab: ${currentTab ?? 'None'}

$message''';

    // Add user message to history
    history.add(ChatMessage(role: 'user', content: contextualMessage));

    // Get the LLM provider
    final provider = LlmProviderFactory.getProvider();
    final tools = AiToolRegistry.getAllTools();

    try {
      LlmResponse response;
      int iterations = 0;
      const maxIterations = 5;
      bool toolsExecuted = false;

      do {
        iterations++;
        _logger.info('LLM call iteration $iterations');

        response = await _callWithFallback(
          provider: provider,
          messages: history,
          tools: tools,
          systemPrompt: _baseSystemPrompt,
        );

        if (response.hasFunctionCalls) {
          toolsExecuted = true;

          history.add(
            ChatMessage(
              role: 'assistant',
              functionCalls: response.functionCalls,
              content: response.textContent,
            ),
          );

          for (final fc in response.functionCalls!) {
            _logger.info('Executing tool: ${fc.name}');

            // SECURITY CHECK: If role is Employee, ensure they only access their own data
            if (role.toLowerCase() == 'employee') {
              final restrictedTools = [
                'get_all_leaves',
                'get_all_wfh_requests',
                'get_all_permissions',
                'get_employee_attendance',
                'submit_leave_request',
                'submit_wfh_request',
                'submit_permission_request',
                'get_all_task_cards',
                'get_all_task_card_requests',
                'get_employee_performance_report',
                'get_employee_leave_statistics',
                'get_employee_tracker_detail',
                'submit_task_card_request',
                'get_chat_conversations',
                'get_conversation_messages',
              ];

              if (restrictedTools.contains(fc.name)) {
                // Force employee_id to be current user
                fc.arguments['employee_id'] = userId;
                fc.arguments['user_role'] = 'Employee';
                if (fc.name == 'get_all_wfh_requests') {
                  fc.arguments['requester_id'] = userId;
                }
              }

              // BLOCK ADMIN TOOLS FOR EMPLOYEES
              final adminTools = [
                'get_pending_leaves',
                'get_pending_permissions',
                'approve_leave_request',
                'reject_leave_request',
                'approve_permission_request',
                'reject_permission_request',
                'approve_reject_wfh_request',
                'get_employee_overview_today',
                'get_all_employees',
                'get_present_employees',
                'get_absent_employees',
                'get_wfh_employees',
                'get_permission_employees',
                'get_late_employees',
                'get_delayed_task_cards',
                'approve_task_card_request',
                'reject_task_card_request',
                'get_all_todos',
                'get_employee_performance_summary',
                'get_employee_tracker_list',
              ];

              if (adminTools.contains(fc.name)) {
                history.add(
                  ChatMessage(
                    role: 'tool',
                    content: jsonEncode({
                      'error': true,
                      'message':
                          'Permission denied. Only Admins can perform this action.',
                    }),
                    toolCallId: fc.id ?? 'call_${fc.name}',
                    name: fc.name,
                  ),
                );
                continue;
              }
            }

            final result = await AiToolExecutor.execute(fc.name, fc.arguments);
            history.add(
              ChatMessage(
                role: 'tool',
                content: result,
                toolCallId: fc.id ?? 'call_${fc.name}',
                name: fc.name,
              ),
            );
          }
        }
      } while (response.hasFunctionCalls && iterations < maxIterations);

      var responseText = response.textContent;
      if (responseText == null || responseText.isEmpty) {
        responseText = toolsExecuted
            ? 'I have retrieved the information for you.'
            : 'I processed your request.';
      }

      String? actionCode;
      final actionRegex = RegExp(r'\|\|ACTION:([a-zA-Z0-9_]+)\|\|');
      final match = actionRegex.firstMatch(responseText ?? '');
      if (match != null) {
        actionCode = match.group(1);
        responseText = responseText.replaceAll(match.group(0)!, '').trim();
      }

      history.add(ChatMessage(role: 'assistant', content: responseText));

      if (history.length > 30) {
        _chatHistories[sessionId] = history.sublist(history.length - 30);
      }

      return {
        'success': true,
        'message': responseText,
        'reply': responseText,
        'response': responseText,
        'action': actionCode,
        'session_id': sessionId,
        'provider': AppConfig.activeLlmProvider,
      };
    } catch (e, stackTrace) {
      _logger.error('AI chat error: $e', e, stackTrace);
      return {
        'success': false,
        'message': 'I encountered an error: $e',
        'error': e.toString(),
        'session_id': sessionId,
      };
    }
  }

  static void clearSession(String sessionId) {
    _chatHistories.remove(sessionId);
  }

  static List<Map<String, dynamic>> getHistory(String sessionId) {
    final history = _chatHistories[sessionId] ?? [];
    return history
        .where(
          (msg) =>
              msg.role == 'user' ||
              (msg.role == 'assistant' && msg.content != null),
        )
        .map(
          (msg) => {
            'role': msg.role,
            'content': msg.content ?? '',
            'timestamp': DateTime.now().toIso8601String(),
          },
        )
        .toList();
  }

  static Map<String, dynamic> getStatus() {
    return {
      'configured': AppConfig.llmApiKey.isNotEmpty,
      'provider': AppConfig.activeLlmProvider,
      'model': AppConfig.llmModel,
      'active_sessions': _chatHistories.length,
    };
  }

  static Future<LlmResponse> _callWithFallback({
    required LlmProvider provider,
    required List<ChatMessage> messages,
    required List<ToolDefinition> tools,
    required String systemPrompt,
  }) async {
    final providers = <MapEntry<String, LlmProvider>>[];
    providers.add(MapEntry('Primary', provider));

    if (provider is! GeminiProvider && AppConfig.geminiApiKey.isNotEmpty) {
      providers.add(MapEntry('Gemini', GeminiProvider()));
    }
    if (provider is! DeepSeekProvider && AppConfig.deepseekApiKey.isNotEmpty) {
      providers.add(MapEntry('DeepSeek', DeepSeekProvider()));
    }
    if (provider is! OpenRouterProvider &&
        AppConfig.openrouterApiKey.isNotEmpty) {
      providers.add(MapEntry('OpenRouter', OpenRouterProvider()));
    }
    if (provider is! OpenAIProvider && AppConfig.openaiApiKey.isNotEmpty) {
      providers.add(MapEntry('OpenAI', OpenAIProvider()));
    }

    Exception? lastError;
    for (final entry in providers) {
      try {
        return await entry.value.chat(
          messages: messages,
          tools: tools,
          systemPrompt: systemPrompt,
        );
      } catch (e) {
        _logger.warning('${entry.key} provider failed: $e');
        lastError = e is Exception ? e : Exception(e.toString());
      }
    }
    throw lastError ?? Exception('All LLM providers failed');
  }
}
