# DRF Outbound（S4H → 外部系统）可复用知识套件

> 本套件沉淀自 **DRF 出站接口**的完整实现与改造实践，覆盖两类典型接口：
> **① BOM（主数据）出站**——对象级过滤、变更分析、批量取数、ECN 校验、消息映射、AIF 发送；
> **② 生产订单（事务数据）出站**——快照比对变更判定、标准 PP 映射、规则表过滤、SOAP 代理发送。
> 另含性能优化、ADT 激活踩坑修复与 DRF 框架契约/IMG 配置映射。
> 所有源码均已**脱敏**（客户特定类名/接口名/工厂/物料等替换为通用占位符），
> 提炼为**可迁移到任意 DRF 出站接口**的通用模式与模板。

## 目标读者

- 需要实现或改造 **SAP DRF（Data Replication Framework）出站接口**的 ABAP 开发者。
- 需要把 **S/4HANA 主数据/事务数据**（BOM、订单、批次、物料等）发送到 **外部系统**（ECMS/MES 等）的集成开发。
- 需要规避 DRF 出站常见坑：`FOR ALL ENTRIES` 空守卫、`CDOBJID` 偏移、ECN 过滤、AIF 分片、ADT 激活报错。

## 内容导航

| 文档 | 主题 | 适用场景 |
|---|---|---|
| [01_drf_outbound_architecture.md](01_drf_outbound_architecture.md) | DRF 出站**三层架构**：filter / out 适配层 / biz 单例 | 任何 DRF 出站接口的骨架搭建 |
| [02_drf_lifecycle_and_object_keys.md](02_drf_lifecycle_and_object_keys.md) | **生命周期**方法与对象键表类型、CDOBJID 解析 | 实现 `IF_DRF_OUTBOUND` 方法 |
| [03_bom_data_model_and_mapping.md](03_bom_data_model_and_mapping.md) | **BOM 表模型**与字段映射（header/items） | BOM / 结构化主数据映射 |
| [04_filter_object_level.md](04_filter_object_level.md) | **对象级过滤**：动态 SQL、存在性校验、stlnr 预查 | 实现 `IF_DRF_FILTER` |
| [05_ecn_validation.md](05_ecn_validation.md) | **ECN 校验**：AENR 状态、批量预加载 | 工程变更/有效期数据 |
| [06_aif_send.md](06_aif_send.md) | **AIF 发送**：SEND_WITH_PROXY、分片、错误五要素、必填校验 | 发送消息到外部系统 |
| [07_performance_patterns.md](07_performance_patterns.md) | **性能优化**：N+1→批量、双重查询统一、冗余移除 | 大数据量出站性能调优 |
| [08_adt_activation_errors.md](08_adt_activation_errors.md) | **ADT 激活报错**与修复（踩坑实录） | 任何 ABAP 类激活失败 |
| [09_drf_framework_contract.md](09_drf_framework_contract.md) | **框架契约**：`IF_DRF_OUTBOUND`/`IF_DRF_FILTER` 精确签名、IMG 配置映射、实现检查表 | 编码前读契约 / 编码后自查 |
| [10_manufacturing_order_outbound.md](10_manufacturing_order_outbound.md) | **生产订单出站模式**：快照比对变更判定、标准 PP 映射、规则表过滤、SOAP 代理 | 事务数据（订单）出站接口 |
| [11_filter_gate_and_stlnr_prefetch.md](11_filter_gate_and_stlnr_prefetch.md) | **filter 门控与 stlnr 预取**：read_complete_data 取数前置、runmod 兜底、内容扫描反模式 | read_complete_data 需用 filter 预查字段时 |
| [references/](references/README.md) | **在产参考源码（脱敏）**：9 个 DRF 出站实现类 + 过滤 CDS + 接口分析 | 对照真实 DRF 出站写法 |
| [templates/](templates/) | **脱敏可复用代码模板**：对象键、过滤、ECN 批量、AIF 发送 | 快速复制骨架 |

## 脱敏占位符约定

源码片段中出现的占位符，在**自己的项目**中替换为实际命名：

