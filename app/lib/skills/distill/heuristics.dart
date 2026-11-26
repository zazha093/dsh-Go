// app/lib/skills/distill/heuristics.dart
// Dart ล้วน: ไม่พึ่ง Flutter / I/O / เครือข่าย → ทดสอบได้ง่าย

import 'package:dsh_client/dsh_client.dart';

// ───────── 1) ชนิดตัวอักษร + ตัดข้อความไม่ให้ขาดกลางสระ/วรรณยุกต์ไทย ─────────
bool _isThai(int c) => c >= 0x0E00 && c <= 0x0E7F;
bool _isCjk(int c) =>
    (c >= 0x3400 && c <= 0x4DBF) ||
    (c >= 0x4E00 && c <= 0x9FFF) ||
    (c >= 0x3040 && c <= 0x30FF) ||
    (c >= 0xAC00 && c <= 0xD7AF);
bool _thaiMark(int c) =>
    c == 0x0E31 || (c >= 0x0E34 && c <= 0x0E3A) || (c >= 0x0E47 && c <= 0x0E4E);
bool _thaiLead(int c) => c >= 0x0E40 && c <= 0x0E44;

bool hasCjk(String s) => s.runes.any(_isCjk);
bool hasThai(String s) => s.runes.any(_isThai);

String clipSmart(String input, int max) {
  final s = input.trim();
  final r = s.runes.toList();
  if (r.length <= max) return s;
  var cut = max;
  final floor = (max * 0.7).floor();
  for (var i = max; i > floor; i--) {
    final c = r[i - 1];
    if (c == 0x0A || c == 0x20 || c == 0x2E || c == 0x2C || c == 0x3002 || c == 0xFF0C) {
      cut = i;
      break;
    }
  }
  while (cut > 1 && (_thaiMark(r[cut]) || _thaiLead(r[cut - 1]))) {
    cut--;
  }
  return '${String.fromCharCodes(r.sublist(0, cut)).trimRight()}…';
}

String normKey(String s) =>
    s.toLowerCase().replaceAll(RegExp(r'[\s\p{P}]+', unicode: true), '');

List<String> dedupe(Iterable<String> items) {
  final seen = <String>{};
  final out = <String>[];
  for (final i in items) {
    final k = normKey(i);
    if (k.isNotEmpty && seen.add(k)) out.add(i.trim());
  }
  return out;
}

// ───────── 2) แยกรั้วโค้ด / ร้อยแก้ว / ตาราง ─────────
const _fence = '\u0060\u0060\u0060';

class CodeBlock {
  const CodeBlock(this.lang, this.code);
  final String lang;
  final String code;
}

class Segments {
  Segments(this.prose, this.blocks);
  final String prose; // ไม่มีโค้ดและไม่มีตาราง
  final List<CodeBlock> blocks;
}

Segments splitFences(String md) {
  final prose = StringBuffer();
  final blocks = <CodeBlock>[];
  String? lang;
  final cur = StringBuffer();
  for (final line in md.split(RegExp(r'\r?\n'))) {
    final t = line.trimLeft();
    if (t.startsWith(_fence)) {
      if (lang == null) {
        lang = t.substring(3).trim();
        cur.clear();
      } else {
        blocks.add(CodeBlock(lang, cur.toString().trimRight()));
        lang = null;
      }
      continue;
    }
    if (lang != null) {
      cur.writeln(line);
    } else if (!t.startsWith('|')) {
      prose.writeln(line);
    }
  }
  if (lang != null) blocks.add(CodeBlock(lang, cur.toString().trimRight())); // รั้วไม่ครบคู่
  return Segments(prose.toString().trim(), blocks);
}

// ───────── 3) ภาษา (Lex) ─────────
enum StepKind { setup, action, verify, report }

class StepDraft {
  const StepDraft(this.kind, this.title, {this.command = '', this.detail = ''});
  final StepKind kind;
  final String title;
  final String command;
  final String detail;
}

abstract class Lex {
  String get setupVars;
  String get verifyNonEmpty;
  String get report;
  String get noSecrets;
  String excludesNote(List<String> ex);
  String get mustVerify;
  String get confirmDestructive;
  String get noOverwrite;
  String mkdir(String dir);
  String generic(String cmd, String arg);
  String tar({
    required bool create,
    required bool gzip,
    String? archive,
    String? source,
    List<String> excludes = const [],
  });
  String nameOf(String intent, String? object, String? format);
  String goalOf(String intent, String? object, String? format, String? dest, List<String> excludes);
  String describe(int steps, List<String> tools, String? output);
  // New methods for turn-based distillation
  String runScript(String file);
  String describeFromChat(int n);
  String describeFile(String file);
  String needsFile(String file);
}

class ThaiLex implements Lex {
  const ThaiLex();
  static const _intent = {
    'backup': 'สำรอง',
    'deploy': 'ปล่อยเวอร์ชัน',
    'clean': 'ล้าง',
    'install': 'ติดตั้ง',
    'build': 'บิลด์',
  };
  static const _object = {'project': 'โปรเจกต์'};
  static const _defaultObject = {
    'backup': 'ข้อมูล',
    'deploy': 'แอป',
    'clean': 'ไฟล์ชั่วคราว',
    'install': 'แพ็กเกจ',
    'build': 'โปรเจกต์',
  };

  @override
  String get setupVars => 'ตั้งค่าตัวแปรและค่าเริ่มต้น';
  @override
  String get verifyNonEmpty => 'ตรวจว่าไฟล์ผลลัพธ์มีขนาดมากกว่า 0 ไบต์';
  @override
  String get report => 'แสดงสถานะ/เส้นทางไฟล์ที่ได้';
  @override
  String mkdir(String dir) => dir.isEmpty
      ? 'สร้างโฟลเดอร์ (ถ้ายังไม่มี)'
      : 'สร้างโฟลเดอร์ ${clipSmart(dir, 50)} (ถ้ายังไม่มี)';
  @override
  String generic(String cmd, String arg) =>
      arg.isEmpty ? cmd : '$cmd ${clipSmart(arg, 50)}';
  @override
  String tar({
    required bool create,
    required bool gzip,
    String? archive,
    String? source,
    List<String> excludes = const [],
  }) {
    final b = StringBuffer(create ? 'สร้างไฟล์บีบอัด' : 'แตกไฟล์');
    if (archive != null) b.write(' ${clipSmart(archive, 60)}');
    if (create && gzip) b.write(' (tar.gz)');
    if (create && source != null) {
      final src = source == '.' ? 'โฟลเดอร์ปัจจุบัน' : clipSmart(source, 40);
      b.write(' จาก $src');
    }
    if (excludes.isNotEmpty) b.write(' โดยไม่รวม ${excludes.join(', ')}');
    return b.toString();
  }

