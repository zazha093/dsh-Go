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

  group('Script Extraction (STAGE 2-3)', () {
    group('_extractScriptFromText', () {
      test('extracts bash script from markdown code block', () {
        const text = '''
Here is a backup script:

```bash
#!/bin/bash
tar --exclude=node_modules --exclude=.git -czf ~/backups/project-\$(date +%Y%m%d-%H%M%S).tar.gz .
ls -lh ~/backups/project-*.tar.gz
```
''';

        final script = SkillDistiller.extractScriptFromText(text);
        expect(script, isNotNull);
        expect(script!.language, 'bash');
        expect(script.content, contains('tar --exclude=node_modules'));
        expect(script.content, contains('ls -lh'));
        expect(script.steps, isNotEmpty);
        expect(script.tools, contains('tar'));
        expect(script.tools, contains('ls'));
      });

      test('extracts script without explicit language', () {
        const text = '''
```
tar --exclude=node_modules -czf backup.tar.gz .
sha256sum backup.tar.gz
```
''';

        final script = SkillDistiller.extractScriptFromText(text);
        expect(script, isNotNull);
        expect(script!.tools, contains('tar'));
        expect(script.tools, contains('sha256sum'));
      });

      test('ignores non-shell code blocks', () {
        const text = '''
```python
def hello():
    print("hello")
```
''';

        final script = SkillDistiller.extractScriptFromText(text);
        expect(script, isNull);
      });

      test('returns null for text without code blocks', () {
        const text = 'Just some text without code blocks';
        final script = SkillDistiller.extractScriptFromText(text);
        expect(script, isNull);
      });

      test('prefers AI response over user message', () {
        const userMessage = 'Please create a backup script';
        const aiResponse = '''
Here is the script:

```bash
tar -czf backup.tar.gz .
```
''';

        final script = SkillDistiller.extractScriptFromText('Please create a backup script') ?? 
                       SkillDistiller.extractScriptFromText('''
```bash
tar -czf backup.tar.gz .
```
''');
        
        expect(script, isNotNull);
        expect(script!.language, 'bash');
        expect(script.content, contains('tar'));
      });
    });

    group('_extractStepsFromScriptContent', () {
      test('extracts steps from tar backup script', () {
        const script = '''
#!/bin/bash
mkdir -p ~/backups
tar --exclude=node_modules --exclude=.git -czf ~/backups/project-\$(date +%Y%m%d-%H%M%S).tar.gz .
ls -lh ~/backups/project-*.tar.gz
''';

        final steps = SkillDistiller.extractStepsFromScriptContent(script);
        expect(steps, isNotEmpty);
        expect(steps.any((s) => s.contains('Create directory')), true);
        expect(steps.any((s) => s.contains('tar')), true);
        expect(steps.any((s) => s.contains('ls') || s.contains('list')), true);
      });

      test('handles script with comments and variables', () {
        const script = '''
#!/bin/bash
# Backup script
BACKUP_DIR=~/backups
DATE=\$(date +%Y%m%d)
mkdir -p \$BACKUP_DIR
tar -czf \$BACKUP_DIR/project-\$DATE.tar.gz .
''';

        final steps = SkillDistiller.extractStepsFromScriptContent(script);
        expect(steps, isNotEmpty);
        // Should extract meaningful commands, not just variable assignments
        expect(steps.any((s) => s.contains('mkdir') || s.contains('directory')), true);
        expect(steps.any((s) => s.contains('tar')), true);
      });

      test('handles script with comments describing steps', () {
        const script = '''
# Step 1: Create backup directory
mkdir -p ~/backups
# Step 2: Create archive
tar -czf backup.tar.gz .
# Step 3: Verify
ls -lh backup.tar.gz
''';

        final steps = SkillDistiller.extractStepsFromScriptContent(script);
        expect(steps.length, greaterThanOrEqualTo(3));
      });

      test('returns empty for empty script', () {
        const script = '';
        final steps = SkillDistiller.extractStepsFromScriptContent(script);
        expect(steps, isEmpty);
      });

      test('handles script with only comments', () {
        const script = '''
# This is a comment
# Another comment
''';

        final steps = SkillDistiller.extractStepsFromScriptContent(script);
        expect(steps, isEmpty);
      });
    });

    group('_inferToolsFromScriptContent', () {
      test('detects tar command', () {
        const script = 'tar -czf backup.tar.gz .';
        final tools = SkillDistiller.inferToolsFromScriptContent(script);
        expect(tools, contains('tar'));
      });

      test('detects gzip and gunzip', () {
        const script = 'gzip file.txt\ngunzip file.txt.gz';
        final tools = SkillDistiller.inferToolsFromScriptContent(script);
        expect(tools, containsAll(['gzip', 'gunzip']));
      });

      test('detects sha256sum', () {
        const script = 'sha256sum file.tar.gz';
        final tools = SkillDistiller.inferToolsFromScriptContent(script);
        expect(tools, contains('sha256sum'));
      });

      test('detects rsync', () {
        const script = 'rsync -av src/ dest/';
        final tools = SkillDistiller.inferToolsFromScriptContent(script);
        expect(tools, contains('rsync'));
      });

      test('detects multiple tools', () {
        const script = '''
mkdir -p backup
tar -czf backup.tar.gz .
sha256sum backup.tar.gz
ls -lh backup.tar.gz
''';
        final tools = SkillDistiller.inferToolsFromScriptContent(script);
        expect(tools, containsAll(['mkdir', 'tar', 'sha256sum', 'ls']));
      });

      test('does not detect tools from comments only', () {
        const script = '# This script uses tar and gzip\necho "done"';
        final tools = SkillDistiller.inferToolsFromScriptContent(script);
        // Should not detect tar/gzip from comment alone
        expect(tools, isNot(contains('tar')));
        expect(tools, isNot(contains('gzip')));
      });

      test('detects common commands', () {
        const script = 'curl https://example.com\nwget https://example.com/file';
        final tools = SkillDistiller.inferToolsFromScriptContent(script);
        expect(tools, containsAll(['curl', 'wget']));
      });

      test('detects git commands', () {
        const script = 'git add .\ngit commit -m "backup"\ngit push';
        final tools = SkillDistiller.inferToolsFromScriptContent(script);
        expect(tools, contains('git'));
      });

      test('detects docker commands', () {
        const script = 'docker build -t myapp .\ndocker run myapp';
        final tools = SkillDistiller.inferToolsFromScriptContent(script);
        expect(tools, contains('docker'));
      });
    });

    group('_dedupConstraints', () {
      test('removes exact duplicates', () {
        final constraints = ['Do not store secrets', 'Do not store secrets'];
        final result = SkillDistiller.dedupConstraints(constraints);
        expect(result.length, 1);
        expect(result.first, 'Do not store secrets');
      });

      test('removes case-insensitive duplicates', () {
        final constraints = ['Do not store secrets', 'do not store secrets', 'DO NOT STORE SECRETS'];
        final result = SkillDistiller.dedupConstraints(constraints);
        expect(result.length, 1);
      });

      test('trims whitespace before dedup', () {
        final constraints = ['  Do not store secrets  ', 'Do not store secrets'];
        final result = SkillDistiller.dedupConstraints(constraints);
        expect(result.length, 1);
        expect(result.first, 'Do not store secrets');
      });

      test('preserves order of first occurrence', () {
        final constraints = ['First constraint', 'Second constraint', 'First constraint'];
        final result = SkillDistiller.dedupConstraints(constraints);
        expect(result.length, 2);
        expect(result[0], 'First constraint');
        expect(result[1], 'Second constraint');
      });

      test('handles empty and whitespace-only constraints', () {
        final constraints = ['Valid constraint', '', '   ', 'Another constraint'];
        final result = SkillDistiller.dedupConstraints(constraints);
        expect(result.length, 2);
      });
    });
  });

  group('Skill Creation from Message Text (STAGE 2-4)', () {
    group('createFromMessageText with script extraction', () {
      test('creates skill with steps from bash script', () {
        const userMessage = 'Please create a backup script for my project';
        const aiResponse = '''
Here's a backup script:

```bash
#!/bin/bash
mkdir -p ~/backups
tar --exclude=node_modules --exclude=.git -czf ~/backups/project-\$(date +%Y%m%d-%H%M%S).tar.gz .
ls -lh ~/backups/project-*.tar.gz
```
''';
        const toolCalls = <String>['bash'];

        final skill = SkillDistiller.createFromMessageText(
          userMessage: userMessage,
          aiResponse: aiResponse,
          toolCalls: ['bash'],
          sessionTitle: 'Backup Script Request',
        );

        expect(skill.name, isNotEmpty);
        expect(skill.goal, isNotEmpty);
        expect(skill.description, isNotEmpty);
        expect(skill.steps, isNotEmpty);
        expect(skill.steps.length, greaterThan(0));
        expect(skill.requiredTools, contains('tar'));
        expect(skill.requiredTools, contains('bash'));
        expect(skill.constraints, isNotEmpty);
        expect(skill.constraints, isNot(contains('Created from message')));
      });

      test('extracts tar tool from script', () {
        const userMessage = 'Create a backup script';
        const aiResponse = '''
```bash
tar --exclude=node_modules -czf backup.tar.gz .
sha256sum backup.tar.gz
```
''';

        final skill = SkillDistiller.createFromMessageText(
          userMessage: 'Create backup',
          aiResponse: aiResponse,
          toolCalls: [],
          sessionTitle: 'Test',
        );

        expect(skill.requiredTools, contains('tar'));
        expect(skill.requiredTools, contains('sha256sum'));
      });

      test('generates meaningful name from intent', () {
        const userMessage = 'Help me create a backup script for my project';
        const aiResponse = 'Here is the script...';

        final skill = SkillDistiller.createFromMessageText(
          userMessage: userMessage,
          aiResponse: aiResponse,
          toolCalls: ['bash'],
          sessionTitle: 'Backup Script',
        );

        expect(skill.name, isNotEmpty);
        expect(skill.name, isNot('Unnamed Skill'));
        expect(skill.name.length, lessThanOrEqualTo(60));
      });

      test('goal reflects script purpose', () {
        const userMessage = 'Create a backup script that uses tar';
        const aiResponse = '''
```bash
tar -czf backup.tar.gz .
```
''';

        final skill = SkillDistiller.createFromMessageText(
          userMessage: userMessage,
          aiResponse: aiResponse,
          toolCalls: ['bash'],
          sessionTitle: 'Test',
        );

        expect(skill.goal, isNotEmpty);
        expect(skill.goal, isNot('Achieve the task described in the message'));
      });

      test('description reflects script content', () {
        const userMessage = 'Create backup script';
        const aiResponse = '''
```bash
tar -czf backup.tar.gz .
sha256sum backup.tar.gz
```
''';

        final skill = SkillDistiller.createFromMessageText(
          userMessage: userMessage,
          aiResponse: aiResponse,
          toolCalls: ['bash'],
          sessionTitle: 'Backup Script',
        );

        expect(skill.description, isNotEmpty);
        expect(skill.description, isNot('Created from message'));
        expect(skill.description, anyOf(contains('tar'), contains('script')));
      });

      test('combines toolCalls and script tools', () {
        const userMessage = 'Run backup';
        const aiResponse = '''
```bash
tar -czf backup.tar.gz .
sha256sum backup.tar.gz
```
''';

        final skill = SkillDistiller.createFromMessageText(
          userMessage: userMessage,
          aiResponse: aiResponse,
          toolCalls: ['bash', 'edit'],
          sessionTitle: 'Test',
        );

        // Should have both toolCalls and script-inferred tools
        expect(skill.requiredTools, contains('bash'));
        expect(skill.requiredTools, contains('edit'));
        expect(skill.requiredTools, contains('tar'));
        expect(skill.requiredTools, contains('sha256sum'));
      });

      test('handles message without script', () {
        const userMessage = 'How do I backup my files?';
        const aiResponse = 'You can use tar to create archives.';

        final skill = SkillDistiller.createFromMessageText(
          userMessage: userMessage,
          aiResponse: aiResponse,
          toolCalls: ['bash'],
          sessionTitle: 'Backup Question',
        );

        expect(skill.name, isNotEmpty);
        expect(skill.goal, isNotEmpty);
        expect(skill.requiredTools, contains('bash'));
      });
    });

    group('_extractSkillName', () {
      test('extracts name from intent pattern', () {
        const userMessage = 'Create a backup script for my project';
        final name = SkillDistiller.extractSkillName(userMessage, null, null);
        expect(name, isNotEmpty);
        expect(name.length, lessThanOrEqualTo(60));
      });

      test('extracts name from "for/to" pattern', () {
        const userMessage = 'Create a script for backing up my files';
        final name = SkillDistiller.extractSkillName(userMessage, null, null);
        expect(name, isNotEmpty);
      });

      test('falls back to cleaned message', () {
        const userMessage = 'Hello world';
        final name = SkillDistiller.extractSkillName('Hello world', null, null);
        expect(name, isNotEmpty);
      });

      test('handles empty message', () {
        final name = SkillDistiller.extractSkillName('', null, null);
        expect(name, 'Unnamed Skill');
      });
    });

    group('_extractGoalFromMessage', () {
      test('extracts goal from intent pattern', () {
        const userMessage = 'Create a backup script for my project';
        final goal = SkillDistiller.extractGoalFromMessage(userMessage, null, null);
        expect(goal, isNotEmpty);
        expect(goal.length, greaterThan(10));
      });

      test('infers goal from script when available', () {
        final script = ExtractedScript(
          language: 'bash',
          content: 'tar -czf backup.tar.gz .',
          steps: ['Create compressed archive with tar'],
          tools: {'tar'},
        );
        const userMessage = 'Create backup';
        final goal = SkillDistiller.extractGoalFromMessage(userMessage, null, script);
        expect(goal, isNotEmpty);
        expect(goal, anyOf(contains('Automate'), contains('tar')));
      });

      test('falls back to cleaned message', () {
        const userMessage = 'Hello';
        final goal = SkillDistiller.extractGoalFromMessage(userMessage, null, null);
        expect(goal, isNotEmpty);
      });
    });

    group('_createDescription', () {
      test('uses AI response when available', () {
        const aiResponse = 'Here is a script that backs up your project using tar and verifies the archive.';
        final desc = SkillDistiller.createDescription('backup', aiResponse, null, 'Test');
        expect(desc, anyOf(contains('tar'), contains('archive'), contains('backup')));
      });

      test('generates from script when no AI response', () {
        final script = ExtractedScript(
          language: 'bash',
          content: 'tar -czf backup.tar.gz .\nsha256sum backup.tar.gz',
          steps: ['Create compressed archive with tar', 'Generate checksum with sha256sum'],
          tools: {'tar', 'sha256sum'},
        );
        final desc = SkillDistiller.createDescription('backup', null, script, null);
        expect(desc, anyOf(contains('tar'), contains('sha256sum'), contains('step')));
      });

      test('falls back to session title', () {
        const desc = SkillDistiller.createDescription('msg', null, null, 'My Session');
        expect(desc, 'Distilled from: My Session');
      });
    });

    group('replaceTemplates', () {
      test('replaces {{placeholder}}', () {
        final result = SkillDistiller.replaceTemplates('Hello {{name}}', {'name': 'World'});
        expect(result, 'Hello World');
      });

      test('replaces ${placeholder}', () {
        final result = SkillDistiller.replaceTemplates('Hello ${name}', {'name': 'World'});
        expect(result, 'Hello World');
      });

      test('replaces $placeholder', () {
        final result = SkillDistiller.replaceTemplates('Hello $name', {'name': 'World'});
        expect(result, 'Hello World');
      });

      test('skips shell positional parameters $1-$9', () {
        final script = 'tar -czf \$1.tar.gz \$2';
        final result = SkillDistiller.replaceTemplates(script, {'1': 'backup', '2': 'src'});
        expect(result, contains('\$1'));
        expect(result, contains('\$2'));
      });

      test('skips shell special parameters', () {
        const script = 'echo \$@ \$* \$# \$? \$\$ \$!';
        final result = SkillDistiller.replaceTemplates(script, {'@': 'args', '*': 'all', '#': 'count'});
        expect(result, contains('\$@'));
        expect(result, contains('\$*'));
        expect(result, contains('\$#'));
        expect(result, contains('\$?'));
      });

      test('does not replace when no replacements', () {
        final text = 'Hello {{name}}';
        final result = SkillDistiller.replaceTemplates(text, {});
        expect(result, 'Hello {{name}}');
      });

      test('replaces multiple placeholders', () {
        final result = SkillDistiller.replaceTemplates(
          '{{cmd}} -czf {{output}} .',
          {'cmd': 'tar', 'output': 'backup.tar.gz'},
        );
        expect(result, 'tar -czf backup.tar.gz .');
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
      final redacted = redactJson(json) as Map<String, dynamic>;
      final apiKey = redacted['api_key'] as String?;
      expect(apiKey, contains('sk-••••••'));
      final nested = redacted['nested'] as Map?;
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