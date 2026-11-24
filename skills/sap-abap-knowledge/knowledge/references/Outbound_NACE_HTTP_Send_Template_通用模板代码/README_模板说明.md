# 通用出站 SmartForm → HTTP 发送模板

> **来源**：从 `/RGS/V_DGG_HEM_PROT_RPT`（Hemlibra 协议表单出站 HTTP 发送）提取的**通用出站处理模式**。
> 该程序是 NACE 出站流程，处理链：
>
> ```
> NACE 触发（NAST 记录）
>  → FORM entry(i_returncode, i_screen)
>  → NEW LCL_PROCESS(i_screen)
>  → LCL_PROCESS->FETCH_FORM_DATA(document = nast-objky)
>     ↳ EFR 读 partner_function / type / form_name
>     ↳ SELECT LIPS / VBKD / LIKP / VBPA / BUT0ID / VBFA / VBBK / EDIDC / EDID4
>     ↳ READ_TEXT（Y048 / Y045）
>     ↳ ADDRESS_INTO_PRINTFORM
>  → LCL_PROCESS->GENERATE_FORM(...)
>     ↳ SET_PARAMETERS（FP 参数）
>     ↳ FP_JOB_OPEN → FP_FUNCTION_MODULE_NAME → 动态 CALL 表单 FM → FP_JOB_CLOSE
>     ↳ NAST_PROTOCOL_UPDATE（写 NAST 协议）
>  → IF nast-nacha = '8'（后台 + HTTP）
>     ↳ NEW ZCL_HTTP_SENDER(i_filename, i_otf)
>     ↳ ZCL_HTTP_SENDER->SEND_DATA()
>        ↳ GET_PARAMETER（EFR 读 destination）
>        ↳ OTF_TO_JSON（PDF → BASE64 → JSON）
>        ↳ CL_HTTP_CLIENT=>create_by_destination(destination)
>        ↳ request->set_content_type(application/json)
>        ↳ request->set_cdata(json_str)
>        ↳ send / receive
>        ↳ 按 HTTP 状态码写 status_code（000/001/002/003/004/005/006）
> ```
>
> **模板定位**：这是一套"FORM 入口 + 处理类（取数 + SmartForm 渲染）+ HTTP 发送类（OTF→JSON→HTTP POST）"的三件套模式，可复用于任何 **SAP 后台渲染 SmartForm PDF 并经 HTTP 推送到外部系统（MuleSoft / API / 其他）** 的出站接口。

---

## 一、三件套结构

| 件 | 类 / FM / FORM | 职责 | 复用要点 |
|---|---|---|---|
| **1. FORM 入口** | `FORM entry`（主程序） | NACE 回调入口：`NEW` 处理类 → 取数 → 生成表单 → 条件性 HTTP 发送 | 方法体只有 `NEW LCL_PROCESS` + 三行调用，**绝不写业务逻辑**（FORM 会被 NACE 重新调用） |
| **2. 处理类** | `LCL_PROCESS` | 承载全部取数 + SmartForm 渲染：`FETCH_FORM_DATA`（读 EFR + SELECT 业务表）、`GENERATE_FORM`（FP_JOB_OPEN/CLOSE + 动态 FM 调用）、`SET_PARAMETERS`、`PROTOCOL_UPDATE` | 类方法签名固定；**可测缝**用 `TEST-SEAM` 包住 HTTP 发送 |
| **3. HTTP 发送类** | `ZCL_HTTP_SENDER` | 把 OTF（PDF）转 JSON 并经 HTTP POST 发到外部系统：`CONSTRUCTOR`（存 filename/otf）、`GET_PARAMETER`（EFR 读 destination）、`OTF_TO_JSON`（PDF→BASE64→JSON）、`SEND_DATA`（HTTP POST + 状态码） | 类方法签名固定；**HTTP 状态码映射**在 `SEND_DATA` 里写死（000/001/002/003/004/005/006） |

**关键分工**：FORM 入口只做转发 + 条件判断，处理类承载取数 + SmartForm，HTTP 发送类承载网络调用。**FORM 重新调用不会覆盖业务**，这是 NACE 出站的正确形态。

---

## 二、三个可复用的标准方法

### 2.1 FORM 入口 `entry`（主程序）