  @override
  String nameOf(String intent, String? object, String? format) {
    final i = _intent[intent] ?? '';
    final o = object != null
        ? (_object[object] ?? _defaultObject[intent] ?? '')
        : (_defaultObject[intent] ?? '');
    final f = format != null ? 'เป็น $format' : '';
    return '$i$o$f';
  }

  @override
  String get noSecrets => 'ห้ามเก็บความลับ (API key, token, รหัสผ่าน)';

  @override
  String excludesNote(List<String> ex) => 'ไม่รวม ${ex.join(', ')}';

  @override
  String get mustVerify => 'ต้องตรวจว่าไฟล์ผลลัพธ์ไม่ว่างก่อนถือว่าสำเร็จ';

  @override
  String get confirmDestructive => 'ต้องได้รับอนุมัติก่อนรันคำสั่งที่ลบหรือแก้ไขไฟล์';

  @override
  String get noOverwrite => 'ชื่อไฟล์มีวันเวลา จึงไม่เขียนทับไฟล์เดิม';

  @override
  String goalOf(String intent, String? object, String? format, String? dest, List<String> excludes) {
    final b = StringBuffer(nameOf(intent, object, format));
    if (dest != null && dest.isNotEmpty) b.write(' ไปที่ $dest');
    if (excludes.isNotEmpty) b.write(' โดยไม่รวม ${excludes.join(', ')}');
    return b.toString();
  }

  @override
  String describe(int steps, List<String> tools, String? output) {
    final b = StringBuffer('สคริปต์ $steps ขั้นตอน');
    if (tools.isNotEmpty) b.write(' ใช้ ${tools.join(', ')}');
    if (output != null) b.write(' ไฟล์ผลลัพธ์ชื่อ $output');
    return b.toString();
  }

  @override
  String runScript(String file) => 'รันสคริปต์ ${clipSmart(file, 60)}';

  @override
  String describeFromChat(int n) => 'สรุปจากคำอธิบายในแชท $n ขั้นตอน';

  @override
  String describeFile(String file) => 'สคริปต์ ${clipSmart(file, 60)} ที่อยู่ในเครื่อง';

  @override
  String needsFile(String file) => 'ต้องมีไฟล์ ${clipSmart(file, 60)} อยู่ในโฟลเดอร์ที่รัน';
}

// ───────── 4) แยกคำแบบ shell + ต่อบรรทัด ─────────
final _trailingBackslashes = RegExp(r'\\+$');
final _trailingOperator = RegExp(r'(?:\|\||&&|\|)\s*$');

List<String> joinContinuations(String code) {
  final out = <String>[];
  final buf = StringBuffer();
  for (final raw in code.split(RegExp(r'\r?\n'))) {
    final line = raw.trimRight();
    final isComment = buf.isEmpty && line.trimLeft().startsWith('#');
    final bs = isComment ? null : _trailingBackslashes.firstMatch(line);
    final cont = bs != null && bs.group(0)!.length.isOdd;
    final text = cont ? line.substring(0, line.length - 1) : line;
    if (buf.isEmpty) {
      buf.write(text);
    } else {
      buf.write(' ');
      buf.write(text.trimLeft());
    }
    if (cont || (!isComment && _trailingOperator.hasMatch(line))) continue;
    out.add(buf.toString());
    buf.clear();
  }
  if (buf.isNotEmpty) out.add(buf.toString());
  return out;
}

List<String> shellWords(String line) {
  final words = <String>[];
  final cur = StringBuffer();
  String? quote;
  var inWord = false;
  for (var i = 0; i < line.length; i++) {
    final ch = line[i];
    if (quote != null) {
      if (ch == quote) {
        quote = null;
      } else if (ch == '\\' && quote == '"' && i + 1 < line.length) {
        cur.write(line[++i]);
      } else {
        cur.write(ch);
      }
      continue;
    }
    if (ch == '"' || ch == "'") {
      quote = ch;
      inWord = true;
      continue;
    }
    if (ch == '\\' && i + 1 < line.length) {
      cur.write(line[++i]);
      inWord = true;
      continue;
    }
    if (ch == '#' && !inWord) break;
    if (ch == ' ' || ch == '\t') {
      if (inWord) {
        words.add(cur.toString());
        cur.clear();
        inWord = false;
      }
      continue;
    }
    cur.write(ch);
    inWord = true;
  }
  if (inWord) words.add(cur.toString());
  return words;
}

// ───────── 4b) ตัวแปรในสคริปต์ → Map ─────────
Map<String, String> parseAssignments(String lines) {
  final out = <String, String>{};
  for (final line in joinContinuations(lines)) {
    final t = line
        .trim()
        .replaceFirst(RegExp(r'^(?:export|readonly|local|declare)\s+'), '');
    final m = RegExp(r'^([A-Za-z_][A-Za-z0-9_]*)=(.*)$').firstMatch(t);
    if (m == null) continue;
    final words = shellWords(m.group(2)!);
    out[m.group(1)!] = words.isEmpty ? '' : words.first;
  }
  return out;
}

Map<String, String> varsOf(String code) {
  final lines = joinContinuations(code).where((l) {
    final w = shellWords(l.trim());
    return w.isNotEmpty && (_assign.hasMatch(w.first) || _setupWords.contains(w.first));
  });
  return parseAssignments(lines.join('\n'));
}

