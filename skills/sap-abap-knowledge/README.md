# sap-abap-knowledge

统一的 SAP / ABAP **知识型 Skill** —— 把分散的三套来源整合为一个可一键复用的目录。

> 状态：已安装到 `~/.agents/skills/` 并实测触发正常（自动发现 + 加载 + 内容读取全通）。

## 这是什么

把以下三套来源合并进一个知识库：

| 来源 | 纳入内容 |
|---|---|
| 官方 SAP `abap-cheat-sheets` | 37 个 ABAP 语法主题 cheat sheet + 可执行示例（`src/`）+ 插图（`files/`） |
| `SAP-ABAP-7.5-syntax-main` | 7.4/7.5 新语法**去重后**的独有价值精华 + 2 份官方 PDF |
| `sap-functional-skill` 的 `sap-trench-skill` | 14 个业务模块参考 + 15 个实战排查案例 + 认证参考手册 |

## 覆盖范围（skill 说明）

对话中出现任何 SAP/ABAP 话题即触发，按四域路由：

| 域 | 覆盖内容 | 语言 | 位置 |
|---|---|---|---|
| **A. ABAP 语法与技术** | 内表、结构、ABAP SQL、OO、构造器表达式、动态编程、字符串处理、RAP/EML/BDL、AMDP、CDS、异常、单元测试、LUW、Dynpro、选择屏幕、Cloud Development、XML/JSON、日期时间、内建函数、权限检查、字典、性能、BAdI、OO 设计模式、生成式 AI、WHERE、正则、数字运算、发布类、版本新闻 | 英文 | `references/abap/` |
| **B. 7.4/7.5 新语法** | SELECT FIELDS、SEGMENT、COMMIT WORK AND WAIT、OpenSQL vs NativeSQL、REST 调用、JSON 转换、Eclipse 快捷键、MIGO/MIRO 骨架 | 中文 | `references/abap-new-syntax/` |
| **C. 业务模块与实战** | MM、SD、FI/CO、PP、WM、PM、QM、VMS、集成(PI/PO/IDoc/Proxy/OData)、权限、打印、事务码速查、15 个排查案例 | 中文 | `references/modules/` |
| **D. 对接认证** | Basic、SPNEGO、X.509、OIDC/OAuth2、边界网关、客户端模式、OData 服务 | 中文 | `references/authentication/` |

**主要触发关键词**：`SAP` `ABAP` `ECC` `S/4HANA` `BAdI` `BAPI` `IDoc` `OData` `Proxy` `STO` `AMDP` `CDS` `RAP` `EML` `BDL` `LUW`、常用事务码（`ME21N` `MIGO` `VA01` `VL01N` `FB01` `CO01` `LT01` `IW31` `QA01`）、`AUTHORITY-CHECK` `SU53`、ATP/MRP/BOM/定价/科目确定、以及任何表名/类名/模糊报错。

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

## 使用方法（skill 用法）

技能触发后按以下三步使用：

### 第 1 步：确定问题类型，从路由表选文件

| 用户问题示例 | 类型 → 加载文件 |
|---|---|
| *"MIGO 过账报 Serial number already exists 怎么解决？"* | C 实战 → `references/modules/troubleshooting.md` |
| *"SD 定价 PR00 条件类型找不到，根因？"* | C 模块 → `references/modules/sd.md` |
| *"IDoc 状态 51 排查思路"* | C 集成 → `references/modules/integration.md` |
| *"ABAP 7.5 的 SELECT FIELDS 怎么用？"* | B 新语法 → `references/abap-new-syntax/README.md` |
| *"CDS 视图里怎么定义 association？"* | A 语法 → `references/abap/15_cds_view_entities.md` |
| *"内表怎么按字段分组统计？"* | A 语法 → `references/abap/11_internal_tables_grouping.md` |
| *"OData 对接用 OAuth2 怎么配？"* | D 认证 → `references/authentication/04-oidc-oauth2.md` |
| *"BAdI 实现步骤"* | C 开发 → `references/modules/abap-dev.md` |
| *"STO 调拨订单的科目确定怎么配？"* | C 模块 → `references/modules/mm.md` |

> 完整映射见 `SKILL.md` 的 A/B/C/D 四区路由表；全部文件清单见 `INDEX.md`。

### 第 2 步：加载文件后组织答案

- **语法/技术类**（A、B 域）：直接引用 cheat sheet 中的语法说明 + 代码片段，标注版本差异。
- **业务/实战类**（C 域）：按以下五段结构输出 ——
  ```
  【问题定性】一句话说清是什么类型的问题
  【根本原因】为什么会发生（核心部分）
  【解决方案】分步骤，给出可执行操作
  【注意事项】版本差异/风险提示/相关对象
  【参考工具】排查时用到的事务码或调试方法
  ```
- **认证类**（D 域）：按对应认证方式的决策树给出逐步落地方案。

### 第 3 步：需要执行时，转交同级执行型 skill

本知识库**只读**，不含脚本/凭据/网络访问。需要写/查系统时使用同级执行型 skill。

## 关联执行型 Skill

相关的两个执行型 skill 在**同级目录**独立存放：

- `../_disabled/sap-sto-create/` — 通过 S/4HANA OData 创建 STO 调拨订单（写入，Python + Java/JCo，**已禁用**）
- `../_disabled/sap-stock-availability/` — 经 REST2RFC 只读查询库存、MD04、物料移动（只读，Python，**已禁用**）

## 评测

自检用例见 `evals/golden-set.yaml`（7 条问答，源自原 sap-trench-skill），可用来验证触发与路由是否正常。

## 来源与许可

- Cheat sheets：© SAP SE，[`SAP-samples/abap-cheat-sheets`](https://github.com/SAP-samples/abap-cheat-sheets)
- 模块/实战/认证：MIT，[`shrek-abaper/sap-functional-skill`](https://github.com/shrek-abaper/sap-functional-skill)
- 本合并产物：MIT —— 知识应该流动，不应该沉睡。