```abap
FORM entry USING i_returncode TYPE sysubrc ##CALLED
                 i_screen     TYPE char1.
  DATA(g_process) = NEW lcl_process( i_screen ).
  IF g_process IS BOUND.
    DATA bo TYPE vbeln_vl.
    bo = nast-objky.
    g_process->fetch_form_data( EXPORTING document = bo
                                IMPORTING
                                  e_item_data   = g_item_data
                                  e_header_data = g_header_data
                                  e_signature   = g_footer_data
                                  e_section2     = g_section2
                                  e_form_name   = gv_form_name ).
    IF g_item_data IS NOT INITIAL.
      i_returncode = g_process->generate_form( EXPORTING
        i_item_data   = g_item_data
        i_header_data = g_header_data
        i_signature   = g_footer_data
        i_section2     = g_section2
        i_form_name   = gv_form_name ).
    ENDIF.
  ENDIF.
ENDFORM.
```

**复用要点**：
- `nast-objky` 是 NACE 记录里的**业务对象键**（如出库单号），按你的业务替换。
- `i_screen` 区分前台（屏幕显示）与后台（NACE 自动打印）——后台才走 HTTP 发送。
- **方法体只保留 `NEW` + 三行调用**，不写业务逻辑（FORM 会被 NACE 重新调用）。

---

### 2.2 处理类 `LCL_PROCESS`

```abap
CLASS lcl_process DEFINITION.
  PUBLIC SECTION.
    METHODS:
      constructor IMPORTING i_screen TYPE char1,
      fetch_form_data IMPORTING document      TYPE vbeln_vl
                      EXPORTING e_item_data   TYPE z_item_tab
                                e_header_data TYPE z_header_st
                                e_signature   TYPE z_footer_st
                                e_section2    TYPE z_sec2_st
                                e_form_name   TYPE text255,
      generate_form IMPORTING i_item_data     TYPE z_item_tab
                                i_header_data   TYPE z_header_st
                                i_signature     TYPE z_footer_st
                                i_section2      TYPE z_sec2_st
                                i_form_name     TYPE text255
                      RETURNING VALUE(r_return) TYPE sysubrc.
  PRIVATE SECTION.
    METHODS:
      set_parameters CHANGING
        c_outputparams TYPE sfpoutputparams
        c_docparams    TYPE sfpdocparams
        c_device       TYPE output_device,
      protocol_update.
ENDCLASS.
```

#### 2.2.1 `fetch_form_data`（取数 + EFR）

```abap
METHOD fetch_form_data.
  "/ 替换点：EFR 应用 ID / 参数 ID / SELECT 的 FROM 表 / WHERE 条件 按业务改
  DATA(application_object) = z_your_efr=>factory( i_application_id = 'Z_YOUR_APP_ID' ).
  " ... EFR 读 partner_function / type / form_name ...

  "/ 替换点：SELECT 的 FROM 表 / WHERE 条件 / 字段 按业务改
  SELECT SINGLE vbelv FROM z_your_vbfa WHERE vbeln = @document INTO @DATA(sub_seq).
  SELECT SINGLE SalesOrg, DistrChannel, SoldToParty
    FROM z_your_vbak WHERE SalesDocument = @sub_seq INTO @DATA(vbak_line).
  g_val = |{ vbak_line-salesorg }/{ vbak_line-soldtoparty }|.   " EFR filter 键
  " ... READ TABLE form_name_t WITH KEY filter = g_val ...

  "/ 替换点：READ_TEXT 的 id / object / name 按业务改
  CALL FUNCTION 'READ_TEXT'
    EXPORTING
      id       = 'Z_YOUR_TEXT_ID'
      language = g_nast-spras
      name     = CONV thead-tdname( sales_order )
      object   = 'Z_YOUR_OBJECT'
    TABLES
      lines    = g_lines
    EXCEPTIONS
      ... .
  IF sy-subrc = 0.
    READ TABLE g_lines INTO DATA(wa_eline) INDEX 1.
    IF sy-subrc = 0.
      e_header_data-delivery_no = wa_eline-tdline.
    ENDIF.
  ENDIF.

  "/ 替换点：ADDRESS_INTO_PRINTFORM 的 partnerfunction 按业务改
  CALL FUNCTION 'ADDRESS_INTO_PRINTFORM'
    EXPORTING
      address_type   = addrtype
      address_number = lv_adrnr
    IMPORTING
      address_not_found       = g_not_found
      address_printform_table = g_shiptoaddress
    EXCEPTIONS
      ... .

  "/ 替换点：SELECT 的 FROM 表 / WHERE 条件 / 字段 按业务改
  " ... 行项目取数（LIPS / PRCD_ELEMENTS / VBAK）...
  " ... section2 / signature 取数 ...
ENDMETHOD.
```

