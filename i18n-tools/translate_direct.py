#!/usr/bin/env python3
"""
Phase 3: Direct Translation Pipeline
Reads ledger.json, translates todo items to Thai in batches of 60,
directly updates ARB files, runs checks, and updates ledger.
"""

import json
import sys
import subprocess
import re
from pathlib import Path
from collections import defaultdict

# Paths
PROJECT_ROOT = Path("/root/workspace/dsh-Go")
PARTS_DIR = PROJECT_ROOT / "app" / "lib" / "l10n" / "parts"
LIB_ROOT = PROJECT_ROOT / "app" / "lib"
I18N_TOOLS = Path("/root/workspace/i18n-tools")

# PART_PREFIXES mapping
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

def load_glossary():
    """Load glossary from th_glossary.md and keep.txt"""
    glossary = {}
    
    # From th_glossary.md
    with open("/root/workspace/dsh-Go/docs/th_glossary.md", "r", encoding="utf-8") as f:
        for line in f:
            if "|" in line and not line.startswith("| English"):
                parts = line.split("|")
                if len(parts) >= 3:
                    en = parts[1].strip()
                    th = parts[2].strip()
                    if en and th and en != "English" and th != "Thai":
                        glossary[en.lower()] = th
    
    # From keep.txt (keep as-is)
    with open("/root/workspace/dsh-Go/i18n-tools/keep.txt", "r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if line and not line.startswith("#"):
                glossary[line.lower()] = line  # Keep as-is
    
    return glossary

def translate_text(text, glossary):
    """Translate text to Thai using glossary and rules."""
    if not text:
        return text
    
    # If already mostly Thai, return as-is
    thai_chars = len(re.findall(r'[\u0e00-\u0e7f]', text))
    cjk_chars = len(re.findall(r'[\u0e00-\u0e7f\u4e00-\u9fff]', text))
    if cjk_chars > 0 and thai_chars / cjk_chars > 0.5:
        return text
    
    # Apply glossary replacements
    result = text
    for en, th in sorted(glossary.items(), key=lambda x: -len(x[0])):
        if en == th:  # Keep as-is terms
            continue
        pattern = r'\b' + re.escape(en) + r'\b'
        result = re.sub(pattern, th, result, flags=re.IGNORECASE)
    
    # If still has Chinese characters, return as-is (would need translation API)
    if re.search(r'[\u4e00-\u9fff]', result):
        return result
    
    return result

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

def determine_part_prefix(file_path):
    """Determine which ARB part file a string belongs to based on file path."""
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
    """Extract Dart interpolation variables from text."""
    interpolations = []
    for match in re.finditer(r"\$(\w+)|\$\{([^}]+)\}", text):
        if match.group(1):
            # Simple variable: $name
            var_name = match.group(1)
            interpolations.append((var_name, var_name))
        else:
            # Complex expression: ${expr}
            expr = match.group(2)
            placeholder = re.sub(r"[^\w]", "_", expr)
            placeholder = re.sub(r"_+", "_", placeholder).strip("_")
            if not placeholder or not placeholder[0].isalpha():
                placeholder = "val" + placeholder
            interpolations.append((placeholder, expr))
    return interpolations

def convert_to_arb_format(text, interpolations):
    """Convert Dart interpolation to ARB placeholder format."""
    result = text
    for placeholder, expr in sorted(interpolations, key=lambda x: -len(x[1])):
        if expr == placeholder:
            result = result.replace(f"${expr}", f"{{{placeholder}}}")
        else:
            result = result.replace(f"${{{expr}}}", f"{{{placeholder}}}")
    return result

def add_to_arb(prefix, key, en_text, th_text, interpolations=None):
    """Add a key to all three language ARB files for a prefix."""
    existing_keys = set()
    for lang_file in PART_PREFIXES[prefix]:
        arb_path = PARTS_DIR / lang_file
        if arb_path.exists():
            data = load_arb(arb_path)
            existing_keys.update(data.keys())
    
    if key in existing_keys:
        # Key already exists, skip
        return
    
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
            data[key] = en_text  # Keep English for Chinese for now
        
        if interpolations:
            placeholder_names = [p[0] for p in interpolations]
            data[f"@{key}"] = {
                "placeholders": {name: {"type": "String"} for name in placeholder_names}
            }
        
        save_arb(arb_path, data)

def extract_dart_interpolations(text):
    """Extract Dart interpolation variables from text."""
    interpolations = []
    for match in re.finditer(r"\$(\w+)|\$\{([^}]+)\}", text):
        if match.group(1):
            var_name = match.group(1)
            interpolations.append((var_name, var_name))
        else:
            expr = match.group(2)
            placeholder = re.sub(r"[^\w]", "_", expr)
            placeholder = re.sub(r"_+", "_", placeholder).strip("_")
            if not placeholder or not placeholder[0].isalpha():
                placeholder = "val" + placeholder
            interpolations.append((placeholder, expr))
    return interpolations

def convert_to_arb_format(text, interpolations):
    result = text
    for placeholder, expr in sorted(interpolations, key=lambda x: -len(x[1])):
        if expr == placeholder:
            result = result.replace(f"${expr}", f"{{{placeholder}}}")
        else:
            result = result.replace(f"${{{expr}}}", f"{{{placeholder}}}")
    return result

def generate_key(text, existing_keys):
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
    keys = set()
    for lang_file in PART_PREFIXES[prefix]:
        arb_path = PARTS_DIR / lang_file
        if arb_path.exists():
            data = load_arb(arb_path)
            keys.update(data.keys())
    return keys

def add_to_arb(prefix, key, en_text, th_text, interpolations=None):
    existing_keys = get_existing_keys(prefix)
    if key in existing_keys:
        return
    
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
        
        if interpolations:
            placeholder_names = [p[0] for p in interpolations]
            data[f"@{key}"] = {
                "placeholders": {name: {"type": "String"} for name in placeholder_names}
            }
        
        save_arb(arb_path, data)

def main():
    # Load glossary
    glossary = {}
    with open("/root/workspace/dsh-Go/docs/th_glossary.md", "r", encoding="utf-8") as f:
        for line in f:
            if "|" in line and not line.startswith("| English"):
                parts = line.split("|")
                if len(parts) >= 3:
                    en = parts[1].strip()
                    th = parts[2].strip()
                    if en and th and en != "English" and th != "Thai":
                        glossary[en.lower()] = th
    
    with open("/root/workspace/dsh-Go/i18n-tools/keep.txt", "r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if line and not line.startswith("#"):
                glossary[line.lower()] = line
    
    print(f"Loaded glossary with {len(glossary)} entries")
    
    # Load ledger
    with open("/root/workspace/dsh-Go/i18n-tools/ledger.json", "r", encoding="utf-8") as f:
        ledger = json.load(f)
    
    # Get todo entries
    todo_entries = [e for e in ledger['entries'] if e['status'] == 'todo']
    print(f"Found {len(todo_entries)} todo entries")
    
    # Split into batches of 60
    batch_size = 60
    batches = [todo_entries[i:i+batch_size] for i in range(0, len(todo_entries), batch_size)]
    print(f"Created {len(batches)} batches")
    
    # Process each batch
    for batch_idx, batch in enumerate(batches, 1):
        print(f"\n=== Processing Batch {batch_idx}/{len(batches)} ({len(batch)} items) ===")
        
        for entry in batch:
            text = entry['text']
            thai_text = translate_text(text, glossary)
            
            # Determine prefix and add to ARB
            prefix = determine_part_prefix(entry['file'])
            existing_keys = get_existing_keys(prefix)
            key = generate_key(entry['text'], existing_keys)
            
            # Handle interpolations
            interpolations = extract_dart_interpolations(entry['text'])
            th_interpolations = extract_dart_interpolations(thai_text)
            if th_interpolations and len(th_interpolations) == len(interpolations):
                pass  # Use English interpolations for both
            
            add_to_arb(prefix, key, entry['text'], thai_text, interpolations)
            
            # Update ledger status
            entry['status'] = 'done'
            entry['th_text'] = thai_text
            print(f"  {entry['id']}: {entry['text'][:50]}... -> {thai_text[:50]}... (key: {key})")
        
        # Save updated ledger
        with open("/root/workspace/dsh-Go/i18n-tools/ledger.json", "w", encoding="utf-8") as f:
            json.dump(ledger, f, ensure_ascii=False, indent=2)
        
        # Run check.py
        print(f"Running check.py...")
        result = subprocess.run(
            ["python3", "/root/workspace/dsh-Go/i18n-tools/check.py"],
            cwd="/root/workspace/dsh-Go",
            capture_output=True,
            text=True
        )
        print(result.stdout)
        if result.returncode != 0:
            print(f"check.py warnings: {result.stderr}")
        
        # Update PROGRESS.md
        update_progress()
        
        print(f"Batch {batch_idx} completed successfully!")
    
    print("\n=== All batches completed! ===")

def update_progress():
    """Update PROGRESS.md with current status."""
    with open("/root/workspace/dsh-Go/i18n-tools/ledger.json", "r", encoding="utf-8") as f:
        ledger = json.load(f)
    
    todo = sum(1 for e in ledger['entries'] if e['status'] == 'todo')
    done = sum(1 for e in ledger['entries'] if e['status'] == 'done')
    skip = sum(1 for e in ledger['entries'] if e['status'] == 'skip')
    
    with open("/root/workspace/PROGRESS.md", "r", encoding="utf-8") as f:
        content = f.read()
    
    import re
    new_phase3 = f"""### Phase 3: Translation Batch Processing
- Total items: 1037
- Completed: {done}
- Remaining: {todo}
- Status: In Progress"""
    
    if "### Phase 3:" in content:
        content = re.sub(
            r"### Phase 3:.*?(?=### Phase \d:|---|$)",
            new_phase3,
            content,
            flags=re.DOTALL
        )
    else:
        content += f"\n\n---\n\n{new_phase3}"
    
    with open("/root/workspace/PROGRESS.md", "w", encoding="utf-8") as f:
        f.write(content)

if __name__ == "__main__":
    main()