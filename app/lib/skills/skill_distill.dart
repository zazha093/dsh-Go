// Skill Distillation — extract a reusable skill formula from a completed session
//
// Analyzes the session's conversation history, tool usage, and outcomes to
// create a skill with: goal, steps, constraints, required tools, user inputs.

import 'package:dsh_client/dsh_client.dart';

import '../share_code/conversation_redact.dart';
import 'skill_model.dart';

/// Distills a skill from a completed session.
class SkillDistiller {
  /// Distill a skill from a session by analyzing its history.
  ///
  /// This is the main entry point. It fetches the session history,
  /// analyzes the conversation, and returns a skill formula.
  static Future<Skill> distillFromSession({
    DshClient? client,
    required String sessionId,
    required String sessionTitle,
  }) async {
    client ??= throw StateError(
        'DshClient is required for distillFromSession. '
        'Pass a client or ensure a default is available via the runtime bridge.');
    // Fetch session history
    final events = await _fetchAllHistory(client, sessionId);

    if (events.isEmpty) {
      // Fallback to template if no history
      return _createTemplateSkill(sessionId, sessionTitle);
    }

    // Analyze the events to create a skill
    return _analyzeHistory(
      sessionId: sessionId,
      sessionTitle: sessionTitle,
      events: events,
    );
  }

  /// Fetch all history for a session by paging through it.
  static Future<List<SessionLogEvent>> _fetchAllHistory(
    DshClient? client,
    String sessionId,
  ) async {
    final allEvents = <SessionLogEvent>[];
    int? beforeSeq;
    const pageSize = 500;
    bool hasMore = true;

    // First, get the latest events to find the cursor
    // We need to know the latest seq to start paging backwards
    // For simplicity, we'll use a large throughSeq and page backwards
    // In practice, we'd get the latest seq from the session list or a snapshot

    // Start with a very large throughSeq to get the latest page
    const maxSeq = 1 << 30;
    int? currentBeforeSeq;

    while (hasMore && allEvents.length < 5000) {
      // Limit total events to prevent memory issues
      final page = await client.history(
        sessionId,
        throughSeq: maxSeq,
        beforeSeq: currentBeforeSeq,
        maxMessages: pageSize,
      );

      if (page.events.isEmpty) break;

      allEvents.addAll(page.events);
      hasMore = page.hasMore;

      if (page.events.isNotEmpty) {
        currentBeforeSeq = page.events.first.seq;
      } else {
        break;
      }

      if (!hasMore) break;
    }

    // Sort events by seq (oldest first)
    allEvents.sort((a, b) => a.seq.compareTo(b.seq));

    return allEvents;
  }

  /// Analyze history events to create a skill.
  static Skill _analyzeHistory({
    required String sessionId,
    required String sessionTitle,
    required List<SessionLogEvent> events,
  }) {
    final now = DateTime.now();
    final name = _generateSkillName(sessionTitle);

    // Extract information from events
    final goal = _extractGoal(events, sessionTitle);
    final steps = _extractSteps(events);
    final constraints = _extractConstraints(events);
    final requiredTools = _extractRequiredTools(events);
    final userInputs = _extractUserInputs(events);
    final category = _inferCategoryFromEvents(events, sessionTitle);

    // Redact secrets from all extracted text
    return Skill(
      id: _generateId(),
      name: name,
      description: redactText('Distilled from session: $sessionTitle'),
      goal: redactText(goal),
      steps: steps.map(redactText).toList(),
      constraints: constraints.map(redactText).toList(),
      requiredTools: requiredTools,
      userInputs: userInputs.map((input) => SkillInput(
        key: input.key,
        label: redactText(input.label),
        hint: redactText(input.hint),
        type: input.type,
        required: input.required,
        defaultValue: input.defaultValue != null ? redactText(input.defaultValue!) : null,
        options: input.options?.map(redactText).toList(),
      )).toList(),
      createdAt: DateTime.now(),
      sourceSessionId: sessionId,
      sourceSessionTitle: sessionTitle,
      category: category,
    );
  }

