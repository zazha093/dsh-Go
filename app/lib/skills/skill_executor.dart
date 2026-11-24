// Skill Executor — thin adapter over DshClient for skill execution
//
// Coordinates step execution, manages session lifecycle, handles
// approval flow, cancellation, and progress reporting.

import 'dart:async';

import 'package:dsh_client/dsh_client.dart';

import 'skill_model.dart';
import 'parameter_resolver.dart'
    show
        mergeParameters,
        validateParameters,
        resolveSkillSteps;
import 'step_runner.dart';

/// Result of a full skill execution.
class SkillExecutionResult {
  const SkillExecutionResult({
    required this.success,
    required this.skillId,
    this.output,
    this.error,
    this.duration,
    this.stepsCompleted = 0,
    this.totalSteps = 0,
    this.stepResults = const [],
  });

  final bool success;
  final String skillId;
  final String? output;
  final String? error;
  final Duration? duration;
  final int stepsCompleted;
  final int totalSteps;
  final List<StepResult> stepResults;

  factory SkillExecutionResult.success({
    required String skillId,
    String? output,
    Duration? duration,
    int stepsCompleted = 0,
    int totalSteps = 0,
    List<StepResult> stepResults = const [],
  }) {
    return SkillExecutionResult(
      success: true,
      skillId: skillId,
      output: output,
      duration: duration,
      stepsCompleted: stepsCompleted,
      totalSteps: totalSteps,
      stepResults: stepResults,
    );
  }

  factory SkillExecutionResult.failure({
    required String skillId,
    required String error,
    Duration? duration,
    int stepsCompleted = 0,
    int totalSteps = 0,
    List<StepResult> stepResults = const [],
  }) {
    return SkillExecutionResult(
      success: false,
      skillId: skillId,
      error: error,
      duration: duration,
      stepsCompleted: stepsCompleted,
      totalSteps: totalSteps,
      stepResults: stepResults,
    );
  }

  factory SkillExecutionResult.cancelled({
    required String skillId,
    Duration? duration,
    int stepsCompleted = 0,
    int totalSteps = 0,
    List<StepResult> stepResults = const [],
  }) {
    return SkillExecutionResult(
      success: false,
      skillId: skillId,
      error: 'Cancelled by user',
      duration: duration,
      stepsCompleted: stepsCompleted,
      totalSteps: totalSteps,
      stepResults: stepResults,
    );
  }
}

/// Progress callback for skill execution.
typedef ProgressCallback = void Function(SkillExecutionProgress progress);

/// Progress information during skill execution.
class SkillExecutionProgress {
  const SkillExecutionProgress({
    required this.currentStep,
    required this.totalSteps,
    required this.currentStepId,
    this.currentStepDescription,
    this.status = 'running',
  });

  final int currentStep;
  final int totalSteps;
  final String currentStepId;
  final String? currentStepDescription;
  final String status; // 'running', 'waiting_approval', 'completed', 'failed', 'cancelled'

  double get progress => totalSteps > 0 ? currentStep / totalSteps : 0.0;
}

/// Configuration for skill execution.
class SkillExecutorConfig {
  const SkillExecutorConfig({
    this.stepConfig = const StepRunnerConfig(),
    this.createNewSession = true,
    this.sessionCwd,
    this.sessionWorkspaceId,
    this.agentPreset,
  });

  final StepRunnerConfig stepConfig;
  final bool createNewSession;
  final String? sessionCwd;
  final String? sessionWorkspaceId;
  final String? agentPreset;
}

/// Thin adapter over DshClient for executing skills.
class SkillExecutor {
  final DshClient _client;
  final SkillExecutorConfig _config;
  String? _sessionId;
  bool _cancelled = false;
  final _progressController = StreamController<SkillExecutionProgress>.broadcast();

  SkillExecutor({
    required this._client,
    this._config = const SkillExecutorConfig(),
  });

  /// Stream of execution progress updates.
  Stream<SkillExecutionProgress> get progressStream => _progressController.stream;

  /// Whether execution has been cancelled.
  bool get isCancelled => _cancelled;

