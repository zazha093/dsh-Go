// Tests for Parameter Resolver

import 'package:flutter_test/flutter_test.dart';

import 'package:dsh_app/skills/parameter_resolver.dart';
import 'package:dsh_app/skills/skill_model.dart';

void main() {
  group('ParameterResolver', () {
    group('resolveValue', () {
      test('returns original value when no placeholders', () {
        expect(resolveValue('hello world', {}), 'hello world');
      });

      test('replaces single placeholder', () {
        expect(resolveValue('host: \${host}', {'host': 'example.com'}), 'host: example.com');
      });

      test('replaces multiple placeholders', () {
        expect(
          resolveValue('deploy \${app} to \${env}', {'app': 'myapp', 'env': 'prod'}),
          'deploy myapp to prod',
        );
      });

      test('handles missing placeholder gracefully', () {
        expect(resolveValue('host: \${host}', {}), 'host: \${host}');
      });

      test('handles empty params', () {
        expect(resolveValue('test \${param}', {}), 'test \${param}');
      });
    });

    group('resolveArgs', () {
      test('resolves string values in map', () {
        final args = {'host': '\${host}', 'port': '8080'};
        final resolved = resolveArgs(args, {'host': 'localhost'});
        expect(resolved['host'], 'localhost');
        expect(resolved['port'], '8080');
      });

      test('resolves nested maps', () {
        final args = {
          'config': {'host': '\${host}'}
        };
        final resolved = resolveArgs(args, {'host': 'example.com'});
        expect(resolved['config'], {'host': 'example.com'});
      });

      test('resolves lists with strings', () {
        final args = {'hosts': ['\${host1}', '\${host2}']};
        final resolved = resolveArgs(args, {'host1': 'a.com', 'host2': 'b.com'});
        expect(resolved['hosts'], ['a.com', 'b.com']);
      });

      test('preserves non-string values', () {
        final args = {'count': 5, 'enabled': true};
        final resolved = resolveArgs(args, {});
        expect(resolved['count'], 5);
        expect(resolved['enabled'], true);
      });
    });

    group('resolveStep', () {
      test('resolves step arguments', () {
        final step = SkillStep(
          id: 'step-1',
          description: 'Deploy',
          mode: 'tool',
          tool: 'bash',
          args: {'command': 'deploy \${app}'},
          order: 1,
        );

        final resolved = resolveStep(step, {'app': 'myapp'});
        expect(resolved.args['command'], 'deploy myapp');
        expect(resolved.id, step.id);
        expect(resolved.description, step.description);
      });
    });

    group('resolveSkillSteps', () {
      test('resolves all steps', () {
        final steps = [
          SkillStep(id: '1', description: 'Step 1', mode: 'tool', tool: 'bash', args: {'cmd': '\${cmd1}'}, order: 1),
          SkillStep(id: '2', description: 'Step 2', mode: 'tool', tool: 'bash', args: {'cmd': '\${cmd2}'}, order: 2),
        ];

        final resolved = resolveSkillSteps(steps, {'cmd1': 'echo 1', 'cmd2': 'echo 2'});
        expect(resolved[0].args['cmd'], 'echo 1');
        expect(resolved[1].args['cmd'], 'echo 2');
      });
    });

    group('validateParameters', () {
      test('returns missing required parameters', () {
        const params = [
          SkillParameter(key: 'host', label: 'Host', type: 'text', required: true),
          SkillParameter(key: 'port', label: 'Port', type: 'number', required: false),
        ];

        final missing = validateParameters(params, {'port': '8080'});
        expect(missing, ['host']);
      });

      test('returns empty when all required provided', () {
        const params = [
          SkillParameter(key: 'host', label: 'Host', type: 'text', required: true),
        ];

        final missing = validateParameters(params, {'host': 'localhost'});
        expect(missing, isEmpty);
      });

      test('uses default value for required param', () {
        const params = [
          SkillParameter(key: 'host', label: 'Host', type: 'text', required: true, defaultValue: 'localhost'),
        ];

        final missing = validateParameters(params, {});
        expect(missing, isEmpty);
      });
    });

    group('mergeParameters', () {
      test('merges defaults, step outputs, and user values', () {
        const params = [
          SkillParameter(key: 'host', label: 'Host', type: 'text', required: true, defaultValue: 'localhost'),
          SkillParameter(key: 'port', label: 'Port', type: 'number', required: true),
        ];

        final merged = mergeParameters(
          parameters: params,
          userProvided: {'port': '8080'},
          stepOutputs: {'host': 'prod.example.com'},
        );

        expect(merged['host'], 'prod.example.com'); // stepOutputs overrides default
        expect(merged['port'], '8080'); // userProvided used
      });

      test('user values have highest priority', () {
        const params = [
          SkillParameter(key: 'env', label: 'Environment', type: 'text', required: true, defaultValue: 'dev'),
        ];

        final merged = mergeParameters(
          parameters: params,
          userProvided: {'env': 'prod'},
          stepOutputs: {'env': 'staging'},
        );

        expect(merged['env'], 'prod'); // userProvided wins
      });
    });
  });
}