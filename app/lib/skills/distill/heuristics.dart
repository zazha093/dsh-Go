// app/lib/skills/distill/heuristics.dart
// Dart ล้วน: ไม่พึ่ง Flutter / I/O / เครือข่าย → ทดสอบได้ง่าย

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
      continue;
    }
    // Skip shell control flow keywords and usage commands
    if (_skipWords.contains(head)) continue;
    // Skip executable script invocations (./script.sh)
    if (_executableScript.hasMatch(t)) continue;
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
  return text.replaceAll(RegExp(r'[\u3400-\u4DBF\u4E00-\u9FFF\u3040-\u30FF\uAC00-\uD7AF]+'), '');
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
  const DistilledDraft(this.name, this.goal, this.steps, this.script);
  final String? name;
  final String? goal;
  final List<StepDraft> steps;
  final String? script; // เก็บเป็นไฟล์แนบ ไม่ใส่ในช่องข้อความ
}

DistilledDraft distillScript({
  required String userPrompt,
  required String assistantMarkdown,
  Lex lex = const ThaiLex(),
  bool allowCjk = false,
}) {
  final seg = splitFences(assistantMarkdown);
  final code = seg.blocks
      .where((b) => const {'bash', 'sh', 'shell', 'zsh', ''}.contains(b.lang.toLowerCase()))
      .map((b) => b.code)
      .join('\n');
  final steps = parseScript(code, lex, allowCjkLabels: allowCjk);
  final name = inferName(
      userPrompt: userPrompt, code: code, steps: steps, lex: lex, allowCjk: allowCjk);
  final goal = inferGoal(
      userPrompt: userPrompt, name: name ?? '', steps: steps, code: code, lex: lex, allowCjk: allowCjk);
  // Sanitize output
  final cleanSteps = _sanitizeSteps(steps, allowCjk);
  final cleanName = _sanitizeName(name, allowCjk);
  final cleanGoal = _sanitizeGoal(goal, allowCjk);
  return DistilledDraft(cleanName, cleanGoal, cleanSteps, code.isEmpty ? null : code);
}