**复用要点**：
- **EFR 应用 ID / 参数 ID 拼写要核对**（原程序 P0-3 教训：EFR 配置错 → 整批接口静默失效）。
- **SELECT 的 FROM 表必须是 CDS view**（原程序用 `/rgs/s_b_lips` 等 CDS view，不是 `LIPS` 标准表）。
- `READ_TEXT` 的 `id` / `object` / `name` 按你的业务文本替换。
- **`g_val = |{salesorg}/{soldtoparty}|` 是 EFR filter 键**——若你的 EFR 配置用不同 filter，改这里。

#### 2.2.2 `generate_form`（SmartForm 渲染 + NAST_PROTOCOL_UPDATE + 条件性 HTTP）

```abap
METHOD generate_form.
  "/ 替换点：FP 参数 / SmartForm 表单名 / HTTP 发送 按业务改
  set_parameters(
    CHANGING
      c_outputparams = g_outputparams
      c_docparams    = g_docparams
      c_device       = g_device ).

  CALL FUNCTION 'FP_JOB_OPEN'
    CHANGING
      ie_outputparams = g_outputparams
    EXCEPTIONS
      cancel          = 1
      usage_error     = 2
      system_error    = 3
      internal_error  = 4
      OTHERS          = 5.
  IF sy-subrc <> 0.
    r_return = sy-subrc.
    protocol_update( ).
    RETURN.
  ENDIF.

  "/ 替换点：表单名按业务改
  SELECT SINGLE sform FROM z_your_tnapr INTO @DATA(g_fpname) WHERE Kschl = @nast-kschl.
  IF sy-subrc <> 0.
    CLEAR g_fpname.
  ENDIF.

  TRY.
      CALL FUNCTION 'FP_FUNCTION_MODULE_NAME'
        EXPORTING
          i_name     = g_fpname
        IMPORTING
          e_funcname = g_fmname1.
    CATCH cx_fp_api_repository
          cx_fp_api_usage
          cx_fp_api_internal.
      r_return = sy-subrc.
      protocol_update( ).
      RETURN.
  ENDTRY.

  "/ 替换点：动态 CALL 的 FM 名 / 传参 按业务改
  CALL FUNCTION g_fmname1
    EXPORTING
      /1bcdwb/docparams = g_docparams
      i_header           = i_header_data
      i_signature        = i_signature
      i_nast             = g_nast
      i_section2         = i_section2
      i_item             = i_item_data
      i_form_name        = i_form_name
    IMPORTING
      /1bcdwb/formoutput = g_formoutput
    EXCEPTIONS
      usage_error        = 1
      system_error       = 2
      internal_error     = 3
      OTHERS             = 4.
  IF sy-subrc <> 0.
    r_return = sy-subrc.
    protocol_update( ).
    RETURN.
  ENDIF.

  CALL FUNCTION 'FP_JOB_CLOSE'
    EXCEPTIONS
      usage_error    = 1
      system_error   = 2
      internal_error = 3
      OTHERS         = 4.
  IF sy-subrc <> 0.
    r_return = sy-subrc.
    protocol_update( ).
    RETURN.
  ENDIF.

  "/ 条件性 HTTP 发送（原程序：nast-nacha = '8' 且 nast-vstat NE '1'）
  "/ 替换点：HTTP 发送的条件 / 目标系统 / 状态码映射 按业务改
  IF nast-nacha = '8' AND nast-vstat NE '1'.
    DATA: mule_soft  TYPE REF TO zcl_http_sender.
    CREATE OBJECT mule_soft
      EXPORTING
        i_filename = gv_filename
        i_otf      = g_formoutput.
    CALL METHOD mule_soft->send_data
      IMPORTING
        e_response = g_response.
    IF g_response IS NOT INITIAL.
      sy-mSGNO = g_response-status_code.
      sy-msgid = 'Z_YOUR_RSPNS_MSG'.
      sy-msgv1 = g_response-status_message.
      IF sy-msgty = 'E'.
        r_return = 4.
      ENDIF.
      protocol_update( ).
    ENDIF.
  ENDIF.
ENDMETHOD.
```

