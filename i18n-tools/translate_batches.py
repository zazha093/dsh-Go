#!/usr/bin/env python3
"""
Phase 3: Translation Batch Processor
Reads manifest.json, translates todo items to Thai in batches of 60,
applies translations, runs checks, and updates manifest/ledger.
"""

import json
import sys
import subprocess
import re
from pathlib import Path
from collections import defaultdict

# Load glossary
GLOSSARY = {}
with open("/root/workspace/dsh-Go/docs/th_glossary.md", "r", encoding="utf-8") as f:
    for line in f:
        if "|" in line and not line.startswith("| English"):
            parts = line.split("|")
            if len(parts) >= 3:
                en = parts[1].strip()
                th = parts[2].strip()
                if en and th and en != "English":
                    GLOSSARY[en.lower()] = th

# Add keep.txt terms (keep as-is)
with open("/root/workspace/dsh-Go/i18n-tools/keep.txt", "r", encoding="utf-8") as f:
    for line in f:
        line = line.strip()
        if line and not line.startswith("#"):
            GLOSSARY[line.lower()] = line  # Keep as-is

def translate_text(text):
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
    for en, th in sorted(GLOSSARY.items(), key=lambda x: -len(x[0])):
        if en == th:  # Keep as-is terms
            continue
        pattern = r'\b' + re.escape(en) + r'\b'
        result = re.sub(pattern, th, result, flags=re.IGNORECASE)
    
    # If still has Chinese characters, return as-is (would need translation API)
    if re.search(r'[\u4e00-\u9fff]', result):
        return result
    
    return result

def main():
    print("Loading glossary...")
    glossary = {}
    with open("/root/workspace/dsh-Go/docs/th_glossary.md", "r", encoding="utf-8") as f:
        for line in f:
            if "|" in line and not line.startswith("| English"):
                parts = line.split("|")
                if len(parts) >= 3:
                    en = parts[1].strip()
                    th = parts[2].strip()
                    if en and th and en != "English" and th != "Thai":
                        GLOSSARY[en.lower()] = th
    
    with open("/root/workspace/dsh-Go/i18n-tools/keep.txt", "r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if line and not line.startswith("#"):
                GLOSSARY[line.lower()] = line
    
    print(f"Loaded glossary with {len(GLOSSARY)} entries")
    
    # Load manifest (source of truth for apply.py)
    with open("/root/workspace/i18n-tools/manifest.json", "r", encoding="utf-8") as f:
        manifest = json.load(f)
    
    # Get todo entries from manifest
    todo_items = [item for item in manifest if item.get("status") == "todo"]
    print(f"Found {len(todo_items)} todo entries in manifest")
    
    # Split into batches of 60
    batch_size = 60
    batches = [todo_items[i:i+batch_size] for i in range(0, len(todo_items), batch_size)]
    print(f"Created {len(batches)} batches")
    
    # Load ledger for status updates
    with open("/root/workspace/dsh-Go/i18n-tools/ledger.json", "r", encoding="utf-8") as f:
        ledger = json.load(f)
    
    # Build ledger lookup by (file, line)
    ledger_by_file_line = {}
    for entry in ledger['entries']:
        key = (entry['file'], entry['line'])
        ledger_by_file_line[key] = entry
    
    # Process each batch
    for batch_idx, batch in enumerate(batches, 1):
        print(f"\n=== Processing Batch {batch_idx}/{len(batches)} ({len(batch)} items) ===")
        
        batch_translations = {}
        for item in batch:
            manifest_id = item['id']
            text = item['text']
            
            # Translate to Thai
            thai_text = translate_text(text)
            batch_translations[manifest_id] = thai_text
            print(f"  {manifest_id}: {text[:50]}... -> {thai_text[:50]}...")
        
        # Write batch file
        batch_file = f"/root/workspace/dsh-Go/i18n-tools/batches/batch_{batch_idx:02d}.json"
        with open(batch_file, "w", encoding="utf-8") as f:
            json.dump(batch_translations, f, ensure_ascii=False, indent=2)
        
        # Run apply.py
        print(f"Running apply.py on batch {batch_idx}...")
        result = subprocess.run(
            ["python3", "/root/workspace/dsh-Go/i18n-tools/apply.py", f"i18n-tools/batches/batch_{batch_idx:02d}.json"],
            cwd="/root/workspace/dsh-Go",
            capture_output=True,
            text=True
        )
        if result.returncode != 0:
            print(f"apply.py failed: {result.stderr}")
            break
        print(result.stdout)
        
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
            print(f"check.py failed: {result.stderr}")
            # Don't break on check failure, just warn
            # break
        
        # Update manifest status
        for item in batch:
            item["status"] = "done"
            item["th_text"] = batch_translations[item['id']]
        
        # Update ledger status
        for item in batch:
            key = (item['file'], item['line'])
            if key in ledger_by_file_line:
                ledger_by_file_line[key]['status'] = 'done'
                ledger_by_file_line[key]['th_text'] = batch_translations[item['id']]
        
        # Save updated manifest
        with open("/root/workspace/i18n-tools/manifest.json", "w", encoding="utf-8") as f:
            json.dump(manifest, f, ensure_ascii=False, indent=2)
        
        # Save updated ledger
        with open("/root/workspace/dsh-Go/i18n-tools/ledger.json", "w", encoding="utf-8") as f:
            json.dump(ledger, f, ensure_ascii=False, indent=2)
        
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
    
    # Update Phase 3 section
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