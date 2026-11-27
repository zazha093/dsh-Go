// Completion Transport for AI Summarization
//
// Lower layer interface that wraps DshClient's prompt method with ephemeral session management.
// This layer is fakeable for testing - tests can provide a fake transport.

import 'dart:async';

import 'package:dsh_client/dsh_client.dart';

/// Interface for AI completion transport.
/// 
/// This is the lower layer that can be faked in tests.
/// The real implementation wraps DshClient's prompt method with ephemeral session management.
abstract class CompletionTransport {
  /// Sends a prompt to the AI and returns the raw response.
  /// 
  /// [prompt] - The full prompt to send to the AI
  /// [isCancelled] - Optional callback to check if the operation was cancelled
  /// 
  /// Returns the raw AI response as a string (typically JSON).
  Future<String> complete({
    required String prompt,
    bool Function()? isCancelled,
  });

  /// Cancels any ongoing completion.
  void cancel();
}

/// Real implementation wrapping DshClient with ephemeral session management.
/// 
/// This implements the ephemeral session flow: create session -> prompt -> watch response -> archive session.
class DshCompletionTransport implements CompletionTransport {
  DshCompletionTransport(this._client);

  final DshClient _client;

  @override
  Future<String> complete({
    required String prompt,
    bool Function()? isCancelled,
  }) async {
    // Check cancellation before starting
    if (isCancelled?.call() == true) {
      throw CancellationException();
    }

    // Create ephemeral session
    final session = await _client.createSession();
    final sessionId = session.sessionId;

    try {
      // Send prompt to the session
      await _client.prompt(
        sessionId,
        prompt,
        mode: PromptMode.queue,
      );

      // Check cancellation after sending prompt
      if (isCancelled?.call() == true) {
        throw CancellationException();
      }

      // Watch for response from the session
      // This is a simplified implementation - in reality we'd watch the session stream
      // for the AI response and extract the response text
      final response = await _waitForResponse(sessionId, isCancelled);

      // Check cancellation after getting response
      if (isCancelled?.call() == true) {
        throw CancellationException();
      }

      return response;
    } finally {
      // Archive the ephemeral session
      await _client.archiveSession(sessionId, stopActivity: true);
    }
  }

  /// Wait for AI response from the session.
  /// This is a simplified implementation - in reality we'd watch the session stream
  /// for the AI response and extract the response text.
  Future<String> _waitForResponse(String sessionId, bool Function()? isCancelled) async {
    // This is a simplified implementation
    // In reality, we'd watch the session stream for the AI response
    // For now, return a placeholder - the real implementation would watch the session stream
    // for the AI response events and extract the response text
    await Future.delayed(const Duration(seconds: 1));
    
    if (isCancelled?.call() == true) {
      throw CancellationException();
    }
    
    // Placeholder response - real implementation would extract from session stream
    return '{}';
  }

  @override
  void cancel() {
    // Cancellation is handled via the isCancelled callback
  }
}

/// Exception thrown when operation is cancelled.
class CancellationException implements Exception {
  @override
  String toString() => 'Operation cancelled';
}

/// Fake transport for testing.
class FakeCompletionTransport implements CompletionTransport {
  FakeCompletionTransport({
    this.response = '{}',
    this.shouldThrow = false,
    this.delay = Duration.zero,
  });

  final String response;
  final bool shouldThrow;
  final Duration delay;
  bool _cancelled = false;

  @override
  Future<String> complete({
    required String prompt,
    bool Function()? isCancelled,
  }) async {
    if (delay > Duration.zero) {
      await Future.delayed(delay);
    }

    if (_cancelled || isCancelled?.call() == true) {
      throw CancellationException();
    }

    if (shouldThrow) {
      throw Exception('Fake transport error');
    }

    return response;
  }

  @override
  void cancel() {
    _cancelled = true;
  }

  void reset() {
    _cancelled = false;
  }
}