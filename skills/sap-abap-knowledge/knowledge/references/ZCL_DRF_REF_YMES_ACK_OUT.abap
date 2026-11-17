CLASS ZCL_DRF_REF_YMES_ACK_OUT DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.

    INTERFACES if_drf_outbound .

    TYPES:
      tt_key_table
        "TYPE SORTED TABLE OF comes_s_drf_prod_key " ZP_MCN_YP_MCN_FLT_LAEDA
        "WITH UNIQUE KEY aufnr .

          TYPE SORTED TABLE OF Zp_dde_drf_ymes_key
        WITH UNIQUE KEY lognumber .
    TYPES:
      BEGIN OF ty_mes_ack,
        msgguid           TYPE guid_32,
        lognumber	        TYPE balognr,
        business_system   TYPE mdg_business_system,
        correlationid     TYPE guid_32, "Zp_dde_mes_replication_uid,
        status            TYPE /aif/proc_status,
        success           TYPE /aif/proc_status,
        entity            TYPE Zp_dde_entity,
        log_handle        TYPE balloghndl,
        source_system(20) TYPE c,
        target_system(20) TYPE c,
      END OF ty_mes_ack .
    TYPES:
      tt_mes_ack TYPE STANDARD TABLE OF ty_mes_ack .

    CONSTANTS c_balhdr_user TYPE baluser VALUE 'MS%CMESS' ##NO_TEXT.    "  ACK DRFOUT filter
    CONSTANTS c_balhdr_object TYPE balobj_d VALUE '/AIF/LOG' ##NO_TEXT.
    CONSTANTS c_balhdr_subobject TYPE balsubobj VALUE '/AIF/NO_SUB_LOG' ##NO_TEXT.
    CONSTANTS c_balhdr_alprog TYPE balprog VALUE '/AIF/CL_FILE_PROCESSING=======CP' ##NO_TEXT.
    CONSTANTS c_mes_ack_entity(20) TYPE  c VALUE 'MES_FUNCTIONAL_ACK' ##NO_TEXT.
    CONSTANTS c_aif_ns             TYPE /aif/ns VALUE 'AIF_NS'.

    CLASS-METHODS class_constructor .
    METHODS constructor .
PRIVATE SECTION.

  "DATA ms_ack_msg TYPE Zp_dde_sap2mes___rgs__p_d1 .
  DATA:
    mt_mes_ack_msg TYPE TABLE OF Zp_dde_sap2mes___rgs__p_d1,
    mt_mes_ack     TYPE tt_mes_ack,
    mt_p_b_mes_ack TYPE TABLE OF Zp_b_mes_ack
    .

  TYPES:
    BEGIN OF ty_balhdr_buf,
      lognumber	 TYPE balognr,
      log_handle TYPE balloghndl,
      aldate     TYPE baldate,
      altime     TYPE baltime,
    END OF ty_balhdr_buf .
  TYPES:
  tt_balhdr_buf TYPE STANDARD TABLE OF ty_balhdr_buf.

  DATA mt_balhdr_buf TYPE tt_balhdr_buf.


  DATA own_logical_system TYPE tbdls-logsys.

  "DATA mt_mdg_bus_sys_tech_logsys TYPE tt_mdg_bus_sys_tech .
  DATA ms_runtime_parameter_ext TYPE drf_s_runtime_parameter_ext .
  DATA mo_drf_ymes_ack_filter TYPE REF TO if_drf_filter .

  CLASS-DATA mo_drf_ymes_ack_out TYPE REF TO ZCL_DRF_REF_YMES_ACK_OUT .      "ZCL_DRF_REF_PROCORD_OUT . "
  "CLASS-DATA gc_mes_procord_key_structure TYPE string VALUE 'ZCL_DRF_REF_PROCORD_OUT=>tt_key_table' ##NO_TEXT.
  CLASS-DATA gc_mes_procord_key_structure TYPE string VALUE 'ZCL_DRF_REF_YMES_ACK_OUT=>tt_key_table' ##NO_TEXT.
  "data SENDING_CODE_VERSION type CHAR02 value '01' ##NO_TEXT.
  DATA ex_object_cx_root TYPE REF TO cx_root  ##NEEDED.
  DATA ex_text TYPE string  ##NEEDED.
  DATA ex_text_long TYPE string  ##NEEDED.

  METHODS get_drf_filter
    RETURNING
      VALUE(ro_procord_filter) TYPE REF TO if_drf_filter .
