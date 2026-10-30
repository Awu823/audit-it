#!/usr/bin/env python3
"""run_audit_test.py -- offline regression for the sap-abap-audit skill.

Audits evals/sample_issues.abap and asserts the expected findings fire
(rule id + line), guarding against regressions in the rule engine.

Usage:  python3 evals/run_audit_test.py
Exit:   0 all expected findings present, 1 otherwise.
"""
from __future__ import annotations

import sys
from pathlib import Path

for _stream in (sys.stdout, sys.stderr):
    if hasattr(_stream, "reconfigure"):
        _stream.reconfigure(encoding="utf-8", errors="replace")

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts"))
import audit_abap  # noqa: E402

# (rule_id, line_number) expected to fire on evals/sample_issues.abap
EXPECTED = [
    ("TABLES_DECL", 6),
    ("TODO_FIXME", 13),
    ("SELECT_ALL", 15),
    ("SELECT_NO_INTO", 17),
    ("SELECT_ALL", 17),
    ("SELECT_ALL", 21),
    ("SELECT_NO_INTO", 21),
    ("MODIFY_INSERT_IN_LOOP", 25),
    ("COMMIT_IN_LOOP", 26),
    ("FOR_ALL_ENTRIES_NO_EMPTY_CHECK", 31),
    ("CONCATENATE_LEGACY", 35),
    ("WORKAREA_INSTEAD_OF_FS", 37),
    ("PERFORM_LEGACY", 39),
    ("DYNAMIC_SQL_CONCAT", 41),
    ("NO_AUTHORITY_CHECK", 43),
]

# These should NOT fire (false-positive guards) on the same sample
NOT_EXPECTED = [
    ("SELECT_NO_INTO", 15),   # has INTO on same line
    ("SELECT_NO_INTO", 43),   # has INTO TABLE
    ("COMMIT_IN_LOOP", 15),   # not in a loop
]


def main() -> int:
    sample = ROOT / "evals" / "sample_issues.abap"
    if not sample.exists():
        print(f"FAIL: missing sample {sample}", file=sys.stderr)
        return 1
    findings = audit_abap.audit_source(sample.read_text(encoding="utf-8"))
    fired = {(x.rule, x.line) for x in findings}

    missing = [e for e in EXPECTED if e not in fired]
    unwanted = [e for e in NOT_EXPECTED if e in fired]

    for rule, line in EXPECTED:
        mark = "PASS" if (rule, line) in fired else "FAIL"
        print(f"[{mark}] {rule} @ L{line}")
    for rule, line in NOT_EXPECTED:
        mark = "FAIL" if (rule, line) in fired else "PASS"
        print(f"[{mark}] (should NOT fire) {rule} @ L{line}")

    if missing or unwanted:
        print(f"\nRESULT: FAIL  missing={missing} unwanted={unwanted}", file=sys.stderr)
        return 1
    print(f"\nRESULT: PASS  ({len(EXPECTED)} expected fired, {len(NOT_EXPECTED)} no-false-positive)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
