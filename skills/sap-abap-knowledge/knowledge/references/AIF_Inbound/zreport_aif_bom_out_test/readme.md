# AIF BOM 出站独立触发（zreport_aif_bom_out_test）

本目录是 **独立于 DRF 框架** 的 AIF BOM 出站触发包：通过 Report 手动触发一条 BOM
消息，经 AIF 出站服务推送到外部系统（如 MuleSoft/ECMS），用于联调与排障，
不依赖 DRF 运行框架。

## 组件职责

| 对象 | 职责 |
|------|------|
| `zcl_aif_outbound_util` | **通用 AIF 出站工具**（接口无关）。封装 `/AIF/SEND_WITH_PROXY` / `TRANSFER_TO_AIF` / 持久化 / 队列 / 错误状态，任意 AIF 出站接口可复用。 |
| `zcl_aif_bom_out_service` | **BOM 业务服务**（取数 + 构建消息 + 委托发送）。业务类不直接碰 AIF 引擎，统一经 `zcl_aif_outbound_util` 与 AIF 交互。 |
| `ZREPORT_AIF_BOM_OUT_TEST` | **薄壳报告**。只做屏幕选择与结果展示，业务/AIF 逻辑全部在服务类。 |

## 分层架构

```
Report zreport_aif_bom_out_test   （薄壳驱动：屏幕选择 + 结果展示）
   │  调用
   ▼
zcl_aif_bom_out_service           （业务服务：取数 + 构建消息 + 委托发送）
   │  委托
   ▼
zcl_aif_outbound_util             （通用 AIF 出站工具：封装 /AIF/SEND_WITH_PROXY 等）
   │
   ▼
AIF 引擎 → 逻辑端口 → 外部系统
```

- 与 DRF 出站（`Source Code/DRF/BOM_S4 New/`）**共用同一 `zcl_aif_outbound_util` 层**：
  二者仅"如何驱动业务逻辑"不同（DRF 经 `if_drf_outbound` 适配层；本站经 Report 薄壳），
  **AIF 交互层完全一致**。
- 业务/服务类不直接调用 AIF 引擎 FM，统一经 util（通用、接口无关）与 AIF 交互。

## 调用流（Report → Service → Util → AIF）

```
① 服务实例化  zcl_aif_bom_out_service( ns/ifname/ifversion/logical_port/recipient/plant )
② 取数        read_bom_data( matnr/werks/stlan/stlal/stlnr )  -> 内部缓冲
③ 构建消息    build_aif_message( )                            -> ms_aif_message(zzbomreplicate_request)
④ 发送        send( mode/test/persist_xml/queue/update/queue_name )  -> 委托 zcl_aif_outbound_util
⑤ 显示结果    经服务层只读访问器读取（不深入 util）
```

- 报告**只经服务层门面**读取发送结果（`get_msgguid` / `get_msgguid_out` /
  `get_error_string` / `get_return` 等），不再 `get_aif_util( )` 直达工具类。
- DRF 出站变体（`Source Code/DRF/BOM_S4 New/` 下的 `zcl_m1t_dcn_bom_change*`）
  同样委托 `zcl_aif_outbound_util~send_with_proxy`，与本站模式一致。

## zcl_aif_outbound_util 公开契约

### 发送方法（best-effort：返回布尔，不抛异常，原因存结果成员）

| 方法 | 说明 |
|------|------|
| `send_with_proxy( iv_persist_xml, CHANGING cs_message )` | **实时**：登记 + 立即推送到逻辑端口。容忍 `PERSISTENCY_ERROR(=1)`（仅 XML 体持久化失败但已推送，按成功处理）。 |
| `transfer_to_aif( is_message, iv_save )` | **异步**：只登记到 AIF 引擎，不推送外部系统（Mule 拉取场景）。 |
| `send_async( is_message, iv_persist_xml, iv_queue, iv_queue_name )` | 异步门面：`transfer_to_aif` + 可选持久化 + 可选队列，一次调用。 |
| `persist_message_xml( iv_msgguid, is_message )` | 持久化消息 XML（供中间件拉取消息体）。 |
| `add_to_queue( iv_msgguid, iv_queue_name )` | 加入进出站队列（供中间件拉取触发）。 |
| `set_error_status( iv_msgguid, is_message, iv_error_text )` | 失败时写应用错误状态 + 日志回 AIF 消息。 |

### 只读结果访问器（结果成员为 PRIVATE）

