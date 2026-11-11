#!/usr/bin/env python3
"""
Check translations for correctness.
Verifies:
1. Brand/technical terms not translated or lost
2. Placeholders match across languages
3. JSON validity
4. Remaining todo count
5. No code literals (l10n., context., ()) in ARB strings
6. No Thai strings with mixed English words (except technical terms)
7. Keys used in Dart code exist in ARB files
"""

import json
import re
from pathlib import Path
from collections import defaultdict

# Paths
PROJECT_ROOT = Path("/root/workspace/dsh-Go")
PARTS_DIR = PROJECT_ROOT / "app" / "lib" / "l10n" / "parts"
DART_LIB_DIR = PROJECT_ROOT / "app" / "lib"
I18N_TOOLS = Path("/root/workspace/i18n-tools")

# Load denylist (technical terms to keep)
with open(I18N_TOOLS / "keep.txt", "r", encoding="utf-8") as f:
    DENYLIST = [line.strip() for line in f if line.strip() and not line.startswith("#")]

# English words that should not appear mixed in Thai sentences (except as technical terms)
MIXED_ENGLISH_WORDS = [
    "only", "without", "before", "for", "the", "a", "ask", "on", "off",
    "new", "going", "beyond", "files", "needed", "each", "first", "start",
    "set up", "open", "not", "actions"
]

# Load manifest
with open(I18N_TOOLS / "manifest.json", "r", encoding="utf-8") as f:
    MANIFEST = {item["id"]: item for item in json.load(f)}

# PART_PREFIXES - only include existing files
def get_existing_part_prefixes():
    """Get only the part prefixes that have all three language files."""
    prefixes = {}
    for prefix, files in {
        "hub": ["hub_en.arb", "hub_th.arb", "hub_zh.arb"],
        "engine": ["engine_en.arb", "engine_th.arb", "engine_zh.arb"],
        "companion": ["companion_en.arb", "companion_th.arb", "companion_zh.arb"],
        "features": ["features_en.arb", "features_th.arb", "features_zh.arb"],
        "plugins": ["plugins_en.arb", "plugins_th.arb", "plugins_zh.arb"],
        "remote": ["remote_en.arb", "remote_th.arb", "remote_zh.arb"],
        "chat": ["chat_en.arb", "chat_th.arb", "chat_zh.arb"],
        "settings": ["settings_en.arb", "settings_th.arb", "settings_zh.arb"],
        "access": ["access_en.arb", "access_th.arb", "access_zh.arb"],
        "pets": ["pets_en.arb", "pets_th.arb", "pets_zh.arb"],
        "share": ["share_en.arb", "share_th.arb", "share_zh.arb"],
        "update": ["update_en.arb", "update_th.arb", "update_zh.arb"],
        "phone": ["phone_en.arb", "phone_th.arb", "phone_zh.arb"],
        "dev": ["dev_en.arb", "dev_th.arb", "dev_zh.arb"],
        "common": ["common_en.arb", "common_th.arb", "common_zh.arb"],
    }.items():
        if all((PARTS_DIR / f).exists() for f in files):
            prefixes[prefix] = files
    return prefixes

def load_arb(file_path):
    """Load ARB file."""
    if not file_path.exists():
        return {}
    with open(file_path, "r", encoding="utf-8") as f:
        return json.load(f)

def get_text_value(data, key):
    """Extract text value from ARB entry, handling metadata format."""
    if key.startswith("@"):
        return ""
    value = data.get(key, "")
    if isinstance(value, dict):
        # ARB metadata format: {"description": "...", "placeholders": {...}}
        return value.get("", "") or value.get("description", "") or ""
    return str(value)

def extract_placeholders(text, meta=None):
    """Extract all placeholders like {name} or $var.
    If meta is provided (from @key metadata), use that as primary source.
    Only use text-based extraction for simple placeholders (no ICU format).
    """
    placeholders = set()
    
    # Check if text contains ICU MessageFormat
    has_icu = any(keyword in text for keyword in ["plural", "select", "offset"])
    
    # Use metadata if available (primary source for ICU format)
    if meta and isinstance(meta, dict) and "placeholders" in meta:
        placeholders.update(meta["placeholders"].keys())
    
    # Fallback: extract from text ONLY for non-ICU format
    if not has_icu:
        # Match {name} where name doesn't contain braces
        simple_placeholders = re.findall(r"\{([^{}]+)\}", text)
        for ph in simple_placeholders:
            if "," not in ph and "=" not in ph and ph.strip():
                placeholders.add(ph.strip())
    
    # Dart interpolation: $var or ${var}
    dart_placeholders = set(re.findall(r"\$(\w+)|\$\{(\w+)\}", text))
    dart_placeholders = {p for group in dart_placeholders for p in group if p}
    
    return placeholders | dart_placeholders

