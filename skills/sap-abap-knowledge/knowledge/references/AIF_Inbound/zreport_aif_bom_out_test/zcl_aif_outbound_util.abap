CLASS zcl_aif_outbound_util DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

*"! <p class="shorttext synchronized">Generic AIF Outbound helper — reusable for any AIF outbound interface</p>
*"!
*"! Extracted from ZREPORT_AIF_BOM_OUT_TEST (which was derived from
*"! zcl_m1t_dcn_bom_out_impl). Encapsulates the pure AIF engine interaction so
*"! that any future AIF outbound interface can reuse it without touching the
*"! BOM business logic.
*"!
*"! Responsibilities (no WSDL-specific types — message is passed as TYPE any):
*"!   1. Async register    -> /aif/cl_enabler_xml=>transfer_to_aif
*"!   2. Real-time push    -> /AIF/SEND_WITH_PROXY (tolerates PERSISTENCY_ERROR)
*"!   3. XML persistence   -> /aif/if_application_engine~persist_message_data
*"!   4. In/outbound queue -> /aif/cl_pers_queue (add_message + save_messages)
*"!   5. Error status      -> /aif/cl_appl_log_writer=>convert_msg_to_bapiret
*"!                             + /aif/if_enabler_base~update
*"!   6. Time conversion   -> CET local date/time to UTC (24:00 rollover)
*"!
*"! Usage:
*"!   DATA(lo_aif) = NEW zcl_aif_outbound_util(
*"!     iv_ns = 'ZDEMO' iv_ifname = 'ZDEMOIF' iv_ifversion = '1'
*"!     iv_logical_port = 'ZBOMOUT' ).          " logical port only needed for real-time
*"!   lo_aif->transfer_to_aif( is_message = ls_any_structure ).
*"!   ... or ...
*"!   lo_aif->send_with_proxy( CHANGING cs_message = ls_any_structure ).
*"!   IF lo_aif->is_success( ) = abap_true. ... ENDIF.
*"!   " result state is read-only: lo_aif->get_msgguid_out( ) / get_subrc( ) / get_error_string( )
*"!
*"! All send/persist/queue/status methods are best-effort: they return a boolean
*"! and store the reason in get_error_string( ) — no exception is raised to the caller.
*"! Result members are PRIVATE; callers read them via the get_* accessors (no abstraction leak).
*"! The raw FM sy-subrc is preserved in get_subrc( ); is_hard_error( ) / get_error_text( ) are
*"! ready-made helpers so callers do not re-implement "subrc not 0/1" or the error-text fallback.
*"! send_async( ) combines transfer_to_aif + persist + queue into one call for the async path.

  PUBLIC SECTION.

    METHODS constructor
      IMPORTING
        !iv_ns           TYPE /aif/ns
        !iv_ifname       TYPE /aif/ifname
        !iv_ifversion    TYPE /aif/ifversion
        !iv_logical_port TYPE prx_logical_port_name OPTIONAL.

    "----------------------------------------------------------------
    " 1) 异步登记：只登记到 AIF 引擎，不推送外部系统（Mule 拉取场景）
    "----------------------------------------------------------------
    METHODS transfer_to_aif
      IMPORTING
        !is_message  TYPE any
        !iv_save     TYPE abap_boolean DEFAULT abap_true
      RETURNING
        VALUE(rv_ok) TYPE abap_bool.

    "----------------------------------------------------------------
    " 2) 实时推送：登记 + 立即推送到逻辑端口（容忍 PERSISTENCY_ERROR）
    "    cs_message 是 CHANGING，因为 /AIF/SEND_WITH_PROXY 会回填 controller 等
    "----------------------------------------------------------------
    METHODS send_with_proxy
      IMPORTING
        !iv_persist_xml TYPE abap_boolean DEFAULT abap_true
      CHANGING
        !cs_message     TYPE any
      RETURNING
        VALUE(rv_ok)    TYPE abap_bool.

    "----------------------------------------------------------------
    " 3) 持久化消息 XML（供中间件拉取消息体）
    "----------------------------------------------------------------
    METHODS persist_message_xml
      IMPORTING
        !iv_msgguid  TYPE sxmsmguid
        !is_message  TYPE any
      RETURNING
        VALUE(rv_ok) TYPE abap_bool.

    "----------------------------------------------------------------
    " 4) 加入进出站队列（供中间件拉取触发）
    "----------------------------------------------------------------
    METHODS add_to_queue
      IMPORTING
        !iv_msgguid    TYPE sxmsmguid
        !iv_queue_name TYPE /aif/pers_rtcfgr_name
      RETURNING
        VALUE(rv_ok)   TYPE abap_bool.

    "----------------------------------------------------------------
    " 4b) 异步登记门面：transfer_to_aif + 可选持久化 + 可选队列，一次调用。
    "     调用方无需再串三步、也无需读 get_msgguid( ) 线程 GUID。
    "     best-effort：rv_ok 反映 transfer_to_aif 是否成功；persist/queue 为副作用。
    "----------------------------------------------------------------
    METHODS send_async
      IMPORTING
        !is_message     TYPE any
        !iv_persist_xml TYPE abap_boolean DEFAULT abap_false
        !iv_queue       TYPE abap_boolean DEFAULT abap_false
        !iv_queue_name  TYPE /aif/pers_rtcfgr_name OPTIONAL
      RETURNING
        VALUE(rv_ok)    TYPE abap_bool.

    "----------------------------------------------------------------
    " 5) 写应用错误状态 + 日志回 AIF 消息
    "----------------------------------------------------------------
    METHODS set_error_status
      IMPORTING
        !iv_msgguid    TYPE sxmsmguid
        !is_message    TYPE any
        !iv_error_text TYPE string
      RETURNING
        VALUE(rv_ok)   TYPE abap_bool.

    "----------------------------------------------------------------
    " 6) 结果状态（发送后读取）—— 只读访问器
    "    结果成员为 PRIVATE，调用方只能经 get_* / is_success 只读访问，
    "    避免公开可变 DATA 造成的抽象泄漏。
    "    语义：
    "      get_msgguid      消息 GUID（ximsgguid / ev_msgguid）— 两种模式均有值
    "      get_msgguid_out  出站消息 GUID（ximsgguid_out，实时模式）；异步模式下同 msgguid
    "      get_subrc        send_with_proxy 的原始 FM sy-subrc（错误粒度保真）
    "      get_error_string 硬错误文本（仅 sy-subrc 非 0/1 时填充）
    "      get_error_long   硬错误长文本
    "      is_success       发送成功（含容忍 PERSISTENCY_ERROR；业务级 E/A 错误为 false）
    "      get_return       add_return_tab（bapiret2），业务级 E/A 行可据此定位
    "   便捷谓词/文本（免去调用方复述判定与回退）：
    "      is_hard_error    原始 sy-subrc 非 0/1（真失败）——调用方免写 get_subrc( )<>0 AND <>1
    "      get_error_text   有硬错误文本取文本，否则按 subrc 生成可读概要（供失败日志）
    "----------------------------------------------------------------
    METHODS get_msgguid
      RETURNING VALUE(rv_msgguid) TYPE sxmsmguid.
    METHODS get_msgguid_out
      RETURNING VALUE(rv_msgguid_out) TYPE sxmsmguid.
    METHODS get_subrc
      RETURNING VALUE(rv_subrc) TYPE syst_subrc.
    METHODS get_error_string
      RETURNING VALUE(rv_error_string) TYPE string.
    METHODS get_error_long
      RETURNING VALUE(rv_error_long) TYPE string.
    METHODS is_success
      RETURNING VALUE(rv_success) TYPE abap_bool.
    METHODS get_return
      RETURNING VALUE(rt_return) TYPE  bapiret2_t.
    METHODS is_hard_error
      RETURNING VALUE(rv_hard_error) TYPE abap_bool.
    METHODS get_error_text
      RETURNING VALUE(rv_error_text) TYPE string.

    "----------------------------------------------------------------
    " 7) 时间工具
    "    convert_timestamp     CET 本地时间 -> UTC（处理 24:00:00 午夜回绕）
    "    get_current_xsd_datetime  当前时间 -> UTC -> XSD datetime 字符串
    "                              （供消息头 creation_date_time，send 时覆盖用）
    "----------------------------------------------------------------
    CLASS-METHODS convert_timestamp
      CHANGING
        !cv_date TYPE datum
        !cv_time TYPE uzeit.
    CLASS-METHODS get_current_xsd_datetime
      RETURNING
        VALUE(rv_xsd_datetime) TYPE string.

  PRIVATE SECTION.

    DATA mv_ns           TYPE /aif/ns.
    DATA mv_ifname       TYPE /aif/ifname.
    DATA mv_ifver        TYPE /aif/ifversion.
    DATA mv_logical_port TYPE prx_logical_port_name.

    " 结果状态（PRIVATE，只读访问经 get_* / is_success）
    DATA mv_msgguid      TYPE sxmsmguid.
    DATA mv_msgguid_out  TYPE sxmsmguid.
    DATA mv_subrc        TYPE syst_subrc.
    DATA mv_success      TYPE abap_bool.
    DATA mv_error_string TYPE string.
    DATA mv_error_long   TYPE string.
    DATA mt_return       TYPE STANDARD TABLE OF bapiret2.
    DATA mt_bal_msgs     TYPE /aif/bal_t_msg.