ENDCLASS.



CLASS ZCL_DRF_REF_YMES_ACK_OUT IMPLEMENTATION.


  METHOD class_constructor.
  ENDMETHOD.


  METHOD constructor.
*----------------------------------------------------------------------------------------*
* Functional Spec: Functional Acknowledgment
* Technical Spec: Functional Acknowledgment
* Process: Monitor Production Process Performance
* History -------------------------------------------------------------------------------*
* Date       | Change           | Contributor               | Description
*----------------------------------------------------------------------------------------*
*----------------------------------------------------------------------------------------*


    SELECT namespace , inf_name , entity , message_index
      FROM Zp_b_mes_ack
      INTO CORRESPONDING FIELDS OF TABLE @mt_p_b_mes_ack
      WHERE namespace EQ @c_aif_ns.
    .
    DATA(rc) = sy-subrc ##needed.


    CALL FUNCTION 'OWN_LOGICAL_SYSTEM_GET'
      IMPORTING
        own_logical_system             = own_logical_system
      EXCEPTIONS
        own_logical_system_not_defined = 1
        OTHERS                         = 2.

    rc = sy-subrc.


    DATA(diag_truncate_log) = space.    "ToDo - test only - to be removed
    IF diag_truncate_log EQ 'X'.
      CALL FUNCTION 'DB_TRUNCATE_TABLE'
        EXPORTING
          tabname = 'ZP_DDE_AIFAK'.

      rc = sy-subrc.
    ENDIF.

  ENDMETHOD.


  METHOD GET_DRF_FILTER.

*    IF mo_procord_filter IS NOT BOUND.
*      mo_procord_filter = NEW ZCL_DRF_REF_PROCORD_FLTR( ).
*    ENDIF.
*    ro_procord_filter = mo_procord_filter.


    IF mo_drf_ymes_ack_filter IS NOT BOUND.
      mo_drf_ymes_ack_filter  = NEW Zcl_p_dde_drf_ymes_ack_flt( ).
    ENDIF.
    ro_procord_filter = mo_drf_ymes_ack_filter
    .



  ENDMETHOD.


  METHOD if_drf_outbound~analyze_changes_by_chg_pointer.

  ENDMETHOD.


  METHOD if_drf_outbound~analyze_changes_by_mdg_cp.

  ENDMETHOD.


  METHOD if_drf_outbound~analyze_changes_by_others.


  ENDMETHOD.


  METHOD if_drf_outbound~apply_node_inst_filter_multi.
    RETURN.
  ENDMETHOD.


  METHOD if_drf_outbound~apply_node_inst_filter_single.
    RETURN.
  ENDMETHOD.


  METHOD if_drf_outbound~build_parallel_package.
  ENDMETHOD.


  METHOD if_drf_outbound~enrich_filter_criteria.

***    DATA(business_system)  =  mo_drf_ymes_ack_out->ms_runtime_parameter_ext-business_system.
***
***    DATA: t_selopt   TYPE rsds_selopt_t.
***    "          T_SELFIELD type RSDS_FRANGE_T,
***    "          T_SELTAB   type RSDS_TRANGE,
***    "          T_EXPRS    type RSDS_TEXPR,
***    "          WA_EXPRS   type RSDS_EXPR,
***    "          T_CLAUS    type RSDS_TWHERE.
***
***    DATA: wa_selopt   TYPE rsdsselopt,
***          wa_selfield TYPE rsds_frange,
***          wa_seltab   TYPE rsds_range.
***
***    wa_seltab-tablename   = 'ZP_S_PROCORD_FLT1'.
***    wa_selfield-fieldname = 'MES'.
***    wa_selopt-sign    = 'I'.
***    wa_selopt-option  = 'EQ'.
***    wa_selopt-low     = business_system .
***    APPEND wa_selopt TO t_selopt.
***    CLEAR wa_selopt.
***    APPEND LINES OF t_selopt TO wa_selfield-selopt_t.
***    CLEAR t_selopt.
***    APPEND wa_selfield TO wa_seltab-frange_t.
***    CLEAR wa_selfield.
***    APPEND wa_seltab TO et_add_external_criteria.
***    CLEAR wa_seltab.

  ENDMETHOD.


  METHOD if_drf_outbound~finalize.



  ENDMETHOD.


  METHOD if_drf_outbound~initialize.
