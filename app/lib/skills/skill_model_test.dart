// Tests for Personal Skills model

import 'package:flutter_test/flutter_test.dart';

import 'skill_model.dart';

void main() {
  group('Skill', () {
    late Skill testSkill;

    setUp(() {
      testSkill = Skill(
        id: 'test-id-1',
        name: 'Test Skill',
        description: 'A test skill',
        goal: 'Test goal',
        steps: ['Step 1', 'Step 2'],
        constraints: ['Constraint 1'],
        requiredTools: ['bash', 'edit'],
        userInputs: [
          SkillInput(
            key: 'input1',
            label: 'Input 1',
            hint: 'Hint 1',
            type: SkillInputType.text,
            required: true,
          ),
        ],
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 2),
        lastUsedAt: DateTime(2024, 1, 3),
        useCount: 5,
        successCount: 4,
        category: SkillCategory.development,
        hidden: false,
        sourceSessionId: 'session-1',
        sourceSessionTitle: 'Test Session',
        version: 2,
      );
    });

    test('successRate calculates correctly', () {
      expect(testSkill.successRate, 80); // 4/5 * 100 = 80
    });

    test('successRate is 0 when useCount is 0', () {
      final skill = testSkill.copyWith(useCount: 0, successCount: 0);
      expect(skill.successRate, 0);
    });

    test('shouldAutoHide returns true after 14 days of no use', () {
      final oldSkill = testSkill.copyWith(
        lastUsedAt: DateTime.now().subtract(const Duration(days: 15)),
      );
      expect(oldSkill.shouldAutoHide, true);
    });

    test('shouldAutoHide returns false when used recently', () {
      final recentSkill = testSkill.copyWith(
        lastUsedAt: DateTime.now().subtract(const Duration(days: 5)),
      );
      expect(recentSkill.shouldAutoHide, false);
    });

    test('shouldAutoHide returns true after 3+ consecutive failures', () {
      final failedSkill = testSkill.copyWith(
        useCount: 3,
        successCount: 0,
      );
      expect(failedSkill.shouldAutoHide, true);
    });

    test('shouldAutoHide returns false when not enough failures', () {
      final skill = testSkill.copyWith(
        useCount: 2,
        successCount: 0,
      );
      expect(skill.shouldAutoHide, false);
    });

    test('shouldAutoHide returns false when already hidden', () {
      final hiddenSkill = testSkill.copyWith(hidden: true);
      expect(hiddenSkill.shouldAutoHide, false);
    });

    test('copyWith updates fields correctly', () {
      final updated = testSkill.copyWith(
        name: 'Updated Name',
        version: 3,
      );
      expect(updated.name, 'Updated Name');
      expect(updated.version, 3);
      expect(updated.id, testSkill.id); // unchanged
    });

    test('toJson and fromJson roundtrip', () {
      final json = testSkill.toJson();
      final restored = Skill.fromJson(json);
      expect(restored.id, testSkill.id);
      expect(restored.name, testSkill.name);
      expect(restored.description, testSkill.description);
      expect(restored.goal, testSkill.goal);
      expect(restored.steps, testSkill.steps);
      expect(restored.constraints, testSkill.constraints);
      expect(restored.requiredTools, testSkill.requiredTools);
      expect(restored.userInputs.length, testSkill.userInputs.length);
      expect(restored.createdAt, testSkill.createdAt);
      expect(restored.updatedAt, testSkill.updatedAt);
      expect(restored.lastUsedAt, testSkill.lastUsedAt);
      expect(restored.useCount, testSkill.useCount);
      expect(restored.successCount, testSkill.successCount);
      expect(restored.category, testSkill.category);
      expect(restored.hidden, testSkill.hidden);
      expect(restored.sourceSessionId, testSkill.sourceSessionId);
      expect(restored.sourceSessionTitle, testSkill.sourceSessionTitle);
      expect(restored.version, testSkill.version);
    });

    test('equality works correctly', () {
      final skill1 = testSkill;
      final skill2 = testSkill.copyWith();
      final skill3 = testSkill.copyWith(id: 'different-id');

      expect(skill1 == skill2, true);
      expect(skill1 == skill3, false);
    });
  });

  group('SkillInput', () {
    test('toJson and fromJson roundtrip', () {
      const input = SkillInput(
        key: 'test_key',
        label: 'Test Label',
        hint: 'Test Hint',
        type: SkillInputType.select,
        required: true,
        defaultValue: 'default',
        options: ['option1', 'option2'],
      );

      final json = input.toJson();
      final restored = SkillInput.fromJson(json);

      expect(restored.key, input.key);
      expect(restored.label, input.label);
      expect(restored.hint, input.hint);
      expect(restored.type, input.type);
      expect(restored.required, input.required);
      expect(restored.defaultValue, input.defaultValue);
      expect(restored.options, input.options);
    });
  });

  group('SkillResult', () {
    test('success factory creates correct result', () {
      const result = SkillResult.success(
        output: 'Success output',
        duration: Duration(seconds: 5),
        stepsCompleted: 3,
        totalSteps: 5,
      );

      expect(result.success, true);
      expect(result.output, 'Success output');
      expect(result.error, null);
      expect(result.duration, const Duration(seconds: 5));
      expect(result.stepsCompleted, 3);
      expect(result.totalSteps, 5);
    });

    test('failure factory creates correct result', () {
      const result = SkillResult.failure(
        error: 'Something went wrong',
        duration: Duration(seconds: 2),
        stepsCompleted: 1,
        totalSteps: 5,
      );

      expect(result.success, false);
      expect(result.output, null);
      expect(result.error, 'Something went wrong');
      expect(result.duration, const Duration(seconds: 2));
      expect(result.stepsCompleted, 1);
      expect(result.totalSteps, 5);
    });
  });
}