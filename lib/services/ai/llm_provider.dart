import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../config/app_config.dart';
import '../../core/utils/logger.dart';

/// Represents a function/tool parameter
class ToolParameter {
  final String name;
  final String type;
  final String description;
  final bool required;
  final List<String>? enumValues;

  ToolParameter({
    required this.name,
    required this.type,
    required this.description,
    this.required = false,
    this.enumValues,
  });
}

/// Represents a function/tool that the LLM can call
class ToolDefinition {
  final String name;
  final String description;
  final List<ToolParameter> parameters;

  ToolDefinition({
    required this.name,
    required this.description,
    required this.parameters,
  });
}

/// Represents a function call made by the LLM
class FunctionCall {
  final String name;
  final Map<String, dynamic> arguments;
  final String? id;

  FunctionCall({required this.name, required this.arguments, this.id});

  Map<String, dynamic> toJson() => {
    'name': name,
    'arguments': arguments,
    if (id != null) 'id': id,
  };
}

/// Represents a chat message
class ChatMessage {
  final String role; // 'system', 'user', 'assistant', 'tool'
  final String? content;
  final List<FunctionCall>? functionCalls;
  final String? toolCallId;
  final String? name;

  ChatMessage({
    required this.role,
    this.content,
    this.functionCalls,
    this.toolCallId,
    this.name,
  });

  Map<String, dynamic> toJson() => {
    'role': role,
    'content': content,
    if (functionCalls != null)
      'function_calls': functionCalls!.map((f) => f.toJson()).toList(),
    if (toolCallId != null) 'tool_call_id': toolCallId,
    if (name != null) 'name': name,
  };
}

/// Represents the LLM response
class LlmResponse {
  final String? textContent;
  final List<FunctionCall>? functionCalls;
  final bool hasFunctionCalls;

  LlmResponse({this.textContent, this.functionCalls})
    : hasFunctionCalls = functionCalls != null && functionCalls.isNotEmpty;

  @override
  String toString() {
    return 'LlmResponse(text: ${textContent != null ? "${textContent!.substring(0, textContent!.length > 50 ? 50 : textContent!.length)}..." : "null"}, functionCalls: ${functionCalls?.length ?? 0})';
  }
}

/// Abstract LLM Provider interface - generic for any LLM
abstract class LlmProvider {
  Future<LlmResponse> chat({
    required List<ChatMessage> messages,
    required List<ToolDefinition> tools,
    String? systemPrompt,
  });
}

/// Gemini LLM Provider implementation
class GeminiProvider implements LlmProvider {
  final AppLogger _logger = AppLogger('GeminiProvider');

  @override
  Future<LlmResponse> chat({
    required List<ChatMessage> messages,
    required List<ToolDefinition> tools,
    String? systemPrompt,
  }) async {
    final apiKey = AppConfig.geminiApiKey.trim();
    final model = AppConfig.geminiModel.trim();

    if (apiKey.isEmpty) {
      throw Exception('GEMINI_API_KEY is not configured');
    }

    final url =
        'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$apiKey';

    // Build Gemini request body
    final body = _buildGeminiRequest(messages, tools, systemPrompt);

    // Retry logic for rate-limit (429) errors
    const maxRetries = 3;
    for (var attempt = 1; attempt <= maxRetries; attempt++) {
      _logger.info('Sending request to Gemini ($model)... (attempt $attempt)');

      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        return _parseGeminiResponse(jsonDecode(response.body));
      }

      // Rate limited — retry after delay
      if (response.statusCode == 429 && attempt < maxRetries) {
        // Parse retry delay from response, default to 30 seconds
        var retryDelay = 30;
        try {
          final errorBody = jsonDecode(response.body);
          final details = errorBody['error']?['details'] as List?;
          if (details != null) {
            for (final detail in details) {
              if (detail['retryDelay'] != null) {
                final delayStr = detail['retryDelay'].toString();
                // Parse "28s" or "28.386099347s" format
                final seconds = double.tryParse(delayStr.replaceAll('s', ''));
                if (seconds != null) {
                  retryDelay = seconds.ceil() + 2; // Add 2s buffer
                }
              }
            }
          }
        } catch (_) {}

        _logger.warning(
          'Gemini rate limited (429). Retrying in ${retryDelay}s... (attempt $attempt/$maxRetries)',
        );
        await Future.delayed(Duration(seconds: retryDelay));
        continue;
      }

      // Non-retryable error
      _logger.error(
        'Gemini API error: ${response.statusCode} - ${response.body}',
      );
      throw Exception(
        'Gemini API error: ${response.statusCode} - ${response.body}',
      );
    }

