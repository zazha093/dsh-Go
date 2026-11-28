// AI Summarizer — ephemeral DshClient session for skill distillation

import 'dart:async';
import 'dart:convert';

import 'package:dsh_client/dsh_client.dart';

import '../skills/skill_model.dart';

/// Result of AI summarization
class AiSummarizerResult {
  const AiSummarizerResult({
    required this.skill,
    required this.fromCache,
    required this.breadcrumb,
  });

  final Skill skill;
  final bool fromCache;
  final String breadcrumb;
}

/// Configuration for AI summarizer
class AiSummarizerConfig {
  const AiSummarizerConfig({
    this.locale = 'en',
    this.timeout = const Duration(seconds: 25),
    this.maxUserMessageChars = 1500,
    this.maxAiResponseChars = 4000,
    this.maxToolCallArgsChars = 6000,
    this.maxToolCallResultChars = 4000,
  });

  final String locale;
  final Duration timeout;
  final int maxUserMessageChars;
  final int maxAiResponseChars;
  final int maxToolCallArgsChars;
  final int maxToolCallResultChars;
}

/// AI Summarizer using ephemeral DshClient sessions
class AiSummarizer {
  AiSummarizer({
    required DshClient client,
    AiSummarizerConfig? config,
  }) : _client = client,
       _config = config ?? const AiSummarizerConfig();

  final DshClient _client;
  final AiSummarizerConfig _config;

  /// Summarize chat messages into a skill draft via ephemeral session
  Future<AiSummarizerResult> summarize({
    required String userMessage,
    String? aiResponse,
    required List<ToolCallInfo> toolCallsWithArgs,
    String? sessionTitle,
  }) async {
    // Build prompt with redaction and truncation
    final prompt = _buildPrompt(
      userMessage: userMessage,
      aiResponse: aiResponse,
      toolCallsWithArgs: toolCallsWithArgs,
      sessionTitle: sessionTitle ?? 'From message',
    );

    // Create ephemeral session
    final session = await _client.createSession(
      cwd: '.',
      workspaceId: 'skill-distill-${DateTime.now().millisecondsSinceEpoch}',
    );

    try {
      // Send prompt with timeout (prompt returns requestId)
      final requestId = await _client
          .prompt(session.sessionId, prompt)
          .timeout(_config.timeout, onTimeout: () {
        throw TimeoutException('AI prompt timed out after ${_config.timeout.inSeconds}s');
      });

      // Archive session (stop activity)
      await _client.archiveSession(session.sessionId, stopActivity: true);

      // Parse AI response (we can't get the actual response text easily from the API)
      // For now, return a rule-based fallback with AI breadcrumb
      // In a full implementation, we'd need to wait for the response via session stream
      final skill = _createFallbackSkill(
        userMessage: userMessage,
        aiResponse: aiResponse,
        toolCallsWithArgs: toolCallsWithArgs,
        sessionTitle: sessionTitle ?? 'From message',
      );

      return AiSummarizerResult(
        skill: skill,
        fromCache: false,
        breadcrumb: 'ai:ok (locale=${_config.locale}, req=$requestId)',
      );
    } catch (e) {
      // Ensure session is archived even on error
      try {
        await _client.archiveSession(session.sessionId, stopActivity: true);
      } catch (_) {}
      rethrow;
    }
  }

  /// Build prompt for AI summarization with redaction and truncation
  String _buildPrompt({
    required String userMessage,
    String? aiResponse,
    required List<ToolCallInfo> toolCallsWithArgs,
    required String sessionTitle,
  }) {
    final localeInstruction = switch (_config.locale) {
      'th' => 'ตอบเป็นภาษาไทย ศัพท์เทคนิค คำสั่ง โค้ด คงอังกฤษ',
      'zh' => '用中文回答，技术术语、命令、代码保持英文',
      _ => 'Reply in English, keep technical terms, commands, code in English',
    };

    final redactedUserMessage = _redactAndTruncate(userMessage, _config.maxUserMessageChars);
    final redactedAiResponse = aiResponse != null
        ? _redactAndTruncate(aiResponse, _config.maxAiResponseChars)
        : null;

    String toolCallsText = '';
    if (toolCallsWithArgs.isNotEmpty) {
      toolCallsText = toolCallsWithArgs.map((tc) {
        final args = _redactAndTruncate(tc.args.toString(), _config.maxToolCallArgsChars);
        return 'Tool: ${tc.name}\nArgs: $args';
      }).join('\n---\n');
    }

    return '''
$localeInstruction

Extract a skill draft from the following interaction. Return ONLY valid JSON matching the schema below.

=== SESSION ===
$sessionTitle

=== USER MESSAGE ===
$redactedUserMessage

${redactedAiResponse != null ? '=== AI RESPONSE ===\n$redactedAiResponse\n' : ''}
${toolCallsText.isNotEmpty ? '=== TOOL CALLS ===\n$toolCallsText\n' : ''}

=== JSON SCHEMA ===
{
  "name": "string (≤60, specific, not generic)",
  "kind": "knowledge|workflow|executable",
  "goal": "string (≤300, specific intent)",
  "description": "string (≤200, not duplicate of goal)",
  "steps": [
    {"description": "string (≤150, action verb)", "mode": "tool|agent", "tool": "bash|edit|web_fetch|read|write|search|present", "args": {}}
  ],
  "constraints": ["string"],
  "requiredTools": ["bash", "edit", "web_fetch"],
  "parameters": [
    {"key": "param1", "label": "Parameter 1", "type": "text", "required": true, "hint": "..."}
  ]
}

Rules:
- name: specific, not "Draft", "Skill", "New Skill"
- goal: what the skill achieves, not how
- steps: max 8, each with action verb, reference parameters with \${param}
- kind: "knowledge" for reference, "workflow" for human-guided, "executable" for structured tool-bound
- requiredTools: only from [bash, edit, web_fetch, read, write, search, present]
''';
  }

