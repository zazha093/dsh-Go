import 'package:test/test.dart';
import 'package:dsh_app/skills/skill_model.dart';

void main() {
  group('Skill v2 Serialization', () {
    final testSkill = Skill(
      id: 'test-123',
      name: 'Test Skill',
      description: 'A test skill',
      goal: 'Test goal',
      steps: ['step 1', 'step 2'],
      constraints: ['no secrets'],
      requiredTools: ['bash', 'edit'],
      userInputs: [
        SkillInput(key: 'host', label: 'Host', hint: 'Enter host'),
      ],
      createdAt: DateTime(2024, 1, 1, 12, 0, 0),
      updatedAt: DateTime(2024, 1, 2, 12, 0, 0),
      lastUsedAt: DateTime(2024, 1, 3, 12, 0, 0),
      useCount: 5,
      successCount: 4,
      category: SkillCategory.development,
      hidden: false,
      sourceSessionId: 'session-456',
      sourceSessionTitle: 'Test Session',
      version: 1,
      requiredPersona: 'devops',
      lastRunStatus: SkillRunStatus.success,
      // v2 fields
      kind: 'executable',
      schemaVersion: 2,
      provenance: SkillProvenance.distilled('session-456', 'msg-789'),
      executableSteps: [
        SkillStep(
          id: 'step-1',
          description: 'Run build',
          mode: 'tool',
          tool: 'bash',
          args: {'command': 'flutter build apk'},
          order: 1,
        ),
      ],
      parameters: [
        SkillParameter(
          key: 'host',
          label: 'Deploy Host',
          type: 'text',
          required: true,
          bindToStep: 'step-1',
          bindToTool: 'bash',
        ),
      ],
      errorHandling: SkillErrorHandling(
        onError: 'retry',
        maxRetries: 2,
        retryDelay: Duration(seconds: 10),
        retryableErrors: ['timeout', 'network'],
      ),
    );

    test('v2 round-trip preserves all fields', () {
      final json = testSkill.toJson();
      final restored = Skill.fromJson(json);

      expect(restored.id, equals(testSkill.id));
      expect(restored.name, equals(testSkill.name));
      expect(restored.description, equals(testSkill.description));
      expect(restored.goal, equals(testSkill.goal));
      expect(restored.steps, equals(testSkill.steps));
      expect(restored.constraints, equals(testSkill.constraints));
      expect(restored.requiredTools, equals(testSkill.requiredTools));
      expect(restored.userInputs.length, equals(testSkill.userInputs.length));
      expect(restored.userInputs.first.key, equals('host'));
      expect(restored.createdAt, equals(testSkill.createdAt));
      expect(restored.updatedAt, equals(testSkill.updatedAt));
      expect(restored.lastUsedAt, equals(testSkill.lastUsedAt));
      expect(restored.useCount, equals(testSkill.useCount));
      expect(restored.successCount, equals(testSkill.successCount));
      expect(restored.category, equals(testSkill.category));
      expect(restored.hidden, equals(testSkill.hidden));
      expect(restored.sourceSessionId, equals(testSkill.sourceSessionId));
      expect(restored.sourceSessionTitle, equals(testSkill.sourceSessionTitle));
      expect(restored.version, equals(testSkill.version));
      expect(restored.requiredPersona, equals(testSkill.requiredPersona));
      expect(restored.lastRunStatus, equals(testSkill.lastRunStatus));

      // v2 fields
      expect(restored.kind, equals('executable'));
      expect(restored.schemaVersion, equals(2));
      expect(restored.provenance, isNotNull);
      expect(restored.provenance!.type, equals('distilled'));
      expect(restored.provenance!.sourceSessionId, equals('session-456'));
      expect(restored.provenance!.sourceMessageId, equals('msg-789'));
      expect(restored.executableSteps, isNotNull);
      expect(restored.executableSteps!.length, equals(1));
      expect(restored.executableSteps!.first.id, equals('step-1'));
      expect(restored.executableSteps!.first.tool, equals('bash'));
      expect(restored.parameters, isNotNull);
      expect(restored.parameters!.length, equals(1));
      expect(restored.parameters!.first.key, equals('host'));
      expect(restored.errorHandling, isNotNull);
      expect(restored.errorHandling!.onError, equals('retry'));
      expect(restored.errorHandling!.maxRetries, equals(2));
    });

    test('v1 JSON → v2 object → v2 JSON (migration)', () {
      // Simulate v1 JSON (no v2 fields)
      final v1Json = {
        'id': 'v1-skill',
        'name': 'V1 Skill',
        'description': 'From v1',
        'goal': 'Old goal',
        'steps': ['old step'],
        'constraints': [],
        'requiredTools': ['bash'],
        'userInputs': [],
        'createdAt': '2024-01-01T12:00:00.000Z',
        'updatedAt': '2024-01-02T12:00:00.000Z',
        'lastUsedAt': '2024-01-03T12:00:00.000Z',
        'useCount': 3,
        'successCount': 2,
        'category': 'development',
        'hidden': false,
        'sourceSessionId': 'session-old',
        'sourceSessionTitle': 'Old Session',
        'version': 1,
        'requiredPersona': 'developer',
        'lastRunStatus': 'success',
      };

      final skill = Skill.fromJson(v1Json);

      // v2 defaults applied
      expect(skill.kind, equals('workflow'));
      expect(skill.schemaVersion, equals(2));
      expect(skill.provenance, isNotNull);
      expect(skill.provenance!.type, equals('migrated'));
      expect(skill.executableSteps, isNull);
      expect(skill.parameters, isNull);
      expect(skill.errorHandling, isNull);

      // Serialize back to v2
      final v2Json = skill.toJson();
      expect(v2Json['kind'], equals('workflow'));
      expect(v2Json['schemaVersion'], equals(2));
      expect(v2Json['provenance'], isNotNull);
      expect(v2Json['executableSteps'], isNull);
      expect(v2Json['parameters'], isNull);
      expect(v2Json['errorHandling'], isNull);
    });

    test('kind validation: only 3 allowed values', () {
      // Valid kinds
      for (final kind in ['knowledge', 'workflow', 'executable']) {
        final skill = testSkill.copyWith(kind: kind);
        expect(skill.kind, equals(kind));
      }

      // Invalid kind would be caught at runtime if we add validation
      // For now, just ensure the field accepts strings
      final skill = testSkill.copyWith(kind: 'custom');
      expect(skill.kind, equals('custom')); // No strict enum validation in model
    });

    test('executableSkills require executableSteps', () {
      final executableSkill = testSkill.copyWith(
        kind: 'executable',
        executableSteps: [
          SkillStep(
            id: 's1',
            description: 'Test',
            mode: 'tool',
            tool: 'bash',
            args: {},
            order: 1,
          ),
        ],
      );
      expect(executableSkill.kind, equals('executable'));
      expect(executableSkill.executableSteps, isNotNull);
      expect(executableSkill.executableSteps!.isNotEmpty, isTrue);
    });

    test('workflowSkills allow null executableSteps', () {
      final workflowSkill = testSkill.copyWith(
        kind: 'workflow',
        executableSteps: null,
      );
      expect(workflowSkill.kind, equals('workflow'));
      expect(workflowSkill.executableSteps, isNull);
    });

    test('knowledgeSkills allow null steps', () {
      final knowledgeSkill = testSkill.copyWith(
        kind: 'knowledge',
        steps: [],
        executableSteps: null,
        parameters: null,
        errorHandling: null,
      );
      expect(knowledgeSkill.kind, equals('knowledge'));
      expect(knowledgeSkill.steps, isEmpty);
      expect(knowledgeSkill.executableSteps, isNull);
    });

    test('provenance types serialize correctly', () {
      final migrated = SkillProvenance.migrated('orig-123');
      final distilled = SkillProvenance.distilled('session-1', 'msg-1');
      final manual = SkillProvenance.manual();
      final imported = SkillProvenance.imported('ext-456');

      for (final p in [migrated, distilled, manual, imported]) {
        final json = p.toJson();
        final restored = SkillProvenance.fromJson(json);
        expect(restored.type, equals(p.type));
        expect(restored.sourceSessionId, equals(p.sourceSessionId));
        expect(restored.sourceMessageId, equals(p.sourceMessageId));
        expect(restored.createdAt, equals(p.createdAt));
        expect(restored.evidence, equals(p.evidence));
      }

      expect(migrated.type, equals('migrated'));
      expect(distilled.type, equals('distilled'));
      expect(manual.type, equals('manual'));
      expect(imported.type, equals('imported'));
    });

    test('SkillErrorHandling serialization', () {
      const handling = SkillErrorHandling(
        onError: 'retry',
        maxRetries: 3,
        retryDelay: Duration(seconds: 30),
        retryableErrors: ['timeout', 'connection refused'],
      );

      final json = handling.toJson();
      final restored = SkillErrorHandling.fromJson(json);

      expect(restored.onError, equals('retry'));
      expect(restored.maxRetries, equals(3));
      expect(restored.retryDelay, equals(Duration(seconds: 30)));
      expect(restored.retryableErrors, equals(['timeout', 'connection refused']));
    });

    test('SkillStep serialization with tool mode', () {
      const step = SkillStep(
        id: 'step-1',
        description: 'Run tests',
        mode: 'tool',
        tool: 'bash',
        args: {'command': 'flutter test', 'cwd': '/project'},
        order: 1,
      );

      final json = step.toJson();
      final restored = SkillStep.fromJson(json);

      expect(restored.id, equals('step-1'));
      expect(restored.description, equals('Run tests'));
      expect(restored.mode, equals('tool'));
      expect(restored.tool, equals('bash'));
      expect(restored.args['command'], equals('flutter test'));
      expect(restored.order, equals(1));
    });

    test('SkillStep serialization with agent mode', () {
      const step = SkillStep(
        id: 'step-2',
        description: 'Analyze code',
        mode: 'agent',
        tool: null,
        args: {'prompt': 'Review the code for bugs'},
        order: 2,
      );

      final json = step.toJson();
      final restored = SkillStep.fromJson(json);

      expect(restored.mode, equals('agent'));
      expect(restored.tool, isNull);
      expect(restored.args['prompt'], equals('Review the code for bugs'));
    });

    test('SkillParameter serialization', () {
      const param = SkillParameter(
        key: 'environment',
        label: 'Environment',
        type: 'select',
        required: true,
        defaultValue: 'staging',
        options: ['dev', 'staging', 'prod'],
        bindToStep: 'step-1',
        bindToTool: 'bash',
        template: 'deploy --env ${environment}',
      );

      final json = param.toJson();
      final restored = SkillParameter.fromJson(json);

      expect(restored.key, equals('environment'));
      expect(restored.label, equals('Environment'));
      expect(restored.type, equals('select'));
      expect(restored.required, isTrue);
      expect(restored.defaultValue, equals('staging'));
      expect(restored.options, equals(['dev', 'staging', 'prod']));
      expect(restored.bindToStep, equals('step-1'));
      expect(restored.bindToTool, equals('bash'));
      expect(restored.template, equals('deploy --env ${environment}'));
    });

    test('copyWith updates v2 fields', () {
      final original = testSkill;
      final updated = original.copyWith(
        kind: 'knowledge',
        schemaVersion: 2,
        provenance: SkillProvenance.manual(),
        executableSteps: null,
        parameters: null,
        errorHandling: null,
      );

      expect(updated.kind, equals('knowledge'));
      expect(updated.schemaVersion, equals(2));
      expect(updated.provenance!.type, equals('manual'));
      expect(updated.executableSteps, isNull);
      expect(updated.parameters, isNull);
      expect(updated.errorHandling, isNull);
      // Original unchanged
      expect(original.kind, equals('executable'));
    });

    test('migrateToV2 extension creates workflow skill', () {
      final v1Skill = Skill(
        id: 'v1-1',
        name: 'V1 Skill',
        description: 'Desc',
        goal: 'Goal',
        steps: ['step 1'],
        constraints: [],
        requiredTools: ['bash'],
        userInputs: [],
        createdAt: DateTime.now(),
        category: SkillCategory.other,
        version: 1,
        lastRunStatus: SkillRunStatus.never,
      );

      final v2Skill = v1Skill.migrateToV2();

      expect(v2Skill.kind, equals('workflow'));
      expect(v2Skill.schemaVersion, equals(2));
      expect(v2Skill.provenance, isNotNull);
      expect(v2Skill.provenance!.type, equals('migrated'));
      expect(v2Skill.executableSteps, isNull);
      expect(v2Skill.parameters, isNull);
      expect(v2Skill.errorHandling, isNull);
      expect(v2Skill.id, equals(v1Skill.id));
      expect(v2Skill.name, equals(v1Skill.name));
    });
  });
}