final _dateSub = RegExp(r'\$\(\s*date[^)]*\)');
final _varRef = RegExp(
    r'\$\{([A-Za-z_][A-Za-z0-9_]*)(?::?[-=][^}]*)?\}|\$([A-Za-z_][A-Za-z0-9_]*)');

String expandVars(String s, Map<String, String> vars,
    {String dateLabel = '‹วันเวลา›'}) {
  var out = s.replaceAll(_dateSub, dateLabel);
  for (var i = 0; i < 4; i++) {
    final next = out.replaceAllMapped(_varRef, (m) {
      final name = m.group(1) ?? m.group(2)!;
      if (name == 'HOME') return '~';
      return vars[name] ?? '‹$name›';
    });
    if (next == out) break;
    out = next;
  }
  return out;
}

// ───────── 4c) ฟังก์ชันช่วยเหลือเพิ่มเติม ─────────

// เลือกบล็อกสคริปต์หลักจากหลาย code blocks
const _shellLangs = {'bash', 'sh', 'shell', 'zsh'};
const _knownCmds = {
  'tar', 'mkdir', 'cp', 'mv', 'rm', 'cd', 'ls', 'cat', 'echo', 'printf', 'git',
  'curl', 'wget', 'find', 'grep', 'sed', 'awk', 'chmod', 'chown', 'zip', 'unzip',
  'stat', 'du', 'wc', 'date', 'basename', 'dirname', 'pwd', 'npm', 'pnpm', 'yarn',
  'pip', 'python', 'python3', 'node', 'docker', 'ssh', 'scp', 'rsync', 'export', 'set',
};

bool looksLikeShell(String code) {
  final lines = code
      .split(RegExp(r'\r?\n'))
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty)
      .toList();
  if (lines.isEmpty) return false;
  if (lines.first.startsWith('#!')) return true;
  var cmd = 0;
  var other = 0;
  for (final l in lines) {
    if (l.startsWith('#')) continue;
    final head = l.split(RegExp(r'\s+')).first;
    final ok = _knownCmds.contains(head) ||
        _assign.hasMatch(head) ||
        head.startsWith('./') ||
        head.startsWith('~/');
    if (ok) {
      cmd++;
    } else {
      other++;
    }
  }
  return cmd > 0 && cmd >= other * 2;
}

CodeBlock? pickMainScript(List<CodeBlock> blocks) {
  final cands = blocks.where((b) {
    final l = b.lang.toLowerCase();
    return _shellLangs.contains(l) || (l.isEmpty && looksLikeShell(b.code));
  }).toList();
  if (cands.isEmpty) return null;
  final withShebang =
      cands.where((b) => b.code.trimLeft().startsWith('#!')).toList();
  final pool = withShebang.isNotEmpty ? withShebang : cands;
  pool.sort((a, b) => b.code.length.compareTo(a.code.length));
  return pool.first;
}

// หาโฟลเดอร์ปลายทางจาก mkdir
String? destDir(String code, Map<String, String> vars) {
  for (final line in joinContinuations(code)) {
    final w = shellWords(line.trim());
    if (w.isNotEmpty && w.first == 'mkdir') {
      final a = _firstArg(w);
      if (a.isNotEmpty) return expandVars(a, vars);
    }
  }
  return null;
}

// รวบรวมรายการ --exclude
List<String> collectExcludes(String code) {
  final out = <String>[];
  for (final line in joinContinuations(code)) {
    final w = shellWords(line.trim());
    if (w.isEmpty || w.first != 'tar') continue;
    for (var i = 1; i < w.length; i++) {
      if (w[i].startsWith('--exclude=')) {
        out.add(w[i].substring(10));
      } else if (w[i] == '--exclude' && i + 1 < w.length) {
        out.add(w[++i]);
      }
    }
  }
  return dedupe(out);
}

// แปลง archive pattern
String? archivePattern(Map<String, String> vars) {
  for (final v in vars.values) {
    final e = expandVars(v, vars);
    if (RegExp(r'\.(tar\.gz|tgz|zip|tar\.xz|7z)$').hasMatch(e)) {
      return e.split('/').last;
    }
  }
  return null;
}

// ดึงชื่อเครื่องมือจากสคริปต์
final _notTools = {
  'cd', 'echo', 'printf', 'export', 'set', 'local', 'readonly', 'declare', 'shopt',
  'umask', 'test', 'true', 'false', 'exit', 'return', 'trap', 'source', 'read',
  'if', 'then', 'else', 'elif', 'fi', 'for', 'while', 'do', 'done', 'case', 'esac',
  'function',
};
const _skipHeads = {'!', 'if', 'then', 'elif', 'else', 'while', 'do'};
final _toolName = RegExp(r'^[a-z][a-z0-9._+-]*$');
final _cmdSub = RegExp(r'\$\(\s*([A-Za-z][A-Za-z0-9._+-]*)');

List<String> toolsOf(String code) {
  final out = <String>{};
  final first = code.trimLeft();
  if (first.startsWith('#!') && first.split(RegExp(r'\r?\n')).first.contains('bash')) {
    out.add('bash');
  }
  for (final line in joinContinuations(code)) {
    final t = line.trim();
    if (t.isEmpty || t.startsWith('#')) continue;
    for (final m in _cmdSub.allMatches(t)) {
      out.add(m.group(1)!);
    }
    for (final part in t.split(RegExp(r'\|\||&&|\||;'))) {
      final w = shellWords(part.trim());
      var i = 0;
      while (i < w.length && (_assign.hasMatch(w[i]) || _skipHeads.contains(w[i]))) {
        i++;
      }
      if (i < w.length) out.add(w[i]);
    }
  }
  return out
      .where((n) => _toolName.hasMatch(n) && n.length >= 2 && !_notTools.contains(n))
      .toList()
    ..sort();
}

// ตรวจจับคำสั่งทำลายข้อมูล
final _destructive = RegExp(
    r'(?:^|[\s;&|])(?:rm|mv|dd|shred|truncate)\s|chmod\s+-R|git\s+reset\s+--hard|git\s+clean');

