// Tests for DraftValidator — field-level validation with rule-based fallback

import 'package:flutter_test/flutter_test.dart';

import 'package:dsh_app/fork/draft_validator.dart';
import 'package:dsh_app/skills/skill_model.dart';

void main() {
  group('DraftValidator', () {
    group('validate() — full skill validation', () {
      test('returns rule-based skill when AI skill is empty', () {
        final validator = DraftValidator(locale: 'en');
        final aiSkill = Skill(
          id: 'ai-1',
          name: '',
          description: '',
          goal: '',
          steps: [],
          constraints: [],
          requiredTools: [],
          userInputs: [],
          createdAt: DateTime(2024, 1, 1),
          category: SkillCategory.development,
        );
        final ruleSkill = Skill(
          id: 'rule-1',
          name: 'Rule Skill',
          description: 'Rule description',
          goal: 'Rule goal',
          steps: ['step 1', 'step 2'],
          constraints: ['constraint 1'],
          requiredTools: ['bash', 'edit'],
          userInputs: [],
          createdAt: DateTime(2024, 1, 1),
          category: SkillCategory.development,
        );

        final result = validator.validate(aiSkill, ruleSkill);

        expect(result.name, 'Rule Skill');
        expect(result.goal, 'Rule goal');
        expect(result.steps, ['step 1', 'step 2']);
        expect(result.requiredTools, ['bash', 'edit']);
      });

      test('keeps valid AI fields, falls back for invalid', () {
        final validator = DraftValidator(locale: 'en');
        final aiSkill = Skill(
          id: 'ai-1',
          name: 'Valid Name',
          description: 'Valid description',
          goal: 'Valid goal',
          steps: ['step with action verb'],
          constraints: ['valid constraint'],
          requiredTools: ['bash'],
          userInputs: [],
          createdAt: DateTime(2024, 1, 1),
          category: SkillCategory.development,
        );
        final ruleSkill = Skill(
          id: 'rule-1',
          name: 'Rule Skill',
          description: 'Rule description',
          goal: 'Rule goal',
          steps: ['rule step'],
          constraints: ['rule constraint'],
          requiredTools: ['bash', 'edit'],
          userInputs: [],
          createdAt: DateTime(2024, 1, 1),
          category: SkillCategory.development,
        );

        final result = validator.validate(aiSkill, ruleSkill);

        expect(result.name, 'Valid Name');
        expect(result.description, 'Valid description');
        expect(result.goal, 'Valid goal');
      });
    });

    group('_validateName', () {
      test('falls back for empty name', () {
        final validator = DraftValidator(locale: 'en');
        final result = validator.validate(
          Skill(
            id: '1',
            name: '',
            description: '',
            goal: '',
            steps: [],
            constraints: [],
            requiredTools: [],
            userInputs: [],
            createdAt: DateTime.now(),
            category: SkillCategory.development,
          ),
          Skill(
            id: '2',
            name: 'Rule Name',
            description: '',
            goal: '',
            steps: [],
            constraints: [],
            requiredTools: [],
            userInputs: [],
            createdAt: DateTime.now(),
            category: SkillCategory.development,
          ),
        );
        expect(result.name, 'Rule Name');
      });

      test('falls back for generic name', () {
        final validator = DraftValidator(locale: 'en');
        final result = validator.validate(
          Skill(
            id: '1',
            name: 'draft',
            description: '',
            goal: '',
            steps: [],
            constraints: [],
            requiredTools: [],
            userInputs: [],
            createdAt: DateTime.now(),
            category: SkillCategory.development,
          ),
          Skill(
            id: '2',
            name: 'Rule Name',
            description: '',
            goal: '',
            steps: [],
            constraints: [],
            requiredTools: [],
            userInputs: [],
            createdAt: DateTime.now(),
            category: SkillCategory.development,
          ),
        );
        expect(result.name, 'Rule Name');
      });

      test('falls back for too long name', () {
        final validator = DraftValidator(locale: 'en');
        final longName = 'a' * 61;
        final result = validator.validate(
          Skill(
            id: '1',
            name: longName,
            description: '',
            goal: '',
            steps: [],
            constraints: [],
            requiredTools: [],
            userInputs: [],
            createdAt: DateTime.now(),
            category: SkillCategory.development,
          ),
          Skill(
            id: '2',
            name: 'Rule Name',
            description: '',
            goal: '',
            steps: [],
            constraints: [],
            requiredTools: [],
            userInputs: [],
            createdAt: DateTime.now(),
            category: SkillCategory.development,
          ),
        );
        expect(result.name, 'Rule Name');
      });

      test('allows CJK for Thai locale', () {
        final validator = DraftValidator(locale: 'th');
        final result = validator.validate(
          Skill(
            id: '1',
            name: 'สร้างสคริปต์',
            description: '',
            goal: '',
            steps: [],
            constraints: [],
            requiredTools: [],
            userInputs: [],
            createdAt: DateTime.now(),
            category: SkillCategory.development,
          ),
          Skill(
            id: '2',
            name: 'Rule Name',
            description: '',
            goal: '',
            steps: [],
            constraints: [],
            requiredTools: [],
            userInputs: [],
            createdAt: DateTime.now(),
            category: SkillCategory.development,
          ),
        );
        expect(result.name, 'สร้างสคริปต์');
      });

      test('falls back for CJK in English locale', () {
        final validator = DraftValidator(locale: 'en');
        final result = validator.validate(
          Skill(
            id: '1',
            name: '创建脚本',
            description: '',
            goal: '',
            steps: [],
            constraints: [],
            requiredTools: [],
            userInputs: [],
            createdAt: DateTime.now(),
            category: SkillCategory.development,
          ),
          Skill(
            id: '2',
            name: 'Rule Name',
            description: '',
            goal: '',
            steps: [],
            constraints: [],
            requiredTools: [],
            userInputs: [],
            createdAt: DateTime.now(),
            category: SkillCategory.development,
          ),
        );
        expect(result.name, 'Rule Name');
      });

      test('trims whitespace', () {
        final validator = DraftValidator(locale: 'en');
        final result = validator.validate(
          Skill(
            id: '1',
            name: '  Valid Name  ',
            description: '',
            goal: '',
            steps: [],
            constraints: [],
            requiredTools: [],
            userInputs: [],
            createdAt: DateTime.now(),
            category: SkillCategory.development,
          ),
          Skill(
            id: '2',
            name: 'Rule Name',
            description: '',
            goal: '',
            steps: [],
            constraints: [],
            requiredTools: [],
            userInputs: [],
            createdAt: DateTime.now(),
            category: SkillCategory.development,
          ),
        );
        expect(result.name, 'Valid Name');
      });
    });

    group('_validateKind', () {
      test('accepts valid kinds', () {
        final validator = DraftValidator(locale: 'en');
        for (final kind in ['knowledge', 'workflow', 'executable']) {
          final result = validator.validate(
            Skill(
              id: '1',
              name: 'Name',
              description: '',
              goal: '',
              steps: [],
              constraints: [],
              requiredTools: [],
              userInputs: [],
              createdAt: DateTime.now(),
              category: SkillCategory.development,
              kind: kind,
            ),
            Skill(
              id: '2',
              name: 'Rule',
              description: '',
              goal: '',
              steps: [],
              constraints: [],
              requiredTools: [],
              userInputs: [],
              createdAt: DateTime.now(),
              category: SkillCategory.development,
              kind: 'workflow',
            ),
          );
          expect(result.kind, kind);
        }
      });

      test('falls back for invalid kind', () {
        final validator = DraftValidator(locale: 'en');
        final result = validator.validate(
          Skill(
            id: '1',
            name: 'Name',
            description: '',
            goal: '',
            steps: [],
            constraints: [],
            requiredTools: [],
            userInputs: [],
            createdAt: DateTime.now(),
            category: SkillCategory.development,
            kind: 'invalid',
          ),
          Skill(
            id: '2',
            name: 'Rule',
            description: '',
            goal: '',
            steps: [],
            constraints: [],
            requiredTools: [],
            userInputs: [],
            createdAt: DateTime.now(),
            category: SkillCategory.development,
            kind: 'workflow',
          ),
        );
        expect(result.kind, 'workflow');
      });

      test('case insensitive', () {
        final validator = DraftValidator(locale: 'en');
        final result = validator.validate(
          Skill(
            id: '1',
            name: 'Name',
            description: '',
            goal: '',
            steps: [],
            constraints: [],
            requiredTools: [],
            userInputs: [],
            createdAt: DateTime.now(),
            category: SkillCategory.development,
            kind: 'KNOWLEDGE',
          ),
          Skill(
            id: '2',
            name: 'Rule',
            description: '',
            goal: '',
            steps: [],
            constraints: [],
            requiredTools: [],
            userInputs: [],
            createdAt: DateTime.now(),
            category: SkillCategory.development,
            kind: 'workflow',
          ),
        );
        expect(result.kind, 'knowledge');
      });
    });

    group('_validateGoal', () {
      test('falls back for empty goal', () {
        final validator = DraftValidator(locale: 'en');
        final result = validator.validate(
          Skill(
            id: '1',
            name: 'Name',
            description: '',
            goal: '',
            steps: [],
            constraints: [],
            requiredTools: [],
            userInputs: [],
            createdAt: DateTime.now(),
            category: SkillCategory.development,
          ),
          Skill(
            id: '2',
            name: 'Rule',
            description: '',
            goal: 'Rule Goal',
            steps: [],
            constraints: [],
            requiredTools: [],
            userInputs: [],
            createdAt: DateTime.now(),
            category: SkillCategory.development,
          ),
        );
        expect(result.goal, 'Rule Goal');
      });

      test('falls back for too long goal', () {
        final validator = DraftValidator(locale: 'en');
        final longGoal = 'a' * 301;
        final result = validator.validate(
          Skill(
            id: '1',
            name: 'Name',
            description: '',
            goal: longGoal,
            steps: [],
            constraints: [],
            requiredTools: [],
            userInputs: [],
            createdAt: DateTime.now(),
            category: SkillCategory.development,
          ),
          Skill(
            id: '2',
            name: 'Rule',
            description: '',
            goal: 'Rule Goal',
            steps: [],
            constraints: [],
            requiredTools: [],
            userInputs: [],
            createdAt: DateTime.now(),
            category: SkillCategory.development,
          ),
        );
        expect(result.goal, 'Rule Goal');
      });

      test('allows CJK for Thai locale', () {
        final validator = DraftValidator(locale: 'th');
        final result = validator.validate(
          Skill(
            id: '1',
            name: 'Name',
            description: '',
            goal: 'สร้างสคริปต์สำหรับแบกอัป',
            steps: [],
            constraints: [],
            requiredTools: [],
            userInputs: [],
            createdAt: DateTime.now(),
            category: SkillCategory.development,
          ),
          Skill(
            id: '2',
            name: 'Rule',
            description: '',
            goal: 'Rule Goal',
            steps: [],
            constraints: [],
            requiredTools: [],
            userInputs: [],
            createdAt: DateTime.now(),
            category: SkillCategory.development,
          ),
        );
        expect(result.goal, 'สร้างสคริปต์สำหรับแบกอัป');
      });
    });

    group('_validateDescription', () {
      test('falls back for empty description', () {
        final validator = DraftValidator(locale: 'en');
        final result = validator.validate(
          Skill(
            id: '1',
            name: 'Name',
            description: '',
            goal: 'Goal',
            steps: [],
            constraints: [],
            requiredTools: [],
            userInputs: [],
            createdAt: DateTime.now(),
            category: SkillCategory.development,
          ),
          Skill(
            id: '2',
            name: 'Rule',
            description: 'Rule Desc',
            goal: 'Goal',
            steps: [],
            constraints: [],
            requiredTools: [],
            userInputs: [],
            createdAt: DateTime.now(),
            category: SkillCategory.development,
          ),
        );
        expect(result.description, 'Rule Desc');
      });

      test('falls back for too long description', () {
        final validator = DraftValidator(locale: 'en');
        final longDesc = 'a' * 201;
        final result = validator.validate(
          Skill(
            id: '1',
            name: 'Name',
            description: longDesc,
            goal: 'Goal',
            steps: [],
            constraints: [],
            requiredTools: [],
            userInputs: [],
            createdAt: DateTime.now(),
            category: SkillCategory.development,
          ),
          Skill(
            id: '2',
            name: 'Rule',
            description: 'Rule Desc',
            goal: 'Goal',
            steps: [],
            constraints: [],
            requiredTools: [],
            userInputs: [],
            createdAt: DateTime.now(),
            category: SkillCategory.development,
          ),
        );
        expect(result.description, 'Rule Desc');
      });
    });

    group('_validateSteps', () {
      test('falls back for empty steps', () {
        final validator = DraftValidator(locale: 'en');
        final result = validator.validate(
          Skill(
            id: '1',
            name: 'Name',
            description: '',
            goal: 'Goal',
            steps: [],
            constraints: [],
            requiredTools: [],
            userInputs: [],
            createdAt: DateTime.now(),
            category: SkillCategory.development,
          ),
          Skill(
            id: '2',
            name: 'Rule',
            description: '',
            goal: 'Goal',
            steps: ['rule step'],
            constraints: [],
            requiredTools: [],
            userInputs: [],
            createdAt: DateTime.now(),
            category: SkillCategory.development,
          ),
        );
        expect(result.steps, ['rule step']);
      });

      test('filters steps without action verbs', () {
        final validator = DraftValidator(locale: 'en');
        final result = validator.validate(
          Skill(
            id: '1',
            name: 'Name',
            description: '',
            goal: 'Goal',
            steps: ['this has no verb', 'create a script'],
            constraints: [],
            requiredTools: [],
            userInputs: [],
            createdAt: DateTime.now(),
            category: SkillCategory.development,
          ),
          Skill(
            id: '2',
            name: 'Rule',
            description: '',
            goal: 'Goal',
            steps: ['rule step'],
            constraints: [],
            requiredTools: [],
            userInputs: [],
            createdAt: DateTime.now(),
            category: SkillCategory.development,
          ),
        );
        expect(result.steps, ['create a script']);
      });

      test('limits to 8 steps', () {
        final validator = DraftValidator(locale: 'en');
        final manySteps = List.generate(10, (i) => 'create step $i');
        final result = validator.validate(
          Skill(
            id: '1',
            name: 'Name',
            description: '',
            goal: 'Goal',
            steps: manySteps,
            constraints: [],
            requiredTools: [],
            userInputs: [],
            createdAt: DateTime.now(),
            category: SkillCategory.development,
          ),
          Skill(
            id: '2',
            name: 'Rule',
            description: '',
            goal: 'Goal',
            steps: ['rule step'],
            constraints: [],
            requiredTools: [],
            userInputs: [],
            createdAt: DateTime.now(),
            category: SkillCategory.development,
          ),
        );
        expect(result.steps.length, 8);
      });

      test('returns rule steps for executable kind', () {
        final validator = DraftValidator(locale: 'en');
        final result = validator.validate(
          Skill(
            id: '1',
            name: 'Name',
            description: '',
            goal: 'Goal',
            steps: ['create step'],
            constraints: [],
            requiredTools: [],
            userInputs: [],
            createdAt: DateTime.now(),
            category: SkillCategory.development,
            kind: 'executable',
          ),
          Skill(
            id: '2',
            name: 'Rule',
            description: '',
            goal: 'Goal',
            steps: ['rule step'],
            constraints: [],
            requiredTools: [],
            userInputs: [],
            createdAt: DateTime.now(),
            category: SkillCategory.development,
            kind: 'executable',
          ),
        );
        expect(result.steps, ['rule step']);
      });
    });

    group('_validateConstraints', () {
      test('falls back for empty constraints', () {
        final validator = DraftValidator(locale: 'en');
        final result = validator.validate(
          Skill(
            id: '1',
            name: 'Name',
            description: '',
            goal: 'Goal',
            steps: [],
            constraints: [],
            requiredTools: [],
            userInputs: [],
            createdAt: DateTime.now(),
            category: SkillCategory.development,
          ),
          Skill(
            id: '2',
            name: 'Rule',
            description: '',
            goal: 'Goal',
            steps: [],
            constraints: ['rule constraint'],
            requiredTools: [],
            userInputs: [],
            createdAt: DateTime.now(),
            category: SkillCategory.development,
          ),
        );
        expect(result.constraints, ['rule constraint']);
      });

      test('filters and trims constraints', () {
        final validator = DraftValidator(locale: 'en');
        final result = validator.validate(
          Skill(
            id: '1',
            name: 'Name',
            description: '',
            goal: 'Goal',
            steps: [],
            constraints: ['  valid constraint  ', '', 'too long ${'a' * 200}'],
            requiredTools: [],
            userInputs: [],
            createdAt: DateTime.now(),
            category: SkillCategory.development,
          ),
          Skill(
            id: '2',
            name: 'Rule',
            description: '',
            goal: 'Goal',
            steps: [],
            constraints: ['rule constraint'],
            requiredTools: [],
            userInputs: [],
            createdAt: DateTime.now(),
            category: SkillCategory.development,
          ),
        );
        expect(result.constraints, ['valid constraint']);
      });
    });

    group('_validateRequiredTools', () {
      test('falls back for empty tools', () {
        final validator = DraftValidator(locale: 'en');
        final result = validator.validate(
          Skill(
            id: '1',
            name: 'Name',
            description: '',
            goal: 'Goal',
            steps: [],
            constraints: [],
            requiredTools: [],
            userInputs: [],
            createdAt: DateTime.now(),
            category: SkillCategory.development,
          ),
          Skill(
            id: '2',
            name: 'Rule',
            description: '',
            goal: 'Goal',
            steps: [],
            constraints: [],
            requiredTools: ['bash', 'edit'],
            userInputs: [],
            createdAt: DateTime.now(),
            category: SkillCategory.development,
          ),
        );
        expect(result.requiredTools, ['bash', 'edit']);
      });

      test('filters invalid tools', () {
        final validator = DraftValidator(locale: 'en');
        final result = validator.validate(
          Skill(
            id: '1',
            name: 'Name',
            description: '',
            goal: 'Goal',
            steps: [],
            constraints: [],
            requiredTools: ['bash', 'invalid_tool', 'EDIT'],
            userInputs: [],
            createdAt: DateTime.now(),
            category: SkillCategory.development,
          ),
          Skill(
            id: '2',
            name: 'Rule',
            description: '',
            goal: 'Goal',
            steps: [],
            constraints: [],
            requiredTools: ['bash', 'edit'],
            userInputs: [],
            createdAt: DateTime.now(),
            category: SkillCategory.development,
          ),
        );
        expect(result.requiredTools, ['bash', 'edit']);
      });
    });

    group('_validateUserInputs', () {
      test('falls back for empty inputs', () {
        final validator = DraftValidator(locale: 'en');
        final result = validator.validate(
          Skill(
            id: '1',
            name: 'Name',
            description: '',
            goal: 'Goal',
            steps: [],
            constraints: [],
            requiredTools: [],
            userInputs: [],
            createdAt: DateTime.now(),
            category: SkillCategory.development,
          ),
          Skill(
            id: '2',
            name: 'Rule',
            description: '',
            goal: 'Goal',
            steps: [],
            constraints: [],
            requiredTools: [],
            userInputs: [
              SkillInput(key: 'k1', label: 'Label', hint: 'Hint', type: SkillInputType.text),
            ],
            createdAt: DateTime.now(),
            category: SkillCategory.development,
          ),
        );
        expect(result.userInputs.length, 1);
        expect(result.userInputs.first.key, 'k1');
      });

      test('filters invalid inputs', () {
        final validator = DraftValidator(locale: 'en');
        final result = validator.validate(
          Skill(
            id: '1',
            name: 'Name',
            description: '',
            goal: 'Goal',
            steps: [],
            constraints: [],
            requiredTools: [],
            userInputs: [
              SkillInput(key: 'valid', label: 'Valid', hint: 'Hint', type: SkillInputType.text),
              SkillInput(key: '', label: 'No Key', hint: 'Hint', type: SkillInputType.text),
              SkillInput(key: 'duplicate', label: 'First', hint: 'Hint', type: SkillInputType.text),
              SkillInput(key: 'duplicate', label: 'Second', hint: 'Hint', type: SkillInputType.text),
            ],
            createdAt: DateTime.now(),
            category: SkillCategory.development,
          ),
          Skill(
            id: '2',
            name: 'Rule',
            description: '',
            goal: 'Goal',
            steps: [],
            constraints: [],
            requiredTools: [],
            userInputs: [],
            createdAt: DateTime.now(),
            category: SkillCategory.development,
          ),
        );
        expect(result.userInputs.length, 2);
        expect(result.userInputs.map((i) => i.key).toList(), ['valid', 'duplicate']);
      });
    });

    group('_validateExecutableSteps', () {
      test('falls back for null steps', () {
        final validator = DraftValidator(locale: 'en');
        final ruleSteps = [
          SkillStep(id: '1', description: 'rule step', mode: 'tool', tool: 'bash', order: 0),
        ];
        final result = validator.validate(
          Skill(
            id: '1',
            name: 'Name',
            description: '',
            goal: 'Goal',
            steps: [],
            constraints: [],
            requiredTools: [],
            userInputs: [],
            createdAt: DateTime.now(),
            category: SkillCategory.development,
            executableSteps: null,
          ),
          Skill(
            id: '2',
            name: 'Rule',
            description: '',
            goal: 'Goal',
            steps: [],
            constraints: [],
            requiredTools: [],
            userInputs: [],
            createdAt: DateTime.now(),
            category: SkillCategory.development,
            executableSteps: ruleSteps,
          ),
        );
        expect(result.executableSteps, ruleSteps);
      });

      test('validates and filters executable steps', () {
        final validator = DraftValidator(locale: 'en');
        final result = validator.validate(
          Skill(
            id: '1',
            name: 'Name',
            description: '',
            goal: 'Goal',
            steps: [],
            constraints: [],
            requiredTools: [],
            userInputs: [],
            createdAt: DateTime.now(),
            category: SkillCategory.development,
            executableSteps: [
              SkillStep(
                id: '1',
                description: 'create backup',
                mode: 'tool',
                tool: 'bash',
                args: {},
                order: 0,
              ),
              SkillStep(
                id: '2',
                description: '',
                mode: 'tool',
                tool: 'bash',
                args: {},
                order: 1,
              ),
              SkillStep(
                id: '3',
                description: 'run with invalid tool',
                mode: 'tool',
                tool: 'invalid',
                args: {},
                order: 2,
              ),
            ],
          ),
          Skill(
            id: '2',
            name: 'Rule',
            description: '',
            goal: 'Goal',
            steps: [],
            constraints: [],
            requiredTools: [],
            userInputs: [],
            createdAt: DateTime.now(),
            category: SkillCategory.development,
            executableSteps: [],
          ),
        );
        expect(result.executableSteps!.length, 1);
        expect(result.executableSteps!.first.tool, 'bash');
      });
    });

    group('_validateParameters', () {
      test('falls back for null parameters', () {
        final validator = DraftValidator(locale: 'en');
        final ruleParams = [
          SkillParameter(key: 'p1', label: 'Param', type: 'text', required: true),
        ];
        final result = validator.validate(
          Skill(
            id: '1',
            name: 'Name',
            description: '',
            goal: 'Goal',
            steps: [],
            constraints: [],
            requiredTools: [],
            userInputs: [],
            createdAt: DateTime.now(),
            category: SkillCategory.development,
            parameters: null,
          ),
          Skill(
            id: '2',
            name: 'Rule',
            description: '',
            goal: 'Goal',
            steps: [],
            constraints: [],
            requiredTools: [],
            userInputs: [],
            createdAt: DateTime.now(),
            category: SkillCategory.development,
            parameters: ruleParams,
          ),
        );
        expect(result.parameters, ruleParams);
      });

      test('validates and filters parameters', () {
        final validator = DraftValidator(locale: 'en');
        final result = validator.validate(
          Skill(
            id: '1',
            name: 'Name',
            description: '',
            goal: 'Goal',
            steps: [],
            constraints: [],
            requiredTools: [],
            userInputs: [],
            createdAt: DateTime.now(),
            category: SkillCategory.development,
            parameters: [
              SkillParameter(key: 'valid', label: 'Valid', type: 'text', required: true),
              SkillParameter(key: '', label: 'No Key', type: 'text', required: true),
              SkillParameter(key: 'duplicate', label: 'First', type: 'text', required: true),
              SkillParameter(key: 'duplicate', label: 'Second', type: 'text', required: true),
            ],
          ),
          Skill(
            id: '2',
            name: 'Rule',
            description: '',
            goal: 'Goal',
            steps: [],
            constraints: [],
            requiredTools: [],
            userInputs: [],
            createdAt: DateTime.now(),
            category: SkillCategory.development,
            parameters: [],
          ),
        );
        expect(result.parameters!.length, 2);
        expect(result.parameters!.map((p) => p.key).toList(), ['valid', 'duplicate']);
      });
    });
  });
}