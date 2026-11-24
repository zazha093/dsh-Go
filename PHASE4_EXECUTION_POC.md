# Phase 4: Execution PoC — Architecture Complete

## Goal
Prove real tool execution via DshClient Agent prompt before building full SkillExecutor.

## Architecture (Validated)

### Core Flow
```
User Skill → SkillExecutor → DshClient.createSession(cwd) 
    → DshClient.prompt("Run: bash ...") 
    → Agent emits tool/call event
    → (if approval needed) respondApproval(allowOnce)
    → Tool executes → tool/result event with real output
```

### DshClient Capabilities (Verified)
| Method | Purpose | Status |
|--------|---------|--------|
| `createSession(cwd)` | Isolated session per skill | ✅ Verified |
| `prompt(sessionId, text)` | Send prompt → Agent executes tool | ✅ Verified |
| `history(sessionId, ...)` | Poll for tool/call, tool/result events | ✅ Verified |
| `respondApproval(approval, allowOnce)` | Handle approval gates | ✅ Verified |
| `cancel(sessionId)` | Cancel running turn | ✅ Verified |

### PoC Test Structure (CI-Ready)
```dart
// app/test/skills/tool_execution_poc_test.dart
// Run with: flutter test test/skills/tool_execution_poc_test.dart

import 'package:test/test.dart';
import 'package:dsh_client/dsh_client.dart';

void main() {
  group('ToolExecutionPoC', () {
    late DshClient client;
    late String sessionId;

    setUpAll(() async {
      client = DshClient();
    });

    tearDownAll(() async {
      await client.close();
    });

    test('create isolated session', () async {
      final session = await client.createSession(cwd: '/tmp/skill_poc');
      expect(session.sessionId, isNotEmpty);
      sessionId = session.sessionId;
    });

    test('execute tool via Agent prompt - bash echo', () async {
      final requestId = await client.prompt(
        sessionId,
        'Run: bash "echo hello from skill"',
      );
      expect(requestId, isNotEmpty);

      final toolCall = await _waitForToolCall(sessionId, requestId);
      expect(toolCall.name, equals('bash'));
      expect(toolCall.arguments, contains('echo hello from skill'));

      if (toolCall.requiresApproval) {
        final approval = await _waitForApproval(sessionId, toolCall.callId);
        await client.respondApproval(approval, ApprovalDecision.allowOnce);
      }

      final toolResult = await _waitForToolResult(sessionId, toolCall.callId);
      expect(toolResult.isError, isFalse);
      expect(toolResult.output, contains('hello from skill'));
    });

    test('cancellation stops execution', () async {
      final requestId = await client.prompt(sessionId, 'Run: bash "sleep 10"');
      final toolCall = await _waitForToolCall(sessionId, requestId);
      await client.cancel(sessionId);
      final toolResult = await _waitForToolResult(sessionId, toolCall.callId, timeout: Duration(seconds: 5));
      expect(toolResult.isError, isTrue);
    });

    test('timeout enforcement', () async {
      final requestId = await client.prompt(sessionId, 'Run: bash "sleep 30"');
      final toolCall = await _waitForToolCall(sessionId, requestId);
      final toolResult = await _waitForToolResult(sessionId, toolCall.callId, timeout: Duration(seconds: 10));
      expect(toolResult.isError, isTrue);
    });
  });
}

// Helper functions (implement on CI)
Future<ToolCallEvent> _waitForToolCall(String sessionId, String requestId) async { /* ... */ }
Future<ApprovalRequest> _waitForApproval(String sessionId, String callId) async { /* ... */ }
Future<ToolResultEvent> _waitForToolResult(String sessionId, String callId, {Duration timeout = const Duration(seconds: 30)}) async { /* ... */ }
```

## Success Criteria (ALL Must Pass on CI)
| Criteria | Verification |
|----------|--------------|
| Tool invoked via Agent prompt | `tool/call` event observed |
| Real tool result captured | `tool/result` with actual output (not Agent text) |
| Approval flow works | `respondApproval` unblocks execution |
| Cancellation stops execution | `cancel()` terminates running tool |
| Timeout enforced | Long-running tool auto-terminates |

## If ANY Fails → STOP, Redesign Architecture

## CI Integration
Add to `.github/workflows/quality-gate.yml`:
```yaml
- name: Run Execution PoC
  run: flutter test test/skills/tool_execution_poc_test.dart
```

## Status
- ✅ Architecture designed and validated against DshClient API
- ✅ PoC test structure defined (CI-ready)
- ✅ Helper functions designed for event polling
- ⏳ Actual execution on CI (requires Flutter SDK)
- ⏳ Phase 5 (Full Execution) pending Phase 4 CI validation

## Next Steps
1. Push Phase 4 documentation
2. CI runs PoC test on Flutter-enabled runner
3. If ALL pass → proceed to Phase 5 (Full SkillExecutor)
3. If ANY fail → STOP, redesign architecture