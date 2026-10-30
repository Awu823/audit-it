# sap-abap-knowledge

统一的 SAP / ABAP **知识型 Skill** —— 把分散的三套来源整合为一个可一键复用的目录。

## 这是什么

把以下三套来源合并进一个知识库：

| 来源 | 纳入内容 |
|---|---|
| 官方 SAP `abap-cheat-sheets` | 37 个 ABAP 语法主题 cheat sheet + 可执行示例（`src/`）+ 插图（`files/`） |
| `SAP-ABAP-7.5-syntax-main` | 7.4/7.5 新语法**去重后**的独有价值精华 + 2 份官方 PDF |
| `sap-functional-skill` 的 `sap-trench-skill` | 14 个业务模块参考 + 15 个实战排查案例 + 认证参考手册 |

## 安装（一键复用）

把整个 `sap-abap-knowledge` 目录复制到任意智能体的 skill 目录即可：

```bash
# 例如 OpenCode / Claude Code
cp -r skills/sap-abap-knowledge ~/.agents/skills/
```

Claude Code / OpenCode 会在对话启动时自动发现并加载。检测到任何 SAP/ABAP 话题即自动触发，无需手动调用。

## 目录结构

```
sap-abap-knowledge/
├── SKILL.md                     # 触发层 + 主题→文件路由表（双语）
├── INDEX.md                     # 全部知识文件的完整索引
├── README.md                    # 本说明
├── evals/
│   └── golden-set.yaml          # 7 条评测问答（功能/实战）
└── references/
    ├── abap/                    # 官方 ABAP Cheat Sheets（37 主题，英文）
    │   ├── 01_internal_tables.md ... 37_logical_expressions_and_functions.md
    │   ├── readme.md            # cheat sheet 总览
    │   ├── files/               # 插图
    │   └── src/                 # 可执行 ABAP 示例（abapGit 可导入）
    ├── abap-new-syntax/         # ABAP 7.4/7.5 新语法精华（去重后）
    │   ├── README.md
    │   └── *.pdf                # 官方 7.40 快速参考 / 7.4 新特性
    ├── modules/                 # SAP 业务模块与实战（中文）
    │   ├── abap-dev.md  mm.md  sd.md  fico.md  pp.md  wm.md  pm.md
    │   ├── qm.md  vms.md  integration.md  auth.md  print.md
    │   ├── reference-tables.md  troubleshooting.md
    └── authentication/         # SAP ↔ AI 对接认证参考
        ├── README.md
        └── 01-basic-auth.md ... 07-odata-services.md
```

## 使用方法

1. 对话中出现 SAP/ABAP 话题 → 技能自动触发。
2. 从 `SKILL.md` 路由表按问题类型选择对应文件优先加载。
3. 业务/实战类答案按 `【问题定性】→【根本原因】→【解决方案】→【注意事项】→【参考工具】` 结构输出。

## 关联执行型 Skill

本知识库**不含**脚本/凭据/网络访问。相关的两个执行型 skill 在**同级目录**独立存放：

- `../sap-sto-create/` — 通过 S/4HANA OData 创建 STO 调拨订单（写入）
- `../sap-stock-availability/` — 经 REST2RFC 只读查询库存、MD04、物料移动（只读）

## 来源与许可

- Cheat sheets：© SAP SE，[`SAP-samples/abap-cheat-sheets`](https://github.com/SAP-samples/abap-cheat-sheets)
- 模块/实战/认证：MIT，[`shrek-abaper/sap-functional-skill`](https://github.com/shrek-abaper/sap-functional-skill)
- 本合并产物：MIT —— 知识应该流动，不应该沉睡。
