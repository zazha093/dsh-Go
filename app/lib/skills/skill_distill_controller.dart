// Skill Distillation Controller — manages AI summarization with cancellation and safety

import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dsh_client/dsh_client.dart';

import 'distill/types.dart';
import 'skill_distill.dart';
import 'skill_model.dart';

/// Simple cancellation token for in-flight operations
class CancelToken {
  final Completer<void> _completer = Completer<void>();
  bool _cancelled = false;

  bool get isCancelled => _cancelled;

  void cancel() {
    if (!_cancelled) {
      _cancelled = true;
      _completer.complete();
    }
  }

  Future<void> get future => _completer.future;

  void throwIfCancelled() {
    if (_cancelled) {
      throw CancelledException('Operation cancelled');
    }
  }
}

/// Exception thrown when operation is cancelled
class CancelledException implements Exception {
  final String message;
  const CancelledException(this.message);
  
  @override
  String toString() => 'CancelledException: $message';
}

/// Controller for skill distillation with AI summarization support
class SkillDistillController extends AutoDisposeNotifier<DistillState> {
  // Cancellation token for in-flight AI requests
  CancelToken? _cancelToken;
  
  // Track if controller is disposed
  bool _isDisposed = false;

  @override
  DistillState build() {
    // Listen for disposal
    ref.onDispose(() {
      _isDisposed = true;
      _cancelToken?.cancel();
      _cancelToken = null;
    });

    return const DistillState();
  }

  /// Start distillation from text (message or turn-based)
  /// Returns the rule-based draft instantly, then runs AI summarization in background
  Future<void> distillFromText(DistillInput input) async {
    // Cancel any in-flight request
    _cancelToken?.cancel();
    _cancelToken = CancelToken();

    // Check if already disposed before starting
    if (_isDisposed) return;

    // 1. Generate rule-based draft INSTANTLY (synchronous)
    final ruleBasedSkill = _generateRuleBasedDraft(input);
    
    // Check disposed/mounted before state update
    if (_isDisposed) return;
    state = state.copyWith(
      status: DistillStatus.running,
      skill: ruleBasedSkill,
      aiProposedSkill: null,
      error: null,
      progress: 0.1,
    );

    // 2. If no DshClient, skip AI and mark as ready with rule-based only
    if (input.dshClient == null) {
      if (_isDisposed) return;
      state = state.copyWith(
        status: DistillStatus.ready,
        progress: 1.0,
      );
      return;
    }

    // 3. Run AI summarization with timeout and cancellation
    try {
      if (_isDisposed) return;
      state = state.copyWith(progress: 0.3);

      final aiSkill = await _runAISummarization(input, _cancelToken!);
      
      // Check cancelled after await
      if (_cancelToken!.isCancelled || _isDisposed) return;

      // 4. Validate AI result field-by-field with rule-based fallback
      final validatedSkill = _validateAndMergeDrafts(aiSkill, ruleBasedSkill);
      
      if (_isDisposed) return;
      state = state.copyWith(
        status: DistillStatus.ready,
        aiProposedSkill: validatedSkill,
        progress: 1.0,
      );
    } on CancelledException {
      // User cancelled - silent discard
      if (_isDisposed) return;
      state = state.copyWith(
        status: DistillStatus.cancelled,
        aiProposedSkill: null,
        progress: 0.0,
      );
    } on TimeoutException {
      // AI timeout - keep rule-based, mark as ready
      if (_isDisposed) return;
      state = state.copyWith(
        status: DistillStatus.ready,
        aiProposedSkill: null,
        error: 'AI summarization timed out, using rule-based draft',
        progress: 1.0,
      );
    } catch (e) {
      // Other errors - keep rule-based, mark as ready with error
      if (_isDisposed) return;
      state = state.copyWith(
        status: DistillStatus.ready,
        aiProposedSkill: null,
        error: 'AI summarization failed: $e',
        progress: 1.0,
      );
    }
  }

  /// Generate rule-based draft synchronously (instant)
  Skill _generateRuleBasedDraft(DistillInput input) {
    if (input.toolCallsWithArgs != null && input.toolCallsWithArgs!.isNotEmpty) {
      return SkillDistiller.createFromTurn(
        userMessage: input.userMessage,
        aiResponse: input.aiResponse,
        toolCallsWithArgs: input.toolCallsWithArgs!,
        sessionTitle: input.sessionTitle,
      );
    } else {
      return SkillDistiller.createFromMessageText(
        userMessage: input.userMessage,
        aiResponse: input.aiResponse,
        toolCalls: input.toolCalls,
        sessionTitle: input.sessionTitle,
      );
    }
  }

  /// Run AI summarization via ephemeral DshClient session
  Future<Skill> _runAISummarization(DistillInput input, CancelToken cancelToken) async {
    final client = input.dshClient!;
    
    // Build prompt with redacted/truncated inputs
    final prompt = _buildPrompt(input);
    
    // Create ephemeral session
    final session = await client.createSession(
      cwd: '.',
      workspaceId: 'skill-distill-${DateTime.now().millisecondsSinceEpoch}',
    );
    
    // Listen for cancellation and cancel the session
    final cancelListener = cancelToken.future.then((_) {
      client.cancel(session.id).catchError((_) {});
    });
    
    try {
      // Check cancellation before prompt
      cancelToken.throwIfCancelled();
      
      // Send prompt with 25s timeout
      final response = await client.prompt(
        sessionId: session.id,
        message: prompt,
      ).timeout(const Duration(seconds: 25), onTimeout: () {
        throw TimeoutException('AI prompt timed out');
      });
      
      cancelToken.throwIfCancelled();
      
      // Archive session (stop activity)
      await client.archiveSession(session.id, stopActivity: true);
      
      // Parse AI response
      return _parseAIResponse(response.text);
    } finally {
      // Clean up cancel listener
      cancelListener.ignore();
      // Ensure session is archived even on error
      try {
        await client.archiveSession(session.id, stopActivity: true);
      } catch (_) {
        // Ignore archive errors
      }
    }
  }

