# sap-abap-audit

对已有 ABAP 源码做**只读静态审查**的技能。纯标准库、无编译、不连 SAP、无凭据。

## 是什么

扫描 ABAP 源文件（单个文件或整个目录），按**严重级别**（error / warn / info）输出发现项，
每条映射到规则 ID、类别，并给出知识库整改参考（`../sap-abap-knowledge/`）。

- **14 条规则**：正确性（SELECT 缺目标、FOR ALL ENTRIES 未判空）、性能（SELECT *、循环内
  COMMIT/MODIFY/INSERT、READ INTO vs ASSIGNING）、安全（动态 SQL 注入、敏感表无权限检查）、
  现代化（TABLES/PERFORM/CONCATENATE/APPEND）、质量（TODO/FIXME、行长）。
- **跨引用**：每条规则的整改提示指向 `sap-abap-knowledge/references/` 对应 cheat sheet / 模块参考。

## 用法

```bash
# 审查文件或目录
python3 scripts/audit_abap.py <file|dir>

# 机器可读
python3 scripts/audit_abap.py <file|dir> --json

# 过滤
python3 scripts/audit_abap.py <file|dir> --rule SELECT_ALL,COMMIT_IN_LOOP
python3 scripts/audit_abap.py <file|dir> --min-severity warn
```

退出码：`0` 无 error/warn；`2` 有 warn；`3` 有 error。

## 目录结构

```
sap-abap-audit/
├── SKILL.md                     # 触发描述 + 规则表 + 用法
├── README.md                    # 本说明
├── references/
│   ├── audit-checklist.md       # 人工复核清单（现象→后果→整改）
│   └── performance-optimization.md  # 性能优化参考（SELECT/FAE/内表/循环，来源见 Resource/）
├── scripts/
│   └── audit_abap.py            # 审计引擎（14 规则，纯标准库）
└── evals/
    ├── sample_issues.abap       # 带已知问题的样例（回归基准）
    └── run_audit_test.py        # 回归：断言预期发现项 + 防误报
```

## 自检

```bash
python3 evals/run_audit_test.py    # 15 条预期命中 + 3 条防误报
```

## 许可

MIT —— 知识应该流动，不应该沉睡。