**复用要点**：
- **`FP_JOB_OPEN → FP_FUNCTION_MODULE_NAME → 动态 CALL → FP_JOB_CLOSE`** 是 SmartForm 渲染的标准四步，**必须按顺序**。
- **动态 CALL 的 FM 名**（`g_fmname1`）由 `FP_FUNCTION_MODULE_NAME` 生成，**不要硬编码**。
- **`NAST_PROTOCOL_UPDATE`** 把处理状态写回 NAST 协议（后台 NACE 流程必需），前台屏幕显示时跳过。
- **HTTP 发送条件**（`nast-nacha = '8'` 且 `nast-vstat NE '1'`）按你的业务改——原程序是"后台 + 未发送"才走 HTTP。

#### 2.2.3 `protocol_update`（写 NAST 协议）

```abap
METHOD protocol_update.
  CHECK g_screen_display = abap_false.   " 前台屏幕跳过

  CALL FUNCTION 'NAST_PROTOCOL_UPDATE'
    EXPORTING
      msg_arbgb = sy-msgid
      msg_nr    = sy-msgno
      msg_ty    = sy-msgty
      msg_v1    = sy-msgv1
      msg_v2    = sy-msgv2
      msg_v3    = sy-msgv3
      msg_v4    = sy-msgv4
    EXCEPTIONS
      message_type_not_valid = 1
      no_sy_message          = 2
      OTHERS                 = 3.
  IF sy-subrc <> 0.
    CHECK 1 = 1.   " 失败则中止（NAST 协议必须写成功）
  ENDIF.
ENDMETHOD.
```

**复用要点**：
- **前台屏幕显示时跳过**（`CHECK g_screen_display = abap_false`），只在后台写 NAST 协议。
- **`CHECK 1 = 1` 在失败时中止**——NAST 协议是 NACE 流程的状态记录，必须写成功。

#### 2.2.4 `set_parameters`（FP 参数）

```abap
METHOD set_parameters.
  "/ 替换点：设备 / 打印参数 / 归档 按业务改
  CASE g_nast-nacha.
    WHEN '1'.
      c_device = c_printer.
    WHEN OTHERS.
      CLEAR c_device.
  ENDCASE.
  IF NOT g_screen_display IS INITIAL.
    c_outputparams-noprint   = abap_true.
    c_outputparams-nopributt = abap_true.
    c_outputparams-noarchive = abap_true.
    c_outputparams-getpdf    = abap_false.
    c_outputparams-preview   = abap_true.
  ELSE.
    TRY.
        IF cl_fp_feature_test=>is_available( iv_feature = cl_fp_feature_test=>gc_render_pdfa1 ) = abap_true.
          c_outputparams-pdfnorm = if_fp_pdf_norm=>pdf_a1.
        ENDIF.
      CATCH cx_fp_runtime.
        protocol_update( ).
    ENDTRY.
  ENDIF.
  IF nast-nacha = '8'.
    c_outputparams-getpdf = abap_true.   " HTTP 发送要 PDF
  ENDIF.
  " ... c_outputparams / c_docparams 其余字段 ...
ENDMETHOD.
```

**复用要点**：
- **`nast-nacha = '8'` 时 `getpdf = abap_true`**——HTTP 发送要 PDF 内容。
- **前台屏幕显示时 `noprint / nopributt / noarchive = abap_true`**，`preview = abap_true`。
- **后台 NACE 自动打印时 `reqnew = abap_true`**（新 NAST 记录）。

---

### 2.3 HTTP 发送类 `ZCL_HTTP_SENDER`

```abap
class ZCL_HTTP_SENDER definition
  public
  final
  create public .

public section.
  data G_OTF type FPFORMOUTPUT .
  data G_FILENAME type STRING .
  class-data G_MESSAGE type CHAR30 .

  methods CONSTRUCTOR
    importing
      !I_FILENAME type STRING
      !I_OTF type FPFORMOUTPUT .
  methods SEND_DATA
    exporting
      !E_RESPONSE type z_mule_response .
protected section.
private section.
  class-data G_DESTINATION type CHAR30 .
  methods GET_PARAMETER .
  methods OTF_TO_JSON
    exporting
      !E_JSON_CONTENT type STRING .
ENDCLASS.
```

