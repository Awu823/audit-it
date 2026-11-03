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
    ("SELECT_NO_WHERE", 15),
    ("SELECT_NO_INTO", 17),
    ("SELECT_ALL", 17),
    ("SELECT_NO_WHERE", 17),
    ("SELECT_ALL", 21),
    ("SELECT_NO_INTO", 21),
    ("MODIFY_INSERT_IN_LOOP", 25),
    ("COMMIT_IN_LOOP", 26),
    ("FOR_ALL_ENTRIES_NO_EMPTY_CHECK", 31),
    ("FAE_NO_DEDUP", 31),
    ("CONCATENATE_LEGACY", 35),
    ("WORKAREA_INSTEAD_OF_FS", 37),
    ("PERFORM_LEGACY", 39),
    ("DYNAMIC_SQL_CONCAT", 41),
    ("NO_AUTHORITY_CHECK", 43),
    ("SELECT_NO_WHERE", 43),
    ("SELECT_IN_LOOP", 50),
    ("STANDARD_TABLE_LINEAR_READ", 60),
    ("SORT_WITHOUT_KEY", 66),
    ("DECL_NOT_AT_TOP", 29),  # program-level decl after executable SELECT
    ("DECL_NOT_AT_TOP", 87),  # method-level decl after executable assignment
    ("INTO_NO_CORRESPONDING", 102),  # existing-typed INTO TABLE, explicit cols
    ("GET_RUN_TIME_COARSE", 116),    # legacy second-resolution timing
]

# These should NOT fire (false-positive guards) on the same sample
NOT_EXPECTED = [
    ("SELECT_NO_INTO", 15),   # has INTO on same line
    ("SELECT_NO_INTO", 43),   # has INTO TABLE
    ("COMMIT_IN_LOOP", 15),   # not in a loop
    ("SELECT_NO_WHERE", 21),  # has WHERE on next line -> no full-scan finding
    ("SELECT_NO_WHERE", 31),  # FAE select carries WHERE (L32) -> no finding
    ("FAE_NO_DEDUP", 6),      # no FOR ALL ENTRIES on this line
    ("SELECT_NO_WHERE", 54),  # JOIN-based select without WHERE -> JOIN filters
    ("STANDARD_TABLE_LINEAR_READ", 37),  # READ ... INDEX 1 -> INDEX excluded
    ("SORT_WITHOUT_KEY", 63), # explicit sort key (BY) -> no implicit-sort finding
    ("DECL_NOT_AT_TOP", 11),  # program decl in declaration part (top) -> no finding
    ("DECL_NOT_AT_TOP", 72),  # method decl at very top -> no finding
    ("DECL_NOT_AT_TOP", 80),  # inline DATA(...) exempt -> no finding
    ("DECL_NOT_AT_TOP", 94),  # decl at top of IF block -> no finding
    ("INTO_NO_CORRESPONDING", 105),  # SELECT * -> positional map is intended
    ("INTO_NO_CORRESPONDING", 108),  # inline @DATA(...) -> type derived, exempt
    ("INTO_NO_CORRESPONDING", 111),  # already uses CORRESPONDING FIELDS
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
