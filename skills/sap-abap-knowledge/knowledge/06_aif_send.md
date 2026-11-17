# 06 · AIF 发送（`/AIF/SEND_WITH_PROXY`）

> 沉淀自 BOM 出站。把消息结构发给外部系统：AIF 接口三元组 + 逻辑端口 + 分片 + 必填校验 + 错误对象五要素。

## AIF 接口常量

```abap
CONSTANTS gc_ns            TYPE /aif/ns        VALUE '<AIF_NS>'           ##NO_TEXT.
CONSTANTS gc_ifname        TYPE /aif/ifname    VALUE '<AIF_IFNAME>'       ##NO_TEXT.
CONSTANTS gc_ifver         TYPE /aif/ifversion VALUE '<AIF_IFVER>'        ##NO_TEXT.
CONSTANTS gc_logical_port  TYPE string         VALUE '<AIF_LOGICAL_PORT>' ##NO_TEXT.
CONSTANTS gc_msgid         TYPE symsgid        VALUE '<AIF_MSGID>'        ##NO_TEXT.
```

## 发送前必填校验（FS M 字段）

- **Header M**：`cop_exg_no`（ID01）、`header_qty`（ID13）非空。
- **Item M**：`cop_img_no`（ID02）、`quantity`（ID03）非空，且 `operation_scrap`/`component_scrap` ≥ 0。
- 缺失 → 对象状态置 `SE` + 写错误五要素 + 写 AIF 日志 + **不发送**（避免空消息送达目标系统）。

```abap
IF <message>-header IS INITIAL
   OR <message>-header-cop_exg_no IS INITIAL
   OR <message>-header-header_qty IS INITIAL.
  LOOP AT ct_obj_rep_sta ASSIGNING FIELD-SYMBOL(<rep>).
    <rep>-repstatus = 'SE'.
  ENDLOOP.
  <build_error_five_elements>( ... ).   " 见下方"错误对象五要素"
  CLEAR <message>.
  RETURN.
ENDIF.
```

## 分片发送（XML 单文件上限）

- `pkg_size = 2000`（组件行/批），超量拆多批调用。
- 至少 1 批（含"仅 Header 无组件"场景）。

```abap
total = lines( <message>-items ).
batch_idx = 1.
IF total > 0.
  batch_idx = ( total + pkg_size - 1 ) DIV pkg_size.
ENDIF.

DO batch_idx TIMES.
  " 切当前批 items（FROM start TO end）
  <batch_msg>-header = <message>-header.
  <batch_msg>-items  = <batch_items>.
  " ... 发送本批
ENDDO.
```

## AIF 应用日志 + 发送（SEND_WITH_PROXY）

```abap
" 建立 AIF 应用日志（header 对象 = /aif/if_globals=>gc_aif_log_obj）
CONCATENATE gc_ns gc_ifname INTO subobject SEPARATED BY space.
header-aldate = sy-datum. header-aluser = sy-uname. header-alchuser = sy-uname.
header-object = /aif/if_globals=>gc_aif_log_obj.
header-subobject = subobject.
CALL FUNCTION '/AIF/CREATE_APPL_LOG'
  EXPORTING is_header_log = header iv_ns = gc_ns iv_ifname = gc_ifname iv_ifversion = gc_ifver
  CHANGING  ct_return     = return_applog.   " 应用日志与发送分用独立返回表

CALL FUNCTION '/AIF/SEND_WITH_PROXY'
  EXPORTING ns                   = gc_ns
            ifname               = gc_ifname
            ifversion            = gc_ifver
            appl_log_function    = 'AIF_SEND_WITH_PROXY'
            msgguid              = msgguid
            iv_persist_xml       = 'X'
            logical_port_name    = gc_logical_port
  IMPORTING ximsgguid            = msgguid
            ximsgguid_out        = msgguid_out
  TABLES    add_return_tab       = return_send
  CHANGING  sap_struct           = <batch_msg>      " 消息结构（header + items）
            error_string         = error_string
            error_long_text      = error_long
  EXCEPTIONS
    persistency_error = 1 status_update_failed = 2 missing_keys = 3
    interface_not_found = 4 transformation_error = 5 general_error = 6 OTHERS = 7.
```

### 关键点

1. **`sap_struct` 即消息结构**（`<MESSAGE_TY>`），AIF 据此做 XML 序列化。
2. **返回判定**：`sy-subrc <> 0` **或** `add_return_tab` 含业务级错误（`type = 'E'` 或 `'A'`）均视为失败。
3. **日志与发送分用返回表**（`return_applog` / `return_send`）：避免 `CREATE_APPL_LOG` 返回污染 `SEND_WITH_PROXY` 的 `sy-subrc` 语义。
4. **`iv_persist_xml = 'X'`**：持久化 XML，便于 AIF 监控界面查看载荷。
5. **优先用 `/AIF/SEND_WITH_PROXY`**（在产实现路径）；`/AIF/CL_ENABLER` 类不存在，其子类需自建日志与 return 收集，不推荐。

## 错误对象五要素（`drf_s_message` → `bapiret2`）

失败时向 DRF 回写结构化错误，供运行日志与 AIF 错误上下文：

```abap
CREATE DATA error_return.          " TYPE REF TO bapiret2
error_return->type       = 'E'.
error_return->id         = gc_msgid.
error_return->number     = '002'.                       " 发送失败消息号
error_return->message_v1 = <message>-header-cop_exg_no. " 主物料 MATNR
error_return->message_v2 = <default_werks>.             " 工厂 WERKS（FS 固定默认）
error_return->message_v3 = <idnrk>.                     " 组件 IDNRK
error_return->message_v4 = <message>-header-change_no.  " ECN AENNR
errmsg-bo_type       = '<BO_TYPE_BOM>'.                 " 主对象类型
errmsg-bo_key        = <message>-header-cop_exg_no.     " 对象 ID
errmsg-target_system = gc_logical_port.                 " 目标系统
errmsg-message       = error_return.
APPEND errmsg TO et_message.
```

- 五要素 = `bo_type`（主对象类型）+ `bo_key`（对象 ID）+ `target_system`（逻辑端口）+ `message`（bapiret2 含 v1-v4 上下文）。
- 同步写**对象级应用日志**：`runtime_parameter_ext-bal->add_msg( ... iv_msgv1..v4 同 v1..v4 )`。

## 对象键回写（对齐在产）

发送成功后构造对象键引用（供框架回写状态）：

```abap
CREATE DATA <bom_key_ref>.
<bom_key_ref>->matnr = <message>-header-cop_exg_no.
<bom_key_ref>->werks = gc_default_werks.
<bom_key_ref>->stlal = <message>-header-alternative_bom.
<bom_key_ref>->aennr = <message>-header-change_no.
```
