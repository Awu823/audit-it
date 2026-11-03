---
name: sap-abap-knowledge
description: |
  Use this skill whenever the user asks about any SAP/ABAP topic — a transaction code, table name, BAPI,
  function module, class, syntax keyword, module abbreviation, or vague error message is enough to trigger it.
  Do not skip it for "simple" ABAP questions.
  Covers: ABAP syntax & language (SQL, internal tables, OO, string processing, constructor expressions,
  dynamic programming, exceptions, regex, numeric operations, date/time, XML/JSON, AMDP, CDS view entities,
  RAP/EML/BDL, ABAP Unit tests, dynpro, selection screens, LUW, released classes, authorization checks,
  ABAP Dictionary, performance, BAdIs, OO design patterns, ABAP for Cloud Development, 7.4/7.5 new syntax);
  SAP business modules (MM, SD, FI/CO, PP, WM, PM, QM, VMS); system integration (PI/PO, IDoc, Proxy, OData);
  authorization (AUTHORITY-CHECK, SU53); print (SmartForms, SAPscript, NACE); real-project troubleshooting
  cases (CASE-001..015); and SAP<->AI authentication reference (Basic/SPNEGO/X.509/OIDC-OAuth2/gateway patterns).
  Trigger keywords: SAP, ABAP, ECC, S/4HANA, BAdI, BAPI, IDoc, OData, Proxy, STO, ME21N, MIGO, VA01, VL01N,
  FB01, CO01, LT01, IW31, QA01, SmartForms, NACE, SU53, AUTHORITY-CHECK, AMDP, CDS, RAP, EML, BDL, LUW,
  internal table, itab, select, insert, update, delete, modify, read table, loop at, field-symbol,
  constructor, value operator, reduce, for operator, corresponding, conv, new, cond, inline declaration,
  account determination, pricing procedure, delivery, ATP, MRP, BOM, production order, goods receipt,
  goods issue, WM transfer order, maintenance order, inspection lot, vehicle management, VELO, IS-AUTO,
  PI channel, Proxy class, error 51, dump analysis, performance tuning, ST05, SM50, SM66,
  big data, large table, internal table performance, nested loop, HASHED table, secondary table key,
  CL_ABAP_PARALLEL, parallel processing, FOR ALL ENTRIES, JOIN, benchmark, profiler.
  Do NOT use for: non-SAP ERP systems (Oracle EBS, Dynamics), generic SQL or database questions unrelated to SAP tables.
license: MIT
allowed-tools: [Read]
metadata:
  version: "1.0.0"
  type: docs
  valid_until: "evergreen"
  source_urls:
    - "https://github.com/SAP-samples/abap-cheat-sheets"
    - "https://help.sap.com"
    - "https://community.sap.com"
    - "https://github.com/benmeijs/ABAP_ITAB"
    - "https://github.com/pokrakam/abap_itab_perf"
---

# SAP ABAP Knowledge Skill

整合三套来源的 SAP/ABAP 知识库，装一个目录即可复用全部知识：

- **ABAP 语法/技术**：官方 SAP ABAP Cheat Sheets（37 个主题）+ ABAP 7.4/7.5 新语法精华
- **SAP 功能/实战**：14 个业务模块参考 + 15 个一线排查案例（CASE-001~015）
- **对接认证**：SAP ↔ AI 对接（CLI / MCP / OData）认证参考手册
- **性能 / 大数据量处理**（`references/large-data/`）：内表实测决策 + DB 侧写法 + 并行 + 剖析定位

## 使用方式

1. **判断问题类型**，从下表选择对应文件优先加载：

### A. ABAP 语法与技术（cheat sheets，英文）

| 主题 | 文件（`references/abap/`） |
|---|---|
| 内表 / 内表分组 | `01_internal_tables.md`, `11_internal_tables_grouping.md` |
| 结构 / 数据类型与对象 | `02_structures.md`, `16_data_types_and_objects.md` |
| ABAP SQL / SQL 层级 / WHERE 条件 | `03_abap_sql.md`, `10_abap_sql_hierarchies.md`, `31_where_conditions.md` |
| 面向对象 / OO 设计模式 | `04_abap_object_orientation.md`, `34_oo_design_patterns.md` |
| 构造器表达式 / 逻辑表达式与函数 | `05_constructor_expressions.md`, `37_logical_expressions_and_functions.md` |
| 动态编程 | `06_dynamic_programming.md` |
| 字符串处理 / 正则 / 数字运算 / 位与字节 | `07_string_processing.md`, `28_regular_expressions.md`, `29_numeric_operations.md`, `09_bits_and_bytes.md` |
| RAP / EML / BDL | `08_eml_abap_for_rap.md`, `36_rap_behavior_definition_language.md` |
| AMDP | `12_amdp.md` |
| 程序流控制 / 异常 | `13_program_flow_logic.md`, `27_exceptions.md` |
| ABAP 单元测试 | `14_abap_unit_tests.md` |
| CDS 视图实体 | `15_cds_view_entities.md` |
| SAP LUW / Dynpro / 选择屏幕与列表 | `17_sap_luw.md`, `18_dynpro.md`, `20_selection_screens_lists.md` |
| ABAP for Cloud Development / 发布类 / 版本新闻 | `19_abap_for_cloud_development.md`, `22_released_abap_classes.md`, `33_abap_release_news.md` |
| XML / JSON | `21_xml_json.md` |
| 日期与时间 / 内建函数 | `23_date_and_time.md`, `24_builtin_functions.md` |
| 权限检查 / ABAP 字典 | `25_authorization_checks.md`, `26_abap_dictionary.md` |
| 生成式 AI | `30_generative_ai.md` |
| 性能优化 / BAdI | `32_performance_notes.md`, `35_badis.md` |
| 性能 / 大数据量处理（内表实测 / DB 侧 / 并行 / 剖析工具） | `../large-data/internal-table-perf.md`, `../large-data/database-access.md`, `../large-data/parallel-processing.md`, `../large-data/profilers.md` |
| 全部 cheat sheet 概览与示例分支说明 | `readme.md` |