// ───────── 5) คอมเมนต์ → ป้ายขั้นตอน (หลายภาษา) ─────────
final _commentBody = RegExp(
  r'^#+\s*(?:(?:step|stage|phase|ขั้น(?:ตอน)?(?:ที่)?|步驟|步骤)\s*\d*|第\s*\d+\s*步|\d+)?\s*[:：.、)\-–—]*\s*(.+)$',
  caseSensitive: false,
);
final _decor = RegExp(r'^[-=_*#~\s]+$');
final _directive = RegExp(r'^(shellcheck|shfmt|-\*-)', caseSensitive: false);

String? commentLabel(String line, {bool allowCjk = false}) {
  final m = _commentBody.firstMatch(line.trim());
  if (m == null) return null;
  final body = m.group(1)!.trim();
  if (_decor.hasMatch(body) || _directive.hasMatch(body)) return null;
  if (!allowCjk && hasCjk(body)) return null;
  if (body.runes.length < 6) return null;
  return clipSmart(body, 80);
}

// ───────── 6) ตารางคำสั่ง (เพิ่มความสามารถ = เพิ่มรายการ) ─────────
typedef Describer = String Function(List<String> words, Lex lex);

String _firstArg(List<String> w) =>
    w.skip(1).firstWhere((e) => !e.startsWith('-'), orElse: () => '');

String _describeTar(List<String> w, Lex lex) {
  final excludes = <String>[];
  final rest = <String>[];
  var flags = '';
  for (var i = 1; i < w.length; i++) {
    final t = w[i];
    if (t.startsWith('--exclude=')) {
      // Handle --exclude=foo, --exclude="foo", --exclude='foo', --exclude={a,b,c}
      var excl = t.substring('--exclude='.length);
      excl = excl.trim();
      if (excl.startsWith('{') && excl.endsWith('}')) {
        // --exclude={a,b,c} format
        excl = excl.substring(1, excl.length - 1);
        for (final part in excl.split(',')) {
          excludes.add(part.trim());
        }
      } else {
        // Remove quotes if present
        if ((excl.startsWith('"') && excl.endsWith('"')) ||
            (excl.startsWith("'") && excl.endsWith("'"))) {
          excl = excl.substring(1, excl.length - 1);
        }
        excludes.add(excl);
      }
    } else if (t == '--exclude' && i + 1 < w.length) {
      var excl = w[++i].trim();
      if ((excl.startsWith('"') && excl.endsWith('"')) ||
          (excl.startsWith("'") && excl.endsWith("'"))) {
        excl = excl.substring(1, excl.length - 1);
      }
      excludes.add(excl);
    } else if (t == '-C' && i + 1 < w.length) {
      i++;
    } else if (t.startsWith('--')) {
      continue;
    } else if (t.startsWith('-') || (i == 1 && RegExp(r'^[A-Za-z]+$').hasMatch(t))) {
      flags += t.replaceAll('-', '');
    } else {
      rest.add(t);
    }
  }
  final hasF = flags.contains('f');
  return lex.tar(
    create: flags.contains('c'),
    gzip: flags.contains('z') ||
        (rest.isNotEmpty && RegExp(r'\.(tar\.gz|tgz)$').hasMatch(rest.first)),
    archive: hasF && rest.isNotEmpty ? rest.first : null,
    source: hasF && rest.length > 1 ? rest[1] : null,
    excludes: excludes,
  );
}

final Map<String, Describer> describers = {
  'tar': _describeTar,
  'mkdir': (w, lex) => lex.mkdir(_firstArg(w)),
  // เพิ่ม: 'cp', 'mv', 'rm', 'curl', 'git', ... ตาม pattern เดียวกัน
};

// ───────── 7) แยกขั้นตอนจากสคริปต์ ─────────
final _assign = RegExp(r'^[A-Za-z_][A-Za-z0-9_]*=');
const _setupWords = {'export', 'set', 'local', 'readonly', 'declare', 'shopt', 'umask'};
const _skipWords = {
  'then', 'else', 'elif', 'fi', 'do', 'done', 'esac', '{', '}', 'exit', 'return', 'trap',
  'if', 'chmod', 'source', '.',
};
final _sizeCheck = RegExp(r'(?:\s-s\s|\bstat\s|\bwc\s+-c\b|-gt\s+0\b)');
final _ifFileCheck = RegExp(r'^if\s+\[\[?\s+-f\s');
final _executableScript = RegExp(r'^\./[\w\-/.]+\.sh\b');

List<StepDraft> parseScript(String code, Lex lex, {bool allowCjkLabels = false}) {
  final steps = <StepDraft>[];
  final setup = <String>[];
  String? label;
  var verified = false;
  var reported = false;
  var inIfBlock = false;

  for (final line in joinContinuations(code)) {
    final t = line.trim();
    if (t.isEmpty) {
      label = null;
      continue;
    }
    if (t.startsWith('#!')) continue;
    if (t.startsWith('#')) {
      final l = commentLabel(t, allowCjk: allowCjkLabels);
      if (l != null) label = l;
      continue;
    }
    if (_sizeCheck.hasMatch(t)) {
      if (!verified) {
        steps.add(StepDraft(StepKind.verify, label ?? lex.verifyNonEmpty, command: t));
        verified = true;
        label = null;
      }
      continue;
    }
    final w = shellWords(t);
    if (w.isEmpty) continue;
    final head = w.first;
    // Handle if-file-check blocks as a single verify step BEFORE skipWords check
    if (_ifFileCheck.hasMatch(t)) {
      if (!verified) {
        steps.add(StepDraft(StepKind.verify, lex.verifyNonEmpty, command: t));
        verified = true;
        label = null;
      }
      inIfBlock = true;
      continue;
    }
    // Skip shell control flow keywords and usage commands
    if (_skipWords.contains(head)) continue;
    // Skip executable script invocations (./script.sh)
    if (_executableScript.hasMatch(t)) continue;
    // Track if-block boundaries
    if (head == 'if') {
      inIfBlock = true;
      continue;
    }
    if (head == 'fi') {
      inIfBlock = false;
      continue;
    }
    // Skip everything inside if-blocks
    if (inIfBlock) continue;
    if (_assign.hasMatch(head) || _setupWords.contains(head)) {
      setup.add(t);
      continue;
    }
    if (head == 'echo' || head == 'printf') {
      reported = true;
      continue;
    }
    final d = describers[head];
    final desc = d != null ? d(w, lex) : lex.generic(head, _firstArg(w));
    steps.add(StepDraft(StepKind.action, label ?? desc,
        command: t, detail: label == null ? '' : desc));
    label = null;
  }
  if (setup.isNotEmpty) {
    steps.insert(0, StepDraft(StepKind.setup, lex.setupVars, command: setup.join('\n')));
  }
  if (reported) steps.add(StepDraft(StepKind.report, lex.report));
  return steps;
}

