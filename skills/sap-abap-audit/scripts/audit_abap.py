#!/usr/bin/env python3
"""audit_abap.py -- static audit engine for existing ABAP source.

Scans ABAP source files (or directories) and reports findings by severity,
each mapped to a rule id, a category and a knowledge-base reference under
the sibling sap-abap-knowledge skill.

Read-only, no SAP connection, no credentials, stdlib only.

Usage:
  python3 audit_abap.py <file|dir> [<file|dir> ...]
  python3 audit_abap.py <path> --json
  python3 audit_abap.py <path> --rule SELECT_ALL,COMMIT_IN_LOOP
  python3 audit_abap.py <path> --min-severity warn   # error|warn|info

Exit codes: 0 no findings (or only info), 2 warnings or worse, 3 errors.
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

# Windows consoles often default to cp1252; force UTF-8 so CJK output survives.
for _stream in (sys.stdout, sys.stderr):
    if hasattr(_stream, "reconfigure"):
        _stream.reconfigure(encoding="utf-8", errors="replace")

KNOWLEDGE_REL = "../sap-abap-knowledge/references"
SEV_RANK = {"error": 3, "warn": 2, "info": 1}
ABAP_EXTS = (".abap", ".clas.abap", ".prog.abap", ".inc.abap",
             ".intf.abap", ".include.abap", ".asbdef", ".asddls")


# --------------------------------------------------------------------------
# Rule definitions
# --------------------------------------------------------------------------
class Finding:
    __slots__ = ("rule", "severity", "category", "title", "message", "ref", "line")

    def __init__(self, rule, severity, category, title, message, ref, line):
        self.rule = rule
        self.severity = severity
        self.category = category
        self.title = title
        self.message = message
        self.ref = ref
        self.line = line

    def as_dict(self):
        return {
            "rule": self.rule, "severity": self.severity, "category": self.category,
            "title": self.title, "message": self.message, "ref": self.ref,
            "line": self.line,
        }


# Regexes used by rules
RE_SELECT_STAR = re.compile(r"\bSELECT\s+(?:[A-Za-z0-9_~*.]+\s+)*\*(?:\s|$)", re.I)
RE_SELECT_BEGIN = re.compile(r"^\s*SELECT\b(?!\s+(?:SINGLE|COUNT|OPTIONS|UP\s+TO))", re.I)
RE_TARGET = re.compile(r"\b(?:INTO|APPENDING)\b", re.I)
RE_LOOP = re.compile(r"^\s*(?:LOOP|DO|WHILE)\b", re.I)
RE_ENDLOOP = re.compile(r"^\s*(?:ENDLOOP|ENDDO|ENDWHILE)\b", re.I)
RE_COMMIT = re.compile(r"^\s*COMMIT\s+WORK\b(?!\s+AND\s+WAIT)", re.I)
RE_FAE = re.compile(r"\bFOR\s+ALL\s+ENTRIES\s+IN\s+@?(\w+)", re.I)
RE_DYN_SQL = re.compile(r"(?:WHERE\s*\(|SELECT\s*\(\s*[^)]*\)\s*FROM|"
                        r"OPEN\s+DATASET|EXEC\s+SQL|FROM\s*\(|GENERATE\s+SUBROUTINE)", re.I)
RE_SQL_IN_STRING = re.compile(r"'(?:SELECT|WHERE|FROM|DELETE|UPDATE|INSERT|TABLE)\b", re.I)
RE_CONCAT_OP = re.compile(r"&&")
RE_CONCAT = re.compile(r"\bCONCATENATE\b", re.I)
RE_TABLES = re.compile(r"^\s*TABLES\s*:", re.I)
RE_PERFORM = re.compile(r"^\s*PERFORM\b(?!\s*[A-Za-z0-9_]+\s*IN\s+PROGRAM)", re.I)
RE_MODIFY_INSERT = re.compile(r"^\s*(?:MODIFY|INSERT)\b.*\b(?:INDEX|WHERE)\b", re.I)
RE_APPEND_COLLECT = re.compile(r"^\s*(?:APPEND|COLLECT)\b", re.I)
RE_READ_INTO = re.compile(r"^\s*READ\s+TABLE\b.*\bINTO\b(?!\s*(?:TRANSPORTING|TABLE|LINE))", re.I)
RE_TODO = re.compile(r"\b(?:TODO|FIXME|XXX|HACK)\b", re.I)
RE_SENSITIVE_TABLE = re.compile(r"\b(?:USR0[1234]|USR02|AGR_\w+|SUCH\w+|AUTH\w+)\b", re.I)
RE_AUTH_CHECK = re.compile(r"\bAUTHORITY-CHECK\b", re.I)


def _strip_comment(line: str) -> str:
    """Remove inline comments (first `"` not inside a string literal)."""
    in_str = False
    for i, ch in enumerate(line):
        if ch == "'":
            in_str = not in_str
        elif ch == '"' and not in_str:
            return line[:i]
    return line


def _same_itab_guarded(window: str, itab: str) -> bool:
    """True if `window` (a few preceding source lines) contains an empty-guard
    that references the SAME internal table as the FOR ALL ENTRIES, i.e.
    `IF <itab> IS NOT INITIAL` / `<itab>[] IS NOT INITIAL` / `line_exists( <itab> )`.
    A guard on a DIFFERENT table (e.g. `IF lt_range IS NOT INITIAL`) does NOT
    protect `FOR ALL ENTRIES IN @lt_mast_lookup`, so it must not count."""
    itab_re = re.escape(itab)
    same_line = re.compile(
        rf"(?:{itab_re}\[?\]?\s+IS\s+NOT\s+INITIAL"
        rf"|IS\s+NOT\s+INITIAL[^\n]*\b{itab_re}\b"
        rf"|line_exists\s*\(\s*{itab_re}\b)", re.I)
    return bool(same_line.search(window))


def _is_comment(line: str) -> bool:
    """ABAP comment: blank line, or a line starting with `*` (classic program
    comment, incl. `*&` macro directives)."""
    s = line.lstrip()
    return s == "" or s.startswith("*")


def audit_source(text: str) -> list[Finding]:
    """Run all rules over a single ABAP source blob. Pure, no I/O."""
    findings: list[Finding] = []
    lines = text.splitlines()
    n = len(lines)

    # ---- contextual state ----
    loop_depth = 0
    seen_auth_check = False
    in_select = False
    select_lines: list[int] = []

    def finish_select(flag_if_no_into: bool) -> None:
        nonlocal in_select, select_lines
        if in_select:
            has_into = any(RE_TARGET.search(_strip_comment(lines[i - 1]))
                           for i in select_lines)
            if flag_if_no_into and not has_into:
                findings.append(Finding(
                    "SELECT_NO_INTO", "error", "correctness",
                    "SELECT 未带 INTO",
                    "SELECT 结果未读到目标（缺 INTO 或 INTO 缺失/被省略），可能引发运行时错误或整表读入。"
                    "应始终使用 `SELECT ... INTO [CORRESPONDING] TABLE @DATA(...)` 明确目标。",
                    f"{KNOWLEDGE_REL}/abap/03_abap_sql.md", select_lines[0]))
            in_select = False
            select_lines = []

    for idx, raw in enumerate(lines, 1):
        if _is_comment(raw):
            # TODO/FIXME can live in comments
            if RE_TODO.search(raw):
                findings.append(Finding(
                    "TODO_FIXME", "info", "quality",
                    "遗留标记 TODO/FIXME",
                    f"源码含遗留标记：{raw.strip()[:60]}",
                    f"{KNOWLEDGE_REL}/modules/abap-dev.md", idx))
            continue
        line = _strip_comment(raw)
        code = line.lstrip()
        upper = code.upper()

        # ---- loop depth ----
        if RE_LOOP.match(code):
            loop_depth += 1
        if RE_ENDLOOP.match(code):
            loop_depth = max(0, loop_depth - 1)

        # ---- SELECT handling ----
        if RE_SELECT_BEGIN.match(code):
            if RE_TARGET.search(code):
                in_select = False
                select_lines = []
            else:
                in_select = True
                select_lines = [idx]
            if RE_SELECT_STAR.search(code):
                findings.append(Finding(
                    "SELECT_ALL", "warn", "performance",
                    "SELECT * 全字段读取",
                    "`SELECT *` 会读取全部字段，增加传输量与开销；应只读所需列"
                    "（7.5 可用 `FIELDS col1, col2`）。",
                    f"{KNOWLEDGE_REL}/abap/03_abap_sql.md", idx))
        elif in_select:
            select_lines.append(idx)
            if RE_TARGET.search(code) or (code.rstrip().endswith(".")):
                finish_select(flag_if_no_into=True)
            elif idx - select_lines[0] > 25:
                finish_select(flag_if_no_into=True)
        # ENDSELECT also closes
        if re.match(r"^\s*ENDSELECT\b", code):
            finish_select(flag_if_no_into=True)

        # ---- FOR ALL ENTRIES without empty check ----
        m = RE_FAE.search(code)
        if m:
            itab = m.group(1)
            window = "\n".join(_strip_comment(lines[j - 1]) for j in range(max(1, idx - 15), idx))
            if not _same_itab_guarded(window, itab):
                findings.append(Finding(
                    "FOR_ALL_ENTRIES_NO_EMPTY_CHECK", "error", "correctness",
                    "FOR ALL ENTRIES 未先判空",
                    f"`FOR ALL ENTRIES IN {itab}` 前未见 `IF {itab}[] IS NOT INITIAL` / "
                    f"`line_exists`。内表为空时该语句会匹配全表，造成错误结果。",
                    f"{KNOWLEDGE_REL}/abap/31_where_conditions.md", idx))

        # ---- COMMIT inside loop ----
        if RE_COMMIT.match(code) and loop_depth > 0:
            findings.append(Finding(
                "COMMIT_IN_LOOP", "warn", "luw",
                "循环内 COMMIT WORK",
                "在 LOOP/DO/WHILE 内执行 COMMIT WORK（且未用 AND WAIT），破坏 LUW 原子性"
                "并产生额外 DB 往返；应移到循环外或改用 `COMMIT WORK AND WAIT`。",
                f"{KNOWLEDGE_REL}/abap/17_sap_luw.md", idx))

        # ---- dynamic SQL / injection ----
        if RE_DYN_SQL.search(code) or (RE_CONCAT_OP.search(code)
                                       and RE_SQL_IN_STRING.search(code)):
            findings.append(Finding(
                "DYNAMIC_SQL_CONCAT", "warn", "security",
                "动态 SQL / 拼接风险",
                "检测到动态 SQL 或字符串拼接构造语句，存在注入风险；应改用参数化"
                "（`@( )` 宿主表达式、`IN @itab`、`FOR ALL ENTRIES`）或严格白名单。",
                f"{KNOWLEDGE_REL}/abap/06_dynamic_programming.md", idx))

        # ---- legacy TABLES ----
        if RE_TABLES.match(code):
            findings.append(Finding(
                "TABLES_DECL", "warn", "modernization",
                "遗留 TABLES 声明",
                "`TABLES:` 为旧式全局工作区声明；应改用具名类型/结构（`TYPES` + `DATA`）"
                "或 `SELECT ... INTO @DATA(...)`。",
                f"{KNOWLEDGE_REL}/abap/02_structures.md", idx))

        # ---- PERFORM vs method ----
        if RE_PERFORM.match(code):
            findings.append(Finding(
                "PERFORM_LEGACY", "warn", "modernization",
                "遗留 PERFORM/FORM",
                "`PERFORM` 使用遗留 FORM 子程序；面向对象建议改为方法调用"
                "（类方法 / `->` 调用）。",
                f"{KNOWLEDGE_REL}/abap/04_abap_object_orientation.md", idx))

        # ---- MODIFY/INSERT in loop ----
        if RE_MODIFY_INSERT.match(code) and loop_depth > 0:
            findings.append(Finding(
                "MODIFY_INSERT_IN_LOOP", "warn", "performance",
                "循环内 MODIFY/INSERT",
                "在循环内逐行 MODIFY/INSERT 内表，可能退化为 O(n²)；应批量构建后一次"
                "`CORRESPONDING`/`VALUE` 赋值或按 key 排序后批量处理。",
                f"{KNOWLEDGE_REL}/abap/01_internal_tables.md", idx))

        # ---- CONCATENATE ----
        if RE_CONCAT.search(code):
            findings.append(Finding(
                "CONCATENATE_LEGACY", "info", "modernization",
                "CONCATENATE 可改字符串模板",
                "简单拼接可用字符串模板 `|...|`（`{var}`）替代 `CONCATENATE`，更可读。",
                f"{KNOWLEDGE_REL}/abap/07_string_processing.md", idx))

        # ---- APPEND / COLLECT ----
        if RE_APPEND_COLLECT.match(code):
            findings.append(Finding(
                "APPEND_COLLECT_LEGACY", "info", "modernization",
                "APPEND/COLLECT 可改构造器",
                "可用 `VALUE #( ... )` 构造器表达式批量赋值内表，避免逐行 APPEND/COLLECT。",
                f"{KNOWLEDGE_REL}/abap/05_constructor_expressions.md", idx))

        # ---- READ TABLE ... INTO vs field-symbol ----
        if RE_READ_INTO.match(code):
            findings.append(Finding(
                "WORKAREA_INSTEAD_OF_FS", "info", "performance",
                "READ TABLE INTO 建议 ASSIGNING",
                "读取到工作区会复制整行；若只读不改写，建议 `READ TABLE ... ASSIGNING <fs>`。",
                f"{KNOWLEDGE_REL}/abap/01_internal_tables.md", idx))

        # ---- line length ----
        if len(raw.rstrip("\n")) > 120:
            findings.append(Finding(
                "LINE_TOO_LONG", "info", "style",
                "行过长 (>120)",
                f"当前行 {len(raw.rstrip())} 字符，建议按可读性换行。",
                f"{KNOWLEDGE_REL}/abap/13_program_flow_logic.md", idx))

        # ---- authorization awareness ----
        if RE_AUTH_CHECK.search(code):
            seen_auth_check = True
        elif RE_SENSITIVE_TABLE.search(code) and not seen_auth_check:
            findings.append(Finding(
                "NO_AUTHORITY_CHECK", "info", "security",
                "敏感表读取未见 AUTHORITY-CHECK",
                "读取授权类/用户类表（USR/AGR/SUCH/AUTH 域），建议在访问前执行 "
                "`AUTHORITY-CHECK OBJECT ...` 并处理权限不足。",
                f"{KNOWLEDGE_REL}/abap/25_authorization_checks.md", idx))

    finish_select(flag_if_no_into=True)
    return findings


def audit_file(path: Path) -> tuple[list[Finding], str | None]:
    try:
        text = path.read_text(encoding="utf-8", errors="replace")
    except OSError as exc:
        return [], f"cannot read {path}: {exc}"
    return audit_source(text), None


def collect_targets(paths: list[str]) -> tuple[list[Path], list[str]]:
    files, errors = [], []
    for p in paths:
        path = Path(p)
        if path.is_file():
            files.append(path)
        elif path.is_dir():
            for f in sorted(path.rglob("*")):
                if f.is_file() and (f.suffix in (".abap", ".asbdef", ".asddls")
                                    or f.name.endswith((".clas.abap", ".prog.abap",
                                                       ".inc.abap", ".intf.abap"))):
                    files.append(f)
        else:
            errors.append(f"not found: {path}")
    return files, errors


def render(files, findings_by_file, use_json, min_sev):
    if use_json:
        report = {"summary": {"files": len(files),
                              "findings": sum(len(v) for v in findings_by_file.values())},
                  "files": {str(f): [x.as_dict() for x in v]
                            for f, v in findings_by_file.items()}}
        print(json.dumps(report, ensure_ascii=False, indent=2))
        return

    total = {"error": 0, "warn": 0, "info": 0}
    for f in files:
        fnd = findings_by_file.get(f, [])
        if not fnd:
            print(f"=== {f} ===\n  OK（无告警）\n")
            continue
        sev_counts = {"error": 0, "warn": 0, "info": 0}
        for x in fnd:
            sev_counts[x.severity] += 1
            total[x.severity] += 1
        print(f"=== {f} ===  E:{sev_counts['error']} W:{sev_counts['warn']} I:{sev_counts['info']}")
        for x in fnd:
            if SEV_RANK[x.severity] < SEV_RANK[min_sev]:
                continue
            mark = {"error": "E", "warn": "W", "info": "I"}[x.severity]
            print(f"  [{mark}] L{x.line:>4} {x.rule:<28} {x.title}")
            print(f"         {x.message}")
            if x.ref:
                print(f"         → {x.ref}")
        print()
    print(f"SUMMARY: {total['error']} error, {total['warn']} warning, {total['info']} info")


def main() -> int:
    ap = argparse.ArgumentParser(prog="audit_abap.py", description=__doc__)
    ap.add_argument("paths", nargs="+", help="ABAP source file(s) or directory(ies)")
    ap.add_argument("--json", action="store_true", help="emit JSON")
    ap.add_argument("--min-severity", default="info", choices=["error", "warn", "info"])
    ap.add_argument("--rule", default="", help="comma-separated rule-id filter")
    args = ap.parse_args()

    rule_filter = {r.strip().upper() for r in args.rule.split(",") if r.strip()}
    files, errors = collect_targets(args.paths)
    for e in errors:
        print(e, file=sys.stderr)
    if not files:
        print("no ABAP source found", file=sys.stderr)
        return 1

    findings_by_file = {}
    for f in files:
        fnd, err = audit_file(f)
        if err:
            print(err, file=sys.stderr)
            fnd = []
        if rule_filter:
            fnd = [x for x in fnd if x.rule in rule_filter]
        findings_by_file[f] = fnd

    render(files, findings_by_file, args.json, args.min_severity)

    # exit code: 3 any error, 2 any warn (>= min severity), else 0
    if any(x.severity == "error" for v in findings_by_file.values() for x in v):
        return 3
    if any(x.severity == "warn" for v in findings_by_file.values() for x in v):
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main())
