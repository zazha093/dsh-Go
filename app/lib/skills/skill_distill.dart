// Skill Distillation — extract a reusable skill formula from a completed session
//
// Analyzes the session's conversation history, tool usage, and outcomes to
// create a skill with: goal, steps, constraints, required tools, user inputs.

import 'package:dsh_client/dsh_client.dart';

import '../share_code/conversation_redact.dart';
import 'skill_model.dart';
import 'distill/heuristics.dart';

/// Result of script extraction from message text
class ExtractedScript {
  final String language;
  final String content;
  final List<String> steps;
  final Set<String> tools;
  
  const ExtractedScript({
    required this.language,
    required this.content,
    required this.steps,
    required this.tools,
  });
}

/// Extract scripts from message text (markdown code blocks)
ExtractedScript? extractScriptFromText(String text) {
  // Match markdown fenced code blocks: ```language ... ```
  final codeBlockRegex = RegExp(r'```(\w+)?\n([\s\S]*?)\n```');
  final matches = codeBlockRegex.allMatches(text);
  
  for (final match in matches) {
    final language = (match.group(1) ?? '').toLowerCase();
    final content = match.group(2) ?? '';
    
    // Only process shell-like scripts
    if (isShellScript(language, content)) {
      final steps = _extractStepsFromScriptContentImpl(content);
      final tools = _inferToolsFromScriptContentImpl(content);
      
      if (steps.isNotEmpty || tools.isNotEmpty) {
        return ExtractedScript(
          language: language,
          content: content,
          steps: steps,
          tools: tools,
        );
      }
    }
  }
  
  return null;
}

/// Check if the code block is a shell script
bool isShellScript(String language, String content) {
  // Explicit shell languages
  if (language == 'bash' || language == 'sh' || language == 'shell' || 
      language == 'zsh' || language == 'fish') {
    return true;
  }
  
  // No language specified but content looks like shell
  if (language.isEmpty) {
    final firstLine = content.trim().split('\n').first.toLowerCase();
    // Shebang check
    if (firstLine.startsWith('#!/bin/bash') || 
        firstLine.startsWith('#!/bin/sh') ||
        firstLine.startsWith('#!/usr/bin/env bash') ||
        firstLine.startsWith('#!/usr/bin/env sh')) {
      return true;
    }
    // Common shell commands at start
    if (firstLine.startsWith('set -') || 
        firstLine.startsWith('export ') ||
        firstLine.startsWith('mkdir ') ||
        firstLine.startsWith('tar ') ||
        firstLine.startsWith('rsync ') ||
        firstLine.startsWith('gzip ') ||
        firstLine.startsWith('sha256sum ') ||
        firstLine.startsWith('find ') ||
        firstLine.startsWith('grep ')) {
      return true;
    }
  }
  
  return false;
}

