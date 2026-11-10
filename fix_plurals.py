#!/usr/bin/env python3
"""Fix plural forms in Thai ARB files - change =1/one/few/many to only other"""

import re
from pathlib import Path

def fix_plurals_in_file(file_path):
    """Fix plural forms in a single ARB file"""
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    original = content
    
    # Pattern to match plural with =1, one, few, many - replace with only other
    # Use non-greedy matching for the other clause to handle double braces
    def replace_plural(match):
        var = match.group(1)
        other_content = match.group(2)
        return f'{{{var}, plural, other{{{other_content}}}}}'
    
    # Match any plural pattern and replace with only other
    # This pattern matches: {var, plural, =1{...} other{...}} or {var, plural, =1{...} =2{...} other{...}} etc.
    # or {var, plural, one{...} other{...}} or {var, plural, few{...} other{...}} etc.
    # The =1{...} part may contain nested placeholders like {message}, {tokens}, etc.
    # We need a more sophisticated pattern that can handle nested braces in the =1 clause
    pattern = r'\{(\w+),\s*plural,\s*(?:(?:=\d+|one|few|many)\{(?:[^{}]|\{[^}]*\})*\}\s*)+other\{(.*?)\}\}'
    content = re.sub(pattern, replace_plural, content)
    
    # Also handle patterns where =1 clause has nested braces with placeholders
    # More aggressive pattern: match from {var, plural, to the closing }} of other
    def replace_plural_v2(match):
        full = match.group(0)
        # Extract var
        var_match = re.search(r'\{(\w+),', full)
        # Extract other content
        other_match = re.search(r'other\{((?:[^{}]|\{[^}]*\})*)\}', full)
        if var_match and other_match:
            var = var_match.group(1)
            other_content = other_match.group(1)
            return f'{{{var}, plural, other{{{other_content}}}}}'
        return full
    
    # Try the more aggressive pattern on remaining content
    pattern2 = r'\{\w+,\s*plural,\s*(?:(?:=\d+|one|few|many)\{(?:[^{}]|\{[^}]*\})*\}\s*)+other\{(?:[^{}]|\{[^}]*\})*\}\}'
    content = re.sub(pattern2, replace_plural_v2, content)
    
    if content != original:
        with open(file_path, 'w', encoding='utf-8') as f:
            f.write(content)
        return True
    return False

def main():
    thai_arb_dir = Path("/root/workspace/dsh-Go/app/lib/l10n/parts")
    fixed_count = 0
    
    for arb_file in thai_arb_dir.glob("*_th.arb"):
        if fix_plurals_in_file(arb_file):
            fixed_count += 1
    
    print(f"\nFixed {fixed_count} files")

if __name__ == "__main__":
    main()