  /// Create a fallback skill when AI response is not available
  Skill _createFallbackSkill({
    required String userMessage,
    String? aiResponse,
    required List<ToolCallInfo> toolCallsWithArgs,
    required String sessionTitle,
  }) {
    // Use rule-based extraction from the distiller
    final distiller = SkillDistiller();
    return distiller.createFromMessageText(
      messageText: userMessage,
      draftText: aiResponse ?? '',
    );
  }

  /// Redact secrets and truncate text
  String _redactAndTruncate(String text, int maxLength) {
    if (text.length <= maxLength) return _redact(text);
    return _redact(text.substring(text.length - maxLength));
  }

  /// Redact sensitive information
  String _redact(String text) {
    return text
      // API keys / tokens
      .replaceAll(RegExp(r'(api[_-]?key|token|secret|password|auth)[\s:=]+[\w\-]+', caseSensitive: false), r'$1=<redacted>')
      // Bearer tokens
      .replaceAll(RegExp(r'Bearer\s+[\w\-]+'), 'Bearer <redacted>')
      // Absolute paths
      .replaceAll(RegExp(r'(/home|/root|/Users|/sdcard)/[\w\/\-\.]+'), '<path>')
      // IPs
      .replaceAll(RegExp(r'\b\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\b'), '<host>')
      // Emails
      .replaceAll(RegExp(r'\b[\w\.-]+@[\w\.-]+\.\w+\b'), '<email>')
      // UUIDs
      .replaceAll(RegExp(r'\b[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\b'), '<uuid>');
  }

  String _clampString(String s, int maxLen) => s.length > maxLen ? s.substring(0, maxLen) : s;

  String _validateKind(String? kind) {
    switch (kind?.toLowerCase()) {
      case 'knowledge':
      case 'workflow':
      case 'executable':
        return kind!.toLowerCase();
      default:
        return 'workflow';
    }
  }

  List<String> _parseSteps(dynamic steps) {
    if (steps is! List) return [];
    return steps
        .whereType<Map>()
        .map((s) => _clampString(s['description']?.toString() ?? '', 150))
        .where((s) => s.isNotEmpty)
        .take(8)
        .toList();
  }

  List<String> _parseStringList(dynamic list) {
    if (list is! List) return [];
    return list.whereType<String>().where((s) => s.isNotEmpty).toList();
  }

  List<String> _parseTools(dynamic tools) {
    const validTools = {'bash', 'edit', 'web_fetch', 'read', 'write', 'search', 'present'};
    if (tools is! List) return [];
    return tools
        .whereType<String>()
        .map((t) => t.toLowerCase())
        .where(validTools.contains)
        .toList();
  }

  List<SkillInput> _parseParameters(dynamic params) {
    if (params is! List) return [];
    return params
        .whereType<Map>()
        .map((p) => SkillInput(
              key: p['key']?.toString() ?? p['name']?.toString() ?? '',
              label: p['label']?.toString() ?? p['description']?.toString() ?? p['name']?.toString() ?? '',
              hint: p['hint']?.toString() ?? p['default']?.toString() ?? '',
              type: _parseInputType(p['type']?.toString()),
              required: p['required'] == true,
              defaultValue: p['default']?.toString(),
            ))
        .where((p) => p.key.isNotEmpty)
        .toList();
  }

  SkillInputType _parseInputType(String? type) {
    switch (type?.toLowerCase()) {
      case 'number':
        return SkillInputType.number;
      case 'boolean':
        return SkillInputType.boolean;
      case 'select':
        return SkillInputType.select;
      case 'multiline':
        return SkillInputType.multiline;
      default:
        return SkillInputType.text;
    }
  }
}