  /// Extract the overall goal from events.
  static String _extractGoal(List<SessionLogEvent> events, String fallbackTitle) {
    // Look for the first user message that seems like a goal/task
    for (final event in events) {
      if (event is UserMessageEvent) {
        final text = event.message.text.trim();
        if (text.isNotEmpty && text.length > 10) {
          // Skip very short messages, system prompts, etc.
          if (!text.startsWith('/') && !text.startsWith('@')) {
            return text.length > 200 ? '${text.substring(0, 200)}...' : text;
          }
        }
      }
    }

    // Fallback: use session title or generic goal
    return 'Achieve the same outcome as the original session: $fallbackTitle';
  }

  /// Extract step-by-step workflow from tool calls and user prompts.
  static List<String> _extractSteps(List<SessionLogEvent> events) {
    final steps = <String>[];

    for (final event in events) {
      if (event is ToolCallEvent) {
        final toolName = event.name;
        final args = event.arguments;

        String step;
        switch (toolName) {
          case 'bash':
            step = 'Run command: $args';
            break;
          case 'edit':
          case 'str_replace_editor':
            step = 'Edit file: $args';
            break;
          case 'write':
            step = 'Write file: $args';
            break;
          case 'web_fetch':
            step = 'Fetch web page: $args';
            break;
          case 'web_search':
            step = 'Search web: $args';
            break;
          case 'read':
            step = 'Read file: $args';
            break;
          default:
            step = 'Use $toolName: $args';
        }
        steps.add(step);
      } else if (event is UserMessageEvent && event.isHumanPrompt) {
        final text = event.message.text.trim();
        if (text.isNotEmpty && text.length > 5 && !text.startsWith('/')) {
          // This is a user instruction, add as a step
          final shortText = text.length > 100 ? '${text.substring(0, 100)}...' : text;
          steps.add('User instruction: $shortText');
        }
      }
    }

    // If no steps found, provide generic steps
    if (steps.isEmpty) {
      steps.addAll([
        'Review the original session context',
        'Identify the key tools and patterns used',
        'Execute the workflow step by step',
        'Verify the results match expectations',
      ]);
    }

    // Limit to reasonable number of steps
    return steps.take(20).toList();
  }

  /// Extract constraints from errors, rejections, corrections.
  static List<String> _extractConstraints(List<SessionLogEvent> events) {
    final constraints = <String>[];

    // Always include the no-secrets constraint
    constraints.add('Do not store secrets (API keys, tokens, passwords)');

    for (final event in events) {
      if (event is ToolResultEvent && event.isError) {
        // Extract constraint from error
        final error = event.failure?.reason ?? '';
        if (error.isNotEmpty) {
          constraints.add('Avoid: $error');
        }
      } else if (event is ApprovalDecidedEvent && event.outcome != ApprovalOutcome.allowedOnce) {
        constraints.add('Approval was rejected for ${event.approvalId}');
      } else if (event is NoticeChatItem && event.kind == 'error') {
        constraints.add('Error encountered: ${event.text}');
      }
    }

    // Add default constraints if none found
    if (constraints.length == 1) {
      constraints.addAll([
        'Follow the original session\'s approval patterns',
        'Use only tools available on the current device',
      ]);
    }

    // Limit constraints
    return constraints.take(10).toList();
  }

  /// Extract required tools from tool calls.
  static List<String> _extractRequiredTools(List<SessionLogEvent> events) {
    final tools = <String>{};

    for (final event in events) {
      if (event is ToolCallEvent) {
        tools.add(event.name);
      }
    }

    // Default tools if none found
    if (tools.isEmpty) {
      tools.addAll(['bash', 'edit']);
    }

    return tools.toList()..sort();
  }

  /// Extract user inputs from questions asked and parameters used.
  static List<SkillInput> _extractUserInputs(List<SessionLogEvent> events) {
    final inputs = <SkillInput>[];
    final seenKeys = <String>{};

    for (final event in events) {
      if (event is UserQuestionRequestedEvent) {
        for (final question in event.request.questions) {
          final key = question.name;
          if (seenKeys.add(key)) {
            inputs.add(SkillInput(
              key: key,
              label: question.prompt,
              hint: question.description ?? 'Enter value for $key',
              type: _inferInputType(question),
              required: true,
              defaultValue: question.defaultValue,
              options: question.options,
            ));
          }
        }
      } else if (event is ToolCallEvent) {
        // Infer inputs from tool arguments that look like parameters
        try {
          final args = event.arguments.trim();
          if (args.isNotEmpty && args.startsWith('{')) {
            final map = <String, dynamic>{};
            // Simple JSON parsing for common patterns
            // In practice, you'd use jsonDecode
          }
        } catch (_) {}
      }
    }

    return inputs;
  }

