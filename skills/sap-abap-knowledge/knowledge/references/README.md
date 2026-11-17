# references · 在产 DRF 出站参考源码（脱敏）

> 本目录是 `resource/` 在产 DRF 出站参考实现的**脱敏副本**，作为本套件的**源码级参考库**。
> 供实现/改造任意 DRF 出站接口时对照：生命周期写法、CDOBJID 解析、AIF 发送、字段映射、过滤、增量判断。

## 脱敏说明

原始源码为客户项目（`/RGS/` 命名空间）在产实现。脱敏处理：

| 项 | 原始 | 脱敏后 |
|---|---|---|
| 命名空间 | `/RGS/CL_...`、`/RGS/P_...` | 改为 `Z` 前缀（`ZCL_...`、`ZP_...`） |
| 类名 | `/RGS/CL_P_DCB_DRF_PROCORD_OUT` | `ZCL_DRF_REF_PROCORD_OUT` |
| AIF 接口配置 | `YPMES`/`YOMES_PO`/`YMESPOOUT` | `AIF_NS`/`AIF_IFNAME`/`AIF_LOGICAL_PORT`（+`_PV`/`_ACK` 变体） |
| 客户名/内部引用 | `Roche`、`ASPMAKE-xxxx`、`ticket xxxxxxxx` | `Customer`、删除 |
| 客户状态 | `YLCK` | `CUST_LOCK` |
| 客户字段前缀 | `ybc_*`/`ybm_*` | `cust_bc_*`/`cust_bm_*` |
| 作者签名 | `20250502-1809 StruzikP` | 删除 |
| changelog 表 | `* DD.MM.YYYY \| 状态 \| 作者 \| 说明` | 整行删除 |
| changelog 日期 | `20211209`、`14.11.2021`、`2021-12-09` | 删除（保留业务日期 `9999-xx-xx`） |
| ticket/change 号 | `3200023099`、`4300008501`、`CHG1073858`、`fix 4300008501` | 删除 |
| 作者名 | `Piotr Struzik`、`BENDALM1`、`BHOGIK` | 删除 |
| 文档头部 | `* Functional Spec: DS_0C_MA ...`、`* Technical Spec: FS_0C_MA ...`、`* Design Spec: ...`、`* Process: 4.3.2.2 ...` | 删除项目标识（`DS_0C_MA`/`FS_0C_MA`/`FS_US_MA` 等）与流程号（`4.3.2.2`/`13.9.1.20` 等），保留接口描述 |

> 保留业务对象名（如 `Zp_po_rt`、`ZP_S_PROCORD_FLT1`、`CL_PPINT_SOA_MFG_ORD_MAPPING`）——
> 它们描述业务含义，客户命名空间 `/RGS/` 统一改为标准 `Z` 前缀。SAP 标准对象（MAST/STKO/AFPO/...、`/AIF/SEND_WITH_PROXY`）原样保留。
> 注：这些参考源码**仅供阅读对照**，未做可编译保证（占位符常量如 `AIF_NS` 需在真实项目替换）。

## 文件清单

### 生产订单 → MES（主参考，本套件 01–08 的模式来源）
| 文件 | 角色 |
|---|---|
| `ZCL_DRF_REF_PROCORD_OUT.abap`（原 `CL_P_DCB_DRF_PROCORD_OUT`） | 生产订单出站（`IF_DRF_OUTBOUND`）：变更分析（变更指针 + 时间增量）、`BAPI_PROCORD_GET_DETAIL`、状态过滤、`CL_PPINT_SOA_MFG_ORD_MAPPING` 映射、AIF 发送 |
| `ZCL_DRF_REF_PROCORD_FLTR.abap`（原 `CL_P_DCB_DRF_PROCORD_FLTR`） | 生产订单过滤器（`IF_DRF_FILTER`）：两层动态 WHERE、CDS FLT1/FLT2、授权检查、NO_SEND 规则 |
| `cds ZP_S_PROCORD_FLT1.cds.txt` | 过滤用 CDS 视图 1（订单→操作→规则，标准过程订单） |
| `cds ZP_S_PROCORD_FLT2.cds.txt` | 过滤用 CDS 视图 2（XStep/PI-sheet 操作，`._OPER_COFT`，`#COMPOSITE`；已按 FLT1 字段集补齐） |

