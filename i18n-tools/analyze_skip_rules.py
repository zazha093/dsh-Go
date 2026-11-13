#!/usr/bin/env python3
"""
Step A: Analyze skip rule accuracy
Check each rule's effectiveness and find false skips
"""

import json
import re
from pathlib import Path
from collections import Counter, defaultdict

# Load ledger
with open('/root/workspace/dsh-Go/i18n-tools/ledger.json', 'r', encoding='utf-8') as f:
    ledger = json.load(f)

# Widget-related contexts/properties
WIDGET_CONTEXTS = {
    'label', 'title', 'tooltip', 'hint', 'hinttext', 'placeholder', 
    'semantic', 'semanticlabel', 'description', 'subtitle', 'message',
    'error', 'warning', 'info', 'success', 'confirm', 'prompt',
    'text', 'button', 'dialog', 'menu', 'tab', 'snackbar',
    'header', 'footer', 'heading', 'caption', 'subtitle', 'message',
    'error', 'warning', 'info', 'success', 'confirm', 'prompt',
    'label', 'title', 'tooltip', 'hinttext', 'helpertext', 'errortext',
    'countertext', 'placeholder', 'semanticlabel', 'prefixtext', 'suffixtext',
    'text', 'label', 'title', 'hint', 'placeholder', 'semantic',
    'button', 'dialog', 'menu', 'tab', 'snackbar', 'tooltip',
    'header', 'footer', 'heading', 'caption', 'subtitle', 'message',
    'error', 'warning', 'info', 'success', 'confirm', 'prompt',
}

WIDGET_PROPERTIES = {
    'text', 'label', 'title', 'hinttext', 'helpertext', 'errortext',
    'countertext', 'placeholder', 'semanticlabel', 'prefixtext',
    'suffixtext', 'content', 'message', 'description', 'summary',
}

def is_widget_context(context: str, parent_property: str) -> bool:
    """Check if this string is in a widget-related context"""
    context_lower = context.lower()
    prop_lower = parent_property.lower() if parent_property else ''
    
    # Check context
    for kw in WIDGET_CONTEXTS:
        if kw in context_lower:
            return True
    # Check property
    if prop_lower in WIDGET_PROPERTIES:
        return True
    return False

def is_english_readable(text: str) -> bool:
    """Check if text has English readable words with spaces, starts with capital"""
    if not text or len(text.strip()) < 2:
        return False
    stripped = text.strip()
    # Has spaces and starts with uppercase
    if ' ' in stripped and stripped[0].isupper():
        return True
    # Has English words with spaces
    if re.search(r'[a-zA-Z]', stripped) and ' ' in stripped:
        return True
    return False

# Load ledger
with open('/root/workspace/dsh-Go/i18n-tools/ledger.json', 'r', encoding='utf-8') as f:
    ledger = json.load(f)

# Load keep.txt
with open('/root/workspace/dsh-Go/i18n-tools/keep.txt', 'r', encoding='utf-8') as f:
    keep_terms = set()
    for line in f:
        line = line.strip()
        if line and not line.startswith('#'):
            keep_terms.add(line.lower())

# Analyze skip rules
entries = ledger['entries']
print(f"Total entries: {len(entries)}")

# Count by status
status_counts = {}
for e in entries:
    s = e.get('status', 'unknown')
    status_counts[s] = status_counts.get(s, 0) + 1
print(f"Status counts: {status_counts}")

# Check each skip rule
skip_entries = [e for e in entries if e.get('status') == 'skip']
todo_entries = [e for e in entries if e.get('status') == 'todo']

print(f"\nSkip: {len(skip_entries)}, Todo: {len(todo_entries)}")

# Analyze widget positions
widget_skip = [e for e in skip_entries if is_widget_context(e.get('context', ''), e.get('parent_property', ''))]
widget_todo = [e for e in todo_entries if is_widget_context(e.get('context', ''), e.get('parent_property', ''))]

print(f"\nWidget position analysis:")
print(f"  Skip in widget pos: {len(widget_skip)}")
print(f"  Todo in widget pos: {len(widget_todo)}")