  /// Infer input type from question.
  static SkillInputType _inferInputType(Question question) {
    // Simple heuristic based on question text
    final prompt = question.prompt.toLowerCase();
    if (prompt.contains('yes') || prompt.contains('no') || prompt.contains('confirm')) {
      return SkillInputType.boolean;
    }
    if (prompt.contains('number') || prompt.contains('count') || prompt.contains('port')) {
      return SkillInputType.number;
    }
    if (question.options != null && question.options!.isNotEmpty) {
      return SkillInputType.select;
    }
    if (prompt.contains('describe') || prompt.contains('explain') || prompt.contains('details')) {
      return SkillInputType.multiline;
    }
    return SkillInputType.text;
  }

  /// Infer category from events and title.
  static SkillCategory _inferCategoryFromEvents(List<SessionLogEvent> events, String title) {
    final lowerTitle = title.toLowerCase();
    final toolNames = <String>{};

    for (final event in events) {
      if (event is ToolCallEvent) {
        toolNames.add(event.name.toLowerCase());
      }
    }

    final allText = '$lowerTitle ${toolNames.join(' ')}';

    if (allText.contains('code') || allText.contains('develop') || allText.contains('program') ||
        allText.contains('debug') || allText.contains('refactor') || allText.contains('review') ||
        allText.contains('git') || allText.contains('build') || allText.contains('test') ||
        toolNames.contains('edit') || toolNames.contains('write') || toolNames.contains('bash')) {
      return SkillCategory.development;
    }
    if (allText.contains('auto') || allText.contains('script') || allText.contains('deploy') ||
        allText.contains('ci') || allText.contains('cd') || allText.contains('pipeline') ||
        toolNames.contains('bash')) {
      return SkillCategory.automation;
    }
    if (allText.contains('analy') || allText.contains('report') || allText.contains('summar') ||
        allText.contains('data') || allText.contains('query') || allText.contains('metric') ||
        allText.contains('log') || allText.contains('monitor') || toolNames.contains('web_fetch')) {
      return SkillCategory.analysis;
    }
    if (allText.contains('product') || allText.contains('todo') || allText.contains('note') ||
        allText.contains('brief') || allText.contains('plan') || allText.contains('schedule') ||
        allText.contains('meeting') || allText.contains('email')) {
      return SkillCategory.productivity;
    }

    return SkillCategory.other;
  }

  /// Create a template skill based on session title (fallback when history not available)
  static Skill createTemplateSkill(String sessionId, String sessionTitle) {
    final now = DateTime.now();
    final name = _generateSkillName(sessionTitle);

    return Skill(
      id: _generateId(),
      name: name,
      description: redactText('Distilled from session: $sessionTitle'),
      goal: redactText('Achieve the same outcome as the original session'),
      steps: [
        'Review the original session context',
        'Identify the key tools and patterns used',
        'Execute the workflow step by step',
        'Verify the results match expectations',
      ].map(redactText).toList(),
      constraints: [
        'Do not store secrets (API keys, tokens, passwords)',
        'Follow the original session\'s approval patterns',
        'Use only tools available on the current device',
      ].map(redactText).toList(),
      requiredTools: inferToolsFromTitle(sessionTitle),
      userInputs: inferInputsFromTitle(sessionTitle),
      createdAt: now,
      sourceSessionId: sessionId,
      sourceSessionTitle: sessionTitle,
      category: inferCategoryFromTitle(sessionTitle),
    );
  }

  /// Generate a skill name from session title
  static String generateSkillName(String sessionTitle) {
    var name = sessionTitle.trim();
    name = name.replaceAll(RegExp(r'^(chat|session|conversation)\s*[:\-]\s*', caseSensitive: false), '');
    if (name.isNotEmpty) {
      name = name[0].toUpperCase() + name.substring(1);
    }
    if (name.length > 50) {
      name = name.substring(0, 47) + '...';
    }
    return name.isEmpty ? 'Unnamed Skill' : name;
  }