### 其它 DRF 出站参考（模式变体）
| 文件（脱敏后） | 接口 | 特点 |
|---|---|---|
| `ZCL_DRF_REF_PRODVER_OUT.abap` | 生产版本 → MES（PV+配方+BOM） | 变更指针按变更文档对象类解析（MATERIAL/PLAN/STUE/... 路径表）、PV 有效性、BOM 多版本取期 |
| `ZCL_DRF_REF_YMES_ACK_OUT.abap` | MES 回执（ACK） | 外部系统回执接收 |
| `ZCL_DRF_REF_BATCH_OUT.abap` | 批次 → MES | 批次主数据出站 |
| `ZCL_DRF_REF_GNEBATCH_OUT.abap` | GNE 批次 → MES | 批次出站（站点变体） |
| `ZCL_DRF_REF_MM_OUT_GMES.abap` | 物料 → GMES | 物料主数据出站（MATMAS） |
| `ZCL_DRF_REF_CEE_BATCH_OUT.abap` | CEE 批次 → MES | 批次出站（站点变体） |
| `ZCL_DRF_REF_LTSMMAS_OUT.abap` | LTS 物料 → MES | 物料主数据出站（LTSMMAS） |

### 分析文档
| 文件 | 内容 |
|---|---|
| `DRF_Interfaces_pattern.md` | DRF 接口分析（生产订单 + 生产版本两条链路的完整生命周期步骤、过滤机制、变更指针路径表、AIF 发送细节）——**通用模式的高价值叙述** |

### BOM 出站（本次改造交付，脱敏）
| 文件 | 角色 |
|---|---|
| `bom_outbound/ZCL_DRF_REF_BOM_CHANGE.abap` | BOM 出站**业务处理单例**（中文版，`IF_DRF_OUTBOUND` 框架适配层的业务逻辑）：变更分析、过滤、批量取数（MAST/STKO/STPO/ECN）、消息映射、AIF 发送、结果回写 |
| `bom_outbound/ZCL_DRF_REF_BOM_CHANGE_EN.abap` | 同上（**英文版**，与中文版同步） |
| `bom_outbound/ZCL_DRF_REF_BOM_OUT.abap` | BOM 出站**框架适配层**（`IF_DRF_OUTBOUND`）：委托给业务单例 |
| `bom_outbound/ZCL_DRF_REF_BOM_OUT_FLTR.abap` | BOM 出站**对象级过滤器**（`IF_DRF_FILTER`）：MAST 存在性校验 + 外部条件 AND 合并 |
| `bom_outbound/ZCL_DRF_REF_BOM_CHANGE_TEST.abap` | BOM 出站**ABAP Unit 测试**（OSQL 测试环境，MAST/STKO/STPO/MARA/AENR） |

> 说明：本分区是本次 BOM 出站改造的**交付实现**（对应本套件 01–08 讲解的模式），已按同规则脱敏（AIF 常量值 → `AIF_NS`/`AIF_IFNAME`/`AIF_LOGICAL_PORT`/`AIF_MSGID`，客户系统 `ECMS` → `TARGET_SYSTEM`，客户工厂 `Q511` → `DEFAULT_WERKS`，文档号/`FS §N` 交叉引用删除，`/RGS/` 引用 → `ZCL_DRF_REF_*`）。类名已按本套件约定统一为 `ZCL_DRF_REF_BOM_*`（剥除客户开发前缀，与参考类同一约定）；业务结构 `ZMCN_BOM_DRF_FLTR_S` 为 Z 命名空间交付对象，保留原名。

## 如何复用

1. **对照生命周期**：读 `DRF_Interfaces_pattern.md` 理解框架调用顺序（initialize → 变更分析 → filter → read_complete_data → map_data2message → send_message → finalize）。
2. **对照源码写法**：以 `ZCL_DRF_REF_PROCORD_OUT.abap` 为主参考，看它如何实现各方法、如何解析 CDOBJID、如何做状态过滤、如何发 AIF。
3. **取模式变体**：其它接口文件提供不同对象键（AUFNR / MATNR+WERKS+VERID / 批次）与不同变更指针路径的写法。
4. **配合主题文档**：本套件 [01](../01_drf_outbound_architecture.md)~[08](../08_adt_activation_errors.md) 提供架构/模式/坑的讲解，`templates/` 提供可复制骨架。

## 关联

- 主题讲解：[01 三层架构](../01_drf_outbound_architecture.md) ~ [08 ADT 激活报错](../08_adt_activation_errors.md)
- 可复用模板：[templates/](../templates/)
- 本次 BOM 出站改造的完整模式即脱敏自 `ZCL_DRF_REF_PROCORD_OUT` + `ZCL_DRF_REF_PROCORD_FLTR` 的同构思路（BOM 用 MAST/STKO/STPO 表，订单用 AFPO/AFVG/RESB 表）。