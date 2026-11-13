#!/usr/bin/env python3
"""
Build ledger.json from literals.json with AGGRESSIVE auto-skip rules.
Target: reduce todo to 2,000-5,000 by filtering out technical/non-UI strings.
"""

import json
import re
import sys
from pathlib import Path
from typing import Set
from dataclasses import dataclass, asdict


@dataclass
class LedgerEntry:
    id: str
    layer: str
    file: str
    line: int
    text: str
    context: str
    kind: str
    status: str  # "skip" or "todo"


# UI text whitelist - single words that ARE user-facing
UI_WHITELIST = {
    # Common UI actions/buttons
    'save', 'cancel', 'delete', 'edit', 'copy', 'paste', 'cut', 'select',
    'search', 'filter', 'sort', 'clear', 'reset', 'apply', 'confirm',
    'yes', 'no', 'ok', 'done', 'next', 'back', 'skip', 'retry', 'close',
    'open', 'create', 'new', 'add', 'remove', 'update', 'refresh', 'load',
    'login', 'logout', 'signin', 'signup', 'register', 'submit', 'send',
    'share', 'download', 'upload', 'import', 'export', 'print', 'preview',
    
    # Navigation
    'home', 'settings', 'profile', 'account', 'help', 'about', 'menu',
    'drawer', 'tab', 'tabs', 'page', 'screen', 'view', 'list', 'grid',
    'detail', 'summary', 'overview', 'dashboard', 'notifications',
    
    # Status/State
    'online', 'offline', 'active', 'inactive', 'enabled', 'disabled',
    'visible', 'hidden', 'loading', 'ready', 'error', 'success', 'warning',
    'info', 'pending', 'complete', 'failed', 'running', 'stopped',
    
    # Common UI labels
    'name', 'title', 'description', 'content', 'message', 'text', 'label',
    'value', 'option', 'choice', 'input', 'output', 'result', 'data',
    'file', 'folder', 'image', 'photo', 'video', 'audio', 'document',
    'link', 'url', 'path', 'size', 'date', 'time', 'duration',
    
    # Actions with objects
    'delete', 'remove', 'archive', 'restore', 'duplicate', 'rename',
    'move', 'copy', 'cut', 'paste', 'select', 'selectall', 'deselect',
    'undo', 'redo', 'refresh', 'sync', 'connect', 'disconnect',
    
    # Thai-specific (keep for translation)
    'ตั้งค่า', 'ค้นหา', 'บันทึก', 'ยกเลิก', 'ลบ', 'แก้ไข', 'เพิ่ม',
    'เปิด', 'ปิด', 'ตกลง', 'เสร็จสิ้น', 'ถัดไป', 'ย้อนกลับ', 'ข้าม',
    'ลองใหม่', 'ปิด', 'สร้าง', 'ใหม่', 'เพิ่ม', 'ลบ', 'อัปเดต', 'รีเฟรช',
    'โหลด', 'เข้าสู่ระบบ', 'ออกจากระบบ', 'สมัคร', 'ส่ง', 'แชร์',
    'ดาวน์โหลด', 'อัปโหลด', 'นำเข้า', 'ส่งออก', 'พิมพ์', 'ดูตัวอย่าง',
}

