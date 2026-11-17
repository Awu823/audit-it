class ZCL_DRF_REF_PROCORD_OUT definition
  public
  final
  create public .

public section.

  interfaces IF_DRF_OUTBOUND .

  types:
    tt_key_table
                      TYPE SORTED TABLE OF comes_s_drf_prod_key " ZP_MCN_YP_MCN_FLT_LAEDA
                      WITH UNIQUE KEY aufnr .
  types:
    BEGIN OF ty_plant_range,
        sign   TYPE  sign,
        option TYPE  option,
        low    TYPE  werks_d,
        high   TYPE  werks_d,
      END OF ty_plant_range .
  types:
    tt_plant_range TYPE STANDARD TABLE OF ty_plant_range .
  types:
    BEGIN OF ty_matnr_range,
        sign   TYPE  sign,
        option TYPE  option,
        low    TYPE  matnr,
        high   TYPE  matnr,
      END OF ty_matnr_range .
  types:
    tt_matnr_range TYPE STANDARD TABLE OF ty_matnr_range .
  types:
    BEGIN OF ty_mfg_ord_acty_user_avfu,
        aufpl TYPE co_aufpl,
        aplzl TYPE co_aplzl.
        INCLUDE TYPE afvui.
    TYPES: END OF  ty_mfg_ord_acty_user_avfu .
  types:
    tt_mfg_ord_acty_user_avfu TYPE STANDARD TABLE OF ty_mfg_ord_acty_user_avfu .
  types:
    BEGIN OF ty_mfg_ord_acty_user_afvc,
        aufpl TYPE co_aufpl,
        aplzl TYPE co_aplzl.
        INCLUDE TYPE afvgi.
    TYPES: END OF  ty_mfg_ord_acty_user_afvc .
  types:
    tt_mfg_ord_acty_user_afvc TYPE STANDARD TABLE OF ty_mfg_ord_acty_user_afvc .
  types:
    BEGIN OF ty_mfg_ord_acty_user_afvv,
        aufpl TYPE co_aufpl,
        aplzl TYPE co_aplzl.
        INCLUDE TYPE afvvi.
    TYPES: END OF  ty_mfg_ord_acty_user_afvv .
  types:
    tt_mfg_ord_acty_user_afvv TYPE STANDARD TABLE OF ty_mfg_ord_acty_user_afvv .
  types:
    BEGIN OF ty_jstat_by_aufnr,
        aufnr TYPE aufnr,
        stat  TYPE j_status,
        txt04 TYPE j_txt04,
      END OF ty_jstat_by_aufnr .
  types:
    tt_jstat_by_aufnr TYPE STANDARD TABLE OF ty_jstat_by_aufnr .

  constants C_CP_TABKEY type CDTABKEY value 'KEY' ##NO_TEXT.
  constants C_CP_TABNAME_CLASSIFY type CDTABKEY value 'CLASSIFY' ##NO_TEXT.
  constants C_CP_TABNAME type CDTABKEY value 'AFVU' ##NO_TEXT.
  constants C_CP_TABNAME_CLASSIF type TABNAME value 'CLASSIF' ##NO_TEXT.
  constants C_CP_ALEMESSTYPE type EDI_MESTYP value 'P1T_MES_MFGORD_EXE_REQ_OUT' ##NO_TEXT.
  constants C_CP_OBJECTCLAS type CDOBJECTCL value 'ORDER' ##NO_TEXT.

  class-methods CLASS_CONSTRUCTOR .
  methods CONSTRUCTOR .
PRIVATE SECTION.

  TYPES:
*  types:
*    begin of TY_SEGMENT,
*      MATNR    type MATNR,
*      MCHA_TAB type ref to TT_MCHA,
*    end of TY_SEGMENT .
    BEGIN OF t_mdg_bus_sys_tech_logsys,
      business_system	TYPE mdg_business_system,
      bus_sys_id      TYPE mdg_business_system_id,
      logsys          TYPE logsys,
    END OF t_mdg_bus_sys_tech_logsys .
  TYPES:
    tt_mdg_bus_sys_tech TYPE SORTED TABLE OF t_mdg_bus_sys_tech_logsys WITH UNIQUE KEY business_system .

**types: ty_t_caufvdb TYPE STANDARD TABLE OF caufvdb .
**TYPES: ty_t_afpob TYPE STANDARD TABLE OF afpob .
**TYPES: ty_t_afflb TYPE STANDARD TABLE OF afflb .
**TYPES: ty_t_afvgb TYPE STANDARD TABLE OF afvgb .
**TYPES: ty_t_resbb TYPE STANDARD TABLE OF resbb .
**
**
**
**types:
**begin of t_PPINT_SOA_MFG_ORD,
**
**
**
**  CAUFV_BT   TYPE ty_t_caufvdb ,"TYPE STANDARD TABLE OF caufvdb,  "CL_PPINT_SOA_MFG_ORD_MAPPING=>TY_T_CAUFVDB,
**  AFPO_BT    TYPE CL_PPINT_SOA_MFG_ORD_MAPPING=>TY_T_AFPOB,
**  AFFL_BT    TYPE CL_PPINT_SOA_MFG_ORD_MAPPING=>TY_T_AFFLB,
**  AFVG_BT    TYPE CL_PPINT_SOA_MFG_ORD_MAPPING=>TY_T_AFVGB,
**  RESB_BT    TYPE CL_PPINT_SOA_MFG_ORD_MAPPING=>TY_T_RESBB,
**  RSEROB     TYPE CL_PPINT_SOA_MFG_ORD_MAPPING=>TY_T_RSEROB,
**  RSEROB_TMP TYPE CL_PPINT_SOA_MFG_ORD_MAPPING=>TY_T_RSEROB,
**  AFABB      TYPE CL_PPINT_SOA_MFG_ORD_MAPPING=>TY_T_AFABB,
**  AFABB_BT   TYPE CL_PPINT_SOA_MFG_ORD_MAPPING=>TY_T_AFABB,
**  AFFHD_BT   TYPE CL_PPINT_SOA_MFG_ORD_MAPPING=>TY_T_AFFHD,
**  AFFHD_TMP  TYPE CL_PPINT_SOA_MFG_ORD_MAPPING=>TY_T_AFFHD,
**
**end of t_PPINT_SOA_MFG_ORD.
  DATA mt_caufv_bt TYPE cl_ppint_soa_mfg_ord_mapping=>ty_t_caufvdb .
  DATA mt_afpo_bt TYPE cl_ppint_soa_mfg_ord_mapping=>ty_t_afpob .
  DATA mt_affl_bt TYPE cl_ppint_soa_mfg_ord_mapping=>ty_t_afflb .
  DATA mt_afvg_bt TYPE cl_ppint_soa_mfg_ord_mapping=>ty_t_afvgb .
  DATA mt_resb_bt TYPE cl_ppint_soa_mfg_ord_mapping=>ty_t_resbb .
  DATA mt_rserob TYPE cl_ppint_soa_mfg_ord_mapping=>ty_t_rserob .
  DATA mt_rserob_tmp TYPE cl_ppint_soa_mfg_ord_mapping=>ty_t_rserob  ##NEEDED.
  DATA mt_afabb TYPE cl_ppint_soa_mfg_ord_mapping=>ty_t_afabb .
  DATA mt_afabb_bt TYPE cl_ppint_soa_mfg_ord_mapping=>ty_t_afabb  ##NEEDED.
  DATA mt_affhd_bt TYPE cl_ppint_soa_mfg_ord_mapping=>ty_t_affhd  ##NEEDED.
  DATA mt_affhd_tmp TYPE cl_ppint_soa_mfg_ord_mapping=>ty_t_affhd  ##NEEDED.
  DATA ms_manufacturing_order_v2 TYPE ppint_manufacturing_order_v2 .
  DATA mt_mdg_bus_sys_tech_logsys TYPE tt_mdg_bus_sys_tech .
  DATA ms_runtime_parameter_ext TYPE drf_s_runtime_parameter_ext .
  DATA mo_procord_filter TYPE REF TO if_drf_filter .
  "data MT_CHARACTRERISTICS type TT_BAPI1003_CHARACT_R .
  CLASS-DATA mo_drf_mes_procord_out TYPE REF TO ZCL_DRF_REF_PROCORD_OUT .
  CLASS-DATA gc_mes_procord_key_structure TYPE string VALUE 'ZCL_DRF_REF_PROCORD_OUT=>tt_key_table' ##NO_TEXT.
  "data SENDING_CODE_VERSION type CHAR02 value '01' ##NO_TEXT.
  DATA ex_object_cx_root TYPE REF TO cx_root .
  DATA ex_text TYPE string .
  DATA ex_text_long TYPE string .
  DATA mt_jstat_by_aufnr TYPE tt_jstat_by_aufnr .
  DATA mt_mfg_ord_acty_user_afvu TYPE tt_mfg_ord_acty_user_avfu .
  DATA mt_mfg_ord_acty_user_afvv TYPE tt_mfg_ord_acty_user_afvv .
  DATA mt_mfg_ord_acty_user_afvc TYPE tt_mfg_ord_acty_user_afvc .
  DATA:
    mt_p_po_rt     TYPE TABLE OF Zp_po_rt .
  DATA:
    mt_p_po_rt_no_send TYPE TABLE OF Zp_po_rt .
  DATA:
    mt_lt_aif_log TYPE TABLE OF  Zp_dcb_aif_1  ##NEEDED.
  DATA mt_aufnr_sent_ok TYPE ty_t_p_aufnr .

  METHODS get_plant_timezone
    IMPORTING
      VALUE(i_business_system) TYPE Zp_mia_matmas_bussys
    EXPORTING
      VALUE(e_planttimezone)   TYPE tznzone .
  CLASS-METHODS tims_not_initial
    CHANGING
      !t TYPE ppint_time .
  METHODS change_is_valid_for_drf
    IMPORTING
      VALUE(i_aufnr)         TYPE aufnr
    RETURNING
      VALUE(change_is_valid) TYPE string .
  METHODS order_status_is_valid_for_drf
    IMPORTING
      VALUE(i_obj_key)             TYPE comes_s_drf_prod_key
    RETURNING
      VALUE(order_status_is_valid) TYPE string .
  CLASS-METHODS set_distribution_status
    IMPORTING
      !iv_aufnr TYPE aufnr   ##NEEDED
      !iv_objnr TYPE j_objnr .
  METHODS get_procord_filter
    RETURNING
      VALUE(ro_procord_filter) TYPE REF TO if_drf_filter .
  METHODS get_exqty_orderltext
    IMPORTING
      !i_aufnr                TYPE aufnr
    RETURNING
      VALUE(r_exqty_ordltext) TYPE string .
  METHODS convert_timestamp
    IMPORTING
      VALUE(c_skip)          TYPE boolean OPTIONAL
      VALUE(i_planttimezone) TYPE tznzone OPTIONAL
    CHANGING
      !c_time                TYPE uzeit
      !c_date                TYPE datum .
ENDCLASS.



CLASS ZCL_DRF_REF_PROCORD_OUT IMPLEMENTATION.


METHOD change_is_valid_for_drf.