  /// Infer required tools from session title
  static List<String> inferToolsFromTitle(String title) {
    final lower = title.toLowerCase();
    final tools = <String>{};

    if (lower.contains('code') || lower.contains('develop') || lower.contains('program') ||
        lower.contains('debug') || lower.contains('refactor') || lower.contains('review')) {
      tools.addAll(['bash', 'edit', 'write']);
    }
    if (lower.contains('web') || lower.contains('fetch') || lower.contains('search') ||
        lower.contains('scrape') || lower.contains('api')) {
      tools.addAll(['web_fetch', 'web_search']);
    }
    if (lower.contains('file') || lower.contains('read') || lower.contains('write') ||
        lower.contains('create') || lower.contains('edit')) {
      tools.addAll(['read', 'write', 'edit']);
    }
    if (lower.contains('git') || lower.contains('commit') || lower.contains('push') ||
        lower.contains('pull') || lower.contains('merge')) {
      tools.add('bash');
    }
    if (lower.contains('test') || lower.contains('build') || lower.contains('deploy') ||
        lower.contains('ci') || lower.contains('cd')) {
      tools.add('bash');
    }
    if (lower.contains('analy') || lower.contains('report') || lower.contains('summar') ||
        lower.contains('data') || lower.contains('query')) {
      tools.addAll(['bash', 'web_fetch']);
    }

    if (tools.isEmpty) {
      tools.addAll(['bash', 'edit']);
    }

    return tools.toList()..sort();
  }

  /// Infer user inputs from session title
  static List<SkillInput> inferInputsFromTitle(String title) {
    final lower = title.toLowerCase();
    final inputs = <SkillInput>[];

    if (lower.contains('deploy') || lower.contains('server') || lower.contains('host')) {
      inputs.add(SkillInput(
        key: 'target_host',
        label: 'Target Host',
        hint: 'e.g., production, staging, localhost',
        type: SkillInputType.text,
        required: true,
      ));
    }
    if (lower.contains('branch') || lower.contains('git') || lower.contains('repo')) {
      inputs.add(SkillInput(
        key: 'branch',
        label: 'Git Branch',
        hint: 'e.g., main, feature/xyz',
        type: SkillInputType.text,
        required: true,
      ));
    }
    if (lower.contains('environment') || lower.contains('env') || lower.contains('config')) {
      inputs.add(SkillInput(
        key: 'environment',
        label: 'Environment',
        hint: 'e.g., development, staging, production',
        type: SkillInputType.select,
        required: true,
        options: ['development', 'staging', 'production'],
      ));
    }
    if (lower.contains('version') || lower.contains('release') || lower.contains('tag')) {
      inputs.add(SkillInput(
        key: 'version',
        label: 'Version',
        hint: 'e.g., v1.0.0, 2.5.0',
        type: SkillInputType.text,
        required: true,
      ));
    }

    return inputs;
  }

  /// Infer category from session title
  static SkillCategory inferCategoryFromTitle(String title) {
    final lower = title.toLowerCase();

    if (lower.contains('code') || lower.contains('develop') || lower.contains('program') ||
        lower.contains('debug') || lower.contains('refactor') || lower.contains('review') ||
        lower.contains('git') || lower.contains('build') || lower.contains('test')) {
      return SkillCategory.development;
    }
    if (lower.contains('auto') || lower.contains('script') || lower.contains('deploy') ||
        lower.contains('ci') || lower.contains('cd') || lower.contains('pipeline')) {
      return SkillCategory.automation;
    }
    if (lower.contains('analy') || lower.contains('report') || lower.contains('summar') ||
        lower.contains('data') || lower.contains('query') || lower.contains('metric') ||
        lower.contains('log') || lower.contains('monitor')) {
      return SkillCategory.analysis;
    }
    if (lower.contains('product') || lower.contains('todo') || lower.contains('note') ||
        lower.contains('brief') || lower.contains('plan') || lower.contains('schedule') ||
        lower.contains('meeting') || lower.contains('email')) {
      return SkillCategory.productivity;
    }

    return SkillCategory.other;
  }

  /// Generate a unique ID
  static String _generateId() {
    return DateTime.now().millisecondsSinceEpoch.toRadixString(36) +
        (DateTime.now().microsecond % 1000).toRadixString(36);
  }
}