  /// Build prompt for AI summarization with redaction and truncation
  String _buildPrompt(DistillInput input) {
    final userMessage = _redactAndTruncate(input.userMessage, 1500);
    final aiResponse = input.aiResponse != null ? _redactAndTruncate(input.aiResponse!, 4000) : null;
    
    String toolCallsText = '';
    if (input.toolCallsWithArgs != null && input.toolCallsWithArgs!.isNotEmpty) {
      toolCallsText = input.toolCallsWithArgs!.map((tc) {
        final args = _redactAndTruncate(tc.args.toString(), 6000);
        return 'Tool: ${tc.tool}\nArgs: $args\nResult: ${_redactAndTruncate(tc.result ?? '', 4000)}';
      }).join('\n---\n');
    } else if (input.toolCalls != null && input.toolCalls!.isNotEmpty) {
      toolCallsText = 'Tools used: ${input.toolCalls!.join(', ')}';
    }

    final locale = _detectLocale(input.userMessage);
    final localeInstruction = switch (locale) {
      'th' => 'ตอบเป็นภาษาไทย ศัพท์เทคนิค คำสั่ง โค้ด คงอังกฤษ',
      'zh' => '用中文回答，技术术语、命令、代码保持英文',
      _ => 'Reply in English, keep technical terms, commands, code in English',
    };

    return '''
$localeInstruction

Extract a skill draft from the following interaction. Return ONLY valid JSON matching the schema below.

=== USER MESSAGE ===
$userMessage

${aiResponse != null ? '=== AI RESPONSE ===\n$aiResponse\n' : ''}
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
    {"name": "param1", "type": "string", "description": "...", "required": true, "default": "..."}
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

  /// Detect locale from text (simple heuristic)
  String _detectLocale(String text) {
    final thaiRegex = RegExp(r'[\u0E00-\u0E7F]');
    final chineseRegex = RegExp(r'[\u4e00-\u9fff]');
    
    int thaiCount = thaiRegex.allMatches(text).length;
    int chineseCount = chineseRegex.allMatches(text).length;
    int total = text.length;
    
    if (thaiCount > total * 0.1) return 'th';
    if (chineseCount > total * 0.1) return 'zh';
    return 'en';
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

  /// Parse AI response JSON
  Skill _parseAIResponse(String response) {
    // Extract JSON from response (handle markdown fences)
    String jsonText = response.trim();
    if (jsonText.startsWith('```')) {
      final fenceEnd = jsonText.indexOf('```', 3);
      if (fenceEnd > 3) {
        jsonText = jsonText.substring(3, fenceEnd).trim();
        if (jsonText.startsWith('json')) {
          jsonText = jsonText.substring(4).trim();
        }
      }
    }
    
    // Find first valid JSON object
    int braceStart = jsonText.indexOf('{');
    int braceEnd = jsonText.lastIndexOf('}');
    if (braceStart >= 0 && braceEnd > braceStart) {
      jsonText = jsonText.substring(braceStart, braceEnd + 1);
    }

    final Map<String, dynamic> data = jsonDecode(jsonText) as Map<String, dynamic>;
    
    return Skill(
      id: 'draft',
      name: _clampString(data['name']?.toString() ?? 'Unnamed Skill', 60),
      kind: _validateKind(data['kind']?.toString()),
      goal: _clampString(data['goal']?.toString() ?? '', 300),
      description: _clampString(data['description']?.toString() ?? '', 200),
      steps: _parseSteps(data['steps']),
      constraints: _parseStringList(data['constraints']),
      requiredTools: _parseTools(data['requiredTools']),
      userInputs: _parseParameters(data['parameters']),
      createdAt: DateTime.now(),
      category: SkillCategory.other,
      schemaVersion: 2,
    );
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
              key: p['name']?.toString() ?? '',
              label: p['description']?.toString() ?? p['name']?.toString() ?? '',
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
      case 'multiselect':
        return SkillInputType.multiSelect;
      default:
        return SkillInputType.text;
    }
  }

  /// Validate AI draft field-by-field, fall back to rule-based for failed fields
  Skill _validateAndMergeDrafts(Skill aiSkill, Skill ruleBasedSkill) {
    // For now, return AI skill as-is
    // Full field-level validation will be implemented in draft_validator.dart (Phase 4)
    return aiSkill;
  }

  /// Cancel any in-flight distillation
  void cancel() {
    _cancelToken?.cancel();
    _cancelToken = null;
    
    if (!_isDisposed) {
      state = state.copyWith(
        status: DistillStatus.cancelled,
        aiProposedSkill: null,
        progress: 0.0,
      );
    }
  }
}

/// Provider for the distillation controller
final skillDistillControllerProvider = NotifierProvider.autoDispose<SkillDistillController, DistillState>(
  SkillDistillController.new,
);