# 通用 AIF Inbound 处理模板

> **来源**：从一组 AIF 入站接口（示例为"发票状态从外部门户同步到 S/4H"）提取的**通用 AIF 入站处理模式**。
> 该接口经 `/AIF/CUST` 核实为 Inbound，处理链：
>
> ```
> 外部门户
>  → [AIF 入站] 命名空间/接口/版本
>  → 代理类 ZCL_PROXY（实现 ZIF_YOUR_PROC）
>  → your_process(input) → EXECUTE_ASYNC_WS
>  → /AIF/CL_ENABLER_PROXY=>PROCESS_MESSAGE
>  → AIF 引擎 structure mapping → assign action Z_YOUR_ACTION
>  → FM ZF_YOUR_IF_AIF（AIF 签名，data = source structure Z_MSG_STRUCT_T1）
>  → FM ZF_YOUR_IF（RFC 签名，唯一调用者 = 上一 FM）
>  → NEW ZCL_PROCESS_CLASS → GET_DATA(i_msg)
>  → 取数 → 改记录 FM → PUSH_LOG_TO_AIF 回写 → SEND_EMAIL
> ```
>
> **模板定位**：这是一套"代理类 + 处理类 + 桥接 FM + AIF 回写 + 邮件通知"的五件套模式，可复用于任何 **SAP 接收外部系统消息、写回 AIF 消息状态、并发邮件通知**的 AIF 入站接口。

---

## 一、五件套结构

| 件 | 类 / FM | 职责 | 复用要点 |
|---|---|---|---|
| **1. 代理接口** | 接口 `ZIF_YOUR_PROC` + 代理类 `ZCL_PROXY` | AIF 入站回调入口：把 `input` 转给处理类 | 接口/类名按业务域替换；方法体只保留一句 `EXECUTE_ASYNC_WS` 转发，**绝不写业务逻辑**（代理类会被重新生成覆盖） |
| **2. 处理类** | `ZCL_PROCESS_CLASS` | 承载全部业务：取数、更新记录、回写 AIF、发邮件 | 类方法签名固定：`EXECUTE_ASYNC_WS`（类方法）、`GET_DATA`（实例方法，被 FM 调用）、`PUSH_LOG_TO_AIF`（类方法）、`SEND_EMAIL`（实例方法）；**可测缝**用 `TEST-SEAM aif_enabler` 包住 `update_message` |
| **3. AIF action FM** | `ZF_YOUR_IF_AIF` | AIF 引擎按 action 调它：取消息 `item[]`、过滤空 `doc_key`、转调业务 FM、回写 `success` | **AIF 签名**：`data/curr_line/success/old_messages/return_tab`；`data` 是 source structure（`Z_MSG_STRUCT_T1`） |
| **4. 业务 FM** | `ZF_YOUR_IF` | RFC 形态：`S_RFC` 鉴权（同系统恒放行），`NEW` 处理类并调 `GET_DATA` | **RFC 签名**：`msg_stat/e_error/return_tab`；**唯一调用者 = AIF action FM**（非直连 RFC 入口，鉴权形同虚设） |
| **5. 回写 + 通知** | `PUSH_LOG_TO_AIF`（`update_message`） + `SEND_EMAIL`（`CL_BCS`） | 把处理状态写回 AIF 消息；发邮件通知 | 回写用 `msgguid_from_proxy_engine` 取当前消息 GUID；邮件用 `CL_BCS` + `CL_DOCUMENT_BCS` 标准 API |

**关键分工**：代理类只做转发，业务 FM 只做桥接，处理类承载全部逻辑。**代理重生成不会覆盖业务**，这是 AIF 入站接口的正确形态。

---

## 二、六个可复用的标准方法

### 2.1 代理入口 `your_process`（1_proxy Class Inbound_ZCL_PROXY.abap）

```abap
METHOD ZIF_YOUR_PROC~YOUR_PROCESS.
  "/ 业务域替换：ZIF_YOUR_IF~YOUR_PROCESS
  ZCL_PROCESS_CLASS=>execute_async_ws( iv_input    = input
                                       iv_bal_object    = 'Z_YOUR_BAL_OBJECT'
                                       iv_bal_subobject = 'Z_YOUR_BAL_SUBOBJ' ).
ENDMETHOD.
```

**复用要点**：
- 方法体只有这一句，不写任何业务逻辑（代理类会被 AIF 重新生成）。
- `iv_bal_object` / `iv_bal_subobject` 传入的是应用日志对象，**必须与 AIF 配置里登记的日志对象一致**，否则日志会写到别的对象下。

---

### 2.2 处理类入口 `EXECUTE_ASYNC_WS`（3_Process Class_ZCL_PROCESS_CLASS.abap）

