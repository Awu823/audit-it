FUNCTION ZF_YOUR_IF
  IMPORTING
    VALUE(msg_stat) TYPE Z_MSG_STRUCT_T OPTIONAL
  EXPORTING
    VALUE(e_error) TYPE flag
  TABLES
    return_tab LIKE bapiret2 OPTIONAL.


* 通用业务 FM（RFC 形态）。
* 替换点：
*   ZCL_PROCESS_CLASS → 你的处理类
*   ZC_YOUR_ASSIST    → 你的同系统判定工具类
*   Z_YOUR_MSGID      → 你的消息类
*
* 已核实事实（与 /AIF/CUST 配置一致）：
*   - 本 FM 的唯一调用者 = ZF_YOUR_IF_AIF（同系统 CALL FUNCTION）
*   - 不是外部系统直连的 RFC 入口 → S_RFC 鉴权在该路径恒为同系统、恒放行
*   - 若你的环境有其它调用者，需按调用者系统配置 S_RFC 鉴权

  DATA: return    TYPE bapiret2_tab,
        return_wa TYPE bapiret2.
*** RFC auth check
  AUTHORITY-CHECK OBJECT 'S_RFC'
           ID 'RFC_TYPE' FIELD c_rfctype
           ID 'RFC_NAME' FIELD c_fncgrp
           ID 'ACTVT'    FIELD c_activity.
  IF sy-subrc <> 0.
    IF zc_your_assist=>is_rfc_within_same_system( ) = abap_true.
      " continue ahead
    ELSE.
      return_wa-id = 'Z_YOUR_MSGID'.
      return_wa-number = '006'.
      return_wa-type = 'S'.
      return_wa-message = TEXT-005.
      APPEND  return_wa TO return_tab.
      CLEAR return_wa.
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
* Implement suitable error handling here
      ENDIF.


    CATCH /cbs/cx_log_error INTO DATA(lo_exc).
* 本模板已改（P1-7）：日志框架错误降级 W，不中止业务
      MESSAGE lo_exc->get_text( ) TYPE 'W'.

  ENDTRY.

ENDFUNCTION.
