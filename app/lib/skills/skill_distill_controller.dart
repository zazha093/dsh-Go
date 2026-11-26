// Distillation controller for skill creation with cancellation and timeout support
//
// Phase 4/5: Integrates AI summarizer + draft validator for AI-assisted distillation

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dsh_client/dsh_client.dart';

import 'skill_distill.dart';
import 'skill_model.dart';
import 'distill/heuristics.dart';
import '../fork/ai_summarizer.dart';
import '../fork/draft_validator.dart';

/// State for the distillation process
@immutable
class DistillState {
  const DistillState({
    this.status = DistillStatus.idle,
    this.skill,
    this.aiProposedSkill,
    this.error,
    this.progress = 0.0,
  });

  final DistillStatus status;
  final Skill? skill;              // Rule-based draft (instant)
  final Skill? aiProposedSkill;    // AI-validated proposal (async)
  final String? error;
  final double progress;

  DistillState copyWith({
    DistillStatus? status,
    Skill? skill,
    Skill? aiProposedSkill,
    String? error,
    double? progress,
  }) {
    return DistillState(
      status: status ?? this.status,
      skill: skill ?? this.skill,
      aiProposedSkill: aiProposedSkill ?? this.aiProposedSkill,
      error: error ?? this.error,
      progress: progress ?? this.progress,
    );
  }
}

enum DistillStatus { idle, running, ready, failed, cancelled }

/// Input for distillation
@immutable
class DistillInput {
  const DistillInput({
    required this.userMessage,
    this.aiResponse,
    this.toolCalls,
    this.toolCallsWithArgs,
    required this.sessionTitle,
    this.dshClient, // Optional: for AI summarization
  });

  final String userMessage;
  final String? aiResponse;
  final List<String>? toolCalls;
  final List<ToolCallInfo>? toolCallsWithArgs;
  final String sessionTitle;
  final DshClient? dshClient;
}

/// Controller for skill distillation with cancellation and timeout support
class SkillDistillController extends Notifier<DistillState> {
  Timer? _timeoutTimer;
  bool _cancelled = false;
  bool _disposed = false;
  AiSummarizer? _aiSummarizer;
  DraftValidator? _draftValidator;

  @override
  DistillState build() {
    // Register dispose callback to clean up resources
    ref.onDispose(() {
      _disposed = true;
      _cancelled = true;
      _timeoutTimer?.cancel();
      _timeoutTimer = null;
      _aiSummarizer?.cancel();
    });
    return const DistillState();
  }

  /// Initialize AI summarizer and draft validator (call after build when ref is available)
  void initializeAi(DshClient client, DistilledDraft ruleBasedDraft) {
    _aiSummarizer = AiSummarizer(client: client);
    _draftValidator = DraftValidator(ruleBasedDraft: ruleBasedDraft);
  }

  /// Start distillation from message text
  Future<void> distillFromText(DistillInput input) async {
    if (state.status == DistillStatus.running) return;

    _cancelled = false;
    state = state.copyWith(status: DistillStatus.running, error: null, progress: 0.1, aiProposedSkill: null);

    // Phase 3: Instant rule-based draft (synchronous)
    Skill ruleBasedSkill;
    if (input.toolCallsWithArgs != null && input.toolCallsWithArgs!.isNotEmpty) {
      ruleBasedSkill = SkillDistiller.createFromTurn(
        userMessage: input.userMessage,
        aiResponse: input.aiResponse,
        toolCallsWithArgs: input.toolCallsWithArgs!,
        sessionTitle: input.sessionTitle,
      );
    } else {
      ruleBasedSkill = SkillDistiller.createFromMessageText(
        userMessage: input.userMessage,
        aiResponse: input.aiResponse,
        toolCalls: input.toolCalls ?? [],
        sessionTitle: input.sessionTitle,
      );
    }

    // Emit rule-based draft immediately
    if (_disposed) return;
    state = state.copyWith(status: DistillStatus.ready, skill: ruleBasedSkill, progress: 0.5);

    // Initialize AI components with rule-based draft for validation fallback
    if (input.dshClient != null) {
      initializeAi(input.dshClient!, _createRuleBasedDraft(ruleBasedSkill));
    }

    // Phase 4/5: AI summarization in background (if client available)
    if (input.dshClient != null && _aiSummarizer != null && _draftValidator != null) {
      _runAiSummarization(input, ruleBasedSkill);
    }
  }

  /// Run AI summarization + validation in background
  Future<void> _runAiSummarization(DistillInput input, Skill ruleBasedSkill) async {
    try {
      if (_disposed) return;
      state = state.copyWith(progress: 0.6);

      // Phase 4: AI summarization via ephemeral session
      final aiResult = await _aiSummarizer!.summarize(
        userMessage: input.userMessage,
        aiResponse: input.aiResponse,
        toolCallsWithArgs: input.toolCallsWithArgs ?? [],
        sessionTitle: input.sessionTitle,
      );

      if (_cancelled || _disposed) return;

      // Phase 4/5: Draft validation with rule-based fallback
      final validationResult = _draftValidator!.validate(aiResult.skill);

      if (_disposed) return;

      // Emit AI proposed skill (validated)
      state = state.copyWith(
        aiProposedSkill: validationResult.validatedSkill,
        progress: 1.0,
      );
    } on TimeoutException {
      if (_disposed) return;
      state = state.copyWith(
        status: DistillStatus.failed,
        error: 'AI summarization timed out',
        aiProposedSkill: null,
      );
    } catch (e) {
      if (_disposed) return;
      state = state.copyWith(
        status: DistillStatus.failed,
        error: 'AI summarization failed: $e',
        aiProposedSkill: null,
      );
    }
  }

  /// Create DistilledDraft from rule-based skill for validation fallback
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

  /// Cancel ongoing distillation
  void cancel() {
    if (state.status != DistillStatus.running) return;
    _cancelled = true;
    _timeoutTimer?.cancel();
    _timeoutTimer = null;
    _aiSummarizer?.cancel();
    if (!_disposed) {
      state = state.copyWith(status: DistillStatus.cancelled, aiProposedSkill: null);
    }
  }

  /// Reset to idle state
  void reset() {
    _cancelled = true;
    _timeoutTimer?.cancel();
    _timeoutTimer = null;
    _aiSummarizer?.cancel();
    if (!_disposed) {
      state = const DistillState();
    }
  }
}

/// Provider for the distillation controller
final skillDistillControllerProvider =
    NotifierProvider.autoDispose<SkillDistillController, DistillState>(() {
  return SkillDistillController();
});

/// Provider family for distillation controller with session parameter (if needed)
final skillDistillControllerFamilyProvider =
    NotifierProvider.autoDispose.family<SkillDistillController, DistillState, String>(
  (ref, sessionId) {
    return SkillDistillController();
  },
);