*-----------------------------------------------------------------------------------------------------*
* Functional Spec: Process order MES interface
* Technical Spec: Process order MES interface
* Process: Manage and Release Orders
* History --------------------------------------------------------------------------------------------*
* Date       | Change           | Contributor               | Description
*-----------------------------------------------------------------------------------------------------*
*-----------------------------------------------------------------------------------------------------*


  DATA: lv_order TYPE comes_s_drf_prod_key.
  DATA: lr_order TYPE REF TO comes_s_drf_prod_key.

  DATA lv_status_tag TYPE char4.


  DATA(business_system)  =  mo_drf_mes_procord_out->ms_runtime_parameter_ext-business_system.
  DATA(ir_application_log) = mo_drf_mes_procord_out->ms_runtime_parameter_ext-bal.


  DATA: order_objects	TYPE bapi_pi_order_objects,
        lt_phase      TYPE  TABLE OF bapi_order_phase,
        lt_component  TYPE TABLE OF bapi_order_component,
        lt_header     TYPE TABLE OF bapi_order_header1,
        ls_return     TYPE  bapiret2 ##NEEDED.

  DATA gasmg TYPE gasmg.

  lv_order-aufnr = i_aufnr.
  GET REFERENCE OF lv_order INTO lr_order .


  order_objects-HEADER = 'X'.
  order_objects-phases = 'X'.
  order_objects-components = 'X'.


  CALL FUNCTION 'BAPI_PROCORD_GET_DETAIL'
  EXPORTING
    NUMBER        = i_aufnr
    order_objects = order_objects
  IMPORTING
    RETURN        = ls_return
  TABLES
    HEADER        = lt_header
    phase         = lt_phase
    COMPONENT     = lt_component.
  DATA(rc) = sy-subrc.

  READ TABLE lt_header INTO DATA(HEADER) INDEX 1.
  rc = sy-subrc.

  IF rc NE 0.
    ir_application_log->add_msg( iv_msgty = if_drf_const=>msg_type_error iv_msgid = 'ZP_DCB_PROCORD'
    iv_msgno = '007' "bapi error
    iv_msgv1 = i_aufnr
    ir_object =  lr_order ).
    change_is_valid = ' BAPI error - replication forced '.

    RETURN.
  ENDIF.

  lv_status_tag = 'GLOCK' .
  IF  HEADER-system_status CS  lv_status_tag .
    ir_application_log->add_msg( iv_msgid = 'ZP_DCB_PROCORD'  iv_msgty = if_drf_const=>msg_type_warning  ir_object =  lr_order
    iv_msgno = '023'  "bad status for replication
    iv_msgv1 = i_aufnr
    iv_msgv2 = lv_status_tag ).
    CLEAR change_is_valid.
    RETURN.
  ENDIF.




  lv_status_tag = 'TECO' .
  IF  HEADER-system_status CS  lv_status_tag .
    ir_application_log->add_msg( iv_msgid = 'ZP_DCB_PROCORD'  iv_msgty = if_drf_const=>msg_type_warning  ir_object =  lr_order
    iv_msgno = '023'  "bad status for replication
    iv_msgv1 = i_aufnr
    iv_msgv2 = lv_status_tag ).
    CLEAR change_is_valid.
    RETURN.
  ENDIF.

  lv_status_tag = 'CUST_LOCK' .
  IF  HEADER-system_status CS  lv_status_tag .
    ir_application_log->add_msg( iv_msgid = 'ZP_DCB_PROCORD'  iv_msgty = if_drf_const=>msg_type_warning  ir_object =  lr_order
    iv_msgno = '023'  "bad status for replication
    iv_msgv1 = i_aufnr
    iv_msgv2 = lv_status_tag ).
    CLEAR change_is_valid.
    RETURN.
  ENDIF.

  "{
  DATA l_txt04   TYPE j_txt04.
  TRY.
    l_txt04 = 'CUST_LOCK'.
    DATA lv_objnr             TYPE jest-objnr.
    DATA user_line         TYPE bsvx-sttxt.
    CONCATENATE 'OR' i_aufnr  INTO lv_objnr.
    CALL FUNCTION 'STATUS_TEXT_EDIT'
    EXPORTING
      objnr            = lv_objnr
      only_active      = 'X'
      spras            = 'E'
    IMPORTING
      user_line        = user_line
    EXCEPTIONS
      object_not_found = 1
      OTHERS           = 2.
    IF sy-subrc EQ 0.
      IF user_line CS l_txt04.
        ir_application_log->add_msg( iv_msgid = 'ZP_DCB_PROCORD'  iv_msgty = if_drf_const=>msg_type_warning  ir_object =  lr_order
        iv_msgno = '023'  "bad status for replication
        iv_msgv1 = i_aufnr
        iv_msgv2 = l_txt04 ).
        CLEAR change_is_valid.
        RETURN.
      ENDIF.
    ENDIF.

  CATCH cx_root INTO DATA(ex_object_cx_root_02).
    DATA(ex_text_02) = ex_object_cx_root_02->get_text( ) ##needed.

  ENDTRY.

  "} NOT ( HEADER-system_status CS 'REL' OR HEADER-system_status CS 'PREL' ).
    ir_application_log->add_msg( iv_msgid = 'ZP_DCB_PROCORD'  iv_msgty = if_drf_const=>msg_type_warning
    iv_msgno = '022'  "Status for header &1 is not in REL/PREL - skipped
    iv_msgv1 = i_aufnr
    ir_object      =  lr_order ).
    CLEAR change_is_valid.
    RETURN.
  ENDIF.


  SELECT create_date ,create_time, msgguid  INTO TABLE @DATA(lt_aif_log) FROM Zp_dcb_aif_1
        WHERE aufnr = @i_aufnr  AND business_system = @business_system.
  IF sy-subrc NE 0.  "never sent before
    ir_application_log->add_msg( iv_msgid = 'ZP_DCB_PROCORD'  iv_msgty = if_drf_const=>msg_type_success
    iv_msgno = '032'  "New REL/PREL Order - never before sentd
    iv_msgv1 = i_aufnr
    ir_object      =  lr_order ).
    change_is_valid  = 'New Order - never before sent'(020).
    RETURN.
  ENDIF.


  SORT lt_aif_log DESCENDING BY create_date create_time.
  DATA(lv_msgguid) = lt_aif_log[ 1 ]-msgguid.

  SELECT mfg_order_planne , mfg_order_plan_2 , mfg_order_plan_3, mfg_order_plan_4 ,  mfg_order_schedu ,  mfg_order_sche_2, mfg_order_sche_3 ,  mfg_order_sche_4,
  content_7 ,  unit_code_2  ,   sapunit_code_2 ,  content_8 ,  unit_code_3 ,  sapunit_code_3 ,  content_9 ,  unit_code_4 ,  sapunit_code_4 ,  content_10
  INTO TABLE @DATA(lt_header_aif_po_s)
        FROM Zp_dcb_po_s WHERE msgguid EQ @lv_msgguid.

  IF sy-subrc EQ 0.
    READ TABLE lt_header_aif_po_s INTO DATA(aif_header) INDEX 1.
    rc = sy-subrc.
    ir_application_log->add_msg( iv_msgid = 'ZP_DCB_PROCORD'  iv_msgty = if_drf_const=>msg_type_info
    iv_msgno = '009'  "info - previous send
    iv_msgv1 = i_aufnr
    iv_msgv2 = lt_aif_log[ 1 ]-create_date
    iv_msgv3 = lt_aif_log[ 1 ]-create_time
    iv_msgv4 = lt_aif_log[ 1 ]-msgguid
    ir_object      =  lr_order  ).
  ELSE.
    DATA(err_po_s) = 'ZP_DCB_PO_S - header persistence'.
    ir_application_log->add_msg( iv_msgty = if_drf_const=>msg_type_warning iv_msgid = 'ZP_DCB_PROCORD'
    iv_msgno = '008' "AIF perstance  error
    iv_msgv1 = i_aufnr
    iv_msgv2 = err_po_s
    ir_object      =  lr_order ).
    change_is_valid = err_po_s.

    RETURN.
  ENDIF.



  "header quantities MfgOrderPlannedTotalQty
  " CONTENT_7 ,  UNIT_CODE_2  ,   SAPUNIT_CODE_2 ,  CONTENT_8 ,  UNIT_CODE_3 ,  SAPUNIT_CODE_3 ,  CONTENT_9 ,  UNIT_CODE_4 ,  SAPUNIT_CODE_4 ,  CONTENT_10 ,

  gasmg =  aif_header-content_7.
  IF aif_header-content_7 EQ HEADER-target_quantity.
    ir_application_log->add_msg( iv_msgid = 'ZP_DCB_PROCORD' iv_msgty = if_drf_const=>msg_type_warning
    iv_msgno = '043'  "  total quantity
    iv_msgv1 = i_aufnr
    iv_msgv2 = HEADER-target_quantity
    iv_msgv3 =   gasmg

    ir_object      =  lr_order ).
  ELSE..
    "CHANGE_IS_VALID = ' total quantity changed'.
    ir_application_log->add_msg( iv_msgid = 'ZP_DCB_PROCORD' iv_msgty = if_drf_const=>msg_type_success
    iv_msgno = '033'  " total quantity changed
    iv_msgv1 = i_aufnr
    iv_msgv2 = HEADER-target_quantity
    iv_msgv3 =   gasmg
    ir_object      =  lr_order ).
  ENDIF.

  "dates ?
  "  MFG_ORDER_PLANNE , MFG_ORDER_PLAN_2 , MFG_ORDER_PLAN_3, MFG_ORDER_PLAN_4 ,  MFG_ORDER_SCHEDU ,  MFG_ORDER_SCHE_2, MFG_ORDER_SCHE_3 ,  MFG_ORDER_SCHE_4,
  "

  "planded date time

  " {

  IF
  ( aif_header-mfg_order_planne EQ  HEADER-start_date )
  AND ( aif_header-mfg_order_plan_2 EQ  HEADER-start_time )
  AND ( aif_header-mfg_order_plan_3 EQ  HEADER-finish_date )
  AND ( aif_header-mfg_order_plan_4 EQ  HEADER-finish_time ).

    ir_application_log->add_msg( iv_msgid = 'ZP_DCB_PROCORD' iv_msgty = if_drf_const=>msg_type_warning
    iv_msgno = '038'  "   ' Date/Time details NOT changed'.
    iv_msgv1 = i_aufnr
    "IV_MSGV2 = HEADER-TARGET_QUANTITY
    "IV_MSGV3 =   GASMG

    ir_object      =  lr_order ).
  ELSE..
    "Disabled  CHANGE_IS_VALID = ' Date/Time details changed'.
    ir_application_log->add_msg( iv_msgid = 'ZP_DCB_PROCORD' iv_msgty = if_drf_const=>msg_type_success
    iv_msgno = '037'  " ' Date/Time details changed'.
    iv_msgv1 = i_aufnr
    "IV_MSGV2 = ' Date/Time ' "HEADER-TARGET_QUANTITY
    "IV_MSGV3 =   GASMG
    ir_object      =  lr_order ).
  ENDIF.


  "scheduled date/time

  IF
  ( aif_header-mfg_order_schedu EQ  HEADER-production_start_date )
  AND ( aif_header-mfg_order_sche_2 EQ  HEADER-sched_start_time )
  AND ( aif_header-mfg_order_sche_3 EQ  HEADER-production_finish_date )
  AND ( aif_header-mfg_order_sche_4 EQ  HEADER-sched_fin_time ).

    ir_application_log->add_msg( iv_msgid = 'ZP_DCB_PROCORD' iv_msgty = if_drf_const=>msg_type_warning
    iv_msgno = '041'  "   ' scheduled Date/Time details NOT changed'.
    iv_msgv1 = i_aufnr
    "IV_MSGV2 = HEADER-TARGET_QUANTITY
    "IV_MSGV3 =   GASMG

    ir_object      =  lr_order ).
  ELSE..
    "Disabled  CHANGE_IS_VALID = ' Date/Time details changed'.
    ir_application_log->add_msg( iv_msgid = 'ZP_DCB_PROCORD' iv_msgty = if_drf_const=>msg_type_success
    iv_msgno = '040'  " ' Date/Time details changed'.
    iv_msgv1 = i_aufnr
    "IV_MSGV2 = ' Date/Time ' "HEADER-TARGET_QUANTITY
    "IV_MSGV3 =   GASMG
    ir_object      =  lr_order ).
  ENDIF.



  " }


  "ZP_DCB_PO_58  operations = network activity

  SELECT parent_id ,order_internal_b , work_center , work_center_inte ,  mfg_order_operat , manufacturing_or
  INTO TABLE @DATA(lt_operations_aif_po_55)
        FROM Zp_dcb_po_58 " UpgradeIssue  Zp_dcb_po_55 renamed to Zp_dcb_po_56

        WHERE msgguid EQ @lv_msgguid.
  IF sy-subrc NE 0.
    DATA(err_55) = 'ZP_DCB_PO_55 - operations persistence'.
    ir_application_log->add_msg( iv_msgty = if_drf_const=>msg_type_warning iv_msgid = 'ZP_DCB_PROCORD' "MSG_TYPE_ERROR
    iv_msgno = '008' "AIF perstance  error
    iv_msgv1 = i_aufnr
    iv_msgv2 = err_55
    ir_object      =  lr_order ).
    change_is_valid = err_55.
    RETURN.
  ENDIF.


  "ZP_DCB_PO_60 Components

  SELECT parent_id , reservation_item , boml_item_number ,  reservation , batch , content , sapunit_code , material
  INTO TABLE @DATA(lt_operations_aif_po_57)

        FROM ZP_DCB_PO_60  " Upgrade Issue  Zp_dcb_po_57 renamed to ZP_DCB_PO_58
        WHERE msgguid EQ @lv_msgguid.
  IF sy-subrc NE 0.
    DATA(err_57) = 'ZP_DCB_PO_57 - components persistence'.
    ir_application_log->add_msg( iv_msgty = if_drf_const=>msg_type_warning iv_msgid = 'ZP_DCB_PROCORD' "MSG_TYPE_ERROR
    iv_msgno = '008' "AIF perstance  error
    iv_msgv1 = i_aufnr
    iv_msgv2 = err_57
    ir_object      =  lr_order ).
    change_is_valid = err_57.
    RETURN.
  ENDIF.





  SELECT aufnr ,orderoperation INTO TABLE @DATA(lt_operations) FROM ZP_S_PROCORD_FLT1" ZP_S_FL1
        WHERE aufnr EQ @i_aufnr
        AND mes EQ @business_system.
  DATA(rc_s) = sy-subrc ##needed.


  CALL METHOD ir_application_log->increase_msg_level
  EXPORTING
    iv_description = 'Operations changes check'.




  LOOP AT lt_operations ASSIGNING FIELD-SYMBOL(<operations>).




    READ TABLE lt_operations_aif_po_55 ASSIGNING FIELD-SYMBOL(<aif_operations>) WITH KEY manufacturing_or = <operations>-orderoperation.
    IF sy-subrc EQ 0.
      DATA(aif_operation_resource) = <aif_operations>-work_center.
    ELSE.
      aif_operation_resource = 'N/A'.
      "new operation.  = 'New operation'.
      ir_application_log->add_msg( iv_msgid = 'ZP_DCB_PROCORD' iv_msgty = if_drf_const=>msg_type_success
      iv_msgno = '030' "'New operation v2'.
      iv_msgv1 = i_aufnr
      iv_msgv2 = <operations>-orderoperation
      "IV_MSGV3 = PHASE_RESOURCE
      "IV_MSGV4 = AIF_OPERATION_RESOURCE
      ir_object      =  lr_order ).

    ENDIF.


    READ TABLE lt_phase ASSIGNING FIELD-SYMBOL(<phase>) WITH KEY operation_number = <operations>-orderoperation.


    IF sy-subrc EQ 0.
      DATA(phase_resource) = <phase>-resource.
      DATA(phase_status)  = <phase>-system_status.

    ELSE.
      phase_resource = 'N/A'.
      phase_status = 'N/A'.

      change_is_valid = 'New operation v2'.
      ir_application_log->add_msg( iv_msgid = 'ZP_DCB_PROCORD' iv_msgty = if_drf_const=>msg_type_success
      iv_msgno = '029' "'New operation v2'.
      iv_msgv1 = i_aufnr
      iv_msgv2 = <operations>-orderoperation
      "IV_MSGV3 = PHASE_RESOURCE
      "IV_MSGV4 = AIF_OPERATION_RESOURCE
      ir_object      =  lr_order ).

    ENDIF.

    IF phase_status CS 'REL'.

      IF aif_operation_resource EQ phase_resource.
        ir_application_log->add_msg( iv_msgid = 'ZP_DCB_PROCORD'  iv_msgty = if_drf_const=>msg_type_warning
        iv_msgno = '021'   "Resource for &1 &2 is  &3 recently sent &4  - skiped
        iv_msgv1 = i_aufnr
        iv_msgv2 = <operations>-orderoperation
        iv_msgv3 = phase_resource
        iv_msgv4 = aif_operation_resource
        ).
      ELSE.
        "CHANGE_IS_VALID = 'Resource changed '.
        ir_application_log->add_msg( iv_msgid = 'ZP_DCB_PROCORD' iv_msgty = if_drf_const=>msg_type_success
        iv_msgno = '031' "Resource for &1 &2 is  &3 recently sent &4  - marked for replication
        iv_msgv1 = i_aufnr
        iv_msgv2 = <operations>-orderoperation
        iv_msgv3 = phase_resource
        iv_msgv4 = aif_operation_resource
        ir_object      =  lr_order ).
      ENDIF.
    ELSE. "
      "operation unreleased - do not trigger
      CLEAR    change_is_valid.
      ir_application_log->add_msg( iv_msgid = 'ZP_DCB_PROCORD'  iv_msgty = if_drf_const=>msg_type_warning
      iv_msgno = '034'   "Operation &1 in status &2  NOT marked for sending
      iv_msgv1 = i_aufnr
      iv_msgv2 = <operations>-orderoperation
      iv_msgv3 = phase_status
      "IV_MSGV4 = AIF_OPERATION_RESOURCE
      ).


    ENDIF. "PHASE_STATUS cs 'REL'.
    "call method IR_APPLICATION_LOG->DECREASE_MSG_LEVEL( ).

  ENDLOOP.

  CALL METHOD ir_application_log->decrease_msg_level( ).


************************


  CALL METHOD ir_application_log->increase_msg_level
  EXPORTING
    iv_description = 'Material changes check'.


  LOOP AT lt_component ASSIGNING FIELD-SYMBOL(<component>).
    "BATCH
    "MATERIAL
    "RESERVATION



    READ TABLE lt_operations_aif_po_57 INTO DATA(aif_component) WITH KEY boml_item_number = <component>-item_number.
    IF sy-subrc NE 0. " new component
      "CHANGE_IS_VALID = 'New component '.
      ir_application_log->add_msg( iv_msgid = 'ZP_DCB_PROCORD' iv_msgty = if_drf_const=>msg_type_success
      iv_msgno = '024'  " new component
      iv_msgv1 = <component>-item_number
      iv_msgv2 = <component>-material
      "IV_MSGV3 =
      ir_object      =  lr_order ).
      CONTINUE.
    ENDIF.

    "Material

    IF <component>-material IS INITIAL
    AND aif_component-material IS INITIAL.
      CONTINUE.
    ENDIF.


*      call method IR_APPLICATION_LOG->INCREASE_MSG_LEVEL
*        exporting
*          IV_DESCRIPTION = `Components changes check for ` && <COMPONENT>-ITEM_NUMBER.


    DATA lv_aif_component_material_raw TYPE matnr18.

    CALL FUNCTION 'CONVERSION_EXIT_MATN1_INPUT'  "cause AIF index
    EXPORTING
      INPUT        = aif_component-material
    IMPORTING
      OUTPUT       = lv_aif_component_material_raw
    EXCEPTIONS
      length_error = 1
      OTHERS       = 2.
    DATA(rc_i0002) = sy-subrc ##needed.


    IF <component>-material EQ lv_aif_component_material_raw.
      ir_application_log->add_msg( iv_msgid = 'ZP_DCB_PROCORD' iv_msgty = if_drf_const=>msg_type_warning
      iv_msgno = '015'  "  material changed
      iv_msgv1 = <component>-item_number
      iv_msgv2 = <component>-material
      iv_msgv3 = aif_component-material
      ir_object      =  lr_order ).
    ELSE..
      "Disabled  CHANGE_IS_VALID = ' material changed'.
      ir_application_log->add_msg( iv_msgid = 'ZP_DCB_PROCORD' iv_msgty = if_drf_const=>msg_type_success
      iv_msgno = '025'  "  material changed
      iv_msgv1 = <component>-item_number
      iv_msgv2 = <component>-material
      iv_msgv3 = aif_component-material
      ir_object      =  lr_order ).
      CONTINUE.
    ENDIF.

    "batch
    IF <component>-batch EQ aif_component-batch.
      ir_application_log->add_msg( iv_msgid = 'ZP_DCB_PROCORD' iv_msgty = if_drf_const=>msg_type_warning
      iv_msgno = '016'  "  batch not changed
      iv_msgv1 = <component>-item_number
      iv_msgv2 = <component>-material
      iv_msgv3 = <component>-batch
      iv_msgv4 = aif_component-batch
      ir_object      =  lr_order ).
    ELSE..
      "Disabled  CHANGE_IS_VALID = ' material changed'.
      ir_application_log->add_msg( iv_msgid = 'ZP_DCB_PROCORD' iv_msgty = if_drf_const=>msg_type_success
      iv_msgno = '026'  "  batch changed
      iv_msgv1 = <component>-item_number
      iv_msgv2 = <component>-material
      iv_msgv3 = <component>-batch
      iv_msgv4 = aif_component-batch
      ir_object      =  lr_order ).
      CONTINUE.
    ENDIF.

    "quantity


    gasmg = aif_component-content..
    IF <component>-entry_quantity EQ aif_component-content.
      ir_application_log->add_msg( iv_msgid = 'ZP_DCB_PROCORD' iv_msgty = if_drf_const=>msg_type_warning
      iv_msgno = '017'  "  quantity
      iv_msgv1 = <component>-item_number
      iv_msgv2 = <component>-material
      iv_msgv3 = <component>-entry_quantity
      iv_msgv4 = gasmg
      ir_object      =  lr_order ).
    ELSE..
      "Disabled  CHANGE_IS_VALID = ' quantity changed'.
      ir_application_log->add_msg( iv_msgid = 'ZP_DCB_PROCORD' iv_msgty = if_drf_const=>msg_type_success
      iv_msgno = '027'  "  quantity changed
      iv_msgv1 = <component>-item_number
      iv_msgv2 = <component>-material
      iv_msgv3 = <component>-entry_quantity
      iv_msgv4 = gasmg
      ir_object      =  lr_order ).
      CONTINUE.
    ENDIF.

    "UoM
    IF <component>-entry_uom EQ aif_component-sapunit_code.
      ir_application_log->add_msg( iv_msgid = 'ZP_DCB_PROCORD' iv_msgty = if_drf_const=>msg_type_warning
      iv_msgno = '018'  "  UOM
      iv_msgv1 = <component>-item_number
      iv_msgv2 = <component>-material
      iv_msgv3 = <component>-entry_uom
      iv_msgv4 = aif_component-sapunit_code
      ir_object      =  lr_order ).
    ELSE..
      "Disabled  CHANGE_IS_VALID = ' UoM changed'.
      ir_application_log->add_msg( iv_msgid = 'ZP_DCB_PROCORD' iv_msgty = if_drf_const=>msg_type_success
      iv_msgno = '028'  "  quantity changed
      iv_msgv1 = <component>-item_number
      iv_msgv2 = <component>-material
      iv_msgv3 = <component>-entry_uom
      iv_msgv4 = aif_component-sapunit_code
      ir_object      =  lr_order ).
      CONTINUE.
    ENDIF.







  ENDLOOP.

  CALL METHOD ir_application_log->decrease_msg_level( ).

  .



ENDMETHOD.


  METHOD class_constructor.
  ENDMETHOD.


  METHOD constructor.


  ENDMETHOD.


  METHOD convert_timestamp.