// ───────── 8) เจตนา / ชื่อ / เป้าหมาย ─────────
const _intentWords = <String, List<String>>{
  'backup': ['backup', 'back up', 'สำรอง', 'แบ็คอัพ', 'แบคอัพ', '備份', '备份'],
  'deploy': ['deploy', 'ดีพลอย', 'ปล่อยเวอร์ชัน', '部署', '發佈', '发布'],
  'clean': ['cleanup', 'clean up', 'ทำความสะอาด', 'ล้าง', '清理', '清除'],
  'install': ['install', 'ติดตั้ง', '安裝', '安装'],
  'build': ['build', 'compile', 'บิลด์', 'บิ้ว', '編譯', '编译', '構建', '构建'],
};
const _objectWords = <String, List<String>>{
  'project': ['project', 'โปรเจกต์', 'โปรเจ็กต์', 'โปรเจค', '專案', '专案', '项目', '項目'],
};

String? detectKey(String text, Map<String, List<String>> table) {
  final t = text.toLowerCase();
  String? best;
  var bestPos = 1 << 30;
  for (final e in table.entries) {
    for (final w in e.value) {
      final p = t.indexOf(w.toLowerCase());
      if (p >= 0 && p < bestPos) {
        best = e.key;
        bestPos = p;
      }
    }
  }
  return best;
}

final _prefixes = <RegExp>[
  RegExp(r'^(?:ช่วย|รบกวน|กรุณา|ขอ|อยากให้|อยาก|ต้องการให้|ต้องการ)(?=\s|ให้|สร้าง|เขียน|ทำ)\s*(?:ให้|หน่อย)?\s*'),
  RegExp(r'^(?:สร้าง|เขียน)\s*|^ทำ(?=\s|[A-Za-z])\s*'),
  RegExp(r'^(?:please\s+|can you\s+|could you\s+|help me\s+|i (?:want|need) (?:you )?to\s+)+', caseSensitive: false),
  RegExp(r'^(?:write|create|make|build|generate)\s+(?:me\s+)?(?:a|an|the)?\s*', caseSensitive: false),
  RegExp(r'^(?:請|请)?(?:幫我|帮我|替我|麻煩|麻烦)?(?:寫|写|建立|创建|創建|製作|制作|做)(?:一個|一个|個|个)?'),
  RegExp(r'^(?:bash|shell|sh|python)?\s*(?:script|สคริปต์|脚本|腳本)\s*', caseSensitive: false),
];

String stripIntentPrefix(String s) {
  var t = s.trim();
  for (var pass = 0; pass < 3; pass++) {
    final before = t;
    for (final re in _prefixes) {
      t = t.replaceFirst(re, '').trimLeft();
    }
    if (t == before) break;
  }
  return t;
}

String firstClause(String s) {
  final m = RegExp(r'[,，、;；\n]|\s(?:ชื่อ|โดย|พร้อม|แล้ว|named|with|that|which)\s').firstMatch(s);
  return (m == null ? s : s.substring(0, m.start)).trim();
}

const _generic = {
  'script', 'code', 'bash', 'shell', 'sh', 'result', 'output', 'answer', 'summary',
  'here', 'example', 'สคริปต์', 'โค้ด', 'ตัวอย่าง', 'ผลลัพธ์', '脚本', '腳本', '代码', '代碼',
};

bool isGenericName(String s) {
  final n = s
      .toLowerCase()
      .replaceAll(RegExp(r'[^\p{L}\p{M}\p{N}]+', unicode: true), ' ')
      .trim();
  if (n.runes.length < 4) return true;
  return n.split(' ').every(_generic.contains);
}

String? inferName({
  required String userPrompt,
  required String code,
  required List<StepDraft> steps,
  required Lex lex,
  bool allowCjk = false,
}) {
  final intent = detectKey(userPrompt, _intentWords) ?? detectKey(code, _intentWords);
  if (intent != null) {
    final object = detectKey(userPrompt, _objectWords) ?? detectKey(code, _objectWords);
    final fmt = RegExp(r'\.(tar\.gz|tgz|zip|tar\.xz|7z)\b').firstMatch(code)?.group(1);
    final n = lex.nameOf(intent, object, fmt);
    if (!isGenericName(n)) return clipSmart(n, 60);
  }
  final clause = clipSmart(firstClause(stripIntentPrefix(userPrompt)), 60);
  if (clause.isNotEmpty && !isGenericName(clause) && (allowCjk || !hasCjk(clause))) {
    return clause;
  }
  for (final s in steps) {
    if (s.kind == StepKind.action && !isGenericName(s.title)) return clipSmart(s.title, 60);
  }
  return null; // ว่างดีกว่าขยะ
}

