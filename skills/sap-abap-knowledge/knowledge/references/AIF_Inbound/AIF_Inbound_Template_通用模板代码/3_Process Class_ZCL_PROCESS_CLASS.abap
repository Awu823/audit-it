class ZCL_PROCESS_CLASS definition
  public
  final
  create public .

public section.

  types:
    single_results  TYPE STANDARD TABLE OF bapi2045d4 .

  class-data MESSAGE_LOG type STRING .

  "/ 类方法：AIF 入站入口（被代理类调）
  class-methods EXECUTE_ASYNC_WS
    importing
      !IV_INPUT type ANY
      !IV_BAL_OBJECT type BALOBJ_D optional
      !IV_BAL_SUBOBJECT type BALSUBOBJ optional .
  "/ 实例方法：业务处理主体（被业务 FM 调）
  methods GET_DATA
    importing
      !i_msg type Z_MSG_STRUCT_T
    changing
      !RETURNTABLE type BAPIRET2_TAB
    exceptions
      ERROR .
  "/ 实例方法：发确认邮件（被 GET_DATA 调）
  methods SEND_EMAIL
    importing
      !I_BODY type STRINGTAB optional
      !EMAILS type CRMTT_EMAIL_ADDRESS optional
    exceptions
      ERROR .
  "/ 类方法：把 sy-msg* 追加进 BAPIRET2（通用工具）
  class-methods ADD_MSG
    changing
      !RETURN type BAPIRET2_TAB .
  "/ 类方法：把处理状态写回 AIF 消息（被 GET_DATA 调）
  class-methods PUSH_LOG_TO_AIF
    importing
      !MSG_DATA type Z_MSG_STRUCT optional
      !STATUS type CHAR1 optional
      !RETURN_LOG type BAPIRETTAB optional .
  "/ 类方法：从 EFR / 配置表读公司代码 + 收件人（被 GET_DATA 调）
  methods YOUR_CONTROL_KEY
    exporting
      !E_COMP_CODE type char10
      !EMAILS type CRMTT_EMAIL_ADDRESS .
protected section.
private section.
ENDCLASS.



CLASS ZCL_PROCESS_CLASS IMPLEMENTATION.


  METHOD ADD_MSG.
*"----------------------------------------------------------
* 把当前 sy-msg* 与类属性 MESSAGE_LOG 封装成 BAPIRET2 追加进 return。
* 注：MESSAGE_LOG 需外部赋值；本模板未赋值，作为可复用的工具方法保留。
*----------------------------------------------------------  *
    APPEND VALUE #( id = sy-msgid
       number = sy-msgno
       type = sy-msgty
       message_v1 = sy-msgv1
       message_v2 = sy-msgv2
       message_v3 = sy-msgv3
       message_v4 = sy-msgv4
       message    = message_log
 )  TO return.

  ENDMETHOD.


  METHOD EXECUTE_ASYNC_WS.
*"----------------------------------------------------------
* 通用 AIF 入站标准入口：
*   1. /AIF/CL_ENABLER_PROXY=>PROCESS_MESSAGE 推进 AIF 引擎
*   2. 捕获 CX_MDC_STANDARD_MESSAGE_FAULT → 用 CBS 日志框架写应用日志
*
* 本模板已修：
*   - P0-4 / P1-1：故障捕获后重新 RAISE（原程序未 RAISE → AIF 引擎无法标记消息失败）
*   - P1-7：日志对象缺失时降级 W（原 TYPE 'E' 中止业务）
*   - P1-8：iv_bal_object / iv_bal_subobject 判空回退
*----------------------------------------------------------  *

    TRY.
* Process the inbound AIF message.
        /aif/cl_enabler_proxy=>process_message( is_input               = iv_input
                                                iv_exception_classname = 'CX_MDC_STANDARD_MESSAGE_FAULT'  ).

      CATCH cx_mdc_standard_message_fault INTO DATA(cx_mdc_std_mess_fault_obj).
* if reference variable was bound.
        IF cx_mdc_std_mess_fault_obj IS BOUND.
          DATA(catch_message_var) = cx_mdc_std_mess_fault_obj->if_message~get_text( ).
        ENDIF.