*----------------------------------------------------------------------------------------*
* Functional Spec: Functional Acknowledgment
* Technical Spec: Functional Acknowledgment
* Process: Monitor Production Process Performance
* History -------------------------------------------------------------------------------*
* Date       | Change           | Contributor               | Description
*----------------------------------------------------------------------------------------*
*----------------------------------------------------------------------------------------*

    CREATE OBJECT mo_drf_ymes_ack_out.
    mo_drf_ymes_ack_out->ms_runtime_parameter_ext = is_runtime_param.

    es_runtime_param_out_impl-table_type_name =  gc_mes_procord_key_structure.
    eo_if_drf_outbound = mo_drf_ymes_ack_out.

  ENDMETHOD.


  METHOD if_drf_outbound~map_data2message.
*----------------------------------------------------------------------------------------*
* Functional Spec: Functional Acknowledgment
* Technical Spec: Functional Acknowledgment
* Process: Monitor Production Process Performance
* History -------------------------------------------------------------------------------*
* Date       | Change           | Contributor               | Description
*----------------------------------------------------------------------------------------*
*----------------------------------------------------------------------------------------*


    CLEAR  mt_mes_ack_msg.

    DATA(business_system)    =  mo_drf_ymes_ack_out->ms_runtime_parameter_ext-business_system ##needed.
    DATA(ir_application_log) = mo_drf_ymes_ack_out->ms_runtime_parameter_ext-bal ##needed.

    DATA mes_ack_msg TYPE Zp_dde_sap2mes___rgs__p_d1.


    FIELD-SYMBOLS <ls_key> TYPE  Zp_dde_drf_ymes_key.


    ASSIGN ir_relevant_object->* TO <ls_key>.
    DATA(rc) = sy-subrc ##needed.

    READ TABLE mt_mes_ack WITH KEY lognumber = <ls_key> INTO DATA(mes_ack).
    rc  = sy-subrc.

    MOVE-CORRESPONDING mes_ack TO mes_ack_msg.
    "mes_ack_msg-entity = c_mes_ack_entity. "


    READ TABLE mt_balhdr_buf WITH KEY lognumber = <ls_key>-lognumber INTO DATA(balhdr_buf) ##needed.
    rc  = sy-subrc.


    DATA l_szal_lognumber TYPE szal_lognumber.
    DATA lognumbers         TYPE szal_lognumbers.

    DATA header_data        TYPE STANDARD TABLE OF balhdr.
    DATA messages           TYPE STANDARD TABLE OF balm.


    l_szal_lognumber-item = <ls_key>-lognumber.
    APPEND l_szal_lognumber TO lognumbers.

    DATA a_msg_item TYPE Zp_dde_sap2mes___rgs__p_dd.
    DATA a_msg_tab TYPE Zp_dde_sap2mes___rgs___tab.

    CALL FUNCTION 'APPL_LOG_READ_DB_WITH_LOGNO'
      TABLES
        lognumbers  = lognumbers
        header_data = header_data
        messages    = messages.

    LOOP AT messages ASSIGNING FIELD-SYMBOL(<messages>).
      CLEAR a_msg_item.
      MESSAGE ID <messages>-msgid  TYPE  <messages>-msgty NUMBER <messages>-msgno
        INTO  a_msg_item-msg_text
    WITH  <messages>-msgv1  <messages>-msgv2  <messages>-msgv3  <messages>-msgv4 .

      CONCATENATE <messages>-msgid  <messages>-msgno INTO a_msg_item-msg_code.
      a_msg_item-msgty =   <messages>-msgty.

      APPEND a_msg_item TO a_msg_tab.
      mes_ack_msg-message-item =  a_msg_tab.

    ENDLOOP.



    APPEND mes_ack_msg TO mt_mes_ack_msg.


  ENDMETHOD.


  METHOD if_drf_outbound~read_complete_data.