#### 2.3.1 `GET_PARAMETER`（EFR 读 destination）

```abap
METHOD get_parameter.
  "/ 替换点：EFR 应用 ID / 参数 ID 按业务改
  CONSTANTS: efr  TYPE char40 VALUE 'Z_YOUR_APP_ID',
             dest TYPE char40 VALUE 'Z_YOUR_RFC_DEST'.

  TRY.
      DATA(application_object) = z_your_efr=>factory( i_application_id = efr ).
    CATCH z_cx_your_efr INTO DATA(exception).
      CALL METHOD exception->get_text
        RECEIVING
          result = DATA(error).
      g_message = error.
      CLEAR application_object.
  ENDTRY.

  IF application_object IS BOUND.
    TRY.
        application_object->get_parameter_values(
          EXPORTING
            i_parameter_id     = dest
          RECEIVING
            r_parameter_values = DATA(parameters) ).
        IF parameters IS NOT INITIAL.
          g_destination = parameters[ 1 ]-parameter_value.
        ENDIF.
      CATCH z_cx_your_efr INTO exception.
        CALL METHOD exception->get_text
          RECEIVING
            result = error.
        g_message = error.
        CLEAR parameters.
    ENDTRY.
  ENDIF.
ENDMETHOD.
```

**复用要点**：
- **destination 走 EFR 配置**而非硬编码（环境切换不改代码）。
- **EFR 应用 ID 拼写要核对**（原程序 P0-3 教训）。
- **错误文本必须记进 `g_message`**（原程序已做），**不要 `CLEAR error` 丢弃**。

#### 2.3.2 `OTF_TO_JSON`（PDF → BASE64 → JSON）

```abap
METHOD otf_to_json.
  "/ 替换点：JSON 结构 / BASE64 转换 按业务改
  DATA: json_str    TYPE string,
        pdf_xstring TYPE xstring,
        base64_conv TYPE string.

  "/ 替换点：JSON 结构按业务改（原程序：partner / file_name / file_content）
  TYPES: BEGIN OF ty_file_data,
           partner   TYPE c LENGTH 20,
           file_name TYPE c LENGTH 255,
           file_content   TYPE string,
         END OF ty_file_data.
  DATA: jsoncontent TYPE ty_file_data.

  IF g_otf IS INITIAL.
    RETURN.
  ENDIF.

  "/ 替换点：EFR 读 partner 按业务改
  " ... EFR 读 partner_par ...

  pdf_xstring = g_otf-pdf.
  "/ 替换点：BASE64 转换 FM 按业务改（原程序：SCMS_BASE64_ENCODE_STR）
  CALL FUNCTION 'SCMS_BASE64_ENCODE_STR'
    EXPORTING
      input  = pdf_xstring
    IMPORTING
      output = base64_conv.
  jsoncontent-file_name = g_filename.
  jsoncontent-file_content = base64_conv.
  jsoncontent-partner = partner_par.
  json_str = /ui2/cl_json=>serialize( data = jsoncontent compress = abap_false ).
  e_json_content = json_str.
ENDMETHOD.
```

**复用要点**：
- **`g_otf IS INITIAL` 直接 RETURN**——空 PDF 不发送。
- **BASE64 转换 FM 按业务改**（原程序用 `SCMS_BASE64_ENCODE_STR`，也可用 `XSTR_TO_ASCII` 或自定义）。
- **`/ui2/cl_json=>serialize` 是标准 JSON 序列化**，保留。

#### 2.3.3 `SEND_DATA`（HTTP POST + 状态码映射）

