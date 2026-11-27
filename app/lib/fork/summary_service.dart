// Summary Service for AI Skill Distillation
//
// Upper layer that combines:
// - AiSummarizer: generates skill draft from chat via AI
// - DraftValidator: validates AI output field-by-field with rule-based fallback
// - JSON extraction: parses AI response and extracts skill JSON
// 
// Uses CompletionTransport (injected via provider) for AI communication.

import 'dart:async';
import 'dart:convert';

import 'package:dsh_client/dsh_client.dart';

import '../../skills/skill_distill.dart';
import '../../skills/skill_model.dart';
import '../../skills/distill/heuristics.dart';
import '../../skills/distill/types.dart';
import '../fork/ai_summarizer.dart';
import '../fork/draft_validator.dart';
import '../fork/completion_transport.dart';

/// Configuration for summary service
class SummaryServiceConfig {
  const SummaryServiceConfig({
    this.maxUserPromptChars = 1500,
    this.maxAssistantChars = 4000,
    this.maxWriteScriptChars = 6000,
    this.maxTotalPromptChars = 20000,
    this.timeoutSeconds = 25,
    this.maxRetries = 1,
    this.locale = 'th',
    this.allowCjk = false,
  });

  final int maxUserPromptChars;
  final int maxAssistantChars;
  final int maxWriteScriptChars;
  final int maxTotalPromptChars;
  final int timeoutSeconds;
  final int maxRetries;
  final String locale;
  final bool allowCjk;
}

/// Result of summary service operation
class SummaryOutcome {
  const SummaryOutcome({
    required this.skill,
    required this.breadcrumb,
    this.fieldResults,
    this.fromCache = false,
  });

  final Skill skill;
  final String breadcrumb;
  final Map<String, FieldValidationResult>? fieldResults;
  final bool fromCache;
}

/// Summary Service - combines AI summarization, validation, and JSON extraction
abstract class SummaryService {
  /// Summarize chat messages into a validated skill draft.
  /// 
  /// Returns a [SummaryOutcome] containing the validated skill and metadata.
  Future<SummaryOutcome> summarize(DistillInput input);

  /// Cancel ongoing summarization.
  void cancel();
}

/// Real implementation combining AiSummarizer + DraftValidator + JSON extraction.
class DshSummaryService implements SummaryService {
  DshSummaryService({
    required CompletionTransport transport,
    SummaryServiceConfig? config,
  }) : _transport = transport,
       _config = config ?? const SummaryServiceConfig();

  final CompletionTransport _transport;
  final SummaryServiceConfig _config;

  AiSummarizer? _aiSummarizer;
  DraftValidator? _draftValidator;
  bool _cancelled = false;

  @override
  Future<SummaryOutcome> summarize(DistillInput input) async {
    if (input.dshClient == null) {
      // No client available - return rule-based draft
      final ruleBasedSkill = _createRuleBasedSkill(input);
      return SummaryOutcome(
        skill: ruleBasedSkill,
        breadcrumb: 'distill:source (no client)',
        fromCache: true,
      );
    }

    // Create rule-based draft for validation fallback
    final ruleBasedSkill = _createRuleBasedSkill(input);
    final ruleBasedDraft = _createRuleBasedDraft(ruleBasedSkill);

    // Initialize AI components
    final aiSummarizer = AiSummarizer(
      client: input.dshClient!,
      config: AiSummarizerConfig(
        maxUserPromptChars: _config.maxUserPromptChars,
        maxAssistantChars: _config.maxAssistantChars,
        maxWriteScriptChars: _config.maxWriteScriptChars,
        maxTotalPromptChars: _config.maxTotalPromptChars,
        timeoutSeconds: _config.timeoutSeconds,
        maxRetries: _config.maxRetries,
        locale: _config.locale,
      ),
    );

    final draftValidator = DraftValidator(
      ruleBasedDraft: _createRuleBasedDraft(ruleBasedSkill),
      config: DraftValidatorConfig(
        locale: _config.locale,
        allowCjk: _config.allowCjk,
      ),
    );

    // Build prompt for AI summarization
    final prompt = _buildPrompt(input);

    try {
      // Call AI via transport
      final rawResponse = await _transport.complete(
        prompt: prompt,
        isCancelled: () => false, // TODO: add cancellation check
      );

      // Extract JSON from AI response
      final aiSkill = _extractSkillFromResponse(rawResponse, ruleBasedSkill);

      // Validate AI skill with rule-based fallback
      final draftValidator = DraftValidator(
        ruleBasedDraft: _createRuleBasedDraft(ruleBasedSkill),
        config: DraftValidatorConfig(
          locale: 'th',
          allowCjk: false,
        ),
      );

      final validationResult = draftValidator.validate(aiSkill);

      return SummaryOutcome(
        skill: validationResult.validatedSkill,
        breadcrumb: validationResult.breadcrumb,
        fieldResults: validationResult.fieldResults,
      );
    } on CancellationException {
      return SummaryOutcome(
        skill: ruleBasedSkill,
        breadcrumb: 'ai:cancel',
        fromCache: true,
      );
    } catch (e) {
      // On error, return rule-based draft with error breadcrumb
      return SummaryOutcome(
        skill: ruleBasedSkill,
        breadcrumb: 'ai:invalid (${e.toString()})',
        fromCache: true,
      );
    }
  }

