// Tests for turn-based skill distillation (distillTurn)

import 'package:flutter_test/flutter_test.dart';
import 'package:dsh_client/dsh_client.dart';

import 'package:dsh_app/skills/distill/heuristics.dart';
import 'package:dsh_app/skills/skill_distill.dart';

void main() {
  group('Turn-based Distillation (distillTurn)', () {
    // Fixture A: Backup script via write tool
    group('Fixture A - Backup script written by agent', () {
      final userPrompt = '請幫我寫一個備份腳本，把專案壓縮成 tar.gz，排除 node_modules 和 .git';
      final assistantMarkdown = '''我來幫你寫備份腳本：

這是腳本內容：

```bash
#!/bin/bash
# 備份專案
tar --exclude=node_modules --exclude=.git -czf backup.tar.gz .
```''';

      final toolCalls = [
        ToolCallInfo('write', {
          'path': '/home/user/backup_flutter.sh',
          'content': '''#!/bin/bash
# 備份專案到 ~/backups/，排除常見不需備份的目錄
set -euo pipefail

BACKUP_DIR="\$HOME/backups"
mkdir -p "\$BACKUP_DIR"

TIMESTAMP=\$(date '+%Y%m%d-%H%M%S')
BACKUP_FILE="\$BACKUP_DIR/project-\$TIMESTAMP.tar.gz"

tar --exclude='node_modules' \\
  --exclude='.git' \\
  --exclude='build' \\
  --exclude='dist' \\
  --exclude='.DS_Store' \\
  -czf "\$BACKUP_FILE" .

if [ -s "\$BACKUP_FILE" ]; then
  echo "✅ 備份成功!"
else
  echo "❌ 備份失敗: 檔案大小為 0 位元組"
fi

echo "📁 路徑: \$BACKUP_FILE"''',
        }),
        ToolCallInfo('bash', {
          'command': './backup_flutter.sh',
        }),
      ];

      test('distills from written file with full script content', () {
        final draft = distillTurn(
          userPrompt: userPrompt,
          assistantMarkdown: assistantMarkdown,
          toolCallsWithArgs: toolCalls,
          lex: const ThaiLex(),
          allowCjk: false,
        );

        // Should use the written file content, not the inline snippet
        expect(draft.script, isNotNull);
        expect(draft.script, contains('BACKUP_DIR'));
        expect(draft.script, contains('mkdir -p'));
        expect(draft.script, contains('tar --exclude'));

        // Should have 5 steps: setup, mkdir, tar, verify, report
        expect(draft.steps.length, 5);
        expect(draft.steps[0].kind, StepKind.setup);
        expect(draft.steps[1].kind, StepKind.action);
        expect(draft.steps[2].kind, StepKind.action);
        expect(draft.steps[3].kind, StepKind.verify);
        expect(draft.steps[4].kind, StepKind.report);

        // Tar step should include all excludes
        final tarStep = draft.steps[2];
        expect(tarStep.title, contains('node_modules'));
        expect(tarStep.title, contains('.git'));
        expect(tarStep.title, contains('build'));
        expect(tarStep.title, contains('dist'));
        expect(tarStep.title, contains('.DS_Store'));

        // Goal should differ from name
        expect(draft.goal, isNotNull);
        expect(normKey(draft.goal!), isNot(normKey(draft.name!)));

        // No CJK in output fields
        expect(hasCjk(draft.name!), false);
        expect(hasCjk(draft.goal!), false);
        for (final step in draft.steps) {
          expect(hasCjk(step.title), false);
        }
      });

      test('createFromTurn produces skill with correct fields', () {
        final skill = SkillDistiller.createFromTurn(
          userMessage: userPrompt,
          aiResponse: assistantMarkdown,
          toolCallsWithArgs: toolCalls,
          sessionTitle: 'Backup skill from turn',
        );

        expect(skill.name, 'สำรองโปรเจกต์เป็น tar.gz');
        expect(skill.goal, isNot(skill.name));
        expect(skill.description, isNotNull);
        expect(skill.steps.length, 5);
        expect(skill.constraints, contains('ห้ามเก็บความลับ (API key, token, รหัสผ่าน)'));
        expect(skill.requiredTools, contains('write'));
        expect(skill.requiredTools, contains('bash'));
      });
    });

    // Fixture B: Example output block
    group('Fixture B - Example output block (no language)', () {
      final userPrompt = 'Show backup result';
      final assistantMarkdown = '''Here is the backup result:

```
/home/user/backups/project-20261125-143016.tar.gz
Size: 2.5 MB
Created: 2026-11-25 14:30:16
```''';

      final toolCalls = <ToolCallInfo>[];

      test('ignores unlanguaged block, no garbage steps', () {
        final draft = distillTurn(
          userPrompt: userPrompt,
          assistantMarkdown: assistantMarkdown,
          toolCallsWithArgs: toolCalls,
          lex: const ThaiLex(),
          allowCjk: false,
        );

        // Should not produce garbage steps from example output
        for (final step in draft.steps) {
          expect(step.title.startsWith(': '), false, reason: 'Should not have path-only step');
          expect(step.title, isNot(contains('✅')));
          expect(step.title, isNot(contains('📁')));
          expect(step.title, isNot(contains('Size:')));
          expect(step.title, isNot(contains('Created:')));
        }
      });
    });

    // Fixture C: Usage block (chmod +x / ./script.sh)
    group('Fixture C - Usage block (chmod +x / ./script.sh)', () {
      final userPrompt = 'How to use backup script';
      final assistantMarkdown = '''Usage:

```bash
chmod +x backup.sh
./backup.sh
```''';

      final toolCalls = <ToolCallInfo>[];

      test('ignores chmod and ./script.sh, no false positive tools', () {
        final draft = distillTurn(
          userPrompt: userPrompt,
          assistantMarkdown: assistantMarkdown,
          toolCallsWithArgs: toolCalls,
          lex: const ThaiLex(),
          allowCjk: false,
        );

        // chmod and ./script.sh should not appear in tools
        final toolNames = draft.tools.map((t) => t.toLowerCase()).toSet();
        expect(toolNames.contains('chmod'), false, reason: 'chmod should not be a tool');
        expect(toolNames.contains('sh'), false, reason: 'sh should not be a tool');
        expect(toolNames.contains('bash'), false, reason: 'bash should not be a tool from usage');
      });
    });

    // Fixture D: No code block (just explanation)
    group('Fixture D - No code block (just explanation)', () {
      final userPrompt = 'Explain how tar works';
      final assistantMarkdown = '''Tar creates archives by concatenating files and compressing them.

The basic syntax is: tar [options] [archive] [files]''';

      final toolCalls = <ToolCallInfo>[];

      test('returns empty steps when no code block', () {
        final draft = distillTurn(
          userPrompt: userPrompt,
          assistantMarkdown: assistantMarkdown,
          toolCallsWithArgs: toolCalls,
          lex: const ThaiLex(),
          allowCjk: false,
        );

        expect(draft.steps, isEmpty);
        expect(draft.script, isNull);
        // Name should still be inferred from user prompt
        expect(draft.name, isNotNull);
      });

      test('createFromTurn handles no script', () {
        final skill = SkillDistiller.createFromTurn(
          userMessage: userPrompt,
          aiResponse: assistantMarkdown,
          toolCallsWithArgs: toolCalls,
          sessionTitle: 'Tar explanation',
        );

        expect(skill.steps, isEmpty);
        expect(skill.name, isNotNull);
      });
    });

    // Fixture E: rm destructive command
    group('Fixture E - rm destructive command (find ... -delete)', () {
      final userPrompt = 'Clean up old backups';
      final assistantMarkdown = '''```bash
#!/bin/bash
# Clean backups older than 30 days
find ~/backups -name "project-*.tar.gz" -mtime +30 -delete
```''';

      final toolCalls = <ToolCallInfo>[];

      test('adds confirmDestructive constraint', () {
        final draft = distillTurn(
          userPrompt: userPrompt,
          assistantMarkdown: assistantMarkdown,
          toolCallsWithArgs: toolCalls,
          lex: const ThaiLex(),
          allowCjk: false,
        );

        // Should have confirmDestructive constraint from rm/delete
        expect(draft.constraints, contains('ต้องได้รับอนุมัติก่อนรันคำสั่งที่ลบหรือแก้ไขไฟล์'));
      });
    });

    // Fixture F: Multiple write tool calls - picks main script
    group('Fixture F - Multiple write tool calls (picks main script)', () {
      final userPrompt = 'Create deploy and backup scripts';
      final assistantMarkdown = '''I'll create two scripts for you.''';

      final toolCalls = [
        ToolCallInfo('write', {
          'path': '/home/user/deploy.sh',
          'content': '''#!/bin/bash
# Deploy script
docker build -t myapp .
docker push myapp''',
        }),
        ToolCallInfo('write', {
          'path': '/home/user/backup.sh',
          'content': '''#!/bin/bash
# Backup script - larger and more complex
BACKUP_DIR="\$HOME/backups"
mkdir -p "\$BACKUP_DIR"

tar --exclude='node_modules' \\
  --exclude='.git' \\
  -czf "\$BACKUP_DIR/backup.tar.gz" .

echo "Done"''',
        }),
        ToolCallInfo('write', {
          'path': '/home/user/readme.txt',
          'content': 'This is just a readme file, not a script.',
        }),
      ];

      test('picks the largest script file (backup.sh)', () {
        final draft = distillTurn(
          userPrompt: userPrompt,
          assistantMarkdown: assistantMarkdown,
          toolCallsWithArgs: toolCalls,
          lex: const ThaiLex(),
          allowCjk: false,
        );

        // Should pick backup.sh (larger content) not deploy.sh
        expect(draft.script, isNotNull);
        expect(draft.script, contains('BACKUP_DIR'));
        expect(draft.script, contains('mkdir -p'));
        expect(draft.script, contains('tar --exclude'));

        // Should have tar steps
        expect(draft.steps.any((s) => s.title.contains('สร้างไฟล์บีบอัด')), true);
      });

      test('ignores non-script files', () {
        final draft = distillTurn(
          userPrompt: userPrompt,
          assistantMarkdown: assistantMarkdown,
          toolCallsWithArgs: toolCalls,
          lex: const ThaiLex(),
          allowCjk: false,
        );

        // readme.txt should be ignored (no shebang, not .sh/.bash/.zsh)
        expect(draft.script, isNot(contains('readme')));
      });
    });

    // Additional: Variable expansion in step titles from turn-based
    group('Fixture G - Variable expansion in step titles', () {
      final userPrompt = 'Backup with custom dir';
      final assistantMarkdown = '''''';

      final toolCalls = [
        ToolCallInfo('write', {
          'path': '/home/user/backup.sh',
          'content': '''#!/bin/bash
BACKUP_DIR="\$HOME/my_backups"
mkdir -p "\$BACKUP_DIR"
tar -czf "\$BACKUP_DIR/project.tar.gz" .''',
        }),
      ];

      test('expands \$HOME to ~ and \$BACKUP_DIR to value', () {
        final draft = distillTurn(
          userPrompt: userPrompt,
          assistantMarkdown: assistantMarkdown,
          toolCallsWithArgs: toolCalls,
          lex: const ThaiLex(),
          allowCjk: false,
        );

        // Step titles should have expanded variables
        for (final step in draft.steps) {
          expect(step.title.contains('\$'), false, reason: 'Step title should not have raw \$: ${step.title}');
        }

        // mkdir step should show expanded path
        final mkdirStep = draft.steps.firstWhere((s) => s.title.contains('สร้างโฟลเดอร์'));
        expect(mkdirStep.title, contains('~'));
        expect(mkdirStep.title, contains('my_backups'));
      });
    });

    // Additional: Goal from userPrompt not step titles
    group('Fixture H - Goal from userPrompt intent', () {
      final userPrompt = '備份專案到 tar.gz，排除 node_modules';
      final assistantMarkdown = '''''';

      final toolCalls = [
        ToolCallInfo('write', {
          'path': '/home/user/backup.sh',
          'content': '''#!/bin/bash
tar --exclude=node_modules -czf backup.tar.gz .''',
        }),
      ];

      test('goal uses userPrompt intent, not step titles joined with arrows', () {
        final draft = distillTurn(
          userPrompt: userPrompt,
          assistantMarkdown: assistantMarkdown,
          toolCallsWithArgs: toolCalls,
          lex: const ThaiLex(),
          allowCjk: false,
        );

        // Goal should not contain "→" (arrow from joined step titles)
        expect(draft.goal, isNot(contains('→')));
        // Goal should mention backup intent
        expect(draft.goal, contains('สำรอง'));
        expect(draft.goal, contains('node_modules'));
        // Goal should not equal name
        expect(draft.goal, isNot(draft.name));
      });
    });

    // Additional: Invoked script reference
    group('Fixture I - Invoked script reference (./backup.sh)', () {
      final userPrompt = 'Run backup script';
      final assistantMarkdown = '''Run the backup script to create archive.''';

      final toolCalls = [
        ToolCallInfo('bash', {
          'command': './backup_flutter.sh',
        }),
      ];

      test('creates step from invoked script reference', () {
        final draft = distillTurn(
          userPrompt: userPrompt,
          assistantMarkdown: assistantMarkdown,
          toolCallsWithArgs: toolCalls,
          lex: const ThaiLex(),
          allowCjk: false,
        );

        // Should have a step for running the script
        expect(draft.steps.length, greaterThanOrEqualTo(1));
        expect(draft.steps.any((s) => s.title.contains('backup_flutter.sh') || s.title.contains('รันสคริปต์')), true);

        // Should have needsFile constraint
        expect(draft.constraints.any((c) => c.contains('ต้องมีไฟล์') && c.contains('backup_flutter.sh')), true);
      });
    });

    // Additional: Main script selection with multiple blocks (written + inline)
    group('Fixture J - Written file preferred over inline', () {
      final userPrompt = 'Backup script';
      final assistantMarkdown = '''Here is an example output:

```
project-20261125.tar.gz
Size: 1.2 MB
```

And the actual script:

```bash
#!/bin/bash
tar --exclude=node_modules -czf backup.tar.gz .
```''';

      final toolCalls = [
        ToolCallInfo('write', {
          'path': '/home/user/backup.sh',
          'content': '''#!/bin/bash
# Full backup script with all features
BACKUP_DIR="\$HOME/backups"
mkdir -p "\$BACKUP_DIR"

tar --exclude='node_modules' \\
  --exclude='.git' \\
  --exclude='build' \\
  --exclude='dist' \\
  -czf "\$BACKUP_DIR/backup.tar.gz" .

echo "Done"''',
        }),
      ];

      test('prefers written file over inline snippet', () {
        final draft = distillTurn(
          userPrompt: userPrompt,
          assistantMarkdown: assistantMarkdown,
          toolCallsWithArgs: toolCalls,
          lex: const ThaiLex(),
          allowCjk: false,
        );

        // Should use written file (has more content: BACKUP_DIR, mkdir, multiple excludes)
        expect(draft.script, isNotNull);
        expect(draft.script, contains('BACKUP_DIR'));
        expect(draft.script, contains('mkdir -p'));

        // Should have more steps than just the inline tar command
        expect(draft.steps.length, greaterThanOrEqualTo(4));
      });

      test('ignores example output block', () {
        final draft = distillTurn(
          userPrompt: userPrompt,
          assistantMarkdown: assistantMarkdown,
          toolCallsWithArgs: toolCalls,
          lex: const ThaiLex(),
          allowCjk: false,
        );

        // Should not have garbage from example output
        for (final step in draft.steps) {
          expect(step.title.startsWith(': '), false);
          expect(step.title, isNot(contains('Size:')));
        }
      });
    });
  });
}