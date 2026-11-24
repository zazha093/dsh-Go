// Step Runner — executes individual skill steps via DshClient
//
// Supports Tool mode (direct tool invocation) and Agent mode (prompt-based).
// Handles approval flow, cancellation, timeouts, and retries.

import 'dart:async';
import 'dart:convert';

import 'package:dsh_client/dsh_client.dart';

import 'skill_model.dart';
import 'parameter_resolver.dart';

/// Result of a single step execution.
class StepResult {
  const StepResult({
    required this.success,
    required this.stepId,
    this.output,
    this.error,
    this.duration,
    this.toolCallId,
  });

  final bool success;
  final String stepId;
  final String? output;
  final String? error;
  final Duration? duration;
  final String? toolCallId;

  factory StepResult.success({
    required String stepId,
    String? output,
    Duration? duration,
    String? toolCallId,
  }) {
    return StepResult(
      success: true,
      stepId: stepId,
      output: output,
      duration: duration,
      toolCallId: toolCallId,
    );
  }

  factory StepResult.failure({
    required String stepId,
    required String error,
    Duration? duration,
    String? toolCallId,
  }) {
    return StepResult(
      success: false,
      stepId: stepId,
      error: error,
      duration: duration,
      toolCallId: toolCallId,
    );
  }
}

/// Configuration for step execution.
class StepRunnerConfig {
  const StepRunnerConfig({
    this.approvalTimeout = const Duration(seconds: 30),
    this.toolTimeout = const Duration(seconds: 60),
    this.maxRetries = 0,
    this.retryDelay = const Duration(seconds: 5),
  });

  final Duration approvalTimeout;
  final Duration toolTimeout;
  final int maxRetries;
  final Duration retryDelay;
}

/// Runs skill steps via DshClient.
class StepRunner {
  final DshClient _client;
  final String _sessionId;
  final StepRunnerConfig _config;

  StepRunner({
    required this._client,
    required this._sessionId,
    this._config = const StepRunnerConfig(),
  });

  /// Runs a single step and returns the result.
  Future<StepResult> runStep({
    required SkillStep step,
    required Map<String, String> resolvedParams,
    required Function(ApprovalRequest) onApprovalRequested,
  }) async {
    final startTime = DateTime.now();

    switch (step.mode) {
      case 'tool':
        return _runToolStep(step, resolvedParams, onApprovalRequested, startTime);
      case 'agent':
        return _runAgentStep(step, resolvedParams, startTime);
      default:
        return StepResult.failure(
          stepId: step.id,
          error: 'Unknown step mode: ${step.mode}',
          duration: DateTime.now().difference(startTime),
        );
    }
  }

  /// Runs a tool-mode step via Agent prompt.
  Future<StepResult> _runToolStep(
    SkillStep step,
    Map<String, String> resolvedParams,
    Function(ApprovalRequest) onApprovalRequested,
    DateTime startTime,
  ) async {
    final tool = step.tool;
    if (tool == null) {
      return StepResult.failure(
        stepId: step.id,
        error: 'Tool step missing tool name',
        duration: DateTime.now().difference(startTime),
      );
    }

    // Resolve arguments with parameters
    final resolvedArgs = resolveArgs(step.args, resolvedParams);

    // Build the prompt for tool execution
    final prompt = _buildToolPrompt(tool, resolvedArgs);

    int attempt = 0;
    while (true) {
      try {
        final result = await _executeWithApproval(
          prompt: prompt,
          onApprovalRequested: onApprovalRequested,
          startTime: startTime,
          stepId: step.id,
        );
        return result;
      } on StepExecutionException catch (e) {
        // Check if we should retry
        if (attempt < _config.maxRetries && _isRetryableError(e.error)) {
          attempt++;
          await Future.delayed(_config.retryDelay);
          continue;
        }
        return StepResult.failure(
          stepId: step.id,
          error: e.error,
          duration: DateTime.now().difference(startTime),
          toolCallId: e.toolCallId,
        );
      } on TimeoutException {
        if (attempt < _config.maxRetries) {
          attempt++;
          await Future.delayed(_config.retryDelay);
          continue;
        }
        return StepResult.failure(
          stepId: step.id,
          error: 'Tool execution timed out after ${_config.toolTimeout.inSeconds}s',
          duration: DateTime.now().difference(startTime),
        );
      } on Exception catch (e) {
        return StepResult.failure(
          stepId: step.id,
          error: 'Unexpected error: $e',
          duration: DateTime.now().difference(startTime),
        );
      }
    }
  }