# Common technical single words that should be skipped
TECH_SINGLE_WORDS = {
    'padding', 'margin', 'border', 'radius', 'width', 'height', 'size',
    'color', 'background', 'foreground', 'opacity', 'visible', 'hidden',
    'flex', 'align', 'justify', 'center', 'start', 'end', 'between',
    'around', 'evenly', 'stretch', 'baseline', 'auto', 'fixed', 'relative',
    'absolute', 'static', 'sticky', 'overflow', 'scroll', 'clip', 'hidden',
    'visible', 'auto', 'none', 'block', 'inline', 'flex', 'grid', 'table',
    'row', 'column', 'wrap', 'nowrap', 'reverse', 'direction', 'flow',
    'order', 'basis', 'grow', 'shrink', 'content', 'items', 'self',
    'index', 'key', 'value', 'data', 'item', 'items', 'list', 'array',
    'map', 'set', 'object', 'string', 'number', 'boolean', 'bool', 'int',
    'float', 'double', 'long', 'short', 'byte', 'char', 'void', 'null',
    'undefined', 'true', 'false', 'this', 'super', 'return', 'break',
    'continue', 'if', 'else', 'for', 'while', 'do', 'switch', 'case',
    'default', 'try', 'catch', 'finally', 'throw', 'new', 'class',
    'interface', 'enum', 'const', 'final', 'var', 'val', 'let', 'const',
    'function', 'func', 'async', 'await', 'yield', 'import', 'export',
    'from', 'as', 'default', 'namespace', 'module', 'package', 'library',
    'part', 'of', 'mixin', 'extends', 'implements', 'with', 'on', 'is',
    'as', 'in', 'out', 'covariant', 'contravariant', 'invariant',
    'abstract', 'sealed', 'final', 'const', 'static', 'factory',
    'external', 'native', 'synchronized', 'volatile', 'transient',
    'strictfp', 'public', 'private', 'protected', 'internal', 'default',
    'override', 'abstract', 'virtual', 'sealed', 'readonly', 'writeonly',
    'get', 'set', 'init', 'deinit', 'subscript', 'operator', 'convenience',
    'required', 'optional', 'implicit', 'explicit', 'dynamic', 'static',
    'lazy', 'late', 'final', 'const', 'var', 'let', 'const', 'function',
    'arrow', 'async', 'await', 'promise', 'then', 'catch', 'finally',
    'resolve', 'reject', 'all', 'race', 'any', 'allsettled', 'finally',
    'await', 'yield', 'generator', 'iterator', 'next', 'done', 'value',
    'return', 'throw', 'try', 'catch', 'finally', 'break', 'continue',
    'label', 'goto', 'switch', 'case', 'default', 'if', 'else', 'elif',
    'while', 'for', 'in', 'of', 'do', 'until', 'repeat', 'loop', 'foreach',
    'map', 'filter', 'reduce', 'find', 'findindex', 'includes', 'some',
    'every', 'flat', 'flatmap', 'sort', 'reverse', 'slice', 'splice',
    'push', 'pop', 'shift', 'unshift', 'concat', 'join', 'split', 'trim',
    'padstart', 'padend', 'repeat', 'replace', 'replaceall', 'match',
    'matchall', 'search', 'exec', 'test', 'compile', 'exec', 'flags',
    'global', 'ignorecase', 'multiline', 'sticky', 'unicode', 'dotall',
    'lastindex', 'source', 'input', 'groups', 'indices', 'substring',
    'substr', 'charat', 'charcodeat', 'codepointat', 'fromcodepoint',
    'fromcharcode', 'tostring', 'tolocalestring', 'tofixed', 'toexponential',
    'toprecision', 'valueof', 'parseint', 'parsefloat', 'isnan', 'isfinite',
    'isinteger', 'issafeinteger', 'min', 'max', 'abs', 'round', 'floor',
    'ceil', 'trunc', 'sqrt', 'cbrt', 'pow', 'exp', 'expm1', 'log', 'log1p',
    'log10', 'log2', 'sin', 'cos', 'tan', 'asin', 'acos', 'atan', 'atan2',
    'sinh', 'cosh', 'tanh', 'asinh', 'acosh', 'atanh', 'hypot', 'sign',
    'random', 'e', 'ln2', 'ln10', 'log2e', 'log10e', 'pi', 'sqrt1_2',
    'sqrt2', 'infinity', 'nan', 'minvalue', 'maxvalue', 'epsilons',
    'prototype', 'constructor', 'hasownproperty', 'isprototypeof',
    'propertyisenumerable', 'tostring', 'tolocalestring', 'valueof',
    'defineproperty', 'defineproperties', 'getownpropertydescriptor',
    'getownpropertydescriptors', 'getownpropertynames', 'getownpropertysymbols',
    'getprototypeof', 'setprototypeof', 'is', 'instanceof', 'typeof',
    'delete', 'void', 'new', 'this', 'super', 'arguments', 'eval', 'with',
    'debugger', 'use', 'strict', 'let', 'const', 'class', 'extends',
    'super', 'static', 'get', 'set', 'constructor', 'prototype',
    'implements', 'interface', 'type', 'typeof', 'keyof', 'in', 'readonly',
    'partial', 'required', 'pick', 'omit', 'record', 'exclude', 'extract',
    'nonnullable', 'returntype', 'instancetype', 'parameterstype',
    'constructortype', 'thistype', 'awaited', 'promise', 'then', 'catch',
    'finally', 'resolve', 'reject', 'all', 'race', 'any', 'allsettled',
}

# Hex color pattern
HEX_COLOR_PATTERN = re.compile(r'^(0x|#)[0-9a-fA-F]{6,8}$')

# Numeric/math pattern
NUMERIC_PATTERN = re.compile(r'^[\d\.\+\-\*/\(\)\s]+$')

# Single word (no spaces) pattern
SINGLE_WORD_PATTERN = re.compile(r'^[a-zA-Z_][a-zA-Z0-9_]*$')


def load_keep_terms(keep_file: Path) -> Set[str]:
    """Load terms from keep.txt that should be skipped."""
    terms = set()
    if keep_file.exists():
        content = keep_file.read_text(encoding='utf-8')
        for line in content.split('\n'):
            line = line.strip()
            if line and not line.startswith('#'):
                terms.add(line)
    return terms


def is_url(text: str) -> bool:
    """Check if text is a URL."""
    url_patterns = [
        r'^https?://',
        r'^wss?://',
        r'^ftp://',
        r'^file://',
        r'^[a-zA-Z0-9.-]+\.(com|org|net|io|dev|app|ai|co|me|xyz|tech|online|site|space|cloud)\b',
        r'^localhost:\d+',
        r'^127\.0\.0\.1:\d+',
        r'^0\.0\.0\.0:\d+',
    ]
    for pattern in url_patterns:
        if re.search(pattern, text, re.IGNORECASE):
            return True
    return False