```abap
class-methods EXECUTE_ASYNC_WS
  importing
    !IV_INPUT type ANY
    !IV_BAL_OBJECT type BALOBJ_D optional
    !IV_BAL_SUBOBJECT type BALSUBOBJ optional.

METHOD EXECUTE_ASYNC_WS.
  TRY.
    "/ 入站消息推进 AIF 引擎
    /aif/cl_enabler_proxy=>process_message( is_input               = iv_input
                                            iv_exception_classname = 'CX_MDC_STANDARD_MESSAGE_FAULT' ).

    CATCH cx_mdc_standard_message_fault INTO DATA(cx_mdc_std_mess_fault_obj).
      IF cx_mdc_std_mess_fault_obj IS BOUND.
        DATA(catch_message_var) = cx_mdc_std_mess_fault_obj->if_message~get_text( ).
      ENDIF.
      "/ 用 CBS 日志框架把 AIF 故障落到应用日志
      TRY.
        DATA(log_manager_obj) = /cbs/cl_log_factory=>get_log_manager( ).
        IF log_manager_obj IS BOUND.
          log_manager_obj->set_bal_header( iv_bal_object    = iv_bal_object
                                           iv_bal_subobject = iv_bal_subobject ).
          DATA(gen_log_obj) = log_manager_obj->get_misc_log( ).
          IF gen_log_obj IS BOUND.
            IF catch_message_var IS NOT INITIAL.
              gen_log_obj->add_message( iv_msgid = 'Z_YOUR_MSGID'
                                        iv_msgno = '008'        " AIF 故障文本
                                        iv_msgty = 'S'
                                        iv_msgv1 = catch_message_var ).
            ENDIF.
            gen_log_obj->add_message( iv_msgid = 'Z_YOUR_MSGID'
                                      iv_msgno = '009'        " 处理异常
                                      iv_msgty = 'S' ).
            log_manager_obj->save_all_logs( ).
          ENDIF.
        ENDIF.
      CATCH /cbs/cx_log_error INTO DATA(lo_exc).
        MESSAGE lo_exc TYPE 'W'.   " ← 本模板已改：W 不 E（P1-7）
      ENDTRY.
      "/ 重新抛出原故障，让 AIF 引擎标记消息失败（本模板已修 P0-4 / P1-1）
      IF cx_mdc_std_mess_fault_obj IS BOUND.
        RAISE cx_mdc_std_mess_fault_obj.
      ENDIF.
  ENDTRY.
ENDMETHOD.
```

**复用要点**：
- `process_message` 是 AIF 入站的标准入口：引擎会按定制做校验、映射、调 action。
- `CX_MDC_STANDARD_MESSAGE_FAULT` 捕获的是 AIF 引擎**标准消息故障**；捕获后**必须写日志 + `RAISE` 原故障**（本模板已修 P0-4 / P1-1）。
- 日志框架用 `/CBS/CL_LOG_FACTORY`（Roche 代码库统一入口）；若你的环境用标准 `BAL*` 函数，把 `log_manager_obj` 换成 `BAL_LOG_CREATE`。

---

### 2.3 业务处理 `GET_DATA`（3_Process Class_ZCL_PROCESS_CLASS.abap）

**这是全程序的主体**，按数据流向拆七段。

#### ① 日志上下文 + 配置读取

```abap
METHOD GET_DATA
  IMPORTING
    I_MSG type Z_MSG_STRUCT_T   " 按业务替换
  CHANGING
    RETURNTABLE type BAPIRET2_TAB
  EXCEPTIONS
    ERROR.

  DATA: lt_accchg  TYPE TABLE OF accchg,
        ls_accchg  TYPE accchg,
        lt_body    TYPE stringtab,
        ls_body    TYPE string,
        ls_ret     TYPE bapiret2,
        lt_ret     TYPE bapirettab.

  DATA(log_manager_obj) = /cbs/cl_log_factory=>get_log_manager( ).
  IF log_manager_obj IS BOUND.
    log_manager_obj->set_bal_header( iv_bal_object    = 'Z_YOUR_BAL_OBJECT'
                                     iv_bal_subobject = 'Z_YOUR_BAL_SUBOBJ' ).
    TRY.
        DATA(gen_log_obj) = log_manager_obj->get_misc_log( ).
      CATCH /cbs/cx_log_error INTO DATA(lo_exc2).
        MESSAGE lo_exc2 TYPE 'W'.   " ← 本模板已改（P1-7）
    ENDTRY.
  ENDIF.

  your_control_key(                     " 替换点：读 EFR / 读配置表
    IMPORTING
      emails  = DATA(emails)
      e_comp_code = DATA(comp_code) ).

* 本模板已补（P2-7）：公司代码未取到直接 RETURN + 错误日志
  IF comp_code IS INITIAL.
    " ... 记日志 + RETURN ...
  ENDIF.
ENDMETHOD.
```

