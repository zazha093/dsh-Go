// Tests for Skill Distillation and Secret Redaction

import 'package:flutter_test/flutter_test.dart';

import 'package:dsh_app/share_code/conversation_redact.dart';
import 'package:dsh_app/skills/skill_model.dart';
import 'package:dsh_app/skills/skill_distill.dart';

void main() {
  group('SkillDistiller', () {
    group('generateSkillName', () {
      test('generates name from session title', () {
        const title = 'My Coding Session';
        final name = SkillDistiller.generateSkillName(title);
        expect(name, 'My coding session');
      });

      test('removes common prefixes', () {
        const title = 'chat: My Session';
        final name = SkillDistiller.generateSkillName(title);
        expect(name, 'My session');
      });

      test('capitalizes first letter', () {
        const title = 'lowercase title';
        final name = SkillDistiller.generateSkillName(title);
        expect(name, 'Lowercase title');
      });

      test('truncates long names', () {
        final title = List.filled(60, 'a').join();
        final name = SkillDistiller.generateSkillName(title);
        expect(name.length, lessThanOrEqualTo(50));
      });

      test('handles empty title', () {
        const title = '';
        final name = SkillDistiller.generateSkillName(title);
        expect(name, 'Unnamed Skill');
      });
    });

    group('inferToolsFromTitle', () {
      test('infers development tools', () {
        const title = 'Code Review Session';
        final tools = SkillDistiller.inferToolsFromTitle(title);
        expect(tools, containsAll(['bash', 'edit', 'write']));
      });

      test('infers web tools', () {
        const title = 'Web Search and Fetch';
        final tools = SkillDistiller.inferToolsFromTitle(title);
        expect(tools, containsAll(['web_fetch', 'web_search']));
      });

      test('infers file tools', () {
        const title = 'File Operations';
        final tools = SkillDistiller.inferToolsFromTitle(title);
        expect(tools, containsAll(['read', 'write', 'edit']));
      });

      test('infers git tools', () {
        const title = 'Git Commit and Push';
        final tools = SkillDistiller.inferToolsFromTitle(title);
        expect(tools, contains('bash'));
      });

      test('infers test tools', () {
        const title = 'CI/CD Build Test Deploy';
        final tools = SkillDistiller.inferToolsFromTitle(title);
        expect(tools, contains('bash'));
      });

      test('infers analysis tools', () {
        const title = 'Data Analysis Report';
        final tools = SkillDistiller.inferToolsFromTitle(title);
        expect(tools, containsAll(['bash', 'web_fetch']));
      });

      test('defaults to bash and edit', () {
        const title = 'Random Session';
        final tools = SkillDistiller.inferToolsFromTitle(title);
        expect(tools, containsAll(['bash', 'edit']));
      });

      test('deduplicates tools', () {
        const title = 'Code Code Code';
        final tools = SkillDistiller.inferToolsFromTitle(title);
        final uniqueTools = tools.toSet();
        expect(tools.length, uniqueTools.length);
      });
    });

    group('inferInputsFromTitle', () {
      test('infers target_host input', () {
        const title = 'Deploy to Production Server';
        final inputs = SkillDistiller.inferInputsFromTitle(title);
        expect(inputs.any((i) => i.key == 'target_host'), true);
      });

      test('infers branch input', () {
        const title = 'Git Branch Management';
        final inputs = SkillDistiller.inferInputsFromTitle(title);
        expect(inputs.any((i) => i.key == 'branch'), true);
      });

      test('infers environment input', () {
        const title = 'Environment Configuration';
        final inputs = SkillDistiller.inferInputsFromTitle(title);
        final envInput = inputs.firstWhere((i) => i.key == 'environment');
        expect(envInput.type, SkillInputType.select);
        expect(envInput.options, ['development', 'staging', 'production']);
      });

      test('infers version input', () {
        const title = 'Release Version 1.0.0';
        final inputs = SkillDistiller.inferInputsFromTitle(title);
        expect(inputs.any((i) => i.key == 'version'), true);
      });
    });

    group('inferCategoryFromTitle', () {
      test('infers development category', () {
        const title = 'Code Review and Debugging';
        final category = SkillDistiller.inferCategoryFromTitle(title);
        expect(category, SkillCategory.development);
      });

      test('infers automation category', () {
        const title = 'Automated CI/CD Pipeline';
        final category = SkillDistiller.inferCategoryFromTitle(title);
        expect(category, SkillCategory.automation);
      });

      test('infers analysis category', () {
        const title = 'Data Analysis Report';
        final category = SkillDistiller.inferCategoryFromTitle(title);
        expect(category, SkillCategory.analysis);
      });

      test('infers productivity category', () {
        const title = 'Daily Todo Planning';
        final category = SkillDistiller.inferCategoryFromTitle(title);
        expect(category, SkillCategory.productivity);
      });

      test('defaults to other', () {
        const title = 'Random Session';
        final category = SkillDistiller.inferCategoryFromTitle(title);
        expect(category, SkillCategory.other);
      });
    });

    group('createTemplateSkill', () {
      test('creates skill with all required fields', () {
        const sessionId = 'test-session';
        const sessionTitle = 'Test Session';

        final skill = SkillDistiller.createTemplateSkill(sessionId, sessionTitle);

        expect(skill.id, isNotEmpty);
        expect(skill.name, isNotEmpty);
        expect(skill.description, 'Distilled from session: Test Session');
        expect(skill.goal, 'Achieve the same outcome as the original session');
        expect(skill.steps, isNotEmpty);
        expect(skill.constraints, isNotEmpty);
        expect(skill.requiredTools, isNotEmpty);
        expect(skill.createdAt, isNotNull);
        expect(skill.sourceSessionId, sessionId);
        expect(skill.sourceSessionTitle, sessionTitle);
        expect(skill.version, 1);
        expect(skill.useCount, 0);
        expect(skill.successCount, 0);
        expect(skill.hidden, false);
      });
    });

    group('Secret redaction in distillation', () {
      test('redacts API keys from skill fields', () {
        const sessionId = 'test-session';
        const sessionTitle = 'API Key: sk-1234567890abcdef';

        final skill = SkillDistiller.createTemplateSkill(sessionId, sessionTitle);

        // The description should have the API key redacted
        expect(skill.description, contains('sk-••••••'));
        expect(skill.description, isNot(contains('sk-1234567890abcdef')));
      });

      test('redacts tokens from skill fields', () {
        const sessionId = 'test-session';
        const sessionTitle = 'Token: ghp_abcdefghijklmnopqrstuvwxyz123456';

        final skill = SkillDistiller.createTemplateSkill(sessionId, sessionTitle);

        expect(skill.description, contains('ghp_••••••'));
        expect(skill.description, isNot(contains('ghp_abcdefghijklmnopqrstuvwxyz123456')));
      });

      test('redacts passwords from skill fields', () {
        const sessionId = 'test-session';
        const sessionTitle = 'Password: mysecretpassword123';

        final skill = SkillDistiller.createTemplateSkill(sessionId, sessionTitle);

        expect(skill.description, contains('••••••'));
        expect(skill.description, isNot(contains('mysecretpassword123')));
      });

      test('redacts JWT tokens from skill fields', () {
        const sessionId = 'test-session';
        const sessionTitle = 'JWT: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyfQ.SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c';

        final skill = SkillDistiller.createTemplateSkill(sessionId, sessionTitle);

        expect(skill.description, contains('••••••'));
        expect(skill.description, isNot(contains('eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9')));
      });
    });
  });

  group('conversation_redact', () {
    test('redacts API keys', () {
      const text = 'API_KEY=sk-1234567890abcdef';
      final redacted = redactText(text);
      expect(redacted, contains('sk-••••••'));
      expect(redacted, isNot(contains('sk-1234567890abcdef')));
    });

    test('redacts GitHub tokens', () {
      const text = 'ghp_abcdefghijklmnopqrstuvwxyz123456';
      final redacted = redactText(text);
      expect(redacted, contains('ghp_••••••'));
      expect(redacted, isNot(contains('ghp_abcdefghijklmnopqrstuvwxyz123456')));
    });

    test('redacts passwords', () {
      const text = 'password=mysecretpassword123';
      final redacted = redactText(text);
      expect(redacted, contains('••••••'));
      expect(redacted, isNot(contains('mysecretpassword123')));
    });

    test('redacts JWT tokens', () {
      const text = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyfQ.SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c';
      final redacted = redactText(text);
      expect(redacted, contains('••••••'));
      expect(redacted, isNot(contains('eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9')));
    });

    test('redacts home paths', () {
      const text = '/home/user/project/file.txt';
      final redacted = redactText(text);
      expect(redacted, '~/project/file.txt');
    });

    test('redacts Windows user paths', () {
      const text = 'C:\\Users\\John\\Documents\\file.txt';
      final redacted = redactText(text);
      expect(redacted, '~\\Documents\\file.txt');
    });

    test('redacts app data paths', () {
      const text = '/data/user/0/com.example.app/databases/db.sqlite';
      final redacted = redactText(text);
      expect(redacted, contains('…'));
    });

    test('converts markdown images to alt text', () {
      const text = '![Alt text](http://example.com/image.png)';
      final redacted = markdownWithoutImages(text);
      expect(redacted, '〔Alt text〕');
    });

    test('preserves code blocks from image conversion', () {
      const text = '```\n![Image](url)\n```';
      final redacted = markdownWithoutImages(text);
      expect(redacted, '```\n![Image](url)\n```');
    });

    test('redacts JSON values', () {
      const json = {
        'api_key': 'sk-1234567890abcdef',
        'nested': {
          'token': 'ghp_abcdefghijklmnopqrstuvwxyz123456',
        },
      };
      final redacted = redactJson(json)!;
      final apiKey = redacted!['api_key'] as String?;
      expect(apiKey, contains('sk-••••••'));
      final nested = redacted!['nested'] as Map?;
      final token = nested?['token'] as String?;
      expect(token, contains('ghp_••••••'));
    });

    test('cuts long text', () {
      final text = List.filled(3000, 'a').join();
      final result = cutText(text, 1000);
      expect(result.text.length, lessThanOrEqualTo(1000));
      expect(result.omitted, greaterThan(0));
    });
  });
}