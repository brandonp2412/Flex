#!/usr/bin/env python3
import argparse
from pathlib import Path
import re
import sys

def validate(text):
    text = text.strip()
    if not text or len(text.encode("utf-16-le")) // 2 > 500:
        raise ValueError("Write 1–500 characters of user-facing release notes.")
    if text.casefold().strip(" •.-") in {"bug fixes and improvements", "maintenance and internal changes", "release notes", "tbd", "todo"}:
        raise ValueError("Describe actual changes, not a placeholder.")
    if any(re.match(r"^\s*(?:[-•]\s*)?(?:feat|fix|chore|ci|refactor|test|docs|build|perf|style)(?:\([^)]*\))?:", line, re.I) for line in text.splitlines()):
        raise ValueError("Rewrite commit subjects in plain English.")
    return text + "\n"

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("source", type=Path)
    parser.add_argument("destinations", nargs="*", type=Path)
    args = parser.parse_args()
    try:
        text = validate(args.source.read_text(encoding="utf-8"))
        for dest in args.destinations:
            dest.parent.mkdir(parents=True, exist_ok=True)
            dest.write_text(text, encoding="utf-8")
    except (ValueError, OSError) as error:
        print(f"Release notes: {error}", file=sys.stderr)
        return 1
    return 0

if __name__ == "__main__":
    sys.exit(main())