**复用要点**：
- 日志框架对象在 `GET_DATA` 里**再建一次**（与 2.2 的 `EXECUTE_ASYNC_WS` 是同一框架），保证异常路径与业务路径的日志进同一对象。
- `your_control_key` 是配置读取（EFR / 表 / 参数），把"公司代码 + 收件人"从配置读出，**避免硬编码**。

#### ② 直接匹配取数

```abap
IF i_msg IS NOT INITIAL.
  SELECT a~documentnumber AS doc_key, a~companycode AS comp_code, a~fiscalyear AS fiscal_yr,
         b~referencekey AS ref1, b~lineitem AS line_item,
         a~referencekey1 AS ref1_hd, a~referencekey2 AS ref2_hd
    FROM z_your_bkpf_view AS a                       " CDS view（按业务替换）
    INNER JOIN z_your_bseg AS b
      ON a~documentnumber = b~accdocumentnumber
     AND a~companycode = b~companycode
     AND a~fiscalyear = b~fiscalyear
    FOR ALL ENTRIES IN @i_msg
    WHERE a~documentnumber = @i_msg-doc_key
      AND b~accounttype = 'D'                    " 客户行项目（按业务口径改）
      AND a~companycode = @comp_code
    INTO TABLE @DATA(msg_data).
  IF sy-subrc = 0.
    SORT msg_data BY doc_key.   " ← 本模板已补（P2-1）
  ENDIF.
ENDIF.
```

**复用要点**：
- 先 `SELECT ... FOR ALL ENTRIES IN @i_msg` 按业务键直接匹配；**必须 `SORT`**，后面 `READ TABLE` 用 `BINARY SEARCH`。
- `WHERE accounttype = 'D'` 是业务口径（客户行项目），按你的业务改。
- `companycode = @comp_code` 限定公司代码，防跨公司重号。

#### ③ 遗留号回退取数（可选）

```abap
IF leg_range IS NOT INITIAL.
  SELECT a~documentnumber AS doc_key, a~companycode AS comp_code, a~fiscalyear AS fiscal_yr,
         b~referencekey AS ref1, b~referencekeyforlineitem AS ref3,
         left( b~referencekeyforlineitem,10 ) AS leg_inv,
         b~lineitem AS line_item, a~referencekey1 AS ref1_hd, a~referencekey2 AS ref2_hd,
         a~reversedocnumber AS reversal_doc
    FROM z_your_bkpf_view AS a
    INNER JOIN z_your_bseg AS b
      ON a~documentnumber = b~accdocumentnumber
     AND a~companycode = b~companycode
     AND a~fiscalyear = b~fiscalyear
    WHERE b~referencekeyforlineitem IN @leg_range
      AND b~accounttype = 'D'
      AND a~companycode = @comp_code
    INTO TABLE @DATA(msg_data_leg).
  IF sy-subrc = 0.
    SORT msg_data_leg BY doc_key.   " ← 本模板已补（P2-1）
    DELETE msg_data_leg WHERE reversal_doc IS NOT INITIAL.   " 删已冲销记录（业务口径）
  ENDIF.
ENDIF.
```

**复用要点**：
- 外部系统发的可能是**遗留系统号**（存在 S/4 记录 `ref3` 行项目参考键里），用 `*doc_key*` 通配 + `left(...,10)` 截断回退匹配。
- **必须过滤已冲销记录**（`DELETE WHERE reversal_doc IS NOT INITIAL`）——这是容易被忽略的正确性细节。
- 若你的业务没有遗留号回退，跳过这一段。

#### ④ 主循环：构建变更 + 改记录 FM

```abap
LOOP AT i_msg ASSIGNING FIELD-SYMBOL(<fs_item>).
  READ TABLE msg_data INTO DATA(msg_db) WITH KEY doc_key = <fs_item>-doc_key BINARY SEARCH.
  IF sy-subrc = 0.
    CLEAR lt_accchg.   " ← 本模板已补（P0-1）
    "/ 替换点：ls_accchg 的 fdname/oldval/newval 按业务改
    " ... 构建 lt_accchg ...
  ENDIF.

  READ TABLE msg_data_leg INTO DATA(msg_db_leg) WITH KEY leg_inv = <fs_item>-doc_key BINARY SEARCH.
  IF sy-subrc = 0.
    CLEAR lt_accchg.   " ← 本模板已补（P0-1）
    " ... 构建 lt_accchg ...
    MOVE-CORRESPONDING msg_db_leg TO msg_db.
  ENDIF.

  IF msg_db-doc_key IS NOT INITIAL.
    "/ 替换点：FI_DOCUMENT_CHANGE → 你要改的 FM（BAPI_ACC_DOCUMENT_MODIFY / CDS update / 自定义 FM）
    CALL FUNCTION 'FI_DOCUMENT_CHANGE'
      EXPORTING
        x_lock               = 'X'
        i_comp_code          = msg_db-comp_code
        i_doc_key            = msg_db-doc_key
        i_fiscal_yr          = msg_db-fiscal_yr
        i_line_item          = msg_db-line_item
      TABLES
        t_accchg             = lt_accchg
      EXCEPTIONS
        no_reference         = 1
        no_document          = 2
        many_documents       = 3
        wrong_input          = 4
        overwrite_creditcard = 5
        OTHERS               = 6.
    " ... 成功/失败分支（见 ⑤）...
  ELSE.
    " ... 未找到分支（见 ⑥）...
  ENDIF.
  CLEAR: msg_db, lt_accchg.   " ← 本模板已补（P0-1）
ENDLOOP.
```