| 占位符 | 含义 | 本次项目实例 |
|---|---|---|
| `<CL_OUT>` | 框架适配层类（实现 `IF_DRF_OUTBOUND`） | `ZCL_DRF_REF_BOM_OUT` |
| `<CL_BIZ>` | 业务单例类（承载全部业务逻辑） | `ZCL_DRF_REF_BOM_CHANGE` |
| `<CL_FILTER>` | 过滤器类（实现 `IF_DRF_FILTER`） | `ZCL_DRF_REF_BOM_OUT_FLTR` |
| `<KEY_STRUCT>` | 对象键结构 | `bom_key_ty` |
| `<KEY_TABLE_TY>` | 对象键表类型（SORTED UNIQUE） | `key_table_ty` |
| `<FILTER_SEL_STRUCT>` | filter 的 selection structure | `ZMCN_BOM_DRF_FLTR_S` |
| `<AIF_NS>` | AIF 命名空间 | `ZDECMS` |
| `<AIF_IFNAME>` | AIF 接口名 | `ZO_PBOM` |
| `<AIF_IFVER>` | AIF 接口版本 | `1` |
| `<AIF_LOGICAL_PORT>` | AIF 逻辑端口（目标系统） | `ZECMSBOMOUT` |
| `<AIF_MSGID>` | 消息类 ID | `ZDCN_PBOM` |
| `<DEFAULT_WERKS>` | 默认工厂 | `Q511` |
| `<DEFAULT_STLAN>` | 默认 BOM 用途 | `1` |
| `<TARGET_SYS>` | 目标系统名 | `ECMS` |
| `<BO_TYPE_BOM>` | BOM 主对象类型 | `BILL_OF_MATERIAL` |

## 快速开始

1. 按 [01](01_drf_outbound_architecture.md) 搭建三层骨架（filter + out + biz）。
2. 按 [02](02_drf_lifecycle_and_object_keys.md) 实现生命周期方法与对象键解析。
3. 有目标数据结构则按 [03](03_bom_data_model_and_mapping.md) 做字段映射。
4. 按 [04](04_filter_object_level.md) 实现对象级过滤。
5. 发送消息按 [06](06_aif_send.md)。
6. 激活失败按 [08](08_adt_activation_errors.md) 排障。

## 目录结构

```
knowledge/
├── README.md                            # 本文件（总览 + 占位符约定）
├── 01_drf_outbound_architecture.md      # 三层架构
├── 02_drf_lifecycle_and_object_keys.md  # 生命周期 + 对象键
├── 03_bom_data_model_and_mapping.md     # BOM 表模型 + 字段映射
├── 04_filter_object_level.md            # 对象级过滤
├── 05_ecn_validation.md                 # ECN 校验
├── 06_aif_send.md                       # AIF 发送
├── 07_performance_patterns.md           # 性能优化模式
├── 08_adt_activation_errors.md          # ADT 激活报错修复
├── 09_drf_framework_contract.md         # 框架契约 + IMG 配置映射 + 检查表
├── 10_manufacturing_order_outbound.md   # 生产订单出站模式
├── 11_filter_gate_and_stlnr_prefetch.md # filter 门控与 stlnr 预取（read_complete_data 取数前置）
├── references/                          # 在产参考源码（脱敏）
│   ├── README.md                        # 参考库索引 + 脱敏说明
│   ├── ZCL_DRF_REF_PROCORD_OUT.abap      # 生产订单出站（主参考）
│   ├── ZCL_DRF_REF_PROCORD_FLTR.abap     # 生产订单过滤器
│   ├── ZCL_DRF_REF_PRODVER_OUT.abap      # 生产版本出站
│   ├── ZCL_DRF_REF_YMES_ACK_OUT.abap     # MES 回执
│   ├── ZCL_DRF_REF_BATCH_OUT.abap        # 批次出站
│   ├── ZCL_DRF_REF_GNEBATCH_OUT.abap     # GNE 批次出站
│   ├── ZCL_DRF_REF_MM_OUT_GMES.abap      # 物料 → GMES
│   ├── ZCL_DRF_REF_CEE_BATCH_OUT.abap    # CEE 批次出站
│   ├── ZCL_DRF_REF_LTSMMAS_OUT.abap      # LTS 物料出站
│   ├── DRF_Interfaces_pattern.md        # DRF 接口分析（通用模式叙述）
│   ├── cds ZP_S_PROCORD_FLT1.cds.txt # 过滤 CDS 视图 1（标准过程订单）
│   ├── cds ZP_S_PROCORD_FLT2.cds.txt # 过滤 CDS 视图 2（XStep/PI-sheet，已补齐）
│   └── bom_outbound/                    # BOM 出站交付（脱敏）
│       ├── ZCL_DRF_REF_BOM_CHANGE.abap      # 业务处理单例（中文版）
│       ├── ZCL_DRF_REF_BOM_CHANGE_EN.abap   # 业务处理单例（英文版）
│       ├── ZCL_DRF_REF_BOM_OUT.abap         # 框架适配层（IF_DRF_OUTBOUND）
│       ├── ZCL_DRF_REF_BOM_OUT_FLTR.abap # 对象级过滤器（IF_DRF_FILTER）
│       └── ZCL_DRF_REF_BOM_CHANGE_TEST.abap  # ABAP Unit 测试
└── templates/                           # 脱敏可复用代码模板
    ├── bom_key_ty.abap                  # 对象键表类型模板
    ├── filter_apply_filter.abap         # 对象级过滤模板
    ├── ecn_batch_snippet.abap           # ECN 批量预加载片段
    └── aif_send_snippet.abap            # AIF 发送片段
```