*----------------------------------------------------------------------------------------*
* Functional Spec: Functional Acknowledgment
* Technical Spec: Functional Acknowledgment
* Process: Monitor Production Process Performance
* History -------------------------------------------------------------------------------*
* Date       | Change           | Contributor               | Description
*----------------------------------------------------------------------------------------*
*----------------------------------------------------------------------------------------*

    IF ms_runtime_parameter_ext-runmod <> if_drf_const=>runmod_bypass_filter.
      "filter class was already called by framework (incl. external criteria)
      "-> no need for filtering again
      "return.
    ELSE.
      DATA(lt_filtered_object) = VALUE tt_key_table( ).
      get_drf_filter( )->apply_filter(
      EXPORTING
        iv_appl                 = ms_runtime_parameter_ext-appl
        iv_business_system      = ms_runtime_parameter_ext-business_system
        iv_outb_impl            = ms_runtime_parameter_ext-outb_impl
        iv_runmod               = ms_runtime_parameter_ext-runmod
        io_bal                  = ms_runtime_parameter_ext-bal
        iv_dlmod                = ms_runtime_parameter_ext-dlmod
        it_unfiltered_objects   = ct_relevant_objects
        is_c_fobj               = VALUE #( ) "filter config not available / required
        is_filt                 = VALUE #( ) "filter config not available / required
        it_external_criteria    = VALUE #( ) "must stay empty, stipulated by runmod
      IMPORTING
        et_filtered_objects     = lt_filtered_object
        ).
      ct_relevant_objects = lt_filtered_object.
    ENDIF.

    FIELD-SYMBOLS <ls_key> TYPE  Zp_dde_drf_ymes_key.


    "DATA l_mes_ack_msg  TYPE   Zp_dde_sap2mes___rgs__p_d1.
    DATA l_mes_ack TYPE ty_mes_ack.
    DATA lognumber_tab TYPE TABLE OF balognr.
    DATA lognumber_tab_clean TYPE TABLE OF balognr.
    "DATA l_entity TYPE Zp_dde_entity.

    LOOP AT ct_relevant_objects ASSIGNING <ls_key> .
      APPEND <ls_key>-lognumber TO lognumber_tab.
    ENDLOOP.

    IF lognumber_tab IS INITIAL.
      RETURN.
    ENDIF.

*  IMES_BC	1	ZP_DDE_BC_TB
    READ TABLE mt_p_b_mes_ack WITH KEY message_index = 'ZP_DDE_AIF_C' INTO DATA(p_b_mes_ack).
    DATA(rc) = sy-subrc ##needed.

    SELECT  msgguid, status, business_system , mes_replication_uuid , lognumber
       FROM Zp_dde_aif_c
      FOR ALL ENTRIES IN @lognumber_tab
        WHERE lognumber EQ @lognumber_tab-table_line
      INTO TABLE @DATA(p_dde_aif_c).

    IF sy-subrc EQ 0.
      LOOP AT p_dde_aif_c ASSIGNING FIELD-SYMBOL(<p_dde_aif_c>).
        MOVE-CORRESPONDING <p_dde_aif_c> TO l_mes_ack.

        l_mes_ack-correlationid = <p_dde_aif_c>-mes_replication_uuid.
        l_mes_ack-success = <p_dde_aif_c>-status.
        l_mes_ack-source_system =  own_logical_system. "sy-sysid.
        l_mes_ack-target_system = <p_dde_aif_c>-business_system.

        l_mes_ack-entity = p_b_mes_ack-entity.

        APPEND l_mes_ack TO mt_mes_ack.
      ENDLOOP.
    ENDIF.

    "ZP_DDE_BC_TB IMES_BC
    READ TABLE mt_p_b_mes_ack WITH KEY message_index = 'ZP_DDE_BC_TB' INTO p_b_mes_ack.
    rc = sy-subrc.


    SELECT  msgguid, status, business_system , mes_replication_uuid , lognumber
    FROM Zp_dde_bc_tb
    FOR ALL ENTRIES IN @lognumber_tab
    WHERE lognumber EQ @lognumber_tab-table_line
    INTO TABLE @DATA(p_dde_bc_tb).

    IF sy-subrc EQ 0.
      LOOP AT p_dde_bc_tb ASSIGNING FIELD-SYMBOL(<p_dde_bc_tb>).
        MOVE-CORRESPONDING <p_dde_bc_tb> TO l_mes_ack.

        l_mes_ack-correlationid = <p_dde_bc_tb>-mes_replication_uuid.
        l_mes_ack-success = <p_dde_bc_tb>-status.
        l_mes_ack-source_system =  own_logical_system. "sy-sysid.
        l_mes_ack-target_system = <p_dde_bc_tb>-business_system.

        l_mes_ack-entity = p_b_mes_ack-entity.

        APPEND l_mes_ack TO mt_mes_ack.
        APPEND <ls_key>-lognumber TO lognumber_tab_clean.
      ENDLOOP.
    ENDIF.
    "IMES_BC


