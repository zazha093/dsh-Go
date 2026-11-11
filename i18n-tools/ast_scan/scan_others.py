#!/usr/bin/env python3
"""
Scanner for non-Dart files: Kotlin, XML, JavaScript/TypeScript, HTML, JSON/ARB
Also includes a regex-based Dart scanner.
Extracts string literals with context information.
"""

import json
import re
import os
import sys
from pathlib import Path
from typing import List, Dict, Any, Optional, Tuple
from dataclasses import dataclass, asdict


@dataclass
class StringLiteralInfo:
    file: str
    line: int
    column: int
    literal: str
    parent_type: str
    parent_property: str
    context: str
    is_interpolation: bool = False
    interpolation_expressions: List[str] = None

    def __post_init__(self):
        if self.interpolation_expressions is None:
            self.interpolation_expressions = []

    def to_dict(self) -> Dict[str, Any]:
        return asdict(self)


class KotlinScanner:
    """Extract string literals from Kotlin files."""
    
    # Patterns for string literals in Kotlin
    STRING_PATTERN = re.compile(
        r'(?:"""[\s\S]*?"""|"[^"\\]*(?:\\.[^"\\]*)*")'
    )
    
    # Context patterns - property assignments, function arguments
    CONTEXT_PATTERNS = [
        # property = "value"
        (re.compile(r'(\w+)\s*=\s*(' + STRING_PATTERN.pattern + ')'), 'property'),
        # function("value")
        (re.compile(r'(\w+)\s*\(\s*(' + STRING_PATTERN.pattern + ')'), 'function_arg'),
        # .property("value")
        (re.compile(r'\.(\w+)\s*\(\s*(' + STRING_PATTERN.pattern + ')'), 'method_arg'),
        # named arg: name = "value"
        (re.compile(r'(\w+)\s*=\s*(' + STRING_PATTERN.pattern + ')'), 'named_arg'),
    ]
    
    def scan_file(self, file_path: Path, base_path: Path) -> List[StringLiteralInfo]:
        results = []
        try:
            content = file_path.read_text(encoding='utf-8')
        except Exception as e:
            print(f"Error reading {file_path}: {e}")
            return results
        
        rel_path = file_path.relative_to(base_path)
        lines = content.split('\n')
        
        for line_num, line in enumerate(lines, 1):
            for match in self.STRING_PATTERN.finditer(line):
                literal = match.group(0)
                # Remove quotes
                if literal.startswith('"""') and literal.endswith('"""'):
                    literal = literal[3:-3]
                elif literal.startswith('"') and literal.endswith('"'):
                    literal = literal[1:-1]
                
                if not literal.strip():
                    continue
                
                # Determine context
                context = self._determine_context(line, match.start())
                
                results.append(StringLiteralInfo(
                    file=str(rel_path),
                    line=line_num,
                    column=match.start() + 1,
                    literal=literal,
                    parent_type='Kotlin',
                    parent_property=context['property'],
                    context=context['context'],
                ))
        
        return results
    
    def _determine_context(self, line: str, pos: int) -> Dict[str, str]:
        """Determine the context of a string literal in Kotlin."""
        # Look for property assignments before the string
        prop_match = re.search(r'(\w+)\s*=\s*$', line[:pos])
        if prop_match:
            prop = prop_match.group(1)
            return {'property': prop, 'context': f'property:{prop}'}
        
        # Look for function/method calls
        func_match = re.search(r'(\w+)\s*\(\s*$', line[:pos])
        if func_match:
            func = func_match.group(1)
            return {'property': func, 'context': f'function:{func}'}
        
        # Look for method calls on objects
        method_match = re.search(r'\.(\w+)\s*\(\s*$', line[:pos])
        if method_match:
            method = method_match.group(1)
            return {'property': method, 'context': f'method:{method}'}
        
        return {'property': 'unknown', 'context': 'unknown'}


