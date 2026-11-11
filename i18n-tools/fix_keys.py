#!/usr/bin/env python3
"""
Fix invalid and duplicate keys in ARB files and Dart files.
"""

import json
import os
from pathlib import Path

PROJECT_ROOT = Path("/root/workspace/dsh-Go")
PARTS_DIR = PROJECT_ROOT / "app" / "lib" / "l10n" / "parts"
LIB_ROOT = PROJECT_ROOT / "app" / "lib"

# Load manifest
with open(Path("/root/workspace/i18n-tools/manifest.json"), "r", encoding="utf-8") as f:
    MANIFEST = {item["id"]: item for item in json.load(f)}

# Key fixes mapping old_key -> new_key
KEY_FIXES = {
    '_movesexpressionslength_movesmotionslength': 'expressionsAndMotionsCount',
    'sectionlabel_page1count': 'sectionLabelPageCount',
    'unknown': 'separatorDot',  # This will be handled specially for duplicates
}

# For duplicate "unknown" keys, we need unique names per file
DUPLICATE_FIXES = {
    'app_lib_ui_forum_forum_search_page_dart:184:18': 'separatorDot',
    'app_lib_ui_forum_forum_search_page_dart:190:18': 'separatorDot2',
    'app_lib_ui_forum_forum_topic_page_dart:226:18': 'separatorDot3',
    'app_lib_ui_forum_forum_topic_page_dart:232:16': 'separatorDot4',
    'app_lib_ui_forum_forum_widgets_dart:240:16': 'separatorDot5',
    'app_lib_ui_pets_pet_bubble_dart:99:20': 'separatorDot6',
    'app_lib_ui_web_web_view_page_dart:1337:10': 'separatorDot7',
}

def load_arb(file_path):
    if not file_path.exists():
        return {}
    with open(file_path, "r", encoding="utf-8") as f:
        return json.load(f)

def save_arb(file_path, data):
    with open(file_path, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
        f.write("\n")

# Fix ARB files
for lang_file in PARTS_DIR.glob("*.arb"):
    data = load_arb(lang_file)
    modified = False
    
    # Create new data with fixed keys
    new_data = {}
    for key, value in data.items():
        # Check if this key needs fixing
        if key in KEY_FIXES:
            new_key = KEY_FIXES[key]
            new_data[new_key] = value
            modified = True
            print(f"Fixed key in {lang_file.name}: {key} -> {new_key}")
        else:
            new_data[key] = value
    
    if modified:
        save_arb(lang_file, new_data)

# Fix Dart files
for item in MANIFEST.values():
    if item['status'] == 'done' and 'key' in item:
        finding_id = item['id']
        new_key = item['key']
        old_key = None
        
        # Find old key from KEY_FIXES or DUPLICATE_FIXES
        for old_k, new_k in KEY_FIXES.items():
            if new_k == new_key:
                old_key = old_k
                break
        if not old_key and finding_id in DUPLICATE_FIXES:
            old_key = 'unknown'  # All duplicates were 'unknown'
        
        if old_key:
            file_path = LIB_ROOT / item["file"].replace("app/lib/", "")
            if file_path.exists():
                content = file_path.read_text(encoding="utf-8")
                # Replace l10n.old_key with l10n.new_key
                old_call = f"l10n.{old_key}"
                new_call = f"l10n.{new_key}"
                if old_call in content:
                    content = content.replace(old_call, new_call)
                    file_path.write_text(content, encoding="utf-8")
                    print(f"Fixed Dart call in {file_path}: {old_call} -> {new_call}")

print("Key fixes applied")