def check_brand_terms():
    """Check that brand terms are not translated in ARB files."""
    issues = []
    
    for prefix, files in get_existing_part_prefixes().items():
        en_data = load_arb(PARTS_DIR / files[0])
        th_data = load_arb(PARTS_DIR / files[1])
        
        for key in en_data:
            if key.startswith("@"):
                continue
            en_text = get_text_value(en_data, key)
            th_text = get_text_value(th_data, key)
            
            # Check each denylist term (use word boundaries to avoid false positives)
            for term in DENYLIST:
                # Use regex with word boundaries for whole word matching
                pattern = r'\b' + re.escape(term) + r'\b'
                if re.search(pattern, en_text, re.IGNORECASE):
                    # Term exists in English as whole word - check if it's preserved in Thai
                    if not re.search(pattern, th_text, re.IGNORECASE):
                        issues.append(f"Brand term '{term}' lost in Thai for key '{key}': EN='{en_text}' TH='{th_text}'")
    
    return issues

def check_placeholders():
    """Check that placeholders match across languages."""
    issues = []
    
    for prefix, files in get_existing_part_prefixes().items():
        en_data = load_arb(PARTS_DIR / files[0])
        th_data = load_arb(PARTS_DIR / files[1])
        zh_data = load_arb(PARTS_DIR / files[2])
        
        all_keys = set(en_data.keys()) | set(th_data.keys()) | set(zh_data.keys())
        
        for key in all_keys:
            if key.startswith("@"):
                continue
            en_text = get_text_value(en_data, key)
            th_text = get_text_value(th_data, key)
            zh_text = get_text_value(zh_data, key)
            
            # Get metadata from all languages (use union)
            en_meta = en_data.get("@" + key, {})
            th_meta = th_data.get("@" + key, {})
            zh_meta = zh_data.get("@" + key, {})
            
            # Merge placeholders from all available metadata
            all_meta_placeholders = set()
            for meta in [en_meta, th_meta, zh_meta]:
                if meta and isinstance(meta, dict) and "placeholders" in meta:
                    all_meta_placeholders.update(meta["placeholders"].keys())
            
            # Create a combined meta object
            combined_meta = {"placeholders": {ph: {} for ph in all_meta_placeholders}} if all_meta_placeholders else None
            
            en_ph = extract_placeholders(en_text, combined_meta)
            th_ph = extract_placeholders(th_text, combined_meta)
            zh_ph = extract_placeholders(zh_text, combined_meta)
            
            if en_ph != th_ph:
                issues.append(f"Placeholder mismatch for '{key}': EN={en_ph} TH={th_ph} (EN='{en_text}' TH='{th_text}')")
            if en_ph != zh_ph:
                issues.append(f"Placeholder mismatch for '{key}': EN={en_ph} ZH={zh_ph} (EN='{en_text}' ZH='{zh_text}')")
    
    return issues

def check_json_validity():
    """Check that all ARB files are valid JSON."""
    issues = []
    
    for prefix, files in get_existing_part_prefixes().items():
        for lang_file in files:
            arb_path = PARTS_DIR / lang_file
            try:
                with open(arb_path, "r", encoding="utf-8") as f:
                    json.load(f)
            except json.JSONDecodeError as e:
                issues.append(f"Invalid JSON in {lang_file}: {e}")
    
    return issues

def check_code_literals_in_arb():
    """Check that ARB strings don't contain code literals like l10n., context., ()"""
    issues = []
    
    # Pattern to detect code-like strings: l10n.something, context.something, function calls with ()
    code_patterns = [
        (r'\bl10n\.\w+', 'l10n.'),
        (r'\bcontext\.\w+', 'context.'),
        (r'\w+\([^)]*\)', 'function call ()'),
    ]
    
    for prefix, files in get_existing_part_prefixes().items():
        for lang_file in files:
            arb_path = PARTS_DIR / lang_file
            data = load_arb(arb_path)
            
            for key, value in data.items():
                if key.startswith("@"):
                    continue
                text = get_text_value(data, key)
                
                for pattern, desc in code_patterns:
                    matches = re.findall(pattern, text)
                    if matches:
                        issues.append(f"Code literal '{desc}' found in {lang_file} key '{key}': '{text}' (matches: {matches})")
    
    return issues

def check_mixed_english_in_thai():
    """Check Thai strings for mixed English words that should be translated."""
    issues = []
    
    # Build a set of technical terms (case-insensitive)
    tech_terms = set(term.lower() for term in DENYLIST)
    
    for prefix, files in get_existing_part_prefixes().items():
        th_file = files[1]  # Thai file is always second
        arb_path = PARTS_DIR / th_file
        data = load_arb(arb_path)
        
        for key, value in data.items():
            if key.startswith("@"):
                continue
            text = get_text_value(data, key)
            
            # Skip if the text is mostly English (likely untranslated)
            # Check for Thai characters
            has_thai = bool(re.search(r'[\u0E00-\u0E7F]', text))
            if not has_thai:
                continue  # Not a Thai string, skip
            
            # Check each mixed English word
            for eng_word in MIXED_ENGLISH_WORDS:
                # Use word boundaries
                pattern = r'\b' + re.escape(eng_word) + r'\b'
                if re.search(pattern, text, re.IGNORECASE):
                    # Check if it's a technical term (exempt)
                    if eng_word.lower() in tech_terms:
                        continue
                    # Check if the whole word is in the denylist as a substring
                    is_tech = any(eng_word.lower() in term.lower() for term in DENYLIST)
                    if is_tech:
                        continue
                    
                    issues.append(f"Mixed English word '{eng_word}' in Thai key '{key}' ({th_file}): '{text}'")
    
    return issues

