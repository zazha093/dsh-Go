#!/usr/bin/env python3
"""
Generate histograms and analysis for i18n translation work.
Required by Phase 4 Step A.2 - Generate histograms first.
"""

import json
import re
from pathlib import Path
from collections import Counter, defaultdict
from typing import Dict, List, Tuple, Any

# Load ledger
with open('/root/workspace/dsh-Go/i18n-tools/ledger.json', 'r', encoding='utf-8') as f:
    ledger = json.load(f)

entries = ledger['entries']
todo_entries = [e for e in entries if e['status'] == 'todo']
skip_entries = [e for e in entries if e['status'] == 'skip']

print(f"Total entries: {len(entries)}")
print(f"Todo: {len(todo_entries)}")
print(f"Skipped: {len(skip_entries)}")
print()

# 1. Layer mapping
def get_layer(file_path: str) -> str:
    if file_path.startswith('lib/'):
        return 'dart'
    elif file_path.startswith('app/android/') and file_path.endswith('.kt'):
        return 'kotlin'
    elif file_path.startswith('app/android/') and file_path.endswith('.xml'):
        return 'xml'
    elif file_path.startswith('app/assets/') and (file_path.endswith('.js') or file_path.endswith('.ts') or file_path.endswith('.html')):
        return 'web'
    elif file_path.startswith('app/') and file_path.endswith('.json'):
        return 'json'
    elif file_path.startswith('app/') and file_path.endswith('.arb'):
        return 'arb'
    return 'other'

# 1. Todo per file top 30
print("=== 1. Todo per file (top 30) ===")
file_todo_counts = Counter(e['file'] for e in todo_entries)
for file_path, count in file_todo_counts.most_common(30):
    layer = get_layer(file_path)
    print(f"  {file_path}: {count} ({layer})")
print()

# 2. Todo per parent context
print("=== 2. Todo per parent context ===")
context_counts = Counter()
for e in todo_entries:
    ctx = e.get('context', 'unknown')
    context_counts[ctx] += 1
for ctx, count in context_counts.most_common():
    print(f"  {ctx}: {count}")
print()

# 3. Todo per top-level folder
print("=== 3. Todo per top-level folder ===")
folder_counts = Counter()
for e in todo_entries:
    parts = e['file'].split('/')
    top_folder = parts[0] if parts else 'unknown'
    folder_counts[top_folder] += 1
for folder, count in folder_counts.most_common():
    print(f"  {folder}: {count}")
print()

# 4. Top 5 files with most todo - show 5 examples each
print("=== 4. Top 5 files with most todo - 5 examples each ===")
top5_files = [f for f, _ in file_todo_counts.most_common(5)]
for file_path in top5_files:
    file_entries = [e for e in todo_entries if e['file'] == file_path]
    print(f"\n  File: {file_path} ({len(file_entries)} todo)")
    for e in file_entries[:5]:
        text = e['text'][:80]
        context = e['context'][:60]
        print(f"    L{e['line']}: {text} | ctx={context}")

print("\n=== 5. Skip rule analysis ===")
# Per rule analysis
rule_skip_counts = Counter()
for e in skip_entries:
    # We'd need to track which rule caused the skip - not directly available
    pass

print("\n=== 6. Todo by layer ===")
layer_counts = Counter()
for e in todo_entries:
    layer = get_layer(e['file'])
    layer_counts[layer] += 1
for layer, count in layer_counts.most_common():
    print(f"  {layer}: {count}")

print("\n=== 7. Todo by kind ===")
kind_counts = Counter()
for e in todo_entries:
    kind = e.get('kind', 'unknown')
    kind_counts[kind] += 1
for kind, count in kind_counts.most_common():
    print(f"  {kind}: {count}")

print("\n=== 8. Seed check ===")
seed_phrases = [
    "Engine parameters", "Runtime", "Subagent", "Agent loop", "Command execution",
    "Plugin inventory", "Permissions", "Read only", "Workspace write", "Full access",
    "Phone control", "Reads the screen and taps for you", "What you can do",
    "App rules", "Confirmation", "Lift limits", "Agent team", "Small", "Large",
    "Extra large", "Pets", "Native", "Automatic", "Notifications", "Voice input",
    "levels", "items", "min", "off limits", "Always ask", "Set up", "Background running",
    "Local engine", "Engine parameters"
]

print("Seed check (exact text search in ledger):")
for phrase in seed_phrases:
    found = False
    status = "NOT FOUND"
    file_loc = ""
    for e in entries:
        if phrase.lower() in e['text'].lower():
            found = True
            status = e['status']
            file_loc = f"{e['file']}:{e['line']}"
            break
    print(f"  {phrase}: {status} {file_loc}")

print("\n=== 8. Skip rule analysis ===")
# We need to add rule tracking to the ledger to do this properly
print("Note: Need to add rule tracking to ledger for per-rule analysis")

print("\n=== Done ===")