String? inferGoal({
  required String userPrompt,
  required String name,
  required List<StepDraft> steps,
  required String code,
  required Lex lex,
  bool allowCjk = false,
}) {
  // Infer goal from script intent (not from user prompt or step titles)
  final intent = detectKey(userPrompt, _intentWords) ?? detectKey(code, _intentWords);
  if (intent != null) {
    final object = detectKey(userPrompt, _objectWords) ?? detectKey(code, _objectWords);
    final fmt = RegExp(r'\.(tar\.gz|tgz|zip|tar\.xz|7z)\b').firstMatch(code)?.group(1);
    final goal = lex.nameOf(intent, object, fmt);
    if (!isGenericName(goal) && normKey(goal) != normKey(name)) {
      return clipSmart(goal, 300);
    }
  }
  // Fallback: use cleaned user prompt (without intent prefix)
  final g = clipSmart(stripIntentPrefix(userPrompt), 300);
  if (g.isNotEmpty && normKey(g) != normKey(name) && (allowCjk || !hasCjk(g))) return g;
  // Last resort: join action step titles (ensure different from name)
  final titles =
      steps.where((s) => s.kind == StepKind.action).map((s) => s.title).take(3).toList();
  final joined = titles.isEmpty ? null : titles.join(' → ');
  if (joined != null && normKey(joined) != normKey(name)) return joined;
  return null;
}

// ───────── 9) ทำความสะอาดข้อความก่อนคืนค่า (กรอง CJK, ตัด step ว่าง) ─────────
String _sanitizeText(String text, bool allowCjk) {
  if (allowCjk) return text;
  // Remove CJK characters
  var result = text.replaceAll(RegExp(r'[\u3400-\u4DBF\u4E00-\u9FFF\u3040-\u30FF\uAC00-\uD7AF]+'), '');
  // Remove emojis (match any character outside ASCII printable + Thai + common punctuation)
  // Emojis are typically in higher Unicode planes, match non-ASCII printable that aren't Thai/CJK
  result = result.replaceAll(RegExp(r'[^\x20-\x7E\u0E00-\u0E7F\u00A0-\u00FF\u2000-\u206F\u3000-\u303F]+'), '');
  return result;
}

List<StepDraft> _sanitizeSteps(List<StepDraft> steps, bool allowCjk) {
  if (allowCjk) return steps;
  final sanitized = <StepDraft>[];
  for (final step in steps) {
    final cleanTitle = _sanitizeText(step.title, false);
    final cleanDetail = _sanitizeText(step.detail, false);
    final cleanCommand = _sanitizeText(step.command, false);
    // Skip step if title becomes empty or only prefix remains
    if (cleanTitle.trim().isEmpty) continue;
    // Skip if title is just generic prefix
    if (cleanTitle.trim() == 'รันคำสั่ง' || cleanTitle.trim() == 'Run command') continue;
    sanitized.add(StepDraft(step.kind, cleanTitle,
        command: cleanCommand, detail: cleanDetail));
  }
  return sanitized;
}

String? _sanitizeGoal(String? goal, bool allowCjk) {
  if (goal == null) return null;
  return _sanitizeText(goal, allowCjk);
}

String? _sanitizeName(String? name, bool allowCjk) {
  if (name == null) return null;
  return _sanitizeText(name, allowCjk);
}

class DistilledDraft {
  const DistilledDraft({
    this.name,
    this.goal,
    this.description,
    this.steps = const [],
    this.constraints = const [],
    this.tools = const [],
    this.script,
  });
  final String? name;
  final String? goal;
  final String? description;
  final List<StepDraft> steps;
  final List<String> constraints;
  final List<String> tools;
  final String? script; // เก็บเป็นไฟล์แนบ ไม่ใส่ในช่องข้อความ
}

DistilledDraft distillScript({
  required String userPrompt,
  required String assistantMarkdown,
  Lex lex = const ThaiLex(),
  bool allowCjk = false,
}) {
  final seg = splitFences(assistantMarkdown);
  
  // ─── 1) เลือกบล็อกสคริปต์หลัก ───────────────────────────────────────
  final scriptBlock = pickMainScript(seg.blocks);
  final code = scriptBlock?.code ?? '';
  
  // ─── 2) แยกตัวแปร ───────────────────────────────────────────────────
  final vars = varsOf(code);
  
  // ─── 3) แยกขั้นตอนจากสคริปต์ ───────────────────────────────────────
  final rawSteps = parseScript(code, lex, allowCjkLabels: allowCjk);
  
  // ─── 4) ขยายตัวแปรในชื่อขั้นตอนและรายละเอียด ────────────────────────
  final expandedSteps = <StepDraft>[];
  for (final s in rawSteps) {
    final title = expandVars(s.title, vars);
    // Skip if title becomes empty or only prefix remains
    if (title.trim().isEmpty) continue;
    // Skip if title is just generic prefix
    if (title.trim() == 'รันคำสั่ง' || title.trim() == 'Run command') continue;
    expandedSteps.add(StepDraft(
      s.kind,
      title,
      command: s.command,
      detail: expandVars(s.detail, vars),
    ));
  }
  
  // ─── 5) กรองขั้นตอนที่ไม่มีความหมาย / ซ้ำ ───────────────────────────
  final steps = _sanitizeSteps(expandedSteps, allowCjk);
  
  // ─── 6) ชื่อสกิล ───────────────────────────────────────────────────
  final name = inferName(
      userPrompt: userPrompt, code: code, steps: steps, lex: lex, allowCjk: allowCjk);
  
  // ─── 7) เป้าหมาย ───────────────────────────────────────────────────
  final intent = detectKey(userPrompt, _intentWords) ?? detectKey(code, _intentWords);
  final object = detectKey(userPrompt, _objectWords) ?? detectKey(code, _objectWords);
  final fmt = RegExp(r'\.(tar\.gz|tgz|zip|tar\.xz|7z)\b').firstMatch(code)?.group(1);
  final dest = destDir(code, vars);
  final excludes = collectExcludes(code);
  final goal = lex.goalOf(
      intent ?? '', object, fmt, dest, excludes);
  
  // ─── 8) คำอธิบาย ────────────────────────────────────────────────────
  final tools = toolsOf(code);
  final outputFile = archivePattern(vars);
  final description = steps.isEmpty
      ? null
      : lex.describe(steps.length, tools, outputFile);
  
  // ─── 9) ข้อจำกัด ────────────────────────────────────────────────────
  final constraints = <String>[];
  constraints.add(lex.noSecrets);
  final ex = excludes;
  if (ex.isNotEmpty) constraints.add(lex.excludesNote(ex));
  if (steps.any((s) => s.kind == StepKind.verify)) constraints.add(lex.mustVerify);
  if (_destructive.hasMatch(code)) constraints.add(lex.confirmDestructive);
  if (code.contains(r'$(date') && RegExp(r'\btar\b').hasMatch(code)) {
    constraints.add(lex.noOverwrite);
  }
  
  // ─── 10) เครื่องมือ ──────────────────────────────────────────────────
  final rawTools = toolsOf(code);
  
  // ─── 11) ทำความสะอาด ───────────────────────────────────────────────
  final cleanSteps = _sanitizeSteps(steps, allowCjk);
  final cleanName = _sanitizeName(name, allowCjk);
  final cleanGoal = _sanitizeGoal(goal, allowCjk);
  final cleanDescription = description != null ? _sanitizeText(description, allowCjk) : null;
  final cleanConstraints = constraints.map((c) => _sanitizeText(c, allowCjk)).toList();
  final cleanTools = rawTools.map((t) => _sanitizeText(t, allowCjk)).toList();
  
  return DistilledDraft(
    name: cleanName,
    goal: cleanGoal,
    description: cleanDescription,
    steps: cleanSteps,
    constraints: cleanConstraints,
    tools: cleanTools,
    script: code.isEmpty ? null : code,
  );
}

