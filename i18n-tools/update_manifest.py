#!/usr/bin/env python3
"""
Update manifest.json with ledger entries so apply.py can process them.
Converts ledger entries to manifest format.
"""

import json
from pathlib import Path

# Load ledger
with open("/root/workspace/dsh-Go/i18n-tools/ledger.json", "r", encoding="utf-8") as f:
    ledger = json.load(f)

# Load existing manifest
with open("/root/workspace/i18n-tools/manifest.json", "r", encoding="utf-8") as f:
    manifest = json.load(f)

# Create a set of existing manifest IDs for quick lookup
existing_ids = {item["id"] for item in manifest}
print(f"Existing manifest entries: {len(existing_ids)}")

# Convert ledger entries to manifest format
new_entries = 0
updated = 0
for entry in ledger['entries']:
    # Create manifest ID from file and line (format: file:line:column)
    # The ledger has line but not column, so we'll use 0 for column
    manifest_id = f"{entry['file']}:{entry['line']}:0"
    
    # Check if already in manifest
    if manifest_id in existing_ids:
        # Update existing entry
        for item in manifest:
            if item["id"] == manifest_id:
                # Update status from ledger
                item["status"] = entry["status"]
                if "th_text" in entry:
                    # We'll need to handle Thai text separately
                    pass
                updated += 1
                break
    else:
        # Create new manifest entry
        new_entry = {
            "id": manifest_id,
            "file": entry["file"],
            "line": entry["line"],
            "text": entry["text"],
            "context": entry["context"],
            "kind": entry["kind"],
            "status": entry["status"],
            "pattern_type": entry.get("kind", "simple")
        }
        manifest.append(new_entry)
        existing_ids.add(manifest_id)
        new_entries += 1

print(f"Added {new_entries} new entries")
print(f"Updated {updated} existing entries")
print(f"Total manifest entries: {len(manifest)}")

# Save updated manifest
with open("/root/workspace/dsh-Go/i18n-tools/manifest.json", "w", encoding="utf-8") as f:
    json.dump(manifest, f, ensure_ascii=False, indent=2)

print("Manifest updated successfully!")