************************************************************************
* Functional Spec: Process Order MES interface                *
* Design Spec    : Process Order MES interface                *
* Process        : Process Order MES interface                         *
* History -------------------------------------------------------------*
* Date       | Change      | Contributor | Description                 *
*----------------------------------------------------------------------*
*----------------------------------------------------------------------*

    DATA: time_stamp_utc TYPE timestamp.
    DATA: date1 TYPE sydats.
    DATA: time1 TYPE syst_uzeit.
    DATA: timezone TYPE tznzone.
    DATA(rc) = sy-subrc.

    IF c_time = '240000'.
      CLEAR c_time.
      IF NOT c_date IS INITIAL.
        c_date = c_date + 1.
      ENDIF.
    ENDIF.

    IF c_skip IS INITIAL.
      IF i_planttimezone IS NOT INITIAL.
        timezone = i_planttimezone.
        CALL FUNCTION 'IB_CONVERT_INTO_TIMESTAMP'
          EXPORTING
            i_datlo     = c_date
            i_timlo     = c_time
            i_tzone     = timezone
          IMPORTING
            e_timestamp = time_stamp_utc.
        IF sy-subrc EQ 0 AND time_stamp_utc IS NOT INITIAL.
          CALL FUNCTION 'IB_CONVERT_FROM_TIMESTAMP'
            EXPORTING
              i_timestamp = time_stamp_utc
              i_tzone     = 'UTC'
            IMPORTING
              e_datlo     = date1
              e_timlo     = time1.
          rc = sy-subrc.
        ENDIF.
      ENDIF.
    ELSE.
      CONVERT DATE c_date TIME c_time INTO TIME STAMP time_stamp_utc TIME ZONE 'CET'.
      rc = sy-subrc.
      CONVERT TIME STAMP time_stamp_utc TIME ZONE 'UTC' INTO DATE date1 TIME time1.
    ENDIF.

    IF rc EQ 0 AND sy-subrc EQ 0.
      c_date = date1.
      c_time = time1.
    ENDIF.

  ENDMETHOD.


  METHOD get_exqty_orderltext.
************************************************************************
* Functional Spec: Process Order MES interface                *
* Design Spec    : Process Order MES interface                *
* Process        : Process Order MES interface                         *
* History -------------------------------------------------------------*
* Date       | Change      | Contributor | Description                 *
*----------------------------------------------------------------------*
*----------------------------------------------------------------------*

    " 
    " commented to move the full class to the transport

    DATA: name    TYPE tdobname,
          text498 TYPE pin_cf_text500,
          string  TYPE string,
          lines   TYPE tline_t.

*    SELECT SINGLE werks
*      FROM aufk
*      INTO @DATA(plant)
*      WHERE aufnr = @i_aufnr.

    SELECT plant AS werks,
           timestamp,
           processorder AS aufnr,
           exactquantitycheck
      INTO TABLE @DATA(loghd)
      FROM Zp_b_dcb_log_hd
      WHERE plant = @ms_manufacturing_order_v2-production_plant"plant
      AND processorder = @i_aufnr.
    IF sy-subrc = 0.
      SORT loghd BY werks timestamp DESCENDING.

      DATA(exqty) = loghd[ 1 ]-exactquantitycheck.

    ENDIF.

    name = |010| &  |{ i_aufnr }|.

    CALL FUNCTION 'READ_TEXT'
      EXPORTING
        id                      = 'KOPF'
        language                = 'E'
        name                    = name
        object                  = 'AUFK'
      TABLES
        lines                   = lines
      EXCEPTIONS
        id                      = 1
        language                = 2
        name                    = 3
        not_found               = 4
        object                  = 5
        reference_check         = 6
        wrong_access_to_archive = 7
        OTHERS                  = 8.
    IF sy-subrc <> 0.

*      SELECT SINGLE description AS ktext
*        INTO @DATA(ktext)
*        FROM  Zs_b_aufk"aufk
*        WHERE ordernumber = @i_aufnr.
*      IF sy-subrc = 0.
*        r_exqty_ordltext = |{ exqty }| & |-| &  |{ ktext }|.
*      ENDIF.

      r_exqty_ordltext = |{ exqty }|.


    ELSE.

      LOOP AT lines ASSIGNING FIELD-SYMBOL(<lines>).
        string = | { string } | & | { <lines>-tdline } |.
      ENDLOOP.

      text498 = string.
      SHIFT text498 RIGHT.
      SHIFT text498 RIGHT.

      r_exqty_ordltext = |{ exqty }| & |-| &  |{ text498 }|.

    ENDIF.


  ENDMETHOD.


  METHOD get_plant_timezone.
    SELECT SINGLE werks
        INTO @DATA(plant)
        FROM Zp_s_mia_matmas_plant_mes"Zp_mia_mes_m
        WHERE business_system = @i_business_system.
    IF sy-subrc = 0.
      SELECT SINGLE address
        FROM Zs_b_t001w
        INTO @DATA(adrnr)
        WHERE plant = @plant.
    ENDIF.
    IF sy-subrc EQ 0.
      SELECT SINGLE timezone2
      FROM Zs_b_adrc "adrc
      INTO @DATA(planttimezone)
      WHERE addrnumber = @adrnr.
    ENDIF.
    IF sy-subrc EQ 0 AND planttimezone IS NOT INITIAL.
      e_planttimezone = planttimezone.
    ENDIF.
  ENDMETHOD.


  METHOD get_procord_filter.
    IF mo_procord_filter IS NOT BOUND.
      mo_procord_filter = NEW ZCL_DRF_REF_PROCORD_FLTR( ).
    ENDIF.

    ro_procord_filter = mo_procord_filter.
  ENDMETHOD.


  METHOD if_drf_outbound~analyze_changes_by_chg_pointer.
*--------------------------------------------------------------------------------------------------*
* Functional Spec: Process order MES interface
* Technical Spec: Process order MES interface
* Process: Manage and Release Orders
* History -------------------------------------------------------------------------------------------------------------*
* Date       | Change           | Contributor               | Description
*----------------------------------------------------------------------------------------------------------------------*
*----------------------------------------------------------------------------------------------------------------------*



    DATA: lt_change_pointer TYPE drf_t_bdcp,
          lr_change_pointer TYPE REF TO drf_s_bdcp,
          ls_obj_key        TYPE comes_s_drf_prod_key,
          lt_obj_key        TYPE comes_t_drf_prod_key.

    lt_change_pointer = it_change_pointer.

    DATA(business_system)  =  mo_drf_mes_procord_out->ms_runtime_parameter_ext-business_system.

**Delete duplicate records from the cahnge pointer table
    SORT lt_change_pointer BY cdobjcl cdobjid.
    DELETE ADJACENT DUPLICATES FROM lt_change_pointer COMPARING cdobjcl cdobjid.

** Object keys are fetched from the change pointer
    LOOP AT lt_change_pointer REFERENCE INTO lr_change_pointer.
      CLEAR ls_obj_key. "

      IF lr_change_pointer->tabname = ZCL_DRF_REF_PROCORD_OUT=>c_cp_tabname.
        ls_obj_key-aufnr = lr_change_pointer->cdobjid(12).
        IF ls_obj_key IS NOT INITIAL.
          INSERT ls_obj_key INTO TABLE lt_obj_key.
        ENDIF.
      ENDIF.
    ENDLOOP.

    " 
    TRY.
        LOOP AT lt_change_pointer REFERENCE INTO lr_change_pointer.
          CLEAR ls_obj_key. "
          IF lr_change_pointer->tabname = ZCL_DRF_REF_PROCORD_OUT=>c_cp_tabname_classif.
            ls_obj_key-aufnr = lr_change_pointer->cdobjid(12).
            IF ls_obj_key IS NOT INITIAL.
              INSERT ls_obj_key INTO TABLE lt_obj_key.
            ENDIF.
          ENDIF.
        ENDLOOP.

        LOOP AT lt_change_pointer REFERENCE INTO lr_change_pointer.
          CLEAR ls_obj_key. "
          IF lr_change_pointer->tabname = ZCL_DRF_REF_PROCORD_OUT=>c_cp_tabname_classify.
            ls_obj_key-aufnr = lr_change_pointer->cdobjid(12).
            IF ls_obj_key IS NOT INITIAL.
              INSERT ls_obj_key INTO TABLE lt_obj_key.
            ENDIF.
          ENDIF.
        ENDLOOP.
      CATCH cx_root INTO DATA(ex_object_cx_root).
        DATA(ex_text) = ex_object_cx_root->get_text( ) ##needed.
        DATA(ex_text_long) = ex_object_cx_root->get_longtext( ) ##needed.
    ENDTRY.

    " 


    IF lt_obj_key[] IS NOT INITIAL.
      SELECT DISTINCT aufnr INTO TABLE @DATA(lt_aufnr_filtered) FROM ZP_S_PROCORD_FLT1"ZP_S_FL1
          FOR ALL ENTRIES IN @lt_obj_key WHERE aufnr EQ @lt_obj_key-aufnr
         AND mes EQ @business_system.
      DATA(rc3) = sy-subrc ##needed.
    ENDIF.

    .
    "ZP_DCB_PO_55

*      call method IR_APPLICATION_LOG->INCREASE_MSG_LEVEL
*        exporting
*          IV_DESCRIPTION = `Operations changes check for ` && <OPERATIONS>-ORDEROPERATION.
*
*    select AUFNR, BUSINESS_SYSTEM , CREATE_DATE ,CREATE_TIME, MSGGUID  into corresponding fields of table @MT_LT_AIF_LOG from ZP_DCB_AIF_1
*      for all entries in  @LT_AUFNR_FILTERED
*  where AUFNR = @LT_AUFNR_FILTERED-AUFNR and BUSINESS_SYSTEM = @BUSINESS_SYSTEM.



    LOOP AT lt_aufnr_filtered ASSIGNING FIELD-SYMBOL(<fs_aufnr_filtered>).
      ls_obj_key-aufnr = <fs_aufnr_filtered>.

      DATA(change_msg) = change_is_valid_for_drf( ls_obj_key-aufnr  ).

      IF change_msg IS NOT INITIAL.
        INSERT ls_obj_key INTO TABLE ct_changed_objects.
      ENDIF.

    ENDLOOP.



  ENDMETHOD.


  METHOD if_drf_outbound~analyze_changes_by_mdg_cp.
    "break .









  ENDMETHOD.


  METHOD if_drf_outbound~analyze_changes_by_others.
*--------------------------------------------------------------------------------------------------*
* Functional Spec: Process order MES interface
* Technical Spec: Process order MES interface
* Process: Manage and Release Orders
* History -------------------------------------------------------------------------------------------------------------*
* Date       | Change           | Contributor               | Description
*----------------------------------------------------------------------------------------------------------------------*
*----------------------------------------------------------------------------------------------------------------------*


    DATA ls_obj_key        TYPE comes_s_drf_prod_key.


    DATA some_time_ago TYPE datum .
    some_time_ago =       sy-datum - 1.

    TYPES: BEGIN OF ty_ll,
             aufnr  TYPE aufnr,
             j_date TYPE datum,
             j_time TYPE uzeit,
             a_date TYPE datum,
             a_time TYPE uzeit,
           END OF ty_ll.
    TYPES tt_ll TYPE TABLE OF  ty_ll WITH KEY aufnr.

    DATA ll_tab TYPE tt_ll.
    DATA ll TYPE ty_ll.

    DATA(business_system)  =  mo_drf_mes_procord_out->ms_runtime_parameter_ext-business_system.

    SELECT aufnr, udate , utime
      FROM Zp_s_dcb_procord_jcds INTO TABLE @DATA(jcds_tab)
        WHERE
          udate >= @some_time_ago
    .
    CHECK sy-subrc = 0.
    SELECT aufnr, create_date,  create_time

      FROM Zp_b_dcb__aif_1 INTO TABLE @DATA(aifindex_tab)
        FOR ALL ENTRIES IN @jcds_tab
        WHERE aufnr = @jcds_tab-aufnr
         AND business_system = @business_system.

    DATA(rc_aif) = sy-subrc ##needed.

    LOOP AT jcds_tab ASSIGNING FIELD-SYMBOL(<jcds>).
      READ TABLE ll_tab WITH TABLE KEY aufnr = <jcds>-aufnr ASSIGNING FIELD-SYMBOL(<ll>).
      IF sy-subrc NE 0.
        ll-aufnr = <jcds>-aufnr.
        ll-j_date = <jcds>-udate.
        ll-j_time = <jcds>-utime.
        APPEND ll TO ll_tab.
      ELSE.
        IF <jcds>-udate > <ll>-j_date
           OR ( <jcds>-udate = ll-j_date  AND <jcds>-utime > <ll>-j_time ).
          <ll>-j_date = <jcds>-udate.
          <ll>-j_time = <jcds>-utime.
        ENDIF.
      ENDIF.
    ENDLOOP.

    LOOP AT ll_tab ASSIGNING <ll>.
      LOOP AT aifindex_tab ASSIGNING FIELD-SYMBOL(<aif>) WHERE aufnr = <ll>-aufnr.
        IF <aif>-create_date > <ll>-a_date
                     OR ( <aif>-create_date = ll-a_date  AND <aif>-create_time > <ll>-a_time ).
          <ll>-a_date = <aif>-create_date.
          <ll>-a_time = <aif>-create_time.
        ENDIF.
      ENDLOOP.
    ENDLOOP.


    LOOP AT ll_tab ASSIGNING <ll>.
      IF <ll>-j_date > <ll>-a_date
                   OR ( <ll>-j_date = <ll>-a_date  AND <ll>-j_time > <ll>-a_time ).
        ls_obj_key = <ll>-aufnr.
        INSERT ls_obj_key INTO TABLE ct_changed_objects.
      ENDIF.
    ENDLOOP.


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

    DATA(business_system)  =  mo_drf_mes_procord_out->ms_runtime_parameter_ext-business_system.

    DATA: t_selopt   TYPE rsds_selopt_t.
    "          T_SELFIELD type RSDS_FRANGE_T,
    "          T_SELTAB   type RSDS_TRANGE,
    "          T_EXPRS    type RSDS_TEXPR,
    "          WA_EXPRS   type RSDS_EXPR,
    "          T_CLAUS    type RSDS_TWHERE.

    DATA: wa_selopt   TYPE rsdsselopt,
          wa_selfield TYPE rsds_frange,
          wa_seltab   TYPE rsds_range.

    wa_seltab-tablename   = 'ZP_S_PROCORD_FLT1'.
    wa_selfield-fieldname = 'MES'.
    wa_selopt-sign    = 'I'.
    wa_selopt-option  = 'EQ'.
    wa_selopt-low     = business_system .
    APPEND wa_selopt TO t_selopt.
    CLEAR wa_selopt.
    APPEND LINES OF t_selopt TO wa_selfield-selopt_t.
    CLEAR t_selopt.
    APPEND wa_selfield TO wa_seltab-frange_t.
    CLEAR wa_selfield.
    APPEND wa_seltab TO et_add_external_criteria.
    CLEAR wa_seltab.

  ENDMETHOD.


  METHOD if_drf_outbound~finalize.

    LOOP AT mt_aufnr_sent_ok ASSIGNING FIELD-SYMBOL(<aufnr>).
      "ToDo: set status
    ENDLOOP.


  ENDMETHOD.


  METHOD if_drf_outbound~initialize.

    CREATE OBJECT mo_drf_mes_procord_out.
    mo_drf_mes_procord_out->ms_runtime_parameter_ext = is_runtime_param.

    es_runtime_param_out_impl-table_type_name =  gc_mes_procord_key_structure.
    eo_if_drf_outbound = mo_drf_mes_procord_out.

  ENDMETHOD.


  METHOD if_drf_outbound~map_data2message.
