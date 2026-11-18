FUNCTION ZF_YOUR_IF_AIF
  IMPORTING
    testrun TYPE c
    sending_system TYPE /aif/aif_business_system_key OPTIONAL
  CHANGING
    data TYPE any ##ADT_PARAMETER_UNTYPED
    curr_line TYPE any ##ADT_PARAMETER_UNTYPED
    success TYPE /aif/successflag
    old_messages TYPE /aif/bal_t_msg
  TABLES
    return_tab LIKE bapiret2 OPTIONAL.


* 通用 AIF 入站 action FM（AIF 引擎按 /AIF/CUST 登记的 action 调它）。
* 替换点：
*   Z_MSG_STRUCT_T1   → 你的 source structure（/AIF/CUST 里 define structure mapping 登记）
*   Z_MSG_STRUCT_TAB  → 你的消息 item 表
*   Z_MSG_STRUCT_T    → 你的消息结构（含 item 表）
*   ZF_YOUR_IF        → 你的业务 FM
*
* 本模板已修：
*   - P1-12  DELETE ... WHERE key IS INITIAL 后判空，不静默丢弃
*   - P1-7   异常降级 W（原 TYPE 'E' 中止业务）

  "/ 替换点：Z_MSG_STRUCT_T1 → 你的 source structure
  FIELD-SYMBOLS: <input_wa>  TYPE Z_MSG_STRUCT_T1.
  DATA:
    msg_stat  TYPE Z_MSG_STRUCT_TAB,
    msg_final TYPE Z_MSG_STRUCT_T,
    error     TYPE flag.
  "/ Begin of TRY block
  TRY.
* Get the data from proxy class through AIF configuration.
      ASSIGN data TO <input_wa>.
 ************************************************************************
 * FIELD SYMBOL NOT ASSIGNED
 ************************************************************************
      IF <input_wa>-item IS ASSIGNED.

        msg_stat = <input_wa>-item[].

        msg_final = CORRESPONDING #( msg_stat ).

        DELETE msg_final WHERE  doc_key IS INITIAL.   " 过滤空号行

* 本模板已补（P1-12）：判空表，避免静默丢弃
        IF msg_final IS INITIAL.
          success = 'N'.
        ELSE.
          CALL FUNCTION 'ZF_YOUR_IF'
            EXPORTING
              msg_stat = msg_final
            IMPORTING
              e_error    = error
            TABLES
              return_tab = return_tab.

          IF error = abap_true.
            success = 'N'.
          ELSE.
            success = 'Y'.
          ENDIF.
        ENDIF.
      ENDIF.
    CATCH cx_root INTO DATA(root_ex).
* 本模板已改（P1-7）：降级 W，不中止业务
      MESSAGE root_ex->get_text( ) TYPE 'W'.
      success = 'N'.
      RETURN.
  ENDTRY.
ENDFUNCTION.