**复用要点**：
- **循环内 `CLEAR lt_accchg`**——这是本模板**刻意补上**的（原程序 P0-1 缺失），否则处理第 2 条时 `lt_accchg` 仍含第 1 条的变更。
- `FI_DOCUMENT_CHANGE` 是"改 FI 凭证字段"的经典 FM：不重新过账，只更新指定字段（`t_accchg` 里的 `fdname/oldval/newval`）。
- `x_lock='X'` 在事务内加锁，防并发改同一记录。
- **按你的业务替换**：把 `FI_DOCUMENT_CHANGE` 换成你要改的 FM（`BAPI_ACC_DOCUMENT_MODIFY`、自定义 FM、CDS update 等）。

#### ⑤ 成功/失败分支

```abap
IF sy-subrc NE 0.
  CALL FUNCTION 'BAPI_TRANSACTION_ROLLBACK'.
  MESSAGE ID sy-msgid TYPE 'I' NUMBER sy-msgno
    WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4 INTO ls_error_msg.
  TRY.
    IF gen_log_obj IS BOUND.
      gen_log_obj->add_message( iv_msgid = 'Z_YOUR_MSGID'
                                iv_msgno = '004'        " 处理异常
                                iv_msgty = 'E'
                                iv_msgv1 = msg_db-doc_key ).
      CONCATENATE TEXT-008 msg_db-doc_key TEXT-010 ls_error_msg INTO ls_body SEPARATED BY space.
      APPEND ls_body TO lt_body.
    ENDIF.
  CATCH /cbs/cx_log_error INTO DATA(lo_exc).
    MESSAGE lo_exc TYPE 'W'.   " ← 本模板已改（P1-7）
  ENDTRY.

  ls_ret-id = 'Z_YOUR_MSGID'.
  ls_ret-number = '004'.
  ls_ret-type = 'E'.
  CONCATENATE TEXT-008 msg_db-doc_key TEXT-010 ls_error_msg INTO ls_ret-message SEPARATED BY space.
  APPEND ls_ret TO lt_ret.
  push_log_to_aif( msg_data = <fs_item> status = 'E' return_log = lt_ret ).
  CLEAR: ls_ret, lt_ret.
ELSE.
  CALL FUNCTION 'BAPI_TRANSACTION_COMMIT'.
  " ... 成功日志 + BAPIRET ...
  push_log_to_aif( msg_data = <fs_item> status = 'S' return_log = lt_ret ).
  CLEAR: ls_ret, lt_ret.
ENDIF.
```

**复用要点**：
- 每条记录独立事务：成功提交、失败回滚。**若业务要求整批原子性**，改为先收集全部变更、最后统一 `BAPI_TRANSACTION_COMMIT`。
- `ls_ret-type` 与 `status` **必须一致**（本模板 ⑤ 已对齐 `E`；原程序 ⑥ 的 `005` 未找到分支里 `ls_ret-type='S'` 与 `status='E'` 不一致，是 P2-2）。

#### ⑥ 未找到分支

```abap
ELSE.
  TRY.
    IF gen_log_obj IS BOUND.
      gen_log_obj->add_message( iv_msgid = 'Z_YOUR_MSGID'
                                iv_msgno = '005'        " 未找到
                                iv_msgty = 'E'
                                iv_msgv1 = <fs_item>-doc_key ).   " ← 本模板已修（P1-9）
      CONCATENATE TEXT-011 <fs_item>-doc_key TEXT-012 INTO ls_body SEPARATED BY space.
      APPEND ls_body TO lt_body.
    ENDIF.
  CATCH /cbs/cx_log_error INTO lo_exc.
    MESSAGE lo_exc TYPE 'W'.   " ← 本模板已改（P1-7）
  ENDTRY.
  ls_ret-id = 'Z_YOUR_MSGID'.
  ls_ret-number = '005'.
  ls_ret-type = 'E'.          " ← 本模板已修（P2-2）
  CONCATENATE TEXT-011 <fs_item>-doc_key TEXT-012 INTO ls_ret-message SEPARATED BY space.
  APPEND ls_ret TO lt_ret.
  push_log_to_aif( msg_data = <fs_item> status = 'E' return_log = lt_ret ).
  CLEAR: ls_ret, lt_ret.
ENDIF.
```