*----------------------------------------------------------------------------------------*
* Functional Spec: Process order MES interface
* Technical Spec: Process order MES interface
* Process: Manage and Release Orders
* History -------------------------------------------------------------------------------*
* Date       | Change           | Contributor               | Description
*----------------------------------------------------------------------------------------*
*                                                           | Time Zone conversion
*----------------------------------------------------------------------------------------*



    CLEAR ms_manufacturing_order_v2.

    DATA(business_system)  =  mo_drf_mes_procord_out->ms_runtime_parameter_ext-business_system.
    DATA(ir_application_log) = mo_drf_mes_procord_out->ms_runtime_parameter_ext-bal.
    DATA(lo_mapping)   = NEW cl_ppint_soa_mfg_ord_mapping( ).

    DATA:
      lt_caufv_bt TYPE cl_ppint_soa_mfg_ord_mapping=>ty_t_caufvdb, "CAUFVDB: Document table structure of the order header
      lt_afpo_bt  TYPE cl_ppint_soa_mfg_ord_mapping=>ty_t_afpob,   "AFPOB  - Document structure for order items
      lt_affl_bt  TYPE cl_ppint_soa_mfg_ord_mapping=>ty_t_afflb,
      lt_afvg_bt  TYPE cl_ppint_soa_mfg_ord_mapping=>ty_t_afvgb,
      lt_resb_bt  TYPE cl_ppint_soa_mfg_ord_mapping=>ty_t_resbb,
      lt_rserob   TYPE cl_ppint_soa_mfg_ord_mapping=>ty_t_rserob, "RSEROB:: Document Serial Numbers
      "LT_RSEROB_TMP type CL_PPINT_SOA_MFG_ORD_MAPPING=>TY_T_RSEROB,
      lt_afabb    TYPE cl_ppint_soa_mfg_ord_mapping=>ty_t_afabb,
      "LT_AFABB_BT   type CL_PPINT_SOA_MFG_ORD_MAPPING=>TY_T_AFABB,
      lt_affhd_bt TYPE cl_ppint_soa_mfg_ord_mapping=>ty_t_affhd
      .
    DATA commercial_unit(3) TYPE c. "
    DATA: tobesent_oprs TYPE RANGE OF vornr,
          tobesent_opr  LIKE LINE OF tobesent_oprs.
    DATA: order_objects    TYPE bapi_pi_order_objects.
    DATA: phases          TYPE STANDARD TABLE OF bapi_order_phase.
    DATA: pltimezone TYPE tznzone.
    CLEAR   ms_manufacturing_order_v2.

    FIELD-SYMBOLS <ls_key> TYPE  comes_s_drf_prod_key.
    ASSIGN ir_relevant_object->* TO <ls_key>.
    DATA(rc) = sy-subrc ##needed.

    DATA(lf_aufnr) = <ls_key>-aufnr.
    lf_aufnr = |{ lf_aufnr ALPHA = IN }| .


    lt_caufv_bt[] = mt_caufv_bt[].
    DELETE lt_caufv_bt WHERE aufnr NE lf_aufnr.

    READ  TABLE lt_caufv_bt INTO  DATA(ls_caufv_bt) INDEX 1.
    IF sy-subrc NE 0.
      MESSAGE ID sy-msgid TYPE sy-msgty NUMBER sy-msgno
      WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4.
    ENDIF.

    IF mt_mdg_bus_sys_tech_logsys[] IS INITIAL.
      SELECT business_system ,  logsys  FROM mdg_bus_sys_tech
        WHERE disabled IS INITIAL
                INTO CORRESPONDING FIELDS OF TABLE @mt_mdg_bus_sys_tech_logsys
        .
      IF sy-subrc NE 0.
        rc = sy-subrc ##needed.
      ENDIF.
    ENDIF.

    lt_afpo_bt[] = mt_afpo_bt[].
    DELETE lt_afpo_bt[] WHERE aufnr NE lf_aufnr.

    lt_affl_bt[] = mt_affl_bt[].
    DELETE  lt_affl_bt WHERE aufnr_t NE lf_aufnr.

    lt_afvg_bt[] = mt_afvg_bt[].
    DELETE  lt_afvg_bt  WHERE aufnr_t NE lf_aufnr.

    lt_resb_bt[] = mt_resb_bt[].
    DELETE   lt_resb_bt WHERE aufnr NE lf_aufnr.

    lt_rserob[] = mt_rserob[].
    DELETE lt_rserob WHERE ppaufnr NE lf_aufnr.

*  - AFFH:: PRT assignment DATA FOR the WORK ORDER(routing)
    lt_affhd_bt[] = mt_affhd_bt[].
    DELETE lt_affhd_bt WHERE aufnr NE lf_aufnr.

    DATA: lv_aplzl TYPE co_aplzl,
          lv_aufpl TYPE co_aufpl.

    lt_afabb[] = mt_afabb[].
    DELETE lt_afabb WHERE aufnr_tvor NE lf_aufnr.  "ToDo - to check

*  - AUFK:: Process ORDER headers
*  - AFKO:: ORDER HEADER DATA PP orders
*        - AFPO:: ORDER item
*        - AFVC:: ORDER operations
*        - AFVV:: Quantities/dates/values IN the operation
*        - AFVU:: User FIELDS OF the operation
*        - AFFL:: WORK ORDER sequence
    "AFABB::  Network: Document Table for Relationships

*********************************************

    " 

***    SELECT crid, werk, bid, phseq FROM coch INTO TABLE @DATA(l_coch) WHERE bid EQ @lf_aufnr.
***    IF sy-subrc EQ 0.
***      IF l_coch[] IS NOT INITIAL.
***        SELECT crid , ftno , ftrnr,  vornr FROM coft INTO TABLE @DATA(l_coft)
***              FOR ALL ENTRIES IN @l_coch
***              WHERE crid EQ @l_coch-crid.
***      ENDIF.
***    ENDIF.
*Begin of changes, TR#D1TK9A2VIS, WI#
    IF business_system IS NOT INITIAL.
      get_plant_timezone(
                        EXPORTING
                           i_business_system = business_system
                        IMPORTING e_planttimezone = pltimezone    ).
    ENDIF.
*End of changes, TR#D1TK9A2VIS, WI#

    " 
    SELECT  plant AS werks,
    controlrecipedestination  AS phseq,
    typecontrolrecipedestin   AS comty,
    ctrlrecipdestinationtygen AS gen_mode
    INTO TABLE @DATA(t_tc52)
          FROM Zs_b_tc52
      WHERE
      typecontrolrecipedestin EQ '3' " EQ '2' AND
      " AND ctrlrecipdestinationtygen = 'P'.
    .
    DATA(rc_122) = sy-subrc ##needed.
    SELECT orderid AS aufnr, werk, phseq, ftno, crid , vornr INTO TABLE @DATA(l_coft)
          FROM Zp_s_dcb_procord_oper_coft
          WHERE orderid  EQ @lf_aufnr.
    IF sy-subrc EQ 0.
      LOOP AT lt_afvg_bt ASSIGNING FIELD-SYMBOL(<afvg>).
        IF <afvg>-phseq IS INITIAL. " -1329
          "or <afvg>-phseq eq '99'  . "@david.puigmal_crespo please confirm this logic
          READ TABLE l_coft WITH  KEY vornr = <afvg>-vornr INTO DATA(l_coft_rec).
          IF sy-subrc EQ 0.
            " READ TABLE t_tc52 WITH KEY werks = l_coft_rec-werk phseq = l_coft_rec-phseq INTO DATA(l_tc52) ##needed.
            READ TABLE t_tc52 WITH KEY werks = l_coft_rec-werk
                                       phseq = l_coft_rec-phseq
                                       comty = '3' " comty = '2'
                                                   " gen_mode = 'P'
                                       INTO DATA(l_tc52)  ##needed. "
            IF sy-subrc EQ 0. "
              <afvg>-phseq = l_coft_rec-phseq.
            ENDIF. "
          ENDIF.
        ENDIF. ".

    ENDIF.
    " 
    CLEAR mt_p_po_rt[].

    " only operations permited in Zp_po_rt are allowed
    SELECT werks, auart, phseq , business_system , no_send FROM Zp_po_rt
      INTO TABLE @DATA(p_po_rt_buffer) WHERE
            auart =  @ls_caufv_bt-auart
        AND werks = @ls_caufv_bt-werks
      AND business_system = @business_system .  "
    rc = sy-subrc.

    SELECT werks, auart, phseq , business_system
      "FROM Zp_po_rt
       FROM @p_po_rt_buffer AS p_po_rt_buffer
    WHERE no_send IS INITIAL
        AND auart =  @ls_caufv_bt-auart
        AND werks = @ls_caufv_bt-werks
       AND business_system = @business_system
    INTO CORRESPONDING FIELDS OF TABLE @mt_p_po_rt.
    rc = sy-subrc.

    SORT mt_p_po_rt BY phseq ASCENDING.
    READ TABLE mt_p_po_rt  INDEX 1  INTO DATA(p_po_rt_first).  "
    rc = sy-subrc.

    " ignore wildcards if any "real CRD rule" is there
    IF lines( mt_p_po_rt ) GT 1 AND p_po_rt_first-phseq IS INITIAL.
      DELETE mt_p_po_rt WHERE phseq IS INITIAL.
    ENDIF.

    SORT mt_p_po_rt BY phseq ASCENDING.
    READ TABLE mt_p_po_rt  INDEX 1  INTO p_po_rt_first.  "
    rc = sy-subrc.

    SELECT werks, auart, phseq , business_system
      "FROM Zp_po_rt
       FROM @p_po_rt_buffer AS p_po_rt_buffer
  WHERE
      no_send IS NOT INITIAL
      AND auart =  @ls_caufv_bt-auart
      AND werks = @ls_caufv_bt-werks
     AND business_system = @business_system
  INTO CORRESPONDING FIELDS OF TABLE @mt_p_po_rt_no_send.
    rc = sy-subrc.

*Begin of changes, TR#D1TK9A2VIS, WI#
    order_objects-phases = 'X'.
    CALL FUNCTION 'BAPI_PROCORD_GET_DETAIL'
      EXPORTING
        number        = lf_aufnr
        order_objects = order_objects
      TABLES
        phase         = phases.
*End of changes, TR#D1TK9A2VIS, WI#

    DATA(operations_filtering) = 'X'.
    DATA(rgs_wildcards_v1_switch) =  space ."'X'.

    IF rgs_wildcards_v1_switch EQ 'X'.
      "{ wildcard
      READ TABLE mt_p_po_rt WITH  KEY  werks = ls_caufv_bt-werks
                     auart =  ls_caufv_bt-auart
                     business_system  = business_system
                     INTO DATA(ls_p_po_rt_wild).
      rc = sy-subrc.

      IF sy-subrc EQ 0 AND
       ( ls_p_po_rt_wild-phseq IS INITIAL
        OR  ls_p_po_rt_wild-phseq EQ space
        OR  ls_p_po_rt_wild-phseq EQ '  ').

        CLEAR operations_filtering.
      ENDIF.
      "}
    ENDIF.

    IF  operations_filtering  EQ 'X'.
      LOOP AT lt_afvg_bt ASSIGNING FIELD-SYMBOL(<fs_afvg_bt>).
        DATA(tabix) = sy-tabix.
        " "read table mt_p_po_rt with  key PHSEQ = <FS_AFVG_BT>-PHSEQ transporting no fields.
        " {

        IF  <fs_afvg_bt>-phflg EQ 'X'. "this a phase
          READ TABLE mt_p_po_rt WITH  KEY phseq = <fs_afvg_bt>-phseq TRANSPORTING NO FIELDS.
          DATA(rt_rc) = sy-subrc.
          DATA(parent_phase_phseq) = <fs_afvg_bt>-phseq.

          IF rt_rc NE 0.
            IF  p_po_rt_first-phseq IS INITIAL  "this is a wildedcarded
                  AND p_po_rt_first-business_system EQ business_system. ""
              CLEAR rt_rc.  "so allow everything
              READ TABLE mt_p_po_rt_no_send WITH  KEY phseq = <fs_afvg_bt>-phseq TRANSPORTING NO FIELDS.
              IF sy-subrc EQ 0.
                rt_rc = 66. "but not send flag is set
              ENDIF.
            ENDIF.
*Begin of changes, TR#D1TK9A2VIS, WI#
          ELSE.
            tobesent_opr-sign = 'I'.
            tobesent_opr-option = 'EQ'.
            tobesent_opr-low = <fs_afvg_bt>-vornr.
            APPEND tobesent_opr TO tobesent_oprs.
            CLEAR tobesent_opr.
            READ TABLE phases WITH KEY operation_number = <fs_afvg_bt>-vornr INTO DATA(phase).
            IF sy-subrc EQ 0.
              tobesent_opr-sign = 'I'.
              tobesent_opr-option = 'EQ'.
              tobesent_opr-low = phase-superior_operation.
              APPEND tobesent_opr TO tobesent_oprs.
              CLEAR tobesent_opr.
            ENDIF.
*End of changes, TR#D1TK9A2VIS, WI#
          ENDIF.
        ELSE.  "this an operation
          " get real parent
          "read table lt_afabb with key <FS_AFVG_BT>-AUFPL
          READ TABLE lt_afvg_bt WITH KEY  pvzkn = <fs_afvg_bt>-aplzl INTO DATA(parent_afvg). "
          IF sy-subrc EQ 0.
            parent_phase_phseq = parent_afvg-phseq.
          ENDIF.

          IF parent_phase_phseq IS NOT  INITIAL.
            READ TABLE mt_p_po_rt WITH  KEY phseq = parent_phase_phseq TRANSPORTING NO FIELDS.
            rt_rc = sy-subrc.
          ENDIF.

          IF  p_po_rt_first-phseq IS INITIAL   "this is a wildedcarded Plant/Document Type / Business System
            AND p_po_rt_first-business_system EQ business_system. ""
            CLEAR rt_rc.  "so allow everything
            IF parent_phase_phseq IS NOT INITIAL.
              READ TABLE mt_p_po_rt_no_send WITH  KEY phseq = parent_phase_phseq TRANSPORTING NO FIELDS.
              IF sy-subrc EQ 0.
                rt_rc = 66. "but not send flag is set
              ENDIF.
            ENDIF.

          ENDIF.
        ENDIF.

        "IF sy-subrc NE 0.  "
        IF rt_rc NE 0.
          "} 
          DELETE lt_affl_bt WHERE aufpl EQ <fs_afvg_bt>-aufpl   AND  aplzl EQ <fs_afvg_bt>-aplzl.
          DELETE lt_afabb WHERE aufpl_vor EQ <fs_afvg_bt>-aufpl AND  aplzl_vor EQ <fs_afvg_bt>-aplzl.
          DELETE lt_afabb WHERE aufpl_nch EQ <fs_afvg_bt>-aufpl AND  aplzl_nch EQ <fs_afvg_bt>-aplzl.
          DELETE lt_affhd_bt WHERE aufpl EQ <fs_afvg_bt>-aufpl  AND  aplzl EQ <fs_afvg_bt>-aplzl.
*Begin of changes, TR#D1TK9A2VIS, WI#
*          DELETE lt_afvg_bt INDEX tabix.
*End of changes, TR#D1TK9A2VIS, WI#
        ENDIF.
      ENDLOOP.
    ELSE.  "  - remove operations - phases only
      DATA(wildecard_operations_filtering) = space.
      IF wildecard_operations_filtering = 'X'.
        LOOP AT lt_afvg_bt ASSIGNING <fs_afvg_bt>.
          tabix = sy-tabix.
          IF <fs_afvg_bt>-phflg IS INITIAL.
            DELETE lt_affl_bt WHERE aufpl EQ <fs_afvg_bt>-aufpl.
            DELETE lt_afabb WHERE aufpl_vor EQ <fs_afvg_bt>-aufpl.
            DELETE lt_afabb WHERE aufpl_nch EQ <fs_afvg_bt>-aufpl.
            DELETE lt_affhd_bt WHERE aufpl EQ <fs_afvg_bt>-aufpl.
            DELETE lt_afvg_bt INDEX tabix.
          ENDIF.
        ENDLOOP.
      ENDIF.
      "}  - remove operations - phases only
    ENDIF.  "filtering

*Begin of changes, TR#D1TK9A2VIS, WI#
    SORT tobesent_oprs BY low.
    DELETE ADJACENT DUPLICATES FROM tobesent_oprs COMPARING low.
    IF tobesent_oprs[] IS NOT INITIAL.
      DELETE lt_afvg_bt WHERE vornr NOT IN tobesent_oprs.
    ELSE.
      CLEAR lt_afvg_bt[].
    ENDIF.
*End of changes, TR#D1TK9A2VIS, WI#

    " " remove no_send = X
    LOOP AT lt_afvg_bt ASSIGNING <fs_afvg_bt>.
      tabix = sy-tabix.

      IF  <fs_afvg_bt>-phflg EQ 'X'.
        READ TABLE mt_p_po_rt_no_send WITH  KEY phseq = <fs_afvg_bt>-phseq  no_send = 'X' TRANSPORTING NO FIELDS.
        rt_rc = sy-subrc.
        parent_phase_phseq = <fs_afvg_bt>-phseq.
      ELSE.  "it is this an operation

        READ TABLE lt_afvg_bt WITH KEY  pvzkn = <fs_afvg_bt>-aplzl INTO parent_afvg. "
        IF sy-subrc EQ 0.
          parent_phase_phseq = parent_afvg-phseq.
        ENDIF.



        READ TABLE mt_p_po_rt WITH  KEY phseq = parent_phase_phseq no_send = 'X'  TRANSPORTING NO FIELDS.
        rt_rc = sy-subrc.


      ENDIF.

      IF rt_rc EQ 0.
*        DELETE lt_affl_bt WHERE aufpl EQ <fs_afvg_bt>-aufpl.
*        DELETE lt_afabb WHERE aufpl_vor EQ <fs_afvg_bt>-aufpl.
*        DELETE lt_afabb WHERE aufpl_nch EQ <fs_afvg_bt>-aufpl.
*        DELETE lt_affhd_bt WHERE aufpl EQ <fs_afvg_bt>-aufpl.

        DELETE lt_affl_bt WHERE aufpl EQ <fs_afvg_bt>-aufpl   AND  aplzl EQ <fs_afvg_bt>-aplzl.
        DELETE lt_afabb WHERE aufpl_vor EQ <fs_afvg_bt>-aufpl AND  aplzl_vor EQ <fs_afvg_bt>-aplzl.
        DELETE lt_afabb WHERE aufpl_nch EQ <fs_afvg_bt>-aufpl AND  aplzl_nch EQ <fs_afvg_bt>-aplzl.
        DELETE lt_affhd_bt WHERE aufpl EQ <fs_afvg_bt>-aufpl  AND  aplzl EQ <fs_afvg_bt>-aplzl.

        DELETE lt_afvg_bt INDEX tabix.
      ENDIF.
    ENDLOOP.


    "

    IF lt_afvg_bt[] IS INITIAL.     "Order &1 has has operations in status valid for sending &2
      ir_application_log->add_msg(
      iv_msgty = if_drf_const=>msg_type_warning
      iv_msgno = '010'
      iv_msgid = 'ZP_DCB_PROCORD'
      iv_msgv1 = lf_aufnr
      iv_msgv2 = business_system
      ).

      CLEAR ms_manufacturing_order_v2.
      RETURN. "nothing to send
    ENDIF.


    " only operations with rel status are allowed.
    "if SY-UNAME = ''.
    DATA(status_filtering) = 'X' ##NEEDED.
    "endif.


    DATA lt_jest TYPE tt_jstat.
    " data LT_JEST_UNIQUE type TT_JSTAT.
    "data LS_JSTAT_BY_AUFNR type TY_JSTAT_BY_AUFNR.


    DATA(operations_filtering_by_status) = 'X'.

    IF  operations_filtering_by_status  EQ 'X'.
      LOOP AT lt_afvg_bt ASSIGNING <fs_afvg_bt> .
        tabix = sy-tabix.

        .
        CALL FUNCTION 'STATUS_READ'
          EXPORTING
            objnr            = <fs_afvg_bt>-objnr
            only_active      = 'X' " Read only Active status
          TABLES
            status           = lt_jest
          EXCEPTIONS
            object_not_found = 1
            OTHERS           = 2.
        DATA(rc_i0002a) = sy-subrc ##needed.
        READ TABLE lt_jest WITH KEY  stat = 'I0002' TRANSPORTING NO FIELDS.  "Released only
        DATA(rc_i0002) = sy-subrc.