/// Turn-based distillation using full tool call arguments
DistilledDraft distillTurn({
  required String userPrompt,
  required String assistantMarkdown,
  required List<ToolCallInfo> toolCallsWithArgs,
  Lex lex = const ThaiLex(),
  bool allowCjk = false,
}) {
  final seg = splitFences(assistantMarkdown);
  
  // ─── 1) Collect scripts from tool calls (write tool) ──────────────────
  final writtenScripts = <ScriptFile>[];
  String? invokedScriptName;
  
  for (final call in toolCallsWithArgs) {
    if (call.name == 'write') {
      final path = _argStr(call.args, _pathKeys);
      final content = _argStr(call.args, _contentKeys);
      if (path != null && content != null) {
        if (_scriptPath.hasMatch(path) || content.trimLeft().startsWith('#!')) {
          writtenScripts.add(ScriptFile(path, content));
        }
      }
    } else if (call.name == 'bash') {
      final cmd = _argStr(call.args, _cmdKeys);
      if (cmd != null) {
        // Check if it's a script invocation like ./backup.sh
        final ref = scriptRef([cmd]);
        if (ref != null) invokedScriptName = ref;
      }
    }
  }
  
  // Sort by content length (largest first - likely the main script)
  writtenScripts.sort((a, b) => b.content.length.compareTo(a.content.length));
  
  String code = '';
  StepSource source = StepSource.none;
  
  // ─── 2) Choose source in priority order ──────────────────────────────
  if (writtenScripts.isNotEmpty) {
    // Priority 1: Written file from write tool
    final f = writtenScripts.first;
    code = f.content;
    source = StepSource.writtenFile;
  } else {
    // Priority 2: Inline script in message
    final inline = pickMainScript(seg.blocks);
    if (inline != null && invokedScript(inline.code) == null) {
      final steps = parseScript(inline.code, lex, allowCjkLabels: allowCjk);
      if (steps.isNotEmpty) {
        code = inline.code;
        source = StepSource.inlineScript;
      }
    }
    
    // Priority 3: Bullet list from prose
    if (code.isEmpty) {
      final bullets = bulletsFromProse(seg.prose, allowCjk: allowCjk);
      if (bullets.length >= 2) {
        source = StepSource.prose;
        // We'll create steps from bullets below
      }
    }
    
    // Priority 4: Invoked script name
    if (code.isEmpty && invokedScriptName != null) {
      source = StepSource.invocation;
    }
  }
  
  // ─── 3) Build steps based on source ──────────────────────────────────
  final steps = <StepDraft>[];
  final vars = varsOf(code);
  
  switch (source) {
    case StepSource.writtenFile:
    case StepSource.inlineScript:
      if (code.isNotEmpty) {
        final rawSteps = parseScript(code, lex, allowCjkLabels: allowCjk);
        for (final s in rawSteps) {
          final title = expandVars(s.title, vars);
          if (title.trim().isEmpty) continue;
          if (title.trim() == 'รันคำสั่ง' || title.trim() == 'Run command') continue;
          steps.add(StepDraft(
            s.kind,
            title,
            command: s.command,
            detail: expandVars(s.detail, vars),
          ));
        }
      }
      break;
    case StepSource.prose:
      final bullets = bulletsFromProse(seg.prose, allowCjk: allowCjk);
      for (final b in bullets) {
        steps.add(StepDraft(StepKind.action, b));
      }
      break;
    case StepSource.invocation:
      if (invokedScriptName != null) {
        steps.add(StepDraft(StepKind.action, lex.runScript(invokedScriptName), command: './$invokedScriptName'));
      }
      break;
    case StepSource.none:
      break;
  }
  
  // ─── 4) Sanitize steps ───────────────────────────────────────────────
  final cleanSteps = _sanitizeSteps(steps, allowCjk);
  
  // ─── 5) Name ─────────────────────────────────────────────────────────
  final name = inferName(
    userPrompt: userPrompt, code: code, steps: cleanSteps, lex: lex, allowCjk: allowCjk);
  
  // ─── 6) Goal ─────────────────────────────────────────────────────────
  final intent = detectKey(userPrompt, _intentWords) ?? detectKey(code, _intentWords);
  final object = detectKey(userPrompt, _objectWords) ?? detectKey(code, _objectWords);
  final fmt = RegExp(r'\.(tar\.gz|tgz|zip|tar\.xz|7z)\b').firstMatch(code)?.group(1);
  final dest = destDir(code, vars);
  final excludes = collectExcludes(code);
  String? goal;
  if (intent != null) {
    goal = lex.goalOf(intent, object, fmt, dest, excludes);
  } else {
    goal = _sanitizeGoal(clipSmart(stripIntentPrefix(userPrompt), 300), allowCjk);
  }
  
  // ─── 7) Description ──────────────────────────────────────────────────
  final toolNames = toolCallsWithArgs.map((c) => c.name).toSet().toList();
  final outputFile = archivePattern(vars);
  String? description;
  switch (source) {
    case StepSource.writtenFile:
    case StepSource.inlineScript:
      if (cleanSteps.isNotEmpty) {
        description = lex.describe(cleanSteps.length, toolNames, outputFile);
      }
      break;
    case StepSource.prose:
      description = lex.describeFromChat(cleanSteps.length);
      break;
    case StepSource.invocation:
      description = lex.describeFile(invokedScriptName ?? '');
      break;
    case StepSource.none:
      break;
  }
  
  // ─── 8) Constraints ──────────────────────────────────────────────────
  final constraints = <String>[];
  constraints.add(lex.noSecrets);
  final ex = excludes;
  if (ex.isNotEmpty) constraints.add(lex.excludesNote(ex));
  if (cleanSteps.any((s) => s.kind == StepKind.verify)) constraints.add(lex.mustVerify);
  if (_destructive.hasMatch(code)) constraints.add(lex.confirmDestructive);
  if (code.contains(r'$(date') && RegExp(r'\btar\b').hasMatch(code)) {
    constraints.add(lex.noOverwrite);
  }
  if (source == StepSource.invocation && invokedScriptName != null) {
    constraints.add(lex.needsFile(invokedScriptName));
  }
  
  // ─── 9) Tools ────────────────────────────────────────────────────────
  final rawTools = code.isEmpty ? toolNames : toolsOf(code);
  final allTools = rawTools.toSet().union(toolNames.toSet()).toList();
  
  // ─── 10) Sanitize output ─────────────────────────────────────────────
  final cleanName = _sanitizeName(name, allowCjk);
  final cleanGoal = _sanitizeGoal(goal, allowCjk);
  final cleanDescription = description != null ? _sanitizeText(description, allowCjk) : null;
  final cleanConstraints = constraints.map((c) => _sanitizeText(c, allowCjk)).toList();
  final cleanTools = allTools.map((t) => _sanitizeText(t, allowCjk)).toList();
  
  return DistilledDraft(
    name: cleanName,
    goal: cleanGoal,
    description: cleanDescription,
    steps: cleanSteps,
    constraints: cleanConstraints,
    tools: cleanTools,
    script: code.isEmpty ? null : code,
  );
}