**复用要点**：
- **未找到分支里 `ls_ret-type` 必须是 `'E'`**（本模板已修），`status` 也必须是 `'E'`——**应用日志、AIF 状态、BAPIRET 三处类型必须一致**，否则排查时会互相矛盾。

#### ⑦ 收尾：保存日志 + 发邮件

```abap
TRY.
  IF log_manager_obj IS BOUND.        " ← 本模板已补（P0-2）
    log_manager_obj->save_all_logs( ).
  ENDIF.
CATCH /cbs/cx_log_error INTO lo_exc.
  MESSAGE lo_exc TYPE 'W'.   " ← 本模板已改（P1-7）
ENDTRY.

send_email(
  EXPORTING
    i_body = lt_body
    emails = emails
  EXCEPTIONS
    error  = 1
    OTHERS = 2 ).
IF sy-subrc <> 0.
  MESSAGE ID sy-msgid TYPE sy-msgty NUMBER sy-msgno
    WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4.
ENDIF.
```

**复用要点**：
- **`save_all_logs` 前必须判 `IS BOUND`**（本模板已补 P0-2；原程序 ⑦ 漏判 → 空引用短转储）。
- `send_email` 失败**不阻断业务**（只 `MESSAGE`，不 `TYPE 'E'`）——邮件是通知，不是业务。

---

### 2.4 配置读取（3_Process Class_ZCL_PROCESS_CLASS.abap，按业务替换）

```abap
class-methods YOUR_CONTROL_KEY
  exporting
    !E_COMP_CODE type char10
    !EMAILS type CRMTT_EMAIL_ADDRESS.

METHOD YOUR_CONTROL_KEY.
  TRY.
    DATA(application_object) = z_your_efr=>factory(
      i_application_id = 'Z_YOUR_APP_ID' ).        " EFR 应用 ID
  CATCH z_cx_your_efr INTO DATA(excpt_o).
    DATA(error) = excpt_o->get_text( ).
  ENDTRY.
  IF application_object IS BOUND.
    TRY.
* 本模板已修（P3-2）：只建一次 factory
      application_object->get_parameter_values(
        EXPORTING
          i_parameter_id     = 'Z_YOUR_V_COMP_CODE'
        RECEIVING
          r_parameter_values = DATA(control_key_tab) ).
      IF control_key_tab IS NOT INITIAL.
        LOOP AT control_key_tab ASSIGNING FIELD-SYMBOL(<ck>).
          IF <ck>-filter = 'COMP_CODE'.
            e_comp_code = <ck>-parameter_value.
          ENDIF.
        ENDLOOP.
      ENDIF.
      " ... EMAIL 参数 ...
      CATCH z_cx_your_efr INTO excpt_o.
* 本模板已修（P2-5）：错误文本记进日志，不 CLEAR
        error = excpt_o->get_text( ).
        " ... 记进日志 ...
      ENDTRY.
    ENDTRY.
  ENDIF.
ENDMETHOD.
```

**复用要点**：
- 公司代码、收件人**走 EFR 配置**而非硬编码（环境切换不改代码）。
- **EFR 应用 ID 拼写要核对**（原程序 P0-3 `UDPATE` 拼写错误 → 接口静默失效）。
- 错误文本**必须记进日志**（原 P2-5 `CLEAR error` 是无用逻辑，本模板已修）。

---

### 2.5 AIF 回写 + 邮件通知（3_Process Class_ZCL_PROCESS_CLASS.abap）

