# 09 · DRF 框架契约、IMG 配置映射与实现检查表

> 沉淀自 BOM 出站实现。覆盖 `IF_DRF_OUTBOUND` / `IF_DRF_FILTER` 的**精确方法签名**、
> **DRF IMG 配置活动 ↔ 代码映射**（DRF_001~012），以及实现完成后的**代码/配置/运行时三张检查表**。
> 所有类型/表名均为 SAP 标准 DRF 框架类型，可直接作为编码依据，无需脱敏。

## 1. `IF_DRF_OUTBOUND` —— 出站实现的唯一契约面

Public / Final 接口，属于 `CA-MDG-DRF` 应用组件，共 **12 个方法**（无 Event、无 local type）：

| # | 方法 | 种类 | 用途 | 是否必填 |
|---|---|---|---|---|
| 1 | `ANALYZE_CHANGES_BY_CHG_POINTER` | Instance | 按变更指针做变更分析 | 可选 |
| 2 | `ANALYZE_CHANGES_BY_MDG_CP` | Instance | 按 MDG 变更指针做变更分析 | 可选 |
| 3 | `ANALYZE_CHANGES_BY_OTHERS` | Instance | 按"其他参数"（初始/手动）做变更分析 | 可选 |
| 4 | `APPLY_NODE_INST_FILTER_MULTI` | Instance | 多对象应用节点实例过滤器 | 可选 |
| 5 | `APPLY_NODE_INST_FILTER_SINGLE` | Instance | 单对象应用节点实例过滤器 | 可选 |
| 6 | `BUILD_PARALLEL_PACKAGE` | Instance | 构建并行处理包 | 可选 |
| 7 | `ENRICH_FILTER_CRITERIA` | Instance | 追加外部过滤条件 | 可选 |
| 8 | `FINALIZE` | Instance | 收尾方法 | 可选 |
| 9 | `INITIALIZE` | **Static** | **初始化方法（静态！）** | **必填** |
| 10 | `MAP_DATA2MESSAGE` | Instance | 内部数据 → 消息映射 | **必填** |
| 11 | `READ_COMPLETE_DATA` | Instance | 批量读取完整数据 | **必填** |
| 12 | `SEND_MESSAGE` | Instance | 发送处理后的消息 | **必填** |

## 2. 关键方法签名（可直接作为编码依据）

### 2.1 `INITIALIZE`（静态方法，无异常）

```abap
INITIALIZE
  IMPORTING is_runtime_param       TYPE drf_s_runtime_parameter_ext
  EXPORTING eo_if_drf_outbound      TYPE REF TO if_drf_outbound
            es_runtime_param_out_impl TYPE drf_s_runtime_param_out_impl.
```
> 三个参数全部是 Import/Export，**没有 Changing**。必须回填 `es_runtime_param_out_impl-table_type_name` 指向对象键表类型。

### 2.2 `READ_COMPLETE_DATA`

```abap
READ_COMPLETE_DATA
  CHANGING  ct_relevant_objects TYPE SORTED TABLE
  EXCEPTIONS cx_drf_exception
             cx_drf_process_messages.
```

### 2.3 `MAP_DATA2MESSAGE`

```abap
MAP_DATA2MESSAGE
  IMPORTING ir_relevant_object TYPE REF TO data
  EXCEPTIONS cx_drf_exception
             cx_drf_process_messages.
```
> ⚠️ `ir_relevant_object` 类型是 **`REF TO data`**（通用引用），实现里必须用 `ASSIGN ir_relevant_object->* TO <ls_key>` 才能拿到具体结构。

### 2.4 `SEND_MESSAGE`

```abap
SEND_MESSAGE
  IMPORTING is_file_info     TYPE drf_s_file_info
            iv_object_count  TYPE drf_package_size
  CHANGING  ct_obj_rep_sta   TYPE drf_t_obj_rep_sta_full
  EXPORTING et_file_data     TYPE drf_t_file_oi_content
            et_message       TYPE drf_t_message
  EXCEPTIONS cx_drf_exception
             cx_drf_process_messages.
```

### 2.5 变更分析方法（`_BY_CHG_POINTER` / `_BY_MDG_CP` / `_BY_OTHERS`）

```abap
ANALYZE_CHANGES_BY_CHG_POINTER
  IMPORTING it_change_pointer TYPE drf_t_bdcp
  CHANGING  ct_changed_objects TYPE SORTED TABLE
  EXPORTING es_stat_info        TYPE drf_s_stat_info
  EXCEPTIONS cx_drf_analyze_changes
             cx_drf_exception.

ANALYZE_CHANGES_BY_OTHERS
  CHANGING  ct_changed_objects TYPE SORTED TABLE
  EXPORTING es_stat_info        TYPE drf_s_stat_info
  EXCEPTIONS cx_drf_analyze_changes
             cx_drf_exception.
```

### 2.6 `ENRICH_FILTER_CRITERIA`

```abap
ENRICH_FILTER_CRITERIA
  IMPORTING it_external_criteria    TYPE rsds_trange
  EXPORTING es_stat_info            TYPE drf_s_stat_info
            et_add_external_criteria TYPE rsds_trange.
```
> 框架**同时传入** `it_external_criteria`（当前已生效的外部条件）和 `es_stat_info`；实现把**新增**条件追加到 `et_add_external_criteria`。

### 2.7 `FINALIZE`（无异常）

