import re
import sys

def format_dart(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    # dart format collapses simple arrays and widgets if they don't have trailing commas.
    # It expands them if they do.
    
    # 1. Remove trailing comma from single element list (colors: [..., ...],)
    content = re.sub(r'colors:\s*\[([^\]]+)\]\,', r'colors: [\1]', content)

    # 2. Make sure there is no trailing comma for simple Icon
    content = re.sub(r'child:\s*const\s*Icon\(([^)]+)\),(\s*\n\s*)', r'child: const Icon(\1),\2', content)

    # 3. Ensure trailing commas on multiline constructor params if they somehow lost it
    # (Just a general pass, but we already removed the ones that Dart format might collapse)
    content = re.sub(r'shape:\s*RoundedRectangleBorder\(\s*borderRadius:\s*BorderRadius\.circular\(16\)\s*\,?\s*\)', 
                     r'shape: RoundedRectangleBorder(\n        borderRadius: BorderRadius.circular(16),\n      )', content)

    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content)

if __name__ == "__main__":
    format_dart(sys.argv[1])
