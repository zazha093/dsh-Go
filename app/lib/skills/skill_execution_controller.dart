// Skill Execution Controller — Riverpod state management for skill execution
//
// Manages the lifecycle of skill execution: pending, running, waiting approval,
// waiting input, completed, failed, cancelled.

import 'dart:async';

import 'package:dsh_client/dsh_client.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'skill_model.dart';
import 'skill_provider.dart';
import 'skill_executor.dart';

/// State for skill execution.
class SkillExecutionState {
  const SkillExecutionState({
    this.status = SkillExecutionStatus.idle,
    this.currentSkillId,
    this.currentStep = 0,
    this.totalSteps = 0,
    this.currentStepId,
    this.currentStepDescription,
    this.progress = 0.0,
    this.error,
    this.result,
    this.isCancelling = false,
    this.awaitingApproval = false,
    this.currentApproval,
    this.awaitingInput = false,
    this.requiredInputs = const [],
  });

  final SkillExecutionStatus status;
  final String? currentSkillId;
  final int currentStep;
  final int totalSteps;
  final String? currentStepId;
  final String? currentStepDescription;
  final double progress;
  final String? error;
  final SkillExecutionResult? result;
  final bool isCancelling;
  final bool awaitingApproval;
  final ApprovalRequest? currentApproval;
  final bool awaitingInput;
  final List<SkillInput> requiredInputs;

  SkillExecutionState copyWith({
    SkillExecutionStatus? status,
    String? currentSkillId,
    int? currentStep,
    int? totalSteps,
    String? currentStepId,
    String? currentStepDescription,
    double? progress,
    String? error,
    SkillExecutionResult? result,
    bool? isCancelling,
    bool? awaitingApproval,
    ApprovalRequest? currentApproval,
    bool? awaitingInput,
    List<SkillInput>? requiredInputs,
  }) {
    return SkillExecutionState(
      status: status ?? this.status,
      currentSkillId: currentSkillId ?? this.currentSkillId,
      currentStep: currentStep ?? this.currentStep,
      totalSteps: totalSteps ?? this.totalSteps,
      currentStepId: currentStepId ?? this.currentStepId,
      currentStepDescription: currentStepDescription ?? this.currentStepDescription,
      progress: progress ?? this.progress,
      error: error ?? this.error,
      result: result ?? this.result,
      isCancelling: isCancelling ?? this.isCancelling,
      awaitingApproval: awaitingApproval ?? this.awaitingApproval,
      currentApproval: currentApproval ?? this.currentApproval,
      awaitingInput: awaitingInput ?? this.awaitingInput,
      requiredInputs: requiredInputs ?? this.requiredInputs,
    );
  }
}

/// Status of skill execution.
enum SkillExecutionStatus {
  idle,
  pending,
  running,
  waitingApproval,
  waitingInput,
  completed,
  failed,
  cancelled,
}

/// Provider for the skill execution controller.
final skillExecutionControllerProvider =
    NotifierProvider<SkillExecutionController, SkillExecutionState>(() {
  return SkillExecutionController();
});

/// Controller for skill execution lifecycle.
class SkillExecutionController extends Notifier<SkillExecutionState> {
  SkillExecutor? _executor;
  StreamSubscription? _progressSubscription;
  Completer<void>? _approvalCompleter;
  Completer<Map<String, String>>? _inputCompleter;

  @override
  SkillExecutionState build() {
    return const SkillExecutionState();
  }

  /// Sets the executor (called once at app startup).
  void setExecutor(SkillExecutor executor) {
    _executor = executor;
  }