### B. ABAP 7.4 / 7.5 新语法精华（去重后）

| 内容 | 文件 |
|---|---|
| FIELDS 关键字、SEGMENT 函数、COMMIT WORK AND WAIT、OpenSQL vs NativeSQL、REST 调用、JSON 转换、Eclipse 快捷键、MIGO/MIRO 骨架、学习链接 | `references/abap-new-syntax/README.md` |
| 官方 PDF：ABAP 7.40 快速参考 / 7.4 新特性 | `references/abap-new-syntax/*.pdf` |

### C. SAP 业务模块与实战（中文）

| 问题类型 | 文件（`references/modules/`） |
|---|---|
| ABAP 开发 / 增强 / BAdI / 性能 / 消息 / 调试 | `abap-dev.md` |
| MM（采购/库存/物料/STO/科目确定） | `mm.md` |
| SD（销售订单/交货/定价/开票/信贷/ATP） | `sd.md` |
| FI/CO（凭证/科目/税务/COPA/凭证分割/汇率） | `fico.md` |
| PP（生产订单/BOM/工艺路线/MTO/ATP） | `pp.md` |
| WM（仓库管理/转储单/仓位/盘点） | `wm.md` |
| PM（工厂维护/设备/维护订单/维护计划） | `pm.md` |
| QM（质量管理/检验批/质量通知书） | `qm.md` |
| VMS（车辆管理/VELO/IDoc增强/IS-AUTO） | `vms.md` |
| 系统集成（PI/PO/IDoc/Proxy/OData/XML/JSON） | `integration.md` |
| 权限（AUTHORITY-CHECK/角色/SU53） | `auth.md` |
| 打印（SmartForms/SAPscript/NACE） | `print.md` |
| 事务码/表/BAPI 速查（全模块） | `reference-tables.md` |
| 报错排查/根因分析/真实案例（CASE-001~015） | `troubleshooting.md` |

### D. SAP ↔ AI 对接认证参考

| 内容 | 文件（`references/authentication/`） |
|---|---|
| 认证总览与决策树 | `README.md` |
| Basic 认证 | `01-basic-auth.md` |
| SPNEGO | `02-spnego.md` |
| X.509 客户端证书 | `03-x509-client-cert.md` |
| OIDC / OAuth2 | `04-oidc-oauth2.md` |
| 边界网关模式 | `05-edge-patterns.md` |
| 客户端模式 | `06-client-patterns.md` |
| OData 服务 | `07-odata-services.md` |

### E. 性能 / 大数据量处理（`references/large-data/`，GitHub 检索补充）

> 与 `references/abap/32_performance_notes.md`（官方 cheat sheet 逐条说明）互补：
> 32 号文档讲"怎么改"，本目录讲"大数据量场景怎么决策 + 实测数字 + 定位工具"。
> 来源：`benmeijs/ABAP_ITAB`（嵌套循环/内表类型实测）、`pokrakam/abap_itab_perf`
> （100 万次查找基准）、官方 `SAP-samples/abap-cheat-sheets`（32 号性能说明 + 可执行示例）。

| 问题类型 | 文件（`references/large-data/`） |
|---|---|
| 大内表嵌套循环 / HASHED vs SORTED vs STANDARD 决策 / 二级表键 / 内存管理 | `internal-table-perf.md` |
| 大表 SELECT 模式（只取所需列、WHERE 索引、JOIN、聚合下推）/ 大内表 JOIN（7.52+）/ 批量 UPDATE | `database-access.md` |
| 并行处理（CL_ABAP_PARALLEL）/ 大内表分块 / 后台 job 替代 / CDS push-down | `parallel-processing.md` |
| 性能剖析定位（ST05 / SAT / ABAP Trace / Memory Inspector）/ 官方推荐工具 / 定位流程 | `profilers.md` |

> 触发词：性能、优化、大表、千万行、大数据量、内表查找、嵌套循环、JOIN、FOR ALL ENTRIES、
> SELECT 慢、SQL 慢、内存、并行、CL_ABAP_PARALLEL、分块、后台 job、ST05、SAT、profiler、
> 定位瓶颈、运行时间、runtime、benchmark。

2. **加载对应文件后**，按以下结构组织答案（适用于业务/实战类）：

```
【问题定性】一句话说清是什么类型的问题
【根本原因】为什么会发生（核心部分）
【解决方案】分步骤，给出可执行操作
【注意事项】版本差异/风险提示/相关对象
【参考工具】排查时用到的事务码或调试方法
```

## 评测

自检用例见 `evals/golden-set.yaml`（源自原 sap-trench-skill 的 7 条评测问答）。

## 相关执行型 Skill（独立，不在此知识库内）

- `../_disabled/sap-sto-create` — 通过 S/4HANA OData 创建 STO 调拨订单（写入，Python + Java/JCo，**已禁用**）
- `../_disabled/sap-stock-availability` — 经 REST2RFC 只读查询库存 / MD04 / 物料移动（只读，Python，**已禁用**）
