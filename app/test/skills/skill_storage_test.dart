// Tests for Personal Skills Storage

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dsh_app/skills/skill_model.dart';
import 'package:dsh_app/skills/skill_storage.dart';

void main() {
  group('SkillStorage', () {
    late SkillStorage storage;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      storage = SkillStorage.instance;
      await storage.init();
      // Clear any existing data
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
    });

    tearDown(() async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
    });

    group('Basic CRUD', () {
      test('getAllSkills returns empty list initially', () {
        expect(storage.getAllSkills(), isEmpty);
      });

      test('upsertSkill adds a new skill', () async {
        final skill = Skill(
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

        await storage.upsertSkill(skill);

        final skills = storage.getAllSkills();
        expect(skills.length, 1);
        expect(skills.first.id, 'test-1');
        expect(skills.first.name, 'Test Skill');
      });

      test('upsertSkill updates existing skill', () async {
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

        final skill2 = Skill(
          id: 'test-1',
          name: 'Updated Skill',
          description: 'Updated description',
          goal: 'Updated goal',
          steps: ['Step 1', 'Step 2'],
          constraints: ['New constraint'],
          requiredTools: ['bash', 'edit'],
          userInputs: [],
          createdAt: DateTime(2024, 1, 1),
          updatedAt: DateTime(2024, 1, 2),
        );

        await storage.upsertSkill(skill2);

        final skills = storage.getAllSkills();
        expect(skills.length, 1);
        expect(skills.first.name, 'Updated Skill');
        expect(skills.first.description, 'Updated description');
        expect(skills.first.steps.length, 2);
        expect(skills.first.updatedAt, isNotNull);
      });

      test('deleteSkill removes a skill', () async {
        final skill = Skill(
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

        await storage.upsertSkill(skill);
        expect(storage.getAllSkills().length, 1);

        await storage.deleteSkill('test-1');
        expect(storage.getAllSkills(), isEmpty);
      });

      test('getSkill returns skill by id', () async {
        final skill = Skill(
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

        await storage.upsertSkill(skill);

        final found = storage.getSkill('test-1');
        expect(found, isNotNull);
        expect(found!.id, 'test-1');

        final notFound = storage.getSkill('non-existent');
        expect(notFound, isNull);
      });
    });

    group('Hidden skills', () {
      test('getVisibleSkills returns only non-hidden skills', () async {
        final visibleSkill = Skill(
          id: 'visible-1',
          name: 'Visible Skill',
          description: 'Visible',
          goal: 'Goal',
          steps: [],
          constraints: [],
          requiredTools: [],
          userInputs: [],
          createdAt: DateTime(2024, 1, 1),
          hidden: false,
        );

        final hiddenSkill = Skill(
          id: 'hidden-1',
          name: 'Hidden Skill',
          description: 'Hidden',
          goal: 'Goal',
          steps: [],
          constraints: [],
          requiredTools: [],
          userInputs: [],
          createdAt: DateTime(2024, 1, 1),
          hidden: true,
        );

        await storage.upsertSkill(visibleSkill);
        await storage.upsertSkill(hiddenSkill);

        final visible = storage.getVisibleSkills();
        final hidden = storage.getHiddenSkills();

        expect(visible.length, 1);
        expect(visible.first.id, 'visible-1');
        expect(hidden.length, 1);
        expect(hidden.first.id, 'hidden-1');
      });

      test('hideSkill marks skill as hidden', () async {
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
          hidden: false,
        );

        await storage.upsertSkill(skill);
        expect(storage.getVisibleSkills().length, 1);

        await storage.hideSkill('test-1');

        expect(storage.getVisibleSkills(), isEmpty);
        expect(storage.getHiddenSkills().length, 1);
        final hidden = storage.getSkill('test-1');
        expect(hidden!.hidden, true);
        expect(hidden.hiddenAt, isNotNull);
      });

      test('restoreSkill marks skill as visible', () async {
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
    });

    group('Skill name uniqueness', () {
      test('skillNameExists returns true for existing name', () async {
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
        );

        await storage.upsertSkill(skill);

        expect(storage.skillNameExists('Test Skill'), true);
        expect(storage.skillNameExists('test skill'), true); // case insensitive
        expect(storage.skillNameExists('Different Skill'), false);
      });

      test('skillNameExists excludes specified id', () async {
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
        );

        await storage.upsertSkill(skill);

        expect(storage.skillNameExists('Test Skill', excludeId: 'test-1'), false);
        expect(storage.skillNameExists('Test Skill', excludeId: 'other-id'), true);
      });
    });

    group('Auto-hide', () {
      test('autoHideSkills hides skills older than 14 days', () async {
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

        final successSkill = Skill(
          id: 'success-1',
          name: 'Success Skill',
          description: 'Success',
          goal: 'Goal',
          steps: [],
          constraints: [],
          requiredTools: [],
          userInputs: [],
          createdAt: DateTime(2024, 1, 1),
          useCount: 3,
          successCount: 1,
          hidden: false,
        );

        await storage.upsertSkill(failedSkill);
        await storage.upsertSkill(successSkill);

        final hiddenCount = await storage.autoHideSkills();

        expect(hiddenCount, 1);
        expect(storage.getSkill('failed-1')!.hidden, true);
        expect(storage.getSkill('success-1')!.hidden, false);
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
    });

    group('Invocation recording', () {
      test('recordInvocation stores success', () async {
        final skill = Skill(
          id: 'test-1',
          name: 'Test Skill',
          description: 'Test',
          goal: 'Goal',
          steps: [],
          constraints: [],
          requiredTools: [],
          userInputs: [],
          createdAt: DateTime(2024, 1, 1),
        );

        await storage.upsertSkill(skill);

        final result = SkillResult.success(
          output: 'Success output',
          duration: const Duration(seconds: 5),
          stepsCompleted: 3,
          totalSteps: 5,
        );

        await storage.recordInvocation('test-1', result);

        final history = storage.getHistory('test-1');
        expect(history.length, 1);
        expect(history.first['success'], true);
        expect(history.first['error'], isNull);
      });

      test('recordInvocation stores failure', () async {
        final skill = Skill(
          id: 'test-1',
          name: 'Test Skill',
          description: 'Test',
          goal: 'Goal',
          steps: [],
          constraints: [],
          requiredTools: [],
          userInputs: [],
          createdAt: DateTime(2024, 1, 1),
        );

        await storage.upsertSkill(skill);

        final result = SkillResult.failure(
          error: 'Something went wrong',
          duration: const Duration(seconds: 2),
        );

        await storage.recordInvocation('test-1', result);

        final history = storage.getHistory('test-1');
        expect(history.length, 1);
        expect(history.first['success'], false);
        expect(history.first['error'], 'Something went wrong');
      });
    });

    group('Import/Export', () {
      test('exportSkills returns valid JSON', () async {
        final skill = Skill(
          id: 'test-1',
          name: 'Test Skill',
          description: 'Test',
          goal: 'Goal',
          steps: ['Step 1'],
          constraints: ['Constraint 1'],
          requiredTools: ['bash'],
          userInputs: [],
          createdAt: DateTime(2024, 1, 1),
        );

        await storage.upsertSkill(skill);

        final json = storage.exportSkills();
        expect(json, contains('test-1'));
        expect(json, contains('Test Skill'));
      });

      test('importSkills imports new skills', () async {
        final skill1 = Skill(
          id: 'import-1',
          name: 'Imported Skill 1',
          description: 'Imported 1',
          goal: 'Goal 1',
          steps: ['Step 1'],
          constraints: [],
          requiredTools: ['bash'],
          userInputs: [],
          createdAt: DateTime(2024, 1, 1),
        );

        final skill2 = Skill(
          id: 'import-2',
          name: 'Imported Skill 2',
          description: 'Imported 2',
          goal: 'Goal 2',
          steps: ['Step 1', 'Step 2'],
          constraints: [],
          requiredTools: ['edit'],
          userInputs: [],
          createdAt: DateTime(2024, 1, 2),
        );

        final json = const JsonEncoder.withIndent('  ').convert([
          skill1.toJson(),
          skill2.toJson(),
        ]);

        final count = await storage.importSkills(json);

        expect(count, 2);
        expect(storage.getSkill('import-1'), isNotNull);
        expect(storage.getSkill('import-2'), isNotNull);
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

        final json = const JsonEncoder.withIndent('  ').convert([updatedSkill.toJson()]);

        final count = await storage.importSkills(json, overwrite: true);

        expect(count, 1);
        final skill = storage.getSkill('existing-1');
        expect(skill!.description, 'New description');
        expect(skill.goal, 'New goal');
        expect(skill.steps.length, 2);
        expect(skill.updatedAt, isNotNull);
      });

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

        final json = const JsonEncoder.withIndent('  ').convert([updatedSkill.toJson()]);

        final count = await storage.importSkills(json, overwrite: false);

        expect(count, 0); // Should not import because it exists and overwrite is false
        final skill = storage.getSkill('existing-1');
        expect(skill!.description, 'Old description'); // Unchanged
      });

      test('importSkills handles name conflicts by renaming', () async {
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
    });

    group('History cleanup', () {
      test('deleteSkill cleans up history', () async {
        final skill = Skill(
          id: 'test-1',
          name: 'Test Skill',
          description: 'Test',
          goal: 'Goal',
          steps: [],
          constraints: [],
          requiredTools: [],
          userInputs: [],
          createdAt: DateTime(2024, 1, 1),
        );

        await storage.upsertSkill(skill);

        await storage.recordInvocation('test-1', SkillResult.success());
        expect(storage.getHistory('test-1').length, 1);

        await storage.deleteSkill('test-1');

        expect(storage.getHistory('test-1'), isEmpty);
      });
    });
  });
}