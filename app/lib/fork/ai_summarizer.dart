// AI Summarizer for Skill Distillation
//
// Uses ephemeral DshClient session to summarize chat messages into skill drafts.
// Implements input size limits, secret redaction, timeout, and robust JSON parsing.
// This is a compile-time stub; actual implementation will be refined in follow-up.

import 'dart:async';

import 'package:dsh_client/dsh_client.dart';

import '../skills/skill_distill.dart';
import '../skills/skill_model.dart';

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

/// AI Summarizer using ephemeral DshClient session (stub implementation)
class AiSummarizer {
  AiSummarizer({
    required this._client,
    AiSummarizerConfig? config,
  }) : _config = config ?? const AiSummarizerConfig();

  final DshClient _client;
  final AiSummarizerConfig _config;

  /// Summarize chat messages into a skill draft (stub - returns rule-based draft)
  Future<AiSummarizerResult> summarize({
    required String userMessage,
    String? aiResponse,
    required List<ToolCallInfo> toolCallsWithArgs,
    String? sessionTitle,
  }) async {
    // TODO: Implement actual AI summarization via ephemeral DshClient session
    // For now, return a basic rule-based draft to satisfy the interface
    final ruleBasedSkill = SkillDistiller.createFromTurn(
      userMessage: userMessage,
      aiResponse: aiResponse,
      toolCallsWithArgs: toolCallsWithArgs,
      sessionTitle: sessionTitle ?? 'From message',
    );

    return AiSummarizerResult(
      skill: ruleBasedSkill,
      fromCache: true,
      breadcrumb: 'ai:stub',
    );
  }

  /// Cancel ongoing summarization
  void cancel() {
    // TODO: Implement cancellation
  }
}