class XMLScanner:
    """Extract string literals from Android XML files."""
    
    def scan_file(self, file_path: Path, base_path: Path) -> List[StringLiteralInfo]:
        results = []
        try:
            content = file_path.read_text(encoding='utf-8')
        except Exception as e:
            print(f"Error reading {file_path}: {e}")
            return results
        
        rel_path = file_path.relative_to(base_path)
        lines = content.split('\n')
        
        # String resources: <string name="key">value</string>
        string_pattern = re.compile(r'<string\s+name="([^"]+)">([^<]+)</string>')
        # Other text attributes: android:text="value", android:hint="value", etc.
        attr_pattern = re.compile(r'(android:|tools:)?(text|hint|contentDescription|label|title|summary|message|tooltip|placeholder)="([^"]*)"')
        
        for line_num, line in enumerate(lines, 1):
            # String resources
            for match in string_pattern.finditer(line):
                key = match.group(1)
                value = match.group(2)
                if value.strip():
                    results.append(StringLiteralInfo(
                        file=str(rel_path),
                        line=line_num,
                        column=match.start() + 1,
                        literal=value,
                        parent_type='XML',
                        parent_property=key,
                        context='string_resource',
                    ))
            
            # Text attributes
            for match in attr_pattern.finditer(line):
                attr_name = match.group(2)
                value = match.group(3)
                if value.strip():
                    results.append(StringLiteralInfo(
                        file=str(rel_path),
                        line=line_num,
                        column=match.start() + 1,
                        literal=value,
                        parent_type='XML',
                        parent_property=attr_name,
                        context=f'xml_attr:{attr_name}',
                    ))
        
        return results


class JavaScriptScanner:
    """Extract string literals from JavaScript/TypeScript files."""
    
    # Pattern for string literals (single, double, template)
    STRING_PATTERN = re.compile(
        r'(?:"(?:[^"\\]|\\.)*"|\'(?:[^\'\\]|\\.)*\'|`[\s\S]*?`)'
    )
    
    def scan_file(self, file_path: Path, base_path: Path) -> List[StringLiteralInfo]:
        results = []
        try:
            content = file_path.read_text(encoding='utf-8')
        except Exception as e:
            print(f"Error reading {file_path}: {e}")
            return results
        
        rel_path = file_path.relative_to(base_path)
        lines = content.split('\n')
        
        for line_num, line in enumerate(lines, 1):
            for match in self.STRING_PATTERN.finditer(line):
                literal = match.group(0)
                # Remove quotes
                if literal.startswith('`') and literal.endswith('`'):
                    literal = literal[1:-1]
                    is_template = True
                elif (literal.startswith('"') and literal.endswith('"')) or \
                     (literal.startswith("'") and literal.endswith("'")):
                    literal = literal[1:-1]
                    is_template = False
                else:
                    continue
                
                if not literal.strip():
                    continue
                
                # Determine context
                context = self._determine_context(line, match.start())
                
                interpolation_exprs = []
                if is_template:
                    # Extract ${...} expressions
                    expr_matches = re.finditer(r'\$\{([^}]+)\}', literal)
                    for em in expr_matches:
                        interpolation_exprs.append(em.group(1).strip())
                
                results.append(StringLiteralInfo(
                    file=str(rel_path),
                    line=line_num,
                    column=match.start() + 1,
                    literal=literal,
                    parent_type='JavaScript' if file_path.suffix == '.js' else 'TypeScript',
                    parent_property=context['property'],
                    context=context['context'],
                    is_interpolation=is_template,
                    interpolation_expressions=interpolation_exprs,
                ))
        
        return results
    
    def _determine_context(self, line: str, pos: int) -> Dict[str, str]:
        """Determine context in JS/TS."""
        # Property: key: "value"
        prop_match = re.search(r'(\w+)\s*:\s*$', line[:pos])
        if prop_match:
            prop = prop_match.group(1)
            return {'property': prop, 'context': f'property:{prop}'}
        
        # Function call: func("value")
        func_match = re.search(r'(\w+)\s*\(\s*$', line[:pos])
        if func_match:
            func = func_match.group(1)
            return {'property': func, 'context': f'function:{func}'}
        
        # Method call: obj.method("value")
        method_match = re.search(r'\.(\w+)\s*\(\s*$', line[:pos])
        if method_match:
            method = method_match.group(1)
            return {'property': method, 'context': f'method:{method}'}
        
        # JSX attribute: prop="value"
        jsx_match = re.search(r'(\w+)\s*=\s*$', line[:pos])
        if jsx_match:
            prop = jsx_match.group(1)
            return {'property': prop, 'context': f'jsx_prop:{prop}'}
        
        return {'property': 'unknown', 'context': 'unknown'}


