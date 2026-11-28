// Draft Validator Tests

import 'package:flutter_test/flutter_test.dart';

import 'package:dsh_go/fork/draft_validator.dart';
import 'package:dsh_go/skills/skill_model.dart';

void main() {
  group('DraftValidator', () {
    late DraftValidator validator;
    late Skill ruleBasedSkill;

    setUp(() {
      validator = DraftValidator(locale: 'en');
      ruleBasedSkill = Skill(
        id: 'rule-based',
        name: 'Rule Based Skill',
        kind: 'workflow',
        goal: 'Rule based goal',
        description: 'Rule based description',
        steps: ['Rule step 1', 'Rule step 2'],
        constraints: ['Rule constraint'],
        requiredTools: ['bash', 'edit'],
        userInputs: [
          SkillInput(key: 'param1', label: 'Parameter 1', type: SkillInputType.text),
        ],
        createdAt: DateTime.now(),
        category: SkillCategory.development,
        schemaVersion: 2,
      );
    });

    test('validates name - empty falls back to rule-based', () {
      final aiSkill = ruleBasedSkill.copyWith(name: '');
      final result = validator.validate(aiSkill, ruleBasedSkill);
      expect(result.name, 'Rule Based Skill');
    });

    test('validates name - generic name falls back', () {
      final aiSkill = ruleBasedSkill.copyWith(name: 'Draft');
      final result = validator.validate(aiSkill, ruleBasedSkill);
      expect(result.name, 'Rule Based Skill');
    });

    test('validates name - too long falls back', () {
      final aiSkill = ruleBasedSkill.copyWith(name: 'x' * 61);
      final result = validator.validate(aiSkill, ruleBasedSkill);
      expect(result.name, 'Rule Based Skill');
    });

    test('validates name - valid name preserved', () {
      final aiSkill = ruleBasedSkill.copyWith(name: 'Valid Skill Name');
      final result = validator.validate(aiSkill, ruleBasedSkill);
      expect(result.name, 'Valid Skill Name');
    });

    test('validates kind - invalid falls back', () {
      final aiSkill = ruleBasedSkill.copyWith(kind: 'invalid');
      final result = validator.validate(aiSkill, ruleBasedSkill);
      expect(result.kind, 'workflow');
    });

    test('validates kind - valid kind preserved', () {
      final aiSkill = ruleBasedSkill.copyWith(kind: 'executable');
      final result = validator.validate(aiSkill, ruleBasedSkill);
      expect(result.kind, 'executable');
    });

    test('validates goal - empty falls back', () {
      final aiSkill = ruleBasedSkill.copyWith(goal: '');
      final result = validator.validate(aiSkill, ruleBasedSkill);
      expect(result.goal, 'Rule based goal');
    });

    test('validates goal - too long falls back', () {
      final aiSkill = ruleBasedSkill.copyWith(goal: 'x' * 301);
      final result = validator.validate(aiSkill, ruleBasedSkill);
      expect(result.goal, 'Rule based goal');
    });

    test('validates description - empty falls back', () {
      final aiSkill = ruleBasedSkill.copyWith(description: '');
      final result = validator.validate(aiSkill, ruleBasedSkill);
      expect(result.description, 'Rule based description');
    });

    test('validates steps - empty falls back', () {
      final aiSkill = ruleBasedSkill.copyWith(steps: []);
      final result = validator.validate(aiSkill, ruleBasedSkill);
      expect(result.steps, ['Rule step 1', 'Rule step 2']);
    });

    test('validates steps - filters invalid steps', () {
      final aiSkill = ruleBasedSkill.copyWith(steps: ['', 'Valid step', 'x' * 151]);
      final result = validator.validate(aiSkill, ruleBasedSkill);
      expect(result.steps, ['Valid step']);
    });

    test('validates steps - max 8 steps', () {
      final aiSkill = ruleBasedSkill.copyWith(steps: List.generate(10, (i) => 'Step ${i + 1}'));
      final result = validator.validate(aiSkill, ruleBasedSkill);
      expect(result.steps.length, 8);
    });

    test('validates constraints - empty falls back', () {
      final aiSkill = ruleBasedSkill.copyWith(constraints: []);
      final result = validator.validate(aiSkill, ruleBasedSkill);
      expect(result.constraints, ['Rule constraint']);
    });

    test('validates requiredTools - filters invalid tools', () {
      final aiSkill = ruleBasedSkill.copyWith(requiredTools: ['invalid_tool', 'bash', 'unknown']);
      final result = validator.validate(aiSkill, ruleBasedSkill);
      expect(result.requiredTools, ['bash']);
    });

    test('validates userInputs - filters invalid inputs', () {
      final aiSkill = ruleBasedSkill.copyWith(userInputs: [
        SkillInput(key: '', label: 'No key', type: SkillInputType.text),
        SkillInput(key: 'valid', label: 'Valid', type: SkillInputType.text),
      ]);
      final result = validator.validate(aiSkill, ruleBasedSkill);
      expect(result.userInputs.length, 1);
      expect(result.userInputs.first.key, 'valid');
    });

    test('validates executableSteps - filters invalid', () {
      final executableRuleSkill = ruleBasedSkill.copyWith(
        kind: 'executable',
        executableSteps: [
          SkillStep(id: '1', description: 'Rule step', mode: StepMode.tool, tool: 'bash', args: {}, order: 1),
        ],
      );
      final aiSkill = executableRuleSkill.copyWith(executableSteps: [
        SkillStep(id: '1', description: '', mode: StepMode.tool, tool: 'invalid', args: {}, order: 1),
        SkillStep(id: '2', description: 'Valid step', mode: StepMode.tool, tool: 'bash', args: {}, order: 2),
      ]);
      final result = validator.validate(aiSkill, executableRuleSkill);
      expect(result.executableSteps!.length, 1);
      expect(result.executableSteps!.first.description, 'Valid step');
    });

    test('validates parameters - filters invalid', () {
      final executableRuleSkill = ruleBasedSkill.copyWith(
        kind: 'executable',
        parameters: [
          SkillParameter(name: 'param1', type: 'string', description: 'Rule param', required: true),
        ],
      );
      final aiSkill = executableRuleSkill.copyWith(parameters: [
        SkillParameter(name: '', type: 'string', description: 'No name', required: true),
        SkillParameter(name: 'valid', type: 'string', description: 'Valid param', required: true),
      ]);
      final result = validator.validate(aiSkill, executableRuleSkill);
      expect(result.parameters!.length, 1);
      expect(result.parameters!.first.name, 'valid');
    });

    test('locale th allows CJK in name', () {
      final thValidator = DraftValidator(locale: 'th');
      final aiSkill = ruleBasedSkill.copyWith(name: 'ทักษะภาษาไทย');
      final result = thValidator.validate(aiSkill, ruleBasedSkill);
      expect(result.name, 'ทักษะภาษาไทย');
    });

    test('locale zh allows CJK in name', () {
      final zhValidator = DraftValidator(locale: 'zh');
      final aiSkill = ruleBasedSkill.copyWith(name: '中文技能');
      final result = zhValidator.validate(aiSkill, ruleBasedSkill);
      expect(result.name, '中文技能');
    });

    test('locale en rejects CJK in name', () {
      final aiSkill = ruleBasedSkill.copyWith(name: '中文技能');
      final result = validator.validate(aiSkill, ruleBasedSkill);
      expect(result.name, 'Rule Based Skill');
    });
  });
}