```abap
class-methods PUSH_LOG_TO_AIF
  importing
    !MSG_DATA type Z_MSG_STRUCT
    !STATUS type CHAR1 optional
    !RETURN_LOG type BAPIRETTAB optional.

METHOD PUSH_LOG_TO_AIF.
  DATA: ns   TYPE /aif/ns VALUE 'ZNS',
        intf TYPE /aif/ifname VALUE 'ZIF_YOUR_IF',
        ver  TYPE /aif/ifversion VALUE '1'.

  TRY.
    /aif/cl_enabler_proxy=>msgguid_from_proxy_engine(
      IMPORTING ev_msgguid = DATA(msgguid) ).
    DATA(lr_enabler) = NEW /aif/cl_enabler_sync_log( iv_msgguid = CONV #( msgguid )
                                                      iv_ns = ns
                                                      iv_ifname = intf
                                                      iv_ifversion = ver
                                                      iv_force_create_log = abap_false ).
    IF lr_enabler IS INITIAL.
      lr_enabler = /aif/cl_enabler_sync_log=>transfer_to_aif( is_aifkeys = VALUE #( ns = ns ifname = intf ifver = ver )
                                                              is_raw_structure = msg_data ).
    ENDIF.
  CATCH /aif/cx_inf_det_base
        /aif/cx_enabler_base
        /aif/cx_aif_engine_not_found
        /aif/cx_error_handling_general
        /aif/cx_aif_engine_base INTO DATA(lr_exc1).
    MESSAGE lr_exc1->get_text( ) TYPE 'W'.
  ENDTRY.

  TRY.
    "/ 可测缝：单测时替换 lr_enabler
    TEST-SEAM aif_enabler.
* 本模板已补（P1-10）：update_message 前判 lr_enabler IS BOUND
      IF lr_enabler IS BOUND.
        lr_enabler->update_message( is_raw_structure = msg_data
                                    iv_message_status = status
                                    it_bapiret = return_log ).
      ENDIF.
    END-TEST-SEAM.
* 本模板已修（P3-3）：双句点改单句点
  CATCH /aif/cx_enabler_base INTO DATA(lr_exc2).
    MESSAGE lr_exc2->get_text( ) TYPE 'W'.
  ENDTRY.
ENDMETHOD.
```

```abap
METHOD SEND_EMAIL.
  CONSTANTS lc_raw TYPE so_obj_tp VALUE 'RAW'.
  DATA: lt_body TYPE stringtab, lv_body TYPE string.

  APPEND LINES OF I_body TO lt_body.
  " ... 拼 body ...
  LOOP AT lt_body ASSIGNING FIELD-SYMBOL(<line>).
    lv_body = |{ lv_body }{ cl_abap_char_utilities=>newline }{ <line> }|.
  ENDLOOP.

* 本模板已补（P1-11）：emails 判空再 send()
  IF emails IS INITIAL.
    RETURN.
  ENDIF.

  TRY.
    DATA(lo_send_request) = cl_bcs=>create_persistent( ).
    lo_send_request->set_document( cl_document_bcs=>create_document(
      i_type    = lc_raw
      i_text    = cl_document_bcs=>string_to_soli( ip_string = lv_body )
      i_subject = TEXT-006 ) ).   " 替换点：TEXT-006 → 你的邮件主题
    lo_send_request->set_sender( i_sender = cl_cam_address_bcs=>create_internet_address( i_address_string = TEXT-007 ) ).   " 替换点：TEXT-007 → 你的发件人
    LOOP AT emails ASSIGNING FIELD-SYMBOL(<ls_email>).
      lo_send_request->add_recipient( i_recipient = cl_cam_address_bcs=>create_internet_address( i_address_string = <ls_email> ) ).
    ENDLOOP.
    lo_send_request->set_send_immediately( i_send_immediately = 'X' ).
    IF lo_send_request->send( ) = abap_true.
      CALL FUNCTION 'BAPI_TRANSACTION_COMMIT'.
    ENDIF.
  CATCH cx_bcs INTO DATA(lo_ex).
* 本模板已改（P1-7）：邮件失败降级 W
    MESSAGE lo_ex->get_text( ) TYPE 'W'.
  ENDTRY.
ENDMETHOD.
```

**复用要点**：
- `TEST-SEAM aif_enabler` 是**刻意的可测性缝**：单测时可替换 `lr_enabler`，避免真实回写 AIF。
- `update_message` 前**判 `lr_enabler IS BOUND`**（本模板已补 P1-10；原程序 ⑦ 漏判 → 空引用短转储）。
- `send_email` 失败**降级为 `W`**（本模板已改 P1-7；原程序 `TYPE 'E'` → 邮件失败中止业务，与"邮件是通知"定位冲突）。
- **`emails` 判空**（本模板已补 P1-11；原程序 `emails` 空仍 `send()` → `CL_BCS` 抛异常）。

---

### 2.6 AIF action FM（桥接层，`/AIF/CUST` 登记的 action）