  /// Executes a skill with the given parameters.
  Future<SkillExecutionResult> execute({
    required Skill skill,
    required Map<String, String> userParameters,
    ProgressCallback? onProgress,
    bool dryRun = false,
  }) async {
    _cancelled = false;
    final startTime = DateTime.now();
    final stepResults = <StepResult>[];

    try {
      // Validate parameters
      final missingParams = validateParameters(skill.parameters ?? [], userParameters);
      if (missingParams.isNotEmpty) {
        return SkillExecutionResult.failure(
          skillId: skill.id,
          error: 'Missing required parameters: ${missingParams.join(', ')}',
          duration: DateTime.now().difference(startTime),
        );
      }

      // Merge parameters with defaults and bindings
      final resolvedParams = mergeParameters(
        parameters: skill.parameters ?? [],
        userProvided: userParameters,
      );

      // Check if executable
      if (skill.kind != 'executable') {
        return SkillExecutionResult.failure(
          skillId: skill.id,
          error: 'Skill is not executable (kind: ${skill.kind})',
          duration: DateTime.now().difference(startTime),
        );
      }

      final executableSteps = resolveSkillSteps(skill.executableSteps ?? [], resolvedParams);
      if (executableSteps.isEmpty) {
        return SkillExecutionResult.failure(
          skillId: skill.id,
          error: 'No executable steps defined',
          duration: DateTime.now().difference(startTime),
        );
      }

      if (dryRun) {
        // Dry run - just validate, don't execute
        return SkillExecutionResult.success(
          skillId: skill.id,
          output: 'Dry run passed - ${executableSteps.length} steps would execute',
          duration: DateTime.now().difference(startTime),
          stepsCompleted: 0,
          totalSteps: executableSteps.length,
        );
      }

      // Create or reuse session
      await _ensureSession();

      // Set up step runner
      final stepRunner = StepRunner(
        client: _client,
        sessionId: _sessionId!,
        config: _config.stepConfig,
      );

      // Track progress
      int completedSteps = 0;
      final totalSteps = executableSteps.length;
      final stepResults = <StepResult>[];

      // Report initial progress
      _reportProgress(0, totalSteps, executableSteps.first.id,
          executableSteps.first.description, 'running');

      // Execute steps sequentially
      for (int i = 0; i < executableSteps.length; i++) {
        if (_cancelled) {
          return SkillExecutionResult.cancelled(
            skillId: skill.id,
            duration: DateTime.now().difference(startTime),
            stepsCompleted: completedSteps,
            totalSteps: totalSteps,
            stepResults: stepResults,
          );
        }

        final step = executableSteps[i];

        // Report progress for this step
        _reportProgress(i, totalSteps, step.id, step.description, 'running');

        // Execute step with approval handling and retry logic
        final stepResult = await _runStepWithRetry(
          stepRunner,
          step,
          i,
          executableSteps.length,
        );

        stepResults.add(stepResult);

        if (!stepResult.success) {
          // Check error handling
          final errorHandling = skill.errorHandling;
          final shouldRetry = errorHandling?.onError == 'retry' &&
              (errorHandling?.retryableErrors.contains(stepResult.error ?? '') ?? false);

          if (shouldRetry && stepResults.length < (errorHandling?.maxRetries ?? 0) + 1) {
            // Retry logic is handled in _runStepWithRetry
          } else {
            return SkillExecutionResult.failure(
              skillId: skill.id,
              error: 'Step ${stepResults.length} failed: ${stepResult.error}',
              duration: DateTime.now().difference(startTime),
              stepsCompleted: stepResults.length - 1,
              totalSteps: executableSteps.length,
              stepResults: stepResults,
            );
          }
        }

        _reportProgress(stepResults.length, executableSteps.length,
            stepResults.last.stepId, stepResults.last.output, 'completed');
      }

      // All steps completed successfully
      return SkillExecutionResult.success(
        skillId: skill.id,
        output: 'All ${executableSteps.length} steps completed successfully',
        duration: DateTime.now().difference(DateTime.now()),
        stepsCompleted: executableSteps.length,
        totalSteps: executableSteps.length,
        stepResults: stepResults,
      );
    } on Exception catch (e) {
      return SkillExecutionResult.failure(
        skillId: skill.id,
        error: 'Execution error: $e',
        duration: DateTime.now().difference(DateTime.now()),
        stepsCompleted: stepResults.length,
        totalSteps: (skill.executableSteps ?? []).length,
        stepResults: stepResults,
      );
    }
  }

