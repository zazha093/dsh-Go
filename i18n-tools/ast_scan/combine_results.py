#!/usr/bin/env python3
"""
Combine results from Dart AST scanner and other scanners into a single literals.json
"""

import json
import sys
from pathlib import Path
from collections import defaultdict


def combine_results(dart_file: Path, others_file: Path, output_file: Path):
    """Combine two literals JSON files into one."""
    
    # Load Dart results
    with open(dart_file, 'r', encoding='utf-8') as f:
        dart_data = json.load(f)
    
    # Load others results
    with open(others_file, 'r', encoding='utf-8') as f:
        others_data = json.load(f)
    
    # Combine byFile dictionaries
    combined_by_file = {}
    
    # Add Dart results
    for file, items in dart_data.get('byFile', {}).items():
        combined_by_file[f"dart:{file}"] = items
    
    # Add other results
    for file, items in others_data.get('byFile', {}).items():
        combined_by_file[f"other:{file}"] = items
    
    # Calculate total
    total_literals = sum(len(items) for items in combined_by_file.values())
    
    # Create combined output
    output = {
        'timestamp': __import__('datetime').datetime.now().isoformat(),
        'totalLiterals': total_literals,
        'byFile': combined_by_file,
        'sources': {
            'dart': {
                'totalLiterals': dart_data.get('totalLiterals', 0),
                'files': len(dart_data.get('byFile', {}))
            },
            'others': {
                'totalLiterals': others_data.get('totalLiterals', 0),
                'files': len(others_data.get('byFile', {}))
            }
        }
    }
    
    with open(output_file, 'w', encoding='utf-8') as f:
        json.dump(output, f, ensure_ascii=False, indent=2)
    
    print(f"Combined results:")
    print(f"  Dart: {dart_data.get('totalLiterals', 0)} literals in {len(dart_data.get('byFile', {}))} files")
    print(f"  Others: {others_data.get('totalLiterals', 0)} literals in {len(others_data.get('byFile', {}))} files")
    print(f"  Total: {total_literals} literals in {len(combined_by_file)} files")
    print(f"  Output: {output_file}")


def main():
    if len(sys.argv) < 4:
        print("Usage: python3 combine_results.py <dart_file> <others_file> <output_file>")
        sys.exit(1)
    
    dart_file = Path(sys.argv[1])
    others_file = Path(sys.argv[2])
    output_file = Path(sys.argv[3])
    
    if not dart_file.exists():
        print(f"Error: Dart results file not found: {dart_file}")
        sys.exit(1)
    
    if not others_file.exists():
        print(f"Error: Others results file not found: {others_file}")
        sys.exit(1)
    
    combine_results(dart_file, others_file, output_file)


if __name__ == '__main__':
    main()