def is_file_path(text: str) -> bool:
    """Check if text looks like a file path."""
    if re.search(r'^[./~]', text):
        return True
    if re.search(r'[/\\].*\.(dart|kt|java|js|ts|tsx|jsx|py|rs|go|cpp|c|h|hpp|json|yaml|yml|xml|html|css|scss|sass|less|md|txt|log|ini|conf|config|toml|properties|gradle|maven|sbt|bazel|cmake|make|sh|bash|zsh|fish|ps1|bat|cmd)$', text):
        return True
    if re.search(r'[/\\](src|lib|bin|build|dist|out|target|node_modules|venv|env|\.git|\.github|assets|res|test|tests|spec|specs)[/\\]', text):
        return True
    return False


def is_regex(text: str) -> bool:
    """Check if text looks like a regex pattern (multiple metacharacters)."""
    if len(text) < 5:
        return False
    regex_chars = r'[\[\]\(\)\{\}\^\$\*\+\?\.\|\\]'
    count = len(re.findall(regex_chars, text))
    return count >= 3


def is_clear_code_syntax(text: str) -> bool:
    """Check if text is CLEARLY code syntax (imports, package declarations)."""
    code_starts = [
        r'^import\s+',
        r'^export\s+',
        r'^require\s*\(',
        r'^include\s+',
        r'^using\s+',
        r'^package\s+',
        r'^module\s+',
        r'^dart:',
        r'^package:',
        r'^part\s+of\s+',
        r'^library\s+',
    ]
    for pattern in code_starts:
        if re.match(pattern, text):
            return True
    return False


def is_log_or_debug(text: str, context: str) -> bool:
    """Check if text is a log/print/debug/throw/assert message with formatting."""
    log_contexts = {
        'log', 'print', 'debugprint', 'debug', 'info', 'warn', 'warning',
        'error', 'fatal', 'assert', 'throw', 'exception', 'trace',
        'verbose', 'wtf'
    }
    context_lower = context.lower()
    for log_kw in log_contexts:
        if log_kw in context_lower:
            if re.search(r'%[sdifoexXgG]|%\{|\$\{', text):
                return True
            return True
    if re.search(r'%[sdifoexXgG]|%\{|\$\{', text):
        return True
    return False


def is_test_or_dev_file(file_path: str) -> bool:
    """Check if file is a test or dev file."""
    test_patterns = [
        r'/test/',
        r'/tests/',
        r'_test\.dart$',
        r'_test\.kt$',
        r'\.test\.(js|ts|tsx|jsx)$',
        r'\.spec\.(js|ts|tsx|jsx)$',
        r'_spec\.dart$',
        r'/test_',
        r'/spec_',
        r'\.golden\.',
        r'/golden/',
        r'/fixture/',
        r'/mock/',
        r'/stub/',
        r'/dev/',
        r'/example/',
        r'/benchmark/',
        r'/perf/',
        r'\.benchmark\.',
        r'/integration_test/',
        r'/unit_test/',
        r'/widget_test/',
    ]
    for pattern in test_patterns:
        if re.search(pattern, file_path, re.IGNORECASE):
            return True
    return False


def is_clear_identifier_key(text: str, context: str) -> bool:
    """Check if text is clearly an identifier key (route, enum, JSON key)."""
    if len(text) < 3:
        return False
    
    key_contexts = {
        'route', 'key', 'name', 'id', 'enum', 'constant', 'property',
        'json_key', 'jsx_prop:key', 'jsx_prop:id', 'jsx_prop:name',
    }
    context_lower = context.lower()
    is_key_context = any(kw in context_lower for kw in key_contexts)
    
    if not is_key_context:
        return False
    
    if re.match(r'^[a-z]+(_[a-z]+){2,}$', text):
        return True
    if re.match(r'^[a-z]+([A-Z][a-z]+){2,}$', text):
        return True
    if re.match(r'^([A-Z][a-z]+){2,}$', text):
        return True
    if re.match(r'^[A-Z]+(_[A-Z]+){1,}$', text):
        return True
    if re.match(r'^[a-z]+(-[a-z]+){2,}$', text):
        return True
    
    return False


def is_hex_color(text: str) -> bool:
    """Check if text is a hex color code."""
    return bool(HEX_COLOR_PATTERN.match(text))


def is_numeric_math(text: str) -> bool:
    """Check if text is purely numeric/math expression."""
    stripped = text.strip()
    if len(stripped) < 2:
        return False
    return bool(NUMERIC_PATTERN.match(stripped))


def is_single_tech_word(text: str) -> bool:
    """Check if text is a single technical word (no spaces, all lowercase or camelCase)."""
    stripped = text.strip()
    if not SINGLE_WORD_PATTERN.match(stripped):
        return False
    
    # Skip if in UI whitelist
    if stripped.lower() in UI_WHITELIST:
        return False
    
    # Skip short words (1-3 chars)
    if len(stripped) <= 3:
        return True
    
    # Skip known tech single words
    if stripped.lower() in TECH_SINGLE_WORDS:
        return True
    
    # Skip all-lowercase single words (likely CSS properties, variable names)
    # BUT allow if it's in UI whitelist (already checked above)
    if stripped.islower() and '_' not in stripped and '-' not in stripped:
        # Check if it's a known UI word that should be translated
        if stripped.lower() in UI_WHITELIST:
            return False
        return True
    
    # Skip camelCase that looks like variable names
    if re.match(r'^[a-z]+([A-Z][a-z]*)+$', stripped):
        return True
    
    return False


