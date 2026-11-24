# 开发者关键信息摘要

> 来源：FS_CN_MA_Production BOM Interface From S4H to ECMS (Functional Specification v1.0)
> 用途：给开发/集成工程师快速抓取实现要点，已剔除文档管理、模板、语言、测试等干扰内容。

---

## 1. 接口概览

| 项目 | 值 |
|---|---|
| 接口名 | BOM SAP to ECMS interface |
| 方向（相对 S4H） | **Outbound**（S4H → Middleware → ECMS） |
| 业务对象 | Production Bill of Materials (BOM) 主数据 |
| 触发方式 | 手动（DRFOUT）或基于变更指针的后台作业 |
| 频率 | 每晚 23:00 定时批量增量；支持按需手动执行 |
| 单次平均/峰值 | 300 / 1000 文档/天 |
| 端到端同步响应 | < 60 秒 |
| 中间件 | MuleSoft（仅做技术映射 message→message，值转换/过滤在 SAP 侧） |
| 目标系统 | ECMS（Electronic Customs Management System） |
| 站点 | RDSZ（Roche Diagnostics Suzhou） |

## 2. 架构与数据流

1. SAP 标准接口：**Bill of Material API (API_BILL_OF_MATERIAL_SRV; v=2)**，需按本 FS 增强。
2. XML 单文件最大 **2000 行**；超量需拆分为多批次 API 调用（例：3999 行 → 2000 + 1999）。
3. MuleSoft 将 API 消息转为 JSON 后发 ECMS；所有值转换/过滤在 SAP 完成。
4. 每次调用均有响应（成功/错误）回 S4H；监控通过 AIF 标准工具。
5. ECMS 负责多批次合并。

## 3. DRF / AIF 配置

| 组件 | 配置 |
|---|---|
| DRF Replication Model | `ZCN_ECMS` |
| DRF Outbound Implementation | `ZDCN_PBOM` |
| AIF Namespace | `ZDECMS` |
| AIF Interface Name | `ZO_PBOM` |
| AIF 附加选择条件 | Material (MATNR)、Plant (WERKS)、Bom usage (STLAN)、Alternative BOM Number (STLAL) |

对象键结构：Bill of materials type / Plant / Material / Bill of materials alternative / Engineering change number。

## 4. 触发类型与过滤条件

| 类型 | 触发 | 频率 | 过滤条件 |
|---|---|---|---|
| Initial（初始） | 手动 DRFOUT | 不相关 | Plant、Bom Usage |
| Scheduled Nightly Batch | 夜间作业 DRFOUT | 每晚 23:00 | Material、Plant、Bom Usage、Valid-To Date、Valid-From Date（API 模式 Change，含变更指针） |
| Manual Ad-Hoc | 手动 DRFOUT | 按需 | Material、Plant、Bom Usage、ECN、Valid-To Date、Valid-From Date |

DRF 选择参数（Selection parameter）：

| 字段 | 必填 | 数据元素 | 默认值 |
|---|---|---|---|
| MAST-WERKS | YES | WERKS_D | Q511 |
| MAST-MATNR | No | MATNR | — |
| MAST-STLAN | YES | STLAN | 1 |
| MAST-STLAL | No | STLAL | — |
| STKO-DATUV | No | DATUV | — |
| STKO-DATUB | No | DATUB | — |

## 5. 变更触发矩阵（BOM 变更 → 是否触发接口）

| 变更 | Update/Create BOM | ECN 必需 | 触发接口 | 备注 |
|---|---|---|---|---|
| Header: Base Quantity | U | Yes | Yes | STKO: BMENG, BMEIN |
| Header: valid-from date | U | Yes | Yes | STKO: DATUV |
| Header: valid-to date | U | Yes | Yes | STKO: DATUB |
| Item: component qty/UoM | U | Yes | Yes | STPO: MEINS, MENGE |
| Item: add/change/remove component | U | Yes | Yes | STPO 新增 |
| Item: component valid-from/to | U | Yes | Yes | STPO: DATUV, AENNR |
| Item: component scrap | U | Yes | Yes | STPO: AUSCH |
| Item: operation scrap | U | Yes | Yes | STPO: AVOAU |

变更对象键：BOM type / Plant / Material / BOM alternative / ECN。

## 6. ECN（工程变更号）处理逻辑

1. ECN 字段映射：从 STKO/STPO 提取 AENNR 与 DATUV，AENNR 作为 ChangeMasterID / ECN_Number 写入 outbound payload。
2. ECN 状态校验：过滤未释放/被阻塞的 ECN（检查 AENR）。
3. 未来生效日期：DRF 按目标评估日期（默认 SY-DATUM）提取；若 ECN 的 DATUV > SY-DATUM，显式传递 DATUV 以便目标系统本地排期切换。

## 7. 字段映射（源 API → 目标结构）