class HTMLScanner:
    """Extract string literals from HTML files."""
    
    def scan_file(self, file_path: Path, base_path: Path) -> List[StringLiteralInfo]:
        results = []
        try:
            content = file_path.read_text(encoding='utf-8')
        except Exception as e:
            print(f"Error reading {file_path}: {e}")
            return results
        
        rel_path = file_path.relative_to(base_path)
        lines = content.split('\n')
        
        # Text content between tags: >text<
        text_pattern = re.compile(r'>\s*([^<>\s][^<]*[^<>\s])\s*<')
        # Attributes: attr="value"
        attr_pattern = re.compile(r'(\w+)="([^"]*)"')
        
        for line_num, line in enumerate(lines, 1):
            # Text content
            for match in text_pattern.finditer(line):
                literal = match.group(1)
                if literal.strip():
                    results.append(StringLiteralInfo(
                        file=str(rel_path),
                        line=line_num,
                        column=match.start() + 1,
                        literal=literal,
                        parent_type='HTML',
                        parent_property='text_content',
                        context='html_text',
                    ))
            
            # Attributes
            for match in attr_pattern.finditer(line):
                attr = match.group(1)
                value = match.group(2)
                if value.strip() and attr in ['title', 'alt', 'placeholder', 'label', 'aria-label', 'aria-description']:
                    results.append(StringLiteralInfo(
                        file=str(rel_path),
                        line=line_num,
                        column=match.start() + 1,
                        literal=value,
                        parent_type='HTML',
                        parent_property=attr,
                        context=f'html_attr:{attr}',
                    ))
        
        return results


class JSONScanner:
    """Extract string literals from JSON/ARB files."""
    
    def scan_file(self, file_path: Path, base_path: Path) -> List[StringLiteralInfo]:
        results = []
        try:
            content = file_path.read_text(encoding='utf-8')
            data = json.loads(content)
        except Exception as e:
            print(f"Error reading {file_path}: {e}")
            return results
        
        rel_path = file_path.relative_to(base_path)
        lines = content.split('\n')
        
        # Extract all string values with their keys
        def extract_strings(obj: Any, path: str = "") -> List[Tuple[str, str, int]]:
            """Extract strings with key paths and line numbers."""
            found = []
            if isinstance(obj, dict):
                for key, value in obj.items():
                    if isinstance(value, str):
                        # Find line number
                        line_num = self._find_line_number(lines, key, value)
                        found.append((path + key, value, line_num))
                    elif isinstance(value, (dict, list)):
                        found.extend(extract_strings(value, path + key + "."))
            elif isinstance(obj, list):
                for i, item in enumerate(obj):
                    found.extend(extract_strings(item, path + f"[{i}]."))
            return found
        
        for key_path, value, line_num in extract_strings(data):
            # Skip metadata keys (starting with @)
            if key_path.startswith('@') or key_path.endswith('.@'):
                continue
            
            # Skip empty strings
            if not value.strip():
                continue
            
            results.append(StringLiteralInfo(
                file=str(rel_path),
                line=line_num,
                column=1,
                literal=value,
                parent_type='JSON' if file_path.suffix == '.json' else 'ARB',
                parent_property=key_path,
                context='json_value',
            ))
        
        return results
    
    def _find_line_number(self, lines: List[str], key: str, value: str) -> int:
        """Find the line number for a key-value pair in JSON."""
        search_str = f'"{key}"'
        for i, line in enumerate(lines):
            if search_str in line and value in line:
                return i + 1
        return 1