*  IMES_POC  1 ZP_DDE_AIF_C
*  IMES_QN	1	ZP_DDE_IDX1
    IF lognumber_tab_clean IS NOT INITIAL.
      SELECT
        lognumber	 ,      log_handle   ,    aldate   , altime
      FROM balhdr
      FOR ALL ENTRIES IN @lognumber_tab_clean
         WHERE lognumber EQ @lognumber_tab_clean-table_line
      INTO CORRESPONDING FIELDS OF TABLE @mt_balhdr_buf
      .
      rc = sy-subrc.
    ENDIF.


  ENDMETHOD.


  METHOD if_drf_outbound~send_message.
*----------------------------------------------------------------------------------------*
* Functional Spec: Functional Acknowledgment
* Technical Spec: Functional Acknowledgment
* Process: Monitor Production Process Performance
* History -------------------------------------------------------------------------------*
* Date       | Change           | Contributor               | Description
*----------------------------------------------------------------------------------------*
*----------------------------------------------------------------------------------------*


    DATA:
      p_ns           TYPE /aif/ns VALUE 'AIF_NS',
      p_ifname       TYPE /aif/ifname VALUE 'AIF_IFNAME_ACK',
      p_ifver        TYPE /aif/ifversion VALUE '1',
      p_logical_port TYPE prx_logical_port_name VALUE 'AIF_LOGICAL_PORT_ACK'.

    DATA(verbose) = space ##NEEDED.
    "DATA: ls_orders_soa TYPE ord_pre.

    DATA it_orders  TYPE  ops_t_caufvdget ##NEEDED.


    DATA: lo_wsprotocol_message_id TYPE REF TO if_wsprotocol_message_id.

    DATA(business_system) = ms_runtime_parameter_ext-business_system.

    DATA(ir_application_log) = mo_drf_ymes_ack_out->ms_runtime_parameter_ext-bal.
    "Do not replicate order if nothing was changed


    "DATA: lv_order TYPE comes_s_drf_prod_key.
    "DATA: lr_order TYPE REF TO comes_s_drf_prod_key.

    DATA: lv_ack_key TYPE Zp_dde_drf_ymes_key.
    DATA: lr_ack_key TYPE REF TO Zp_dde_drf_ymes_key.


    " data MSGGUIDS type SYSUUID_C32.
    DATA lt_return  TYPE  bapiret2_t.
    DATA ls_return  TYPE  bapiret2.

    "data LV_MSGGUID type  GUID_32.



    DATA: lv_header    TYPE bal_s_log,
          lv_subobject TYPE balsubobj.


    DATA: ximsgguid     TYPE  sxmsmguid,
          ximsgguid_out TYPE  sxmsmguid.




    DATA mes_ack_msg    TYPE  Zp_dde_sap2mes___rgs__p_d1.

    "DATA lr_proxy TYPE REF TO co_ppint_mfgord_exe_req_out_v2. "
    DATA lr_proxy TYPE REF TO Zco_p_dde_sap2mes___rgs__p.

    FIELD-SYMBOLS: <ls_obj_rep_sta>  TYPE drf_s_obj_rep_sta_attr.

    "BREAK-POINT ID drf_prod.
    "DATA: lt_aufnr TYPE STANDARD TABLE OF ord_pre  ##needed.




    DATA aif_lr_proxy TYPE REF TO object ##NEEDED..



    READ TABLE ct_obj_rep_sta ASSIGNING <ls_obj_rep_sta> INDEX 1.
    IF sy-subrc NE 0.
      "TODO - message
      RETURN.
    ENDIF.

    READ TABLE mt_mes_ack WITH KEY lognumber = <ls_obj_rep_sta>-object_id INTO DATA(mes_ack).
    IF sy-subrc NE 0.
      "TODO - message
      RETURN.
    ENDIF.

    READ TABLE mt_mes_ack_msg WITH KEY correlationid = mes_ack-correlationid INTO mes_ack_msg.
    IF sy-subrc NE 0.
      "TODO - message
      RETURN.
    ENDIF.

    IF  mes_ack_msg IS INITIAL.
      "TODO - message
      RETURN.
    ENDIF.


    IF  mes_ack_msg-target_system NE business_system.
      "TODO - message
      RETURN.
    ENDIF.



    lv_ack_key = <ls_obj_rep_sta>-object_id.


    "lv_ack_key-lognumber = lv_aufnr.
    GET REFERENCE OF lv_ack_key INTO lr_ack_key .





    TRY .
        CREATE OBJECT lr_proxy.
        lo_wsprotocol_message_id ?= lr_proxy->get_protocol( if_wsprotocol=>message_id ).
        aif_lr_proxy ?=  lr_proxy.

      CATCH cx_ai_system_fault INTO DATA(lo_exception).
        CALL METHOD lo_exception->if_message~get_longtext
          RECEIVING
            result = ex_text_long.
        CALL METHOD lo_exception->if_message~get_text RECEIVING result = ex_text.
        CALL METHOD ir_application_log->add_msg_re
          EXPORTING
            iv_msgno             = '015'
            iv_msgid             = if_drf_const=>msg_id_common
            iv_msgv2             = ex_text
            iv_msgv3             = ex_text_long
            ix_exception_catched = lo_exception.
    ENDTRY.


    "DATA(is_valid) = order_status_is_valid_for_drf( lv_order ).

    DATA: is_valid TYPE bool VALUE abap_true. "


    IF is_valid NE abap_true.

      "CLEAR  mes_ack_msg.

      ir_application_log->add_msg(
      iv_msgty = if_drf_const=>msg_type_warning
      iv_msgno = '012'
      iv_msgid = 'ZP_DDE_YMES_ACK'
    iv_msgv1 = lv_ack_key-lognumber "lv_aufnr
      iv_msgv2 = is_valid
      "IV_MSGV3 =
      ir_object      =  lr_ack_key  "lr_order
      ).

    ENDIF.


    lv_header-aldate = sy-datum.
    lv_header-aluser = sy-uname.
    lv_header-alchuser = sy-uname.
    CONCATENATE p_ns p_ifname INTO lv_subobject SEPARATED BY space.
    lv_header-object = /aif/if_globals=>gc_aif_log_obj.
    lv_header-subobject = lv_subobject.
    ls_return-type = 'I'.
    ls_return-id = 'ZP_DDE_YMES_ACK'.

    DATA:
      error_string    TYPE  string,
      error_long_text TYPE  string.


    "ls_ack_msg-correlationid = '307B2FD463E14B188E96BA7131B89AA0'.



    IF mes_ack_msg IS NOT INITIAL.
      .

      ls_return-number = '019'.
      "ls_return-message_v1 = CONV symsgv( lv_aufnr ).
      ls_return-message_v1 = CONV symsgv( lv_ack_key-lognumber ).
      ls_return-message_v2 = CONV symsgv( business_system ).

      APPEND ls_return TO lt_return.

      CALL FUNCTION '/AIF/CREATE_APPL_LOG'
        EXPORTING
          is_header_log = lv_header
          iv_ns         = p_ns
          iv_ifname     = p_ifname
          iv_ifversion  = p_ifver
        CHANGING
          ct_return     = lt_return.


      TRY.

          DATA(aif_explict) = 'X'.

          IF aif_explict EQ 'X'.


            DATA do_commit_at_aif TYPE  char01 VALUE space .


            CALL FUNCTION '/AIF/SEND_WITH_PROXY'
              EXPORTING
                ns                   = p_ns
                ifname               = p_ifname
                ifversion            = p_ifver
                appl_log_function    = 'AIF_SEND_WITH_PROXY'
                msgguid              = ximsgguid  "
                iv_persist_xml       = 'X'
                logical_port_name    = p_logical_port "'AIF_LOGICAL_PORT'
              IMPORTING
                ximsgguid            = ximsgguid
                ximsgguid_out        = ximsgguid_out
              TABLES
                add_return_tab       = lt_return
              CHANGING
                sap_struct           = mes_ack_msg
                error_string         = error_string
                error_long_text      = error_long_text
              EXCEPTIONS
                persistency_error    = 1
                status_update_failed = 2
                missing_keys         = 3
                interface_not_found  = 4
                transformation_error = 5
                general_error        = 6
                OTHERS               = 7.
            IF sy-subrc NE 0
            AND sy-subrc NE 1 . "PERSISTENCY_ERROR    "ToDo


            ELSE.



              CALL FUNCTION '/AIF/UTIL_ADD_MSG'
                EXPORTING
                  msgty              = 'I'
                  msgid              = 'ZP_DDE_YMES_ACK'
                  msgno              = '19'
                  "msgv1      = lv_msgv1
                TABLES
                  return_tab         = lt_return
                EXCEPTIONS
                  max_errors_reached = 1
                  OTHERS             = 2.
              DATA(rc_msg) = sy-subrc ##needed.


