// Tests for Step Runner

import 'package:flutter_test/flutter_test.dart';

import 'package:dsh_app/skills/step_runner.dart';

void main() {
  group('StepRunner', () {
    group('StepResult', () {
      test('success factory creates correct result', () {
        final result = StepResult.success(
          stepId: 'step-1',
          output: 'done',
          duration: const Duration(seconds: 1),
        );

        expect(result.success, true);
        expect(result.stepId, 'step-1');
        expect(result.output, 'done');
        expect(result.duration, const Duration(seconds: 1));
        expect(result.error, null);
      });

      test('failure factory creates correct result', () {
        final result = StepResult.failure(
          stepId: 'step-1',
          error: 'timeout',
          duration: const Duration(seconds: 5),
        );

        expect(result.success, false);
        expect(result.stepId, 'step-1');
        expect(result.error, 'timeout');
        expect(result.duration, const Duration(seconds: 5));
        expect(result.output, null);
      });
    });

    group('StepRunnerConfig', () {
      test('default config has reasonable values', () {
        const config = StepRunnerConfig();
        expect(config.approvalTimeout, const Duration(seconds: 30));
        expect(config.toolTimeout, const Duration(seconds: 60));
        expect(config.maxRetries, 0);
        expect(config.retryDelay, const Duration(seconds: 5));
      });

      test('custom config works', () {
        const config = StepRunnerConfig(
          approvalTimeout: Duration(seconds: 60),
          toolTimeout: Duration(seconds: 120),
          maxRetries: 3,
          retryDelay: Duration(seconds: 10),
        );

        expect(config.approvalTimeout, const Duration(seconds: 60));
        expect(config.toolTimeout, const Duration(seconds: 120));
        expect(config.maxRetries, 3);
        expect(config.retryDelay, const Duration(seconds: 10));
      });
    });

    group('StepExecutionException', () {
      test('creates exception with error message', () {
        const exception = StepExecutionException('test error', stepId: 'step-1');
        expect(exception.error, 'test error');
        expect(exception.stepId, 'step-1');
      });

      test('toString includes error', () {
        const exception = StepExecutionException('test error');
        expect(exception.toString(), contains('test error'));
      });
    });
  });
}