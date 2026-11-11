#!/usr/bin/env python3
"""
Apply translations to ARB files and Dart source code.
Reads a batch file (JSON: id -> th_translation) and updates:
- ARB part files (hub_en.arb, hub_th.arb, engine_en.arb, engine_th.arb, etc.)
- Dart files (replaces hardcoded strings with l10n.keyName)
"""

import json
import os
import re
from pathlib import Path
from collections import defaultdict

# Paths
PROJECT_ROOT = Path("/root/workspace/dsh-Go")
LIB_ROOT = PROJECT_ROOT / "app" / "lib"
PARTS_DIR = PROJECT_ROOT / "app" / "lib" / "l10n" / "parts"
I18N_TOOLS = Path("/root/workspace/i18n-tools")

# Load manifest
with open(I18N_TOOLS / "manifest.json", "r", encoding="utf-8") as f:
    MANIFEST = {item["id"]: item for item in json.load(f)}

# ARB part files mapping (prefix -> language files)
PART_PREFIXES = {
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
}

def load_arb(file_path):
    """Load ARB file as ordered dict."""
    if not file_path.exists():
        return {}
    with open(file_path, "r", encoding="utf-8") as f:
        content = json.load(f)
    return content

def save_arb(file_path, data):
    """Save ARB file with proper formatting."""
    with open(file_path, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
        f.write("\n")

def determine_part_prefix(item):
    """Determine which ARB part file a string belongs to based on file path."""
    file_path = item["file"]
    
    if "hub" in file_path or "account" in file_path or "onboarding" in file_path:
        return "hub"
    elif "engine" in file_path or "provider" in file_path:
        return "engine"
    elif "companion" in file_path:
        return "companion"
    elif "features" in file_path or "preset" in file_path or "schedule" in file_path or "skill" in file_path:
        return "features"
    elif "plugin" in file_path or "native" in file_path:
        return "plugins"
    elif "remote" in file_path or "ssh" in file_path:
        return "remote"
    elif "chat" in file_path or "trajectory" in file_path or "tool_row" in file_path or "activity_strip" in file_path:
        return "chat"
    elif "settings" in file_path or "diagnostics" in file_path or "privacy" in file_path or "appearance" in file_path:
        return "settings"
    elif "access" in file_path:
        return "access"
    elif "pet" in file_path:
        return "pets"
    elif "share" in file_path:
        return "share"
    elif "update" in file_path:
        return "update"
    elif "phone" in file_path:
        return "phone"
    elif "dev" in file_path:
        return "dev"
    else:
        return "common"

def generate_key(text, existing_keys):
    """Generate a camelCase key from text."""
    clean = re.sub(r"[^\w\s]", "", text)
    words = clean.split()
    if not words:
        return "unknown"
    key = words[0].lower()
    for w in words[1:]:
        key += w.capitalize()
    base_key = key
    counter = 1
    while key in existing_keys:
        key = f"{base_key}{counter}"
        counter += 1
    return key

def get_existing_keys(prefix):
    """Get all existing keys from ARB files for a prefix."""
    keys = set()
    for lang_file in PART_PREFIXES[prefix]:
        arb_path = PARTS_DIR / lang_file
        if arb_path.exists():
            data = load_arb(arb_path)
            keys.update(data.keys())
    return keys

def extract_dart_interpolations(text):
    """Extract Dart interpolation variables from text.
    Returns list of (placeholder_name, dart_expression) tuples.
    """
    # Match $var or ${expr}
    interpolations = []
    for match in re.finditer(r"\$(\w+)|\$\{([^}]+)\}", text):
        if match.group(1):
            # Simple variable: $name
            var_name = match.group(1)
            interpolations.append((var_name, var_name))
        else:
            # Complex expression: ${expr}
            expr = match.group(2)
            # Convert to valid placeholder name
            placeholder = re.sub(r"[^\w]", "_", expr)
            placeholder = re.sub(r"_+", "_", placeholder).strip("_")
            if not placeholder or not placeholder[0].isalpha():
                placeholder = "val" + placeholder
            interpolations.append((placeholder, expr))
    return interpolations

def convert_to_arb_format(text, interpolations):
    """Convert Dart interpolation to ARB placeholder format."""
    result = text
    # Replace ${expr} first (longer patterns)
    for placeholder, expr in sorted(interpolations, key=lambda x: -len(x[1])):
        if expr == placeholder:
            # Simple variable $name
            result = result.replace(f"${expr}", f"{{{placeholder}}}")
        else:
            # Complex expression ${expr}
            result = result.replace(f"${{{expr}}}", f"{{{placeholder}}}")
    return result

def add_to_arb(prefix, key, en_text, th_text, interpolations=None):
    """Add a key to all three language ARB files for a prefix."""
    existing_keys = get_existing_keys(prefix)
    
    # Convert to ARB format if interpolated
    if interpolations:
        en_text = convert_to_arb_format(en_text, interpolations)
        th_text = convert_to_arb_format(th_text, interpolations)
    
    for lang_file in PART_PREFIXES[prefix]:
        arb_path = PARTS_DIR / lang_file
        data = load_arb(arb_path)
        
        if lang_file.endswith("_en.arb"):
            data[key] = en_text
        elif lang_file.endswith("_th.arb"):
            data[key] = th_text
        elif lang_file.endswith("_zh.arb"):
            data[key] = en_text
        
        # Add metadata for placeholders
        if interpolations:
            placeholder_names = [p[0] for p in interpolations]
            data[f"@{key}"] = {
                "placeholders": {name: {"type": "String"} for name in placeholder_names}
            }
        
        save_arb(arb_path, data)

def generate_l10n_call(key, interpolations, pattern_type):
    """Generate the Dart l10n call for the given key and interpolations."""
    if not interpolations:
        return f"l10n.{key}"
    
    # For simple variables, pass them as positional arguments
    # The generated Dart function will have parameters in the same order as placeholders
    args = ", ".join([expr for _, expr in interpolations])
    return f"l10n.{key}({args})"

def replace_in_dart_file(file_path, replacements):
    """Replace hardcoded strings in a Dart file with l10n calls."""
    content = file_path.read_text(encoding="utf-8")
    lines = content.splitlines()
    modified = False
    
    for line_idx, line in enumerate(lines):
        for repl in replacements:
            if repl["line"] == line_idx + 1:
                old_text = repl["old_text"]
                new_text = repl["new_text"]
                if old_text in line:
                    lines[line_idx] = line.replace(old_text, new_text)
                    modified = True
    
    if modified:
        file_path.write_text("\n".join(lines), encoding="utf-8")
        return True
    return False

def process_batch(batch_file):
    """Process a batch of translations."""
    with open(batch_file, "r", encoding="utf-8") as f:
        batch = json.load(f)
    
    file_replacements = defaultdict(list)
    
    for finding_id, th_text in batch.items():
        if finding_id not in MANIFEST:
            print(f"Warning: {finding_id} not in manifest")
            continue
        
        item = MANIFEST[finding_id]
        if item["status"] != "todo":
            print(f"Skipping {finding_id} (status: {item['status']})")
            continue
        
        # Generate key
        prefix = determine_part_prefix(item)
        existing_keys = get_existing_keys(prefix)
        key = generate_key(item["text"], existing_keys)
        
        # Handle interpolations
        interpolations = None
        if item["kind"] == "interpolated":
            interpolations = extract_dart_interpolations(item["text"])
            # Also check Thai translation for interpolations
            th_interpolations = extract_dart_interpolations(th_text)
            # Use the same placeholders for both languages
            if th_interpolations and len(th_interpolations) == len(interpolations):
                # Map Thai expressions to same placeholders
                pass  # We'll use the English interpolations for both
        
        # Add to ARB files
        add_to_arb(prefix, key, item["text"], th_text, interpolations)
        
        # Determine replacement
        pattern_type = item["pattern_type"]
        file_path = LIB_ROOT / item["file"].replace("app/lib/", "")
        
        if interpolations:
            new_text = generate_l10n_call(key, interpolations, pattern_type)
        else:
            new_text = f"l10n.{key}"
        
        file_replacements[file_path].append({
            "line": item["line"],
            "old_text": item["text"],
            "new_text": new_text,
            "key": key
        })
        
        # Update manifest status
        item["status"] = "done"
        item["key"] = key
    
    # Apply replacements to Dart files
    for file_path, replacements in file_replacements.items():
        if replace_in_dart_file(file_path, replacements):
            print(f"Updated {file_path}")
    
    # Save updated manifest
    with open(I18N_TOOLS / "manifest.json", "w", encoding="utf-8") as f:
        json.dump(list(MANIFEST.values()), f, ensure_ascii=False, indent=2)
    
    print(f"Processed {len(batch)} translations")

def main():
    import sys
    if len(sys.argv) < 2:
        print("Usage: python3 apply.py <batch_file>")
        sys.exit(1)
    
    batch_file = sys.argv[1]
    process_batch(batch_file)

if __name__ == "__main__":
    main()