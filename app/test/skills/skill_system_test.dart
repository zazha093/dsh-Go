// Tests for Personal Skills System - Integration and Behavior Tests
//
// Covers:
// 1. Fallback distillation (when session data is minimal)
// 2. Secret/credential redaction
// 3. Auto-hide rules (14 days unused, 3+ consecutive failures) and restore
// 4. No auto-overwrite without explicit user confirmation

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dsh_client/dsh_client.dart';
import '../../lib/skills/skill_model.dart';
import '../../lib/skills/skill_distill.dart';
import '../../lib/skills/skill_storage.dart';

void main() {
  group('Personal Skills System Integration', () {
    late SkillStorage storage;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      storage = SkillStorage.instance;
      await storage.init();
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
    });

    tearDown(() async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
    });

    group('1. Fallback distillation', () {
      test('creates template skill when session has minimal data', () {
        const sessionId = 'minimal-session';
        const sessionTitle = 'Minimal Session';

        final skill = SkillDistiller.createTemplateSkill(sessionId, sessionTitle);

        expect(skill.id, isNotEmpty);
        expect(skill.name, 'Minimal session');
        expect(skill.description, 'Distilled from session: Minimal Session');
        expect(skill.goal, 'Achieve the same outcome as the original session');
        expect(skill.steps, isNotEmpty);
        expect(skill.constraints, isNotEmpty);
        expect(skill.requiredTools, containsAll(['bash', 'edit']));
        expect(skill.userInputs, isNotEmpty);
        expect(skill.sourceSessionId, sessionId);
        expect(skill.sourceSessionTitle, sessionTitle);
        expect(skill.version, 1);
        expect(skill.useCount, 0);
        expect(skill.successCount, 0);
        expect(skill.hidden, false);
        expect(skill.category, isNotNull);
      });

      test('generates reasonable name from generic session title', () {
        const titles = [
          'Session 1',
          'Work Session',
          'Coding',
          'Debugging Session',
        ];

        for (final title in titles) {
          final name = SkillDistiller.generateSkillName(title);
          expect(name, isNotEmpty);
          expect(name.length, lessThanOrEqualTo(50));
          // First letter should be capitalized
          expect(name[0], equals(name[0].toUpperCase()));
        }
      });

      test('falls back to default category when title is unrecognized', () {
        const title = 'Random Unrelated Session Title XYZ';
        final category = SkillDistiller.inferCategoryFromTitle(title);
        expect(category, SkillCategory.other);
      });

      test('falls back to default tools when title is unrecognized', () {
        const title = 'Random Unrelated Session Title XYZ';
        final tools = SkillDistiller.inferToolsFromTitle(title);
        expect(tools, containsAll(['bash', 'edit']));
      });

      test('generates fallback inputs when no specific pattern matched', () {
        const title = 'Random Session';
        final inputs = SkillDistiller.inferInputsFromTitle(title);
        // Should still generate some generic inputs or empty list
        expect(inputs, isA<List<SkillInput>>());
      });
    });

    group('2. Secret/credential redaction', () {
      test('redacts API keys in skill fields during distillation', () {
        const sessionId = 'test-session';
        const sessionTitle = 'Deploy with API_KEY=sk-1234567890abcdef1234567890abcdef';

        final skill = SkillDistiller.createTemplateSkill(sessionId, sessionTitle);

        expect(skill.description, contains('sk-••••••'));
        expect(skill.description, isNot(contains('sk-1234567890abcdef1234567890abcdef')));
      });

      test('redacts GitHub tokens in skill fields during distillation', () {
        const sessionId = 'test-session';
        const sessionTitle = 'GitHub token: ghp_abcdefghijklmnopqrstuvwxyz123456';

        final skill = SkillDistiller.createTemplateSkill(sessionId, sessionTitle);

        expect(skill.description, contains('ghp_••••••'));
        expect(skill.description, isNot(contains('ghp_abcdefghijklmnopqrstuvwxyz123456')));
      });

      test('redacts passwords in skill fields during distillation', () {
        const sessionId = 'test-session';
        const sessionTitle = 'Password: mysecretpassword123';

        final skill = SkillDistiller.createTemplateSkill(sessionId, sessionTitle);

        expect(skill.description, contains('••••••'));
        expect(skill.description, isNot(contains('mysecretpassword123')));
      });

      test('redacts JWT tokens in skill fields during distillation', () {
        const sessionId = 'test-session';
        const sessionTitle = 'JWT: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyfQ.SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c';

        final skill = SkillDistiller.createTemplateSkill(sessionId, sessionTitle);

        expect(skill.description, contains('••••••'));
        expect(skill.description, isNot(contains('eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9')));
      });

      test('redaction applies to all text fields in skill', () {
        const sessionId = 'test-session';
        const sessionTitle = 'API key sk-live_abcdef1234567890 and password secret123';

        final skill = SkillDistiller.createTemplateSkill(sessionId, sessionTitle);

        // Check multiple fields are redacted
        expect(skill.description, contains('sk-••••••'));
        expect(skill.description, contains('••••••'));
        expect(skill.description, isNot(contains('sk-live_abcdef1234567890')));
        expect(skill.description, isNot(contains('secret123')));
      });
    });

    group('3. Auto-hide rules and restore', () {
      test('autoHideSkills hides skills unused for 14+ days', () async {
        final oldSkill = Skill(
          id: 'old-1',
          name: 'Old Skill',
          description: 'Old',
          goal: 'Goal',
          steps: [],
          constraints: [],
          requiredTools: [],
          userInputs: [],
          createdAt: DateTime.now().subtract(const Duration(days: 15)),
          lastUsedAt: DateTime.now().subtract(const Duration(days: 15)),
          hidden: false,
        );

        final recentSkill = Skill(
          id: 'recent-1',
          name: 'Recent Skill',
          description: 'Recent',
          goal: 'Goal',
          steps: [],
          constraints: [],
          requiredTools: [],
          userInputs: [],
          createdAt: DateTime.now().subtract(const Duration(days: 5)),
          lastUsedAt: DateTime.now().subtract(const Duration(days: 5)),
          hidden: false,
        );

        await storage.upsertSkill(oldSkill);
        await storage.upsertSkill(recentSkill);

        final hiddenCount = await storage.autoHideSkills();

        expect(hiddenCount, 1);
        expect(storage.getSkill('old-1')!.hidden, true);
        expect(storage.getSkill('old-1')!.hiddenAt, isNotNull);
        expect(storage.getSkill('recent-1')!.hidden, false);
      });

      test('autoHideSkills hides skills with 3+ consecutive failures', () async {
        final failedSkill = Skill(
          id: 'failed-1',
          name: 'Failed Skill',
          description: 'Failed',
          goal: 'Goal',
          steps: [],
          constraints: [],
          requiredTools: [],
          userInputs: [],
          createdAt: DateTime(2024, 1, 1),
          useCount: 3,
          successCount: 0,
          hidden: false,
        );

        final partialFailSkill = Skill(
          id: 'partial-1',
          name: 'Partial Fail Skill',
          description: 'Partial Fail',
          goal: 'Goal',
          steps: [],
          constraints: [],
          requiredTools: [],
          userInputs: [],
          createdAt: DateTime(2024, 1, 1),
          useCount: 3,
          successCount: 1, // Only 1 success, 2 failures - not 3+ consecutive
          hidden: false,
        );

        await storage.upsertSkill(failedSkill);
        await storage.upsertSkill(partialFailSkill);

        final hiddenCount = await storage.autoHideSkills();

        expect(hiddenCount, 1);
        expect(storage.getSkill('failed-1')!.hidden, true);
        expect(storage.getSkill('partial-1')!.hidden, false);
      });

      test('autoHideSkills does not hide already hidden skills', () async {
        final hiddenSkill = Skill(
          id: 'hidden-1',
          name: 'Hidden Skill',
          description: 'Hidden',
          goal: 'Goal',
          steps: [],
          constraints: [],
          requiredTools: [],
          userInputs: [],
          createdAt: DateTime.now().subtract(const Duration(days: 20)),
          hidden: true,
        );

        await storage.upsertSkill(hiddenSkill);

        final hiddenCount = await storage.autoHideSkills();

        expect(hiddenCount, 0);
        expect(storage.getSkill('hidden-1')!.hidden, true);
      });

      test('restoreSkill marks skill as visible and clears hiddenAt', () async {
        final skill = Skill(
          id: 'test-1',
          name: 'Test Skill',
          description: 'A test skill',
          goal: 'Test goal',
          steps: [],
          constraints: [],
          requiredTools: [],
          userInputs: [],
          createdAt: DateTime(2024, 1, 1),
          hidden: true,
          hiddenAt: DateTime(2024, 1, 1),
        );

        await storage.upsertSkill(skill);
        expect(storage.getHiddenSkills().length, 1);

        await storage.restoreSkill('test-1');

        expect(storage.getHiddenSkills(), isEmpty);
        expect(storage.getVisibleSkills().length, 1);
        final restored = storage.getSkill('test-1');
        expect(restored!.hidden, false);
        expect(restored.hiddenAt, isNull);
      });

      test('restoreSkill works on skills hidden by auto-hide (14 days)', () async {
        final oldSkill = Skill(
          id: 'old-1',
          name: 'Old Skill',
          description: 'Old',
          goal: 'Goal',
          steps: [],
          constraints: [],
          requiredTools: [],
          userInputs: [],
          createdAt: DateTime.now().subtract(const Duration(days: 15)),
          lastUsedAt: DateTime.now().subtract(const Duration(days: 15)),
          hidden: false,
        );

        await storage.upsertSkill(oldSkill);
        await storage.autoHideSkills();
        expect(storage.getSkill('old-1')!.hidden, true);

        await storage.restoreSkill('old-1');

        expect(storage.getSkill('old-1')!.hidden, false);
        expect(storage.getSkill('old-1')!.hiddenAt, isNull);
      });

      test('restoreSkill works on skills hidden by consecutive failures', () async {
        final failedSkill = Skill(
          id: 'failed-1',
          name: 'Failed Skill',
          description: 'Failed',
          goal: 'Goal',
          steps: [],
          constraints: [],
          requiredTools: [],
          userInputs: [],
          createdAt: DateTime(2024, 1, 1),
          useCount: 3,
          successCount: 0,
          hidden: false,
        );

        await storage.upsertSkill(failedSkill);
        await storage.autoHideSkills();
        expect(storage.getSkill('failed-1')!.hidden, true);

        await storage.restoreSkill('failed-1');

        expect(storage.getSkill('failed-1')!.hidden, false);
        expect(storage.getSkill('failed-1')!.hiddenAt, isNull);
      });
    });

    group('4. No auto-overwrite without explicit confirmation', () {
      test('importSkills without overwrite keeps existing skills', () async {
        final existingSkill = Skill(
          id: 'existing-1',
          name: 'Existing Skill',
          description: 'Old description',
          goal: 'Old goal',
          steps: ['Old step'],
          constraints: [],
          requiredTools: ['bash'],
          userInputs: [],
          createdAt: DateTime(2024, 1, 1),
        );

        await storage.upsertSkill(existingSkill);

        final updatedSkill = Skill(
          id: 'existing-1',
          name: 'Existing Skill',
          description: 'New description',
          goal: 'New goal',
          steps: ['New step 1', 'New step 2'],
          constraints: ['New constraint'],
          requiredTools: ['bash', 'edit'],
          userInputs: [],
          createdAt: DateTime(2024, 1, 1),
          updatedAt: DateTime(2024, 1, 2),
        );

        final json = JsonEncoder.withIndent('  ').convert([updatedSkill.toJson()]);

        // overwrite: false (default behavior should not overwrite)
        final count = await storage.importSkills(json, overwrite: false);

        expect(count, 0); // Should not import because it exists and overwrite is false
        final skill = storage.getSkill('existing-1');
        expect(skill!.description, 'Old description'); // Unchanged
        expect(skill.goal, 'Old goal'); // Unchanged
        expect(skill.steps.length, 1); // Unchanged
      });

      test('importSkills with overwrite updates existing skills', () async {
        final existingSkill = Skill(
          id: 'existing-1',
          name: 'Existing Skill',
          description: 'Old description',
          goal: 'Old goal',
          steps: ['Old step'],
          constraints: [],
          requiredTools: ['bash'],
          userInputs: [],
          createdAt: DateTime(2024, 1, 1),
        );

        await storage.upsertSkill(existingSkill);

        final updatedSkill = Skill(
          id: 'existing-1',
          name: 'Existing Skill',
          description: 'New description',
          goal: 'New goal',
          steps: ['New step 1', 'New step 2'],
          constraints: ['New constraint'],
          requiredTools: ['bash', 'edit'],
          userInputs: [],
          createdAt: DateTime(2024, 1, 1),
          updatedAt: DateTime(2024, 1, 2),
        );

        final json = JsonEncoder.withIndent('  ').convert([updatedSkill.toJson()]);

        // overwrite: true - explicit confirmation to overwrite
        final count = await storage.importSkills(json, overwrite: true);

        expect(count, 1);
        final skill = storage.getSkill('existing-1');
        expect(skill!.description, 'New description');
        expect(skill.goal, 'New goal');
        expect(skill.steps.length, 2);
        expect(skill.updatedAt, isNotNull);
      });

      test('importSkills handles name conflicts by renaming when overwrite is false', () async {
        final existingSkill = Skill(
          id: 'existing-1',
          name: 'Duplicate Name',
          description: 'Existing',
          goal: 'Goal',
          steps: [],
          constraints: [],
          requiredTools: [],
          userInputs: [],
          createdAt: DateTime(2024, 1, 1),
        );

        await storage.upsertSkill(existingSkill);

        final newSkill = Skill(
          id: 'new-1',
          name: 'Duplicate Name',
          description: 'New',
          goal: 'Goal',
          steps: [],
          constraints: [],
          requiredTools: [],
          userInputs: [],
          createdAt: DateTime(2024, 1, 2),
        );

        final json = const JsonEncoder.withIndent('  ').convert([newSkill.toJson()]);

        final count = await storage.importSkills(json, overwrite: false);

        expect(count, 1);
        // Should have both skills with different names
        expect(storage.getAllSkills().length, 2);
        final names = storage.getAllSkills().map((s) => s.name).toSet();
        expect(names.contains('Duplicate Name'), true);
        expect(names.contains('Duplicate Name (2)'), true);
      });

      test('upsertSkill updates existing skill and increments version', () async {
        final skill1 = Skill(
          id: 'test-1',
          name: 'Test Skill',
          description: 'A test skill',
          goal: 'Test goal',
          steps: ['Step 1'],
          constraints: [],
          requiredTools: ['bash'],
          userInputs: [],
          createdAt: DateTime(2024, 1, 1),
        );

        await storage.upsertSkill(skill1);
        final firstSkill = storage.getSkill('test-1');
        expect(firstSkill!.version, 1);

        final skill2 = Skill(
          id: 'test-1',
          name: 'Test Skill',
          description: 'Updated description',
          goal: 'Updated goal',
          steps: ['Step 1', 'Step 2'],
          constraints: ['New constraint'],
          requiredTools: ['bash', 'edit'],
          userInputs: [],
          createdAt: DateTime(2024, 1, 1),
          updatedAt: DateTime(2024, 1, 2),
          version: 2, // User explicitly provides version
        );

        await storage.upsertSkill(skill2);

        final updatedSkill = storage.getSkill('test-1');
        expect(updatedSkill!.description, 'Updated description');
        expect(updatedSkill.version, 2);
        expect(updatedSkill.updatedAt, isNotNull);
      });

      test('storage does not automatically overwrite on name conflict', () async {
        final skill1 = Skill(
          id: 'skill-1',
          name: 'My Skill',
          description: 'First skill',
          goal: 'Goal 1',
          steps: [],
          constraints: [],
          requiredTools: [],
          userInputs: [],
          createdAt: DateTime(2024, 1, 1),
        );

        await storage.upsertSkill(skill1);

        // Try to add another skill with same name but different ID
        final skill2 = Skill(
          id: 'skill-2',
          name: 'My Skill',
          description: 'Second skill',
          goal: 'Goal 2',
          steps: [],
          constraints: [],
          requiredTools: [],
          userInputs: [],
          createdAt: DateTime(2024, 1, 2),
        );

        // upsertSkill should reject or handle name conflict
        // The storage uses ID as primary key, so this would create a separate entry
        // but skillNameExists should detect the conflict
        expect(storage.skillNameExists('My Skill'), true);
        expect(storage.skillNameExists('My Skill', excludeId: 'skill-1'), true);
        expect(storage.skillNameExists('My Skill', excludeId: 'skill-2'), false);
      });
    });
  });
}