*        read table LT_JEST with key  STAT = 'I0001' transporting no fields.  "and Created ? "ToDo:  to confirm
*        data(RC_I0001) = SY-SUBRC.

        IF rc_i0002 NE 0  "released only not found
          "or RC_I0002 eq 0.
          .
          DELETE lt_affl_bt WHERE aufpl EQ <fs_afvg_bt>-aufpl.
          DELETE lt_afabb WHERE aufpl_vor EQ <fs_afvg_bt>-aufpl.
          DELETE lt_afabb WHERE aufpl_nch EQ <fs_afvg_bt>-aufpl.
          DELETE lt_affhd_bt WHERE aufpl EQ <fs_afvg_bt>-aufpl.
          DELETE lt_afvg_bt INDEX tabix.
        ELSE.
          "keep status change history

          SELECT objnr , stat , chgnr , usnam , udate , utime , tcode , cdtcode , inact , chind
            FROM jcds "Change Documents for System/User Statuses (Table JEST)
           WHERE  objnr            = @<fs_afvg_bt>-objnr
            AND stat = 'I0002' AND inact IS INITIAL
              APPENDING TABLE @DATA(lt_jcds).
          DATA(rc3) = sy-subrc ##needed.

        ENDIF.
      ENDLOOP.
    ENDIF.


    IF lt_afvg_bt[] IS INITIAL.     "Order &1 has has operations in status valid for sending &2
      ir_application_log->add_msg(
      iv_msgty = if_drf_const=>msg_type_warning
      iv_msgno = '011'
      iv_msgid = 'ZP_DCB_PROCORD'
      iv_msgv1 = lf_aufnr
      ).
      CLEAR ms_manufacturing_order_v2.
      RETURN. "nothing to send
    ENDIF.


    "
    "}"


    IF ls_caufv_bt-loekz  IS NOT INITIAL.  "Order has deletion flag
      ir_application_log->add_msg(
      iv_msgty = if_drf_const=>msg_type_warning
      iv_msgno = '013'
      iv_msgid = 'ZP_DCB_PROCORD'
      iv_msgv1 = lf_aufnr
      iv_msgv2 = business_system
      ).

      CLEAR ms_manufacturing_order_v2.
      RETURN. "nothing to send
    ENDIF.





    ms_manufacturing_order_v2 = lo_mapping->map_mfgorder_v2(
    EXPORTING
    it_caufv_bt = lt_caufv_bt  "Document table structure of the order header
    it_afpo_bt  = lt_afpo_bt  "AFPO:: ORDER item - Document structure for order items
    it_affl_bt  = lt_affl_bt  "AFFL:: WORK ORDER sequence, AUFPL as the key
    it_afvg_bt  = lt_afvg_bt  "AFVGB:: Order: Operation structure for buffer table
    it_resb_bt  = lt_resb_bt  "Document table for order components
    it_rserob   = lt_rserob   "RSEROB:: Document Serial Numbers
    it_afabb    = lt_afabb    "AFABB::  Network: Document Table for Relationships
    it_affhd_bt = lt_affhd_bt ).



    "  MS_MANUFACTURING_ORDER_V2-MATERIAL  = conv MATNR_D( |{ MS_MANUFACTURING_ORDER_V2-MATERIAL  alpha = in }| ).
    CALL FUNCTION 'CONVERSION_EXIT_MATN1_INPUT'  "cause AIF index
      EXPORTING
        input        = ms_manufacturing_order_v2-material
      IMPORTING
        output       = ms_manufacturing_order_v2-material
      EXCEPTIONS
        length_error = 1
        OTHERS       = 2.
    DATA(rc_i0002c) = sy-subrc ##needed.

    "{
    CALL FUNCTION 'CONVERSION_EXIT_MATN1_OUTPUT'
      EXPORTING
        input  = ms_manufacturing_order_v2-material
      IMPORTING
        output = ms_manufacturing_order_v2-material.
    DATA(rc_i0002z) = sy-subrc ##needed.
    "}

    ms_manufacturing_order_v2-manufacturing_order = CONV aufnr( |{ ms_manufacturing_order_v2-manufacturing_order ALPHA = IN }| ).  "cause AIF index
    ms_manufacturing_order_v2-business_system = business_system.

    "COBRB-PS_PSP_PNR COBRB-KOSTL
    DATA lv_wbs_element TYPE char20.
    "data LS_CC type ZCL_P_DCB_PPINT_CC_TAB_GL.

    SELECT kostl , ps_psp_pnr FROM cobrb INTO TABLE @DATA(lt_cobrb) WHERE objnr = @ls_caufv_bt-objnr.
    rc3 = sy-subrc ##needed.
    LOOP AT lt_cobrb ASSIGNING FIELD-SYMBOL(<cobrb>).
      IF <cobrb>-kostl IS NOT INITIAL.
        "LS_CC-COST_CENTER = <COBRB>-KOSTL.
        APPEND  <cobrb>-kostl TO  ms_manufacturing_order_v2-manufacturing_order_cc-cost_center.
      ENDIF.
      IF <cobrb>-ps_psp_pnr IS NOT INITIAL.
        CALL FUNCTION 'CONVERSION_EXIT_ABPSP_OUTPUT'
          EXPORTING
            input  = <cobrb>-ps_psp_pnr
          IMPORTING
            output = lv_wbs_element.
        ms_manufacturing_order_v2-wbs_element = lv_wbs_element.
      ENDIF.
    ENDLOOP.
*Begin of changes, TR#D1TK9A2VIS, WI#
    IF pltimezone IS NOT INITIAL.
      convert_timestamp(
                        EXPORTING
                           i_planttimezone = pltimezone
                        CHANGING c_date =   ms_manufacturing_order_v2-mfg_order_planned_start_date
                                 c_time =   ms_manufacturing_order_v2-mfg_order_planned_start_time     ).

      convert_timestamp(
                        EXPORTING
                           i_planttimezone = pltimezone
                        CHANGING c_date =   ms_manufacturing_order_v2-mfg_order_planned_end_date
                                 c_time =   ms_manufacturing_order_v2-mfg_order_planned_end_time     ).
    ENDIF.
