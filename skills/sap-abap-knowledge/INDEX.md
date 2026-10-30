# 完整主题索引（INDEX）

本索引把三套来源的**全部**知识文件列成一张表，便于快速定位。加载入口为 `SKILL.md` 路由表。

## 1. ABAP 语法与技术 — `references/abap/`

| # | 文件 | 主题 |
|---|---|---|
| 01 | `01_internal_tables.md` | 内表（Internal Tables） |
| 02 | `02_structures.md` | 结构（Structures） |
| 03 | `03_abap_sql.md` | ABAP SQL（SELECT/WHERE/CTE/表达式/内建函数） |
| 04 | `04_abap_object_orientation.md` | ABAP 面向对象 |
| 05 | `05_constructor_expressions.md` | 构造器表达式（NEW/VALUE/REDUCE/CONV/COND/CORRESPONDING…） |
| 06 | `06_dynamic_programming.md` | 动态编程 |
| 07 | `07_string_processing.md` | 字符串处理 |
| 08 | `08_eml_abap_for_rap.md` | ABAP EML（RAP） |
| 09 | `09_bits_and_bytes.md` | 位与字节（Bits & Bytes） |
| 10 | `10_abap_sql_hierarchies.md` | ABAP SQL 层级（Hierarchies） |
| 11 | `11_internal_tables_grouping.md` | 内表分组（GROUP BY / GROUP ITAB） |
| 12 | `12_amdp.md` | AMDP |
| 13 | `13_program_flow_logic.md` | 程序流控制 |
| 14 | `14_abap_unit_tests.md` | ABAP 单元测试 |
| 15 | `15_cds_view_entities.md` | CDS 视图实体 |
| 16 | `16_data_types_and_objects.md` | 数据类型与数据对象 |
| 17 | `17_sap_luw.md` | SAP 逻辑工作单元（LUW） |
| 18 | `18_dynpro.md` | Dynpro |
| 19 | `19_abap_for_cloud_development.md` | ABAP for Cloud Development |
| 20 | `20_selection_screens_lists.md` | 选择屏幕与列表 |
| 21 | `21_xml_json.md` | XML / JSON |
| 22 | `22_released_abap_classes.md` | 已发布 ABAP 类（Released ABAP Classes） |
| 23 | `23_date_and_time.md` | 日期与时间 |
| 24 | `24_builtin_functions.md` | 内建函数 |
| 25 | `25_authorization_checks.md` | 权限检查（AUTHORITY-CHECK） |
| 26 | `26_abap_dictionary.md` | ABAP 字典 |
| 27 | `27_exceptions.md` | 异常（Exceptions） |
| 28 | `28_regular_expressions.md` | 正则表达式 |
| 29 | `29_numeric_operations.md` | 数字运算 |
| 30 | `30_generative_ai.md` | 生成式 AI（Generative AI） |
| 31 | `31_where_conditions.md` | WHERE 条件 |
| 32 | `32_performance_notes.md` | 性能优化（Performance Notes） |
| 33 | `33_abap_release_news.md` | ABAP 版本新闻 |
| 34 | `34_oo_design_patterns.md` | OO 设计模式 |
| 35 | `35_badis.md` | BAdI |
| 36 | `36_rap_behavior_definition_language.md` | RAP 行为定义语言（BDL） |
| 37 | `37_logical_expressions_and_functions.md` | 逻辑表达式与函数 |
| — | `readme.md` | 全部 cheat sheet 概览、示例分支、使用说明 |

> `references/abap/src/` 存放可执行 ABAP 示例对象（abapGit 可导入），`references/abap/files/` 存放插图。

## 2. ABAP 7.4 / 7.5 新语法 — `references/abap-new-syntax/`

| 文件 | 内容 |
|---|---|
| `README.md` | 去重后精华：SELECT FIELDS、SEGMENT、COMMIT WORK AND WAIT、OpenSQL vs NativeSQL、REST 调用、/UI2/CL_JSON、Eclipse 快捷键、MIGO/MIRO 骨架、学习链接 |
| `ABAP 7.40 Quick Reference _ SAP Blogs.pdf` | 官方 7.40 快速参考 |
| `new-features-in-abap-7-4_614cccdc-1.pdf` | 官方 7.4 新特性 |

## 3. SAP 业务模块与实战 — `references/modules/`

| 文件 | 内容 |
|---|---|
| `abap-dev.md` | ABAP 开发：User Exit/SMOD/CMOD/BAdI/BTE/Enhancement Spot/Modification、调试 |
| `mm.md` | MM 采购与库存：采购订单、STO、科目确定、消息控制 |
| `sd.md` | SD 销售与分销：销售订单、定价、交货、开票、信贷、ATP/MTO |
| `fico.md` | FI/CO 财务：凭证过账、汇率、凭证分割、COPA、替换、自动付款 |
| `pp.md` | PP 生产计划：生产订单、BOM、工艺路线、MRP、可配置 BOM |
| `wm.md` | WM 仓库管理：转储单、转储需求、仓位、盘点 |
| `pm.md` | PM 工厂维护：设备、功能位置、维护订单、维护计划、序列号 |
| `qm.md` | QM 质量管理：检验批、使用决策、质量通知书、检验计划 |
| `vms.md` | VMS 车辆管理：IS-AUTO VELO 对象、IDoc 增强、SPRO 配置 |
| `integration.md` | 系统集成：PI/PO、IDoc、Proxy、OData、XML/JSON 排查 |
| `auth.md` | 权限：AUTHORITY-CHECK、角色、SU53、权限对象 |
| `print.md` | 打印：SmartForms、SAPscript、NACE 消息控制 |
| `reference-tables.md` | 全模块事务码、关键表、BAPI 速查 |
| `troubleshooting.md` | CASE-001 ~ CASE-015 完整根因分析 |

## 4. SAP ↔ AI 对接认证 — `references/authentication/`

| 文件 | 内容 |
|---|---|
| `README.md` | 认证参考总览与决策树 |
| `01-basic-auth.md` | Basic 认证 |
| `02-spnego.md` | SPNEGO |
| `03-x509-client-cert.md` | X.509 客户端证书 |
| `04-oidc-oauth2.md` | OIDC / OAuth2 |
| `05-edge-patterns.md` | 边界网关模式 |
| `06-client-patterns.md` | 客户端模式 |
| `07-odata-services.md` | OData 服务 |

## 5. 评测

- `evals/golden-set.yaml` — 源自原 sap-trench-skill 的 7 条评测问答（功能/实战类）。

## 关联执行型 Skill（独立目录）

| Skill | 目录 | 类型 |
|---|---|---|
| STO 调拨订单创建 | `../sap-sto-create/` | 执行型（写入，OData + Java/JCo） |
| 库存与可用性查询 | `../sap-stock-availability/` | 执行型（只读，REST2RFC） |
