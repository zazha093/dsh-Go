// Tests for Skill Execution Controller

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsh_app/skills/skill_execution_controller.dart';
import 'package:dsh_app/skills/skill_model.dart';

void main() {
  group('SkillExecutionController', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    group('SkillExecutionState', () {
      test('initial state is idle', () {
        const state = SkillExecutionState();
        expect(state.status, SkillExecutionStatus.idle);
        expect(state.currentSkillId, null);
        expect(state.currentStep, 0);
        expect(state.totalSteps, 0);
        expect(state.progress, 0.0);
        expect(state.error, null);
        expect(state.result, null);
        expect(state.isCancelling, false);
        expect(state.awaitingApproval, false);
        expect(state.currentApproval, null);
        expect(state.awaitingInput, false);
        expect(state.requiredInputs, isEmpty);
      });

      test('copyWith updates fields correctly', () {
        const state = SkillExecutionState();
        final updated = state.copyWith(
          status: SkillExecutionStatus.running,
          currentSkillId: 'test-skill',
          currentStep: 1,
          totalSteps: 3,
          progress: 0.33,
        );

        expect(updated.status, SkillExecutionStatus.running);
        expect(updated.currentSkillId, 'test-skill');
        expect(updated.currentStep, 1);
        expect(updated.totalSteps, 3);
        expect(updated.progress, 0.33);
        // Unchanged fields remain
        expect(updated.currentStepId, null);
        expect(updated.error, null);
      });
    });

    group('SkillExecutionStatus', () {
      test('has all expected values', () {
        expect(SkillExecutionStatus.values, containsAll([
          SkillExecutionStatus.idle,
          SkillExecutionStatus.pending,
          SkillExecutionStatus.running,
          SkillExecutionStatus.waitingApproval,
          SkillExecutionStatus.waitingInput,
          SkillExecutionStatus.completed,
          SkillExecutionStatus.failed,
          SkillExecutionStatus.cancelled,
        ]));
      });
    });

    group('SkillExecutionResult', () {
      test('success factory creates correct result', () {
        const result = SkillExecutionResult.success(
          skillId: 'test-skill',
          output: 'done',
          duration: Duration(seconds: 10),
          stepsCompleted: 3,
          totalSteps: 3,
        );

        expect(result.success, true);
        expect(result.skillId, 'test-skill');
        expect(result.output, 'done');
        expect(result.stepsCompleted, 3);
        expect(result.totalSteps, 3);
        expect(result.error, null);
      });

      test('failure factory creates correct result', () {
        const result = SkillExecutionResult.failure(
          skillId: 'test-skill',
          error: 'timeout',
          duration: Duration(seconds: 5),
          stepsCompleted: 1,
          totalSteps: 3,
        );

        expect(result.success, false);
        expect(result.skillId, 'test-skill');
        expect(result.error, 'timeout');
        expect(result.stepsCompleted, 1);
        expect(result.totalSteps, 3);
      });

      test('cancelled factory creates correct result', () {
        const result = SkillExecutionResult.cancelled(
          skillId: 'test-skill',
          duration: Duration(seconds: 2),
          stepsCompleted: 1,
          totalSteps: 3,
        );

        expect(result.success, false);
        expect(result.skillId, 'test-skill');
        expect(result.error, 'Cancelled by user');
        expect(result.stepsCompleted, 1);
      });
    });

    group('SkillExecutionProgress', () {
      test('calculates progress correctly', () {
        const progress = SkillExecutionProgress(
          currentStep: 2,
          totalSteps: 4,
          currentStepId: 'step-2',
          currentStepDescription: 'Running tests',
        );

        expect(progress.progress, 0.5);
        expect(progress.currentStep, 2);
        expect(progress.totalSteps, 4);
      });

      test('progress is 0 when totalSteps is 0', () {
        const progress = SkillExecutionProgress(
          currentStep: 0,
          totalSteps: 0,
          currentStepId: '',
        );

        expect(progress.progress, 0.0);
      });
    });
  });

  group('SkillExecutionController integration', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('controller starts in idle state', () {
      final state = container.read(skillExecutionControllerProvider);
      expect(state.status, SkillExecutionStatus.idle);
    });

    test('clear resets to idle state', () {
      // First set some state
      container.read(skillExecutionControllerProvider.notifier).state =
          const SkillExecutionState(
            status: SkillExecutionStatus.running,
            currentSkillId: 'test',
            error: 'some error',
          );

      // Then clear
      container.read(skillExecutionControllerProvider.notifier).clear();

      final state = container.read(skillExecutionControllerProvider);
      expect(state.status, SkillExecutionStatus.idle);
      expect(state.currentSkillId, null);
      expect(state.error, null);
    });
  });
}