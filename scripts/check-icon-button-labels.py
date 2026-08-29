from pathlib import Path
import re

ROOT = Path("lib/features")
missing = []
for path in ROOT.rglob("*.dart"):
    source = path.read_text(encoding="utf-8")
    start = 0
    while True:
        index = source.find("IconButton(", start)
        if index < 0: break
        depth, cursor, quote = 1, index + len("IconButton("), None
        while cursor < len(source) and depth:
            char = source[cursor]
            if quote:
                if char == "\\\\": cursor += 1
                elif char == quote: quote = None
            elif char in ("\\x27", "\\\""): quote = char
            elif char == "(": depth += 1
            elif char == ")": depth -= 1
            cursor += 1
        if not re.search(r"\\b(?:tooltip|semanticLabel)\\s*:", source[index:cursor]):
            missing.append(f"{path}:{source.count(chr(10), 0, index) + 1}")
        start = cursor
if missing:
    print("Icon-only controls missing tooltip or semanticLabel:")
    print("\\n".join(missing))
    raise SystemExit(1)
print("Icon-button accessibility scan passed.")