| ID | 源 API 字段 | 目标结构 | 类型 | M/O | 说明 |
|---|---|---|---|---|---|
| ID01 | MATERIAL | copExgNo | CHAR 40 | M | BOM Header 物料（含 FG/SEMI），MAST-MATNR |
| ID02 | COMPONENT_MATNR | copImgNo | CHAR 40 | M | BOM Item 物料/组件，STPO-IDNRK |
| ID03 | QUANTITY | decCm | DEC(13,3) | M | 组件数量，STPO-MENGE |
| ID04 | VALID_FROM | startDate | DATS 8 | O | 组件生效开始日期 YYYYMMDD，STPO-DATUV |
| ID05 | VALID_TO | endDate | DATS 8 | O | 组件生效结束日期 YYYYMMDD，STPO-DATUB |
| ID06 | BOM_CREATION | bomCreation | DATS 8 | O | BOM 创建日期，STKO-ANDAT |
| ID07 | ALTERNATIVE_BOM | alternativeBom | CHAR 2 | O | 备选 BOM 号，MAST-STLAL |
| ID08 | BOM_NO | bomNo | CHAR 8 | O | BOM 编号，MAST-STLNR |
| ID09 | CHANGE_NO | changeNo | CHAR 12 | O | 工程变更号，AENR-AENNR |
| ID10 | BOM_USAGE | useTo | CHAR 1 | O | BOM 用途，MAST-STLAN |
| ID11 | HEADER_START_DATE | bomStartDate | DATS 8 | O | BOM Header 生效开始 YYYYMMDD，STKO-DATUV |
| ID12 | HEADER_END_DATE | bomEndDate | DATS 8 | O | BOM Header 生效结束 YYYYMMDD，STKO-DATUB |
| ID13 | HEADER_QTY | copExgQty | DEC(13,3) | M | BOM Header 数量，STKO-BMENG |
| ID14 | HEADER_UNIT | copExgUnit | UNIT 3 | O | 成品/半成品 UoM，MARA-MEINS |
| ID15 | COMPONENT_UNIT | copImgUnit | UNIT 3 | O | 组件 UoM/海关单位，STPO-MEINS |
| ID16 | OPERATION_SCRAP | OperationScrap | DEC(5,2) | M | 工序损耗 % 或数量，STPO-AUSCH |
| ID17 | COMPONENT_SCRAP | ComponentScrap | DEC(5,2) | M | 组件损耗 % 或数量，STPO-KAUSF |

详细 XML→JSON 映射见关联文档 `FS_CN_DL_Production BOM to ECMS MW Attachment 0.2` 与 `FS_CN_MA_Production BOM interface to ECMS MW.docx`。

## 8. 数据访问与校验

- 无敏感/法律要求。
- 需要 MuleSoft 即时响应。
- 成功：消息经 MuleSoft 传递，无发送顺序要求。
- 失败：MuleSoft 或 MuleSoft→ECMS 失败。

## 9. 消息转换与富化

- 消息内容需与 ECMS 字段映射。
- ECMS 数据格式已捕获。
- 源字段 vs 目标字段映射在 MuleSoft 完成。
- XML 生成后需映射为 JSON（映射细节见 MW 文档）。

## 10. 确认与错误处理

错误需覆盖全流程：DRF 消息生成 → 发送 MuleSoft → MuleSoft 处理 → 发送 ECMS → ECMS 处理。

- 任一错误：S4H 必须收到错误码与详情（Production BOM、错误值等），并生成错误日志。
- MuleSoft 错误日志保留 21 天。
- 目标系统不允许在出错时修正消息内容。
- AIF 负责错误收集与分类，需可按以下维度分类：
  - ECMS 目标系统
  - 错误类型
  - Material
  - Plant
  - 字段与值（如相关）
- AIF 错误对象：Production BOM（必填）；附加对象：Parent Material (MATNR)、Plant (WERKS Q511)、Component Item (IDNRK)、ECN (AENNR)。
- 错误内容：错误码（技术码）、错误描述、错误详情（失败字段/值/技术信息）。
- **错误出现后，通过手动触发 DRFOUT 重发 Production BOM，而非在 AIF 中重处理消息。**

## 11. 监控（AIF）

- AIF 为 ERP 标准组件，提供接口监控与告警；重处理通过 DRFOUT 重执行而非 AIF 直接重处理。
- AIF 作为 Business 与 IT 的单一监控入口；集成返回 Green/Red（通过 MuleSoft 同步响应）。
- 支持批量/单条重处理失败消息，含重发 outbound 消息。
- 用户通知（邮件 + SAP 告警）包含：接口类型/名称、ECMS 源/目标、基于错误码的动态说明、GUID、/AIF/ERR 链接。
- 邮件路由依据：接口类型/名称、ECMS 源/目标、错误类型。

## 12. 授权

- 手动触发：DRF (DRF_OUT) 下基于 SAP Plant code (Auth Object: M_MATE_WRK) 授权。
- 需创建授权对象以限制 AIF 监控到字段级 — ECMS 目标系统。

## 13. 性能与运维

- E2E 同步响应 < 60 秒。
- 归档：不适用。
- 审计：完整审计历史记录于 DRF outbound 执行日志与 AIF 消息日志。
- 电子签名：不适用；ICFR：不适用。

## 14. 数据加载（站点上线）

- 本接口用于站点上线割接期数据加载：Yes。
- 站点：RDSZ；最小 300/天；最大 1000/天。

## 15. 错误场景（测试）

| 场景 | 预期 |
|---|---|
| 前台手动发送 (DRFOUT) | 复制到 Middleware → 发送 ECMS → 成功消息 → 日志记录 |
| 后台定时发送 (DRFOUT) | 同上 |
| 前台/后台失败 | 复制失败 → 错误消息 → 日志记录 |
| 重执行 (DRFOUT) | 成功复制 → 成功消息 → 日志记录 |

## 16. 关联文档

- CG_CN_XF ECMS Integration（AIF 核心配置、DRF/AIF 逻辑）
- FS_CN_DL_Production BOM interface to ECMS MW.docx（MW 映射）
- FS_CN_MA_Production BOM to ECMS MW Attachment 0.2（字段映射附件）
- SAP 帮助：API_BILL_OF_MATERIAL_SRV v2