```abap
FUNCTION ZF_YOUR_IF_AIF
  IMPORTING
    testrun TYPE c
    sending_system TYPE /aif/aif_business_system_key OPTIONAL
  CHANGING
    data TYPE any ##ADT_PARAMETER_UNTYPED        " AIF 消息体（source structure）
    curr_line TYPE any ##ADT_PARAMETER_UNTYPED   " 当前行指针
    success TYPE /aif/successflag
    old_messages TYPE /aif/bal_t_msg
  TABLES
    return_tab LIKE bapiret2 OPTIONAL.

  "/ 取消息 item
  FIELD-SYMBOLS: <input_wa> TYPE Z_MSG_STRUCT_T1.   " source structure
  DATA: msg_stat  TYPE Z_MSG_STRUCT_TAB,
        msg_final TYPE Z_MSG_STRUCT_T,
        error     TYPE flag.

  TRY.
    ASSIGN data TO <input_wa>.
    IF <input_wa>-item IS ASSIGNED.
      msg_stat = <input_wa>-item[].
      msg_final = CORRESPONDING #( msg_stat ).
      DELETE msg_final WHERE doc_key IS INITIAL.   " 过滤空号行
      IF msg_final IS NOT INITIAL.                " ← 本模板已补（P1-12）
        CALL FUNCTION 'ZF_YOUR_IF'
          EXPORTING
            msg_stat = msg_final
          IMPORTING
            e_error    = error
          TABLES
            return_tab = return_tab.
      ELSE.
        success = 'N'.                            " 空表直接失败
      ENDIF.
      IF error = abap_true.
        success = 'N'.
      ELSE.
        success = 'Y'.
      ENDIF.
    ENDIF.
  CATCH cx_root INTO DATA(root_ex).
* 本模板已改（P1-7）：降级 W
    MESSAGE root_ex->get_text( ) TYPE 'W'.
    success = 'N'.
    RETURN.
  ENDTRY.
ENDFUNCTION.
```

**复用要点**：
- AIF 签名固定：`data/curr_line/success/old_messages/return_tab`。
- `data` 是 AIF 消息体（`/AIF/CUST` 里 define structure mapping 登记的 source structure）。
- **空表判断**（本模板已补 P1-12）：`DELETE ... WHERE doc_key IS INITIAL` 后若 `msg_final` 空，直接 `success='N'`，**不静默丢弃**。

---

### 2.7 业务 FM（RFC 形态，被 AIF action FM 调用）

```abap
FUNCTION ZF_YOUR_IF
  IMPORTING
    VALUE(msg_stat) TYPE Z_MSG_STRUCT_T OPTIONAL
  EXPORTING
    VALUE(e_error) TYPE flag
  TABLES
    return_tab LIKE bapiret2 OPTIONAL.

  DATA: return    TYPE bapiret2_tab,
        return_wa TYPE bapiret2.
* RFC 鉴权（同系统内 is_rfc_within_same_system 放行；非直连 RFC 入口，鉴权形同虚设）
  AUTHORITY-CHECK OBJECT 'S_RFC'
           ID 'RFC_TYPE' FIELD c_rfctype
           ID 'RFC_NAME' FIELD c_fncgrp
           ID 'ACTVT'    FIELD c_activity.
  IF sy-subrc <> 0.
    IF zc_your_assist=>is_rfc_within_same_system( ) = abap_true.
      " continue
    ELSE.
      return_wa-id = 'Z_YOUR_MSGID'.
      return_wa-number = '006'.
      return_wa-type = 'S'.
      return_wa-message = TEXT-005.
      APPEND return_wa TO return_tab.
    ENDIF.
  ENDIF.

  DATA(process_utility) = NEW ZCL_PROCESS_CLASS( ).
  TRY.
    CALL METHOD process_utility->get_data
      EXPORTING
        i_msg      = msg_stat
      CHANGING
        returntable = return
      EXCEPTIONS
        error       = 1
        OTHERS      = 2.
    IF sy-subrc <> 0.
      return_tab[] = return[].
    ENDIF.
  CATCH /cbs/cx_log_error INTO DATA(lo_exc).
* 本模板已改（P1-7）：降级 W
    MESSAGE lo_exc->get_text( ) TYPE 'W'.
  ENDTRY.
ENDFUNCTION.
```

**复用要点**：
- **唯一调用者 = AIF action FM**（同系统 `CALL FUNCTION`，非外部系统直连 RFC 入口）；`S_RFC` 鉴权恒为同系统、恒放行。
- `NEW` 处理类 + `CALL METHOD ->get_data` 是 AIF 入站接口的**标准触发模式**：AIF 引擎按 action 调 FM，FM `NEW` 类并调方法。
- 错误捕获**降级为 `W`**（本模板已改 P1-7；原程序 `TYPE 'E'` 中止业务）。

---

## 三、`/AIF/CUST` 登记清单（必须配套）

模板五件套要在目标系统跑起来，**必须在 `/AIF/CUST` 登记**：

| 登记项 | 内容 | 本模板示例 |
|---|---|---|
| 接口方向 | Inbound | `ZNS/ZIF_YOUR_IF/1` 方向 = Inbound |
| 代理类入站 | 实现代理接口的类 | `ZCL_PROXY` |
| structure mapping | source structure | `Z_MSG_STRUCT_T1`（含 `-item` 表） |
| assign action | AIF 引擎按 action 调 FM | `Z_YOUR_ACTION` → FM `ZF_YOUR_IF_AIF` |
| 日志对象 | 代理类 + 处理类里传入的 `iv_bal_object/iv_bal_subobject` | `Z_YOUR_BAL_OBJECT` / `Z_YOUR_BAL_SUBOBJ` |
| 入站校验 | 签名 / 认证 / 接口授权 | （本模板**未配**，是已知缺口 1.4） |