  @override
  void cancel() {
    // Cancellation is handled via transport's isCancelled callback
  }

  /// Create rule-based skill from input
  Skill _createRuleBasedSkill(DistillInput input) {
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
        toolCalls: input.toolCalls ?? [],
        sessionTitle: input.sessionTitle,
      );
    }
  }

  /// Build prompt for AI summarization
  String _buildPrompt(DistillInput input) {
    final buffer = StringBuffer();
    buffer.writeln('You are a skill distillation expert. Create a skill from this chat.');
    buffer.writeln('');
    buffer.writeln('User message:');
    buffer.writeln(input.userMessage);
    buffer.writeln('');

    if (input.aiResponse != null && input.aiResponse!.isNotEmpty) {
      buffer.writeln('AI response:');
      buffer.writeln(input.aiResponse!);
      buffer.writeln('');
    }

    if (input.toolCallsWithArgs != null && input.toolCallsWithArgs!.isNotEmpty) {
      buffer.writeln('Tool calls with arguments:');
      for (final toolCall in input.toolCallsWithArgs!) {
        buffer.writeln('- ${toolCall.name}: ${toolCall.arguments}');
      }
      buffer.writeln('');
    } else if (input.toolCalls != null && input.toolCalls!.isNotEmpty) {
      buffer.writeln('Tool calls:');
      for (final tool in input.toolCalls!) {
        buffer.writeln('- $tool');
      }
      buffer.writeln('');
    }

    buffer.writeln('Session title: ${input.sessionTitle}');
    buffer.writeln('');
    buffer.writeln('Return a JSON object with these fields:');
    buffer.writeln('name, description, goal, steps[], constraints[], requiredTools[], userInputs[], kind');
    buffer.writeln('Return ONLY the JSON object, no extra text.');

    return buffer.toString();
  }

  /// Extract skill from AI response, with rule-based fallback
  Skill _extractSkillFromResponse(String response, Skill fallbackSkill) {
    try {
      // Try to find JSON in the response
      final jsonMatch = RegExp(r'\{[\s\S]*\}').firstMatch(response);
      if (jsonMatch == null) {
        throw FormatException('No JSON object found in response');
      }

      final jsonStr = jsonMatch.group(0)!;
      final Map<String, dynamic> json = jsonDecode(jsonStr);

      return Skill(
        id: fallbackSkill.id,
        name: json['name'] as String? ?? fallbackSkill.name,
        description: json['description'] as String? ?? fallbackSkill.description,
        goal: json['goal'] as String? ?? fallbackSkill.goal,
        steps: (json['steps'] as List?)?.map((e) => e.toString()).toList() ?? fallbackSkill.steps,
        constraints: (json['constraints'] as List?)?.map((e) => e.toString()).toList() ?? fallbackSkill.constraints,
        requiredTools: (json['requiredTools'] as List?)?.map((e) => e.toString()).toList() ?? fallbackSkill.requiredTools,
        userInputs: fallbackSkill.userInputs,
        createdAt: DateTime.now(),
        category: fallbackSkill.category,
        kind: json['kind'] as String? ?? fallbackSkill.kind,
        schemaVersion: fallbackSkill.schemaVersion,
        executableSteps: fallbackSkill.executableSteps,
        parameters: fallbackSkill.parameters,
        errorHandling: fallbackSkill.errorHandling,
        sourceSessionId: fallbackSkill.sourceSessionId,
        sourceSessionTitle: fallbackSkill.sourceSessionTitle,
      );
    } catch (e) {
      // On JSON parse error, return rule-based skill
      return fallbackSkill;
    }
  }

  /// Create DistilledDraft from skill for validation fallback
  DistilledDraft _createRuleBasedDraft(Skill skill) {
    return DistilledDraft(
      name: skill.name,
      goal: skill.goal,
      description: skill.description,
      steps: skill.steps.map((s) => StepDraft(StepKind.action, s)).toList(),
      constraints: skill.constraints,
      tools: skill.requiredTools,
    );
  }
}