    throw Exception('Gemini API failed after $maxRetries retries');
  }

  Map<String, dynamic> _buildGeminiRequest(
    List<ChatMessage> messages,
    List<ToolDefinition> tools,
    String? systemPrompt,
  ) {
    final request = <String, dynamic>{};

    // System instruction
    if (systemPrompt != null) {
      request['system_instruction'] = {
        'parts': [
          {'text': systemPrompt},
        ],
      };
    }

    // Contents (messages)
    final contents = <Map<String, dynamic>>[];
    for (final msg in messages) {
      if (msg.role == 'system') continue; // Handled by system_instruction

      final parts = <Map<String, dynamic>>[];

      if (msg.content != null) {
        parts.add({'text': msg.content!});
      }

      // Handle function calls from assistant
      if (msg.functionCalls != null) {
        for (final fc in msg.functionCalls!) {
          parts.add({
            'functionCall': {'name': fc.name, 'args': fc.arguments},
          });
        }
      }

      // Handle tool responses
      if (msg.role == 'tool' && msg.name != null) {
        parts.add({
          'functionResponse': {
            'name': msg.name!,
            'response': {'result': msg.content ?? ''},
          },
        });
      }

      final role = msg.role == 'assistant' ? 'model' : 'user';
      if (msg.role == 'tool') {
        contents.add({'role': 'user', 'parts': parts});
      } else {
        contents.add({'role': role, 'parts': parts});
      }
    }
    request['contents'] = contents;

    // Tools (function declarations)
    if (tools.isNotEmpty) {
      final functionDeclarations = tools.map((tool) {
        final properties = <String, dynamic>{};
        final required = <String>[];

        for (final param in tool.parameters) {
          final prop = <String, dynamic>{
            'type': param.type.toUpperCase(),
            'description': param.description,
          };
          if (param.enumValues != null) {
            prop['enum'] = param.enumValues;
          }
          properties[param.name] = prop;
          if (param.required) {
            required.add(param.name);
          }
        }

        return {
          'name': tool.name,
          'description': tool.description,
          'parameters': {
            'type': 'OBJECT',
            'properties': properties,
            if (required.isNotEmpty) 'required': required,
          },
        };
      }).toList();

      request['tools'] = [
        {'function_declarations': functionDeclarations},
      ];
    }

    // Generation config
    request['generation_config'] = {
      'temperature': 0.2,
      'top_p': 0.8,
      'max_output_tokens': 4096,
    };

    return request;
  }

  LlmResponse _parseGeminiResponse(Map<String, dynamic> response) {
    final candidates = response['candidates'] as List?;
    if (candidates == null || candidates.isEmpty) {
      // Check for prompt feedback block
      if (response['promptFeedback'] != null) {
        _logger.warning(
          'Prompt feedback: ${jsonEncode(response['promptFeedback'])}',
        );
      }
      return LlmResponse(textContent: 'No response from AI.');
    }

    final content = candidates[0]['content'] as Map<String, dynamic>?;
    if (content == null) {
      return LlmResponse(textContent: 'No content in AI response.');
    }

    final parts = content['parts'] as List?;
    if (parts == null || parts.isEmpty) {
      return LlmResponse(textContent: 'Empty response from AI.');
    }

    String? textContent;
    final functionCalls = <FunctionCall>[];

    for (final part in parts) {
      if (part.containsKey('text')) {
        textContent = (textContent ?? '') + part['text'];
      }
      if (part.containsKey('functionCall')) {
        final fc = part['functionCall'];
        functionCalls.add(
          FunctionCall(
            name: fc['name'],
            arguments: Map<String, dynamic>.from(fc['args'] ?? {}),
          ),
        );
      }
    }

    return LlmResponse(
      textContent: textContent,
      functionCalls: functionCalls.isEmpty ? null : functionCalls,
    );
  }
}

/// OpenAI GPT Provider implementation
class OpenAIProvider implements LlmProvider {
  final AppLogger _logger = AppLogger('OpenAIProvider');