def determine_layer(file_path: str, parent_type: str) -> str:
    """Determine the layer based on file path and parent type."""
    file_lower = file_path.lower()
    
    if 'android' in file_lower and ('kotlin' in file_lower or file_lower.endswith('.kt')):
        return 'kotlin'
    if file_lower.endswith('.xml') and 'android' in file_lower:
        return 'xml'
    if file_lower.endswith('.dart'):
        return 'dart'
    if file_lower.endswith(('.js', '.ts', '.tsx', '.jsx')):
        return 'javascript'
    if file_lower.endswith('.html'):
        return 'html'
    if file_lower.endswith(('.json', '.arb')):
        return 'json'
    if parent_type:
        return parent_type.lower()
    return 'unknown'


def determine_kind(parent_type: str, context: str, parent_property: str) -> str:
    """Determine the kind of string literal."""
    if parent_type == 'Dart':
        if 'widget' in context.lower():
            return 'widget_text'
        if any(kw in context.lower() for kw in ['label', 'title', 'tooltip', 'hint', 'placeholder', 'semantic']):
            return 'ui_text'
        if 'dialog' in context.lower():
            return 'dialog_text'
        return 'dart_string'
    if parent_type == 'Kotlin':
        if 'string_resource' in context.lower():
            return 'string_resource'
        if 'xml_attr' in context.lower():
            return 'xml_attribute'
        return 'kotlin_string'
    if parent_type == 'XML':
        if 'string_resource' in context.lower():
            return 'string_resource'
        return 'xml_attribute'
    if parent_type in ('JavaScript', 'TypeScript'):
        return 'js_string'
    if parent_type == 'HTML':
        return 'html_text'
    if parent_type in ('JSON', 'ARB'):
        return 'translation_key'
    return 'unknown'