/// Extract meaningful steps from shell script content
List<String> _extractStepsFromScriptContentImpl(String content) {
  final steps = <String>[];
  final lines = content.split('\n');
  
  String? currentStep;
  
  for (final rawLine in lines) {
    final line = rawLine.trim();
    
    // Skip empty lines
    if (line.isEmpty) continue;
    
    // Handle comments - check for section markers in multiple languages
    if (line.startsWith('#')) {
      // Check if it's a section comment (e.g., "# Step 1: ..." or "## Backup" or Chinese/Thai equivalents)
      final commentText = line.replaceFirst(RegExp(r'^#+\s*'), '').trim();
      if (RegExp(r'^#+\s*(step|phase|stage|步骤|步驟|ขั้นตอน)\s*\d*', caseSensitive: false).hasMatch(line) ||
          RegExp(r'^#+\s*(backup|備份|备份|部署|deploy|同步|sync)', caseSensitive: false).hasMatch(line)) {
        if (currentStep != null) {
          steps.add(currentStep);
        }
        currentStep = commentText;
        continue;
      }
      // Skip other pure comments
      continue;
    }
    
    // Skip variable assignments that are just setup
    if (RegExp(r'^[A-Z_][A-Z0-9_]*\s*=').hasMatch(line)) {
      currentStep ??= 'Set up environment variables';
      continue;
    }
    
    // Skip function definitions for now (they're implementation details)
    if (RegExp(r'^\w+\s*\(\)\s*\{?').hasMatch(line) && line.endsWith('{')) {
      if (currentStep != null) {
        steps.add(currentStep);
      }
      currentStep = 'Define function: ${line.replaceFirst(RegExp(r'\s*\{?\s*$'), '').trim()}';
      continue;
    }
    
    // Detect actual commands
    if (isExecutableCommand(line)) {
      final commandDesc = describeCommand(line);
      // Filter out generic/unhelpful descriptions
      if (!_isGenericCommandDesc(commandDesc)) {
        if (currentStep != null) {
          steps.add(currentStep);
        }
        currentStep = commandDesc;
      }
    }
  }
  
  // Add the last step
  if (currentStep != null) {
    steps.add(currentStep);
  }
  
  // If no steps extracted but we have content, provide a generic step
  if (steps.isEmpty) {
    // Try to extract at least one meaningful command
    for (final rawLine in lines) {
      final line = rawLine.trim();
      if (line.isEmpty || line.startsWith('#')) continue;
      if (isExecutableCommand(line)) {
        final desc = describeCommand(line);
        if (!_isGenericCommandDesc(desc)) {
          steps.add(desc);
        }
        break;
      }
    }
  }
  
  // Filter out generic steps and limit
  return steps.where((s) => !_isGenericStep(s)).take(15).toList();
}

/// Check if a command description is too generic
bool _isGenericCommandDesc(String desc) {
  final lower = desc.toLowerCase();
  return lower == 'run: set -euo pipefail' ||
         lower == 'run: set -e' ||
         lower == 'run: export' ||
         lower.startsWith('run: ') && lower.length < 15;
}

/// Check if a step is too generic
bool _isGenericStep(String step) {
  final lower = step.toLowerCase().trim();
  // Filter out language identifiers and generic words
  return lower == 'script' || 
         lower == 'bash' || 
         lower == 'shell' || 
         lower == 'sh' ||
         lower == 'a script' ||
         lower == 'the script' ||
         lower == 'the bash script' ||
         lower == 'the shell script';
}

/// Check if a line is an executable command (not variable assignment, function, etc.)
bool isExecutableCommand(String line) {
  // Skip variable assignments
  if (RegExp(r'^[A-Z_][A-Z0-9_]*\s*=').hasMatch(line)) return false;
  // Skip function definitions
  if (RegExp(r'^\w+\s*\(\)\s*\{?').hasMatch(line)) return false;
  // Skip control structures (if, for, while, case)
  if (RegExp(r'^(if|for|while|case|select)\s').hasMatch(line)) return false;
  // Skip closing braces
  if (line == '}' || line == 'fi' || line == 'done' || line == 'esac') return false;
  // Skip empty or comments
  if (line.isEmpty || line.startsWith('#')) return false;
  // Skip export, declare, local, readonly
  if (RegExp(r'^(export|declare|local|readonly)\s').hasMatch(line)) return false;
  
  return true;
}

/// Describe a command in human-readable form
String describeCommand(String line) {
  // Extract the command name
  final parts = line.split(RegExp(r'\s+'));
  final cmd = parts.first;
  
  // Common commands with specific descriptions
  switch (cmd) {
    case 'tar':
      return 'Create compressed archive with tar';
    case 'gzip':
    case 'gunzip':
    case 'zcat':
      return 'Compress/decompress with gzip';
    case 'zip':
    case 'unzip':
      return 'Create/extract ZIP archive';
    case 'rsync':
      return 'Sync files with rsync';
    case 'cp':
      return 'Copy files';
    case 'mv':
      return 'Move/rename files';
    case 'mkdir':
      return 'Create directory';
    case 'rm':
    case 'rmdir':
      return 'Remove files/directories';
    case 'find':
      return 'Find files';
    case 'grep':
    case 'egrep':
    case 'fgrep':
      return 'Search text with grep';
    case 'sed':
      return 'Stream edit with sed';
    case 'awk':
      return 'Process text with awk';
    case 'curl':
    case 'wget':
      return 'Download with $cmd';
    case 'git':
      return 'Git: ${parts.length > 1 ? parts[1] : ''}'.trim();
    case 'ssh':
    case 'scp':
      return 'Remote operation: $cmd';
    case 'sha256sum':
    case 'sha512sum':
    case 'md5sum':
      return 'Generate checksum with $cmd';
    case 'chmod':
    case 'chown':
      return 'Change permissions/ownership';
    case 'ssh-keygen':
      return 'Generate SSH key';
    case 'openssl':
      return 'OpenSSL operation';
    case 'docker':
    case 'podman':
      return 'Container: ${parts.length > 1 ? parts[1] : ''}'.trim();
    case 'kubectl':
      return 'Kubernetes: ${parts.length > 1 ? parts[1] : ''}'.trim();
    case 'systemctl':
    case 'service':
      return 'System service: ${parts.length > 1 ? parts[1] : ''}'.trim();
    default:
      // Generic command description
      final args = parts.length > 1 ? parts.sublist(1).join(' ') : '';
      return 'Run: $cmd ${args.isNotEmpty ? args : ''}'.trim();
  }
}

/// Infer tools used in script content
Set<String> _inferToolsFromScriptContentImpl(String content) {
  final tools = <String>{};
  
  // Command patterns to detect (no duplicate keys)
  // Note: Excluded chmod, git, sh as they are often false positives
  // chmod: usage command, not a tool
  // git: often false positive from variable names
  // sh: often from shebang or variable names
  final commandPatterns = {
    'bash': [r'\bbash\b', r'#!/bin/bash', r'#!/usr/bin/env bash'],
    'tar': [r'\btar\b'],
    'gzip': [r'\bgzip\b', r'\bgunzip\b', r'\bzcat\b'],
    'zip': [r'\bzip\b', r'\bunzip\b'],
    'unzip': [r'\bunzip\b'],
    'rsync': [r'\brsync\b'],
    'cp': [r'\bcp\b'],
    'mv': [r'\bmv\b'],
    'mkdir': [r'\bmkdir\b'],
    'rm': [r'\brm\b', r'\brmdir\b'],
    'find': [r'\bfind\b'],
    'grep': [r'\bgrep\b', r'\begrep\b', r'\bfgrep\b'],
    'sed': [r'\bsed\b'],
    'awk': [r'\bawk\b'],
    'curl': [r'\bcurl\b'],
    'wget': [r'\bwget\b'],
    'ssh': [r'\bssh\b', r'\bscp\b'],
    'sha256sum': [r'\bsha256sum\b'],
    'sha512sum': [r'\bsha512sum\b'],
    'md5sum': [r'\bmd5sum\b'],
    'chown': [r'\bchown\b'],
    'ssh-keygen': [r'\bssh-keygen\b'],
    'openssl': [r'\bopenssl\b'],
    'docker': [r'\bdocker\b'],
    'podman': [r'\bpodman\b'],
    'kubectl': [r'\bkubectl\b'],
    'systemctl': [r'\bsystemctl\b'],
    'service': [r'\bservice\b'],
    'jq': [r'\bjq\b'],
    'cat': [r'\bcat\b'],
    'ls': [r'\bls\b'],
  };
  
  for (final entry in commandPatterns.entries) {
    final tool = entry.key;
    final patterns = entry.value;
    
    for (final pattern in patterns) {
      if (RegExp(pattern).hasMatch(content)) {
        tools.add(tool);
        break;
      }
    }
  }
  
  return tools;
}
SkillProvenance _makeDistilledProvenance(String sessionId, {String? messageId}) {
  return SkillProvenance(
    type: 'distilled',
    sourceSessionId: sessionId,
    sourceMessageId: messageId,
    createdAt: DateTime.now(),
    evidence: messageId != null 
        ? {'distilledFrom': {'session': sessionId, 'message': messageId}}
        : {'distilledFrom': {'session': sessionId}},
  );
}

/// Distills a skill from a completed session.
class SkillDistiller {
  /// Distill a skill from a session by analyzing its history.
  ///
  /// This is the main entry point. It fetches the session history,
  /// analyzes the conversation, and returns a skill formula.
  static Future<Skill> distillFromSession({
    required DshClient client,
    required String sessionId,
    required String sessionTitle,
  }) async {
    // Fetch session history
    final events = await _fetchAllHistory(client, sessionId);

    if (events.isEmpty) {
      // Fallback to template if no history
      return createTemplateSkill(sessionId, sessionTitle);
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
    DshClient client,
    String sessionId,
  ) async {
    final allEvents = <SessionLogEvent>[];
    const pageSize = 500;
    bool hasMore = true;

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
    final name = generateSkillName(sessionTitle);

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
      // v2 fields
      kind: 'workflow',
      schemaVersion: 2,
      provenance: _makeDistilledProvenance(sessionId),
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
      }
      // NoticeChatItem is not a SessionLogEvent, so we can't check for it here
      // Error constraints are already captured from ToolResultEvent
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
        final uqre = event as UserQuestionRequestedEvent;
        for (final question in uqre.request.questions) {
          final key = question.id;
          if (seenKeys.add(key)) {
            inputs.add(SkillInput(
              key: key,
              label: question.question,
              hint: question.detail ?? 'Enter value for $key',
              type: _inferInputType(question),
              required: true,
              defaultValue: null, // UserQuestion doesn't have defaultValue
              options: question.options.map((o) => o.label).toList(),
            ));
          }
        }
      } else if (event is ToolCallEvent) {
        // Infer inputs from tool arguments that look like parameters
        // (implementation omitted - would parse JSON arguments)
      }
    }

    return inputs;
  }

  /// Infer input type from question.
  static SkillInputType _inferInputType(UserQuestion question) {
    // Simple heuristic based on question text
    final prompt = question.question.toLowerCase();
    if (prompt.contains('yes') || prompt.contains('no') || prompt.contains('confirm')) {
      return SkillInputType.boolean;
    }
    if (prompt.contains('number') || prompt.contains('count') || prompt.contains('port')) {
      return SkillInputType.number;
    }
    if (question.options.isNotEmpty) {
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
    final name = generateSkillName(sessionTitle);

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
      // v2 fields
      kind: 'workflow',
      schemaVersion: 2,
      provenance: _makeDistilledProvenance(sessionId),
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
      name = '${name.substring(0, 47)}...';
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

  /// Extract skill name from user message and AI response
  static String extractSkillName(String userMessage, String? aiResponse, ExtractedScript? script) {
    // Try to extract a meaningful name from the user message intent
    final cleaned = _cleanMarkdown(userMessage).trim();
    
    // Look for common intent patterns
    final intentPatterns = [
      RegExp(r'(?:create|make|build|write|generate|script|backup|backup|sync|deploy)\s+(\w[\w\s]{2,40})', caseSensitive: false),
      RegExp(r'(?:for|to)\s+(\w[\w\s]{2,40})', caseSensitive: false),
    ];
    
    for (final pattern in intentPatterns) {
      final match = pattern.firstMatch(userMessage);
      if (match != null && match.groupCount >= 1) {
        final extracted = match.group(1)!.trim();
        if (extracted.length > 3 && extracted.length < 50) {
          return extracted[0].toUpperCase() + extracted.substring(1);
        }
      }
    }
    
    // Fallback: use first meaningful words from user message
    final words = cleaned.split(RegExp(r'\s+')).where((w) => w.length > 2).take(6).join(' ');
    if (words.length > 5 && words.length < 60) {
      return words[0].toUpperCase() + words.substring(1);
    }
    
    // Fallback to first 50 chars of cleaned message
    String name = _cleanMarkdown(userMessage).trim();
    if (name.length > 50) name = '${name.substring(0, 47)}...';
    if (name.isEmpty) name = 'Unnamed Skill';
    return name;
  }

  /// Extract goal from user message and script
  static String extractGoalFromMessage(String userMessage, String? aiResponse, ExtractedScript? script) {
    // Try to extract goal from user message intent
    final goalPatterns = [
      RegExp(r'(?:create|make|build|write|generate|script|backup|sync|deploy|setup|configure)\s+(?:a|an|the)?\s*([^.]{10,200})', caseSensitive: false),
      RegExp(r'(?:I want to|I need to|Please|Help me)\s+([^.]{10,200})', caseSensitive: false),
    ];
    
    for (final pattern in goalPatterns) {
      final match = pattern.firstMatch(userMessage);
      if (match != null && match.groupCount >= 1) {
        final goal = match.group(1)!.trim();
        // Filter out language identifiers and generic words
        final lowerGoal = goal.toLowerCase();
        if (lowerGoal == 'script' || lowerGoal == 'bash' || lowerGoal == 'shell' || 
            lowerGoal == 'a script' || lowerGoal == 'the script') {
          continue; // Skip generic identifiers
        }
        if (goal.length > 10 && goal.length < 300) {
          return goal[0].toUpperCase() + goal.substring(1);
        }
      }
    }
    
    // If script found, infer goal from script purpose (not just first command)
    if (script != null && script.content.isNotEmpty) {
      final lines = script.content.trim().split('\n');
      
      // Look for descriptive comments first
      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.startsWith('#') && trimmed.length > 10) {
          // Extract meaningful comment as goal
          final comment = trimmed.replaceFirst(RegExp(r'^#+\s*'), '').trim();
          // Skip if it's just a command name or too short
          if (comment.length > 10 && !RegExp(r'^(bash|sh|shell|script|set|export|mkdir|tar)\b').hasMatch(comment)) {
            return comment[0].toUpperCase() + comment.substring(1);
          }
        }
      }
      
      // Infer from script tools and content
      final toolNames = script.tools.join(' ');
      if (toolNames.contains('tar') || toolNames.contains('backup')) {
        return 'Create compressed backup archive';
      }
      if (toolNames.contains('git') || toolNames.contains('commit') || toolNames.contains('push')) {
        return 'Automate git workflow';
      }
      if (toolNames.contains('docker') || toolNames.contains('deploy')) {
        return 'Deploy application';
      }
      if (toolNames.contains('rsync') || toolNames.contains('sync')) {
        return 'Synchronize files';
      }
      
      // Fallback: use first meaningful command
      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.isNotEmpty && !trimmed.startsWith('#') && 
            !trimmed.startsWith('set -') && !trimmed.startsWith('export ')) {
          return 'Run: ${trimmed.length > 80 ? trimmed.substring(0, 80) : trimmed}';
        }
      }
    }
    
    // Fallback: use first meaningful sentence from user message
    String goal = _cleanMarkdown(userMessage).trim();
    // Remove language identifiers
    goal = goal.replaceAll(RegExp(r'\b(script|bash|shell|sh)\b', caseSensitive: false), '');
    if (goal.length > 200) goal = '${goal.substring(0, 197)}...';
    if (goal.isEmpty) goal = 'Achieve the task described in the message';
    return goal;
  }

  /// Create description from script and context
  static String createDescription(String userMessage, String? aiResponse, ExtractedScript? script, String? sessionTitle) {
    // Try AI response first (substantive content only)
    if (aiResponse != null && aiResponse.isNotEmpty) {
      final cleaned = _cleanMarkdown(aiResponse).trim();
      if (cleaned.length > 50) {
        String desc = cleaned.length > 300 ? '${cleaned.substring(0, 297)}...' : cleaned;
        return desc;
      }
    }
    
    // Generate meaningful description from script
    if (script != null && script.content.isNotEmpty) {
      final toolNames = script.tools.toList()..sort();
      final toolsStr = toolNames.join(', ');
      
      // Infer purpose from tools and content
      String purpose = 'Automated workflow';
      if (toolNames.contains('tar') || script.content.contains('backup')) {
        purpose = 'Create compressed backup archive';
      } else if (toolNames.contains('git') || script.content.contains('commit') || script.content.contains('push')) {
        purpose = 'Automate git operations';
      } else if (toolNames.contains('docker') || script.content.contains('deploy')) {
        purpose = 'Deploy application';
      } else if (toolNames.contains('rsync') || script.content.contains('sync')) {
        purpose = 'Synchronize files';
      } else if (toolNames.contains('ssh') || script.content.contains('scp')) {
        purpose = 'Remote file operations';
      } else if (toolNames.contains('curl') || toolNames.contains('wget') || script.content.contains('download')) {
        purpose = 'Download files from web';
      } else if (toolNames.contains('find') || toolNames.contains('grep')) {
        purpose = 'Search and filter files';
      }
      
      String desc = purpose;
      if (toolsStr.isNotEmpty) {
        desc += ' using $toolsStr';
      }
      
      // Add key steps summary (not just first command)
      if (script.steps.isNotEmpty) {
        final keySteps = script.steps.take(3).join('; ');
        desc += '. Key steps: $keySteps';
      }
      
      return desc;
    }
    
    // Fallback to session title or user message
    if (sessionTitle != null && sessionTitle.isNotEmpty) {
      return 'Distilled from: $sessionTitle';
    }
    
    final userMsg = _cleanMarkdown(userMessage).trim();
    if (userMsg.length > 200) return '${userMsg.substring(0, 197)}...';
    return userMsg.isEmpty ? 'Distilled from message' : userMsg;
  }

  /// Deduplicate constraints (case-insensitive, trim)
  static List<String> dedupConstraints(List<String> constraints) {
    final seen = <String>{};
    final result = <String>[];
    
    for (final constraint in constraints) {
      final trimmed = constraint.trim();
      if (trimmed.isEmpty) continue;
      
      final normalized = trimmed.toLowerCase();
      if (!seen.contains(normalized)) {
        seen.add(normalized);
        result.add(trimmed);
      }
    }
    
    return result;
  }

  /// Replace template placeholders while preserving shell positional parameters
  /// Does NOT replace $1-$9, $@, $*, $#, $?, $$, $! which are shell positional/special parameters
  static String replaceTemplates(String text, Map<String, String> replacements) {
    if (replacements.isEmpty) return text;
    
    String result = text;
    
    for (final entry in replacements.entries) {
      final placeholder = entry.key;
      final value = entry.value;
      
      // Skip shell positional parameters: $1-$9, $@, $*, $#, $?, $$, $!
      if (RegExp(r'^\$\d+$').hasMatch(placeholder) ||
          placeholder == r'$@' || placeholder == r'$*' ||
          placeholder == r'$#' || placeholder == r'$?' ||
          placeholder == r'$$' || placeholder == r'$!') {
        continue;
      }
      
      // Replace {{placeholder}} or ${placeholder} or $placeholder
      final patterns = [
        RegExp(r'\{\{\s*' + RegExp.escape(placeholder) + r'\s*\}\}'),
        RegExp(r'\$\{\s*' + RegExp.escape(placeholder) + r'\s*\}'),
        RegExp(r'(?<!\$)\$' + RegExp.escape(placeholder) + r'(?![\w\d])'),
      ];
      
      for (final pattern in patterns) {
        result = result.replaceAll(pattern, value);
      }
    }
    
    return result;
  }
  static Skill createFromMessageText({
    required String userMessage,
    String? aiResponse,
    required List<String> toolCalls,
    String? sessionTitle,
  }) {
    // Use new pipeline-based distillation
    final draft = distillScript(
      userPrompt: userMessage,
      assistantMarkdown: aiResponse ?? userMessage,
      lex: const ThaiLex(),
      allowCjk: false, // Don't include CJK in output fields
    );
    
    // Extract tools from the distilled script
    final scriptTools = draft.script != null 
        ? _inferToolsFromScriptContentImpl(draft.script!) 
        : <String>{};
    
    // Build steps from StepDraft
    final steps = draft.steps
        .map((s) => s.title)
        .where((s) => s.isNotEmpty)
        .take(15)
        .map((s) => s.length > 200 ? '${s.substring(0, 197)}...' : s)
        .toList();
    
    // Constraints with deduplication
    final constraints = dedupConstraints([
      'Do not store secrets (API keys, tokens, passwords)',
    ]);
    
    // Required tools (from toolCalls + script inference)
    final requiredTools = <String>{...toolCalls, ...scriptTools}.toList()
      ..sort();
    if (requiredTools.isEmpty) {
      requiredTools.addAll(['bash', 'edit']);
    }
    
    // Category inference
    final category = _inferCategoryFromText(userMessage, aiResponse, toolCalls);
    
    // Use drafted name/goal or fallbacks
    final name = draft.name?.isNotEmpty == true ? draft.name! : 'Unnamed Skill';
    final goal = draft.goal?.isNotEmpty == true ? draft.goal! : 'Achieve the task described in the message';
    final description = draft.goal?.isNotEmpty == true ? draft.goal! : (sessionTitle != null ? 'Distilled from: $sessionTitle' : userMessage);
    
    return Skill(
      id: _generateId(),
      name: name,
      description: redactText(description),
      goal: redactText(goal),
      steps: steps.map(redactText).toList(),
      constraints: constraints.map(redactText).toList(),
      requiredTools: requiredTools,
      userInputs: [],
      createdAt: DateTime.now(),
      sourceSessionTitle: sessionTitle,
      category: category,
      // v2 fields
      kind: 'workflow',
      schemaVersion: 2,
      provenance: SkillProvenance.manual(),
    );
  }
  
  /// Clean markdown formatting from text
  static String _cleanMarkdown(String text) {
    return text
        .replaceAll(RegExp(r'\*\*(.*?)\*\*'), r'$1')  // Bold
        .replaceAll(RegExp(r'\*(.*?)\*'), r'$1')      // Italic
        .replaceAll(RegExp(r'`(.*?)`'), r'$1')        // Inline code
        .replaceAll(RegExp(r'```[\s\S]*?```'), '')    // Code blocks
        .replaceAll(RegExp(r'#{1,6}\s*'), '')         // Headers
        .replaceAll(RegExp(r'\[(.*?)\]\(.*?\)'), r'$1') // Links
        .replaceAll(RegExp(r'^\s*[-*+]\s+', multiLine: true), '') // List markers
        .replaceAll(RegExp(r'^\s*\d+\.\s+', multiLine: true), '') // Numbered list
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')        // Multiple newlines
        .trim();
  }
  
  /// Infer category from text content
  static SkillCategory _inferCategoryFromText(String userMessage, String? aiResponse, List<String> toolCalls) {
    final response = aiResponse ?? '';
    final tools = toolCalls.join(' ');
    final allText = '$userMessage $response $tools'.toLowerCase();
    
    if (allText.contains('code') || allText.contains('develop') || allText.contains('program') ||
        allText.contains('debug') || allText.contains('refactor') || allText.contains('review') ||
        allText.contains('git') || allText.contains('build') || allText.contains('test') ||
        toolCalls.contains('edit') || toolCalls.contains('write') || toolCalls.contains('bash')) {
      return SkillCategory.development;
    }
    if (allText.contains('auto') || allText.contains('script') || allText.contains('deploy') ||
        allText.contains('ci') || allText.contains('cd') || allText.contains('pipeline') ||
        toolCalls.contains('bash')) {
      return SkillCategory.automation;
    }
    if (allText.contains('analy') || allText.contains('report') || allText.contains('summar') ||
        allText.contains('data') || allText.contains('query') || allText.contains('metric') ||
        allText.contains('log') || allText.contains('monitor') || toolCalls.contains('web_fetch')) {
      return SkillCategory.analysis;
    }
    if (allText.contains('product') || allText.contains('todo') || allText.contains('note') ||
        allText.contains('brief') || allText.contains('plan') || allText.contains('schedule') ||
        allText.contains('meeting') || allText.contains('email')) {
      return SkillCategory.productivity;
    }
    
    return SkillCategory.other;
  }

  /// Result of script extraction from message text
  static ExtractedScript? extractScriptFromText(String text) {
    // Match markdown fenced code blocks: ```language ... ```
    final codeBlockRegex = RegExp(r'```(\w+)?\n([\s\S]*?)\n```');
    final matches = codeBlockRegex.allMatches(text);
    
    for (final match in matches) {
      final language = (match.group(1) ?? '').toLowerCase();
      final content = match.group(2) ?? '';
      
      // Only process shell-like scripts
      if (isShellScript(language, content)) {
        final steps = _extractStepsFromScriptContentImpl(content);
        final tools = _inferToolsFromScriptContentImpl(content);
        
        if (steps.isNotEmpty || tools.isNotEmpty) {
          return ExtractedScript(
            language: language,
            content: content,
            steps: steps,
            tools: tools,
          );
        }
      }
    }
    
    return null;
  }

  /// Check if the code block is a shell script
  static bool isShellScript(String language, String content) {
    // Explicit shell languages
    if (language == 'bash' || language == 'sh' || language == 'shell' || 
        language == 'zsh' || language == 'fish') {
      return true;
    }
    
    // No language specified but content looks like shell
    if (language.isEmpty) {
      final firstLine = content.trim().split('\n').first.toLowerCase();
      // Shebang check
      if (firstLine.startsWith('#!/bin/bash') || 
          firstLine.startsWith('#!/bin/sh') ||
          firstLine.startsWith('#!/usr/bin/env bash') ||
          firstLine.startsWith('#!/usr/bin/env sh')) {
        return true;
      }
      // Common shell commands at start
      if (firstLine.startsWith('set -') || 
          firstLine.startsWith('export ') ||
          firstLine.startsWith('mkdir ') ||
          firstLine.startsWith('tar ') ||
          firstLine.startsWith('rsync ') ||
          firstLine.startsWith('gzip ') ||
          firstLine.startsWith('sha256sum ') ||
          firstLine.startsWith('find ') ||
          firstLine.startsWith('grep ')) {
        return true;
      }
    }
    
    return false;
  }

  /// Static wrapper for top-level extractStepsFromScriptContent function
  static List<String> extractStepsFromScriptContent(String content) {
    return _extractStepsFromScriptContentImpl(content);
  }

  /// Static wrapper for top-level inferToolsFromScriptContent function
  static Set<String> inferToolsFromScriptContent(String content) {
    return _inferToolsFromScriptContentImpl(content);
  }
}