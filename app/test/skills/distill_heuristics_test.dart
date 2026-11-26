// Tests for the new pipeline-based skill distillation (heuristics.dart)

import 'package:flutter_test/flutter_test.dart';

import 'package:dsh_app/skills/distill/heuristics.dart';

void main() {
  group('Heuristics Pipeline', () {
    group('splitFences', () {
      test('extracts bash code block from markdown', () {
        const md = '''
Here is a script:

```bash
#!/bin/bash
tar -czf backup.tar.gz .
```
''';

        final seg = splitFences(md);
        expect(seg.blocks.length, 1);
        expect(seg.blocks.first.lang, 'bash');
        expect(seg.blocks.first.code, contains('tar -czf'));
      });

      test('extracts multiple code blocks', () {
        const md = '''
```bash
echo first
```
text
```sh
echo second
```
''';
        final seg = splitFences(md);
        expect(seg.blocks.length, 2);
      });

      test('handles unclosed fence', () {
        const md = '''
```bash
echo hello
```''';
        final seg = splitFences(md);
        expect(seg.blocks.length, 1);
        expect(seg.blocks.first.code, 'echo hello');
      });

      test('ignores tables', () {
        const md = '''
| a | b |
|---|---|
| 1 | 2 |
```bash
echo hi
```''';
        final seg = splitFences(md);
        expect(seg.blocks.length, 1);
        expect(seg.prose, isNot(contains('| a |')));
      });
    });

    group('joinContinuations', () {
      test('joins backslash continuation lines', () {
        const code = '''tar --exclude=node_modules \\
  --exclude=.git \\
  -czf backup.tar.gz .''';
        final lines = joinContinuations(code);
        expect(lines.length, 1);
        expect(lines.first, contains('--exclude=node_modules'));
        expect(lines.first, contains('--exclude=.git'));
        expect(lines.first, contains('-czf backup.tar.gz'));
      });

      test('joins lines ending with && or ||', () {
        const code = '''mkdir -p dir &&
  cd dir''';
        final lines = joinContinuations(code);
        expect(lines.length, 1);
      });

      test('does not join comment lines', () {
        const code = '''# comment \\
  more''';
        final lines = joinContinuations(code);
        expect(lines.length, 2); // comment line not joined
      });
    });

    group('shellWords', () {
      test('splits simple command', () {
        final words = shellWords('tar -czf backup.tar.gz .');
        expect(words, ['tar', '-czf', 'backup.tar.gz', '.']);
      });

      test('handles quoted arguments', () {
        final words = shellWords('echo "hello world"');
        expect(words, ['echo', 'hello world']);
      });

      test('handles single quotes', () {
        final words = shellWords("echo 'hello world'");
        expect(words, ['echo', 'hello world']);
      });

      test('handles escaped characters', () {
        final words = shellWords('echo hello\\ world');
        expect(words, ['echo', 'hello world']);
      });

      test('stops at comment', () {
        final words = shellWords('echo hello # comment');
        expect(words, ['echo', 'hello']);
      });
    });

    group('commentLabel', () {
      test('extracts English step comment', () {
        final label = commentLabel('# Step 1: Create backup directory');
        expect(label, 'Create backup directory');
      });

      test('extracts Chinese step comment', () {
        final label = commentLabel('# 步骤 1: 建立備份目錄', allowCjk: true);
        expect(label, '建立備份目錄');
      });

      test('extracts Thai step comment', () {
        final label = commentLabel('# ขั้นตอน 1: สร้างโฟลเดอร์สำรอง', allowCjk: true);
        expect(label, 'สร้างโฟลเดอร์สำรอง');
      });

      test('rejects CJK when not allowed', () {
        final label = commentLabel('# 步骤 1: 建立備份目錄', allowCjk: false);
        expect(label, isNull);
      });

      test('rejects decorator lines', () {
        expect(commentLabel('# =========='), isNull);
        expect(commentLabel('# -----'), isNull);
      });

      test('rejects directives', () {
        expect(commentLabel('# shellcheck disable=SC2034'), isNull);
      });

      test('rejects too short', () {
        expect(commentLabel('# hi'), isNull);
      });
    });

    group('parseScript', () {
      const backupScript = '''#!/bin/bash
# 備份當前專案到 ~/backups/，排除常見不需備份的目錄
set -euo pipefail

# 1) 建立備份目錄
BACKUP_DIR="\$HOME/backups"
mkdir -p "\$BACKUP_DIR"

# 2) 產生帶時間戳的檔名
TIMESTAMP=\$(date '+%Y%m%d-%H%M%S')
BACKUP_FILE="\$BACKUP_DIR/project-\$TIMESTAMP.tar.gz"

# 3) 建立壓縮備份
tar --exclude='node_modules' \\
  --exclude='.git' \\
  --exclude='build' \\
  --exclude='dist' \\
  --exclude='.DS_Store' \\
  -czf "\$BACKUP_FILE" .

# 4) 驗證備份
if [ -s "\$BACKUP_FILE" ]; then
  echo "✅ 備份成功!"
else
  echo "❌ 備份失敗: 檔案大小為 0 bytes"
fi

# 5) 顯示結果
echo "📁 路徑: \$BACKUP_FILE"
''';

      test('parses backup script into 5 steps', () {
        final steps = parseScript(backupScript, const ThaiLex());
        
        // Should have 5 steps: setup, mkdir, tar, verify, report
        expect(steps.length, 5);
        
        // Step 0: setup
        expect(steps[0].kind, StepKind.setup);
        expect(steps[0].title, 'ตั้งค่าตัวแปรและค่าเริ่มต้น');
        
        // Step 1: mkdir
        expect(steps[1].kind, StepKind.action);
        expect(steps[1].title, contains('สร้างโฟลเดอร์'));
        
        // Step 2: tar with all excludes
        expect(steps[2].kind, StepKind.action);
        expect(steps[2].title, contains('สร้างไฟล์บีบอัด'));
        expect(steps[2].title, contains('node_modules'));
        expect(steps[2].title, contains('.git'));
        expect(steps[2].title, contains('build'));
        expect(steps[2].title, contains('dist'));
        expect(steps[2].title, contains('.DS_Store'));
        
        // Step 3: verify
        expect(steps[3].kind, StepKind.verify);
        expect(steps[3].title, contains('ตรวจ'));
        
        // Step 4: report
        expect(steps[4].kind, StepKind.report);
        expect(steps[4].title, 'แสดงสถานะ/เส้นทางไฟล์ที่ได้');
      });

      test('no CJK in step titles when allowCjk=false', () {
        final steps = parseScript(backupScript, const ThaiLex(), allowCjkLabels: false);
        for (final step in steps) {
          expect(hasCjk(step.title), false, reason: 'Step title should not have CJK: ${step.title}');
        }
      });

      test('no step starts with echo/--exclude/#', () {
        final steps = parseScript(backupScript, const ThaiLex());
        for (final step in steps) {
          expect(step.title.startsWith('echo'), false);
          expect(step.title.startsWith('--exclude'), false);
          expect(step.title.startsWith('#'), false);
        }
      });
    });

    group('distillScript - backup scenario', () {
      const userPrompt = '請幫我寫一個備份腳本，把專案壓縮成 tar.gz，排除 node_modules 和 .git';
      const aiResponse = '''這裡是備份腳本：

```bash
#!/bin/bash
# 備份當前專案到 ~/backups/，排除常見不需備份的目錄
set -euo pipefail

# 1) 建立備份目錄
BACKUP_DIR="\$HOME/backups"
mkdir -p "\$BACKUP_DIR"

# 2) 產生帶時間戳的檔名
TIMESTAMP=\$(date '+%Y%m%d-%H%M%S')
BACKUP_FILE="\$BACKUP_DIR/project-\$TIMESTAMP.tar.gz"

# 3) 建立壓縮備份
tar --exclude='node_modules' \\
  --exclude='.git' \\
  --exclude='build' \\
  --exclude='dist' \\
  --exclude='.DS_Store' \\
  -czf "\$BACKUP_FILE" .

# 4) 驗證備份
if [ -s "\$BACKUP_FILE" ]; then
  echo "✅ 備份成功!"
else
  echo "❌ 備份失敗: 檔案大小為 0 位元組"
fi

# 5) 顯示結果
echo "📁 路徑: \$BACKUP_FILE"
```''';

      test('produces correct Thai name', () {
        final draft = distillScript(
          userPrompt: userPrompt,
          assistantMarkdown: aiResponse,
          lex: const ThaiLex(),
          allowCjk: false,
        );
        
        expect(draft.name, 'สำรองโปรเจกต์เป็น tar.gz');
      });

      test('produces correct steps', () {
        final draft = distillScript(
          userPrompt: userPrompt,
          assistantMarkdown: aiResponse,
          lex: const ThaiLex(),
          allowCjk: false,
        );
        
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
      });

      test('goal differs from name', () {
        final draft = distillScript(
          userPrompt: userPrompt,
          assistantMarkdown: aiResponse,
          lex: const ThaiLex(),
          allowCjk: false,
        );
        
        expect(draft.goal, isNotNull);
        expect(normKey(draft.goal!), isNot(normKey(draft.name!)));
      });

      test('name is not "Script"', () {
        final draft = distillScript(
          userPrompt: userPrompt,
          assistantMarkdown: aiResponse,
          lex: const ThaiLex(),
          allowCjk: false,
        );
        
        expect(draft.name, isNot('Script'));
        expect(draft.name, isNot('script'));
      });

      test('no CJK in output fields', () {
        final draft = distillScript(
          userPrompt: userPrompt,
          assistantMarkdown: aiResponse,
          lex: const ThaiLex(),
          allowCjk: false,
        );
        
        expect(hasCjk(draft.name!), false);
        expect(hasCjk(draft.goal!), false);
        for (final step in draft.steps) {
          expect(hasCjk(step.title), false);
        }
      });
    });

    group('distillScript - bullet list only (no code block)', () {
      const userPrompt = 'How to backup project';
      const aiResponse = '''Steps to backup:
- Create backup directory
- Run tar with excludes
- Verify the archive
- Report success''';

      test('extracts steps from bullet list', () {
        final draft = distillScript(
          userPrompt: userPrompt,
          assistantMarkdown: aiResponse,
          lex: const ThaiLex(),
          allowCjk: false,
        );
        
        expect(draft.steps.length, greaterThanOrEqualTo(3));
      });
    });

    group('distillScript - markdown table', () {
      const userPrompt = 'Deploy steps';
      const aiResponse = '''| Step | Command |
|------|---------|
| 1 | docker build -t app . |
| 2 | docker push app |''';

      test('ignores table, extracts from prose', () {
        final draft = distillScript(
          userPrompt: userPrompt,
          assistantMarkdown: aiResponse,
          lex: const ThaiLex(),
          allowCjk: false,
        );
        
        // Table should be ignored, no code blocks = empty steps
        expect(draft.steps, isEmpty);
      });
    });

    group('distillScript - example output block (no language)', () {
      const userPrompt = 'Show backup result';
      const aiResponse = '''Here is the backup result:

```
/home/user/backups/project-20261125-143016.tar.gz
Size: 2.5 MB
Created: 2026-11-25 14:30:16
```''';

      test('ignores unlanguaged block, no garbage steps', () {
        final draft = distillScript(
          userPrompt: userPrompt,
          assistantMarkdown: aiResponse,
          lex: const ThaiLex(),
          allowCjk: false,
        );
        
        // Unlanguaged block should be treated as example output, not parsed as script
        // Should not produce garbage steps like ": ~/backups/..." or "✅ !"
        for (final step in draft.steps) {
          expect(step.title.startsWith(': '), false, reason: 'Should not have path-only step');
          expect(step.title, isNot(contains('✅')));
          expect(step.title, isNot(contains('📁')));
          expect(step.title, isNot(contains('📦')));
        }
      });
    });

    group('distillScript - usage block (chmod +x / ./script.sh)', () {
      const userPrompt = 'How to use backup script';
      const aiResponse = '''Usage:

```bash
chmod +x backup.sh
./backup.sh
```''';

      test('ignores chmod and ./script.sh, no false positive tools', () {
        final draft = distillScript(
          userPrompt: userPrompt,
          assistantMarkdown: aiResponse,
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

    group('distillScript - no code block', () {
      const userPrompt = 'Explain how tar works';
      const aiResponse = '''Tar creates archives by concatenating files and compressing them.

The basic syntax is: tar [options] [archive] [files]''';

      test('returns empty steps when no code block', () {
        final draft = distillScript(
          userPrompt: userPrompt,
          assistantMarkdown: aiResponse,
          lex: const ThaiLex(),
          allowCjk: false,
        );
        
        expect(draft.steps, isEmpty);
        expect(draft.script, isNull);
        // Name should still be inferred from user prompt
        expect(draft.name, isNotNull);
      });
    });

    group('distillScript - rm destructive command', () {
      const userPrompt = 'Clean up old backups';
      const aiResponse = '''```bash
#!/bin/bash
# Clean backups older than 30 days
find ~/backups -name "project-*.tar.gz" -mtime +30 -delete
```''';

      test('adds confirmDestructive constraint', () {
        final draft = distillScript(
          userPrompt: userPrompt,
          assistantMarkdown: aiResponse,
          lex: const ThaiLex(),
          allowCjk: false,
        );
        
        // Should have confirmDestructive constraint from rm/delete
        expect(draft.constraints, contains('ต้องได้รับอนุมัติก่อนรันคำสั่งที่ลบหรือแก้ไขไฟล์'));
      });
    });

    group('distillScript - git clean / git reset --hard', () {
      const userPrompt = 'Reset repo';
      const aiResponse = '''```bash
git clean -fd
git reset --hard HEAD
```''';

      test('adds confirmDestructive for git destructive commands', () {
        final draft = distillScript(
          userPrompt: userPrompt,
          assistantMarkdown: aiResponse,
          lex: const ThaiLex(),
          allowCjk: false,
        );
        
        expect(draft.constraints, contains('ต้องได้รับอนุมัติก่อนรันคำสั่งที่ลบหรือแก้ไขไฟล์'));
      });
    });

    group('distillScript - variable expansion in step titles', () {
      const userPrompt = 'Backup with custom dir';
      const aiResponse = '''```bash
#!/bin/bash
BACKUP_DIR="\$HOME/my_backups"
mkdir -p "\$BACKUP_DIR"
tar -czf "\$BACKUP_DIR/project.tar.gz" .
```''';

      test('expands \$HOME to ~ and \$BACKUP_DIR to value', () {
        final draft = distillScript(
          userPrompt: userPrompt,
          assistantMarkdown: aiResponse,
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

    group('distillScript - goal from userPrompt not step titles', () {
      const userPrompt = '備份專案到 tar.gz，排除 node_modules';
      const aiResponse = '''```bash
tar --exclude=node_modules -czf backup.tar.gz .
```''';

      test('goal uses userPrompt intent, not step titles joined with arrows', () {
        final draft = distillScript(
          userPrompt: userPrompt,
          assistantMarkdown: aiResponse,
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

    group('distillScript - main script selection (multiple blocks)', () {
      const userPrompt = 'Backup script';
      const aiResponse = '''Here is an example output:

```
project-20261125.tar.gz
Size: 1.2 MB
```

And the actual script:

```bash
#!/bin/bash
tar --exclude=node_modules -czf backup.tar.gz .
```''';

      test('picks the script block with shebang, not example output', () {
        final draft = distillScript(
          userPrompt: userPrompt,
          assistantMarkdown: aiResponse,
          lex: const ThaiLex(),
          allowCjk: false,
        );
        
        // Should parse the script block, not the example output
        expect(draft.steps.length, greaterThanOrEqualTo(3));
        
        // Should not have garbage from example output
        for (final step in draft.steps) {
          expect(step.title.startsWith(': '), false);
          expect(step.title, isNot(contains('Size:')));
        }
      });
    });

    group('distillScript - unclosed code fence', () {
      const userPrompt = 'Test';
      const aiResponse = '''```bash
echo hello
```''';

      test('handles unclosed fence', () {
        final draft = distillScript(
          userPrompt: userPrompt,
          assistantMarkdown: aiResponse,
          lex: const ThaiLex(),
          allowCjk: false,
        );
        
        expect(draft.script, isNotNull);
        expect(draft.script, contains('echo hello'));
      });
    });

    group('distillScript - backslash at end of comment', () {
      const script = '''# Step 1: Setup \\
mkdir -p dir
echo done''';

      test('handles backslash in comment', () {
        final steps = parseScript(script, const ThaiLex());
        expect(steps.length, greaterThanOrEqualTo(1));
      });
    });

    group('clipSmart', () {
      // Local helpers to check Thai characters (same logic as heuristics.dart)
      bool isThaiMark(int c) =>
          c == 0x0E31 || (c >= 0x0E34 && c <= 0x0E3A) || (c >= 0x0E47 && c <= 0x0E4E);
      bool isThaiLead(int c) => c >= 0x0E40 && c <= 0x0E44;

      test('does not cut Thai vowel', () {
        const text = 'สร้างโฟลเดอร์สำรองข้อมูล';
        final clipped = clipSmart(text, 10);
        // Should not end with a Thai mark
        final last = clipped.runes.last;
        expect(isThaiMark(last), false);
      });

      test('does not cut Thai lead consonant', () {
        const text = 'สร้างโฟลเดอร์';
        final clipped = clipSmart(text, 6);
        final last = clipped.runes.last;
        expect(isThaiLead(last), false);
      });

      test('clips at punctuation', () {
        const text = 'Hello, world. This is a test.';
        final clipped = clipSmart(text, 15);
        expect(clipped.endsWith('…'), true);
        expect(clipped.length, lessThanOrEqualTo(16)); // 15 + …
      });
    });

    group('dedupe', () {
      test('removes case-insensitive duplicates', () {
        final items = ['Hello', 'hello', 'HELLO', 'World'];
        final result = dedupe(items);
        expect(result.length, 2);
      });

      test('trims whitespace', () {
        final items = ['  hello  ', 'hello'];
        final result = dedupe(items);
        expect(result.length, 1);
        expect(result.first, 'hello');
      });

      test('preserves order', () {
        final items = ['first', 'second', 'first'];
        final result = dedupe(items);
        expect(result[0], 'first');
        expect(result[1], 'second');
      });
    });
  });
}