// AI Summarizer for Skill Distillation
//
// Uses ephemeral DshClient session to summarize chat messages into skill drafts.
// Implements input size limits, secret redaction, timeout, and robust JSON parsing.

import 'dart:async';
import 'dart:convert';

import 'package:dsh_client/dsh_client.dart';

import '../skills/skill_distill.dart';
import '../skills/skill_model.dart';
import '../share_code/conversation_redact.dart';
import '../ui/chat/secret_mask.dart';

/// Configuration for AI summarization
class AiSummarizerConfig {
  const AiSummarizerConfig({
    this.maxUserPromptChars = 1500,
    this.maxAssistantChars = 4000,
    this.maxWriteScriptChars = 6000,
    this.maxTotalPromptChars = 20000,
    this.timeoutSeconds = 25,
    this.maxRetries = 1,
    this.locale = 'th',
  });

  final int maxUserPromptChars;
  final int maxAssistantChars;
  final int maxWriteScriptChars;
  final int maxTotalPromptChars;
  final int timeoutSeconds;
  final int maxRetries;
  final String locale;
}

/// Result of AI summarization
class AiSummarizerResult {
  const AiSummarizerResult({
    required this.skill,
    required this.fromCache,
    this.breadcrumb,
  });

  final Skill skill;
  final bool fromCache;
  final String? breadcrumb;
}

/// AI Summarizer using ephemeral DshClient session
class AiSummarizer {
  AiSummarizer({
    required DshClient client,
    AiSummarizerConfig? config,
  }) : _client = client,
       _config = config ?? const AiSummarizerConfig();

  final DshClient _client;
  final AiSummarizerConfig _config;
  String? _ephemeralSessionId;

  /// Summarize chat messages into a skill draft
  Future<AiSummarizerResult> summarize({
    required String userMessage,
    String? aiResponse,
    required List<ToolCallInfo> toolCallsWithArgs,
    String? sessionTitle,
  }) async {
    // Phase 4: Build prompt with size limits and redaction
    final prompt = _buildPrompt(
      userMessage: userMessage,
      aiResponse: aiResponse,
      toolCallsWithArgs: toolCallsWithArgs,
      sessionTitle: sessionTitle,
    );

    // Phase 4: Create ephemeral session
    _ephemeralSessionId = await _createEphemeralSession();
    if (_ephemeralSessionId == null) {
      throw StateError('Failed to create ephemeral session');
    }

    // Phase 4: Send prompt with timeout and retries
    String response = '';
    int attempt = 0;
    while (attempt <= _config.maxRetries) {
      try {
        response = await _sendPromptWithTimeout(_ephemeralSessionId!, prompt);
        break;
      } on TimeoutException {
        attempt++;
        if (attempt > _config.maxRetries) {
          throw TimeoutException('AI summarization timed out after ${_config.timeoutSeconds}s');
        }
        // Wait before retry
        await Future.delayed(const Duration(seconds: 2));
      }
    }

    // Phase 4: Parse JSON response robustly
    final skill = _parseJsonResponse(response);

    // Phase 4: Cleanup ephemeral session
    await _cleanupEphemeralSession();

    return AiSummarizerResult(
      skill: skill,
      fromCache: false,
      breadcrumb: 'ai:ok',
    );
  }