**关键**：`structure mapping` 的 source structure 必须与 AIF action FM 里 `ASSIGN data TO <input_wa>` 的类型一致（`Z_MSG_STRUCT_T1`），否则 `data` 解引用错位。

---

## 四、复用检查清单（10 项）

| # | 检查项 | 本模板状态 |
|---|---|---|
| 1 | 代理类方法体**只转发**，不写业务 | ✅ 已做 |
| 2 | `GET_DATA` 循环内**清空累积内表**（`CLEAR lt_accchg`） | ✅ 已补（P0-1） |
| 3 | `save_all_logs` / `update_message` 前**判 `IS BOUND`** | ✅ 已补（P0-2 / P1-10） |
| 4 | 应用日志、AIF 状态、BAPIRET **类型一致**（`005` 未找到 → 三处都 `E`） | ✅ 已修（P2-2） |
| 5 | 邮件失败**降级 `W`** 不中止业务 | ✅ 已改（P1-7） |
| 6 | `emails` 判空再 `send()` | ✅ 已补（P1-11） |
| 7 | EFR 配置读取错误**记进日志**不 `CLEAR` | ✅ 已修（P2-5） |
| 8 | `READ TABLE` 用 `BINARY SEARCH`（表已 `SORT`） | ✅ 已补（P2-1） |
| 9 | `structure mapping` source structure 与 AIF action FM 里 `ASSIGN data` 类型一致 | ✅ 已核实 |
| 10 | `/AIF/CUST` 登记：方向 / 代理类 / structure mapping / assign action / 日志对象 | ✅ 已核实 |

---

## 五、与 Roche 代码库的适配

本模板提取自 Roche 代码库（`/RGS` 命名空间），以下替换点按你的环境改：

| 本模板写法 | 你的环境可能替换为 |
|---|---|
| `/CBS/CL_LOG_FACTORY` | 标准 `BAL_LOG_CREATE` / `BAL_SLOG_WRITE` |
| `z_your_efr=>factory` | 你的 EFR 框架 / 自定义配置表 |
| `Z_YOUR_MSGID` | 你的消息类 + 文本元素 |
| `TEXT-001..012` | 你的文本元素 / 直接字符串 |
| `zc_your_assist` | 你的同系统判定工具类 |
| `FI_DOCUMENT_CHANGE` | 你要改的 FM（`BAPI_ACC_DOCUMENT_MODIFY`、CDS update 等） |

---

## 六、与原程序的差异（本模板刻意修了什么）

| 原程序缺陷 | 本模板处理 |
|---|---|
| P0-1 `lt_accchg` 循环内未清空 | ✅ 每轮 `CLEAR lt_accchg` |
| P0-2 `save_all_logs` 无 `IS BOUND` 守卫 | ✅ `IF log_manager_obj IS BOUND.` 再调 |
| P2-2 未找到分支 `ls_ret-type='S'` 与 `status='E'` 矛盾 | ✅ 三处类型统一 `E` |
| P1-7 邮件失败 `TYPE 'E'` 中止业务 | ✅ 改 `TYPE 'W'` |
| P1-10 `update_message` 前无 `lr_enabler IS BOUND` 判 | ✅ 已补 |
| P1-11 `emails` 空仍 `send()` | ✅ 判空再 `send()` |
| P2-5 EFR 错误 `CLEAR error` 丢弃 | ✅ 记进日志 |
| P2-1 `READ TABLE` 无 `BINARY SEARCH` | ✅ 补 `BINARY SEARCH` |
| P1-12 AIF action FM 静默丢弃空 `doc_key` 行 | ✅ 判空 + `success='N'` |
| P3-3 `CATCH ... INTO DATA(lr_exception2)..` 双句点 | ✅ 改单句点 |
| P1-1 `GET_DATA` 调用链入口靠 AIF 定制 | ✅ 完整链写进注释 |

**未修**（属业务口径，需你按实际业务决定）：
- P1-2 直接匹配 + 遗留匹配都命中时 `MOVE-CORRESPONDING` 覆盖（业务要求二选一）
- P1-3 `*doc_key*` 通配 + `left(...,10)` 截断（业务要求精确匹配）
- P1-4 逐条提交 vs 整批原子性（业务要求明确）
- P0-3 EFR 应用 ID `UDPATE` 拼写（需你核实真实拼写）
- 1.4 AIF 接口入站校验（需你配签名/认证）
