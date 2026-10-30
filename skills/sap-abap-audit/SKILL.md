---
name: sap-abap-audit
description: |
  Use this skill when the user asks to review, audit, inspect, or statically check
  existing ABAP source code — e.g. "review this ABAP program", "audit this class",
  "check this report for issues", "帮我审查这段 ABAP 代码", "这个 include 有没有问题",
  "静态检查", "code review", "找潜在 bug / 性能 / 安全风险". Scans ABAP source
  (files or directories) and reports findings by severity (error/warn/info), each
  mapped to a rule id, a category and a knowledge-base reference for remediation.
  Covers: SELECT * / SELECT without INTO / SELECT without WHERE / SELECT inside
  loops, FOR ALL ENTRIES without empty check or without dedup, COMMIT WORK inside
  loops, dynamic SQL / injection risk, legacy TABLES / PERFORM / CONCATENATE /
  APPEND, READ TABLE INTO vs field-symbol, STANDARD-table linear key lookup,
  SORT without explicit key, MODIFY/INSERT in loops, missing AUTHORITY-CHECK on
  sensitive tables, TODO/FIXME markers, over-long lines.
  Do NOT use for: auditing non-ABAP languages (Java, JS, Python), or running the code
  (this is read-only static analysis — no compile, no SAP connection).
license: MIT
allowed-tools: [Read, Bash]
metadata:
  version: "1.0.0"
  type: static-analysis
  valid_until: evergreen
  permissions:
    read_paths: ["evals/", "scripts/"]
    can_spawn_processes: true
    requires_elevation: false
  output_schema:
    format: json
  mcp_hints:
    readOnlyHint: true
    destructiveHint: false
    idempotentHint: true
    openWorldHint: true
---

# SAP ABAP Audit Skill

对已有 ABAP 源码做**只读静态审查**，输出按严重级别分级的发现项，每条映射到规则 ID、
类别，并给出知识库（`../sap-abap-knowledge/`）的整改参考。纯静态、无编译、不连 SAP。

## 使用方式

```bash
# 审查单个文件或整个目录（递归 .abap / .clas.abap / .prog.abap / .inc.abap / .intf.abap / .asbdef / .asddls）
python3 scripts/audit_abap.py <file|dir>

# 机器可读 JSON
python3 scripts/audit_abap.py <file|dir> --json

# 只看某几条规则，或只看某级别及以上
python3 scripts/audit_abap.py <file|dir> --rule SELECT_ALL,COMMIT_IN_LOOP
python3 scripts/audit_abap.py <file|dir> --min-severity warn
```

退出码：`0` 无 error/warn；`2` 有 warning；`3` 有 error。

## 规则表（19 条）

| 规则 | 级别 | 类别 | 检测点 | 知识库参考 |
|---|---|---|---|---|
| `SELECT_ALL` | warn | performance | `SELECT *` 全字段读取 | `references/performance-optimization.md` |
| `SELECT_NO_INTO` | error | correctness | SELECT 缺目标子句（无 `INTO`/`APPENDING`） | `03_abap_sql.md` |
| `SELECT_NO_WHERE` | info | performance | SELECT 无 WHERE（全表读取，JOIN 除外） | `references/performance-optimization.md` |
| `SELECT_IN_LOOP` | warn | performance | 循环内 SELECT（含 SELECT SINGLE） | `references/performance-optimization.md` |
| `FOR_ALL_ENTRIES_NO_EMPTY_CHECK` | error | correctness | `FOR ALL ENTRIES` 前未判空 | `references/performance-optimization.md` |
| `FAE_NO_DEDUP` | info | performance | `FOR ALL ENTRIES` 内表未去重（SORTED/HASHED 除外） | `references/performance-optimization.md` |
| `COMMIT_IN_LOOP` | warn | luw | LOOP/DO/WHILE 内 `COMMIT WORK` | `17_sap_luw.md` |
| `DYNAMIC_SQL_CONCAT` | warn | security | 动态 SQL / 字符串拼接构造语句 | `06_dynamic_programming.md` |
| `TABLES_DECL` | warn | modernization | 遗留 `TABLES:` 声明 | `02_structures.md` |
| `PERFORM_LEGACY` | warn | modernization | 遗留 `PERFORM`/FORM | `04_abap_object_orientation.md` |
| `MODIFY_INSERT_IN_LOOP` | warn | performance | 循环内 `MODIFY`/`INSERT`（INDEX/WHERE 定位写） | `references/performance-optimization.md` |
| `CONCATENATE_LEGACY` | info | modernization | `CONCATENATE` 可改字符串模板 | `references/performance-optimization.md` |
| `APPEND_COLLECT_LEGACY` | info | modernization | `APPEND`/`COLLECT` 可改构造器 | `references/performance-optimization.md` |
| `WORKAREA_INSTEAD_OF_FS` | info | performance | `READ TABLE ... INTO` 建议 `ASSIGNING` | `references/performance-optimization.md` |
| `STANDARD_TABLE_LINEAR_READ` | info | performance | STANDARD 表 `READ TABLE ... WITH KEY` 线性查找 | `references/performance-optimization.md` |
| `SORT_WITHOUT_KEY` | info | performance | `SORT` 未显式指定排序键（隐式标准键） | `references/performance-optimization.md` |
| `NO_AUTHORITY_CHECK` | info | security | 敏感表读取未见 `AUTHORITY-CHECK` | `25_authorization_checks.md` |
| `TODO_FIXME` | info | quality | `TODO`/`FIXME`/`XXX` 遗留标记 | `modules/abap-dev.md` |
| `LINE_TOO_LONG` | info | style | 行 > 120 字符 | `13_program_flow_logic.md` |

> 规则为**启发式**行级检测，可能有个别误报/漏报；发现项用于**引导人工复核**，不是编译错误。
> 建议先跑 `--min-severity warn` 聚焦高价值问题。

## 输出格式

```
=== <文件> ===  E:0 W:1 I:2
  [W] L12 SELECT_ALL  SELECT * 全字段读取
        `SELECT *` 会读取全部字段...应只读所需列（7.5 可用 `FIELDS col1, col2`）。
        → ../sap-abap-knowledge/references/abap/03_abap_sql.md
SUMMARY: 0 error, 1 warning, 2 info
```

## 自检 / 回归

```bash
python3 evals/run_audit_test.py            # 对 evals/sample_issues.abap 断言预期发现项
```

## 关联知识库

- 规则整改参考指向 `../sap-abap-knowledge/references/`（ABAP 语法 cheat sheets + 模块实战），
  性能类规则指向技能自带的 `references/performance-optimization.md`（来源：
  Web 版 `Resource/abap-performance-optimization.md` + **GitHub 官方版** `Resource/abap-performance-notes-github.md`）。
- 需要更深入的代码逻辑梳理/onboarding，可参考环境的 `analyzing-programs`、`abap-logic-doc` 类技能。