// ─── G) Helper classes for turn-based distillation ──────────────────────

enum StepSource { inlineScript, writtenFile, prose, invocation, none }

class ScriptFile {
  const ScriptFile(this.path, this.content);
  final String path;
  final String content;
}

const _pathKeys = ['path', 'file_path', 'filePath', 'filename'];
const _contentKeys = ['content', 'file_text', 'text', 'contents'];
const _cmdKeys = ['command', 'cmd', 'script'];
final _scriptPath = RegExp(r'\.(?:sh|bash|zsh)$');

String? _argStr(Map<String, dynamic> a, List<String> keys) {
  for (final k in keys) {
    final v = a[k];
    if (v is String && v.trim().isNotEmpty) return v;
  }
  return null;
}

List<ScriptFile> scriptsFromCalls(List<ToolCallInfo> calls) {
  final out = <ScriptFile>[];
  for (final c in calls) {
    if (c.name != 'write') continue;
    final p = _argStr(c.args, _pathKeys);
    final body = _argStr(c.args, _contentKeys);
    if (p == null || body == null) continue;
    if (_scriptPath.hasMatch(p) || body.trimLeft().startsWith('#!')) {
      out.add(ScriptFile(p, body));
    }
  }
  return out;
}

List<String> commandsFromCalls(List<ToolCallInfo> calls) {
  final out = <String>[];
  for (final c in calls) {
    if (c.name != 'bash') continue;
    final s = _argStr(c.args, _cmdKeys);
    if (s != null) out.add(s);
  }
  return out;
}

final _bullet = RegExp(r'^\s*(?:[-*•·]|\d+[.)])\s+(.+)$');
final _leadingSymbols = RegExp(r'^[^\p{L}\p{N}]+', unicode: true);

List<String> bulletsFromProse(String prose, {bool allowCjk = false}) {
  final out = <String>[];
  for (final line in prose.split(RegExp(r'\r?\n'))) {
    final m = _bullet.firstMatch(line);
    if (m == null) continue;
    var t = m.group(1)!.replaceAll(RegExp(r'[*_`]+'), '').trim();
    t = t.replaceFirst(_leadingSymbols, '');
    t = t.replaceFirst(RegExp(r'[:：\s]+$'), '');
    if (!isMeaningfulText(t, allowCjk: allowCjk)) continue;
    out.add(clipSmart(t, 120));
    if (out.length >= 8) break;
  }
  return dedupe(out);
}

final _scriptRef = RegExp(r'((?:\./|~/|/)?[\w.\-/]+\.(?:sh|bash|zsh))\b');

String? scriptRef(Iterable<String> texts) {
  for (final t in texts) {
    final m = _scriptRef.firstMatch(t);
    if (m != null) return m.group(1);
  }
  return null;
}

String? invokedScript(String code) {
  final lines = code
      .split(RegExp(r'\r?\n'))
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty && !l.startsWith('#'))
      .toList();
  if (lines.length != 1) return null;
  return scriptRef([lines.first]);
}

bool isMeaningfulText(String t, {bool allowCjk = false}) {
  if (t.trim().isEmpty) return false;
  if (t.trim() == 'รันคำสั่ง' || t.trim() == 'Run command') return false;
  if (!allowCjk && hasCjk(t)) return false;
  return true;
}

/// Add to abstract class Lex:
///   String runScript(String file);        // Thai: 'รันสคริปต์ $file'
///   String describeFromChat(int n);       // Thai: 'สรุปจากคำอธิบายในแชท $n ขั้นตอน'
///   String describeFile(String file);     // Thai: 'สคริปต์ $file ที่อยู่ในเครื่อง'
///   String needsFile(String file);        // Thai: 'ต้องมีไฟล์ $file อยู่ในโฟลเดอร์ที่รัน'