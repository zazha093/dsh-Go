#!/usr/bin/env python3
"""
Scan Dart files for hardcoded UI strings that need localization.
Outputs a manifest.json with all findings.
"""

import json
import os
import re
from pathlib import Path
from collections import defaultdict

# Project root
PROJECT_ROOT = Path("/root/workspace/dsh-Go")
LIB_ROOT = PROJECT_ROOT / "app" / "lib"

# Files to skip entirely
SKIP_FILES = {
    "third_party_licenses.dart",  # License texts, not UI
    "plugin_namespace_copy_zh.dart",  # Chinese-only source data
}

# Denylist - brands/technical terms that must NOT be translated
DENYLIST = {
    "DeepSeek", "npm", "pnpm", "Node.js", "API Key", "AGENTS.md", "NOTES.md",
    "PROGRESS.md", "DSH", "GitHub", "Flutter", "Termux", "proot", "Ubuntu",
    "Android", "JSON", "URL", "Terminal", "Skills", "Token", "Model", "Agent",
    "Plugin", "Workspace", "Session", "Cache", "Proxy", "Port", "Prompt",
    "Server", "Engine", "Chat log"
}

# Patterns to skip (comments, imports, logs, keys, routes, regex, paths)
SKIP_PATTERNS = [
    r"^\s*//",  # comments
    r"^\s*/\*",  # block comments
    r"import\s+",  # imports
    r"export\s+",  # exports
    r"\.log\(",  # log calls
    r"print\(",  # print calls
    r"debugPrint\(",  # debugPrint calls
    r"RegExp\(",  # regex
    r"r['\"].*['\"]",  # raw strings
    r"['\"][a-zA-Z0-9_/-]+\.(dart|arb|json|yaml|yml|md)['\"]",  # file paths
    r"['\"][a-z]+://",  # URLs
    r"['\"][A-Z][a-zA-Z0-9_]*['\"]",  # likely keys/routes (PascalCase)
]

# UI string patterns to find
UI_PATTERNS = [
    # Text widgets
    (r"Text\(['\"]([^'\"]+)['\"]", "Text"),
    # title, label, hintText, tooltip, semanticsLabel
    (r"title:\s*['\"]([^'\"]+)['\"]", "title"),
    (r"label:\s*['\"]([^'\"]+)['\"]", "label"),
    (r"hintText:\s*['\"]([^'\"]+)['\"]", "hintText"),
    (r"tooltip:\s*['\"]([^'\"]+)['\"]", "tooltip"),
    (r"semanticsLabel:\s*['\"]([^'\"]+)['\"]", "semanticsLabel"),
    # SnackBar, AlertDialog, AppBar
    (r"SnackBar\([^)]*content:\s*Text\(['\"]([^'\"]+)['\"]", "SnackBar"),
    (r"AlertDialog\([^)]*title:\s*Text\(['\"]([^'\"]+)['\"]", "AlertDialog.title"),
    (r"AlertDialog\([^)]*content:\s*Text\(['\"]([^'\"]+)['\"]", "AlertDialog.content"),
    (r"AppBar\([^)]*title:\s*Text\(['\"]([^'\"]+)['\"]", "AppBar.title"),
]

def should_skip_file(file_path):
    """Check if file should be skipped entirely."""
    return file_path.name in SKIP_FILES

def is_in_keep_region(lines, line_idx):
    """Check if line is within l10n:keep-begin/end region."""
    in_keep = False
    for i in range(line_idx + 1):
        if "l10n:keep-begin" in lines[i]:
            in_keep = True
        elif "l10n:keep-end" in lines[i]:
            in_keep = False
    return in_keep

def should_skip_line(line, file_path):
    """Check if a line should be skipped."""
    for pattern in SKIP_PATTERNS:
        if re.search(pattern, line):
            return True
    return False

def is_brand_or_technical(text):
    """Check if text contains denylisted terms."""
    for term in DENYLIST:
        if term.lower() in text.lower():
            return True
    return False

def classify_kind(text, context_line, has_interpolation):
    """Classify the kind of string."""
    if has_interpolation:
        return "interpolated"
    # Check if it's a const data map entry (not UI text)
    if re.search(r"^\s*\w+:\s*['\"]", context_line):
        return "skip_data"
    if "const" in context_line or "static" in context_line:
        # Check if it's a const map/list that's data
        if "=" in context_line and ("{" in context_line or "[" in context_line):
            return "skip_data"
        return "needs_context"
    if is_brand_or_technical(text):
        return "skip_brand"
    if re.search(r"[A-Z]{2,}", text) and len(text) > 15:
        # Likely technical text with many capitals
        return "skip_technical"
    return "simple"

