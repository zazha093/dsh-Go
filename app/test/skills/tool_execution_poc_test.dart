// Tool Execution PoC — proves real tool execution via DshClient Agent prompt
// This is a throwaway test to validate architecture before building full SkillExecutor
// Run with: flutter test test/skills/tool_execution_poc_test.dart
// Requires: DSH server running at DSH_TEST_URL or default http://127.0.0.1:3080
// If no server is available, tests are skipped (not failed) so CI doesn't block.

import 'package:flutter_test/flutter_test.dart';
import 'dart:async';
import 'dart:io';
import 'package:dsh_client/dsh_client.dart';

void main() {
  group('ToolExecutionPoC', () {
    late DshClient client;
    late String sessionId;
    late String launchUrl;
    bool serverAvailable = false;

    setUpAll(() async {
      // Get launch URL from environment or use default
      launchUrl = Platform.environment['DSH_TEST_URL'] ?? 'http://127.0.0.1:3080';
      
      // Try to connect to server - if unavailable, skip all tests
      try {
        client = await DshClient.connect(launchUrl: launchUrl);
        serverAvailable = true;
      } catch (e) {
        // Server not available - mark as unavailable, tests will be skipped
        serverAvailable = false;
        // ignore: avoid_print
        print('DSH server not available at $launchUrl: $e');
        // ignore: avoid_print
        print('Skipping ToolExecutionPoC tests.');
      }
    });

    tearDownAll(() async {
      if (serverAvailable && sessionId.isNotEmpty) {
        try {
          await client.cancel(sessionId);
        } catch (_) {}
        await client.close();
      }
    });

    test('create isolated session', () async {
      if (!serverAvailable) {
        return; // Skip test
      }
      final session = await client.createSession(cwd: '/tmp/skill_poc');
      expect(session.sessionId, isNotEmpty);
      sessionId = session.sessionId;
    });

    test('execute tool via Agent prompt - bash echo', () async {
      if (!serverAvailable) {
        return; // Skip test
      }
      final requestId = await client.prompt(
        sessionId,
        'Run: bash "echo hello from skill"',
      );
      expect(requestId, isNotEmpty);

      // Watch for tool/call event
      final toolCall = await _waitForToolCall(client, sessionId, requestId);
      expect(toolCall.name, equals('bash'));
      expect(toolCall.arguments, contains('echo hello from skill'));

      // Watch for approval if needed
      final approval = await _waitForApproval(client, sessionId, toolCall.callId, timeout: const Duration(seconds: 5));
      if (approval != null) {
        await client.respondApproval(approval, ApprovalDecision.allowOnce);
      }

      // Watch for tool/result
      final toolResult = await _waitForToolResult(client, sessionId, toolCall.callId);
      expect(toolResult.isError, isFalse);
      expect(toolResult.message.text, contains('hello from skill'));
    });

    test('cancellation stops execution', () async {
      if (!serverAvailable) {
        return; // Skip test
      }
      final requestId = await client.prompt(
        sessionId,
        'Run: bash "sleep 10"',
      );

      final toolCall = await _waitForToolCall(client, sessionId, requestId);
      expect(toolCall.name, equals('bash'));

      await client.cancel(sessionId);

      final toolResult = await _waitForToolResult(
        client,
        sessionId,
        toolCall.callId,
        timeout: const Duration(seconds: 5),
      );
      expect(toolResult.isError, isTrue);
    });

    test('timeout enforcement', () async {
      if (!serverAvailable) {
        return; // Skip test
      }
      final requestId = await client.prompt(
        sessionId,
        'Run: bash "sleep 30"',
      );

      final toolCall = await _waitForToolCall(client, sessionId, requestId);

      final toolResult = await _waitForToolResult(
        client,
        sessionId,
        toolCall.callId,
        timeout: const Duration(seconds: 10),
      );
      expect(toolResult.isError, isTrue);
    });
  });
}

// Helper: Wait for ToolCallEvent via watch stream
Future<ToolCallEvent> _waitForToolCall(
  DshClient client,
  String sessionId,
  String requestId, {
  Duration timeout = const Duration(seconds: 30),
}) async {
  final completer = Completer<ToolCallEvent>();
  late final StreamSubscription<DshEvent> subscription;
  
  subscription = client.watch(sessionId).listen((event) {
    if (event is ToolCallEvent && event.callId == requestId) {
      if (!completer.isCompleted) completer.complete(event);
    }
  });

  try {
    return await completer.future.timeout(timeout);
  } on TimeoutException {
    await subscription.cancel();
    throw TimeoutException('Tool call not found for requestId: $requestId');
  }
}

// Helper: Wait for ApprovalRequestedEvent
Future<ApprovalRequest?> _waitForApproval(
  DshClient client,
  String sessionId,
  String callId, {
  Duration timeout = const Duration(seconds: 30),
}) async {
  final completer = Completer<ApprovalRequest?>();
  bool found = false;
  
  late final StreamSubscription<DshEvent> subscription;
  subscription = client.watch(sessionId).listen((event) {
    if (found) return;
    if (event is ApprovalRequestedEvent && event.request.callId == callId) {
      found = true;
      completer.complete(event.request);
    }
  });

  try {
    return await completer.future.timeout(timeout);
  } on TimeoutException {
    await subscription.cancel();
    return null; // No approval needed
  }
}

// Helper: Wait for ToolResultEvent
Future<ToolResultEvent> _waitForToolResult(
  DshClient client,
  String sessionId,
  String callId, {
  Duration timeout = const Duration(seconds: 30),
}) async {
  final completer = Completer<ToolResultEvent>();
  late final StreamSubscription<DshEvent> subscription;
  
  subscription = client.watch(sessionId).listen((event) {
    if (event is ToolResultEvent && event.callId == callId) {
      if (!completer.isCompleted) completer.complete(event);
    }
  });

  try {
    return await completer.future.timeout(timeout);
  } on TimeoutException {
    await subscription.cancel();
    throw TimeoutException('Tool result not found for callId: $callId');
  }
}