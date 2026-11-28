// Distillation controller for skill creation with cancellation and timeout support
//
// Phase 4/5: Integrates SummaryService for AI-assisted distillation

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dsh_client/dsh_client.dart';

import 'skill_distill.dart';
import 'skill_model.dart';
import 'distill/heuristics.dart';
import 'distill/types.dart';
import '../fork/summary_service.dart';
import '../fork/completion_transport.dart';
import '../state/connection_state.dart';

/// Controller for skill distillation with cancellation and timeout support
class SkillDistillController extends Notifier<DistillState> {
  Timer? _timeoutTimer;
  bool _cancelled = false;
  bool _disposed = false;

  @override
  DistillState build() {
    // Register dispose callback to clean up resources
    ref.onDispose(() {
      _disposed = true;
      _cancelled = true;
      _timeoutTimer?.cancel();
      _timeoutTimer = null;
    });
    return const DistillState();
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

    // Phase 4/5: AI summarization + validation via SummaryService (if client available)
    if (input.dshClient != null) {
      _runSummarization(input, ruleBasedSkill);
    }
  }

  /// Run AI summarization + validation via SummaryService
  Future<void> _runSummarization(DistillInput input, Skill ruleBasedSkill) async {
    try {
      if (_disposed) return;
      state = state.copyWith(progress: 0.6);

      // Get SummaryService from provider
      final summaryService = ref.read(summaryServiceProvider);

      // Run summarization via SummaryService (combines AI + validation + JSON extraction)
      final outcome = await summaryService.summarize(input);

      if (_cancelled || _disposed) return;

      // Emit AI proposed skill (validated)
      state = state.copyWith(
        aiProposedSkill: outcome.skill,
        progress: 1.0,
      );
    } on CancellationException {
      if (_disposed) return;
      state = state.copyWith(
        status: DistillStatus.cancelled,
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
    if (!_disposed) {
      state = state.copyWith(status: DistillStatus.cancelled, aiProposedSkill: null);
    }
  }

  /// Reset to idle state
  void reset() {
    _cancelled = true;
    _timeoutTimer?.cancel();
    _timeoutTimer = null;
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

/// Provider for the completion transport (lower layer - fakeable for tests)
final completionTransportProvider = Provider<CompletionTransport>((ref) {
  final client = ref.watch(activeConnectionProvider).value?.client;
  if (client == null) {
    // Return a fake transport that will fail gracefully
    return FakeCompletionTransport(shouldThrow: true);
  }
  return DshCompletionTransport(client);
});

/// Provider for the summary service (upper layer - combines AI + validation + JSON extraction)
final summaryServiceProvider = Provider<SummaryService>((ref) {
  final transport = ref.watch(completionTransportProvider);
  return DshSummaryService(transport: transport);
});