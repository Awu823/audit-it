# SAP Knowledge — 统一 Skill 集合

把分散的 SAP/ABAP 知识整理为**可复用**的 Skill 集合：**1 个知识型 skill + 2 个执行型 skill**。

## 当前状态

- ✅ 已整合并提交到 git（root-commit，290 文件）
- ✅ `skills/sap-abap-knowledge` 已安装到 `~/.agents/skills/` 并**实测触发正常**（自动发现 + 加载 + 内容读取全通）
- ✅ 原始三个仓库目录已删除，工作区只保留整合后的集合
- ✅ 凭据/缓存文件已通过 `.gitignore` 排除

## 结构

```
sap-knowledge/
├── README.md                          # 本说明
└── skills/
    ├── sap-abap-knowledge/            # ★ 知识型：ABAP 语法 + 7.4/7.5 新语法 + 14 模块功能 + 认证
    │   ├── SKILL.md                   #   触发路由表（双语）
    │   ├── INDEX.md                   #   完整主题索引
    │   ├── README.md
    │   ├── evals/golden-set.yaml
    │   └── references/
    │       ├── abap/                  #   官方 ABAP Cheat Sheets（37 主题 + 示例 + 插图）
    │       ├── abap-new-syntax/       #   7.4/7.5 新语法精华（去重）+ 2 份官方 PDF
    │       ├── modules/               #   14 个业务模块参考 + 15 个实战排查案例
    │       └── authentication/        #   SAP↔AI 对接认证参考
    ├── sap-sto-create/                # 执行型(写)：OData 创建 STO 调拨订单
    └── sap-stock-availability/        # 执行型(读)：REST2RFC 只读查询库存/可用性
```

## 快速开始

```bash
# 1) 知识库（装一个文件夹 = 全部知识可用；已安装并验证）
cp -r skills/sap-abap-knowledge ~/.agents/skills/

# 2) 执行型 skill（如需写/查功能）
cp -r skills/sap-sto-create ~/.agents/skills/
cp -r skills/sap-stock-availability ~/.agents/skills/
```

Claude Code / OpenCode 会自动发现并加载。对话中出现 SAP/ABAP 话题即触发。
`skills/sap-abap-knowledge` 已安装，其余两个执行型 skill 可按需安装。

## 数据来源

| 来源 | 去向 |
|---|---|
| 官方 `abap-cheat-sheets`（SAP-samples） | `sap-abap-knowledge/references/abap/` |
| `SAP-ABAP-7.5-syntax-main`（个人笔记） | `sap-abap-knowledge/references/abap-new-syntax/`（去重提炼） |
| `sap-functional-skill` 知识型 `sap-trench-skill` | `sap-abap-knowledge/references/modules/` + `authentication/` |
| `sap-functional-skill` 执行型 `sap-sto-create` / `sap-stock-availability` | `skills/sap-sto-create/`、`skills/sap-stock-availability/`（原样） |

## 版本控制

仓库已用 git 管理（分支 `master`）。提交说明见 `git log`。

```bash
git status        # 查看工作区状态
git log --oneline # 查看提交历史
```

## License

MIT —— 知识应该流动，不应该沉睡。