class DartScanner:
    """Extract string literals from Dart files using regex."""
    
    # Pattern for Dart string literals:
    # - Regular strings: "..." or '...' (with escape sequences)
    # - Raw strings: r"..." or r'...' (no escape processing)
    # - Multi-line strings: """...""" or '''...'''
    # - Raw multi-line: r"""...""" or r'''...'''
    # - String interpolation: $var or ${expr}
    STRING_PATTERN = re.compile(
        r'(?:r?"""[\s\S]*?"""|r?\'\'\'[\s\S]*?\'\'\'|r?"(?:[^"\\]|\\.)*"|r?\'(?:[^\'\\]|\\.)*\')'
    )
    
    # Common Dart/Flutter widget names for context detection
    WIDGET_NAMES = {
        'Text', 'AppBar', 'Tab', 'MenuItem', 'ListTile', 'Button', 'Chip',
        'AlertDialog', 'SnackBar', 'Tooltip', 'RichText', 'TextSpan',
        'TextField', 'InputDecoration', 'IconButton', 'FloatingActionButton',
        'PopupMenuItem', 'DropdownMenuItem', 'ExpansionTile', 'Card',
        'SettingsTile', 'ListPageRow', 'SheetTitleBar', 'SheetHeader',
        'InfoRow', 'PillSegment', 'FieldBadge', 'HostedLinksSettingsTile',
        'UsageStatsSection', 'Container', 'Column', 'Row', 'Stack',
        'Padding', 'Margin', 'Center', 'Align', 'SizedBox', 'Expanded',
        'Flexible', 'ListView', 'GridView', 'SingleChildScrollView',
        'Wrap', 'Flow', 'Table', 'DataTable', 'SelectableText',
        'TextFormField', 'Form', 'FormField', 'DropdownButton',
        'Checkbox', 'Radio', 'Switch', 'Slider', 'ProgressIndicator',
        'CircularProgressIndicator', 'LinearProgressIndicator',
        'BottomNavigationBar', 'NavigationBar', 'TabBar', 'TabBarView',
        'Drawer', 'EndDrawer', 'BottomSheet', 'ModalBottomSheet',
        'Dialog', 'SimpleDialog', 'CupertinoDialog', 'MaterialDialog',
        'SnackBar', 'Banner', 'MaterialBanner', 'Tooltip',
        'PopupMenuButton', 'DropdownMenu', 'MenuAnchor', 'MenuItemButton',
        'ListTile', 'Card', 'InkWell', 'GestureDetector', 'InkResponse',
        'AnimatedContainer', 'AnimatedOpacity', 'AnimatedPositioned',
        'Hero', 'FadeInImage', 'Image', 'Icon', 'CircleAvatar',
        'ClipRect', 'ClipRRect', 'ClipOval', 'ClipPath',
        'Transform', 'RotatedBox', 'FittedBox', 'AspectRatio',
        'ConstrainedBox', 'UnconstrainedBox', 'IntrinsicWidth',
        'IntrinsicHeight', 'LimitedBox', 'Offstage', 'Opacity',
        'Visibility', 'AbsorbPointer', 'IgnorePointer', 'Focus',
        'FocusScope', 'Actions', 'Shortcuts', 'Listener',
        'MouseRegion', 'Draggable', 'DragTarget', 'LongPressDraggable',
        'Scrollbar', 'ScrollConfiguration', 'NotificationListener',
        'GestureDetector', 'InkWell', 'InkResponse', 'ButtonTheme',
        'TextTheme', 'IconTheme', 'ColorScheme', 'Theme',
        'MediaQuery', 'LayoutBuilder', 'OrientationBuilder',
        'Builder', 'StatefulBuilder', 'InheritedWidget',
        'InheritedNotifier', 'InheritedModel', 'NotificationListener',
        'ValueListenableBuilder', 'StreamBuilder', 'FutureBuilder',
        'AnimatedBuilder', 'AnimatedWidget', 'TweenAnimationBuilder',
        'CustomPaint', 'CustomSingleChildLayout', 'CustomMultiChildLayout',
        'Flow', 'Viewport', 'RenderObjectWidget', 'LeafRenderObjectWidget',
        'SingleChildRenderObjectWidget', 'MultiChildRenderObjectWidget',
        'ParentDataWidget', 'RenderObjectElement', 'RenderObject',
        'Container', 'ColoredBox', 'DecoratedBox', 'FractionallySizedBox',
        'ConstrainedBox', 'SizedBox', 'SizedOverflowBox', 'LimitedBox',
        'Offstage', 'Opacity', 'Visibility', 'AbsorbPointer', 'IgnorePointer',
        'ClipRect', 'ClipRRect', 'ClipOval', 'ClipPath', 'Transform',
        'RotatedBox', 'FittedBox', 'AspectRatio', 'FractionalTranslation',
        'Padding', 'Align', 'Center', 'Positioned', 'Stack', 'IndexedStack',
        'Row', 'Column', 'Flex', 'Wrap', 'Flow', 'Table', 'GridView',
        'ListView', 'PageView', 'CustomScrollView', 'NestedScrollView',
        'SingleChildScrollView', 'ScrollView', 'Scrollable', 'Scrollbar',
        'RefreshIndicator', 'SliverAppBar', 'SliverList', 'SliverGrid',
        'SliverToBoxAdapter', 'SliverPadding', 'SliverFillRemaining',
        'SliverFillViewport', 'SliverFixedExtentList', 'SliverPrototypeExtentList',
    }
    
    # Common property names for text content
    TEXT_PROPERTIES = {
        'text', 'label', 'title', 'tooltip', 'hintText', 'helperText',
        'errorText', 'counterText', 'placeholder', 'semanticLabel',
        'prefixText', 'suffixText', 'prefix', 'suffix', 'content',
        'message', 'description', 'summary', 'caption', 'subtitle',
        'header', 'footer', 'leading', 'trailing', 'textAlign',
        'style', 'strutStyle', 'textAlign', 'textDirection', 'softWrap',
        'overflow', 'textScaleFactor', 'maxLines', 'minLines',
    }
    
    def scan_file(self, file_path: Path, base_path: Path) -> List[StringLiteralInfo]:
        results = []
        try:
            content = file_path.read_text(encoding='utf-8')
        except Exception as e:
            print(f"Error reading {file_path}: {e}")
            return results
        
        rel_path = file_path.relative_to(base_path)
        lines = content.split('\n')
        
        for line_num, line in enumerate(lines, 1):
            for match in self.STRING_PATTERN.finditer(line):
                literal = match.group(0)
                is_raw = literal.startswith('r')
                is_multiline = literal.startswith('"""') or literal.startswith("'''")
                
                # Remove quotes and raw prefix
                if is_raw:
                    literal = literal[1:]  # Remove 'r'
                
                if is_multiline:
                    if literal.startswith('"""') and literal.endswith('"""'):
                        literal = literal[3:-3]
                    elif literal.startswith("'''") and literal.endswith("'''"):
                        literal = literal[3:-3]
                elif literal.startswith('"') and literal.endswith('"'):
                    literal = literal[1:-1]
                elif literal.startswith("'") and literal.endswith("'"):
                    literal = literal[1:-1]
                else:
                    continue
                
                if not literal.strip():
                    continue
                
                # Check for interpolation
                is_interpolation = '$' in literal and ('${' in literal or 
                    any(c.isalpha() or c == '_' for c in literal.split('$')[1:]))
                
                interpolation_exprs = []
                if is_interpolation:
                    # Extract ${...} expressions
                    expr_matches = re.finditer(r'\$\{([^}]+)\}', literal)
                    for em in expr_matches:
                        interpolation_exprs.append(em.group(1).strip())
                    # Also extract $var patterns
                    var_matches = re.finditer(r'\$([a-zA-Z_][a-zA-Z0-9_]*)', literal)
                    for vm in var_matches:
                        if vm.group(1) not in [e.split('.')[0] for e in interpolation_exprs]:
                            interpolation_exprs.append(vm.group(1))
                
                # Determine context
                context = self._determine_context(line, match.start())
                
                results.append(StringLiteralInfo(
                    file=str(rel_path),
                    line=line_num,
                    column=match.start() + 1,
                    literal=literal,
                    parent_type='Dart',
                    parent_property=context['property'],
                    context=context['context'],
                    is_interpolation=is_interpolation,
                    interpolation_expressions=interpolation_exprs,
                ))
        
        return results
    
    def _determine_context(self, line: str, pos: int) -> Dict[str, str]:
        """Determine the context of a string literal in Dart."""
        # Look for named parameters: property: "value"
        prop_match = re.search(r'(\w+)\s*:\s*$', line[:pos])
        if prop_match:
            prop = prop_match.group(1)
            if prop in self.TEXT_PROPERTIES:
                return {'property': prop, 'context': f'property:{prop}'}
            return {'property': prop, 'context': f'named_arg:{prop}'}
        
        # Look for property assignments: property = "value"
        prop_match = re.search(r'(\w+)\s*=\s*$', line[:pos])
        if prop_match:
            prop = prop_match.group(1)
            return {'property': prop, 'context': f'property:{prop}'}
        
        # Look for function/method calls: func("value")
        func_match = re.search(r'(\w+)\s*\(\s*$', line[:pos])
        if func_match:
            func = func_match.group(1)
            if func in self.WIDGET_NAMES:
                return {'property': func, 'context': f'widget:{func}'}
            return {'property': func, 'context': f'function:{func}'}
        
        # Look for method calls on objects: obj.method("value")
        method_match = re.search(r'\.(\w+)\s*\(\s*$', line[:pos])
        if method_match:
            method = method_match.group(1)
            return {'property': method, 'context': f'method:{method}'}
        
        # Look for widget constructor: WidgetName("value")
        # Check if previous word is a known widget
        widget_match = re.search(r'(\w+)\s*$', line[:pos])
        if widget_match:
            widget = widget_match.group(1)
            if widget in self.WIDGET_NAMES:
                return {'property': widget, 'context': f'widget:{widget}'}
        
        return {'property': 'unknown', 'context': 'unknown'}