def extract_context(lines, line_idx, window=1):
    """Extract surrounding context."""
    start = max(0, line_idx - window)
    end = min(len(lines), line_idx + window + 1)
    return " | ".join(lines[start:end]).strip()

def scan_file(file_path):
    """Scan a single Dart file for hardcoded UI strings."""
    findings = []
    try:
        content = file_path.read_text(encoding="utf-8")
        lines = content.splitlines()
        
        for i, line in enumerate(lines):
            stripped = line.strip()
            
            # Skip files entirely
            if should_skip_file(file_path):
                continue
            
            # Skip lines in l10n:keep regions
            if is_in_keep_region(lines, i):
                continue
            
            # Skip lines that match skip patterns
            if should_skip_line(stripped, file_path):
                continue
            
            # Check each UI pattern
            for pattern, pattern_type in UI_PATTERNS:
                matches = re.finditer(pattern, line)
                for match in matches:
                    text = match.group(1)
                    
                    # Skip very short strings
                    if len(text) < 2:
                        continue
                    
                    # Skip if it's just a variable name or key
                    if re.match(r"^[a-z_][a-zA-Z0-9_]*$", text):
                        continue
                    
                    # Check for interpolation
                    has_interpolation = bool(re.search(r"\$\w+|\$\{.*?\}", text))
                    
                    # Classify
                    kind = classify_kind(text, stripped, has_interpolation)
                    
                    # Status
                    status = "todo" if kind in ("simple", "interpolated", "needs_context") else "skip"
                    
                    # Generate ID
                    rel_path = file_path.relative_to(PROJECT_ROOT)
                    finding_id = f"{rel_path}:{i+1}:{match.start()}"
                    finding_id = re.sub(r"[^a-zA-Z0-9_:]", "_", finding_id)
                    
                    findings.append({
                        "id": finding_id,
                        "file": str(rel_path),
                        "line": i + 1,
                        "text": text,
                        "context": extract_context(lines, i),
                        "kind": kind,
                        "status": status,
                        "pattern_type": pattern_type
                    })
    except Exception as e:
        print(f"Error scanning {file_path}: {e}")
    
    return findings

def main():
    """Main scan function."""
    all_findings = []
    
    # Scan all Dart files in lib/
    dart_files = list(LIB_ROOT.rglob("*.dart"))
    print(f"Scanning {len(dart_files)} Dart files...")
    
    for file_path in dart_files:
        # Skip generated files
        if "gen" in file_path.parts or ".g.dart" in file_path.name:
            continue
        findings = scan_file(file_path)
        all_findings.extend(findings)
    
    # Also scan web/ directory if it exists
    web_root = PROJECT_ROOT / "web"
    if web_root.exists():
        web_files = list(web_root.rglob("*.dart")) + list(web_root.rglob("*.js")) + list(web_root.rglob("*.ts"))
        for file_path in web_files:
            findings = scan_file(file_path)
            all_findings.extend(findings)
    
    # Save manifest
    manifest_path = Path("/root/workspace/i18n-tools/manifest.json")
    with open(manifest_path, "w", encoding="utf-8") as f:
        json.dump(all_findings, f, ensure_ascii=False, indent=2)
    
    # Print summary
    by_kind = defaultdict(int)
    by_file = defaultdict(int)
    by_status = defaultdict(int)
    
    for f in all_findings:
        by_kind[f["kind"]] += 1
        by_file[f["file"]] += 1
        by_status[f["status"]] += 1
    
    print("\n=== SCAN SUMMARY ===")
    print(f"Total findings: {len(all_findings)}")
    print("\nBy kind:")
    for kind, count in sorted(by_kind.items()):
        print(f"  {kind}: {count}")
    print("\nBy status:")
    for status, count in sorted(by_status.items()):
        print(f"  {status}: {count}")
    print("\nTop 20 files by findings:")
    for file, count in sorted(by_file.items(), key=lambda x: -x[1])[:20]:
        print(f"  {file}: {count}")
    
    print(f"\nManifest saved to {manifest_path}")

if __name__ == "__main__":
    main()