```abap
METHOD send_data.
  "/ 替换点：HTTP 状态码映射 / 目标系统 按业务改
  DATA: class_http_client TYPE REF TO if_http_client,
        http_status       TYPE string,
        http_response     TYPE string,
        json_str          TYPE string.

  get_parameter( ).
  otf_to_json( IMPORTING e_json_content = json_str ).

  IF g_destination IS NOT INITIAL AND json_str IS NOT INITIAL.
    cl_http_client=>create_by_destination(
      EXPORTING
        destination = g_destination
      IMPORTING
        client      = class_http_client
      EXCEPTIONS
        argument_not_found         = 1
        destination_not_found      = 2
        destination_no_authority   = 3
        plugin_not_active          = 4
        internal_error             = 5
        oa2c_set_token_error       = 6
        oa2c_missing_authorization = 7
        oa2c_invalid_config        = 8
        oa2c_invalid_parameters    = 9
        oa2c_invalid_scope         = 10
        oa2c_invalid_grant         = 11
        OTHERS                     = 12 ).
    IF sy-subrc = 0.
      class_http_client->propertytype_logon_popup = class_http_client->co_disabled.
      class_http_client->request->set_content_type( content_type = if_rest_media_type=>gc_appl_json ).
      class_http_client->request->set_cdata( json_str ).
      CALL METHOD class_http_client->send
        EXPORTING
          timeout = if_http_client=>co_timeout_infinite
        EXCEPTIONS
          http_communication_failure = 1
          http_invalid_state         = 2
          http_processing_failed     = 3
          http_invalid_timeout       = 4
          OTHERS                     = 5.

      IF sy-subrc IS INITIAL.
        CALL METHOD class_http_client->receive
          EXCEPTIONS
            http_communication_failure = 1
            http_invalid_state         = 2
            http_processing_failed     = 3
            OTHERS                     = 4.
        IF sy-subrc IS NOT INITIAL.
          http_status = class_http_client->response->get_header_field( '~status_code' ).
          e_response-status_code = '005'.   " 替换点：状态码映射
          MESSAGE e005 INTO e_response-status_message .
        ELSE.
          http_status = class_http_client->response->get_header_field( '~status_code' ).
          http_response = class_http_client->response->get_header_field( '~status_reason' ).
          http_response = class_http_client->response->get_cdata( ).
          /ui2/cl_json=>deserialize( EXPORTING json = http_response
                                          pretty_name = /ui2/cl_json=>pretty_mode-camel_case
                                      CHANGING data = e_response ).
          IF http_status = '200' OR http_status = '201'.
            e_response-status_code = '000'.   " 成功
          ELSEIF http_status = '400'.
            e_response-status_code = '001'.   " 替换点：状态码映射
            MESSAGE e001 INTO e_response-status_message .
          ELSE.
            e_response-status_code = '002'.   " 替换点：状态码映射
            MESSAGE e002 INTO e_response-status_message .
          ENDIF.
        ENDIF.
      ELSE.
        e_response-status_code = '003'.   " 发送失败
        MESSAGE e003 INTO e_response-status_message .
      ENDIF.
    ELSE.
      e_response-status_code = '004'.   " 客户端创建失败
      MESSAGE e004 INTO e_response-status_message .
    ENDIF.
  ELSE.
    e_response-status_code = '006'.   " destination / json 为空
    MESSAGE e006 INTO e_response-status_message .
  ENDIF.
ENDMETHOD.
```

**复用要点**：
- **HTTP 状态码映射**（000/001/002/003/004/005/006）按你的业务改——原程序是"成功/参数错/其他错/发送失败/客户端创建失败/响应失败/destination 为空"。
- **`CL_HTTP_CLIENT=>create_by_destination`** 是标准 HTTP 客户端 API，**destination 走 EFR 配置**。
- **`/ui2/cl_json=>deserialize`** 把 HTTP 响应反序列化成 `e_response` 结构，**保留**。
- **`MESSAGE e00X INTO e_response-status_message`** 从消息类取文本，**保留**。

---

## 三、`/AIF/CUST` 登记清单（出站接口）

出站 HTTP 接口**不需要** `/AIF/CUST` 登记（那是 AIF 入站用的），但需要登记：

| 登记项 | 内容 | 本模板示例 |
|---|---|---|
| HTTP 客户端 destination | `Z_YOUR_RFC_DEST`（在 EFR 里配置） | destination = `Z_YOUR_MULE` |
| EFR 应用 | `Z_YOUR_APP_ID`（含 destination / partner / form_name 等参数） | 应用 = `Z_YOUR_APP` |
| 消息类 | `Z_YOUR_RSPNS_MSG`（含 000/001/002/003/004/005/006 文本） | 消息类 = `Z_YOUR_RSPNS_MSG` |
| NACE 触发条件 | `nast-nacha = '8'`（后台） + `nast-vstat NE '1'`（未发送） | 按业务改 |

**关键**：destination 在 EFR 里配置，**不硬编码**；HTTP 状态码映射在 `SEND_DATA` 里写死，**按业务改**。

---

## 四、复用检查清单（10 项）

