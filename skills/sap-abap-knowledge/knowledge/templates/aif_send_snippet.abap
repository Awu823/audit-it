*"! 模板：AIF 发送（/AIF/SEND_WITH_PROXY，脱敏）
*"! 替换占位符：<AIF_NS>/<AIF_IFNAME>/<AIF_IFVER>/<AIF_LOGICAL_PORT>/<AIF_MSGID>
*"!            <MESSAGE_TY>（header+items 消息结构）/ <BATCH_MSG>/<BATCH_ITEMS>
*"!            <DEFAULT_WERKS>/<BO_TYPE_BOM>/<OBJ_REP_STA>/<MESSAGE>/<IDNRK>
*"! 依赖：AIF 接口常量（gc_ns/gc_ifname/gc_ifver/gc_logical_port/gc_msgid）

    " --- AIF 应用日志（与发送分用返回表，避免污染 sy-subrc） ---
    CLEAR: return_applog, return_send.
    CONCATENATE gc_ns gc_ifname INTO subobject SEPARATED BY space.
    header-aldate = sy-datum.
    header-aluser = sy-uname.
    header-alchuser = sy-uname.
    header-object    = /aif/if_globals=>gc_aif_log_obj.
    header-subobject = subobject.
    CALL FUNCTION '/AIF/CREATE_APPL_LOG'
      EXPORTING
        is_header_log = header
        iv_ns         = gc_ns
        iv_ifname     = gc_ifname
        iv_ifversion  = gc_ifver
      CHANGING
        ct_return     = return_applog.

    " --- 发送（sap_struct = 消息结构，AIF 据此序列化 XML） ---
    CALL FUNCTION '/AIF/SEND_WITH_PROXY'
      EXPORTING
        ns                   = gc_ns
        ifname               = gc_ifname
        ifversion            = gc_ifver
        appl_log_function    = 'AIF_SEND_WITH_PROXY'
        msgguid              = msgguid
        iv_persist_xml       = 'X'
        logical_port_name    = gc_logical_port
      IMPORTING
        ximsgguid            = msgguid
        ximsgguid_out        = msgguid_out
      TABLES
        add_return_tab       = return_send
      CHANGING
        sap_struct           = <BATCH_MSG>
        error_string         = error_string
        error_long_text      = error_long
      EXCEPTIONS
        persistency_error    = 1
        status_update_failed = 2
        missing_keys         = 3
        interface_not_found  = 4
        transformation_error = 5
        general_error        = 6
        OTHERS               = 7.

    " --- 失败判定：sy-subrc <> 0 或 add_return_tab 含业务级错误（E/A） ---
    DATA(has_biz_error) = abap_false.
    LOOP AT return_send INTO DATA(ret_send)
      WHERE type = if_drf_const=>msg_type_error
         OR type = 'A'.
      has_biz_error = abap_true.
      EXIT.
    ENDLOOP.

    IF sy-subrc <> 0 OR has_biz_error = abap_true.
      " --- 错误对象五要素（drf_s_message → bapiret2） ---
      CREATE DATA error_return.                     " TYPE REF TO bapiret2
      error_return->type       = 'E'.
      error_return->id         = gc_msgid.
      error_return->number     = '002'.
      error_return->message_v1 = <MESSAGE>-header-cop_exg_no.   " 主物料
      error_return->message_v2 = <DEFAULT_WERKS>.               " 工厂（FS 固定）
      error_return->message_v3 = <IDNRK>.                       " 组件
      error_return->message_v4 = <MESSAGE>-header-change_no.    " ECN
      errmsg-bo_type       = '<BO_TYPE_BOM>'.
      errmsg-bo_key        = <MESSAGE>-header-cop_exg_no.
      errmsg-target_system = gc_logical_port.
      errmsg-message       = error_return.
      APPEND errmsg TO <MESSAGE>.
      CLEAR: errmsg, error_return.
    ENDIF.