*End of changes, TR#D1TK9A2VIS, WI#
    ms_manufacturing_order_v2-exqty_orderltext = get_exqty_orderltext(  lf_aufnr ). " 12Oct2023

    ms_manufacturing_order_v2-bom_header_ecn = ls_caufv_bt-saenr.

    ms_manufacturing_order_v2-bom_header_ecn = ls_caufv_bt-saenr.
    ms_manufacturing_order_v2-recipe_header_ecn = ls_caufv_bt-paenr.

    ms_manufacturing_order_v2-prod_supervisor =  ls_caufv_bt-fevor.
    ms_manufacturing_order_v2-priority = ls_caufv_bt-aprio.

    ms_manufacturing_order_v2-run_id = ls_caufv_bt-cy_seqnr.

    "{
    CALL FUNCTION 'CONVERSION_EXIT_CUNIT_OUTPUT'
      EXPORTING
        input          = ms_manufacturing_order_v2-mfg_order_planned_total_qty-sapunit_code
        language       = 'E'
      IMPORTING
        output         = commercial_unit
      EXCEPTIONS
        unit_not_found = 1
        OTHERS         = 2.
    IF sy-subrc EQ 0.
      ms_manufacturing_order_v2-mfg_order_planned_total_qty-unit_code = commercial_unit.
    ENDIF.

    CALL FUNCTION 'CONVERSION_EXIT_CUNIT_OUTPUT'
      EXPORTING
        input          = ms_manufacturing_order_v2-mfg_ord_plnd_tot_qty_in_base_u-sapunit_code
        language       = 'E'
      IMPORTING
        output         = commercial_unit
      EXCEPTIONS
        unit_not_found = 1
        OTHERS         = 2.
    IF sy-subrc EQ 0.
      ms_manufacturing_order_v2-mfg_ord_plnd_tot_qty_in_base_u-unit_code = commercial_unit.
    ENDIF.

    CALL FUNCTION 'CONVERSION_EXIT_CUNIT_OUTPUT'
      EXPORTING
        input          = ms_manufacturing_order_v2-boomin_lot_size_qty-sapunit_code
        language       = 'E'
      IMPORTING
        output         = commercial_unit
      EXCEPTIONS
        unit_not_found = 1
        OTHERS         = 2.
    IF sy-subrc EQ 0.
      ms_manufacturing_order_v2-boomin_lot_size_qty-unit_code = commercial_unit.
    ENDIF.

    CALL FUNCTION 'CONVERSION_EXIT_CUNIT_OUTPUT'
      EXPORTING
        input          = ms_manufacturing_order_v2-boomax_lot_size_qty-sapunit_code
        language       = 'E'
      IMPORTING
        output         = commercial_unit
      EXCEPTIONS
        unit_not_found = 1
        OTHERS         = 2.
    IF sy-subrc EQ 0.
      ms_manufacturing_order_v2-boomax_lot_size_qty-unit_code = commercial_unit.
    ENDIF.
    " }

    "{
    DATA: mfgorderhdr_kv TYPE Zp_dcb_manufacturing_orde2.
    DATA: mfgordhdr_kv_tab TYPE STANDARD TABLE OF Zp_dcb_manufacturing_orde2.

    mfgorderhdr_kv-key = 'LeadingOrder'.
    mfgorderhdr_kv-sequence = '1'.
    mfgorderhdr_kv-content = ls_caufv_bt-lead_aufnr.
    APPEND mfgorderhdr_kv TO mfgordhdr_kv_tab.
    CLEAR mfgorderhdr_kv.

    mfgorderhdr_kv-key = 'SuperiorOrder'.
    mfgorderhdr_kv-sequence = '1'.
    mfgorderhdr_kv-content = ls_caufv_bt-maufnr.
    APPEND mfgorderhdr_kv TO mfgordhdr_kv_tab.
    CLEAR mfgorderhdr_kv.

    ms_manufacturing_order_v2-Zp_dcb_manufacturing_order = mfgordhdr_kv_tab.

    "}




    "MS_MANUFACTURING_ORDER_V2-CAMPAIGN
    SELECT pcmnr , aufnr , werks , matnr FROM pcmp INTO TABLE @DATA(lt_pcmp) WHERE aufnr = @ls_caufv_bt-aufnr.
    IF sy-subrc EQ 0.
      READ TABLE lt_pcmp  INTO DATA(ls_pcmp) WITH  KEY aufnr = ls_caufv_bt-aufnr werks = ls_caufv_bt-werks matnr =  ls_caufv_bt-plnbez.
      IF sy-subrc NE 0.
        READ TABLE lt_pcmp  INTO ls_pcmp WITH  KEY aufnr = ls_caufv_bt-aufnr werks = ls_caufv_bt-werks .
        IF sy-subrc NE 0.
          READ TABLE lt_pcmp  INTO ls_pcmp WITH  KEY aufnr = ls_caufv_bt-aufnr.
          IF sy-subrc NE 0.
            ms_manufacturing_order_v2-campaign = space.
          ELSE.
            ms_manufacturing_order_v2-campaign = ls_pcmp-pcmnr.
          ENDIF.
        ELSE.
          ms_manufacturing_order_v2-campaign = ls_pcmp-pcmnr.
        ENDIF.
      ELSE.
        ms_manufacturing_order_v2-campaign = ls_pcmp-pcmnr.
      ENDIF.
    ENDIF.

    DATA:
      lv_rsnum TYPE rsnum,
      lv_rspos TYPE rspos.

    SELECT aennr, rsnum, rspos, rsart , fmeng , ausch , schgt, yy1tp_dcb_mltbtch_res, yy1tp_dcb_weighing_tp_res
       FROM resb INTO TABLE @DATA(lt_resb) WHERE  rsnum EQ @ls_caufv_bt-rsnum.
    IF sy-subrc NE 0.
      rc = sy-subrc.
    ENDIF.


    SELECT create_date ,create_time  INTO TABLE @DATA(mt_aif_log) FROM Zp_dcb_aif_1
          WHERE aufnr = @lf_aufnr  AND business_system = @business_system.
    IF sy-subrc NE 0.
      rc = sy-subrc.
    ENDIF.


    LOOP AT ms_manufacturing_order_v2-manufacturing_order_item ASSIGNING FIELD-SYMBOL(<item>).
      "AFPO-WEMNG
      READ TABLE mt_afpo_bt INTO DATA(ls_afpo) WITH KEY aufnr = lf_aufnr posnr = <item>-manufacturing_order_item.
      IF sy-subrc EQ 0.
        <item>-gr_quantity = ls_afpo-wemng.
      ENDIF.

      "
      CALL FUNCTION 'CONVERSION_EXIT_CUNIT_OUTPUT'
        EXPORTING
          input          = <item>-mfgord_item_plnd_tot_qty-sapunit_code
          language       = 'E'
        IMPORTING
          output         = commercial_unit
        EXCEPTIONS
          unit_not_found = 1
          OTHERS         = 2.
      IF sy-subrc EQ 0.
        <item>-mfgord_item_plnd_tot_qty-unit_code = commercial_unit.
      ENDIF.

      "


    ENDLOOP.



    LOOP AT  ms_manufacturing_order_v2-manufacturing_order_activity_n ASSIGNING FIELD-SYMBOL(<acty_net>).

      lv_aufpl = <acty_net>-order_internal_bill_of_operati.
      lv_aplzl = <acty_net>-order_int_bill_of_operations_i.

      READ TABLE mt_mfg_ord_acty_user_afvc INTO DATA(ls_user_afvc) WITH KEY aufpl =  lv_aufpl aplzl = lv_aplzl.
      DATA(rc1) = sy-subrc ##needed.
      MOVE-CORRESPONDING ls_user_afvc TO <acty_net>.


      READ TABLE mt_mfg_ord_acty_user_afvu INTO DATA(ls_user_afvu) WITH KEY aufpl =  lv_aufpl aplzl = lv_aplzl.
      rc1 = sy-subrc.

      MOVE-CORRESPONDING ls_user_afvu TO <acty_net>.

      "{
      SHIFT <acty_net>-usr00 RIGHT DELETING TRAILING space.
      SHIFT <acty_net>-usr01 RIGHT DELETING TRAILING space.
      SHIFT <acty_net>-usr02 RIGHT DELETING TRAILING space.
      SHIFT <acty_net>-usr03 RIGHT DELETING TRAILING space.
      SHIFT <acty_net>-usr04 RIGHT DELETING TRAILING space.
      SHIFT <acty_net>-use04 RIGHT DELETING TRAILING space.
      SHIFT <acty_net>-usr05 RIGHT DELETING TRAILING space.
      SHIFT <acty_net>-use05 RIGHT DELETING TRAILING space.
      SHIFT <acty_net>-usr06 RIGHT DELETING TRAILING space.
      SHIFT <acty_net>-use06 RIGHT DELETING TRAILING space.
      SHIFT <acty_net>-usr07 RIGHT DELETING TRAILING space.
      SHIFT <acty_net>-use07 RIGHT DELETING TRAILING space.
      SHIFT <acty_net>-usr08 RIGHT DELETING TRAILING space.
      SHIFT <acty_net>-usr09 RIGHT DELETING TRAILING space.
      SHIFT <acty_net>-usr10 RIGHT DELETING TRAILING space.
      SHIFT <acty_net>-usr11 RIGHT DELETING TRAILING space.

      SHIFT <acty_net>-lar01 RIGHT DELETING TRAILING space.
      SHIFT <acty_net>-lar02 RIGHT DELETING TRAILING space.
      SHIFT <acty_net>-lar03 RIGHT DELETING TRAILING space.
      SHIFT <acty_net>-lar04 RIGHT DELETING TRAILING space.
      SHIFT <acty_net>-lar05 RIGHT DELETING TRAILING space.
      SHIFT <acty_net>-lar06 RIGHT DELETING TRAILING space.

      CALL FUNCTION 'CONVERSION_EXIT_CUNIT_OUTPUT'
        EXPORTING
          input          = <acty_net>-use04
          language       = 'E'
        IMPORTING
          output         = commercial_unit
        EXCEPTIONS
          unit_not_found = 1
          OTHERS         = 2.
      IF sy-subrc EQ 0.
        <acty_net>-use04 = commercial_unit.
      ENDIF.

      CALL FUNCTION 'CONVERSION_EXIT_CUNIT_OUTPUT'
        EXPORTING
          input          = <acty_net>-use05
          language       = 'E'
        IMPORTING
          output         = commercial_unit
        EXCEPTIONS
          unit_not_found = 1
          OTHERS         = 2.
      IF sy-subrc EQ 0.
        <acty_net>-use05 = commercial_unit.
      ENDIF.

      CALL FUNCTION 'CONVERSION_EXIT_CUNIT_OUTPUT'
        EXPORTING
          input          = <acty_net>-use06
          language       = 'E'
        IMPORTING
          output         = commercial_unit
        EXCEPTIONS
          unit_not_found = 1
          OTHERS         = 2.
      IF sy-subrc EQ 0.
        <acty_net>-use06 = commercial_unit.
      ENDIF.


      CALL FUNCTION 'CONVERSION_EXIT_CUNIT_OUTPUT'
        EXPORTING
          input          = <acty_net>-use07
          language       = 'E'
        IMPORTING
          output         = commercial_unit
        EXCEPTIONS
          unit_not_found = 1
          OTHERS         = 2.
      IF sy-subrc EQ 0.
        <acty_net>-use07 = commercial_unit.
      ENDIF.


      SHIFT <acty_net>-usr00 LEFT DELETING LEADING space.
      SHIFT <acty_net>-usr01 LEFT DELETING LEADING space.
      SHIFT <acty_net>-usr02 LEFT DELETING LEADING space.
      SHIFT <acty_net>-usr03 LEFT DELETING LEADING space.
      SHIFT <acty_net>-usr04 LEFT DELETING LEADING space.
      SHIFT <acty_net>-use04 LEFT DELETING LEADING space.
      SHIFT <acty_net>-usr05 LEFT DELETING LEADING space.
      SHIFT <acty_net>-use05 LEFT DELETING LEADING space.
      SHIFT <acty_net>-usr06 LEFT DELETING LEADING space.
      SHIFT <acty_net>-use06 LEFT DELETING LEADING space.
      SHIFT <acty_net>-usr07 LEFT DELETING LEADING space.
      SHIFT <acty_net>-use07 LEFT DELETING LEADING space.
      SHIFT <acty_net>-usr08 LEFT DELETING LEADING space.
      SHIFT <acty_net>-usr09 LEFT DELETING LEADING space.
      SHIFT <acty_net>-usr10 LEFT DELETING LEADING space.
      SHIFT <acty_net>-usr11 LEFT DELETING LEADING space.

      SHIFT <acty_net>-lar01 LEFT DELETING LEADING space.
      SHIFT <acty_net>-lar02 LEFT DELETING LEADING space.
      SHIFT <acty_net>-lar03 LEFT DELETING LEADING space.
      SHIFT <acty_net>-lar04 LEFT DELETING LEADING space.
      SHIFT <acty_net>-lar05 LEFT DELETING LEADING space.
      SHIFT <acty_net>-lar06 LEFT DELETING LEADING space.


      "} 

      TRY.  "  {   S4H-MES Mapping updates
          DATA ls_tcn01            TYPE tcn01.
          DATA l_slwid  TYPE slwid.

          l_slwid = <acty_net>-slwid.

          CALL FUNCTION 'TCN01_READ'
            EXPORTING
              slwid    = l_slwid
              spras    = sy-langu
            IMPORTING
              struct   = ls_tcn01
            EXCEPTIONS
              no_entry = 1
              OTHERS   = 2.
          IF sy-subrc = 0.
            <acty_net>-swrt0 = ls_tcn01-swrt0.
            <acty_net>-swrt1 = ls_tcn01-swrt1.
            <acty_net>-swrt2 = ls_tcn01-swrt2.
            <acty_net>-swrt3 = ls_tcn01-swrt3.
            <acty_net>-swrt4 = ls_tcn01-swrt4.
            <acty_net>-swrt5 = ls_tcn01-swrt5.
            <acty_net>-swrt6 = ls_tcn01-swrt6.
            <acty_net>-swrt7 = ls_tcn01-swrt7.
            <acty_net>-swrt8 = ls_tcn01-swrt8.
            <acty_net>-swrt9 = ls_tcn01-swrt9.
            <acty_net>-swrt10 = ls_tcn01-swrt10.
            <acty_net>-swrt11 = ls_tcn01-swrt11.

            "{
            SHIFT <acty_net>-swrt0 RIGHT DELETING TRAILING space.
            SHIFT <acty_net>-swrt1 RIGHT DELETING TRAILING space.
            SHIFT <acty_net>-swrt2 RIGHT DELETING TRAILING space.
            SHIFT <acty_net>-swrt3 RIGHT DELETING TRAILING space.
            SHIFT <acty_net>-swrt4 RIGHT DELETING TRAILING space.
            SHIFT <acty_net>-swrt5 RIGHT DELETING TRAILING space.
            SHIFT <acty_net>-swrt6 RIGHT DELETING TRAILING space.
            SHIFT <acty_net>-swrt7 RIGHT DELETING TRAILING space.
            SHIFT <acty_net>-swrt8 RIGHT DELETING TRAILING space.
            SHIFT <acty_net>-swrt9 RIGHT DELETING TRAILING space.
            SHIFT <acty_net>-swrt10 RIGHT DELETING TRAILING space.
            SHIFT <acty_net>-swrt11 RIGHT DELETING TRAILING space.

            SHIFT <acty_net>-swrt0 LEFT DELETING LEADING space.
            SHIFT <acty_net>-swrt1 LEFT DELETING LEADING space.
            SHIFT <acty_net>-swrt2 LEFT DELETING LEADING space.
            SHIFT <acty_net>-swrt3 LEFT DELETING LEADING space.
            SHIFT <acty_net>-swrt4 LEFT DELETING LEADING space.
            SHIFT <acty_net>-swrt5 LEFT DELETING LEADING space.
            SHIFT <acty_net>-swrt6 LEFT DELETING LEADING space.
            SHIFT <acty_net>-swrt7 LEFT DELETING LEADING space.
            SHIFT <acty_net>-swrt8 LEFT DELETING LEADING space.
            SHIFT <acty_net>-swrt9 LEFT DELETING LEADING space.
            SHIFT <acty_net>-swrt10 LEFT DELETING LEADING space.
            SHIFT <acty_net>-swrt11 LEFT DELETING LEADING space.


            "} 

          ENDIF.

        CATCH cx_root INTO DATA(ex_object_cx_root).
          DATA(ex_text) = ex_object_cx_root->get_text( ) ##needed.
          DATA(ex_text_long) = ex_object_cx_root->get_longtext( ) ##needed.
      ENDTRY.
      "}     S4H-MES Mapping updates

      READ TABLE mt_mfg_ord_acty_user_afvv INTO DATA(ls_user_afvv) WITH KEY aufpl =  lv_aufpl aplzl = lv_aplzl.
      rc1 = sy-subrc.
      MOVE-CORRESPONDING ls_user_afvv TO <acty_net>.


      SHIFT <acty_net>-vgw01 RIGHT DELETING TRAILING space.
      SHIFT <acty_net>-vgw02 RIGHT DELETING TRAILING space.
      SHIFT <acty_net>-vgw03 RIGHT DELETING TRAILING space.
      SHIFT <acty_net>-vgw04 RIGHT DELETING TRAILING space.
      SHIFT <acty_net>-vgw05 RIGHT DELETING TRAILING space.
      SHIFT <acty_net>-vgw06 RIGHT DELETING TRAILING space.
      SHIFT <acty_net>-vgw01 LEFT DELETING LEADING space.
      SHIFT <acty_net>-vgw02 LEFT DELETING LEADING space.
      SHIFT <acty_net>-vgw03 LEFT DELETING LEADING space.
      SHIFT <acty_net>-vgw04 LEFT DELETING LEADING space.
      SHIFT <acty_net>-vgw05 LEFT DELETING LEADING space.
      SHIFT <acty_net>-vgw06 LEFT DELETING LEADING space.


      READ TABLE lt_afvg_bt  WITH KEY aufpl =  lv_aufpl aplzl = lv_aplzl INTO DATA(afvg2). ""
      IF sy-subrc EQ 0.
        <acty_net>-standardtextkey = afvg2-ktsch. "
      ENDIF.


      LOOP AT <acty_net>-manufacturing_order_component ASSIGNING FIELD-SYMBOL(<order_comp>).
        lv_rsnum = <order_comp>-reservation.
        lv_rspos =  <order_comp>-reservation_item.
        READ TABLE lt_resb WITH  KEY rsnum = lv_rsnum rspos = lv_rspos INTO DATA(ls_resb).
        rc = sy-subrc.

        <order_comp>-ecn_of_bom_comp = ls_resb-aennr.
        <order_comp>-fixed_quantity = ls_resb-fmeng.
        <order_comp>-scrap_percentage = ls_resb-ausch.


        CALL FUNCTION 'CONVERSION_EXIT_CUNIT_OUTPUT'
          EXPORTING
            input          = <order_comp>-required_quantity_in_base_unit-sapunit_code
            language       = 'E'
          IMPORTING
            output         = commercial_unit
          EXCEPTIONS
            unit_not_found = 1
            OTHERS         = 2.
        IF sy-subrc EQ 0.
          <order_comp>-required_quantity_in_base_unit-unit_code = commercial_unit.
        ENDIF.

        SHIFT <order_comp>-required_quantity_in_base_unit-unit_code RIGHT DELETING TRAILING space.
        SHIFT <order_comp>-required_quantity_in_base_unit-unit_code LEFT DELETING LEADING space.


        SHIFT <order_comp>-scrap_percentage  RIGHT DELETING TRAILING space.
        SHIFT <order_comp>-scrap_percentage LEFT DELETING LEADING space.


        <order_comp>-bulk_indicator = ls_resb-schgt.

        "{
        DATA: mfgorder_comp_kv TYPE Zp_dcb_manufacturing_orde2.
        DATA: mfgord_comp_kv_tab TYPE STANDARD TABLE OF Zp_dcb_manufacturing_orde2.

        mfgorder_comp_kv-key = 'MLTBTCH_RES'.
        mfgorder_comp_kv-sequence = '1'.
        mfgorder_comp_kv-content = ls_resb-yy1tp_dcb_mltbtch_res.
        APPEND mfgorder_comp_kv TO mfgord_comp_kv_tab.
        CLEAR mfgorder_comp_kv.

        mfgorder_comp_kv-key = 'WEIGHING_TP_RES'.
        mfgorder_comp_kv-sequence = '1'.
        mfgorder_comp_kv-content = ls_resb-yy1tp_dcb_weighing_tp_res.
        APPEND mfgorder_comp_kv TO mfgord_comp_kv_tab.
        CLEAR mfgorder_comp_kv.

        <order_comp>-Zp_dcb_mfg_ord_component_k = mfgord_comp_kv_tab.
        CLEAR  mfgord_comp_kv_tab.
        "



      ENDLOOP.
      "LOOP AT <acty_net>-manufacturing_order_component

      DATA(rgs_force24h_switch) = space. "

      IF rgs_force24h_switch EQ 'X'.  "
        tims_not_initial( CHANGING t = <acty_net>-op_erlst_schedld_exec_strt_tme  ).
        tims_not_initial( CHANGING t = <acty_net>-op_erlst_schedld_exec_end_tme ).
        tims_not_initial( CHANGING t = <acty_net>-op_ltst_schedld_exec_strt_tme ).
        tims_not_initial( CHANGING t = <acty_net>-op_ltst_schedld_exec_end_tme ).

        tims_not_initial( CHANGING t = <acty_net>-earliest_finish_of_op_tme ).
        tims_not_initial( CHANGING t = <acty_net>-op_erlst_schedld_procg_strt_tm ).
        tims_not_initial( CHANGING t = <acty_net>-op_ltst_schedld_procg_strt_tme ).
      ENDIF.

      "{

      CALL FUNCTION 'CONVERSION_EXIT_CUNIT_OUTPUT'
        EXPORTING
          input          = <acty_net>-op_planned_total_quantity-sapunit_code
          language       = 'E'
        IMPORTING
          output         = commercial_unit
        EXCEPTIONS
          unit_not_found = 1
          OTHERS         = 2.
      IF sy-subrc EQ 0.
        <acty_net>-op_planned_total_quantity-unit_code = commercial_unit.
      ENDIF.

      CALL FUNCTION 'CONVERSION_EXIT_CUNIT_OUTPUT'
        EXPORTING
          input          = <acty_net>-operation_reference_quantity-sapunit_code
          language       = 'E'
        IMPORTING
          output         = commercial_unit
        EXCEPTIONS
          unit_not_found = 1
          OTHERS         = 2.
      IF sy-subrc EQ 0.
        <acty_net>-operation_reference_quantity-unit_code = commercial_unit.
      ENDIF.

      CALL FUNCTION 'CONVERSION_EXIT_CUNIT_OUTPUT'
        EXPORTING
          input          = <acty_net>-op_planned_processing_durn-sapunit_code
          language       = 'E'
        IMPORTING
          output         = commercial_unit
        EXCEPTIONS
          unit_not_found = 1
          OTHERS         = 2.
      IF sy-subrc EQ 0.
        <acty_net>-op_planned_processing_durn-unit_code = commercial_unit.
      ENDIF.



      CALL FUNCTION 'CONVERSION_EXIT_CUNIT_OUTPUT'
        EXPORTING
          input          = <acty_net>-standard_work_formula_param_gr-work_center_formula_param1-work_center_standard_work_qty-sapunit_code
          language       = 'E'
        IMPORTING
          output         = commercial_unit
        EXCEPTIONS
          unit_not_found = 1
          OTHERS         = 2.
      IF sy-subrc EQ 0.
        <acty_net>-standard_work_formula_param_gr-work_center_formula_param1-work_center_standard_work_qty-unit_code = commercial_unit.
      ENDIF.

      CALL FUNCTION 'CONVERSION_EXIT_CUNIT_OUTPUT'
        EXPORTING
          input          = <acty_net>-standard_work_formula_param_gr-work_center_formula_param2-work_center_standard_work_qty-sapunit_code
          language       = 'E'
        IMPORTING
          output         = commercial_unit
        EXCEPTIONS
          unit_not_found = 1
          OTHERS         = 2.
      IF sy-subrc EQ 0.
        <acty_net>-standard_work_formula_param_gr-work_center_formula_param2-work_center_standard_work_qty-unit_code = commercial_unit.
      ENDIF.


      CALL FUNCTION 'CONVERSION_EXIT_CUNIT_OUTPUT'
        EXPORTING
          input          = <acty_net>-standard_work_formula_param_gr-work_center_formula_param3-work_center_standard_work_qty-sapunit_code
          language       = 'E'
        IMPORTING
          output         = commercial_unit
        EXCEPTIONS
          unit_not_found = 1
          OTHERS         = 2.
      IF sy-subrc EQ 0.
        <acty_net>-standard_work_formula_param_gr-work_center_formula_param3-work_center_standard_work_qty-unit_code = commercial_unit.
      ENDIF.


      CALL FUNCTION 'CONVERSION_EXIT_CUNIT_OUTPUT'
        EXPORTING
          input          = <acty_net>-standard_work_formula_param_gr-work_center_formula_param4-work_center_standard_work_qty-sapunit_code
          language       = 'E'
        IMPORTING
          output         = commercial_unit
        EXCEPTIONS
          unit_not_found = 1
          OTHERS         = 2.
      IF sy-subrc EQ 0.
        <acty_net>-standard_work_formula_param_gr-work_center_formula_param4-work_center_standard_work_qty-unit_code = commercial_unit.
      ENDIF.


      CALL FUNCTION 'CONVERSION_EXIT_CUNIT_OUTPUT'
        EXPORTING
          input          = <acty_net>-standard_work_formula_param_gr-work_center_formula_param5-work_center_standard_work_qty-sapunit_code
          language       = 'E'
        IMPORTING
          output         = commercial_unit
        EXCEPTIONS
          unit_not_found = 1
          OTHERS         = 2.
      IF sy-subrc EQ 0.
        <acty_net>-standard_work_formula_param_gr-work_center_formula_param5-work_center_standard_work_qty-unit_code = commercial_unit.
      ENDIF.

      CALL FUNCTION 'CONVERSION_EXIT_CUNIT_OUTPUT'
        EXPORTING
          input          = <acty_net>-standard_work_formula_param_gr-work_center_formula_param6-work_center_standard_work_qty-sapunit_code
          language       = 'E'
        IMPORTING
          output         = commercial_unit
        EXCEPTIONS
          unit_not_found = 1
          OTHERS         = 2.
      IF sy-subrc EQ 0.
        <acty_net>-standard_work_formula_param_gr-work_center_formula_param6-work_center_standard_work_qty-unit_code = commercial_unit.
      ENDIF.

      IF pltimezone IS NOT INITIAL.
        convert_timestamp(
                        EXPORTING
                           i_planttimezone = pltimezone
                        CHANGING c_date =   <acty_net>-op_erlst_schedld_exec_strt_dte
                                 c_time =   <acty_net>-op_erlst_schedld_exec_strt_tme     ).

        convert_timestamp(
                        EXPORTING
                           i_planttimezone = pltimezone
                        CHANGING c_date =   <acty_net>-op_erlst_schedld_exec_end_dte
                                 c_time =   <acty_net>-op_erlst_schedld_exec_end_tme     ).
      ENDIF.
    ENDLOOP.  "LOOP AT  ms_manufacturing_order_v2-manufacturing_order_activity_n

    "{
    LOOP AT  ms_manufacturing_order_v2-manufacturing_order_relationsh  ASSIGNING FIELD-SYMBOL(<rel>).

      CALL FUNCTION 'CONVERSION_EXIT_CUNIT_OUTPUT'
        EXPORTING
          input          = <rel>-time_intvl_btwn_relshp_node-max_time_intvl_btwn_relshp-sapunit_code
          language       = 'E'
        IMPORTING
          output         = commercial_unit
        EXCEPTIONS
          unit_not_found = 1
          OTHERS         = 2.
      IF sy-subrc EQ 0.
        <rel>-time_intvl_btwn_relshp_node-max_time_intvl_btwn_relshp-unit_code = commercial_unit.
      ENDIF.

      CALL FUNCTION 'CONVERSION_EXIT_CUNIT_OUTPUT'
        EXPORTING
          input          = <rel>-time_intvl_btwn_relshp_node-time_intvl_btwn_relshp-sapunit_code
          language       = 'E'
        IMPORTING
          output         = commercial_unit
        EXCEPTIONS
          unit_not_found = 1
          OTHERS         = 2.
      IF sy-subrc EQ 0.
        <rel>-time_intvl_btwn_relshp_node-time_intvl_btwn_relshp-unit_code = commercial_unit.
      ENDIF.



    ENDLOOP.




    "}


    DATA(freshely_released_indicator) = 'X'.
    IF  freshely_released_indicator  EQ 'X'.


      LOOP AT  ms_manufacturing_order_v2-manufacturing_order_activity_n ASSIGNING FIELD-SYMBOL(<z_acty_net>).
        "LOOP AT  ms_manufacturing_order_v2-manufacturing_order_activity_n

        DATA(aif_log) = mt_aif_log[].

        READ TABLE lt_afvg_bt ASSIGNING <fs_afvg_bt> WITH  KEY vornr = <z_acty_net>-manufacturing_order_operation.
        IF sy-subrc EQ 0.
          READ TABLE  lt_jcds WITH KEY objnr = <fs_afvg_bt>-objnr INTO DATA(ls_jcds).
          IF sy-subrc EQ 0.
            <z_acty_net>-release_date = ls_jcds-udate.
            <z_acty_net>-release_time = ls_jcds-utime.
            <z_acty_net>-acty_ntwk_elmnt_sys_sts-crtd_rel_flag = space.

            DELETE aif_log WHERE create_date LT ls_jcds-udate.
            SORT  aif_log BY  create_date create_time DESCENDING "#EC CI_SORTLOOP .
            .
            READ TABLE aif_log INDEX 1  ASSIGNING FIELD-SYMBOL(<ls_aif_log>).
            IF  sy-subrc NE 0.  "not sent after change yet
              <z_acty_net>-acty_ntwk_elmnt_sys_sts-crtd_rel_flag = 'X'.
            ELSE.
              IF
              <ls_aif_log>-create_date EQ  ls_jcds-udate   "sental already on the same date but earlier
              AND <ls_aif_log>-create_time LE  ls_jcds-utime .

                <z_acty_net>-acty_ntwk_elmnt_sys_sts-crtd_rel_flag = 'X'.

              ENDIF.

            ENDIF .
          ENDIF.

        ENDIF.

      ENDLOOP.
    ENDIF.

    "
    DATA(event_order_type_remove) = 'X'.
    IF  event_order_type_remove  EQ 'X'.
      DELETE ms_manufacturing_order_v2-manufacturing_order_activity_n  WHERE mfg_order_node_type EQ 'StartEvent'.
      DELETE ms_manufacturing_order_v2-manufacturing_order_relationsh  WHERE predecessor_mfgorder_node_type EQ 'StartEvent'.
      DELETE ms_manufacturing_order_v2-manufacturing_order_activity_n  WHERE mfg_order_node_type EQ 'EndEvent'.
      DELETE ms_manufacturing_order_v2-manufacturing_order_relationsh  WHERE successor_mfgorder_node_type EQ 'EndEvent'.
    ENDIF.

  ENDMETHOD.


  METHOD if_drf_outbound~read_complete_data.
