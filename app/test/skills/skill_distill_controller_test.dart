// Skill Distill Controller Tests

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsh_client/dsh_client.dart';
import 'package:dsh_go/skills/skill_distill_controller.dart';
import 'package:dsh_go/skills/distill/types.dart';
import 'package:dsh_go/skills/skill_model.dart';

class MockDshClient extends Mock implements DshClient {}

class MockSession extends Mock implements DshSession {}

void main() {
  group('SkillDistillController', () {
    late ProviderContainer container;
    late MockDshClient mockClient;

    setUp(() {
      mockClient = MockDshClient();
      container = ProviderContainer(
        overrides: [
          // Override the forkSkillsAISummarizationControllerProvider to return true
          forkSkillsAISummarizationControllerProvider.overrideWith(
            (ref) => ForkSkillsAISummarizationController(),
          ),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('distillFromText generates rule-based draft instantly', () async {
      // Arrange
      final input = DistillInput(
        userMessage: 'Create a script to backup files',
        aiResponse: 'Here is a backup script...',
        toolCalls: ['bash'],
        toolCallsWithArgs: [
          ToolCallInfo(
            tool: 'bash',
            args: {'command': 'tar -czf backup.tar.gz /home/user'},
            result: 'Backup created',
          ),
        ],
        sessionTitle: 'Test Session',
        dshClient: null, // No client = rule-based only
      );

      // Act
      await container.read(skillDistillControllerProvider.notifier).distillFromText(input);

      // Assert
      final state = container.read(skillDistillControllerProvider);
      expect(state.status, DistillStatus.ready);
      expect(state.skill, isNotNull);
      expect(state.skill!.name, isNotEmpty);
      expect(state.aiProposedSkill, isNull);
    });

    test('distillFromText with AI enabled runs AI summarization', () async {
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
  "name": "AI Backup Skill",
  "kind": "workflow",
  "goal": "Backup files automatically",
  "description": "Creates compressed backups",
  "steps": ["Create backup", "Verify backup"],
  "constraints": ["Run daily"],
  "requiredTools": ["bash"],
  "parameters": []
}
''',
      ));

      when(() => mockClient.archiveSession(
        any(named: 'sessionId'),
        stopActivity: any(named: 'stopActivity'),
      )).thenAnswer((_) async => {});

      final input = DistillInput(
        userMessage: 'Create a script to backup files',
        aiResponse: 'Here is a backup script...',
        toolCalls: ['bash'],
        toolCallsWithArgs: [
          ToolCallInfo(
            tool: 'bash',
            args: {'command': 'tar -czf backup.tar.gz /home/user'},
            result: 'Backup created',
          ),
        ],
        sessionTitle: 'Test Session',
        dshClient: mockClient,
      );

      // Act
      await container.read(skillDistillControllerProvider.notifier).distillFromText(input);

      // Wait for AI to complete
      await Future.delayed(const Duration(milliseconds: 100));

      // Assert
      final state = container.read(skillDistillControllerProvider);
      expect(state.status, DistillStatus.ready);
      expect(state.aiProposedSkill, isNotNull);
      expect(state.aiProposedSkill!.name, 'AI Backup Skill');
    });

    test('cancel stops in-flight AI request', () async {
      // Arrange
      final mockSession = MockSession();
      when(() => mockSession.id).thenReturn('test-session');
      when(() => mockClient.createSession(
        cwd: any(named: 'cwd'),
        workspaceId: any(named: 'workspaceId'),
      )).thenAnswer((_) async => mockSession);

      // Delay the prompt response
      when(() => mockClient.prompt(
        sessionId: any(named: 'sessionId'),
        message: any(named: 'message'),
      )).thenAnswer((_) => Future.delayed(const Duration(seconds: 2)));

      when(() => mockClient.archiveSession(
        any(named: 'sessionId'),
        stopActivity: any(named: 'stopActivity'),
      )).thenAnswer((_) async => {});

      final input = DistillInput(
        userMessage: 'Test',
        toolCalls: ['bash'],
        sessionTitle: 'Test',
        dshClient: mockClient,
      );

      // Act - start distillation then cancel immediately
      final controller = container.read(skillDistillControllerProvider.notifier);
      controller.distillFromText(input);
      await Future.delayed(const Duration(milliseconds: 50));
      controller.cancel();

      // Wait for cancellation to process
      await Future.delayed(const Duration(milliseconds: 100));

      // Assert
      final state = container.read(skillDistillControllerProvider);
      expect(state.status, DistillStatus.cancelled);
      expect(state.aiProposedSkill, isNull);
    });

    test('disposed controller discards results silently', () async {
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
        text: '{"name":"Test","kind":"workflow","goal":"Test","description":"Test","steps":[],"constraints":[],"requiredTools":[],"parameters":[]}',
      ));

      when(() => mockClient.archiveSession(
        any(named: 'sessionId'),
        stopActivity: any(named: 'stopActivity'),
      )).thenAnswer((_) async => {});

      final input = DistillInput(
        userMessage: 'Test',
        toolCalls: ['bash'],
        sessionTitle: 'Test',
        dshClient: mockClient,
      );

      // Act - start distillation then dispose container
      container.read(skillDistillControllerProvider.notifier).distillFromText(input);
      await Future.delayed(const Duration(milliseconds: 50));
      container.dispose();

      // Wait for AI to complete (should be discarded silently)
      await Future.delayed(const Duration(milliseconds: 200));

      // Assert - no exception should be thrown
      // This test passes if no exception occurs during disposal
    });

    test('AI disabled setting skips AI summarization', () async {
      // Arrange - create container with AI disabled
      final disabledContainer = ProviderContainer(
        overrides: [
          forkSkillsAISummarizationControllerProvider.overrideWith(
            (ref) {
              final c = ForkSkillsAISummarizationController();
              c.state = false;
              return c;
            },
          ),
        ],
      );

      final input = DistillInput(
        userMessage: 'Test',
        toolCalls: ['bash'],
        sessionTitle: 'Test',
        dshClient: mockClient,
      );

      // Act
      await disabledContainer.read(skillDistillControllerProvider.notifier).distillFromText(input);

      // Assert
      final state = disabledContainer.read(skillDistillControllerProvider);
      expect(state.status, DistillStatus.ready);
      expect(state.aiProposedSkill, isNull);

      disabledContainer.dispose();
    });
  });
}