```abap
FINALIZE
  IMPORTING it_erroneous_objects   TYPE SORTED TABLE
            it_relevant_objects     TYPE SORTED TABLE
            iv_repeated_initial_run TYPE boole_d
  EXPORTING ev_delete_change_pointer TYPE boole_d.
```

## 3. `IF_DRF_FILTER` —— 过滤契约

只有一个方法 `APPLY_FILTER`（12 个 Importing + 1 个 Exporting），异常为 `CX_DRF_FILTER_OBJECT`：

```abap
APPLY_FILTER
  IMPORTING it_unfiltered_objects TYPE SORTED TABLE
            iv_appl                TYPE drf_appl
            iv_business_system     TYPE mdg_business_system
            iv_outb_impl           TYPE drf_outb_impl
            iv_runmod              TYPE drf_runmod
            io_bal                 TYPE REF TO cl_drf_bal
            iv_dlmod               TYPE drf_dlmod
            is_c_fobj              TYPE drf_s_c_fobj_runtime
            is_filt                TYPE drf_s_c_filt_runtime
            it_external_criteria   TYPE rsds_trange
            is_additional_parameter TYPE drf_s_rtime_param_additional
  EXPORTING et_filtered_objects   TYPE SORTED TABLE
  EXCEPTIONS cx_drf_filter_object.
```
> 关键点：`is_c_fobj` / `is_filt` 是**框架下发的过滤器运行时配置**，`it_external_criteria` 是 `ENRICH_FILTER_CRITERIA` 追加的外部条件。在 `RUNMOD_BYPASS_FILTER` 场景下由框架先行过滤，业务实现不再重复过滤。

## 4. 运行时参数与常量

### 4.1 `DRF_S_RUNTIME_PARAMETER_EXT`（外部运行时参数）

| 字段 | 用途 |
|---|---|
| `business_system` | 目标业务系统（接收端） |
| `appl` | 应用标识，传给过滤器 |
| `outb_impl` | 出站实现标识，传给过滤器 |
| `runmod` | 运行模式，决定是否重复过滤 |
| `bal` | DRF 的 Application Log 对象（`REF TO cl_drf_bal`） |
| `dlmod` | 服务操作的 Processing Mode |

### 4.2 `IF_DRF_CONST` 常用常量（已确认）

| 常量 | 值 | 用途 |
|---|---|---|
| `msg_type_info` / `msg_type_warning` / `msg_type_error` / `msg_type_success` | `'I'/'W'/'E'/'S'` | 应用日志消息类型 |
| `drf_s_stat_info` 的 `object_count_out` | — | 变更分析输出对象数 |

## 5. DRF IMG 配置活动 → 代码映射（DRF_001~012）

| IMG | 标题 | 关联代码 |
|---|---|---|
| `DRF_001` | Define Filter Objects | 过滤器实现类 |
| `DRF_002` | Define Business Objects | 键结构 |
| `DRF_003` | Define Service Operations Available for Replication | `SEND_MESSAGE` 的服务操作 |
| `DRF_004` | Define Outbound Implementations | 出站适配类（核心绑定） |
| `DRF_005` | Define Replication Models | 整体编排 |
| `DRF_006` | Define Parameters | `DRF_S_RUNTIME_PARAMETER_EXT` |
| `DRF_007` | Define Communication Arrangement | AIF 场景 |
| `DRF_008` | Define Technical Settings for Business Systems | `iv_logical_port` |
| `DRF_009` | Define Business Object Settings | 业务对象级设置 |
| `DRF_010` | Define Object Identifiers | 对象标识符 |
| `DRF_011` | Assign Key Structures to Object Identifiers | 键表类型 |
| `DRF_012` | Assign Filter Objects to Business Objects | 过滤器绑定 |

## 6. 实现完成检查表

### 6.1 代码检查
- [ ] 无 `BREAK-POINT` / `BREAK` 残留
- [ ] 无硬编码的 namespace / ifname / logical port
- [ ] `INITIALIZE` 正确回填 `table_type_name`
- [ ] `table_type_name` 指向的类型真实存在且有 `UNIQUE KEY`
- [ ] 所有 `EXCEPTIONS` 都被处理（`CX_DRF_EXCEPTION` / `CX_DRF_PROCESS_MESSAGES` / `CX_DRF_ANALYZE_CHANGES`）
- [ ] `map_data2message` 正确处理 `ASSIGN` 失败（`sy-subrc <> 0`）
- [ ] 无空 `CHANGING` 引用被意外覆盖
- [ ] STLNR 去重 JOIN（防组件重复发送）
- [ ] 发送后检查 `add_return_tab` 业务级错误
- [ ] `/AIF/CREATE_APPL_LOG` 与 `/AIF/SEND_WITH_PROXY` 分用返回表

### 6.2 配置检查
- [ ] `DRF_004` 出站实现指向正确的类
- [ ] 同一复制模型内**一业务对象一过滤器**（否则模型校验失败）
- [ ] `DRF_007` 通信安排与 AIF 场景一致
- [ ] `DRF_008` 逻辑端口与代码中的 `iv_logical_port` 一致
- [ ] `DRF_011` 键结构分配正确
- [ ] 复制模型校验通过

### 6.3 运行时检查
- [ ] DRF 应用日志（`CL_DRF_BAL`）无异常
- [ ] AIF 消息日志可查询（`/AIF/` 监控）
- [ ] 初始复制与增量复制都验证过
- [ ] 重启模式（`RUNMOD_RESTART_*`）行为正确
- [ ] 过滤正确生效（不应传的对象确实没传）