*              DATA(set_rel) = 'X'.





              IF do_commit_at_aif EQ space.
                COMMIT WORK AND WAIT.
              ENDIF.

            ENDIF.


            CALL METHOD ir_application_log->add_msg_xi
              EXPORTING
                "IV_XI_MSG_GUID         = XIMSGGUID " LV_GUID
                iv_xi_msg_guid         = ximsgguid_out "        = iv_object_count
                io_message_id_protocol = lo_wsprotocol_message_id
                iv_outb_impl           = mo_drf_ymes_ack_out->ms_runtime_parameter_ext-outb_impl
                ir_object              = lr_ack_key "lr_order
                is_message_out         = mes_ack_msg.
            IF sy-subrc <> 0 ##SUBRC_OK.
              ir_application_log->add_msg( iv_msgid = sy-msgid iv_msgno = sy-msgno iv_msgty = sy-msgty
              iv_msgv1 = sy-msgv1 iv_msgv2 = sy-msgv2 iv_msgv3 = sy-msgv3 iv_msgv4 = sy-msgv4 ).
            ENDIF.


            "MES integration via SOAP message
**
**            READ TABLE mt_caufv_bt WITH KEY aufnr = lv_aufnr INTO DATA(ls_caufvd).
**            IF sy-subrc EQ 0.
**              DATA(lv_objnr) = ls_caufvd-objnr ##NEEDED.
**            ENDIF.

          ELSE.
            "lr_proxy->mfgord_execute_req_out_v2( output = ls_ack_msg ).  "/aif/proxy_enabler_update bundled in proxy code -
            lr_proxy->rgs__p_dde_sap2mes_ack( input = mes_ack_msg ).


            CALL METHOD ir_application_log->add_msg_xi
              EXPORTING
                "IV_XI_MSG_GUID         = LV_GUID
                iv_object_count        = iv_object_count
                io_message_id_protocol = lo_wsprotocol_message_id
                iv_outb_impl           = mo_drf_ymes_ack_out->ms_runtime_parameter_ext-outb_impl
                ir_object              = lr_ack_key "lr_order
                is_message_out         = mes_ack_msg.
            IF sy-subrc <> 0 ##SUBRC_OK .
              ir_application_log->add_msg( iv_msgid = sy-msgid iv_msgno = sy-msgno iv_msgty = sy-msgty
              iv_msgv1 = sy-msgv1 iv_msgv2 = sy-msgv2 iv_msgv3 = sy-msgv3 iv_msgv4 = sy-msgv4 ).
            ENDIF.


          ENDIF.



          DATA(lv_xi_msg_guid) = lo_wsprotocol_message_id->get_message_id( ).


          lv_header-extnumber = lv_xi_msg_guid.


          ls_return-type = 'I'.
          ls_return-id = 'ZP_DDE_YMES_ACK'.
          ls_return-number = '020'.
          "ls_return-message_v1 = CONV symsgv( lv_aufnr ).
          ls_return-message_v1 = CONV symsgv( lv_ack_key-lognumber ).
          ls_return-message_v2 = CONV symsgv( business_system ).

          APPEND ls_return TO lt_return.

          CALL FUNCTION '/AIF/CREATE_APPL_LOG'
            EXPORTING
              is_header_log = lv_header
              iv_ns         = p_ns
              iv_ifname     = p_ifname
              iv_ifversion  = p_ifver
            CHANGING
              ct_return     = lt_return.


        CATCH cx_ai_system_fault INTO lo_exception .
          "       RETURN.
          CALL METHOD lo_exception->if_message~get_text RECEIVING result = ex_text.
          CALL METHOD lo_exception->if_message~get_longtext RECEIVING result = ex_text_long.

          CALL METHOD ir_application_log->add_msg_re
            EXPORTING
              iv_msgno             = '015'
              iv_msgid             = if_drf_const=>msg_id_common
              iv_msgv2             = ex_text
              iv_msgv3             = ex_text_long
              ix_exception_catched = lo_exception.
      ENDTRY.

      <ls_obj_rep_sta>-repstatus = 'SN'. "Message was sent
      "CLEAR  ms_ack_msg.








    ENDIF.


  ENDMETHOD.
ENDCLASS.