def scan_directory(scanner, dir_path: Path, base_path: Path, patterns: List[str]) -> List[StringLiteralInfo]:
    """Scan a directory with a specific scanner."""
    results = []
    for pattern in patterns:
        for file_path in dir_path.rglob(pattern):
            if file_path.is_file():
                results.extend(scanner.scan_file(file_path, base_path))
    return results


def main():
    if len(sys.argv) < 3:
        print("Usage: python3 scan_others.py <app_root> <output_file>")
        sys.exit(1)
    
    app_root = Path(sys.argv[1]).resolve()
    output_file = Path(sys.argv[2]).resolve()
    
    if not app_root.exists():
        print(f"Error: {app_root} does not exist")
        sys.exit(1)
    
    all_results = []
    
    # Dart files
    print("Scanning Dart files...")
    dart_scanner = DartScanner()
    dart_results = scan_directory(
        dart_scanner,
        app_root / 'lib',
        app_root,
        ['*.dart']
    )
    all_results.extend(dart_results)
    print(f"  Found {len(dart_results)} Dart string literals")
    
    # Kotlin files
    print("Scanning Kotlin files...")
    kotlin_scanner = KotlinScanner()
    kotlin_results = scan_directory(
        kotlin_scanner,
        app_root / 'android' / 'app' / 'src' / 'main' / 'kotlin',
        app_root,
        ['*.kt']
    )
    all_results.extend(kotlin_results)
    print(f"  Found {len(kotlin_results)} Kotlin string literals")
    
    # XML files
    print("Scanning XML files...")
    xml_scanner = XMLScanner()
    xml_results = scan_directory(
        xml_scanner,
        app_root / 'android' / 'app' / 'src' / 'main' / 'res',
        app_root,
        ['*.xml']
    )
    all_results.extend(xml_results)
    print(f"  Found {len(xml_results)} XML string literals")
    
    # JavaScript/TypeScript files
    print("Scanning JavaScript/TypeScript files...")
    js_scanner = JavaScriptScanner()
    js_results = scan_directory(
        js_scanner,
        app_root / 'assets',
        app_root,
        ['*.js', '*.ts']
    )
    all_results.extend(js_results)
    print(f"  Found {len(js_results)} JS/TS string literals")
    
    # HTML files
    print("Scanning HTML files...")
    html_scanner = HTMLScanner()
    html_results = scan_directory(
        html_scanner,
        app_root / 'assets',
        app_root,
        ['*.html']
    )
    all_results.extend(html_results)
    print(f"  Found {len(html_results)} HTML string literals")
    
    # JSON/ARB files
    print("Scanning JSON/ARB files...")
    json_scanner = JSONScanner()
    arb_results = scan_directory(
        json_scanner,
        app_root / 'lib' / 'l10n',
        app_root,
        ['*.arb', '*.json']
    )
    all_results.extend(arb_results)
    print(f"  Found {len(arb_results)} ARB/JSON string literals")
    
    # Also scan assets JSON
    asset_json_results = scan_directory(
        json_scanner,
        app_root / 'assets',
        app_root,
        ['*.json']
    )
    all_results.extend(asset_json_results)
    print(f"  Found {len(asset_json_results)} asset JSON string literals")
    
    # Group by file
    by_file = {}
    for result in all_results:
        by_file.setdefault(result.file, []).append(result.to_dict())
    
    output = {
        'timestamp': __import__('datetime').datetime.now().isoformat(),
        'totalLiterals': len(all_results),
        'byFile': by_file,
    }
    
    with open(output_file, 'w', encoding='utf-8') as f:
        json.dump(output, f, ensure_ascii=False, indent=2)
    
    print(f"\nTotal literals: {len(all_results)}")
    print(f"Files scanned: {len(by_file)}")
    print(f"Results written to: {output_file}")


if __name__ == '__main__':
    main()