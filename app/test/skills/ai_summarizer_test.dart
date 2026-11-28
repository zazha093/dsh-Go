// AI Summarizer Tests

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:dsh_client/dsh_client.dart';
import 'package:dsh_go/fork/ai_summarizer.dart';
import 'package:dsh_go/skills/skill_model.dart';
import 'package:dsh_go/skills/distill/types.dart';

class MockDshClient extends Mock implements DshClient {}

class MockSession extends Mock implements DshSession {}

void main() {
  group('AiSummarizer', () {
    late MockDshClient mockClient;
    late AiSummarizer summarizer;

    setUp(() {
      mockClient = MockDshClient();
      summarizer = AiSummarizer(client: mockClient);
    });

    test('summarize returns skill from AI response', () async {
      // Arrange
      final mockSession = MockSession();
      when(() => mockSession.id).thenReturn('test-session');
      when(() => mockClient.createSession(
        cwd: any(named: 'cwd'),
        workspaceId: any(named: 'workspaceId'),
      )).thenAnswer((_) async => mockSession);

      when(() => mockClient.prompt(
        sessionId: any(named: 'sessionId'),
        message: any(named: 'message'),
      )).thenAnswer((_) async => DshPromptResponse(
        requestId: 'req-1',
        text: '''
{
  "name": "Test Skill",
  "kind": "workflow",
  "goal": "Test goal",
  "description": "Test description",
  "steps": ["Step 1", "Step 2"],
  "constraints": ["Constraint 1"],
  "requiredTools": ["bash"],
  "parameters": []
}
''',
      ));

      when(() => mockClient.archiveSession(
        any(named: 'sessionId'),
        stopActivity: any(named: 'stopActivity'),
      )).thenAnswer((_) async => {});

      // Act
      final result = await summarizer.summarize(
        userMessage: 'Test user message',
        aiResponse: 'Test AI response',
        toolCallsWithArgs: [],
        sessionTitle: 'Test Session',
      );

      // Assert
      expect(result.skill.name, 'Test Skill');
      expect(result.skill.kind, 'workflow');
      expect(result.skill.goal, 'Test goal');
      expect(result.fromCache, false);
      expect(result.breadcrumb, contains('ai:ok'));
    });

    test('summarize redacts sensitive data in prompt', () async {
      // Arrange
      final mockSession = MockSession();
      when(() => mockSession.id).thenReturn('test-session');
      when(() => mockClient.createSession(
        cwd: any(named: 'cwd'),
        workspaceId: any(named: 'workspaceId'),
      )).thenAnswer((_) async => mockSession);

      String? capturedPrompt;
      when(() => mockClient.prompt(
        sessionId: any(named: 'sessionId'),
        message: any(named: 'message'),
      )).thenAnswer((invocation) {
        capturedPrompt = invocation.namedArguments['message'] as String;
        return Future.value(DshPromptResponse(
          requestId: 'req-1',
          text: '{"name":"Test","kind":"workflow","goal":"Test","description":"Test","steps":[],"constraints":[],"requiredTools":[],"parameters":[]}',
        ));
      });

      when(() => mockClient.archiveSession(
        any(named: 'sessionId'),
        stopActivity: any(named: 'stopActivity'),
      )).thenAnswer((_) async => {});

      // Act
      await summarizer.summarize(
        userMessage: 'My API key is sk-1234567890abcdef',
        aiResponse: 'Bearer token-abcdef',
        toolCallsWithArgs: [],
        sessionTitle: 'Test',
      );

      // Assert - prompt should not contain raw secrets
      expect(capturedPrompt, isNot(contains('sk-1234567890abcdef')));
      expect(capturedPrompt, isNot(contains('Bearer token-abcdef')));
      expect(capturedPrompt, contains('<redacted>'));
    });

    test('summarize truncates long inputs', () async {
      // Arrange
      final mockSession = MockSession();
      when(() => mockSession.id).thenReturn('test-session');
      when(() => mockClient.createSession(
        cwd: any(named: 'cwd'),
        workspaceId: any(named: 'workspaceId'),
      )).thenAnswer((_) async => mockSession);

      String? capturedPrompt;
      when(() => mockClient.prompt(
        sessionId: any(named: 'sessionId'),
        message: any(named: 'message'),
      )).thenAnswer((invocation) {
        capturedPrompt = invocation.namedArguments['message'] as String;
        return Future.value(DshPromptResponse(
          requestId: 'req-1',
          text: '{"name":"Test","kind":"workflow","goal":"Test","description":"Test","steps":[],"constraints":[],"requiredTools":[],"parameters":[]}',
        ));
      });

      when(() => mockClient.archiveSession(
        any(named: 'sessionId'),
        stopActivity: any(named: 'stopActivity'),
      )).thenAnswer((_) async => {});

      // Act - very long user message
      final longMessage = 'x' * 5000;
      await summarizer.summarize(
        userMessage: longMessage,
        aiResponse: null,
        toolCallsWithArgs: [],
        sessionTitle: 'Test',
      );

      // Assert - should be truncated to maxUserMessageChars (1500)
      expect(capturedPrompt!.length, lessThanOrEqualTo(10000)); // Total prompt budget
    });

    test('summarize throws on timeout', () async {
      // Arrange
      final mockSession = MockSession();
      when(() => mockSession.id).thenReturn('test-session');
      when(() => mockClient.createSession(
        cwd: any(named: 'cwd'),
        workspaceId: any(named: 'workspaceId'),
      )).thenAnswer((_) async => mockSession);

      when(() => mockClient.prompt(
        sessionId: any(named: 'sessionId'),
        message: any(named: 'message'),
      )).thenAnswer((_) => Future.delayed(const Duration(seconds: 30)));

      when(() => mockClient.archiveSession(
        any(named: 'sessionId'),
        stopActivity: any(named: 'stopActivity'),
      )).thenAnswer((_) async => {});

      // Act & Assert
      expect(
        () => summarizer.summarize(
          userMessage: 'Test',
          aiResponse: null,
          toolCallsWithArgs: [],
          sessionTitle: 'Test',
        ),
        throwsA(isA<TimeoutException>()),
      );
    });

    test('parses JSON from markdown fences', () async {
      // Arrange
      final mockSession = MockSession();
      when(() => mockSession.id).thenReturn('test-session');
      when(() => mockClient.createSession(
        cwd: any(named: 'cwd'),
        workspaceId: any(named: 'workspaceId'),
      )).thenAnswer((_) async => mockSession);

      when(() => mockClient.prompt(
        sessionId: any(named: 'sessionId'),
        message: any(named: 'message'),
      )).thenAnswer((_) async => DshPromptResponse(
        requestId: 'req-1',
        text: '''
```json
{
  "name": "Fenced Skill",
  "kind": "executable",
  "goal": "Test goal",
  "description": "Test description",
  "steps": [],
  "constraints": [],
  "requiredTools": [],
  "parameters": []
}
```
''',
      ));

      when(() => mockClient.archiveSession(
        any(named: 'sessionId'),
        stopActivity: any(named: 'stopActivity'),
      )).thenAnswer((_) async => {});

      // Act
      final result = await summarizer.summarize(
        userMessage: 'Test',
        aiResponse: null,
        toolCallsWithArgs: [],
        sessionTitle: 'Test',
      );

      // Assert
      expect(result.skill.name, 'Fenced Skill');
      expect(result.skill.kind, 'executable');
    });
  });
}