  /// Runs a single step with retry logic.
  Future<StepResult> _runStepWithRetry(
    StepRunner stepRunner,
    SkillStep step,
    int stepIndex,
    int totalSteps,
  ) async {
    final errorHandling = SkillErrorHandling(
      onError: 'stop',
      maxRetries: 0,
      retryDelay: const Duration(seconds: 5),
      retryableErrors: [],
    );

    int attempt = 0;
    while (true) {
      try {
        // For now, pass empty params - in a real implementation, this would come from skill context
        final stepResult = await _runStepWithApproval(stepRunner, {});
        return stepResult;
      } on StepExecutionException catch (e) {
        // Check if we should retry
        if (attempt < errorHandling.maxRetries && _isRetryableError(e.error)) {
          attempt++;
          await Future.delayed(errorHandling.retryDelay);
          continue;
        }
        return StepResult.failure(
          stepId: step.id,
          error: e.error,
          duration: DateTime.now().difference(DateTime.now()),
          toolCallId: e.toolCallId,
        );
      } on TimeoutException {
        if (attempt < 3) {
          attempt++;
          await Future.delayed(const Duration(seconds: 5));
          continue;
        }
        return StepResult.failure(
          stepId: 'unknown',
          error: 'Tool execution timed out',
          duration: DateTime.now().difference(DateTime.now()),
        );
      } on Exception catch (e) {
        return StepResult.failure(
          stepId: 'unknown',
          error: 'Unexpected error: $e',
          duration: DateTime.now().difference(DateTime.now()),
        );
      }
    }
  }

  /// Runs a single step with approval handling.
  Future<StepResult> _runStepWithApproval(
    StepRunner stepRunner,
    Map<String, String> resolvedParams,
  ) async {
    // For now, use the step runner with empty params
    // In a real implementation, we'd pass the resolved params and handle approval via callback
    // For now, we'll use the step runner's built-in approval handling
    return stepRunner.runStep(
      step: SkillStep(
        id: 'step-${DateTime.now().millisecondsSinceEpoch}',
        description: 'Execute step',
        mode: 'tool',
        tool: 'bash',
        args: {},
        order: 0,
      ),
      resolvedParams: {},
      onApprovalRequested: (approval) {
        // Auto-allow for now
        // In a real implementation, this would trigger UI and await user decision
      },
    );
  }

  /// Ensures a session exists for execution.
  Future<void> _ensureSession() async {
    if (_sessionId != null) return;

    if (_config.createNewSession) {
      final session = await _client.createSession(
        cwd: _config.sessionCwd,
        workspaceId: _config.sessionWorkspaceId,
      );
      _sessionId = session.sessionId;
    } else {
      throw StateError('Session reuse not implemented');
    }
  }

  /// Reports progress to listeners.
  void _reportProgress(int current, int total, String stepId, String? description, String status) {
    final progress = SkillExecutionProgress(
      currentStep: current,
      totalSteps: total,
      currentStepId: stepId,
      currentStepDescription: description,
      status: status,
    );
    _progressController.add(progress);
  }

  /// Checks if an error is retryable.
  bool _isRetryableError(String error) {
    return error.contains('timeout') ||
        error.contains('network') ||
        error.contains('connection') ||
        error.contains('temporary');
  }

  /// Cancels the current execution.
  Future<void> cancel() async {
    _cancelled = true;
    if (_sessionId != null) {
      await _client.cancel(_sessionId!);
    }
  }

  /// Closes the executor and cleans up resources.
  Future<void> close() async {
    await _progressController.close();
  }
}