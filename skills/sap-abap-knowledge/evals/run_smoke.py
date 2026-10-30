#!/usr/bin/env python3
"""run_smoke.py -- offline regression for the sap-abap-knowledge skill.

Reads evals/golden-set.yaml and, for every case, asserts:
  1. the routed reference file exists under the skill root;
  2. each keyword in expected_contains occurs in that file.

No network, no SAP connection, no LLM needed -- the routing table is the
contract. Exit code 0 = all pass, 1 = at least one failure.

Usage:  python3 evals/run_smoke.py [skill_root]
        (defaults to the skill root, i.e. the parent of this file's parent)
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

# Windows consoles often default to cp1252; force UTF-8 so CJK output survives.
for _stream in (sys.stdout, sys.stderr):
    if hasattr(_stream, "reconfigure"):
        _stream.reconfigure(encoding="utf-8", errors="replace")

SKILL_ROOT = Path(__file__).resolve().parents[1]


def parse_golden(path: Path):
    """Minimal parser for the specific YAML shape used in golden-set.yaml:
    a list of mappings with scalar values and lists of scalars. Avoids a
    PyYAML dependency so the regression can run anywhere."""
    items, cur = [], None
    in_key = None
    for raw in path.read_text(encoding="utf-8").splitlines():
        line = raw.rstrip()
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        if line.startswith("- question:"):
            if cur:
                items.append(cur)
            cur = {"question": line.split(":", 1)[1].strip().strip('"')}
            in_key = None
            continue
        if cur is None:
            continue
        stripped = line.strip()
        if stripped.startswith("- "):
            # list item under the current key
            val = stripped[2:].strip().strip('"')
            cur.setdefault(in_key, []).append(val)
            continue
        if ":" in stripped:
            key, _, val = stripped.partition(":")
            key = key.strip()
            val = val.strip()
            if val.startswith("["):
                # inline array, e.g. ["a", "b"]  (valid JSON once stripped)
                try:
                    cur[key] = json.loads(val)
                except json.JSONDecodeError:
                    cur[key] = [v.strip().strip('"') for v in
                                val[1:-1].split(",") if v.strip()]
                in_key = None
            else:
                val = val.strip('"')
                if val in ("", "[]"):
                    cur[key] = []
                    in_key = key
                else:
                    cur[key] = val
                    in_key = None
    if cur:
        items.append(cur)
    return items


def main() -> int:
    root = Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else SKILL_ROOT
    golden = root / "evals" / "golden-set.yaml"
    if not golden.exists():
        print(f"FAIL: missing eval file {golden}", file=sys.stderr)
        return 1

    cases = parse_golden(golden)
    if not cases:
        print("FAIL: no cases parsed from golden-set.yaml", file=sys.stderr)
        return 1

    failures = []
    for i, case in enumerate(cases, 1):
        route = case.get("route", "")
        q = case.get("question", f"case {i}")
        if not route:
            failures.append((i, q, "missing route field"))
            print(f"[{i:02d}] FAIL  {q}  ->  no route", file=sys.stderr)
            continue
        target = root / route
        if not target.exists():
            failures.append((i, q, f"missing file {route}"))
            print(f"[{i:02d}] FAIL  {q}  ->  file missing: {route}", file=sys.stderr)
            continue
        text = target.read_text(encoding="utf-8", errors="replace")
        missing_kw = [k for k in case.get("expected_contains", [])
                      if k not in text]
        if missing_kw:
            failures.append((i, q, f"keywords not in {route}: {missing_kw}"))
            print(f"[{i:02d}] FAIL  {q}  ->  {route} missing {missing_kw}",
                  file=sys.stderr)
        else:
            print(f"[{i:02d}] PASS  {q}  ->  {route}")

    total = len(cases)
    if failures:
        print(f"\nRESULT: {total - len(failures)}/{total} pass, {len(failures)} fail",
              file=sys.stderr)
        return 1
    print(f"\nRESULT: {total}/{total} pass")
    return 0


if __name__ == "__main__":
    sys.exit(main())