def check_keys_exist_in_arb():
    """Check that l10n keys used in Dart code exist in ARB files."""
    issues = []
    
    # Collect all keys from all ARB files (all languages)
    all_arb_keys = set()
    for prefix, files in get_existing_part_prefixes().items():
        for lang_file in files:
            arb_path = PARTS_DIR / lang_file
            data = load_arb(arb_path)
            all_arb_keys.update(k for k in data.keys() if not k.startswith("@"))
    
    # Also include merged app_*.arb files
    for lang in ['en', 'th', 'zh']:
        arb_path = PROJECT_ROOT / "app" / "lib" / "l10n" / f"app_{lang}.arb"
        if arb_path.exists():
            data = load_arb(arb_path)
            all_arb_keys.update(k for k in data.keys() if not k.startswith("@"))
    
    # Find l10n.XXX calls in Dart files
    l10n_call_pattern = r'l10n\.(\w+)\('
    
    for dart_file in DART_LIB_DIR.rglob("*.dart"):
        # Skip test files
        if "test" in str(dart_file).split("/"):
            continue
        try:
            content = dart_file.read_text(encoding="utf-8")
        except Exception:
            continue
        
        matches = re.findall(l10n_call_pattern, content)
        for key in matches:
            if key not in all_arb_keys:
                # Check if it's a getter (like l10n.localeName) - those might be properties not keys
                # But we'll still report it as a potential issue
                issues.append(f"Key '{key}' used in {dart_file.relative_to(PROJECT_ROOT)} but not found in ARB files")
    
    return issues

def count_todos():
    """Count remaining todo items in manifest."""
    todo_count = sum(1 for item in MANIFEST.values() if item["status"] == "todo")
    done_count = sum(1 for item in MANIFEST.values() if item["status"] == "done")
    skip_count = sum(1 for item in MANIFEST.values() if item["status"] == "skip")
    return todo_count, done_count, skip_count

def main():
    print("=== CHECKING TRANSLATIONS ===\n")
    
    all_issues = []
    
    # Check 1: Brand terms
    print("1. Checking brand/technical terms...")
    brand_issues = check_brand_terms()
    if brand_issues:
        all_issues.extend(brand_issues)
        print(f"   FAIL: {len(brand_issues)} issues")
        for issue in brand_issues[:5]:
            print(f"   - {issue}")
    else:
        print("   PASS: All brand terms preserved")
    
    # Check 2: Placeholders
    print("\n2. Checking placeholder consistency...")
    ph_issues = check_placeholders()
    if ph_issues:
        all_issues.extend(ph_issues)
        print(f"   FAIL: {len(ph_issues)} issues")
        for issue in ph_issues[:5]:
            print(f"   - {issue}")
    else:
        print("   PASS: All placeholders match")
    
    # Check 3: JSON validity
    print("\n3. Checking JSON validity...")
    json_issues = check_json_validity()
    if json_issues:
        all_issues.extend(json_issues)
        print(f"   FAIL: {len(json_issues)} issues")
        for issue in json_issues:
            print(f"   - {issue}")
    else:
        print("   PASS: All ARB files are valid JSON")
    
    # Check 4: Code literals in ARB
    print("\n4. Checking for code literals in ARB strings...")
    code_issues = check_code_literals_in_arb()
    if code_issues:
        all_issues.extend(code_issues)
        print(f"   FAIL: {len(code_issues)} issues")
        for issue in code_issues[:10]:
            print(f"   - {issue}")
    else:
        print("   PASS: No code literals found in ARB strings")
    
    # Check 5: Mixed English in Thai
    print("\n5. Checking for mixed English words in Thai strings...")
    mixed_issues = check_mixed_english_in_thai()
    if mixed_issues:
        all_issues.extend(mixed_issues)
        print(f"   FAIL: {len(mixed_issues)} issues")
        for issue in mixed_issues[:10]:
            print(f"   - {issue}")
    else:
        print("   PASS: No mixed English words found in Thai strings")
    
    # Check 6: Keys exist in ARB
    print("\n6. Checking that Dart l10n keys exist in ARB files...")
    key_issues = check_keys_exist_in_arb()
    if key_issues:
        all_issues.extend(key_issues)
        print(f"   FAIL: {len(key_issues)} issues")
        for issue in key_issues[:10]:
            print(f"   - {issue}")
    else:
        print("   PASS: All Dart l10n keys found in ARB files")
    
    # Check 7: Todo count
    print("\n7. Counting remaining work...")
    todo, done, skip = count_todos()
    print(f"   TODO: {todo}")
    print(f"   DONE: {done}")
    print(f"   SKIP: {skip}")
    
    # Summary
    print("\n=== SUMMARY ===")
    if all_issues:
        print(f"FAILED: {len(all_issues)} total issues")
        return 1
    else:
        print("PASSED: All checks passed")
        return 0

if __name__ == "__main__":
    exit(main())