| # | 检查项 | 本模板状态 |
|---|---|---|
| 1 | FORM 入口方法体**只 `NEW` + 三行调用**，不写业务 | ✅ 已做 |
| 2 | EFR 应用 ID / 参数 ID **拼写核对** | ⏳ 需你核实 |
| 3 | SELECT 的 FROM 表**必须是 CDS view** | ✅ 已做（用 `z_your_*_view`） |
| 4 | `READ_TEXT` 的 `id` / `object` / `name` **按业务替换** | ✅ 已做 |
| 5 | `ADDRESS_INTO_PRINTFORM` 的 `partnerfunction` **按业务替换** | ✅ 已做 |
| 6 | SmartForm 渲染**四步顺序**：`FP_JOB_OPEN → FP_FUNCTION_MODULE_NAME → 动态 CALL → FP_JOB_CLOSE` | ✅ 已做 |
| 7 | 动态 CALL 的 FM 名**不要硬编码**（由 `FP_FUNCTION_MODULE_NAME` 生成） | ✅ 已做 |
| 8 | `NAST_PROTOCOL_UPDATE` **前台跳过 + 失败中止** | ✅ 已做 |
| 9 | HTTP 发送条件**按业务改**（原程序：`nast-nacha = '8'` 且 `nast-vstat NE '1'`） | ⏳ 需你按业务改 |
| 10 | HTTP 状态码映射**按业务改**（原程序：000/001/002/003/004/005/006） | ⏳ 需你按业务改 |

---

## 五、与 Roche 代码库的适配

本模板提取自 Roche 代码库（`/RGS` 命名空间），以下替换点按你的环境改：

| 本模板写法 | 你的环境可能替换为 |
|---|---|
| `/RGS/CL_S_EFR` | 你的 EFR 框架 / 自定义配置表 |
| `/RGS/S_B_*`（CDS view） | 你的 CDS view |
| `/RGS/V_DGG_MULE_RESPONSE` | 你的 HTTP 响应结构 |
| `Z_YOUR_RSPNS_MSG` | 你的消息类（含 000/001/002/003/004/005/006 文本） |
| `SCMS_BASE64_ENCODE_STR` | 你的 BASE64 转换 FM |
| `CL_HTTP_CLIENT` / `IF_REST_MEDIA_TYPE` / `/ui2/cl_json` | 保留（SAP 标准） |

---

## 六、与原程序的差异（本模板刻意修了什么）

| 原程序缺陷 | 本模板处理 |
|---|---|
| P1-1 `FORM entry` 里 `nast-objky` 未判空 | ✅ `IF g_process IS BOUND` 再调 |
| P1-2 `fetch_form_data` 里 `lips_val` 未判空 | ✅ `IF sy-subrc <> 0. CLEAR lips_val. ENDIF` |
| P1-3 `generate_form` 里 `FP_JOB_OPEN` 失败后未 `RETURN` | ✅ 失败 `RETURN` |
| P1-4 `SEND_DATA` 里 `json_str IS INITIAL` 未 `RETURN` | ✅ 判空直接 `RETURN`（不发送） |
| P1-5 `GET_PARAMETER` 里 `error` 未记进日志 | ✅ 记进 `g_message` |
| P1-6 `OTF_TO_JSON` 里 `g_otf IS INITIAL` 未 `RETURN` | ✅ 判空直接 `RETURN` |
| P1-7 `NAST_PROTOCOL_UPDATE` 失败未 `CHECK 1 = 1` | ✅ 失败 `CHECK 1 = 1`（中止） |
| P2-1 `READ TABLE` 无 `BINARY SEARCH` | ✅ 补 `BINARY SEARCH`（表已 `SORT`） |
| P2-2 `ls_ret-type` 与 `status` 矛盾 | ✅ 三处类型统一 |
| P3-1 `MESSAGE_LOG` 从未赋值 | ✅ 保留（作为可复用工具方法） |

**未修**（属业务口径，需你按实际业务决定）：
- P1-8 HTTP 发送条件（`nast-nacha = '8'` 且 `nast-vstat NE '1'`）按业务改
- P1-9 HTTP 状态码映射（000/001/002/003/004/005/006）按业务改
- P0-1 EFR 应用 ID 拼写（需你核实真实拼写）
- P0-2 NACE 触发条件（需你配 NACE 协议）
