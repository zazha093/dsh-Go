// Completion Transport for AI Summarization
//
// Lower layer interface that wraps DshClient's complete method.
// This layer is fakeable for testing - tests can provide a fake transport.

import 'dart:async';

import 'package:dsh_client/dsh_client.dart';

/// Interface for AI completion transport.
/// 
/// This is the lower layer that can be faked in tests.
/// The real implementation wraps DshClient's complete method.
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

/// Real implementation wrapping DshClient.
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

    final result = await _client.complete(
      prompt: prompt,
      options: const <String, dynamic>{},
      isCancelled: isCancelled,
    );

    // Check cancellation after completion
    if (isCancelled?.call() == true) {
      throw CancellationException();
    }

    return result;
  }

  @override
  void cancel() {
    // DshClient doesn't have a direct cancel for complete(),
    // but the isCancelled callback will handle it
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