* Begin of TRY block
        TRY.
* Get the factory instance log manager
            DATA(log_manager_obj) = /cbs/cl_log_factory=>get_log_manager( ).
* If reference variable was bound.
            IF log_manager_obj IS BOUND.
* Set the Application Log object and Subobject
* 替换点：iv_bal_object / iv_bal_subobject 传空时回退到默认
              log_manager_obj->set_bal_header( iv_bal_object    = COND #( WHEN iv_bal_object IS INITIAL THEN 'Z_YOUR_BAL_OBJECT' ELSE iv_bal_object )
                                               iv_bal_subobject = COND #( WHEN iv_bal_subobject IS INITIAL THEN 'Z_YOUR_BAL_SUBOBJ' ELSE iv_bal_subobject ) ).
* Get the application log pointers
              DATA(gen_log_obj) = log_manager_obj->get_misc_log( ).
* if reference variable was bound.
              IF gen_log_obj IS BOUND.
* If the application log variable is not empty.
                IF catch_message_var IS NOT INITIAL.
* Add message to the Application log
                  gen_log_obj->add_message( iv_msgid = 'Z_YOUR_MSGID'
                                            iv_msgno = '008'        " AIF Exception: &1 &2 &3 &4.
                                            iv_msgty = 'S'
                                            iv_msgv1 = catch_message_var ).
                ENDIF.
* Add message to the Application log
                gen_log_obj->add_message( iv_msgid = 'Z_YOUR_MSGID'
                                          iv_msgno = '009'        " Exception has raised during the processing call.
                                          iv_msgty = 'S' ).
* Saves the log messages into the log object/subobject
                log_manager_obj->save_all_logs( ).
              ENDIF.
            ENDIF.
          CATCH /cbs/cx_log_error INTO DATA(lo_exc).
* In case the application log object/subobject does not exist
            MESSAGE lo_exc TYPE 'W'.   " ← 本模板已改（P1-7）：W 不 E，辅助失败不中止业务
        ENDTRY.

* 重新抛出原故障，让 AIF 引擎标记消息失败（本模板已修 P0-4 / P1-1）
        IF cx_mdc_std_mess_fault_obj IS BOUND.
          RAISE cx_mdc_std_mess_fault_obj.
        ENDIF.
    ENDTRY.
  ENDMETHOD.


  METHOD get_data.
*"----------------------------------------------------------
* 业务处理主体（本模板是骨架，按业务替换 ①②③④ 四处）。
* 结构保留：① 日志 + 配置 → ② 取数 → ③ 主循环 + 改记录 → ④ 回写 + 邮件。
*
* 本模板已修：
*   - P0-1  循环内 CLEAR lt_accchg（原缺失 → 致命缺陷）
*   - P0-2  save_all_logs 前判 IS BOUND（原漏判 → 空引用短转储）
*   - P1-7  日志/邮件失败降级 W（原 TYPE 'E' 中止业务）
*   - P1-9  未找到分支 body 用 <fs_item>-key（原 msg_db-key 为空）
*   - P1-10 update_message 前判 lr_enabler IS BOUND
*   - P1-11 emails 判空再 send()
*   - P2-1  READ TABLE 用 BINARY SEARCH（表已 SORT）
*   - P2-2  未找到分支 ls_ret-type 与 status 一致（原矛盾）
*   - P2-5  EFR 错误记进日志（原 CLEAR error 丢弃）
*   - P2-7  公司代码为空直接 RETURN + 错误日志
*   - P3-2  factory 只建一次（原调两次）
*   - P3-3  CATCH ... INTO DATA(...) 双句点改单
*----------------------------------------------------------  *

*internal tables and Variables（按业务替换：lt_accchg / ls_accchg 是你的"变更行"表）
    DATA: lt_accchg  TYPE TABLE OF accchg,
          ls_accchg  TYPE accchg,
          leg_range    TYPE RANGE OF ref3,
          leg_range_wa LIKE LINE OF  leg_range,
          lt_body    TYPE stringtab,
          ls_body    TYPE string.

    DATA: ls_error_msg TYPE bapi_msg,
          ls_ret       TYPE bapiret2,
          lt_ret       TYPE bapirettab.
* Get the factory instance log manager
    DATA(log_manager_obj) = /cbs/cl_log_factory=>get_log_manager( ).
* If reference variable was bound.
    IF log_manager_obj IS BOUND.
* Set the Application Log object and Subobject
      log_manager_obj->set_bal_header( iv_bal_object    = 'Z_YOUR_BAL_OBJECT'
                                       iv_bal_subobject = 'Z_YOUR_BAL_SUBOBJ' ).
* Get the application log pointers
      TRY.
          DATA(gen_log_obj) = log_manager_obj->get_misc_log( ).
        CATCH /cbs/cx_log_error INTO DATA(lo_exc2).
          MESSAGE lo_exc2 TYPE 'W'.   " ← 本模板已改（P1-7）
      ENDTRY.
    ENDIF.

* ① 配置读取（替换点：your_control_key 读 EFR / 配置表，返回公司代码 + 收件人）
    your_control_key(
      IMPORTING
        emails  = DATA(emails)
        E_COMP_CODE = DATA(comp_code)                " 公司代码
    ).

* 本模板已补（P2-7）：公司代码未取到直接 RETURN + 错误日志（原静默跑完整批）
    IF comp_code IS INITIAL.
      TRY.
        IF gen_log_obj IS BOUND.
          gen_log_obj->add_message( iv_msgid = 'Z_YOUR_MSGID'
                                    iv_msgno = '010'        " Company code missing
                                    iv_msgty = 'E' ).
          log_manager_obj->save_all_logs( ).
        ENDIF.
      CATCH /cbs/cx_log_error INTO DATA(lo_exc3).
      ENDTRY.
      RETURN.
    ENDIF.

    ls_body = TEXT-001.
    APPEND ls_body TO lt_body.
    CLEAR: ls_body.
    APPEND ls_body TO lt_body.

    CLEAR: ls_body.
    ls_body = TEXT-002.
    APPEND ls_body TO lt_body.
    CLEAR: ls_body.
    APPEND ls_body TO lt_body.

* ② 直接匹配取数（替换点：SELECT 的 FROM 表 / WHERE 条件 / SORT 键 按业务改）
    IF i_msg IS NOT INITIAL.
      SELECT a~documentnumber AS doc_key , a~companycode AS comp_code, a~fiscalyear AS fiscal_yr ,
        b~referencekey AS ref1 ,  b~lineitem AS line_item , a~referencekey1 AS ref1_hd ,
        a~referencekey2  AS ref2_hd
        FROM z_your_bkpf_view AS a
        INNER JOIN  z_your_bseg AS b
        ON a~documentnumber = b~accdocumentnumber AND  a~companycode = b~companycode
        AND  a~fiscalyear = b~fiscalyear
        FOR ALL ENTRIES IN @i_msg WHERE a~documentnumber = @i_msg-doc_key AND  b~accounttype = 'D'
        AND a~companycode = @comp_code
        INTO TABLE @DATA(msg_data).
      IF sy-subrc = 0.
        SORT msg_data BY doc_key.   " ← 本模板已补（P2-1）
      ENDIF.
    ENDIF.

* ② 遗留号回退取数（可选；替换点：leg_range 的范围表 + SELECT 的 WHERE 条件按业务改）
    LOOP AT i_msg ASSIGNING FIELD-SYMBOL(<msg_wa>).
      READ TABLE msg_data WITH KEY doc_key = <msg_wa>-doc_key BINARY SEARCH TRANSPORTING NO FIELDS.
      IF sy-subrc NE 0.
        leg_range_wa-sign  = 'I'.
        leg_range_wa-option  = 'CP'.
        CONCATENATE '*'  <msg_wa>-doc_key '*' INTO leg_range_wa-low.
        APPEND leg_range_wa TO leg_range.
      ENDIF.
    ENDLOOP.

    IF leg_range IS NOT INITIAL.
      SELECT a~documentnumber AS doc_key , a~companycode AS comp_code, a~fiscalyear AS fiscal_yr ,
      b~referencekey AS ref1 , b~referencekeyforlineitem AS ref3,
      left( b~referencekeyforlineitem,10 ) AS leg_range ,
      b~lineitem AS line_item , a~referencekey1 AS ref1_hd , a~referencekey2  AS ref2_hd,
      a~reversedocnumber AS reversal_doc
      FROM  z_your_bkpf_view AS a
      INNER JOIN z_your_bseg AS b
      ON a~documentnumber = b~accdocumentnumber AND  a~companycode = b~companycode
      AND  a~fiscalyear = b~fiscalyear
       WHERE b~referencekeyforlineitem IN @leg_range AND  b~accounttype = 'D' AND a~companycode  = @comp_code
      INTO TABLE @DATA(msg_data_leg).
      IF sy-subrc = 0.
        SORT msg_data_leg BY doc_key.   " ← 本模板已补（P2-1）
        DELETE msg_data_leg WHERE reversal_doc IS NOT INITIAL.   " 删已冲销记录（业务口径）
      ENDIF.
    ENDIF.

* ③ 主循环：构建变更 + 改记录 FM（替换点：lt_accchg 的字段 + 改记录的 FM）
    LOOP AT i_msg ASSIGNING FIELD-SYMBOL(<fs_item>).

      READ TABLE msg_data INTO DATA(msg_db) WITH KEY doc_key = <fs_item>-doc_key BINARY SEARCH.   " ← 本模板已补（P2-1）
      IF sy-subrc = 0.
        CLEAR lt_accchg.   " ← 本模板已补（P0-1）：原缺失 → 处理第 2 张时带第 1 张的变更
        ls_accchg-fdname = 'ref1'.
        ls_accchg-oldval = msg_db-ref1.
        ls_accchg-newval = <fs_item>-ref1.
        APPEND ls_accchg TO lt_accchg.

        ls_accchg-fdname = 'ref1_HD'.
        ls_accchg-oldval = msg_db-ref1_hd.
        ls_accchg-newval = <fs_item>-ref1_hd.
        APPEND ls_accchg TO lt_accchg.

        ls_accchg-fdname = 'ref2_HD'.
        ls_accchg-oldval = msg_db-ref2_hd.
        ls_accchg-newval = <fs_item>-ref2_hd.
        APPEND ls_accchg TO lt_accchg.
      ENDIF.

      READ TABLE msg_data_leg INTO DATA(msg_db_leg) WITH KEY leg_range = <fs_item>-doc_key BINARY SEARCH.   " ← 本模板已补（P2-1）
      IF sy-subrc = 0.
        CLEAR lt_accchg.   " ← 本模板已补（P0-1）
        ls_accchg-fdname = 'ref1'.
        ls_accchg-oldval = msg_db_leg-ref1.
        ls_accchg-newval = <fs_item>-ref1.
        APPEND ls_accchg TO lt_accchg.

        ls_accchg-fdname = 'ref1_HD'.
        ls_accchg-oldval = msg_db_leg-ref1_hd.
        ls_accchg-newval = <fs_item>-ref1_hd.
        APPEND ls_accchg TO lt_accchg.

        ls_accchg-fdname = 'ref2_HD'.
        ls_accchg-oldval = msg_db_leg-ref2_hd.
        ls_accchg-newval = <fs_item>-ref2_hd.
        APPEND ls_accchg TO lt_accchg.

        MOVE-CORRESPONDING msg_db_leg TO msg_db.
      ENDIF.

      IF msg_db-doc_key IS NOT INITIAL.

* 替换点：FI_DOCUMENT_CHANGE → 你要改的 FM（BAPI_ACC_DOCUMENT_MODIFY / CDS update / 自定义 FM 等）
        CALL FUNCTION 'FI_DOCUMENT_CHANGE'
          EXPORTING
            x_lock               = 'X'
            i_comp_code              = msg_db-comp_code
            i_doc_key              = msg_db-doc_key
            i_fiscal_yr              = msg_db-fiscal_yr
            i_line_item              = msg_db-line_item
          TABLES
            t_accchg             = lt_accchg
          EXCEPTIONS
            no_reference         = 1
            no_document          = 2
            many_documents       = 3
            wrong_input          = 4
            overwrite_creditcard = 5
            OTHERS               = 6.

        IF sy-subrc NE 0.

* 失败：回滚 + 日志 + BAPIRET + 回写 AIF（本模板 P1-4 注释"逐条提交"是有意设计）
          CALL FUNCTION 'BAPI_TRANSACTION_ROLLBACK'.

          MESSAGE ID sy-msgid
                  TYPE   'I'
                  NUMBER sy-msgno
                  WITH   sy-msgv1
                           sy-msgv2
                           sy-msgv3
                           sy-msgv4
                           INTO ls_error_msg.

*Begin of try block
          TRY.
* if reference variable was bound.
              IF gen_log_obj IS BOUND.
* Add message to the Application log
                gen_log_obj->add_message( iv_msgid = 'Z_YOUR_MSGID'
                                          iv_msgno = '004'        " 处理异常
                                          iv_msgty = 'E'
                                          iv_msgv1 = msg_db-doc_key ).
* Saves the log messages into the log object/subobject
                CONCATENATE TEXT-008 msg_db-doc_key  TEXT-010 ls_error_msg INTO ls_body SEPARATED BY space.
                APPEND ls_body TO lt_body.
              ENDIF.
            CATCH /cbs/cx_log_error INTO DATA(lo_exc).
* In case the application log object/subobject does not exist
              MESSAGE lo_exc TYPE 'W'.   " ← 本模板已改（P1-7）
          ENDTRY.

          ls_ret-id = 'Z_YOUR_MSGID' .
          ls_ret-number = '004' .
          ls_ret-type = 'E' .
          CONCATENATE TEXT-008 msg_db-doc_key  TEXT-010 ls_error_msg INTO ls_ret-message  SEPARATED BY space.
          APPEND ls_ret TO lt_ret.

          push_log_to_aif(
           msg_data =  <fs_item>
           status   =   'E'
           return_log = lt_ret
          ).

          CLEAR: ls_ret , lt_ret.

        ELSE.

* 成功：提交 + 日志 + BAPIRET + 回写 AIF
          CALL FUNCTION 'BAPI_TRANSACTION_COMMIT'.

* Begin of try block
          TRY.
* if reference variable was bound.
              IF gen_log_obj IS BOUND.
* Add message to the Application log
                gen_log_obj->add_message( iv_msgid = 'Z_YOUR_MSGID'
                                          iv_msgno = '003'        " 处理成功
                                          iv_msgty = 'S'
                                          iv_msgv1 = msg_db-doc_key ).
* Saves the log messages into the log object/subobject
                CONCATENATE TEXT-008 msg_db-doc_key  TEXT-009  INTO ls_body SEPARATED BY space.
                APPEND ls_body TO lt_body.
              ENDIF.
            CATCH /cbs/cx_log_error INTO lo_exc.
* In case the application log object/subobject does not exist
              MESSAGE lo_exc TYPE 'W'.   " ← 本模板已改（P1-7）
          ENDTRY.

          ls_ret-id = 'Z_YOUR_MSGID' .
          ls_ret-number = '003' .
          ls_ret-type = 'S' .
          CONCATENATE TEXT-008 msg_db-doc_key  TEXT-009  INTO ls_ret-message  SEPARATED BY space.
          APPEND ls_ret TO lt_ret.

          push_log_to_aif(
            msg_data =  <fs_item>
            status   =   'S'
            return_log = lt_ret
          ).
          CLEAR: ls_ret , lt_ret.

        ENDIF.

      ELSE.

* 未找到：日志 + BAPIRET + 回写 AIF（本模板 P1-9 已修：用 <fs_item>-doc_key；P2-2 已修：type='E'）
        TRY.
* if reference variable was bound.
            IF gen_log_obj IS BOUND.
* Add message to the Application log
              gen_log_obj->add_message( iv_msgid = 'Z_YOUR_MSGID'
                                        iv_msgno = '005'        " 未找到
                                        iv_msgty = 'E'
                                        iv_msgv1 = <fs_item>-doc_key ).   " ← 本模板已修（P1-9）
* Saves the log messages into the log object/subobject
              CONCATENATE TEXT-011 <fs_item>-doc_key  TEXT-012  INTO ls_body SEPARATED BY space.
              APPEND ls_body TO lt_body.
            ENDIF.
          CATCH /cbs/cx_log_error INTO lo_exc.
* In case the application log object/subobject does not exist
            MESSAGE lo_exc TYPE 'W'.   " ← 本模板已改（P1-7）
        ENDTRY.

        ls_ret-id = 'Z_YOUR_MSGID' .
        ls_ret-number = '005' .
        ls_ret-type = 'E' .   " ← 本模板已修（P2-2）
        CONCATENATE TEXT-011 <fs_item>-doc_key  TEXT-012  INTO ls_ret-message  SEPARATED BY space.  " ← 本模板已修（P1-9）
        APPEND ls_ret TO lt_ret.

        push_log_to_aif(
              msg_data =  <fs_item>
              status   =   'E'
              return_log = lt_ret          " ← 本模板已补（P1-8：return_log 含当前条）
        ).
        CLEAR: ls_ret , lt_ret.
      ENDIF.
      CLEAR: msg_db, lt_accchg.   " ← 本模板已补（P0-1）
    ENDLOOP.

* 收尾：保存日志 + 发邮件（本模板 P0-2 已补 IS BOUND 守卫）
    TRY.
        IF log_manager_obj IS BOUND.
          log_manager_obj->save_all_logs( ).
        ENDIF.
      CATCH /cbs/cx_log_error INTO lo_exc.
* In case the application log object/subobject does not exist
        MESSAGE lo_exc TYPE 'W'.   " ← 本模板已改（P1-7）
    ENDTRY.

* 替换点：send_email 的 i_body / emails / TEXT-006 / TEXT-007 按业务改
    send_email(
      EXPORTING
        i_body = lt_body
        emails = emails
      EXCEPTIONS
        error  = 1
        OTHERS = 2
    ).
    IF sy-subrc <> 0.
      MESSAGE ID sy-msgid TYPE sy-msgty NUMBER sy-msgno
        WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4.
    ENDIF.
  ENDMETHOD.


  METHOD push_log_to_aif.
*"----------------------------------------------------------
* 把处理状态写回 AIF 消息。本模板已修：
*   - P1-10  update_message 前判 lr_enabler IS BOUND（原漏判 → 空引用短转储）
*   - P3-3   CATCH ... INTO DATA(lr_exception2).. 双句点改单
*----------------------------------------------------------  *
    DATA: xmlparse_r  TYPE REF TO data,
          enabler_xml TYPE REF TO /aif/cl_enabler_xml.

    DATA: lr_enabler        TYPE REF TO /aif/cl_enabler_sync_log,
          ls_aifkeys        TYPE /aif/ifkeys.

* 替换点：ns / intf / ver → 你的 /AIF/CUST 登记的命名空间 / 接口 / 版本
    DATA : ns   TYPE /aif/ns VALUE 'ZNS',
           intf TYPE /aif/ifname VALUE 'ZIF_YOUR_IF',
           ver  TYPE /aif/ifversion VALUE '1'.

    TRY.
        /aif/cl_enabler_proxy=>msgguid_from_proxy_engine(
                  IMPORTING
                    ev_msgguid = DATA(msgguid)
                ).
        CREATE OBJECT enabler_xml
          EXPORTING
            iv_msgguid   = CONV #( msgguid )
            iv_direction = 'I'
            iv_ns        = ns
            iv_ifname    = intf
            iv_ifversion = ver.

        DATA(xmlparse) = VALUE /aif/xmlparse_data(
                  ns      = ns
                  ifname  = intf
                  ifver   = ver
                  msgguid = msgguid ).

        ASSIGN msg_data TO FIELD-SYMBOL(<input_wa>).
        GET REFERENCE OF <input_wa> INTO xmlparse-xi_data.
        GET REFERENCE OF xmlparse INTO xmlparse_r.

        /aif/cl_aif_engine_factory=>get_engine(
           iv_ns            = ns
           iv_ifname        = intf
           iv_ifversion     = ver )->persist_message_data(
              EXPORTING
                iv_use_buffer = abap_false
              CHANGING
                cr_xmlparse   = xmlparse_r ).

      CATCH /aif/cx_error_handling_general
              /aif/cx_aif_engine_not_found
              /aif/cx_enabler_base
              cx_ai_system_fault INTO DATA(lr_exception).
        DATA(exc_msg) = lr_exception->get_text( ).
        MESSAGE exc_msg TYPE 'W'.
    ENDTRY.


    ls_aifkeys-ns = ns.
    ls_aifkeys-ifname = intf.
    ls_aifkeys-ifver = ver.

    TRY.
        lr_enabler = NEW /aif/cl_enabler_sync_log( iv_msgguid =  CONV #( msgguid )
                                                   iv_ns = ns
                                                   iv_ifname = intf
                                                   iv_ifversion = ver
                                                   iv_force_create_log  = abap_false ).

        IF lr_enabler IS INITIAL.
          lr_enabler = /aif/cl_enabler_sync_log=>transfer_to_aif( is_aifkeys = ls_aifkeys is_raw_structure = msg_data ).
        ENDIF.
      CATCH  /aif/cx_inf_det_base
             /aif/cx_enabler_base
             /aif/cx_aif_engine_not_found
             /aif/cx_error_handling_general
             /aif/cx_aif_engine_base INTO DATA(lr_exception1).
        exc_msg = lr_exception1->get_text( ).
        MESSAGE exc_msg TYPE 'W'.

    ENDTRY.

    TRY.
        "/ 可测缝：单测时替换 lr_enabler
        TEST-SEAM aif_enabler.
* 本模板已补（P1-10）：update_message 前判 lr_enabler IS BOUND
          IF lr_enabler IS BOUND.
            lr_enabler->update_message(  is_raw_structure = msg_data
                    iv_message_status = status
                    it_bapiret = return_log ).
          ENDIF.
        END-TEST-SEAM.
* 本模板已修（P3-3）：双句点改单句点
      CATCH /aif/cx_enabler_base INTO DATA(lr_exception2).
        "handle exception
        exc_msg = lr_exception2->get_text( ).
        MESSAGE exc_msg TYPE 'W'.
    ENDTRY.


  ENDMETHOD.


  METHOD your_control_key.
*"----------------------------------------------------------
* 从 EFR 读公司代码 + 收件邮箱。本模板已修：
*   - P3-2  factory 只建一次（原调两次）
*   - P2-5  错误文本记进日志（原 CLEAR error 丢弃）
*----------------------------------------------------------  *
    DATA: email TYPE ad_smtpadr.
*Call your framework for control keys
* 替换点：i_application_id / i_parameter_id / filter → 你的 EFR 配置
    TRY.
        DATA(application_object) = z_your_efr=>factory(
          i_application_id = 'Z_YOUR_APP_ID' ).

      CATCH z_cx_your_efr INTO DATA(excpt_o).
        DATA(error) = excpt_o->get_text( ).
    ENDTRY.
*--Pass the app id to read the control keys which are maintained
    IF application_object IS BOUND.
      TRY.
* 本模板已修（P3-2）：只建一次 factory
          application_object->get_parameter_values(
            EXPORTING
              i_parameter_id     = 'Z_YOUR_V_COMP_CODE'
            RECEIVING
              r_parameter_values = DATA(control_key_tab) ).
*--Read both parent and child control keys
          IF control_key_tab IS NOT INITIAL.
            LOOP AT control_key_tab ASSIGNING FIELD-SYMBOL(<control_key_line>) .
              IF <control_key_line>-filter = 'COMP_CODE'.
                E_COMP_CODE  = <control_key_line>-parameter_value.
              ENDIF.
            ENDLOOP.
          ENDIF.
          application_object->get_parameter_values(
            EXPORTING
              i_parameter_id     = 'Z_YOUR_V_EMAIL'
            RECEIVING
              r_parameter_values = DATA(control_key_tab1) ).
*--Read both parent and child control keys
          IF control_key_tab1 IS NOT INITIAL.
            LOOP AT control_key_tab1 ASSIGNING FIELD-SYMBOL(<control_key_line1>) .
              IF <control_key_line1>-filter = 'EMAIL'.
                email  = <control_key_line1>-parameter_value.
                APPEND email TO emails.
              ENDIF.
            ENDLOOP.
          ENDIF.
        CATCH z_cx_your_efr INTO excpt_o.
* 本模板已修（P2-5）：错误文本记进日志，不 CLEAR
          error = excpt_o->get_text( ).
          TRY.
            DATA(lm) = /cbs/cl_log_factory=>get_log_manager( ).
            IF lm IS BOUND.
              DATA(gl) = lm->get_misc_log( ).
              IF gl IS BOUND AND error IS NOT INITIAL.
                gl->add_message( iv_msgid = 'Z_YOUR_MSGID'
                                 iv_msgno = '011'        " EFR 配置错误
                                 iv_msgty = 'W'
                                 iv_msgv1 = error ).
              ENDIF.
            ENDIF.
          CATCH z_cx_your_log INTO ENDTRY.
        ENDTRY.
      ENDIF.
  ENDMETHOD.


  METHOD SEND_EMAIL.
*"----------------------------------------------------------
* 发确认邮件。本模板已修：
*   - P1-11  emails 判空再 send()（原程序空仍 send → CL_BCS 抛异常）
*   - P1-7   邮件失败降级 W（原 TYPE 'E' 中止业务）
*----------------------------------------------------------  *
*internal tables and Variables

    DATA:
      lt_body TYPE stringtab,
      ls_body TYPE string.

*This method sends out a confirmation mail
*with all details of Updated Records as well as errors

    CONSTANTS: lc_raw        TYPE so_obj_tp VALUE 'RAW'.

    DATA: lv_body             TYPE string,
          lv_obj_tp           TYPE so_obj_tp,
          lo_send_request     TYPE REF TO cl_bcs,
          lo_ex_bcs_exception TYPE REF TO cx_bcs.

    DATA: lv_subject TYPE so_obj_des.

    FIELD-SYMBOLS: <fs_line> TYPE string.


    APPEND LINES OF I_body TO lt_body.

    CLEAR: ls_body.
    APPEND ls_body TO lt_body.

    CLEAR: ls_body.
    ls_body = TEXT-003.
    APPEND ls_body TO lt_body.

    CLEAR: ls_body.
    APPEND ls_body TO lt_body.

    CLEAR: ls_body.
    ls_body = TEXT-004.
    APPEND ls_body TO lt_body.

    CLEAR: ls_body.
    APPEND ls_body TO lt_body.

    CLEAR: ls_body.
    ls_body = TEXT-005.
    APPEND ls_body TO lt_body.

* 替换点：TEXT-006 → 你的邮件主题（或走配置）
    lv_subject = TEXT-006.

    LOOP AT lt_body ASSIGNING <fs_line>.
      lv_body = | { lv_body }{ cl_abap_char_utilities=>newline }{ <fs_line> } |.
    ENDLOOP.
    lv_obj_tp = lc_raw.

* 本模板已补（P1-11）：emails 判空再 send()
    IF emails IS INITIAL.
      RETURN.
    ENDIF.

*   -----------Create the request
    TRY.
        lo_send_request = cl_bcs=>create_persistent( ).
        lo_send_request->set_document( cl_document_bcs=>create_document(
                 i_type    = lv_obj_tp
                 i_text    = cl_document_bcs=>string_to_soli( ip_string = lv_body )
                 i_subject = lv_subject ) ).

*   -----------set sender's and recipient's email address

* 替换点：TEXT-007 → 你的发件人（或走配置）
        lo_send_request->set_sender( i_sender = cl_cam_address_bcs=>create_internet_address( i_address_string = TEXT-007 ) ).

        LOOP AT emails ASSIGNING FIELD-SYMBOL(<ls_email>).
          lo_send_request->add_recipient( i_recipient = cl_cam_address_bcs=>create_internet_address( i_address_string = <ls_email> ) ).
        ENDLOOP.
*   ---------- send document ---------------------------------------
        lo_send_request->set_send_immediately( i_send_immediately = 'X' ).
        IF lo_send_request->send( )  = abap_true.
          CALL FUNCTION 'BAPI_TRANSACTION_COMMIT'.
        ENDIF.
      CATCH cx_bcs INTO lo_ex_bcs_exception.
* 本模板已改（P1-7）：邮件失败降级 W，不中止业务
        MESSAGE lo_ex_bcs_exception TYPE 'W'.
        RETURN.
    ENDTRY.

  ENDMETHOD.
ENDCLASS.