ENDCLASS.


CLASS zcl_aif_outbound_util IMPLEMENTATION.


  METHOD constructor.

    mv_ns           = iv_ns.
    mv_ifname       = iv_ifname.
    mv_ifver        = iv_ifversion.
    mv_logical_port = iv_logical_port.

  ENDMETHOD.


  METHOD transfer_to_aif.

    CLEAR: mv_msgguid, mv_msgguid_out, mt_return, mt_bal_msgs,
           mv_success, mv_error_string, mv_error_long, mv_subrc.

    TRY.
        CALL METHOD /aif/cl_enabler_xml=>transfer_to_aif
          EXPORTING
            is_any_structure = is_message
            iv_cust_ns       = mv_ns
            iv_save          = iv_save
          IMPORTING
            ev_msgguid       = mv_msgguid.

        " 异步模式只产生一个消息 GUID（ev_msgguid），无独立的出站 GUID；
        " 同步到 mv_msgguid_out，保证任何发送成功后 mv_msgguid / mv_msgguid_out 均有值
        mv_msgguid_out = mv_msgguid.
        mv_success     = abap_true.
        mv_subrc       = 0.
        rv_ok          = abap_true.

      CATCH /aif/cx_inf_det_base
            /aif/cx_enabler_base
            /aif/cx_aif_engine_not_found
            /aif/cx_error_handling_general
            /aif/cx_aif_engine_base
            cx_root INTO DATA(lx_root).
        CLEAR mv_msgguid.
        mv_success      = abap_false.
        rv_ok           = abap_false.
        mv_error_string = lx_root->get_text( ).
    ENDTRY.

  ENDMETHOD.


  METHOD send_with_proxy.

    CLEAR: mv_msgguid, mv_msgguid_out, mt_return, mt_bal_msgs,
           mv_success, mv_error_string, mv_error_long, mv_subrc.

    CALL FUNCTION '/AIF/SEND_WITH_PROXY'
      EXPORTING
        ns                   = mv_ns
        ifname               = mv_ifname
        ifversion            = mv_ifver
        appl_log_function    = 'AIF_SEND_WITH_PROXY'
        msgguid              = mv_msgguid
        iv_persist_xml       = iv_persist_xml
        logical_port_name    = mv_logical_port
      IMPORTING
        ximsgguid            = mv_msgguid
        ximsgguid_out        = mv_msgguid_out
      TABLES
        add_return_tab       = mt_return
      CHANGING
        sap_struct           = cs_message
        error_string         = mv_error_string
        error_long_text      = mv_error_long
      EXCEPTIONS
        persistency_error    = 1
        status_update_failed = 2
        missing_keys         = 3
        interface_not_found  = 4
        transformation_error = 5
        general_error        = 6
        OTHERS               = 7.

    " 保留原始 sy-subrc：调用方可精确区分硬错误（非 0/1）与业务错误（0/1 + E/A 返回行）
    mv_subrc = sy-subrc.

    " --- 容忍 PERSISTENCY_ERROR(=1) 的理由 ---
    " /AIF/SEND_WITH_PROXY 的 EXCEPTIONS：
    "   sy-subrc = 0  完全成功（注册 + XML 持久化 + 实时推送）
    "   sy-subrc = 1  persistency_error：仅"消息 XML 体持久化"失败
    "                消息 GUID（ximsgguid_out）已生成、实时推送（proxy）已执行，
    "                外部系统已收到载荷，故按成功处理（容忍），不中断发送。
    "   sy-subrc = 2..7  missing_keys / interface_not_found / transformation_error
    "                 / general_error / OTHERS：真失败（消息未正确推送），记为失败。
    " 该容忍策略与生产参照实现 /RGS/CL_P_DCB_DRF_PRODVER_OUT 一致：
    "   "参照类对 PERSISTENCY_ERROR(=1) 容忍：持久化错误不中断发送循环"。
    " 适用前提：本方法为"实时推送"路径（DRF 出站即此模式）——持久化失败不影响已推送数据。
    " 边界：若将来切到"拉取型（中间件读 XML）"或需严格持久化，持久化失败会导致消息体缺失，
    "       调用方应改用 get_subrc( ) 精确分支（=1 时按告警/'SE' 处理），勿再当作成功。
    IF mv_subrc = 0 OR mv_subrc = 1.
      mv_success = abap_true.
      " 业务错误：add_return_tab 含 E/A 行则视为失败
      LOOP AT mt_return INTO DATA(ls_ret)
        WHERE type = 'E' OR type = 'A'.
        mv_success = abap_false.
        EXIT.
      ENDLOOP.
      rv_ok = mv_success.
    ELSE.
      mv_success      = abap_false.
      rv_ok           = abap_false.
      mv_error_string = |sy-subrc={ mv_subrc } / { mv_error_string } / { mv_error_long }|.
    ENDIF.

  ENDMETHOD.


  METHOD persist_message_xml.

    DATA: lr_engine   TYPE REF TO /aif/if_application_engine,
          ls_xmlparse TYPE /aif/xmlparse_data,
          lr_xmlparse TYPE REF TO data.

    rv_ok = abap_false.

    TRY.
        CALL METHOD /aif/cl_aif_engine_factory=>get_engine
          EXPORTING
            iv_ns            = mv_ns
            iv_ifname        = mv_ifname
            iv_ifversion     = mv_ifver
          RECEIVING
            rref_appl_engine = lr_engine.

        ls_xmlparse-ns      = mv_ns.
        ls_xmlparse-ifname  = mv_ifname.
        ls_xmlparse-ifver   = mv_ifver.
        ls_xmlparse-msgguid = iv_msgguid.

        GET REFERENCE OF is_message INTO ls_xmlparse-xi_data.
        GET REFERENCE OF ls_xmlparse INTO lr_xmlparse.

        lr_engine->persist_message_data(
          EXPORTING
            iv_use_buffer = abap_false
          CHANGING
            cr_xmlparse   = lr_xmlparse ).

        rv_ok = abap_true.

      CATCH /aif/cx_aif_engine_not_found
            /aif/cx_error_handling_general
            cx_root INTO DATA(lx_root).
        mv_error_string = lx_root->get_text( ).
    ENDTRY.

  ENDMETHOD.


  METHOD add_to_queue.

    DATA: lq_queue TYPE REF TO /aif/cl_pers_queue.

    rv_ok = abap_false.

    TRY.
        CREATE OBJECT lq_queue
          EXPORTING
            iv_queue_ns   = mv_ns
            iv_queue_name = iv_queue_name
          EXCEPTIONS
            not_exists    = 1
            OTHERS        = 2.

        IF sy-subrc <> 0.
          mv_error_string = |Queue "{ iv_queue_name }" not found|.
          RETURN.
        ENDIF.

        lq_queue->add_message(
          EXPORTING
            msgguid             = CONV #( iv_msgguid )
            ns                  = mv_ns
            ifname              = mv_ifname
            ifversion           = mv_ifver
          EXCEPTIONS
            lock_failed         = 1
            already_exist       = 2
            run_creation_failed = 3 ).

        IF sy-subrc = 0.
          lq_queue->save_messages(
            EXPORTING
              iv_flg_create_run   = abap_true
            EXCEPTIONS
              run_creation_failed = 1 ).
          rv_ok = boolc( sy-subrc = 0 ).
          IF rv_ok = abap_false.
            mv_error_string = 'save_messages failed (run creation failed)'.
          ENDIF.
        ELSE.
          mv_error_string = |add_message failed (sy-subrc = { sy-subrc })|.
        ENDIF.

      CATCH cx_root INTO DATA(lx_root).
        mv_error_string = lx_root->get_text( ).
    ENDTRY.

  ENDMETHOD.


  METHOD send_async.
    " 异步登记门面：transfer_to_aif（只登记）→ 可选 persist_message_xml → 可选 add_to_queue。
    " 与调用方直接串三步等价（best-effort）：rv_ok 反映 transfer 是否成功；
    " persist/queue 为副作用（失败仅记录、不抛异常）。
    rv_ok = abap_false.
    IF transfer_to_aif(
         is_message = is_message
         iv_save    = abap_true ) = abap_true.
      IF iv_persist_xml = abap_true.
        persist_message_xml(
          iv_msgguid = mv_msgguid
          is_message = is_message ).
      ENDIF.
      IF iv_queue = abap_true.
        add_to_queue(
          iv_msgguid    = mv_msgguid
          iv_queue_name = iv_queue_name ).
      ENDIF.
      rv_ok = abap_true.
    ENDIF.
  ENDMETHOD.


  METHOD set_error_status.

    DATA: lx_enabler  TYPE REF TO /aif/cl_enabler_xml,
          bal_context TYPE /aif/bal_context.

    rv_ok = abap_false.
    CLEAR mt_bal_msgs.

    " ① 错误文本 -> BAPIRET 行
    /aif/cl_appl_log_writer=>convert_msg_to_bapiret(
      EXPORTING
        iv_msgty        = 'E'
        iv_msgid        = '/AIF/MES'
        iv_msgno        = '000'
        iv_msgv1        = iv_error_text
        is_bal_context  = VALUE /aif/bal_context(
           msg_category = /aif/if_globals=>gc_msg_category_code-others
           function     = sy-repid
           sydate       = sy-datum
           sytime       = sy-uzeit )
      CHANGING
        ct_bal_messages = mt_bal_msgs ).

    " ② 写错误状态 + 日志到 AIF 消息
    TRY.
        CREATE OBJECT lx_enabler
          EXPORTING
            iv_msgguid   = CONV #( iv_msgguid )
            iv_direction = 'O'
            iv_ns        = mv_ns
            iv_ifname    = mv_ifname
            iv_ifversion = mv_ifver.

        lx_enabler->/aif/if_enabler_base~update(
          iv_message_status_flag = /aif/if_globals=>gc_eh_file_status-application_error
          is_raw_structure       = is_message
          it_log_messages        = mt_bal_msgs
          iv_msgguid             = CONV #( iv_msgguid )
          iv_user_name           = cl_abap_syst=>get_user_name( )
          iv_create_date         = sy-datum
          iv_create_time         = sy-uzeit ).

        rv_ok = abap_true.

      CATCH /aif/cx_enabler_base
            cx_root INTO DATA(lx_root).
        mv_error_string = lx_root->get_text( ).
    ENDTRY.

  ENDMETHOD.


  METHOD get_msgguid.
    rv_msgguid = mv_msgguid.
  ENDMETHOD.


  METHOD get_msgguid_out.
    rv_msgguid_out = mv_msgguid_out.
  ENDMETHOD.


  METHOD get_subrc.
    rv_subrc = mv_subrc.
  ENDMETHOD.


  METHOD get_error_string.
    rv_error_string = mv_error_string.
  ENDMETHOD.


  METHOD get_error_long.
    rv_error_long = mv_error_long.
  ENDMETHOD.


  METHOD is_success.
    rv_success = mv_success.
  ENDMETHOD.


  METHOD get_return.
    rt_return = mt_return.
  ENDMETHOD.


  METHOD is_hard_error.
    " 原始 FM sy-subrc 非 0/1 为真失败（0=成功，1=PERSISTENCY_ERROR 容忍）。
    " 调用方免写 get_subrc( ) <> 0 AND get_subrc( ) <> 1。
    rv_hard_error = boolc( mv_subrc <> 0 AND mv_subrc <> 1 ).
  ENDMETHOD.


  METHOD get_error_text.
    " 失败文本：有硬错误文本取文本；否则按 sy-subrc 生成可读概要。
    " 仅在失败路径调用（rv_ok = abap_false）；此时 subrc=0/1 即业务级 E/A 错误。
    IF mv_error_string IS NOT INITIAL.
      rv_error_text = mv_error_string.
    ELSEIF mv_subrc = 0 OR mv_subrc = 1.
      rv_error_text = |AIF business error (E/A rows in return, sy-subrc={ mv_subrc })|.
    ELSE.
      rv_error_text = |AIF send failed (sy-subrc={ mv_subrc })|.
    ENDIF.
  ENDMETHOD.


  METHOD convert_timestamp.

    DATA: lv_time_stamp_utc TYPE timestamp.

    " 24:00:00 -> 次日 00:00:00
    IF cv_time = '240000'.
      CLEAR cv_time.
      IF cv_date IS NOT INITIAL.
        cv_date = cv_date + 1.
      ENDIF.
    ENDIF.

    " CET -> UTC
    CONVERT DATE cv_date TIME cv_time INTO TIME STAMP lv_time_stamp_utc TIME ZONE 'CET'.
    IF sy-subrc = 0.
      CONVERT TIME STAMP lv_time_stamp_utc TIME ZONE 'UTC'
        INTO DATE DATA(lv_utc_date) TIME DATA(lv_utc_time).
      IF sy-subrc = 0.
        cv_date = lv_utc_date.
        cv_time = lv_utc_time.
      ENDIF.
    ENDIF.

  ENDMETHOD.


  METHOD get_current_xsd_datetime.
    " 当前时间 -> CET->UTC -> XSD datetime 字符串（供消息头 creation_date_time）。
    " 封装 send 时覆盖样板：sy-datum/sy-uzeit + convert_timestamp + map_xsddatetime_long_z_out。
    DATA: lv_date TYPE datum,
          lv_time TYPE uzeit.

    lv_date = sy-datum.
    lv_time = sy-uzeit.
    convert_timestamp(
      CHANGING
        cv_date = lv_date
        cv_time = lv_time ).
    TRY.
        cl_bs_soa_convert_xsddatetime=>map_xsddatetime_long_z_out(
          EXPORTING
            iv_date         = lv_date
            iv_time         = lv_time
          IMPORTING
            ev_xsd_datetime = rv_xsd_datetime ).
      CATCH cx_bs_soa_exception.
        CLEAR rv_xsd_datetime.
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