| 访问器 | 语义 |
|--------|------|
| `get_msgguid` | 消息 GUID（`ev_msgguid`，两种模式均有值） |
| `get_msgguid_out` | 出站消息 GUID（`ximsgguid_out`，实时模式）；异步下同 `msgguid` |
| `get_subrc` | `/AIF/SEND_WITH_PROXY` 原始 `sy-subrc`（**错误粒度保真**） |
| `is_success` | 发送成功（含容忍 `persistency_error`；业务级 E/A 错误为 false） |
| `is_hard_error` | 原始 `sy-subrc` 非 0/1（真失败）——免调用方写 `get_subrc()<>0 AND <>1` |
| `get_error_string` / `get_error_long` | 硬错误文本（仅 `sy-subrc` 非 0/1 时填充） |
| `get_error_text` | 硬错误文本优先，否则按 `subrc` 生成可读概要（供失败日志） |
| `get_return` | `add_return_tab`（`bapiret2`），业务级 E/A 行可据此定位 |

### 时间工具（CLASS-METHODS）

| 方法 | 说明 |
|------|------|
| `convert_timestamp( CHANGING cv_date, cv_time )` | CET 本地时间 → UTC（处理 `24:00:00` 午夜回绕）。 |
| `get_current_xsd_datetime( )` | 当前时间 → UTC → XSD datetime 字符串（供消息头 `creation_date_time`，send 时覆盖用）。 |

### 结果成员语义

- `mv_subrc = 0` 完全成功（注册 + XML 持久化 + 实时推送）。
- `mv_subrc = 1` `persistency_error`：仅"消息 XML 体持久化"失败；消息 GUID 已生成、
  实时推送已执行、外部系统已收到载荷，**按成功处理（容忍），不中断发送**。
- `mv_subrc = 2..7` 真失败（`missing_keys` / `interface_not_found` 等）。
- 业务级 E/A 错误由 `get_return( )` 承载；`is_success` 为 false 但 `is_hard_error` 为
  false 即业务错误（`subrc` 0/1 且 `return_tab` 含 E/A 行）。

## zcl_aif_bom_out_service 公开契约

| 方法 | 说明 |
|------|------|
| `constructor( iv_ns, iv_ifname, iv_ifversion, iv_logical_port, iv_recipient, iv_plant='Q511' )` | 实例化（AIF 接口键 + 接收方 + 工厂）。 |
| `read_bom_data( it_matnr, it_werks, it_stlan, it_stlal, it_stlnr )` | 取数 MAST/STKO/STPO/MARA → 内部缓冲（只取第一条 BOM）。 |
| `build_aif_message( )` | 构建 `zzbomreplicate_request`（AIF sap_struct）。 |
| `send( iv_mode='A', iv_test=abap_true, iv_persist_xml, iv_queue, iv_update, iv_queue_name='T01' )` | 发送，委托 `zcl_aif_outbound_util`。 |
| `get_aif_message( )` | 返回构建后的消息。 |
| `get_msgguid` / `get_msgguid_out` / `get_subrc` / `get_error_string` / `is_success` / `get_return` | 只读结果访问器（转发到 util），报告经此读取，不深入 util。 |

## 报告选择参数

| 参数 | 说明 |
|------|------|
| `p_mode` | 发送模式：`A`=异步（只登记）/ `R`=实时（`/AIF/SEND_WITH_PROXY` + 逻辑端口）。 |
| `p_lp` | 逻辑端口（仅 `R` 模式需要，默认 `ZBOMOUT`）。 |
| `p_recip` | 接收方业务系统 ID（默认 `MES_BS_IMP_LM`）。 |
| `p_test` | 测试运行（默认开）：不实际发送。 |
| `p_pst` | 持久化 XML（异步模式有意义）。 |
| `p_queue` | 进出站队列（异步模式 Mule 拉取触发）。 |
| `p_update` | 失败时写状态（实时模式有意义）。 |
| `iv_queue_name` | 队列名，默认 `'T01'`。 |

## 前置条件（目标系统必须已配置）

- `/AIF/CUST` 登记接口 `ZDEMO/ZDEMOIF/1`（direction = Outbound）。
- DDIC 结构 `zzbomreplicate_request` + 子结构已激活。
- 业务系统已登记（`LCR_GET_OWN_BUSINESS_SYSTEM` 取本系统）。
- （仅实时模式 `R` 需要）逻辑端口 `ZBOMOUT` 已配置。