def is_likely_ui_text(text: str, file_path: str, context: str, parent_type: str, parent_property: str) -> bool:
    """
    Determine if text is likely user-facing UI text.
    Returns True if it should be translated (todo), False if it should be skipped.
    EXTREMELY AGGRESSIVE - only keep clear user-facing sentences/phrases.
    Target: 2,000-5,000 todo entries.
    """
    # === ALL CONSTANTS DEFINED AT TOP ===
    ui_contexts = {
        'label', 'title', 'tooltip', 'hint', 'placeholder', 'semantic',
        'text', 'button', 'dialog', 'menu', 'tab', 'snackbar', 'tooltip',
        'header', 'footer', 'heading', 'caption', 'subtitle', 'message',
        'error', 'warning', 'info', 'success', 'confirm', 'prompt',
    }
    ui_properties = {
        'text', 'label', 'title', 'hinttext', 'helpertext', 'errortext',
        'countertext', 'placeholder', 'semanticlabel', 'prefixtext',
        'suffixtext', 'content', 'message', 'description', 'summary',
    }
    action_contexts = {'button', 'action', 'menu', 'tab', 'button:', 'function:button'}
    ui_verbs = {'click', 'tap', 'press', 'swipe', 'drag', 'pull', 'select', 'choose', 'pick', 'enter', 'type', 'input', 'search', 'find', 'filter', 'sort', 'save', 'cancel', 'delete', 'edit', 'copy', 'paste', 'cut', 'undo', 'redo', 'refresh', 'reload', 'reset', 'clear', 'close', 'open', 'view', 'show', 'hide', 'enable', 'disable', 'turn on', 'turn off', 'switch', 'toggle', 'change', 'update', 'add', 'remove', 'create', 'new', 'import', 'export', 'download', 'upload', 'share', 'send', 'receive', 'sync', 'connect', 'disconnect', 'login', 'logout', 'sign in', 'sign out', 'register', 'sign up', 'forgot', 'reset password', 'verify', 'confirm', 'agree', 'accept', 'decline', 'reject', 'allow', 'deny', 'permission', 'grant', 'revoke'}
    ui_whitelist = UI_WHITELIST
    tech_single_words = TECH_SINGLE_WORDS
    legal_keywords = {
        'copyright', 'license', 'licensed', 'reserved', 'permission',
        'warranty', 'liability', 'damages', 'indemnify', 'as is',
        'jetbrains', 'mono', 'font software', 'reserved font name',
        'original version', 'modified version', 'author', 'contributors',
        'bouncy castle', 'xz for java', 'androidx webkit', 'phosphor icons',
        'material icons', 'this implementation', 'legal entity',
        'derivative works', 'not a contribution', 'gnu gpl',
        'combined work', 'minimal corresponding source',
        'corresponding application code', 'appropriate legal notices',
        'object code', 'standard interface', 'legal entity',
        'bouncy castle', 'xz for java', 'androidx webkit', 'phosphor icons',
        'material icons', 'noto sans cjk sc', 'noto sans', 'cjk sc',
        'mikan', 'anibt', 'noto', 'sans', 'cjk', 'sc', 'int8', 'fp32',
        'float', 'quantized', 'quantization', 'gb', 'mb', 'kb', 'tb', 'pb',
        'bouncy', 'castle', 'phosphor', 'icons', 'material', 'icons',
        'noto', 'sans', 'cjk', 'sc', 'int8', 'fp32', 'float',
        'quantized', 'quantization', 'gb', 'mb', 'kb', 'tb', 'pb',
    }
    brand_names = {'ds bot', 'dsbot', 'deepseek', 'github', 'flutter', 'dart', 'android', 'ios', 'linux', 'windows', 'macos', 'web', 'api', 'sdk', 'ide', 'ui', 'ux', 'json', 'xml', 'yaml', 'http', 'https', 'ssh', 'ssl', 'tls', 'vpn', 'dns', 'ip', 'tcp', 'udp', 'uuid', 'sha', 'aes', 'rsa', 'ecdsa', 'ed25519', 'base64', 'utf-8', 'ascii', 'iso', 'utc', 'gmt', 'ram', 'cpu', 'gpu', 'ssd', 'hdd', 'usb', 'hdmi', 'dp', 'wifi', 'bluetooth', 'nfc', 'qr', 'ar', 'vr', 'mr', 'xr', 'ai', 'ml', 'llm', 'nlp', 'cnn', 'rnn', 'gan', 'bert', 'gpt', 'bouncy castle', 'xz for java', 'androidx webkit', 'phosphor icons', 'material icons', 'noto sans cjk sc', 'noto sans', 'cjk sc', 'mikan', 'anibt', 'noto', 'sans', 'cjk', 'sc', 'int8', 'fp32', 'float', 'quantized', 'quantization', 'gb', 'mb', 'kb', 'tb', 'pb'}
    scanner_noise_prefixes = [
        's ', 't ', ' chats', ' chat', ' island', ' own', ' read', ' route',
        ' islands', ' kept', ' answer', ' say', ' keep', ' looked', ' take',
        ' insets', ' islands', ' navigation', ' gate', ' recipes', ' handle',
        ' navigation', ' looked', ' no origin', ' meta keyword', ' circle',
        ' stadium', ' modern app', ' keep it', ' say what', ' answer the',
    ]
    log_debug_keywords = [
        'reply', 'masked', 'row', 'title', 'islands', 'own', 'edits', 'preview',
        'heading', 'label', 'signal', 'freshness', 'happened', 'native',
        'issue', 'badeffect', 'namespace', 'copy', 'zh', 'plugin', 'config',
        'settings', 'schema', 'form', 'media', 'url', 'sheet', 'font',
        'licenses', 'reserved', 'original', 'modified', 'version', 'software',
        'name', 'jetbrains', 'mono', 'as', 'is', 'permission', 'warranty',
        'liability', 'damages', 'indemnify',
    ]
    ui_phrases = ['click here', 'tap here', 'press here', 'click to', 'tap to', 'press to', 'swipe to', 'drag to', 'pull to']
    action_contexts = {'button', 'action', 'menu', 'tab', 'button:', 'function:button'}
    tech_single_words = TECH_SINGLE_WORDS
    ui_whitelist = UI_WHITELIST
    
    # === PROCESSING STARTS HERE ===
    stripped = text.strip()
    if not stripped:
        return False
    
    text_lower = stripped.lower()
    prop_lower = parent_property.lower() if parent_property else ''
    context_lower = context.lower()
    stripped_clean = stripped.strip()
    
    # === NEGATIVE INDICATORS (should skip) ===
    
    # 0. Skip license files entirely (by filename)
    filename = file_path.split('/')[-1].lower()
    if 'license' in filename or 'third_party' in filename:
        return False
    
    # 0.1 Skip ARB translation files and generated files - they're not hardcoded strings
    if file_path.endswith('.arb') or '/gen/' in file_path or file_path.startswith('gen/'):
        return False
    
    # 0.2 Skip generated localization files
    if 'l10n/gen/' in file_path or 'l10n\\gen\\' in file_path:
        return False
    
    # 1. Skip l10n keys - these are not translatable text
    # BUT allow l10n. keys that are actually UI text (simple keys only, no interpolation)
    if stripped.startswith('l10n.'):
        # Allow only simple keys: no parentheses, no $, no commas, no spaces (unless it's a simple key)
        # If it has parentheses, $, commas, or spaces, it's a function call with interpolation - skip it
        if re.search(r'[\(\)\$\,\s]', stripped):
            return False
        # Simple key like "l10n.hello" - allow for translation
        pass
    
    # 2. Skip template strings with $ interpolation - these are code templates
    # BUT allow l10n. calls which are legitimate UI text with interpolation
    if '$' in stripped and ('${' in stripped or re.search(r'\$[a-zA-Z_][a-zA-Z0-9_]*', stripped)):
        # Allow l10n. calls which are legitimate UI text
        if 'l10n.' in stripped:
            pass  # Don't skip l10n. calls
        else:
            return False
    
    # 3. Skip license/legal/copyright text
    if any(kw in text_lower for kw in legal_keywords):
        return False
    
    # 4. Skip obvious code/templates with $ or % formatting
    if re.search(r'%[sdifoexXgG]|%\{|\$\{', stripped):
        return False
    
    # 5. ARB/JSON translation files - high priority for translation
    if file_path.endswith(('.arb', '.json')) and parent_type in ('JSON', 'ARB'):
        return True
    
    # 6. Scanner noise: strings starting with "s " or "t " (regex scanner artifact)
    # BUT allow if it looks like a real word/phrase (has length > 2 after prefix)
    if stripped.startswith(('s ', 't ', 's\t', 't\t')):
        rest = stripped[2:].strip()
        if len(rest) >= 3 and ' ' in rest:
            # Looks like a real phrase, not scanner noise
            pass
        else:
            return False
    
    # 7. Skip strings starting with common scanner artifacts
    # BUT allow if the rest looks like a real phrase
    for prefix in scanner_noise_prefixes:
        if stripped.lower().startswith(prefix):
            rest = stripped[len(prefix):].strip()
            if len(rest) >= 3 and ' ' in rest:
                # Looks like a real phrase, not scanner noise
                pass
            else:
                return False
    
    # 8. Skip corrupted/incomplete extractions (very short after common prefixes)
    # BUT allow if it looks like a complete word/phrase
    if re.match(r'^(s|t|a|the|an|to|of|in|on|for|with|by|at|from|as|is|it|be|or|and|but|if|then|else|when|while|for|do|try|catch|finally|throw|return|break|continue|switch|case|default)\s+', stripped.lower()):
        rest = stripped[stripped.index(' ') + 1:].strip()
        if len(rest) >= 5 and ' ' in rest:
            # Looks like a complete phrase
            pass
        else:
            # Additional check: if it has Chinese/Thai chars or looks like UI text, allow it
            if ' ' in rest and (re.search(r'[\u4e00-\u9fff\u0e00-\u0e7f]', rest) or len(rest) >= 10):
                pass
            else:
                return False
    
    # 9. Skip strings that are mostly noise (too many special chars)
    alnum_count = len(re.findall(r'[a-zA-Z0-9\u4e00-\u9fff\u0e00-\u0e7f]', stripped))
    total_count = len(stripped)
    if total_count > 0 and alnum_count / total_count < 0.5:
        return False
    
    # 10. Skip very short fragments
    if len(stripped) < 3:
        return False
    
    # 11. Skip code-like fragments (camelCase, snake_case with multiple parts)
    if re.match(r'^[a-z]+([A-Z][a-z]*){2,}$', stripped):  # camelCase with 2+ capitals
        return False
    if re.match(r'^[a-z]+(_[a-z]+){2,}$', stripped):  # snake_case with 2+ underscores
        return False
    
    # 12. Skip strings that are just numbers with units
    if re.match(r'^\d+\s*(步|个|次|天|小时|分钟|秒|ms|kb|mb|gb|px|dp|sp|%)$', stripped):
        return False
    
    # 13. Skip strings that look like log/debug output patterns
    if any(kw in text_lower for kw in log_debug_keywords):
        if not (' ' in stripped and (stripped[0].isupper() or re.search(r'[\u4e00-\u9fff\u0e00-\u0e7f]', stripped))):
            return False
    
    # 14. Skip obvious brand/product names
    if text_lower in brand_names:
        return False
    
    # 15. Skip measurements with units (1.2 GB, 70%, etc.)
    if re.match(r'^[\d\.]+\s*(gb|mb|kb|tb|pb|%|ms|s|h|m|hz|khz|mhz|ghz|db|dbm|vw|vh|px|dp|sp|pt|in|cm|mm)$', stripped, re.IGNORECASE):
        return False
    
    # 16. Skip incomplete sentence fragments (start with lowercase, no sentence ending)
    # BUT allow if it's in a widget context or looks like UI text
    if stripped and stripped[0].islower() and ' ' in stripped:
        if not re.search(r'[.!?。！？]$', stripped):
            if not any(phrase in text_lower for phrase in ui_phrases):
                # Allow if in widget context or property
                if not (prop_lower in ui_properties or any(kw in context_lower for kw in ui_contexts)):
                    # Also allow if it's a known UI phrase pattern
                    if not any(phrase in text_lower for phrase in ui_phrases):
                        # Check if it looks like a UI action phrase (verb + object)
                        words = stripped.split()
                        if len(words) >= 2:
                            first_word = words[0].lower()
                            if first_word in ui_verbs:
                                pass  # Allow UI action phrases
                            else:
                                # Additional check: if it has Chinese/Thai or looks like UI text, allow it
                                if re.search(r'[\u4e00-\u9fff\u0e00-\u0e7f]', stripped) or len(stripped) >= 10:
                                    pass
                                else:
                                    return False
                        else:
                            return False
    
    # 17. Skip English technical terms without clear UI purpose
    # BUT allow if it looks like a UI phrase (has spaces, reasonable length)
    if re.match(r'^[a-zA-Z\s\.\,\!\?]+$', stripped):
        words = stripped.split()
        if len(words) >= 2:
            # Allow if it has 3+ words (likely a phrase)
            if len(words) >= 3:
                pass  # Allow longer phrases
            elif all(w.lower() in tech_single_words for w in words):
                return False
            first_word = words[0].lower()
            if first_word not in ui_verbs and not stripped[0].isupper():
                # Additional check: if it has Chinese/Thai or looks like UI text, allow it
                if re.search(r'[\u4e00-\u9fff\u0e00-\u0e7f]', stripped) or len(stripped) >= 10:
                    pass
                else:
                    return False
    
    # 18. Skip pure Chinese technical terms without clear UI purpose (like FP32 浮点, INT8 量化)
    if re.search(r'[\u4e00-\u9fff]', stripped) and re.search(r'[a-zA-Z0-9]', stripped):
        tech_terms_cn = {'int8', 'fp32', 'fp16', 'bf16', 'quantized', 'quantization', 'int4', 'int2', 'gpt', 'bert', 'llm', 'api', 'sdk', 'http', 'https', 'ssh', 'ssl', 'tls', 'vpn', 'dns', 'ip', 'tcp', 'udp', 'uuid', 'sha', 'aes', 'rsa', 'ecdsa', 'ed25519', 'base64', 'utf-8', 'ascii', 'iso', 'utc', 'gmt', 'ram', 'cpu', 'gpu', 'ssd', 'hdd', 'usb', 'hdmi', 'dp', 'wifi', 'bluetooth', 'nfc', 'qr', 'ar', 'vr', 'mr', 'xr', 'ai', 'ml', 'llm', 'nlp', 'cnn', 'rnn', 'gan', 'bert', 'gpt'}
        words = stripped.split()
        all_tech = True
        for w in words:
            w_lower = w.lower()
            w_clean = re.sub(r'[\u4e00-\u9fff]', '', w_lower)
            if w_clean and w_clean not in tech_terms_cn and w_clean not in tech_single_words:
                all_tech = False
                break
        if all_tech and len(words) >= 2:
            # Additional check: if it has Thai chars or looks like UI text, allow it
            if re.search(r'[\u0e00-\u0e7f]', stripped) or len(stripped) >= 15:
                pass
            else:
                return False
    
    # 19. Skip pure English technical terms without clear UI purpose
    # BUT allow if it looks like a UI phrase (has spaces, reasonable length)
    if re.match(r'^[a-zA-Z\s\.\,\!\?]+$', stripped):
        words = stripped.split()
        if len(words) >= 2:
            if all(w.lower() in tech_single_words for w in words):
                return False
            first_word = words[0].lower()
            if first_word not in ui_verbs and not stripped[0].isupper():
                # Additional check: if it has Chinese/Thai or looks like UI text, allow it
                if re.search(r'[\u4e00-\u9fff\u0e00-\u0e7f]', stripped) or len(stripped) >= 15:
                    pass
                else:
                    return False
    
    # 20. Skip strings with trailing commas, colons, or other punctuation that indicates code fragments
    # BUT allow if it looks like a UI phrase (has spaces, reasonable length)
    if re.search(r'[,:;]\s*$', stripped):
        if ' ' in stripped and len(stripped) >= 5:
            # Check if it looks like a UI phrase
            if not re.match(r'^[a-z_]+$', stripped.replace(' ', '_')):
                pass  # Allow UI phrases
            else:
                # Additional check: if it has Chinese/Thai or looks like UI text, allow it
                if re.search(r'[\u4e00-\u9fff\u0e00-\u0e7f]', stripped) or len(stripped) >= 10:
                    pass
                else:
                    return False
    
    # 21. Skip strings that are just IDs, paths, or technical identifiers
    # BUT allow if it looks like a UI phrase (has spaces, reasonable length)
    if re.match(r'^[\w\-\.\/]+$', stripped) and not re.search(r'[\u4e00-\u9fff\u0e00-\u0e7f]', stripped):
        # Pure ASCII identifier - likely a key, path, or technical term
        if ' ' in stripped and len(stripped) >= 5:
            # Has spaces and reasonable length - likely UI text
            pass
        elif not any(kw in context_lower for kw in ui_contexts):
            # Additional check: if it has Chinese/Thai or looks like UI text, allow it
            if re.search(r'[\u4e00-\u9fff\u0e00-\u0e7f]', stripped) or len(stripped) >= 15:
                pass
            else:
                return False
    
    # 22. Skip license files entirely (by filename)
    filename = file_path.split('/')[-1].lower()
    if 'license' in filename or 'third_party' in filename:
        return False
    
    # === POSITIVE INDICATORS (should translate) ===
    
    # ARB/JSON translation files - high priority
    if file_path.endswith(('.arb', '.json')) and parent_type in ('JSON', 'ARB'):
        return True
    
    # Has spaces and starts with uppercase - likely a sentence/phrase
    if ' ' in stripped_clean and stripped_clean[0].isupper():
        return True
    
    # Has spaces and contains Thai characters
    if ' ' in stripped_clean and re.search(r'[\u0e00-\u0e7f]', stripped_clean):
        return True
    
    # Has spaces and contains Chinese characters (needs translation to Thai)
    if ' ' in stripped_clean and re.search(r'[\u4e00-\u9fff]', stripped_clean):
        return True
    
    # Has spaces and contains Thai/Chinese
    if ' ' in stripped_clean and (re.search(r'[\u4e00-\u9fff]', stripped_clean) or re.search(r'[\u0e00-\u0e7f]', stripped_clean)):
        return True
    
    # Context indicates UI text (but not templates or l10n keys)
    if any(kw in context_lower for kw in ui_contexts):
        if not stripped.startswith('l10n.') and '$' not in stripped and ' ' in stripped_clean:
            return True
    
    # Widget/property names that indicate UI text
    if prop_lower in ui_properties:
        if not stripped.startswith('l10n.') and '$' not in stripped and ' ' in stripped_clean:
            return True
    
    # Single words - only keep if clearly UI actions in button context
    if ' ' not in stripped_clean:
        if stripped_clean.lower() in ui_whitelist:
            if any(ctx in context_lower for ctx in action_contexts):
                return True
        return False
    
    # Multi-word phrases - check if reasonable
    words = stripped_clean.split()
    if len(words) >= 2 and len(stripped_clean) >= 5:
        if not all(w.islower() and w in tech_single_words for w in words):
            return True
    
    return False