  /// Build prompt with size limits and redaction
  String _buildPrompt({
    required String userMessage,
    String? aiResponse,
    required List<ToolCallInfo> toolCallsWithArgs,
    String? sessionTitle,
  }) {
    // Truncate inputs to size limits
    final truncatedUserPrompt = _truncateAndRedact(userMessage, _config.maxUserPromptChars);
    final truncatedAiResponse = aiResponse != null
        ? _truncateAndRedact(aiResponse, _config.maxAssistantChars)
        : null;

    // Build tool calls summary with size limits
    final toolCallsSummary = toolCallsWithArgs.map((call) {
      final argsJson = jsonEncode(call.args);
      final truncatedArgs = _truncateAndRedact(argsJson, _config.maxWriteScriptChars);
      return {
        'name': call.name,
        'args': jsonDecode(truncatedArgs),
      };
    }).toList();

    // Build prompt
    final prompt = StringBuffer();
    prompt.writeln('You are a skill distillation assistant.');
    prompt.writeln('Analyze the following chat message and tool calls to create a reusable skill.');
    prompt.writeln('Respond ONLY with valid JSON matching the schema below.');
    prompt.writeln('Language: ${_config.locale == 'th' ? 'Thai (technical terms in English)' : _config.locale == 'zh' ? 'Chinese (technical terms in English)' : 'English'}');
    prompt.writeln('');
    prompt.writeln('Schema:');
    prompt.writeln('''{
  "name": "string (<=60 chars, descriptive, not generic like Script/Code)",
  "goal": "string (<=300 chars, specific objective)",
  "description": "string (<=200 chars, what the skill does)",
  "steps": ["string (<=150 chars each, max 8 steps, action-oriented)"],
  "constraints": ["string (safety/operational constraints)"],
  "tools": ["string (tool names: bash, edit, write, read, web_fetch, etc.)"],
  "parameters": [
    {"key": "string", "label": "string", "hint": "string", "type": "string", "required": "bool", "default": "string?"}
  ]
}''');
    prompt.writeln('');
    prompt.writeln('User Message:');
    prompt.writeln(truncatedUserPrompt);
    if (truncatedAiResponse != null) {
      prompt.writeln('');
      prompt.writeln('Assistant Response:');
      prompt.writeln(truncatedAiResponse);
    }
    if (toolCallsSummary.isNotEmpty) {
      prompt.writeln('');
      prompt.writeln('Tool Calls:');
      prompt.writeln(jsonEncode(toolCallsSummary));
    }
    if (sessionTitle != null) {
      prompt.writeln('');
      prompt.writeln('Session Title: $sessionTitle');
    }
    prompt.writeln('');
    prompt.writeln('Rules:');
    prompt.writeln('- No CJK characters in output unless locale is zh');
    prompt.writeln('- No secrets (API keys, tokens, passwords) in output');
    prompt.writeln('- Name must not be generic (Script, Code, Result, etc.)');
    prompt.writeln('- Goal must not duplicate name or description');
    prompt.writeln('- Steps must be action-oriented, no leading symbols');
    prompt.writeln('- Output ONLY the JSON object, no markdown fences');

    // Truncate total prompt if needed
    final fullPrompt = prompt.toString();
    return _truncate(fullPrompt, _config.maxTotalPromptChars);
  }

  /// Truncate and redact text
  String _truncateAndRedact(String text, int maxChars) {
    // First truncate
    final truncated = _truncate(text, maxChars);
    // Then redact secrets
    return redactText(truncated);
  }

  /// Truncate text to max chars
  String _truncate(String text, int maxChars) {
    if (text.length <= maxChars) return text;
    return '${text.substring(0, maxChars)}...';
  }

  /// Create ephemeral session for AI summarization
  Future<String?> _createEphemeralSession() async {
    try {
      final session = await _client.createSession(
        cwd: '/tmp',
        workspaceId: 'skill-distill-ai',
        agentPreset: 'standard',
      );
      return session.sessionId;
    } catch (e) {
      return null;
    }
  }

  /// Send prompt to ephemeral session with timeout
  Future<String?> _sendPromptWithTimeout(String sessionId, String prompt) async {
    final completer = Completer<String?>();
    final timeoutTimer = Timer(Duration(seconds: _config.timeoutSeconds), () {
      if (!completer.isCompleted) {
        completer.completeError(TimeoutException('Prompt timeout'));
      }
    });

    try {
      final stream = _client.prompt(
        sessionId: sessionId,
        prompt: prompt,
      );

      final buffer = StringBuffer();
      await for (final event in stream) {
        if (event is PromptEvent && event.text != null) {
          buffer.write(event.text);
        }
      }
      timeoutTimer.cancel();
      completer.complete(buffer.toString());
    } catch (e) {
      timeoutTimer.cancel();
      completer.completeError(e);
    }

    return completer.future;
  }