  @override
  Future<LlmResponse> chat({
    required List<ChatMessage> messages,
    required List<ToolDefinition> tools,
    String? systemPrompt,
  }) async {
    final apiKey = AppConfig.openaiApiKey.trim();
    final model = AppConfig.openaiModel.trim();

    if (apiKey.isEmpty) {
      throw Exception('OPENAI_API_KEY is not configured');
    }

    const url = 'https://api.openai.com/v1/chat/completions';

    final body = buildOpenAIRequest(messages, tools, systemPrompt, model);

    _logger.info('Sending request to OpenAI ($model)...');

    final response = await http.post(
      Uri.parse(url),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      },
      body: jsonEncode(body),
    );

    if (response.statusCode != 200) {
      _logger.error(
        'OpenAI API error: ${response.statusCode} - ${response.body}',
      );
      throw Exception(
        'OpenAI API error: ${response.statusCode} - ${response.body}',
      );
    }

    // DEBUG: Log Raw Response
    _logger.info('OpenAI Response: ${response.body}');

    return parseOpenAIResponse(jsonDecode(response.body));
  }

  Map<String, dynamic> buildOpenAIRequest(
    List<ChatMessage> messages,
    List<ToolDefinition> tools,
    String? systemPrompt,
    String model,
  ) {
    final openaiMessages = <Map<String, dynamic>>[];

    // Add system prompt
    if (systemPrompt != null) {
      openaiMessages.add({'role': 'system', 'content': systemPrompt});
    }

    // Convert messages
    for (final msg in messages) {
      if (msg.role == 'system') continue;

      if (msg.role == 'tool') {
        openaiMessages.add({
          'role': 'tool',
          'content': msg.content ?? '',
          'tool_call_id': msg.toolCallId ?? '',
        });
      } else if (msg.role == 'assistant' && msg.functionCalls != null) {
        final toolCalls = msg.functionCalls!
            .map(
              (fc) => {
                'id': fc.id ?? 'call_${fc.name}',
                'type': 'function',
                'function': {
                  'name': fc.name,
                  'arguments': jsonEncode(fc.arguments),
                },
              },
            )
            .toList();

        openaiMessages.add({'role': 'assistant', 'tool_calls': toolCalls});
      } else {
        openaiMessages.add({'role': msg.role, 'content': msg.content ?? ''});
      }
    }

    // Build tools
    final openaiTools = tools.map((tool) {
      final properties = <String, dynamic>{};
      final required = <String>[];

      for (final param in tool.parameters) {
        final prop = <String, dynamic>{
          'type': param.type,
          'description': param.description,
        };
        if (param.enumValues != null) {
          prop['enum'] = param.enumValues;
        }
        properties[param.name] = prop;
        if (param.required) {
          required.add(param.name);
        }
      }

      return {
        'type': 'function',
        'function': {
          'name': tool.name,
          'description': tool.description,
          'parameters': {
            'type': 'object',
            'properties': properties,
            if (required.isNotEmpty) 'required': required,
          },
        },
      };
    }).toList();

    return {
      'model': model,
      'messages': openaiMessages,
      if (openaiTools.isNotEmpty) 'tools': openaiTools,
      'temperature': 0.2,
      'max_tokens': 4096,
    };
  }

  LlmResponse parseOpenAIResponse(Map<String, dynamic> response) {
    final choices = response['choices'] as List?;
    if (choices == null || choices.isEmpty) {
      return LlmResponse(textContent: 'No response from AI.');
    }

    final message = choices[0]['message'] as Map<String, dynamic>;
    final content = message['content'] as String?;
    final toolCalls = message['tool_calls'] as List?;

    final functionCalls = <FunctionCall>[];
    if (toolCalls != null) {
      for (final tc in toolCalls) {
        final function_ = tc['function'];
        try {
          // Robust parsing for arguments - handle string or Map
          var args = function_['arguments'];
          if (args is String) {
            args = jsonDecode(args);
          }

          functionCalls.add(
            FunctionCall(
              name: function_['name'],
              arguments: args is Map<String, dynamic> ? args : {},
              id: tc['id'],
            ),
          );
        } catch (e) {
          print(
            'Failed to parse function call args: ${function_['arguments']}',
          );
        }
      }
    }

    // Check for DeepSeek Reasoning Content (often in 'reasoning_content' or similar invisible field)
    // We can't easily extract it if it's not in content, but logging helps.

    return LlmResponse(
      textContent: content,
      functionCalls: functionCalls.isEmpty ? null : functionCalls,
    );
  }
}

/// OpenRouter Provider implementation (OpenAI-compatible)
class OpenRouterProvider implements LlmProvider {
  final AppLogger _logger = AppLogger('OpenRouterProvider');
  final OpenAIProvider _openAIProvider = OpenAIProvider();

