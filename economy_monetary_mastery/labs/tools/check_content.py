"""Check content/dayNN.md structure and sweep the course tree for secrets.

Usage (from labs/):  uv run python tools/check_content.py [day01 ...]
"""
import re
import sys
from pathlib import Path

COURSE = Path(__file__).resolve().parents[2]
INTEGRATION_DAYS = {6, 12, 18, 24, 30}
REQUIRED = ["## Why this matters", "## Core concepts", "## Worked example", "## Exercises",
            "## Anti-patterns / Common mistakes", "## Lab", "## Teardown", "## Journal prompt"]
INTEGRATION_EXTRA = ["## Checkpoint quiz", "## Answer key"]
SECRET_PATTERNS = [
    re.compile(r"AKIA[0-9A-Z]{16}"),
    re.compile(r"-----BEGIN [A-Z ]*PRIVATE KEY-----"),
    re.compile(r"(?i)(api[_-]?key|secret[_-]?key|secret)\s*[:=]\s*['\"]?(?!your-)[A-Za-z0-9/+]{20,}"),
]


def _section(text: str, heading: str) -> str:
    start = text.find(heading)
    if start < 0:
        return ""
    nxt = text.find("\n## ", start + len(heading))
    return text[start:nxt if nxt >= 0 else len(text)]


def check_day_file(path: Path, integration: bool) -> list[str]:
    text = path.read_text()
    errs = [f"missing heading '{h}'" for h in REQUIRED if h not in text]
    if integration:
        errs += [f"missing heading '{h}'" for h in INTEGRATION_EXTRA if h not in text]
    if "as of 2026-10" not in text:
        errs.append("missing 'as of 2026-10' stamp")
    ex = _section(text, "## Exercises")
    items = len(re.findall(r"^\d+\.\s", ex, re.M))
    hints, sols = ex.count("**Hint:**"), ex.count("**Solution sketch:**")
    minimum = 3 if integration else 5
    if items < minimum:
        errs.append(f"only {items} exercises (need >= {minimum})")
    if hints != items:
        errs.append(f"{items} exercises but {hints} **Hint:** markers")
    if sols != items:
        errs.append(f"{items} exercises but {sols} **Solution sketch:** markers")
    return errs


def scan_secrets(root: Path) -> list[str]:
    hits = []
    for f in root.rglob("*"):
        rel = f.relative_to(root).parts  # skip-parts are judged inside root, not the absolute path
        if not f.is_file() or any(p in rel for p in (".venv", ".cache", "__pycache__", ".git", "docs")):
            continue
        if f.name == ".env":  # the learner's own gitignored key file; never committed
            continue
        if f.suffix in {".csv", ".json", ".png", ".pyc"}:
            continue
        try:
            text = f.read_text()
        except UnicodeDecodeError:
            continue
        for pat in SECRET_PATTERNS:  # one hit per file is enough to flag it
            m = pat.search(text)
            if m:
                hits.append(f"{f}: {m.group(0)[:40]}")
                break
    return hits


def main(argv: list[str]) -> int:
    files = sorted((COURSE / "content").glob("day[0-9][0-9].md"))
    if argv:
        files = [f for f in files if f.stem in argv]
    bad = 0
    for f in files:
        errs = check_day_file(f, integration=int(f.stem[3:]) in INTEGRATION_DAYS)
        print(f"{f.stem} OK" if not errs else f"{f.stem} FAIL: " + "; ".join(errs))
        bad += bool(errs)
    secrets = scan_secrets(COURSE)
    for s in secrets:
        print("SECRET?", s)
    return 1 if bad or secrets else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