def should_skip(text: str, context: str, parent_type: str, parent_property: str, 
                file_path: str, keep_terms: Set[str]) -> bool:
    """Determine if a string should be skipped (not translated).
    AGGRESSIVE: Skip anything that's not clearly user-facing UI text.
    """
    
    # 1. Check keep terms (exact word match, case-insensitive)
    text_lower = text.lower()
    for term in keep_terms:
        if re.search(r'\b' + re.escape(term.lower()) + r'\b', text_lower):
            return True
    
    # 2. Test/dev files - skip all
    if is_test_or_dev_file(file_path):
        return True
    
    # 3. URL - clear technical content
    if is_url(text):
        return True
    
    # 4. File path - clear technical content
    if is_file_path(text):
        return True
    
    # 5. Regex pattern - clear technical content
    if is_regex(text):
        return True
    
    # 6. Clear code syntax (imports, package declarations)
    if is_clear_code_syntax(text):
        return True
    
    # 7. Log/debug/throw/assert with formatting
    if is_log_or_debug(text, context):
        return True
    
    # 8. Clear identifier key (in key context with strong pattern)
    if is_clear_identifier_key(text, context):
        return True
    
    # 9. Empty or very short
    if len(text.strip()) < 2:
        return True
    
    # 10. Only numbers/symbols/whitespace
    if re.match(r'^[\d\s\W]+$', text.strip()):
        return True
    
    # 11. Hex color codes
    if is_hex_color(text):
        return True
    
    # 12. Pure numeric/math expressions
    if is_numeric_math(text):
        return True
    
    # 13. Single technical words (padding, margin, value, index, etc.)
    if is_single_tech_word(text):
        return True
    
    # 14. NOT likely UI text - skip
    # BUT be less aggressive - allow more potential UI text
    if not is_likely_ui_text(text, file_path, context, parent_type, parent_property):
        # Additional check: if it has Chinese/Thai or looks like UI text, allow it
        if re.search(r'[\u4e00-\u9fff\u0e00-\u0e7f]', text) or len(text.strip()) >= 10:
            pass
        else:
            return True
    
    return False