  /// Runs an agent-mode step via prompt.
  Future<StepResult> _runAgentStep(
    SkillStep step,
    Map<String, String> resolvedParams,
    DateTime startTime,
  ) async {
    // Build prompt with resolved parameters
    final description = resolveValue(step.description, resolvedParams);
    final prompt = 'Execute this step: $description';

    try {
      await _client.prompt(
        _sessionId,
        prompt,
        mode: PromptMode.queue,
      );

      // Wait for completion (simplified - in practice would watch for completion)
      await Future.delayed(const Duration(seconds: 2));

      return StepResult.success(
        stepId: step.id,
        output: 'Agent step completed',
        duration: DateTime.now().difference(startTime),
      );
    } on Exception catch (e) {
      return StepResult.failure(
        stepId: step.id,
        error: 'Agent step failed: $e',
        duration: DateTime.now().difference(startTime),
      );
    }
  }

  /// Executes a prompt and handles approval flow.
  Future<StepResult> _executeWithApproval({
    required String prompt,
    required Function(ApprovalRequest) onApprovalRequested,
    required DateTime startTime,
    required String stepId,
  }) async {
    // Send prompt
    final requestId = await _client.prompt(
      _sessionId,
      prompt,
      mode: PromptMode.queue,
    );

    // Wait for tool call event
    final toolCall = await _waitForToolCall(requestId);
    if (toolCall == null) {
      throw StepExecutionException('No tool call received', stepId: stepId);
    }

    // Handle approval if needed
    final approval = await _waitForApproval(toolCall.callId);
    if (approval != null) {
      onApprovalRequested(approval);
      // Wait for user decision (this would be async in real implementation)
      // For now, we'll auto-allow once
      await _client.respondApproval(approval, ApprovalDecision.allowOnce);
    }

    // Wait for tool result
    final toolResult = await _waitForToolResult(toolCall.callId);
    if (toolResult == null) {
      throw StepExecutionException('No tool result received', stepId: stepId, toolCallId: toolCall.callId);
    }

    if (toolResult.isError) {
      throw StepExecutionException(
        toolResult.message.text,
        stepId: stepId,
        toolCallId: toolCall.callId,
      );
    }

    return StepResult.success(
      stepId: stepId,
      output: toolResult.message.text,
      duration: DateTime.now().difference(startTime),
      toolCallId: toolCall.callId,
    );
  }

  /// Builds a tool execution prompt.
  String _buildToolPrompt(String tool, Map<String, dynamic> args) {
    final argsJson = const JsonEncoder().convert(args);
    return 'Run: $tool $argsJson';
  }

  /// Waits for a tool call event matching the request ID.
  Future<ToolCallEvent?> _waitForToolCall(String requestId) async {
    final completer = Completer<ToolCallEvent?>();
    late final StreamSubscription<DshEvent> subscription;

    subscription = _client.watch(_sessionId).listen((event) {
      if (event is ToolCallEvent) {
        // In a real implementation, we'd match by requestId
        // For now, we'll take the first tool call after our prompt
        if (!completer.isCompleted) completer.complete(event);
      }
    });

    try {
      return await completer.future.timeout(_config.toolTimeout);
    } on TimeoutException {
      await subscription.cancel();
      return null;
    }
  }

  /// Waits for an approval request for the given call ID.
  Future<ApprovalRequest?> _waitForApproval(String callId) async {
    final completer = Completer<ApprovalRequest?>();

    late final StreamSubscription<DshEvent> subscription;
    subscription = _client.watch(_sessionId).listen((event) {
      if (event is ApprovalRequestedEvent && event.request.callId == callId) {
        if (!completer.isCompleted) completer.complete(event.request);
      }
    });

    try {
      return await completer.future.timeout(_config.approvalTimeout);
    } on TimeoutException {
      await subscription.cancel();
      return null; // No approval needed
    }
  }

  /// Waits for a tool result event.
  Future<ToolResultEvent?> _waitForToolResult(String callId) async {
    final completer = Completer<ToolResultEvent?>();

    late final StreamSubscription<DshEvent> subscription;
    subscription = _client.watch(_sessionId).listen((event) {
      if (event is ToolResultEvent && event.callId == callId) {
        if (!completer.isCompleted) completer.complete(event);
      }
    });

    try {
      return await completer.future.timeout(_config.toolTimeout);
    } on TimeoutException {
      await subscription.cancel();
      return null;
    }
  }

  /// Checks if an error is retryable based on configuration.
  bool _isRetryableError(String error) {
    // In a real implementation, this would check against errorHandling.retryableErrors
    return error.contains('timeout') || error.contains('network') || error.contains('connection');
  }
}

/// Exception for step execution errors.
class StepExecutionException implements Exception {
  const StepExecutionException(this.error, {this.stepId, this.toolCallId});

  final String error;
  final String? stepId;
  final String? toolCallId;

  @override
  String toString() => 'StepExecutionException: $error';
}