  @override
  Future<LlmResponse> chat({
    required List<ChatMessage> messages,
    required List<ToolDefinition> tools,
    String? systemPrompt,
  }) async {
    final apiKey = AppConfig.openrouterApiKey.trim();
    final model = AppConfig.openrouterModel.trim();

    if (apiKey.isEmpty) {
      throw Exception('OPENROUTER_API_KEY is not configured');
    }

    const url = 'https://openrouter.ai/api/v1/chat/completions';

    // OpenRouter uses the same request format as OpenAI
    final body = _openAIProvider.buildOpenAIRequest(
      messages,
      tools,
      systemPrompt,
      model,
    );

    // Retry logic for rate-limit (429) and transient (500) errors
    const maxRetries = 2;
    for (var attempt = 1; attempt <= maxRetries; attempt++) {
      _logger.info(
        'Sending request to OpenRouter ($model)... (attempt $attempt)',
      );

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
          'HTTP-Referer': 'https://sprintly.webnoxdigital.com',
          'X-Title': 'Sprintly Admin Dashboard',
        },
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        _logger.info('OpenRouter Response: ${response.body}');
        return _openAIProvider.parseOpenAIResponse(jsonDecode(response.body));
      }

      // Retryable errors
      if ((response.statusCode == 429 || response.statusCode == 500) &&
          attempt < maxRetries) {
        final retryDelay = response.statusCode == 429 ? 30 : 5;
        _logger.warning(
          'OpenRouter error ${response.statusCode}. Retrying in ${retryDelay}s... (attempt $attempt/$maxRetries)',
        );
        await Future.delayed(Duration(seconds: retryDelay));
        continue;
      }

      // Non-retryable or final attempt error
      _logger.error(
        'OpenRouter API error: ${response.statusCode} - ${response.body}',
      );
      throw Exception(
        'OpenRouter API error: ${response.statusCode} - ${response.body}',
      );
    }

    throw Exception('OpenRouter API failed after $maxRetries retries');
  }
}

/// DeepSeek Provider implementation (OpenAI-compatible)
class DeepSeekProvider implements LlmProvider {
  final AppLogger _logger = AppLogger('DeepSeekProvider');
  final OpenAIProvider _openAIProvider = OpenAIProvider();

  @override
  Future<LlmResponse> chat({
    required List<ChatMessage> messages,
    required List<ToolDefinition> tools,
    String? systemPrompt,
  }) async {
    final apiKey = AppConfig.deepseekApiKey.trim();
    final model = AppConfig.deepseekModel.trim();

    if (apiKey.isEmpty) {
      throw Exception('DEEPSEEK_API_KEY is not configured');
    }

    const url = 'https://api.deepseek.com/chat/completions';

    // DeepSeek uses the same request format as OpenAI
    final body = _openAIProvider.buildOpenAIRequest(
      messages,
      tools,
      systemPrompt,
      model,
    );

    // Retry logic for rate-limit (429) and transient (500) errors
    const maxRetries = 3;
    for (var attempt = 1; attempt <= maxRetries; attempt++) {
      _logger.info(
        'Sending request to DeepSeek ($model)... (attempt $attempt)',
      );

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        _logger.info('DeepSeek Response: ${response.body}');
        return _openAIProvider.parseOpenAIResponse(jsonDecode(response.body));
      }

      // Retryable errors
      if ((response.statusCode == 429 || response.statusCode == 500) &&
          attempt < maxRetries) {
        final retryDelay = response.statusCode == 429 ? 30 : 5;
        _logger.warning(
          'DeepSeek error ${response.statusCode}. Retrying in ${retryDelay}s... (attempt $attempt/$maxRetries)',
        );
        await Future.delayed(Duration(seconds: retryDelay));
        continue;
      }

      // Non-retryable or final attempt error
      _logger.error(
        'DeepSeek API error: ${response.statusCode} - ${response.body}',
      );
      throw Exception(
        'DeepSeek API error: ${response.statusCode} - ${response.body}',
      );
    }

    throw Exception('DeepSeek API failed after $maxRetries retries');
  }
}

/// Factory to get the active LLM provider
class LlmProviderFactory {
  static LlmProvider getProvider() {
    if (AppConfig.useGemini) {
      return GeminiProvider();
    } else if (AppConfig.useOpenRouter) {
      return OpenRouterProvider();
    } else if (AppConfig.useDeepSeek) {
      return DeepSeekProvider();
    } else {
      return OpenAIProvider();
    }
  }
}