*------------------------------------------------------------------------------*
* Functional Spec: Process order MES interface
* Technical Spec: Process order MES interface
* Process: Manage and Release Orders
* History ---------------------------------------------------------------------*
* Date       | Change           | Contributor               | Description
*------------------------------------------------------------------------------*
*------------------------------------------------------------------------------*
    IF ms_runtime_parameter_ext-runmod <> if_drf_const=>runmod_bypass_filter.
      "filter class was already called by framework (incl. external criteria)
      "-> no need for filtering again
      "return.
    ELSE.
      DATA(lt_filtered_object) = VALUE tt_key_table( ).
      get_procord_filter( )->apply_filter(
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

    DATA:
      lt_caufv_bt   TYPE cl_ppint_soa_mfg_ord_mapping=>ty_t_caufvdb, "CAUFVDB: Document table structure of the order header
      lt_afpo_bt    TYPE cl_ppint_soa_mfg_ord_mapping=>ty_t_afpob,   "AFPOB  - Document structure for order items
      lt_affl_bt    TYPE cl_ppint_soa_mfg_ord_mapping=>ty_t_afflb,
      lt_afvg_bt    TYPE cl_ppint_soa_mfg_ord_mapping=>ty_t_afvgb,
      lt_resb_bt    TYPE cl_ppint_soa_mfg_ord_mapping=>ty_t_resbb,
      lt_rserob     TYPE cl_ppint_soa_mfg_ord_mapping=>ty_t_rserob,
      lt_rserob_tmp TYPE cl_ppint_soa_mfg_ord_mapping=>ty_t_rserob,
      lt_afabb      TYPE cl_ppint_soa_mfg_ord_mapping=>ty_t_afabb,
      lt_afabb_bt   TYPE cl_ppint_soa_mfg_ord_mapping=>ty_t_afabb,
      lt_affhd_bt   TYPE cl_ppint_soa_mfg_ord_mapping=>ty_t_affhd,
      lt_affhd_tmp  TYPE cl_ppint_soa_mfg_ord_mapping=>ty_t_affhd
      .


    "data RETURN type BAPIRET2_T.
    "data(IR_APPLICATION_LOG) = MO_DRF_MES_PROCORD_OUT->MS_RUNTIME_PARAMETER_EXT-BAL.

    DATA lt_aufpl TYPE pshlp_aufpl_t.

    "   if  SENDING_CODE_VERSION = '02' ." sy-uname EQ ''.

    FIELD-SYMBOLS <ls_relv_obj>  TYPE comes_s_drf_prod_key.


    " data LF_AUFNR type AUFNR.
    DATA lt_aufnr      TYPE STANDARD TABLE OF ord_pre.
    DATA ls_ord_pre      TYPE ord_pre.

    CONSTANTS lc_taser_ser05 TYPE taser VALUE 'SER05'.

    DATA: ls_rserob TYPE rserob.",
    "LS_CAUFVD type CAUFVD,
    "LS_AFPOD  type AFPOD.

    "data(LO_INTEGRATE) = CL_PPINT_SOA_MFG_ORD_INTEGRATE=>GET_INSTANCE( ).
    "data(LO_WRAPPER)   = LO_INTEGRATE->GET_WRAPPER( ).
    "   data(LO_MAPPING)   = new CL_PPINT_SOA_MFG_ORD_MAPPING( ).

    DATA ev_return_field TYPE sysubrc ##NEEDED.

    LOOP AT ct_relevant_objects ASSIGNING <ls_relv_obj> .
      ls_ord_pre-aufnr = <ls_relv_obj>-aufnr.
      APPEND  ls_ord_pre TO lt_aufnr.
    ENDLOOP. "


**  CLEAR  LT_AUFNR[].
**
**  CLEAR: LT_CAUFV_BT[], LT_AFPO_BT[] , LT_AFFL_BT[] ,  LT_AFVG_BT[] ,
**  LT_RESB_BT[] ,  LT_RSEROB[] ,  LT_RSEROB_TMP[] ,
**  LT_AFABB[]  , LT_AFABB_BT[] , LT_AFFHD_BT[], LT_AFFHD_TMP[].


    CALL FUNCTION 'CO_DB_ORDER_PRE_READ'
      EXPORTING
        client            = sy-mandt
        flg_check         = abap_true
        flg_no_external   = abap_false
      TABLES
        ord_pre_imp       = lt_aufnr
      EXCEPTIONS
        not_found         = 1
        release_no_change = 2
        OTHERS            = 3.
    IF sy-subrc NE 0.
      ev_return_field = sy-subrc.
      RETURN.
    ENDIF.

    "Get order headers
    CALL FUNCTION 'CO_BH_CAUFV_BT_FETCH'
      TABLES
        et_caufv_bt = lt_caufv_bt.


    "Order items
    CALL FUNCTION 'CO_BT_AFPO_BT_FETCH'
      TABLES
        et_afpo_bt = lt_afpo_bt.


    "
*    if LF_AUFNR is not initial.
*      delete LT_AFPO_BT where AUFNR_T ne LF_AUFNR.
*    endif.

    "Serial Numbers
    ls_rserob-taser = lc_taser_ser05.
    LOOP AT lt_afpo_bt ASSIGNING FIELD-SYMBOL(<ls_afpo_bt>)
    WHERE anzsn GT 0.

      CLEAR lt_rserob_tmp[].

      ls_rserob-ppaufnr = <ls_afpo_bt>-aufnr.
      ls_rserob-ppposnr = <ls_afpo_bt>-posnr.
      CALL FUNCTION 'GET_SERNOS_OF_DOCUMENT'
        EXPORTING
          key_data            = ls_rserob
        TABLES
          sernos              = lt_rserob_tmp
        EXCEPTIONS
          key_parameter_error = 1
          no_supported_access = 2
          no_data_found       = 3
          OTHERS              = 4.
      IF sy-subrc IS INITIAL.
        APPEND LINES OF lt_rserob_tmp TO lt_rserob.
      ENDIF.
    ENDLOOP.

    "Sequences
    CALL FUNCTION 'CO_BP_AFFL_BT_FETCH'
      TABLES
        et_affl_bt = lt_affl_bt.

    "Operations
    CALL FUNCTION 'CO_BP_AFVG_BT_FETCH'
      TABLES
        et_afvg_bt = lt_afvg_bt.

    "Reservations
    CALL FUNCTION 'CO_BC_RESB_BT_FETCH'
      TABLES
        et_resb_bt = lt_resb_bt.

    "Relationships
*    call function 'NW_BT_AFAB_OF_ORDER'
*      exporting
*        I_AUFNR         = LF_AUFNR
*        I_INCL_EXT_AOBS = ABAP_TRUE
*      tables
*        ET_AFAB_BT      = LT_AFABB.

    LOOP AT lt_caufv_bt ASSIGNING FIELD-SYMBOL(<caufv>).
      CLEAR lt_afabb[].
      CALL FUNCTION 'NW_BT_AFAB_OF_ORDER'
        EXPORTING
          i_aufnr         = <caufv>-aufnr
          i_incl_ext_aobs = abap_true
        TABLES
          et_afab_bt      = lt_afabb.

      APPEND LINES OF lt_afabb TO mt_afabb.

    ENDLOOP.





    "Production Resources and Tool
    LOOP AT lt_afvg_bt ASSIGNING FIELD-SYMBOL(<fs_afvg_bt>).
      CLEAR lt_affhd_tmp[].
      CALL FUNCTION 'CF_BT_CO_AFFHD_TAB_GET'
        EXPORTING
          i_aufpl           = <fs_afvg_bt>-aufpl
          i_aplzl           = <fs_afvg_bt>-aplzl
          i_no_deleted      = 'X'
          i_no_phys_deleted = 'X'
        TABLES
          affhd_tab         = lt_affhd_tmp
        EXCEPTIONS
          not_found         = 1
          OTHERS            = 2.
      IF sy-subrc NE 0.
        CONTINUE.
      ELSE.
        APPEND LINES OF lt_affhd_tmp TO lt_affhd_bt.
      ENDIF.
    ENDLOOP.

    SORT lt_affhd_bt BY aufpl pzlfh.


    APPEND LINES OF lt_caufv_bt TO mt_caufv_bt .
    APPEND LINES OF lt_afpo_bt TO mt_afpo_bt  .
    APPEND LINES OF lt_affl_bt TO mt_affl_bt  .
    APPEND LINES OF lt_afvg_bt TO mt_afvg_bt  .
    APPEND LINES OF lt_resb_bt TO mt_resb_bt  .
    APPEND LINES OF lt_rserob TO mt_rserob  .
    APPEND LINES OF lt_rserob_tmp TO mt_rserob_tmp  .
    APPEND LINES OF lt_afabb TO mt_afabb   .
    APPEND LINES OF lt_afabb_bt TO mt_afabb_bt  .
    APPEND LINES OF lt_affhd_bt TO mt_affhd_bt.
    APPEND LINES OF lt_affhd_tmp TO mt_affhd_tmp .



*    types: begin of TY_JSTAT_BY_AUFNR,
*             AUFNNR type AUFNR,
*             STAT   type J_STATUS,
*           end of TY_JSTAT_BY_AUFNR,
*           TY_JSTAT_BY_AUFN type standard table of TY_JSTAT_BY_AUFNR.
*
*

    DATA lt_jest TYPE tt_jstat.
    DATA lt_jest_unique TYPE tt_jstat.
    DATA ls_jstat_by_aufnr TYPE ty_jstat_by_aufnr.

    LOOP AT lt_caufv_bt ASSIGNING <caufv>.
      CLEAR lt_jest[].
      CALL FUNCTION 'STATUS_READ'
        EXPORTING
          objnr            = <caufv>-objnr
          only_active      = 'X' " Read only Active status
        TABLES
          status           = lt_jest
        EXCEPTIONS
          object_not_found = 1
          OTHERS           = 2.

      IF sy-subrc EQ 0.
        LOOP AT lt_jest ASSIGNING FIELD-SYMBOL(<ls_jest>).
          ls_jstat_by_aufnr-aufnr = <caufv>-aufnr.
          ls_jstat_by_aufnr-stat = <ls_jest>-stat.
          APPEND ls_jstat_by_aufnr TO mt_jstat_by_aufnr.
        ENDLOOP.
      ENDIF.
    ENDLOOP.





    APPEND LINES OF lt_jest TO lt_jest_unique.
    SORT lt_jest_unique BY stat.
    DELETE ADJACENT DUPLICATES FROM lt_jest_unique COMPARING stat.

    IF lt_jest_unique[] IS NOT INITIAL.
      SELECT istat , txt04 FROM tj02t
      INTO TABLE @DATA(lt_tj02t)
            FOR ALL ENTRIES IN @lt_jest_unique
            WHERE istat = @lt_jest_unique-stat
      AND spras = @sy-langu.
      DATA(rc) = sy-subrc ##needed.
    ENDIF.



    LOOP AT mt_jstat_by_aufnr ASSIGNING FIELD-SYMBOL(<jstat_by_aufnr>).

      READ TABLE  lt_tj02t WITH KEY istat = <jstat_by_aufnr>-stat INTO DATA(lv_tj02t) .
      IF sy-subrc EQ 0.
        <jstat_by_aufnr>-txt04 = lv_tj02t-txt04 .
      ELSE.
        <jstat_by_aufnr>-txt04 =  <jstat_by_aufnr>-stat(4).
      ENDIF.

      CLEAR lv_tj02t.

    ENDLOOP.

    "OBJNR

    LOOP AT lt_caufv_bt ASSIGNING <caufv>.
      APPEND <caufv>-aufpl TO   lt_aufpl.
    ENDLOOP.

    "data LT_MFG_ORD_ACTY_USER_AVFU type TT_MFG_ORD_ACTY_USER_AVFU.
    "data LS_MFG_ORD_ACTY_USER_AVFU type TY_MFG_ORD_ACTY_USER_AVFU.

    SELECT aufpl, aplzl,
      slwid , usr00 , usr01 , usr02 , usr03 , usr04 , use04 , usr05 ,
      use05 , usr06 , use06 , usr07 , use07 , usr08 , usr10 , usr09 , usr11
    INTO CORRESPONDING FIELDS OF TABLE @mt_mfg_ord_acty_user_afvu
     FROM afvu
    FOR ALL ENTRIES IN @lt_aufpl
      WHERE aufpl = @lt_aufpl-table_line.
    DATA(rc3) = sy-subrc ##needed.




    SELECT aufpl, aplzl,
    lar01 , lar02 , lar03 , lar04 , lar05 , lar06
    INTO CORRESPONDING FIELDS OF TABLE @mt_mfg_ord_acty_user_afvc
    FROM afvc
    FOR ALL ENTRIES IN @lt_aufpl
    WHERE aufpl = @lt_aufpl-table_line.
    rc3 = sy-subrc .

    SELECT aufpl, aplzl,
    vgw01 , vge01 , vgw02 , vge02 , vgw03 , vge03 , vgw04 , vge04 ,
    vgw05 , vge05 , vgw06 , vge06
          INTO CORRESPONDING FIELDS OF TABLE @mt_mfg_ord_acty_user_afvv
    FROM afvv
    FOR ALL ENTRIES IN @lt_aufpl
    WHERE aufpl = @lt_aufpl-table_line.
    rc3 = sy-subrc .


*  LOOP AT LT_CAUFV_BT ASSIGNING <CAUFV>.
*    APPEND <CAUFV>-AUFPL TO   LT_AUFPL.
*  ENDLOOP.


  ENDMETHOD.


  METHOD if_drf_outbound~send_message.
*----------------------------------------------------------------------------------------*
* Functional Spec: Process order MES interface
* Technical Spec: Process order MES interface
* Process: Manage and Release Orders
* History -------------------------------------------------------------------------------*
* Date       | Change           | Contributor               | Description
*----------------------------------------------------------------------------------------*
*----------------------------------------------------------------------------------------*


    DATA(verbose) = space ##NEEDED.
    DATA: ls_orders_soa TYPE ord_pre.

    DATA it_orders  TYPE  ops_t_caufvdget ##NEEDED.


    DATA: lo_wsprotocol_message_id TYPE REF TO if_wsprotocol_message_id.

    DATA(business_system) = ms_runtime_parameter_ext-business_system.

    DATA(ir_application_log) = mo_drf_mes_procord_out->ms_runtime_parameter_ext-bal.
    "Do not replicate order if nothing was changed


    DATA: lv_order TYPE comes_s_drf_prod_key.
    DATA: lr_order TYPE REF TO comes_s_drf_prod_key.

    " data MSGGUIDS type SYSUUID_C32.
    DATA lt_return  TYPE  bapiret2_t.
    DATA ls_return  TYPE  bapiret2.

    "data LV_MSGGUID type  GUID_32.

    DATA:
      p_ns     TYPE /aif/ns VALUE 'AIF_NS',
      p_ifname TYPE /aif/ifname VALUE 'AIF_IFNAME',
      p_ifver  TYPE /aif/ifversion VALUE '1'.

    DATA: lv_header    TYPE bal_s_log,
          lv_subobject TYPE balsubobj.


    DATA: ximsgguid     TYPE  sxmsmguid,
          ximsgguid_out TYPE  sxmsmguid.


    DATA(li_mes_int) = cl_im_co_mes_integration=>get_instance( ).
    IF li_mes_int->get_data_change_flag( ) IS INITIAL.
      RETURN.
    ENDIF.


    DATA
          lv_aufnr               TYPE aufnr.


    DATA ls_mfg_order    TYPE ppint_mfgord_exect_req_v2.

    DATA lr_proxy TYPE REF TO co_ppint_mfgord_exe_req_out_v2.

    FIELD-SYMBOLS: <ls_obj_rep_sta>  TYPE drf_s_obj_rep_sta_attr.

    BREAK-POINT ID drf_prod.

    DATA: lt_aufnr TYPE STANDARD TABLE OF ord_pre  ##needed.
    "          LT_CAUFV_BT  type CL_PPINT_SOA_MFG_ORD_MAPPING=>TY_T_CAUFVDB,
    " LT_AFPO_BT   type CL_PPINT_SOA_MFG_ORD_MAPPING=>TY_T_AFPOB,
    "LT_AFFL_BT   type CL_PPINT_SOA_MFG_ORD_MAPPING=>TY_T_AFFLB,
    "LT_AFVG_BT   type CL_PPINT_SOA_MFG_ORD_MAPPING=>TY_T_AFVGB,
    "          LT_RESB_BT   type CL_PPINT_SOA_MFG_ORD_MAPPING=>TY_T_RESBB,
    "lt_afabe     TYPE cl_ppint_soa_mfg_ord_mapping=>ty_t_afabe,  "
    "LT_AFABB     type CL_PPINT_SOA_MFG_ORD_MAPPING=>TY_T_AFABB,  " v2
    " LT_AFABE     type CO_TT_AFABE,  " v1
    "LS_CAUFVD    type CAUFVD,
    "LS_AFPOD type AFPOD ##NEEDED
    "LV_STOP_EXEC type CHAR1
    .



    "data LS_MANUFACTURING_ORDER type PPINT_MANUFACTURING_ORDER_V2 ##NEEDED. "v2
    "data LV_GUID type SXMSMGUID.


    "data(LO_INTEGRATE) = CL_PPINT_SOA_MFG_ORD_INTEGRATE=>GET_INSTANCE( ).
    "data(LO_WRAPPER)   = LO_INTEGRATE->GET_WRAPPER( ).
    "data(LO_MAPPING)   = new CL_PPINT_SOA_MFG_ORD_MAPPING( ).

    "data OBJ_KEY  type COMES_S_DRF_PROD_KEY.


    IF ms_manufacturing_order_v2 IS INITIAL.
      RETURN.
    ENDIF.

    DATA aif_lr_proxy TYPE REF TO object ##NEEDED..


    "loop at CT_OBJ_REP_STA assigning <LS_OBJ_REP_STA>.

    READ TABLE ct_obj_rep_sta ASSIGNING <ls_obj_rep_sta> INDEX 1.
    IF sy-subrc NE 0.
      RETURN.
    ENDIF.

    CLEAR lt_aufnr.
    lv_aufnr = <ls_obj_rep_sta>-object_id.
    ls_orders_soa-aufnr = lv_aufnr.
    APPEND ls_orders_soa TO lt_aufnr.


    lv_order-aufnr = lv_aufnr.
    GET REFERENCE OF lv_order INTO lr_order .


    ls_mfg_order-manufacturing_order_execute_re-message_header = cl_ppint_soa_mfg_ord_bdmh_util=>create_new_bdmh( ).
*Begin of changes, WI#, TR#D1TK9A2QN3
*    ls_mfg_order-manufacturing_order_execute_re-message_header-creation_date_time = sy-datum && sy-uzeit.
    DATA(lv_date) = sy-datum.
    DATA(lv_time) = sy-uzeit.
    convert_timestamp( EXPORTING c_skip = 'X'
                       CHANGING c_date =   lv_date
                                c_time =   lv_time     ).
    ls_mfg_order-manufacturing_order_execute_re-message_header-creation_date_time = lv_date && lv_time.
*End of changes, WI#, TR#D1TK9A2QN3
    ls_mfg_order-manufacturing_order_execute_re-message_header-recipient_business_system_id = <ls_obj_rep_sta>-business_system.

    ls_mfg_order-manufacturing_order_execute_re-manufacturing_order = ms_manufacturing_order_v2.

    "LV_GUID = LS_MFG_ORDER-MANUFACTURING_ORDER_EXECUTE_RE-MESSAGE_HEADER-ID-CONTENT.

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


    DATA(is_valid) = order_status_is_valid_for_drf( lv_order ).
    IF is_valid NE abap_true.

      CLEAR  ls_mfg_order.

      ir_application_log->add_msg(
      iv_msgty = if_drf_const=>msg_type_warning
      iv_msgno = '012'
      iv_msgid = 'ZP_DCB_PROCORD'
      iv_msgv1 = lv_aufnr
      iv_msgv2 = is_valid
      "IV_MSGV3 =
      ir_object      =  lr_order
      ).

    ENDIF.


    lv_header-aldate = sy-datum.
    lv_header-aluser = sy-uname.
    lv_header-alchuser = sy-uname.
    CONCATENATE p_ns p_ifname INTO lv_subobject SEPARATED BY space.
    lv_header-object = /aif/if_globals=>gc_aif_log_obj.
    lv_header-subobject = lv_subobject.
    ls_return-type = 'I'.
    ls_return-id = 'ZP_DCB_PROCORD'.

    DATA:
      error_string    TYPE  string,
      error_long_text TYPE  string.


    IF ls_mfg_order IS NOT INITIAL.
      .

      ls_return-number = '019'.
      ls_return-message_v1 = CONV symsgv( lv_aufnr ).
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

            "data: L_UUID_X16 type SYSUUID_X16.
            "data: SYSTEM_UUID type ref to IF_SYSTEM_UUID.
            "data: OREF type ref to CX_UUID_ERROR.


            DATA do_commit_at_aif TYPE  char01 VALUE space .

            "SYSTEM_UUID = CL_UUID_FACTORY=>CREATE_SYSTEM_UUID( ).
            "XIMSGGUID   = SYSTEM_UUID->CREATE_UUID_X16( ).


            CALL FUNCTION '/AIF/SEND_WITH_PROXY'
              EXPORTING
                ns                   = p_ns
                ifname               = p_ifname
                ifversion            = p_ifver
                appl_log_function    = 'AIF_SEND_WITH_PROXY'
                msgguid              = ximsgguid  "
                iv_persist_xml       = 'X'
                logical_port_name    = 'AIF_LOGICAL_PORT'
              IMPORTING
                ximsgguid            = ximsgguid
                ximsgguid_out        = ximsgguid_out
              TABLES
                add_return_tab       = lt_return
              CHANGING
                sap_struct           = ls_mfg_order
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
                  msgid              = 'ZP_DCB_PROCORD'
                  msgno              = '19'
                  "msgv1      = lv_msgv1
                TABLES
                  return_tab         = lt_return
                EXCEPTIONS
                  max_errors_reached = 1
                  OTHERS             = 2.
              DATA(rc_msg) = sy-subrc ##needed.


              DATA(set_rel) = 'X'.


              IF set_rel EQ 'X'.
                READ TABLE mt_caufv_bt WITH KEY aufnr = lv_aufnr ASSIGNING FIELD-SYMBOL(<fs_caufv>).
                IF sy-subrc EQ 0.
                  TRY.
                      set_distribution_status( EXPORTING iv_aufnr = lv_aufnr iv_objnr = <fs_caufv>-objnr ).


*                  DATA(LO_SOA_MFG_ORD) = CL_PPINT_SOA_MFG_ORD_INTEGRATE=>GET_INSTANCE( ).
*                  LO_SOA_MFG_ORD->SET_DISTRIBUTION_STATUS( IV_ORDER_NUMBER = LV_AUFNR IV_OBJECT_NUMBER = LV_OBJNR ).
                    CATCH cx_root INTO ex_object_cx_root.

                      ex_text = ex_object_cx_root->get_text( ).
                      ex_text_long = ex_object_cx_root->get_longtext( ).
                  ENDTRY.

                ENDIF.
              ENDIF.



              IF do_commit_at_aif EQ space.
                COMMIT WORK AND WAIT.
              ENDIF.

            ENDIF.


            CALL METHOD ir_application_log->add_msg_xi
              EXPORTING
                "IV_XI_MSG_GUID         = XIMSGGUID " LV_GUID
                iv_xi_msg_guid         = ximsgguid_out "        = iv_object_count
                io_message_id_protocol = lo_wsprotocol_message_id
                iv_outb_impl           = mo_drf_mes_procord_out->ms_runtime_parameter_ext-outb_impl
                ir_object              = lr_order
                is_message_out         = ls_mfg_order.
            IF sy-subrc <> 0 ##SUBRC_OK.
              ir_application_log->add_msg( iv_msgid = sy-msgid iv_msgno = sy-msgno iv_msgty = sy-msgty
              iv_msgv1 = sy-msgv1 iv_msgv2 = sy-msgv2 iv_msgv3 = sy-msgv3 iv_msgv4 = sy-msgv4 ).
            ENDIF.


            "MES integration via SOAP message

            READ TABLE mt_caufv_bt WITH KEY aufnr = lv_aufnr INTO DATA(ls_caufvd).
            IF sy-subrc EQ 0.
              DATA(lv_objnr) = ls_caufvd-objnr ##NEEDED.
            ENDIF.

          ELSE.
            lr_proxy->mfgord_execute_req_out_v2( output = ls_mfg_order ).  "/aif/proxy_enabler_update bundled in proxy code -



            CALL METHOD ir_application_log->add_msg_xi
              EXPORTING
                "IV_XI_MSG_GUID         = LV_GUID
                iv_object_count        = iv_object_count
                io_message_id_protocol = lo_wsprotocol_message_id
                iv_outb_impl           = mo_drf_mes_procord_out->ms_runtime_parameter_ext-outb_impl
                ir_object              = lr_order
                is_message_out         = ls_mfg_order.
            IF sy-subrc <> 0 ##SUBRC_OK .
              ir_application_log->add_msg( iv_msgid = sy-msgid iv_msgno = sy-msgno iv_msgty = sy-msgty
              iv_msgv1 = sy-msgv1 iv_msgv2 = sy-msgv2 iv_msgv3 = sy-msgv3 iv_msgv4 = sy-msgv4 ).
            ENDIF.


          ENDIF.








          DATA(lv_xi_msg_guid) = lo_wsprotocol_message_id->get_message_id( ).


          lv_header-extnumber = lv_xi_msg_guid.


          ls_return-type = 'I'.
          ls_return-id = 'ZP_DCB_PROCORD'.
          ls_return-number = '020'.
          ls_return-message_v1 = CONV symsgv( lv_aufnr ).
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
      CLEAR ms_manufacturing_order_v2.








    ENDIF.
    " endloop. "

*
*    data: LS_DISPLAY_PROFILE type BAL_S_PROF,
*          LT_LOG_HANDLES     type BAL_T_LOGH,
*          LS_LOG_HEADER      type BAL_S_LOG,
*          LT_LOG_MSG_HANDLES type BAL_T_MSGH,
*          LS_LOG_MSG_HANDLES like line of LT_LOG_MSG_HANDLES,
*          LT_MESSAGES        type /AIF/BAL_T_MSG,
*          "          LS_MESSAGES        like line of LT_MESSAGES,
*          LV_LINES           type I,
*          LV_EXTENSION       type I.












  ENDMETHOD.


  METHOD order_status_is_valid_for_drf.

    DATA l_txt04   TYPE j_txt04.
    DATA l_txt04_all TYPE string.

    order_status_is_valid = abap_true.

    l_txt04 = 'TECO'.
    READ TABLE mt_jstat_by_aufnr WITH KEY aufnr = i_obj_key-aufnr txt04 = l_txt04 TRANSPORTING NO FIELDS.
    IF sy-subrc EQ 0.
      order_status_is_valid =  l_txt04.
    ENDIF.

**    L_TXT04 = 'PCNF'.
**    read table MT_JSTAT_BY_AUFNR with key AUFNR = I_OBJ_KEY-AUFNR TXT04 = L_TXT04 transporting no fields.
**    if SY-SUBRC eq 0.
**      ORDER_STATUS_IS_VALID =   L_TXT04.
**    endif.
**
**    L_TXT04 = 'CNF'.
**    read table MT_JSTAT_BY_AUFNR with key AUFNR = I_OBJ_KEY-AUFNR TXT04 = L_TXT04 transporting no fields.
**    if SY-SUBRC eq 0.
**      ORDER_STATUS_IS_VALID =   L_TXT04.
**    endif.

    l_txt04 = 'GLOCK' .
    READ TABLE mt_jstat_by_aufnr WITH KEY aufnr = i_obj_key-aufnr txt04 = l_txt04 TRANSPORTING NO FIELDS.
    IF sy-subrc EQ 0.
      order_status_is_valid =   l_txt04.
    ENDIF.

    l_txt04 = 'CUST_LOCK'.
    READ TABLE mt_jstat_by_aufnr WITH KEY aufnr = i_obj_key-aufnr txt04 = l_txt04 TRANSPORTING NO FIELDS.
    IF sy-subrc EQ 0.
      order_status_is_valid =   l_txt04.
    ENDIF.



    "L_TXT04 = 'PREL'.
    "read table MT_JSTAT_BY_AUFNR with key AUFNR = I_OBJ_KEY-AUFNR TXT04 = L_TXT04 transporting no fields.
    "if SY-SUBRC eq 0. ORDER_STATUS_IS_VALID =  L_TXT04. endif.




    "{
    TRY.
        l_txt04 = 'CUST_LOCK'.
        DATA lv_objnr             TYPE jest-objnr.
        DATA user_line         TYPE bsvx-sttxt.
        CONCATENATE 'OR' i_obj_key-aufnr  INTO lv_objnr.
        CALL FUNCTION 'STATUS_TEXT_EDIT'
          EXPORTING
            objnr            = lv_objnr
            only_active      = 'X'
            spras            = 'E'
          IMPORTING
            user_line        = user_line
          EXCEPTIONS
            object_not_found = 1
            OTHERS           = 2.
        IF sy-subrc EQ 0.
          IF user_line CS l_txt04.
            order_status_is_valid =   l_txt04.
          ENDIF.
        ENDIF.
      CATCH cx_root INTO DATA(ex_object_cx_root).
        DATA(ex_text) = ex_object_cx_root->get_text( ) ##needed.
    ENDTRY.

    "}

    LOOP AT mt_jstat_by_aufnr  ASSIGNING FIELD-SYMBOL(<ls_jest>) WHERE aufnr = i_obj_key-aufnr.
      CONCATENATE l_txt04_all <ls_jest>-txt04 INTO l_txt04_all SEPARATED BY space.
    ENDLOOP.


  ENDMETHOD.


  METHOD set_distribution_status.
    "   data: LV_DIST_STATUS type CO_MES_DIST_STATUS.

**
**    Actually set distribution status (no errors may occur at this point)
**    call function 'STATUS_CHANGE_FOR_ACTIVITY'
**      exporting
**        OBJNR                = IV_OBJNR
**        VRGNG                = 'VERT'
**      exceptions
**        ACTIVITY_NOT_ALLOWED = 1
**        OBJECT_NOT_FOUND     = 2
**        STATUS_INCONSISTENT  = 3
**        STATUS_NOT_ALLOWED   = 4
**        WRONG_INPUT          = 5
**        WARNING_OCCURED      = 6
**        others               = 7.
**
**    if SY-SUBRC eq 0.
    "    endif.


    DATA(logswitch_distribution_stat) =  space. "'X'.

    DATA:

      lt_status TYPE TABLE OF jstat,
      ls_status LIKE LINE OF lt_status.


    IF logswitch_distribution_stat EQ 'X'.

      ls_status-stat = 'I0048'. "DISB
      ls_status-inact = ' '.
      APPEND ls_status TO lt_status.
      CALL FUNCTION 'STATUS_CHANGE_INTERN'
        EXPORTING
          objnr               = iv_objnr
        TABLES
          status              = lt_status
        EXCEPTIONS
          object_not_found    = 1
          status_inconsistent = 2
          status_not_allowed  = 3
          OTHERS              = 4.
      DATA(rc_i0002) = sy-subrc ##needed .

    ENDIF.

*     data(LO_SOA_MFG_ORD) = CL_PPINT_SOA_MFG_ORD_INTEGRATE=>GET_INSTANCE( ).
*    LO_SOA_MFG_ORD->SET_DISTRIBUTION_STATUS( IV_ORDER_NUMBER = IV_AUFNR IV_OBJECT_NUMBER = IV_OBJNR ).



  ENDMETHOD.


  METHOD tims_not_initial.

    IF t IS INITIAL.
      t = '240000'.
    ENDIF.

  ENDMETHOD.
ENDCLASS.