  /// Parse JSON response robustly (strip fences, parse object)
  Skill _parseJsonResponse(String response) {
    // Strip markdown fences if present
    String jsonText = response.trim();
    if (jsonText.startsWith('```json')) {
      jsonText = jsonText.substring(7);
    } else if (jsonText.startsWith('```')) {
      jsonText = jsonText.substring(3);
    }
    if (jsonText.endsWith('```')) {
      jsonText = jsonText.substring(0, jsonText.length - 3);
    }
    jsonText = jsonText.trim();

    // Parse JSON
    final Map<String, dynamic> data;
    try {
      data = jsonDecode(jsonText) as Map<String, dynamic>;
    } catch (e) {
      throw FormatException('Failed to parse AI response as JSON: $e');
    }

    // Validate required fields
    _validateJsonFields(data);

    // Build Skill from parsed JSON
    return Skill(
      id: _generateId(),
      name: _sanitizeString(data['name'] as String?) ?? 'Unnamed Skill',
      goal: _sanitizeString(data['goal'] as String?) ?? 'Achieve the described task',
      description: _sanitizeString(data['description'] as String?) ?? 'Skill distilled from chat',
      steps: _parseStringList(data['steps']),
      constraints: _parseStringList(data['constraints']),
      requiredTools: _parseStringList(data['tools']),
      userInputs: _parseParameters(data['parameters']),
      createdAt: DateTime.now(),
      category: _inferCategory(data['tools'] as List<dynamic>?),
      kind: 'workflow',
      schemaVersion: 2,
    );
  }

  void _validateJsonFields(Map<String, dynamic> data) {
    const requiredFields = ['name', 'goal', 'description', 'steps', 'constraints', 'tools', 'parameters'];
    for (final field in requiredFields) {
      if (!data.containsKey(field)) {
        throw FormatException('Missing required field: $field');
      }
    }
  }

  String? _sanitizeString(String? value) {
    if (value == null) return null;
    final redacted = redactText(value);
    return redacted.isEmpty ? null : redacted;
  }

  List<String> _parseStringList(dynamic value) {
    if (value is List) {
      return value
          .whereType<String>()
          .map(_sanitizeString)
          .where((s) => s != null && s.isNotEmpty)
          .cast<String>()
          .toList();
    }
    return [];
  }

  List<SkillInput> _parseParameters(dynamic value) {
    if (value is List) {
      return value
          .whereType<Map<String, dynamic>>()
          .map((p) => SkillInput(
                key: _sanitizeString(p['key'] as String?) ?? 'param',
                label: _sanitizeString(p['label'] as String?) ?? 'Parameter',
                hint: _sanitizeString(p['hint'] as String?) ?? '',
                type: _parseInputType(p['type'] as String?),
                required: p['required'] as bool? ?? false,
                defaultValue: p['default'] as String?,
              ))
          .toList();
    }
    return [];
  }

  SkillInputType _parseInputType(String? typeStr) {
    switch (typeStr?.toLowerCase()) {
      case 'number':
        return SkillInputType.number;
      case 'boolean':
        return SkillInputType.boolean;
      case 'select':
        return SkillInputType.select;
      case 'multiline':
        return SkillInputType.multiline;
      case 'text':
      default:
        return SkillInputType.text;
    }
  }

  SkillCategory _inferCategory(List<dynamic>? tools) {
    if (tools == null) return SkillCategory.other;
    final toolSet = tools.whereType<String>().toSet();
    if (toolSet.contains('bash') || toolSet.contains('edit') || toolSet.contains('write')) {
      return SkillCategory.development;
    }
    if (toolSet.contains('web_fetch') || toolSet.contains('web_search')) {
      return SkillCategory.automation;
    }
    return SkillCategory.other;
  }

  String _generateId() {
    return DateTime.now().millisecondsSinceEpoch.toRadixString(36) +
        (DateTime.now().microsecond % 1000).toRadixString(36);
  }

  /// Cleanup ephemeral session
  Future<void> _cleanupEphemeralSession() async {
    if (_ephemeralSessionId == null) return;
    try {
      await _client.archiveSession(
        sessionId: _ephemeralSessionId!,
        stopActivity: true,
      );
    } catch (_) {
      // Ignore cleanup errors
    } finally {
      _ephemeralSessionId = null;
    }
  }

  /// Cancel ongoing summarization
  void cancel() {
    if (_ephemeralSessionId != null) {
      _cleanupEphemeralSession();
    }
  }
}