  /// Executes a skill with the given parameters.
  Future<void> executeSkill({
    required Skill skill,
    required Map<String, String> userParameters,
    bool dryRun = false,
  }) async {
    if (_executor == null) {
      state = state.copyWith(
        status: SkillExecutionStatus.failed,
        error: 'Executor not initialized',
      );
      return;
    }

    // Check if skill is executable
    if (skill.kind != 'executable') {
      state = state.copyWith(
        status: SkillExecutionStatus.failed,
        error: 'Skill is not executable (kind: ${skill.kind})',
      );
      return;
    }

    // Check for required user inputs - convert SkillParameter to SkillInput
    final missingInputs = skill.parameters?.where((p) =>
        p.required &&
        (userParameters[p.key] == null || userParameters[p.key]!.isEmpty) &&
        (p.defaultValue == null || p.defaultValue!.isEmpty))
        .map((p) => SkillInput(
              key: p.key,
              label: p.label,
              hint: p.label, // Use label as hint since SkillParameter doesn't have hint
              type: _stringToSkillInputType(p.type),
              required: p.required,
              defaultValue: p.defaultValue,
              options: p.options,
            ))
        .toList() ?? [];

    if (missingInputs.isNotEmpty) {
      state = state.copyWith(
        status: SkillExecutionStatus.waitingInput,
        awaitingInput: true,
        requiredInputs: missingInputs,
        currentSkillId: skill.id,
      );
      return;
    }

    // Start execution
    state = state.copyWith(
      status: SkillExecutionStatus.running,
      currentSkillId: skill.id,
      currentStep: 0,
      totalSteps: skill.executableSteps?.length ?? 0,
      error: null,
      result: null,
    );

    try {
      // Subscribe to progress
      _progressSubscription?.cancel();
      _progressSubscription = _executor!.progressStream.listen((progress) {
        state = state.copyWith(
          currentStep: progress.currentStep,
          totalSteps: progress.totalSteps,
          currentStepId: progress.currentStepId,
          currentStepDescription: progress.currentStepDescription,
          progress: progress.progress,
          status: _mapProgressStatus(progress.status),
        );
      });

      final result = await _executor!.execute(
        skill: skill,
        userParameters: userParameters,
        dryRun: false,
        onProgress: (progress) {
          // Progress is handled via stream
        },
      );

      if (result.success) {
        state = state.copyWith(
          status: SkillExecutionStatus.completed,
          currentStep: result.stepsCompleted,
          progress: 1.0,
          result: result,
        );

        // Record success in skill provider
        ref.read(skillsProvider.notifier).recordSuccess(skill.id);
      } else {
        state = state.copyWith(
          status: SkillExecutionStatus.failed,
          error: result.error,
          result: result,
        );

        // Record failure in skill provider
        ref.read(skillsProvider.notifier).recordFailure(skill.id);
      }
    } catch (e) {
      state = state.copyWith(
        status: SkillExecutionStatus.failed,
        error: 'Execution error: $e',
      );
    } finally {
      _progressSubscription?.cancel();
    }
  }

  /// Handles approval response from user.
  Future<void> respondApproval(ApprovalDecision decision) async {
    if (_approvalCompleter != null && !_approvalCompleter!.isCompleted) {
      _approvalCompleter!.complete(decision);
      _approvalCompleter = null;
    }

    state = state.copyWith(
      awaitingApproval: false,
      currentApproval: null,
    ); // ignore: void_checks

    // Resume execution (would need to be implemented in executor)
  }

  /// Handles user input for required parameters.
  Future<void> provideInput(Map<String, String> inputs) async {
    if (_inputCompleter != null && !_inputCompleter!.isCompleted) {
      _inputCompleter!.complete(inputs);
      _inputCompleter = null;
    }

    state = state.copyWith(
      awaitingInput: false,
      requiredInputs: [],
    );

    // Resume execution with provided inputs
    // This would need to be implemented to resume from waitingInput state
  }

  /// Cancels the current execution.
  Future<void> cancel() async {
    state = state.copyWith(
      status: SkillExecutionStatus.cancelled,
      isCancelling: true,
    );

    await _executor?.cancel();
    _progressSubscription?.cancel();

    state = state.copyWith(
      isCancelling: false,
    );
  }

  /// Clears the current result/error.
  void clear() {
    state = const SkillExecutionState();
  }

  /// Retries a failed execution.
  Future<void> retry() async {
    final skillId = state.currentSkillId;
    final result = state.result;

    if (skillId == null || result == null) return;

    // Get the skill and retry
    final skill = ref.read(skillProvider(skillId));
    if (skill == null) return;

    await executeSkill(skill: skill, userParameters: {});
  }

  SkillExecutionStatus _mapProgressStatus(String progressStatus) {
    switch (progressStatus) {
      case 'running':
        return SkillExecutionStatus.running;
      case 'waiting_approval':
        return SkillExecutionStatus.waitingApproval;
      case 'completed':
        return SkillExecutionStatus.completed;
      case 'failed':
        return SkillExecutionStatus.failed;
      case 'cancelled':
        return SkillExecutionStatus.cancelled;
      default:
        return SkillExecutionStatus.running;
    }
  }

  /// Converts a string type to SkillInputType enum.
  SkillInputType _stringToSkillInputType(String type) {
    switch (type) {
      case 'number':
        return SkillInputType.number;
      case 'select':
        return SkillInputType.select;
      case 'boolean':
        return SkillInputType.boolean;
      case 'multiline':
        return SkillInputType.multiline;
      case 'text':
      default:
        return SkillInputType.text;
    }
  }
}

/// Provider for the current executing skill (for UI).
final currentExecutingSkillProvider = Provider<Skill?>((ref) {
  final state = ref.watch(skillExecutionControllerProvider);
  if (state.currentSkillId == null) return null;
  return ref.watch(skillProvider(state.currentSkillId!));
});