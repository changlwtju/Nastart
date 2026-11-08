#!/usr/bin/env python3
"""Check repository-local Markdown destinations without opening external URLs."""
from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from urllib.parse import unquote, urlsplit

ROOT = Path(__file__).resolve().parents[1]
LINK = re.compile(r"!?\[[^\]\n]*\]\((<[^>]+>|[^\s)]+)(?:\s+[^)]*)?\)")
REFERENCE = re.compile(r"^\s*\[[^\]]+\]:\s*(<[^>]+>|\S+)", re.MULTILINE)


def destinations(text: str):
    # Examples in fenced or inline code are not live links.
    text = re.sub(r"(?ms)^(```|~~~).*?^\1[^\n]*$", "", text)
    text = re.sub(r"`[^`\n]+`", "", text)
    yield from (m.group(1).strip("<>") for m in LINK.finditer(text))
    yield from (m.group(1).strip("<>") for m in REFERENCE.finditer(text))


def check():
    files = [ROOT / "README.md", ROOT / "PROGRESS.md", ROOT / "AGENTS.md"]
    files += sorted((ROOT / "docs").rglob("*.md"))
    files += [ROOT / area / "README.md" for area in ["ios", "agent", "cloud", "website", "scripts"]]
    missing = []
    checked = 0
    for source in files:
        if not source.is_file():
            missing.append({"source": str(source.relative_to(ROOT)), "target": "document itself missing"})
            continue
        for url in destinations(source.read_text(encoding="utf-8")):
            parts = urlsplit(url)
            if parts.scheme or parts.netloc or not parts.path:
                continue
            path = re.sub(r":\d+$", "", unquote(parts.path))
            target = (source.parent / path).resolve()
            try:
                target.relative_to(ROOT)
            except ValueError:
                # Private device evidence and external local files stay local.
                continue
            checked += 1
            if not target.exists():
                missing.append({"source": str(source.relative_to(ROOT)), "target": path})
    return {"documents": len(files), "localLinksChecked": checked, "missing": missing}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--json", action="store_true", help="print a machine-readable report")
    args = parser.parse_args()
    result = check()
    if args.json:
        print(json.dumps(result, ensure_ascii=False, indent=2))
    else:
        print(f"Checked {result['documents']} documents / {result['localLinksChecked']} local links")
        for item in result["missing"]:
            print(f"MISSING {item['source']} -> {item['target']}")
        print(f"Missing destinations: {len(result['missing'])}")
    return int(bool(result["missing"]))


if __name__ == "__main__":
    raise SystemExit(main())