# Find false skips: items in widget positions that are English readable
false_skips = []
for e in widget_skip:
    text = e.get('text', '')
    if is_english_readable(text):
        # Check if in keep.txt
        text_lower = text.lower()
        in_keep = any(kw in text_lower for kw in set([k.lower() for k in []]))  # We'll check against keep.txt
        actually_in_keep = any(kw in text_lower for kw in ['deepseek', 'dsh', 'api', 'npm', 'plugin', 'flutter', 'dart', 'android', 'ios', 'linux', 'windows', 'macos', 'web', 'api', 'sdk', 'ide', 'ui', 'ux', 'json', 'xml', 'yaml', 'http', 'https', 'ssh', 'ssl', 'tls', 'vpn', 'dns', 'ip', 'tcp', 'udp', 'uuid', 'sha', 'aes', 'rsa', 'ecdsa', 'ed25519', 'base64', 'utf-8', 'ascii', 'iso', 'utc', 'gmt', 'ram', 'cpu', 'gpu', 'ssd', 'hdd', 'usb', 'hdmi', 'dp', 'wifi', 'bluetooth', 'nfc', 'qr', 'ar', 'vr', 'mr', 'xr', 'ai', 'ml', 'llm', 'nlp', 'cnn', 'rnn', 'gan', 'bert', 'gpt'])
        if not actually_in_keep:
            false_skips.append(e)

print(f"\nFalse skips (English readable in widget pos, not in keep.txt): {len(false_skips)}")

# Show sample false skips
print("\nSample false skips (first 20):")
for e in false_skips[:20]:
    print(f"  {e['id']} | {e['file']}:{e['line']} | {e['text'][:80]} | ctx={e['context'][:40]} | kind={e['kind']}")

# Analyze by rule - let's categorize skips
# We need to check which rule caused each skip
# Let's re-run the skip logic with rule tracking

print("\n=== Analyzing skip rules ===")

# Let's check specific problematic patterns
# Check for English readable in skip that are NOT in keep.txt
english_skip = [e for e in skip_entries if is_english_readable(e['text'])]
print(f"\nEnglish readable in skip: {len(english_skip)}")

# Sample some
print("\nSample English readable skips (first 30):")
for e in english_skip[:30]:
    print(f"  {e['id']} | {e['file']}:{e['line']} | {e['text'][:100]} | ctx={e['context'][:40]} | kind={e['kind']}")

# Check keep.txt coverage
keep_lower = {k.lower() for k in [
    'DeepSeek', 'DSH', 'API', 'npm', 'Plugin', 'Flutter', 'Dart', 'Android', 'iOS', 
    'Linux', 'Windows', 'macOS', 'Web', 'API', 'SDK', 'IDE', 'UI', 'UX', 'JSON', 
    'XML', 'YAML', 'HTTP', 'HTTPS', 'SSH', 'SSL', 'TLS', 'VPN', 'DNS', 'IP', 
    'TCP', 'UDP', 'UUID', 'SHA', 'AES', 'RSA', 'ECDSA', 'Ed25519', 'Base64', 
    'UTF-8', 'ASCII', 'ISO', 'UTC', 'GMT', 'RAM', 'CPU', 'GPU', 'SSD', 'HDD', 
    'USB', 'HDMI', 'DP', 'WiFi', 'Bluetooth', 'NFC', 'QR', 'AR', 'VR', 'MR', 'XR', 
    'AI', 'ML', 'LLM', 'NLP', 'CNN', 'RNN', 'GAN', 'BERT', 'GPT', 'GitHub', 'Flutter', 
    'Dart', 'Android', 'iOS', 'Linux', 'Windows', 'macOS', 'Web', 'API', 'SDK', 
    'IDE', 'UI', 'UX', 'JSON', 'XML', 'YAML', 'HTTP', 'HTTPS', 'SSH', 'SSL', 'TLS', 
    'VPN', 'DNS', 'IP', 'TCP', 'UDP', 'UUID', 'SHA', 'AES', 'RSA', 'ECDSA', 'Ed25519', 
    'Base64', 'UTF-8', 'ASCII', 'ISO', 'UTC', 'GMT', 'RAM', 'CPU', 'GPU', 'SSD', 
    'HDD', 'USB', 'HDMI', 'DP', 'WiFi', 'Bluetooth', 'NFC', 'QR', 'AR', 'VR', 'MR', 
    'XR', 'AI', 'ML', 'LLM', 'NLP', 'CNN', 'RNN', 'GAN', 'BERT', 'GPT'
]}

# Check which English skips are NOT in keep.txt
not_in_keep = []
for e in english_skip:
    text_lower = e['text'].lower()
    in_keep = any(kw in text_lower for kw in keep_terms)  # keep_terms from keep.txt
    if not in_keep:
        not_in_keep.append(e)

print(f"\nEnglish readable skips NOT in keep.txt: {len(not_in_keep)}")
print("Sample (first 30):")
for e in not_in_keep[:30]:
    print(f"  {e['id']} | {e['file']}:{e['line']} | {e['text'][:100]} | ctx={e['context'][:40]} | kind={e['kind']}")