def main():
    if len(sys.argv) < 3:
        print("Usage: python3 build_ledger.py <literals.json> <ledger.json> [keep.txt]")
        sys.exit(1)
    
    literals_file = Path(sys.argv[1])
    ledger_file = Path(sys.argv[2])
    keep_file = Path(sys.argv[3]) if len(sys.argv) > 3 else Path('keep.txt')
    
    if not literals_file.exists():
        print(f"Error: {literals_file} does not exist")
        sys.exit(1)
    
    # Load keep terms
    keep_terms = load_keep_terms(keep_file)
    print(f"Loaded {len(keep_terms)} keep terms")
    
    # Load literals
    with open(literals_file, 'r', encoding='utf-8') as f:
        data = json.load(f)
    
    print(f"Processing {data['totalLiterals']} literals from {len(data['byFile'])} files")
    
    ledger_entries = []
    skip_count = 0
    todo_count = 0
    
    entry_id = 0
    for file_path, items in data['byFile'].items():
        layer = determine_layer(file_path, items[0]['parent_type'] if items else '')
        
        for item in items:
            entry_id += 1
            text = item['literal']
            context = item['context']
            parent_type = item['parent_type']
            parent_property = item['parent_property']
            line = item['line']
            
            kind = determine_kind(parent_type, context, parent_property)
            
            # Determine status
            if should_skip(text, context, parent_type, parent_property, file_path, keep_terms):
                status = 'skip'
                skip_count += 1
            else:
                status = 'todo'
                todo_count += 1
            
            entry = LedgerEntry(
                id=f"L{entry_id:06d}",
                layer=layer,
                file=file_path,
                line=line,
                text=text,
                context=context,
                kind=kind,
                status=status
            )
            ledger_entries.append(entry)
    
    # Write ledger
    output = {
        'version': '1.0',
        'source': str(literals_file),
        'totalEntries': len(ledger_entries),
        'skipCount': skip_count,
        'todoCount': todo_count,
        'entries': [asdict(entry) for entry in ledger_entries]
    }
    
    with open(ledger_file, 'w', encoding='utf-8') as f:
        json.dump(output, f, ensure_ascii=False, indent=2)
    
    print(f"\nLedger created: {ledger_file}")
    print(f"Total entries: {len(ledger_entries)}")
    print(f"Skipped: {skip_count}")
    print(f"To translate (todo): {todo_count}")


if __name__ == '__main__':
    main()