*----------------------------------------------------------------------*
*       CLASS CL_MDG_MAT_IDOC_DRF DEFINITION
*----------------------------------------------------------------------*
*
*----------------------------------------------------------------------*
CLASS ZCL_DRF_REF_LTSMMAS_OUT DEFINITION
PUBLIC
CREATE PUBLIC .

  PUBLIC SECTION.

    INTERFACES if_drf_outbound .

    TYPES:
      "interfaces IF_MDG_MAT_DRF_CONSTANTS .
      BEGIN OF ts_segment_transfer ,
        segtyp  TYPE edidd-segnam,
        parseg  TYPE edidd-segnam,
        send(1) TYPE c,
      END OF ts_segment_transfer .
    TYPES:
    tt_segment_transfer TYPE STANDARD TABLE OF ts_segment_transfer .
    TYPES:
    t_edidc TYPE STANDARD TABLE OF edidc .
    TYPES:
    "TT_KEY_TABLE type sorted table of MDG_BS_MAT_DRF_S_MATNR_KEY  with unique key MATNR .
    tt_key_table TYPE SORTED TABLE OF Zv_mia_mm_lts_drf_key_s WITH UNIQUE KEY matnr .  "

    METHODS constructor .
  PROTECTED SECTION.

private section.

  types:
    BEGIN OF t_mat3060,
        matnr               TYPE  bapibatchkey-material,
        plant               TYPE  bapibatchkey-plant,
        classallocations    TYPE  bapi3060_allocations,
        classvaluationschar TYPE  bapi3060_valuations_char,
        classvaluationscurr TYPE  bapi3060_valuations_curr,
        classvaluationsnum  TYPE  bapi3060_valuations_num,
      END OF t_mat3060 .
  types:
    tt_mat3060 TYPE TABLE OF t_mat3060 WITH KEY matnr .
  types:
    BEGIN OF t_mdg_bus_sys_tech_logsys,
        business_system	TYPE mdg_business_system,
        bus_sys_id      TYPE mdg_business_system_id,
        logsys          TYPE logsys,
      END OF t_mdg_bus_sys_tech_logsys .
  types:
    tt_mdg_bus_sys_tech TYPE SORTED TABLE OF t_mdg_bus_sys_tech_logsys WITH UNIQUE KEY business_system .

  data MV_LOGSYS_DEFAULT type LOGSYS .
  constants C_LOGSYS_DEFAULT_PARAMETER_ID type ZS_EFR_FILTER_VALUE value 'LOGSYS_DEFAULT' ##NO_TEXT.
  constants C_APPLICATION_ID type ZS_EFR_APP_ID value 'ZP_MES' ##NO_TEXT.
  data MT_BAPICHARACTVALDESCR_MES_DIS type TT_BAPICHARACTVALUESDESCR .
  data MT_MDG_BUS_SYS_TECH_LOGSYS type TT_MDG_BUS_SYS_TECH .
  class-data GV_SENDCONFIG type MGALE-SENDALL .
  data MO_ID_MATCHING_API type ref to IF_MDG_ID_MATCHING_API_BS .
  data MV_OWN_SYSTEM_ID type MDG_BUSINESS_SYSTEM .
  data MT_BUS_SYS_TECH type MDG_T_BUS_SYS_TECH .
  data MT_MAT_SEGMENT_DATA type MDG_BS_MAT_DRF_S_KEY_DATA .
  class-data GV_REPL_MODE type DRF_DLMOD .
  data MS_RUNTIME_PARAM type DRF_S_RUNTIME_PARAMETER_EXT .
  data MV_COUNT_CALL type C value '0' ##NO_TEXT.
  data MT_CLASS_DATA type MDG_BS_MAT_DRF_T_CLF_KEY_DATA .
    "CLASS-DATA gr_drf_mat TYPE REF TO Zcl_p_mia_drf_matmas_out .  "
  class-data GR_DRF_MAT type ref to ZCL_DRF_REF_LTSMMAS_OUT .
  data MT_INOB_MAP type MDG_BS_CLF_T_OBJNUM_MAP .
  data MT_CHANGE_POINTER type MDG_CP_T_CP .
  data GT_MAT3060 type TT_MAT3060 .
    "DATA gt_matmas_ehsphr_t TYPE Zp_mia_mes_matmas_ehsphr_t .
  data EX_OBJECT_CX_ROOT type ref to CX_ROOT .
  data EX_TEXT type STRING .
  data EX_TEXT_LONG type STRING .
  data RC type SYSUBRC .
  data MT_CHARACTRERISTICS type TT_BAPI1003_CHARACT_R .
  constants GC_MAT_KEY_TAB type STRING value 'MDG_BS_MAT_DRF_T_MATNR_KEY' ##NO_TEXT.
  constants GC_MBEW_SEGMENT type TBNAM value 'MDG_BS_MAT_S_MBEW' ##NO_TEXT.
  constants GC_MARC_SEGMENT type TBNAM value 'MDG_BS_MAT_S_MARC' ##NO_TEXT.
  constants GC_MARA_SEGMENT type TBNAM value 'MDG_BS_MAT_S_MARA' ##NO_TEXT.
  constants GC_MARM_SEGMENT type TBNAM value 'MDG_BS_MAT_S_MARM' ##NO_TEXT.
  constants GC_MARD_SEGMENT type TBNAM value 'MDG_BS_MAT_S_MARD' ##NO_TEXT.
  constants GC_MAKT_SEGMENT type TBNAM value 'MDG_BS_MAT_S_MAKT' ##NO_TEXT.
  constants GC_MEAN_SEGMENT type TBNAM value 'MDG_BS_MAT_S_MEAN' ##NO_TEXT.
  constants GC_RCVPRT type CHAR2 value 'LS' ##NO_TEXT.
  constants GC_OUTB_IMPL type DRF_OUTB_IMPL value 'YMES_MM' ##NO_TEXT.
  constants C_LOGSYS_DEFAULT type LOGSYS value 'MULESOFT' ##NO_TEXT.
  constants C_cust_bc_MES_DIST type ATNAM value 'MM_MES_DIST' ##NO_TEXT.

  methods READ_TEXT_KEYS
    importing
      !IT_MATNR_RANGE type RANGE_T_MATNR
      !IT_MARC type MDG_BS_MAT_T_MARC
      !IT_MVKE type MDG_BS_MAT_T_MVKE .
  methods CHECK_ID_MAPPING
    importing
      !IV_MATNR type KSSK-OBJEK
      !IV_TARGET_BS type MDG_BUSINESS_SYSTEM
    exporting
      !EV_ERROR type ABAP_BOOL .
  methods UPDATE_REPLICATION_DATA
    importing
      !IV_OBJECT_ID type DRF_OBJECT_ID optional
      !IT_IDOC_RESULT type T_EDIDC
      !IV_MESSAGETYPE type EDI_DOCTYP
    changing
      !CT_OBJ_REP_STA type DRF_T_OBJ_REP_STA_FULL optional .
  methods SEND_YP1T_MES_MATMAS_IDOC
    importing
      !IS_MATERIAL_DATA type MDG_BS_MAT_DRF_S_KEY_DATA
      !IS_BUS_SYS_TECH type MDG_S_BUS_SYS_TECH
    changing
      !CT_IDOC_CNTRL type T_EDIDC
      !CT_OBJ_REP_STA type DRF_T_OBJ_REP_STA_FULL .
  methods MAP_MAT_SEGMENT_DATA
    importing
      !IS_MAT_DATA type MDG_BS_MAT_S_MAT_DATA .
  methods CHECK_AENNR
    importing
      !IV_AENNR type AENNR
    changing
      !CV_VALID_FROM type DATUV .
  methods HANDLE_MAT_DATA
    importing
      !IV_PACKET_SIZE type I
    exporting
      !ET_CLASS_DATA type MDG_BS_MAT_DRF_T_CLF_KEY_DATA
    changing
      !CS_MAT_DATA type MDG_BS_MAT_DRF_S_KEY_DATA .
  methods CALL_FILTER
    importing
      !IV_FILTER_OBJ type DRF_FILTER_OBJECT
      !IT_EXTERNAL_CRITERIA type RSDS_TRANGE
      !IV_IGNORE_FILTER type ABAP_BOOL
    changing
      !IT_UNFILT type ANY TABLE
      !ET_FILT type ANY TABLE .
  methods READ_MAT_DATA_PACK
    importing
      !IT_RELEVANT_OBJECTS type SORTED TABLE
    raising
      CX_DRF_PROCESS_MESSAGES .
  methods SEND_YP1T_MAT_SEGMENTS
    importing
      !IS_MATERIAL_DATA type MDG_BS_MAT_DRF_S_KEY_DATA
      !IS_MARAKEY type BDIMARAKEY
      !IS_IDOC_CONTROL type EDIDC
      !IV_MESGTYPE type EDMSG-MSGTYP
      !IS_BUS_SYS_TECH type MDG_S_BUS_SYS_TECH
    exporting
      !ET_IDOC type T_EDIDC
      !EV_CREATED_IDOCS type SY-TABIX .
  methods BUSINESS_SYS_TO_LOGSYS
    importing
      value(IV_BUSINESS_SYSTEM) type MDG_BUSINESS_SYSTEM optional
    returning
      value(RV_LOGSYS) type LOGSYS .
  methods BUSINESS_SYS_TO_cust_bc_MES_DIST
    importing
      value(IV_BUSINESS_SYSTEM) type MDG_BUSINESS_SYSTEM optional
    returning
      value(RV_cust_bc_MES_DIST) type ZV_MIA_YMM_MES_DIST .
  methods DIAG
    exporting
      value(E_EX_TEXT_LONG) type STRING
      value(E_EX_TEXT) type STRING
      value(E_RC) type SYSUBRC .
  methods CONVERT_TIMESTAMP
    changing
      !C_DATE type DATUM
      !C_TIME type UZEIT .
ENDCLASS.



CLASS ZCL_DRF_REF_LTSMMAS_OUT IMPLEMENTATION.


  METHOD business_sys_to_logsys.

    IF mt_mdg_bus_sys_tech_logsys[] IS INITIAL.
      SELECT business_system ,  logsys  FROM Zp_mcn_mdg_bus_sys_tech
      WHERE disabled IS INITIAL
      INTO CORRESPONDING FIELDS OF TABLE @mt_mdg_bus_sys_tech_logsys
      .
      IF sy-subrc NE 0.
        MESSAGE ID sy-msgid TYPE sy-msgty NUMBER sy-msgno
        WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4.
      ENDIF.
    ENDIF.


    TRY.
        rv_logsys = mt_mdg_bus_sys_tech_logsys[ business_system = iv_business_system ]-logsys.

      CATCH cx_sy_itab_line_not_found.
        MESSAGE ID sy-msgid TYPE sy-msgty NUMBER sy-msgno
        WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4.
    ENDTRY.

    IF   rv_logsys IS INITIAL.
      rv_logsys = mv_logsys_default.  " ZCL_S_EFR=>GET_PARAMETER_VALUE( exporting  I_PARAMETER_ID = C_LOGSYS_DEFAULT_PARAMETER_ID .

    IF   rv_logsys IS INITIAL.
      rv_logsys = c_logsys_default.
    ENDIF.

  ENDMETHOD.


  METHOD business_sys_to_cust_bc_mes_dist.


    rv_cust_bc_mes_dist = iv_business_system.

    DATA return_t TYPE bapiret2_tab.

    IF  mt_bapicharactvaldescr_mes_dis IS INITIAL.
      CALL FUNCTION 'BAPI_CHARACT_GETDETAIL'
        EXPORTING
          charactname        = c_cust_bc_mes_dist
          keydate            = sy-datum
          language           = 'E'
        TABLES
          charactvaluesdescr = mt_bapicharactvaldescr_mes_dis
          return             = return_t.
    ENDIF.

    READ TABLE mt_bapicharactvaldescr_mes_dis WITH KEY value_char = iv_business_system(30) INTO DATA(charactvalues_s).
    IF sy-subrc EQ 0.
      rv_cust_bc_mes_dist = charactvalues_s-value_char.
    ELSE.
      READ TABLE mt_bapicharactvaldescr_mes_dis WITH KEY description = iv_business_system  INTO charactvalues_s.
      IF sy-subrc EQ 0.
        rv_cust_bc_mes_dist = charactvalues_s-value_char.
      ELSE.
        "to do ignore
        rv_cust_bc_mes_dist = iv_business_system.
      ENDIF.
    ENDIF.

  ENDMETHOD.


  METHOD call_filter.
*------------------------------------------------------------------------------*
* Functional Spec: Material Master MES interface
* Technical Spec: Material Master MES interface
* Process: Maintain product master data
* History ---------------------------------------------------------------------*
* Date       | Change           | Contributor               | Description
*------------------------------------------------------------------------------*
*------------------------------------------------------------------------------*



    DATA use_object_ref_v     TYPE abap_bool.

    DATA lo_node_inst_fobj     TYPE REF TO cl_drf_filter_object.
    TRY.
        cl_mdg_drf_node_inst_fobj=>apply_filter_all_in_one(
        EXPORTING
          iv_appl               = ms_runtime_param-appl
          iv_business_system    = ms_runtime_param-business_system
          iv_filter_object      = iv_filter_obj
          iv_outb_impl          = ms_runtime_param-outb_impl
          io_bal                = ms_runtime_param-bal
          iv_dlmod              = ms_runtime_param-dlmod
          iv_runmod             = ms_runtime_param-runmod
          iv_fobj               = iv_filter_obj
          iv_use_object_ref     = use_object_ref_v
          it_external_criteria  = it_external_criteria
          iv_ignore_filter      = iv_ignore_filter
        CHANGING
          it_unfiltered_objects = it_unfilt
          co_filter_object      = lo_node_inst_fobj
          et_filtered_objects   = et_filt
          ).
**      catch CX_DRF_FILTER_OBJECT .
**        ##NO_HANDLER
**      catch CX_DRF_EXCEPTION .
**        ##NO_HANDLER
      CATCH cx_root INTO DATA(ex_object_cx_root).
        DATA(ex_text) = ex_object_cx_root->get_text( ) ##needed.
        DATA(ex_text_long) = ex_object_cx_root->get_longtext( ) ##needed.


    ENDTRY.
  ENDMETHOD.                  "call_filter


  METHOD check_aennr.

    DATA:
      ecn_effectivity_v TYPE csdata-xfeld,    "ECM with parameters
      xccin             TYPE ccin.                      "structure for change mgtm.

* check type of change number
    CALL FUNCTION 'CCCN_ECN_WITH_EFFECTIVITY'
      EXPORTING
        eaennr          = iv_aennr
      IMPORTING
        flg_effectivity = ecn_effectivity_v
      EXCEPTIONS
        no_record_found = 1.

    DATA(rc) = sy-subrc ##needed.
    IF ecn_effectivity_v IS INITIAL.

*   Get date of change number
      xccin-aennr = iv_aennr.
      xccin-aeobj = '5'.
      xccin-aeclt = '3'.

      CALL FUNCTION 'CC_CHANGE_NUMBER_CHECK'
        EXPORTING
          eccin                     = xccin
        IMPORTING
          adatuv                    = cv_valid_from
        EXCEPTIONS
          error_aenr                = 1
          error_class               = 2
          error_create              = 3
          error_date_restriction    = 4
          error_generate            = 5
          error_no_omr_for_material = 6
          error_index               = 7
          error_input               = 8
          error_obj_lock            = 9
          error_tcc01               = 10
          error_status              = 11
          error_lock                = 12
          error_authority           = 13
          error_released            = 14
          marked_for_deletion       = 15
          error_leader              = 16
          error_baseline            = 17
          OTHERS                    = 18.
      rc = sy-subrc.
    ELSE.

*   Init ECM processor
      CALL FUNCTION 'CLEF_ECM_PROCESSOR_INIT'
        EXPORTING
          key_date            = cv_valid_from
          i_aennr             = iv_aennr
          i_maintain_flag     = 'X'
        EXCEPTIONS
          ecm_init_error      = 1
          exit_from_dynpro    = 2
          no_maintenance_data = 3
          OTHERS              = 4.
      IF NOT sy-subrc IS INITIAL.
        MESSAGE ID sy-msgid TYPE sy-msgty NUMBER sy-msgno
        WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4.
      ENDIF.
    ENDIF.





  ENDMETHOD.                    "check_aennr


  METHOD check_id_mapping.

    DATA:
      matching_s       TYPE mdg_s_get_matching_easy_bs,
      matching_t       TYPE mdg_t_get_matching_easy_bs,
      error_occurred_v TYPE abap_bool ##needed,
      object_key_s     TYPE mdg_s_object_key_bs,
      object_key_t     TYPE mdg_t_object_key_bs,
      bs_attr_t        TYPE mgd_t_bus_sys_attr.

    CALL METHOD cl_mdg_bs_access_cust_data=>select_bs_data
      EXPORTING
        iv_business_system = iv_target_bs
      IMPORTING
        et_bs_attr         = bs_attr_t.

    READ TABLE bs_attr_t TRANSPORTING NO FIELDS WITH KEY business_system = iv_target_bs
    business_object = if_mdg_otc_const=>material
    comm_channel = '2' "IDoc
    obj_correlation = '2' " Key Mapping
    upd_km = abap_true.

    CHECK sy-subrc = 0.

    IF  mo_id_matching_api IS NOT BOUND.
      TRY.
          CALL METHOD cl_mdg_id_matching_api_bs=>get_instance
            EXPORTING
              iv_direct_db_insert       = abap_false
              iv_set_lcl_system_by_api  = abap_true
            IMPORTING
              er_if_mdg_id_matching_api = mo_id_matching_api
              ev_lcl_business_system    = mv_own_system_id.
        CATCH cx_mdg_id_matching_bs .
          error_occurred_v = abap_true.
        CATCH cx_mdg_no_api_instance .
          error_occurred_v = abap_true.
        CATCH cx_mdg_lcl_bus_sys_not_found .
          error_occurred_v = abap_true.
      ENDTRY.
    ENDIF.

    object_key_s-object_type_code = if_mdg_otc_const=>material.
    object_key_s-identifier_key-id_value = iv_matnr.
    object_key_s-identifier_key-ident_defining_scheme_code = if_mdg_idsc_const=>material_id.
    object_key_s-identifier_key-business_system_id = iv_target_bs.

    APPEND object_key_s TO object_key_t.
    TRY.
        CALL METHOD mo_id_matching_api->get_matching
          EXPORTING
            it_search_key       = object_key_t    " Multiple Object Keys inlcuding Object Type Code
            iv_target_system    = mv_own_system_id    " Key Name of Business System
          IMPORTING
            et_matching_objects = matching_t.    " Identifier Set data of multiple pairs of mapped objects
      CATCH cx_mdg_missing_input_parameter.    " Missing Input parameter in a method
        error_occurred_v = abap_true.
      CATCH cx_mdg_missing_id_data.    " One or more ID data are missing
        error_occurred_v = abap_true.
      CATCH cx_mdg_otc_idm_error.    " Key Mapping related OTC Error
        error_occurred_v = abap_true.
      CATCH cx_mdg_id_matching_bs.    " General Key Mapping Messages
        error_occurred_v = abap_true.
      CATCH cx_mdg_idsc_invalid.    " Key Mapping related OITC code error
        error_occurred_v = abap_true.
      CATCH cx_mdg_no_ctrl_reg_defined.    " For OTC no central registry defined in KM
        error_occurred_v = abap_true.
      CATCH cx_mdg_km_invalid_id_value.    " Invalid ID value
        error_occurred_v = abap_true.
    ENDTRY.

    READ TABLE matching_t INTO matching_s WITH KEY search_key-object_type_code = object_key_s-object_type_code
    search_key-identifier_key-ident_defining_scheme_code = object_key_s-identifier_key-ident_defining_scheme_code
    search_key-identifier_key-id_value = object_key_s-identifier_key-id_value
    search_key-identifier_key-business_system_id = iv_target_bs.

    IF sy-subrc IS NOT INITIAL OR matching_s-no_matching_objects_found = abap_true.
      ev_error = abap_true.
    ENDIF.

  ENDMETHOD.


  METHOD constructor.
    DATA classcharacteristics TYPE tt_bapi1003_charact_r .

    "
    SELECT class FROM ZV_S_MIA_KLAH_Y001 "ZV_S_MIA_KLAH "klah
     WHERE
      "  klart = '001'
     " AND class LIKE 'Y%'   "
      "AND
          vondt LE @sy-datum
      AND bisdt GE @sy-datum
      AND statu EQ 1
       INTO TABLE @DATA(class_t).

    rc = sy-subrc.
    LOOP AT class_t ASSIGNING FIELD-SYMBOL(<class>).

      TRY.
          CALL FUNCTION 'BAPI_CLASS_GETDETAIL'
            EXPORTING
              classtype            = '001'
              classnum             = <class>-class "'cust_bm_INTRAMATERIALS'
            TABLES
              classcharacteristics = classcharacteristics.

          APPEND LINES OF classcharacteristics TO mt_charactreristics.

        CATCH cx_root INTO ex_object_cx_root.
          ex_text = ex_object_cx_root->get_text( ).
          ex_text_long = ex_object_cx_root->get_longtext( ).
      ENDTRY.

    ENDLOOP.

    DELETE mt_charactreristics WHERE department_view IS INITIAL.
    SORT   mt_charactreristics BY name_char department_view. "# no pragma EC CI_SORTSEQ
    DELETE ADJACENT DUPLICATES FROM  mt_charactreristics COMPARING name_char department_view.


    TRY.
        DATA(application_object) = Zcl_s_efr=>factory( i_application_id = c_application_id ).
        DATA: l_result_value TYPE Zs_efr_parameter_value.
        application_object->get_parameter_value( EXPORTING
          i_parameter_id = c_logsys_default_parameter_id
        CHANGING
          c_parameter_value = l_result_value ).

        mv_logsys_default = l_result_value.
      CATCH Zcx_s_efr INTO DATA(exception_ref).
        MESSAGE exception_ref TYPE 'I' DISPLAY LIKE exception_ref->message_type.
        RETURN.
    ENDTRY.





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
*    DATA: time_stamp_plant TYPE timestamp.
    DATA: time_stamp_utc TYPE timestamp.

    IF c_time = '240000'.
      CLEAR c_time.
      IF NOT c_date IS INITIAL.
        c_date = c_date + 1.
      ENDIF.
    ENDIF.

*    time_stamp_plant = |{ c_date }|  &  |{ c_time }|.

    CONVERT DATE c_date TIME c_time INTO TIME STAMP time_stamp_utc TIME ZONE 'CET'.
    rc = sy-subrc.
    CONVERT TIME STAMP time_stamp_utc TIME ZONE 'UTC' INTO DATE DATA(date1) TIME DATA(time1).

    IF rc EQ 0 AND sy-subrc EQ 0.
      c_date = date1.
      c_time = time1.
    ENDIF.
  ENDMETHOD.


  METHOD diag.
    e_ex_text_long = ex_text_long.
    e_ex_text = ex_text.
    e_rc = rc.
  ENDMETHOD.


  METHOD handle_mat_data.

    DATA:object_count_v TYPE i,
         objek_v        TYPE cuobn,
         matnr_v        TYPE matnr.

    DATA:matnr_s    TYPE rsdsselopt,
         marakey_s  TYPE bdimarakey,
         inob_map_s TYPE mdg_bs_clf_s_objnum_map,
         stxhkey_s  TYPE bdistxhkey.

    DATA:matnr_t      TYPE rsdsselopt_t,
         class_data_t TYPE mdg_bs_mat_drf_t_clf_key_data,
         class_data_s LIKE LINE OF class_data_t,
         inob_map_t   TYPE mdg_bs_clf_t_objnum_map.

    object_count_v = iv_packet_size + 1.

* Delete the records which are more then the packet size and replicate which comes under the packet size
    DELETE cs_mat_data-t_marakey FROM object_count_v.

    LOOP AT cs_mat_data-t_marakey INTO marakey_s.
      matnr_s-low = marakey_s-matnr.
      matnr_s-option = 'EQ'.
      matnr_s-sign = 'I'.
      APPEND matnr_s TO matnr_t.
    ENDLOOP.

* Operate on class data of the corresponding materials
    IF mt_class_data IS NOT INITIAL.
      inob_map_t = mt_inob_map.
      class_data_t    = mt_class_data.
      DELETE class_data_t WHERE objek NOT IN matnr_t.
      DELETE mt_class_data WHERE objek IN matnr_t.
      IF inob_map_t IS NOT INITIAL. " check whether class type is valid for multiple objects


        " for ATC only
        DELETE inob_map_t WHERE objek NOT IN matnr_t. " not the pragma #EC CI_SORTSEQ. "


        LOOP AT inob_map_t INTO inob_map_s.
          "move INOB_MAP_S-CUOBJ to OBJEK_V.
          objek_v =  inob_map_s-cuobj.

          LOOP AT mt_class_data INTO class_data_s WHERE objek EQ objek_v
          OR objek EQ inob_map_s-objek.
            INSERT class_data_s INTO TABLE class_data_t.
            DELETE mt_class_data WHERE objek = class_data_s-objek." delete the entry for current object
          ENDLOOP.
          DELETE TABLE mt_inob_map FROM inob_map_s. " delete the netry for current object
        ENDLOOP.
      ENDIF.
    ENDIF.

    " delete duplicated entries for the same class type.
    DATA: class_prev_s LIKE LINE OF mt_class_data.
    SORT class_data_t BY objek obtab klart clint.
    LOOP AT class_data_t INTO class_data_s.
      IF class_data_s-klart <> class_prev_s-klart OR
      class_data_s-objek <> class_prev_s-objek OR
      class_data_s-obtab <> class_prev_s-obtab OR
      class_data_s-aennr <> class_prev_s-aennr OR
      class_data_s-datuv <> class_prev_s-datuv.
        class_prev_s = class_data_s.
      ELSE.
        DELETE class_data_t INDEX sy-tabix.
      ENDIF.
    ENDLOOP.

    DELETE cs_mat_data-t_maktkey WHERE matnr NOT IN matnr_t.
    DELETE cs_mat_data-t_marckey WHERE matnr NOT IN matnr_t. "# not-pragma EC CI_SORTSEQ
    DELETE cs_mat_data-t_mardkey WHERE matnr NOT IN matnr_t.
    DELETE cs_mat_data-t_mpgdkey WHERE matnr NOT IN matnr_t.
    DELETE cs_mat_data-t_mpopkey WHERE matnr NOT IN matnr_t.
    DELETE cs_mat_data-t_marmkey WHERE matnr NOT IN matnr_t.
    DELETE cs_mat_data-t_meankey WHERE matnr NOT IN matnr_t.
    DELETE cs_mat_data-t_mbewkey WHERE matnr NOT IN matnr_t.
    DELETE cs_mat_data-t_mlgnkey WHERE matnr NOT IN matnr_t.
    DELETE cs_mat_data-t_mlgtkey WHERE matnr NOT IN matnr_t.
    DELETE cs_mat_data-t_mvkekey WHERE matnr NOT IN matnr_t.
    DELETE cs_mat_data-t_mlankey WHERE matnr NOT IN matnr_t.

    LOOP AT cs_mat_data-t_stxhkey INTO stxhkey_s.
      IF stxhkey_s-tdobject = 'MVKE' OR stxhkey_s-tdobject = 'MDTXT'.
        matnr_v = stxhkey_s-tdname+0(18).
        READ TABLE matnr_t WITH KEY low = matnr_v TRANSPORTING NO FIELDS.
        IF sy-subrc NE 0.
          DELETE cs_mat_data-t_stxhkey WHERE tdname EQ matnr_v..
        ENDIF.
      ELSE.
        DELETE cs_mat_data-t_stxhkey WHERE tdname NOT IN matnr_t AND tdobject NE 'MVKE' AND tdobject NE 'MDTXT'.
      ENDIF.
    ENDLOOP.

    DELETE cs_mat_data-t_mprwkey WHERE matnr NOT IN matnr_t.
    DELETE cs_mat_data-t_mvegkey WHERE matnr NOT IN matnr_t.
    DELETE cs_mat_data-t_mveukey WHERE matnr NOT IN matnr_t.
    DELETE cs_mat_data-t_mkalkey WHERE matnr NOT IN matnr_t.

* Delete the entries which will be replicated and keep the rest
    DELETE mt_mat_segment_data-t_marakey TO iv_packet_size.
    DELETE mt_mat_segment_data-t_maktkey WHERE matnr IN matnr_t.
    DELETE mt_mat_segment_data-t_marckey WHERE matnr IN matnr_t. "# not-pragma EC CI_SORTSEQ
    DELETE mt_mat_segment_data-t_mardkey WHERE matnr IN matnr_t.
    DELETE mt_mat_segment_data-t_mpgdkey WHERE matnr IN matnr_t.
    DELETE mt_mat_segment_data-t_mpopkey WHERE matnr IN matnr_t.
    DELETE mt_mat_segment_data-t_marmkey WHERE matnr IN matnr_t.
    DELETE mt_mat_segment_data-t_meankey WHERE matnr IN matnr_t.
    DELETE mt_mat_segment_data-t_mbewkey WHERE matnr IN matnr_t.
    DELETE mt_mat_segment_data-t_mlgnkey WHERE matnr IN matnr_t.
    DELETE mt_mat_segment_data-t_mlgtkey WHERE matnr IN matnr_t.
    DELETE mt_mat_segment_data-t_mvkekey WHERE matnr IN matnr_t.
    DELETE mt_mat_segment_data-t_mlankey WHERE matnr IN matnr_t.
    DELETE mt_mat_segment_data-t_stxhkey WHERE tdobject IN matnr_t.
    DELETE mt_mat_segment_data-t_mprwkey WHERE matnr IN matnr_t.
    DELETE mt_mat_segment_data-t_mvegkey WHERE matnr IN matnr_t.
    DELETE mt_mat_segment_data-t_mveukey WHERE matnr IN matnr_t.
    DELETE mt_mat_segment_data-t_mkalkey WHERE matnr IN matnr_t.

    et_class_data = class_data_t.
  ENDMETHOD.                    "handle_mat_data


  METHOD if_drf_outbound~analyze_changes_by_chg_pointer.
* -----------------------------------------------------------------------------*
* Functional Spec: Material Master LAETUS interface
* Technical Spec: Material Master LAETUS interface
* Process: Maintain product master data
* History ---------------------------------------------------------------------*
* Date       | Change           | Contributor               | Description
*------------------------------------------------------------------------------*
*------------------------------------------------------------------------------*




    DATA change_pointer_t TYPE  bdcp_tab.
    DATA change_pointer_s TYPE bdcp.
    DATA temp_cust_bc_mes_dist TYPE Zv_mcn_cust_bc_mes_dist.
    DATA(business_system)  =  gr_drf_mat->ms_runtime_param-business_system.
    DATA objs_t TYPE TABLE OF mdg_bs_mat_drf_s_matnr_key.
    DATA key_s  TYPE mdg_bs_mat_drf_s_matnr_key.

    DATA l_objek TYPE cuobn.
    DATA t_cuobj  TYPE TABLE OF  cuobj. "COMT_VBX_OBJ_NO_BTT.
    DATA l_cuobj TYPE cuobj.

    DATA l_atinn TYPE atinn.
    DATA l_atnam TYPE atnam.


    temp_cust_bc_mes_dist = business_sys_to_cust_bc_mes_dist( business_system ).

    LOOP AT it_change_pointer ASSIGNING FIELD-SYMBOL(<cp>).
      MOVE-CORRESPONDING <cp> TO change_pointer_s.
      APPEND change_pointer_s TO change_pointer_t.
    ENDLOOP.

    LOOP AT change_pointer_t ASSIGNING FIELD-SYMBOL(<lc_bdcp>).
      IF <lc_bdcp>-tabname = 'ABAUSP'. "Characteristics change
        l_cuobj = <lc_bdcp>-tabkey(18).
        APPEND  l_cuobj TO  t_cuobj.
      ENDIF.
    ENDLOOP.

    IF  t_cuobj[] IS NOT INITIAL.
*      SELECT cuobj , objek FROM inob INTO TABLE @DATA(t_objek_abausp) "@data(T_OBJEK_ABAUSP)
*            FOR ALL ENTRIES IN @t_cuobj
*            WHERE cuobj = @t_cuobj-table_line.
      SELECT ClfnObjectInternalID AS cuobj, ClfnObjectID AS objek FROM Zq_b_inob INTO TABLE @DATA(t_objek_abausp)
            FOR ALL ENTRIES IN @t_cuobj
            WHERE ClfnObjectInternalID = @t_cuobj-table_line.
      IF sy-subrc <> 0.
        MESSAGE ID sy-msgid TYPE sy-msgty NUMBER sy-msgno
        WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4 INTO ex_text.
      ENDIF.
    ENDIF.


    LOOP AT change_pointer_t ASSIGNING <lc_bdcp>.
      "loop at CHANGE_POINTER_T assigning field-symbol(<LC_BDCP>).
      CASE <lc_bdcp>-tabname.
        WHEN 'MARA'
          OR 'MARC'.  "MARC -matnr = <lc_bdcp>-tabkey+3(40).
          APPEND key_s TO objs_t.

        WHEN 'DMAKT'.
          IF <lc_bdcp>-cdobjcl = 'MATERIAL'.
            key_s-matnr =  <lc_bdcp>-cdobjid(40).

            APPEND key_s TO objs_t.
          ENDIF.
          "{
        WHEN 'DMARM'.
          IF <lc_bdcp>-cdobjcl = 'MATERIAL'.
            key_s-matnr =  <lc_bdcp>-cdobjid(40).

            APPEND key_s TO objs_t.
          ENDIF.
          "}


        WHEN 'HSMT_DT'
          OR 'HSMT_DN'.
          IF <lc_bdcp>-cdobjcl = 'HSM_MASTER'.
            key_s-matnr =  <lc_bdcp>-cdobjid(18).
            APPEND key_s TO objs_t.
          ENDIF.
          .

        WHEN 'ABAUSP'. "Characteristics change
          l_cuobj = <lc_bdcp>-tabkey(18).

          READ TABLE  t_objek_abausp INTO DATA(objek_abausp_s) WITH KEY cuobj = l_cuobj.
          "select single OBJEK from INOB into L_OBJEK where CUOBJ = L_CUOBJ.   "ATC exception raised

          IF sy-subrc EQ 0.
            l_objek =  objek_abausp_s-objek.
            key_s-matnr = l_objek(39).
            l_atinn = <lc_bdcp>-tabkey+18(10).

            CALL FUNCTION 'CONVERSION_EXIT_ATINN_OUTPUT'
              EXPORTING
                input  = l_atinn
              IMPORTING
                output = l_atnam.

            " characteristics for material ?
            READ TABLE  mt_charactreristics WITH KEY name_char =  l_atnam INTO DATA(l_charact).
            IF sy-subrc EQ 0 AND l_charact-department_view CS 'L'.  "reject characteristics change if not in 'L' Org Area
              APPEND key_s TO objs_t.
            ENDIF.

          ENDIF.

        WHEN OTHERS.
          ex_text = <lc_bdcp>-tabname.

      ENDCASE.


    ENDLOOP.


    SORT objs_t BY matnr.
    DELETE ADJACENT DUPLICATES FROM objs_t COMPARING  matnr.


    IF objs_t[] IS NOT INITIAL.
      SELECT DISTINCT matnr
      FROM Zv_s_mia_drf_mat_filter
      INTO TABLE @ct_changed_objects
      FOR ALL ENTRIES IN @objs_t
      WHERE matnr = @objs_t-matnr
      AND cust_bc_mes_dist = @temp_cust_bc_mes_dist .
      IF sy-subrc <> 0.
        MESSAGE ID sy-msgid TYPE sy-msgty NUMBER sy-msgno
        WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4 INTO ex_text.
      ENDIF.

    ENDIF.



  ENDMETHOD.                    "IF_DRF_OUTBOUND~ANALYZE_CHANGES_BY_CHG_POINTER


  METHOD if_drf_outbound~analyze_changes_by_mdg_cp.


  ENDMETHOD.                    "if_drf_outbound~analyze_changes_by_mdg_cp


  METHOD if_drf_outbound~analyze_changes_by_others.

  ENDMETHOD.                    "IF_DRF_OUTBOUND~ANALYZE_CHANGES_BY_OTHERS


  METHOD if_drf_outbound~apply_node_inst_filter_multi.
    RETURN.
  ENDMETHOD.                    "if_drf_outbound~apply_node_inst_filter_multi


  METHOD if_drf_outbound~apply_node_inst_filter_single.
    RETURN.
  ENDMETHOD.                    "IF_DRF_OUTBOUND~APPLY_NODE_INST_FILTER_SINGLE


  METHOD if_drf_outbound~build_parallel_package.

  ENDMETHOD.                    "IF_DRF_OUTBOUND~BUILD_PARALLEL_PACKAGE


  METHOD if_drf_outbound~enrich_filter_criteria.


*
    DATA(business_system)  =  gr_drf_mat->ms_runtime_param-business_system.
*  DATA TEMP_cust_bc_MES_DIST TYPE ZP_MCN_cust_bc_MES_DIST.
*
*
    DATA(temp_cust_bc_mes_dist) = business_sys_to_cust_bc_mes_dist( business_system ).
*


    DATA: t_selopt   TYPE rsds_selopt_t.


    DATA: wa_selopt   TYPE rsdsselopt,
          wa_selfield TYPE rsds_frange,
          wa_seltab   TYPE rsds_range.

    wa_seltab-tablename   = 'ZV_MIA_MM_LTS_DRF_FLT_S'.
    wa_selfield-fieldname = 'cust_bc_MES_DIST'.
    wa_selopt-sign    = 'I'.
    wa_selopt-option  = 'EQ'.
    wa_selopt-low     = temp_cust_bc_mes_dist .
    APPEND wa_selopt TO t_selopt.

    CLEAR wa_selopt.
    APPEND LINES OF t_selopt TO wa_selfield-selopt_t.
    CLEAR t_selopt.
    APPEND wa_selfield TO wa_seltab-frange_t.
    CLEAR wa_selfield.
    APPEND wa_seltab TO et_add_external_criteria.
    CLEAR wa_seltab.








  ENDMETHOD.                    "if_drf_outbound~enrich_filter_criteria


  METHOD if_drf_outbound~finalize.

  ENDMETHOD.                    "IF_DRF_OUTBOUND~FINALIZE


  METHOD if_drf_outbound~initialize.


    gv_repl_mode = is_runtime_param-dlmod.

    CREATE OBJECT gr_drf_mat.

    gr_drf_mat->ms_runtime_param = is_runtime_param .

    es_runtime_param_out_impl-table_type_name =  gc_mat_key_tab.
    eo_if_drf_outbound = gr_drf_mat.


  ENDMETHOD.                    "if_drf_outbound~initialize


  METHOD if_drf_outbound~map_data2message.

  ENDMETHOD.                    "IF_DRF_OUTBOUND~MAP_DATA2MESSAGE


  METHOD if_drf_outbound~read_complete_data.

    DATA :
      class_data_s TYPE mdg_bs_mat_drf_s_clf_key_data,
      inob_map_s   TYPE mdg_bs_clf_s_objnum_map,
      obj_key_s    TYPE cuobn,
      class_s      TYPE if_mdg_bs_clf_access=>ty_s_classasgn.
    DATA:
      lo_mat_clf    TYPE REF TO cl_mdg_mat_drf_clf,
      lx_mdg_bs_clf TYPE REF TO cx_mdg_bs_clf_gen.
    DATA:
      inob_map_t TYPE mdg_bs_clf_t_objnum_map,
      obj_key_t  TYPE mdg_bs_clf_t_objnum,
      class_t    TYPE if_mdg_bs_clf_access=>ty_ts_classasgn,
      marakey_s  TYPE bdimarakey.

    FIELD-SYMBOLS : <relv_obj_s> TYPE mdg_bs_mat_drf_s_matnr_key.

**** The range tables are filled for fetching complete data of material

    "DELETE ADJACENT DUPLICATES FROM ct_relevant_objects.


    LOOP AT ct_relevant_objects ASSIGNING <relv_obj_s> .
      obj_key_s = <relv_obj_s>-matnr.
      "APPEND obj_key_s TO obj_key_t.
      INSERT obj_key_s INTO TABLE obj_key_t. " - dumps -matnr = <relv_obj_s>-matnr.
      marakey_s-mandt = sy-mandt.
      INSERT marakey_s INTO TABLE mt_mat_segment_data-t_marakey.
    ENDLOOP.

*** The method is called to get the classification data of the materials
*-----------------------------------------------------------
    CREATE OBJECT lo_mat_clf.

    TRY.
        CLEAR class_t.
        CALL METHOD cl_mdg_bs_clf_access=>check_out_classasgn
          EXPORTING
            io_context_cntl = lo_mat_clf
            iv_objtype      = 'MARA'
            its_objnum      = obj_key_t
          IMPORTING
            ets_classasgn   = class_t
            ets_objnum_map  = inob_map_t.

      CATCH cx_mdg_bs_clf_gen INTO lx_mdg_bs_clf.
        CALL METHOD ms_runtime_param-bal->add_msg_re
          EXPORTING
            iv_msgno             = sy-msgno
            ix_exception_catched = lx_mdg_bs_clf.
    ENDTRY.
* Collect
    mt_inob_map = inob_map_t.

*** Class data are read for materials and stored in a global object for later access.
    IF class_t IS NOT INITIAL.
      CLEAR class_s.
      LOOP AT class_t INTO class_s.
        READ TABLE inob_map_t INTO inob_map_s WITH KEY objek = class_s-key-id-objnum
        objtype = class_s-key-id-objtype classtype = class_s-key-id-classtype .
        IF sy-subrc EQ 0.
          class_data_s-objek = inob_map_s-cuobj.
          class_data_s-obtab = inob_map_s-objtype.
        ELSE.
          class_data_s-objek = class_s-key-id-objnum.
          class_data_s-obtab = class_s-key-id-objtype.
        ENDIF.
        class_data_s-klart = class_s-key-id-classtype.
        class_data_s-aennr = class_s-key-id-changeno.
        class_data_s-datuv = class_s-att-datuv.
        class_data_s-clint = class_s-att-clint.
        class_data_s-adzhl = class_s-att-adzhl.
        class_data_s-mafid = class_s-att-mafid.
        class_data_s-matnr = class_s-key-id-objnum.
        APPEND class_data_s TO mt_class_data.
        CLEAR inob_map_s.
      ENDLOOP.
    ENDIF.
    SORT  mt_class_data BY klart objek obtab aennr.
    DELETE ADJACENT DUPLICATES FROM mt_class_data.


    me->read_mat_data_pack( it_relevant_objects = ct_relevant_objects ).  " mat3060_s TYPE t_mat3060.
    DATA return TYPE bapiret2_t.
    "DATA(IR_APPLICATION_LOG) = MO_ ->MS_RUNTIME_PARAMETER_EXT-BAL.



    LOOP AT ct_relevant_objects ASSIGNING <relv_obj_s> .
      CALL FUNCTION 'ZV_MIA_MATERIAL_READ_DATA'
        EXPORTING
          material            = <relv_obj_s>-matnr
        TABLES
          return              = return
          classallocations    = mat3060_s-classallocations[]
          classvaluationschar = mat3060_s-classvaluationschar[]
          classvaluationscurr = mat3060_s-classvaluationscurr[]
          classvaluationsnum  = mat3060_s-classvaluationsnum[].

      IF sy-subrc NE 0.

***      IR_APPLICATION_LOG->ADD_MSG(
***      IV_MSGTY = IF_DRF_CONST=>MSG_TYPE_WARNING
***      IV_MSGNO = '004'
***      IV_MSGID = 'ZP_MCN'
***      IV_MSGV1 = <RELV_OBJ_S>-MATNR
***      IV_MSGV2 = <RELV_OBJ_S>-CHARG
***      IV_MSGV3 = SPACE
***      "ir_object      =  lr_mcha_key
***
***      ).

      ENDIF.



      mat3060_s-matnr = <relv_obj_s>-matnr.

      APPEND mat3060_s TO gt_mat3060.

***
***      DATA return_ehs             TYPE STANDARD TABLE OF bapiret2.
***
***      CALL FUNCTION 'ZP_MIA_EHS_READ_DATA'
***        EXPORTING
***          material           = <relv_obj_s>-matnr
***        IMPORTING
***          rc                 = rc
***        TABLES
***          return             = return_ehs
***        CHANGING
***          ct_matmas_ehsphr_t = gt_matmas_ehsphr_t.
***
***
***      rc = sy-subrc + rc.

    ENDLOOP.





  ENDMETHOD.                    "if_drf_outbound~read_complete_data


  METHOD if_drf_outbound~send_message.

    DATA :
      bus_sys_tech_s        TYPE mdg_s_bus_sys_tech,
      obj_rep_s             TYPE drf_s_obj_rep_sta_attr,
      idoc_control_s        TYPE edidc,
      idoc_matmas_control_t TYPE t_edidc,
      idoc_clfmas_control_t TYPE t_edidc ##needed,
      class_data_t          TYPE mdg_bs_mat_drf_t_clf_key_data ##needed,
      mat_data_s            TYPE mdg_bs_mat_drf_s_key_data.

    CLEAR mt_change_pointer."For each business system refresh the change pointer table



    "data(BUSINESS_SYSTEM)  =  MO_DRF_MES_BATCH_OUT->MS_RUNTIME_PARAMETER_EXT-BUSINESS_SYSTEM.  "

* Fetch the business system for the replication model
    IF mv_count_call EQ 0.
      mv_count_call = 1.
      CALL METHOD cl_drf_access_cust_data=>select_business_sys_for_appl
        EXPORTING
          iv_appl         = ms_runtime_param-appl
          iv_outb_impl    = ms_runtime_param-outb_impl
        IMPORTING
          et_bus_sys_tech = mt_bus_sys_tech.
    ENDIF.

    READ TABLE ct_obj_rep_sta INTO obj_rep_s INDEX 1.
    DATA(rc) = sy-subrc ##needed.

    READ TABLE mt_bus_sys_tech INTO bus_sys_tech_s WITH KEY business_system = obj_rep_s-business_system.
    rc = sy-subrc.
    idoc_control_s-rcvprn = bus_sys_tech_s-logsys.
    idoc_control_s-rcvprt =  gc_rcvprt.

    APPEND idoc_control_s TO idoc_matmas_control_t.
    APPEND idoc_control_s TO idoc_clfmas_control_t.
    mat_data_s = mt_mat_segment_data .


    SORT mat_data_s-t_stxhkey BY tdname(18).

    IF iv_object_count > 0.
      CALL METHOD me->handle_mat_data
        EXPORTING
          iv_packet_size = iv_object_count
        IMPORTING
          et_class_data  = class_data_t
        CHANGING
          cs_mat_data    = mat_data_s.
    ENDIF.


* Send Matmas IDOC
    IF mat_data_s IS NOT INITIAL.
      CALL METHOD send_yp1t_mes_matmas_idoc
        EXPORTING
          is_material_data = mat_data_s
          is_bus_sys_tech  = bus_sys_tech_s "IS_BUS_SYS_TECH 
          ct_idoc_cntrl    = idoc_matmas_control_t
          ct_obj_rep_sta   = ct_obj_rep_sta.
    ENDIF.



    DATA(cp_postproces) = space.

    IF cp_postproces EQ 'X'.
      IF ms_runtime_param-outb_impl =  gc_outb_impl."Execute change pointer and new message types only in case of new outbound implmentation
        " Set Change pointer to processed for current system
        IF mt_change_pointer IS NOT INITIAL.
          SORT mt_change_pointer.
          DELETE ADJACENT DUPLICATES FROM mt_change_pointer.
          cl_mdg_change_pointer=>set_cp_status_per_bus_sys(
          EXPORTING
            it_change_pointer  = mt_change_pointer
            iv_business_system = obj_rep_s-business_system
            iv_status          = cl_mdg_change_pointer=>gc_status_cp ).
        ENDIF.
      ENDIF.
    ENDIF.
  ENDMETHOD.                    "if_drf_outbound~send_message


  METHOD map_mat_segment_data.
**** Get the relevant objects from the filter and store it in static variable

    DATA : mat_s_mara_s TYPE mdg_bs_mat_s_mara .
    DATA : mat_s_makt_s TYPE mdg_bs_mat_s_makt .
    DATA : mat_s_marc_s TYPE mdg_bs_mat_s_marc .
    DATA : mat_s_mard_s TYPE mdg_bs_mat_s_mard .
    DATA : mat_s_mpgd_s TYPE mdg_bs_mat_s_mpgd .
    DATA : mat_s_mpop_s TYPE mdg_bs_mat_s_mpop .
    DATA : mat_s_marm_s TYPE mdg_bs_mat_s_marm .
    DATA : mat_s_mean_s TYPE mdg_bs_mat_s_mean .
    DATA : mat_s_mbew_s TYPE mdg_bs_mat_s_mbew .
    DATA : mat_s_mlgn_s TYPE mdg_bs_mat_s_mlgn.
    DATA : mat_s_mlgt_s TYPE mdg_bs_mat_s_mlgt .
    DATA : mat_s_mvke_s TYPE mdg_bs_mat_s_mvke .
    DATA : mat_s_mlan_pr_s     TYPE mdg_bs_mat_s_steumm.
    DATA : mat_s_mlan_sl_s     TYPE mdg_bs_mat_s_steu.

    DATA : bdimarakey_s TYPE bdimarakey.
    DATA : bdimaktkey_s TYPE bdimaktkey.
    DATA : bdimarckey_s TYPE mdg_bs_mat_drf_s_plnt_key_data.
    DATA : bdimardkey_s TYPE bdimardkey.
    DATA : bdimpgdkey_s TYPE bdimpgdkey.
    DATA : bdimpopkey_s TYPE bdimpopkey.
    DATA : bdimarmkey_s TYPE bdimarmkey.
    DATA : bdimeankey_s TYPE bdimeankey.
    DATA : bdimbewkey_s TYPE bdimbewkey.
    DATA : bdimlgnkey_s TYPE bdimlgnkey.
    DATA : bdimlgtkey_s TYPE bdimlgtkey.
    DATA : bdimvkekey_s TYPE mdg_bs_mat_drf_s_sls_key_data.
    DATA : bdimlankey_s TYPE bdimlankey.

    DATA : mara_t TYPE STANDARD TABLE OF mdg_bs_mat_s_mara.
    DATA : marc_t TYPE STANDARD TABLE OF mdg_bs_mat_s_marc.
    DATA : mard_t TYPE STANDARD TABLE OF mdg_bs_mat_s_mard.
    DATA : mbew_t TYPE STANDARD TABLE OF mdg_bs_mat_s_mbew.
    DATA : mlgn_t TYPE STANDARD TABLE OF mdg_bs_mat_s_mlgn.
    DATA : mvke_t TYPE STANDARD TABLE OF mdg_bs_mat_s_mvke.
    DATA : mlgt_t TYPE STANDARD TABLE OF mdg_bs_mat_s_mlgt.

    DEFINE filltable .
      LOOP AT is_mat_data-&1_tab INTO mat_s_&1_s .
        MOVE-CORRESPONDING mat_s_&1_s TO bdi&1key_s.
        APPEND bdi&1key_s TO mt_mat_segment_data-t_&1key.
      ENDLOOP.
    END-OF-DEFINITION.

    DEFINE filltable_1 .
      "APPEND LINES OF is_mat_data-&1_tab TO lt_&1.
      APPEND LINES OF is_mat_data-&1_tab TO &1_t.
      IF gv_repl_mode = if_drf_const=>mode_init.
        LOOP AT &1_t INTO mat_s_&1_s WHERE lvorm NE abap_true.
          MOVE-CORRESPONDING mat_s_&1_s TO bdi&1key_s.
          APPEND bdi&1key_s TO mt_mat_segment_data-t_&1key.
        ENDLOOP.
      ELSE.
        LOOP AT &1_t INTO mat_s_&1_s .
          MOVE-CORRESPONDING mat_s_&1_s TO bdi&1key_s.
          APPEND bdi&1key_s TO mt_mat_segment_data-t_&1key.
        ENDLOOP.
      ENDIF.
    END-OF-DEFINITION.

    filltable_1 mara.
    filltable_1 marc.
    filltable_1 mard.
    filltable_1 mbew.
    filltable_1 mlgn.
    filltable_1 mlgt.
    filltable_1 mvke.
    filltable makt.
    filltable mpgd.
    filltable mpop.
    filltable marm.
    filltable mean.

    LOOP AT is_mat_data-mlan_purchase_tab INTO mat_s_mlan_pr_s .
      CLEAR bdimlankey_s.
      MOVE-CORRESPONDING mat_s_mlan_pr_s TO bdimlankey_s.
      bdimlankey_s-mandt = sy-mandt.
      APPEND bdimlankey_s TO mt_mat_segment_data-t_mlankey.
    ENDLOOP.

    LOOP AT is_mat_data-mlan_sales_tab INTO mat_s_mlan_sl_s.
      CLEAR bdimlankey_s.
      MOVE-CORRESPONDING mat_s_mlan_sl_s TO bdimlankey_s.
      bdimlankey_s-msgfn = mat_s_mlan_sl_s-taxkm.
      bdimlankey_s-mandt = sy-mandt.
      APPEND bdimlankey_s TO mt_mat_segment_data-t_mlankey.
    ENDLOOP.

  ENDMETHOD.                    "map_mat_segment_data


  METHOD read_mat_data_pack.
*** the range tables are filled for fetching complete data of material

    DATA :mat_id_s    TYPE range_s_matnr,
          selection_s TYPE mdg_bs_mat_s_mat_selection,
          data_s      TYPE mdg_bs_mat_s_mat_data,
          message_s   TYPE mdg_bs_mat_s_mat_msg,
          sql_err_s   TYPE scx_t100key.

    DATA:
      lr_mdg_mat       TYPE REF TO cl_mdg_bs_mat_api,
      lx_sql_exception TYPE REF TO cx_root.

    DATA:
      mat_id_t      TYPE range_t_matnr,
      mat_segment_t TYPE mdg_bs_mat_t_mat_tbnam,
      messages_t    TYPE mdg_bs_mat_t_mat_msg.

    FIELD-SYMBOLS : <relv_obj_s> TYPE mdg_bs_mat_drf_s_matnr_key.

    LOOP AT it_relevant_objects ASSIGNING <relv_obj_s> ##GEN_OK .
      mat_id_s-option = 'EQ'.
      mat_id_s-sign = 'I'.
      mat_id_s-low = <relv_obj_s>-matnr.
      INSERT mat_id_s INTO TABLE mat_id_t.
    ENDLOOP.

*=================================================
*** All segments are filled for fetching the data of these segments
    APPEND  gc_marc_segment TO mat_segment_t.
    APPEND  gc_mbew_segment TO mat_segment_t.
    APPEND  gc_mara_segment TO mat_segment_t.
    APPEND  gc_marm_segment TO mat_segment_t.
    APPEND  gc_mard_segment TO mat_segment_t.
    APPEND  gc_makt_segment TO mat_segment_t.
    APPEND  gc_mean_segment TO mat_segment_t.
***    append  GC_MVKE_SEGMENT to MAT_SEGMENT_T.
***    append  GC_MPOP_SEGMENT to MAT_SEGMENT_T.
***    append  GC_MPGD_SEGMENT to MAT_SEGMENT_T.
***    append  GC_STEUMM_SEGMENT to MAT_SEGMENT_T.
***    append  GC_STEU_SEGMENT to MAT_SEGMENT_T.
***    append  GC_MLGT_SEGMENT to MAT_SEGMENT_T.
***    append  GC_MLGN_SEGMENT to MAT_SEGMENT_T.

    CREATE OBJECT lr_mdg_mat.

** read materials in batch of 1000 material per call to avoid huge data processing at one call
    selection_s-matnr_range = mat_id_t.

*** To get complete data of materials, this method is called.
    CLEAR data_s.
    TRY.
        CALL METHOD lr_mdg_mat->read
          EXPORTING
            is_selection    = selection_s
            it_mat_segments = mat_segment_t
          IMPORTING
            es_data         = data_s
            et_message      = messages_t.

      CATCH cx_root INTO lx_sql_exception .
        CALL METHOD ms_runtime_param-bal->add_msg
          EXPORTING
            iv_msgty = 'E'
            iv_msgno = '007'
            iv_msgid = 'MDG_BS_MAT_DRF_MSG'
            iv_msgv1 = lx_sql_exception->get_longtext( ).

        sql_err_s-msgid =  'MDG_BS_MAT_DRF_MSG'.
        sql_err_s-msgno = '007'.
        sql_err_s-attr1 = lx_sql_exception->get_longtext( ).

        RAISE EXCEPTION TYPE cx_drf_process_messages
          EXPORTING
            textid   = sql_err_s
            previous = lx_sql_exception->previous.

    ENDTRY.

*** Error handling
    LOOP AT messages_t INTO message_s WHERE msgty CA 'EAX' .
      CALL METHOD ms_runtime_param-bal->add_msg
        EXPORTING
          iv_msgty = message_s-msgty
          iv_msgno = message_s-msgno
          iv_msgid = message_s-msgid
          iv_msgv1 = message_s-msgv1
          iv_msgv2 = message_s-msgv2
          iv_msgv3 = message_s-msgv3
          iv_msgv4 = message_s-msgv4.
      CLEAR message_s.
    ENDLOOP.

*** The method is called to map the segment data of material
    CALL METHOD gr_drf_mat->map_mat_segment_data
      EXPORTING
        is_mat_data = data_s.

    CALL METHOD read_text_keys
      EXPORTING
        it_matnr_range = selection_s-matnr_range   " Range Table for Data Element MATNR
        it_marc        = data_s-marc_tab
        it_mvke        = data_s-mvke_tab.

    DELETE ADJACENT DUPLICATES FROM mt_mat_segment_data-t_marakey COMPARING matnr.

  ENDMETHOD.                    "read_mat_data_pack


  METHOD read_text_keys.

    DATA:
      selection_t  TYPE TABLE OF thead,
      name_s       TYPE stxdrname,
      name_t       TYPE TABLE OF stxdrname,
      name_i_s     TYPE stextname,
      name_i_t     TYPE TABLE OF stextname,
      bdistxhkey_s TYPE bdistxhkey.

    FIELD-SYMBOLS:
      <matnr_range_s> TYPE range_s_matnr,
      <marc_s>        TYPE mdg_bs_mat_s_marc,
      <mvke_s>        TYPE mdg_bs_mat_s_mvke,
      <selection_s>   TYPE thead.

** Build the Range tables for MATNR
    LOOP AT it_matnr_range ASSIGNING <matnr_range_s> .
      name_s-sign = <matnr_range_s>-sign .
      name_s-option = <matnr_range_s>-option .
      name_s-low = <matnr_range_s>-low .
      name_s-high = <matnr_range_s>-high .
      APPEND name_s TO name_t .
    ENDLOOP.

    IF name_t[] IS NOT INITIAL.
      CLEAR selection_t.
      CALL FUNCTION 'SELECT_TEXT'
        EXPORTING
          object                  = 'MATERIAL'
        TABLES
          selections              = selection_t
          t_name                  = name_t
        EXCEPTIONS
          wrong_access_to_archive = 1
          OTHERS                  = 2.
      DATA(rc) = sy-subrc ##needed.


      LOOP AT selection_t ASSIGNING <selection_s>.
        CLEAR bdistxhkey_s.
        bdistxhkey_s-mandt = <selection_s>-mandt.
        bdistxhkey_s-tdid = <selection_s>-tdid.
        bdistxhkey_s-tdname = <selection_s>-tdname.
        bdistxhkey_s-tdobject = <selection_s>-tdobject.
        bdistxhkey_s-tdspras = <selection_s>-tdspras.
*      bdistxhkey_s-msgfn = ...
        APPEND bdistxhkey_s TO mt_mat_segment_data-t_stxhkey.
      ENDLOOP.

    ENDIF.
    " Plant Text
    CLEAR : name_t, name_s, name_i_t, name_i_s.
    LOOP AT it_marc ASSIGNING <marc_s> .
      CONCATENATE <marc_s>-matnr <marc_s>-werks INTO name_i_s SEPARATED BY space RESPECTING BLANKS.
      APPEND name_i_s TO name_i_t.
    ENDLOOP.
    IF name_i_t[] IS NOT INITIAL.
** Call function SELECT_TEXT
      CLEAR selection_t.
      CALL FUNCTION 'SELECT_TEXT'
        EXPORTING
          object                  = 'MDTXT'
          id                      = 'LTXT'
        TABLES
          selections              = selection_t
          i_name                  = name_i_t
        EXCEPTIONS
          wrong_access_to_archive = 1
          OTHERS                  = 2.

      rc = sy-subrc.

      LOOP AT selection_t ASSIGNING <selection_s>.
        CLEAR bdistxhkey_s.
        bdistxhkey_s-mandt = <selection_s>-mandt.
        bdistxhkey_s-tdid = <selection_s>-tdid.
        bdistxhkey_s-tdname = <selection_s>-tdname.
        bdistxhkey_s-tdobject = <selection_s>-tdobject.
        bdistxhkey_s-tdspras = <selection_s>-tdspras.
*      bdistxhkey_s-msgfn = ...
        APPEND bdistxhkey_s TO mt_mat_segment_data-t_stxhkey.
      ENDLOOP.

    ENDIF.

    " Sales Text
    CLEAR : name_i_t, name_i_s.
    LOOP AT it_mvke ASSIGNING <mvke_s> .
      CONCATENATE <mvke_s>-matnr <mvke_s>-vkorg <mvke_s>-vtweg INTO name_i_s RESPECTING BLANKS.
      APPEND name_i_s TO name_i_t.
    ENDLOOP.

    IF name_i_t[] IS NOT INITIAL.
      CLEAR selection_t.
      CALL FUNCTION 'SELECT_TEXT'
        EXPORTING
          object                  = 'MVKE'
        TABLES
          selections              = selection_t
          i_name                  = name_i_t
        EXCEPTIONS
          wrong_access_to_archive = 1
          OTHERS                  = 2.

      rc = sy-subrc.


      LOOP AT selection_t ASSIGNING <selection_s>.
        CLEAR bdistxhkey_s.
        bdistxhkey_s-mandt = <selection_s>-mandt.
        bdistxhkey_s-tdid = <selection_s>-tdid.
        bdistxhkey_s-tdname = <selection_s>-tdname.
        bdistxhkey_s-tdobject = <selection_s>-tdobject.
        bdistxhkey_s-tdspras = <selection_s>-tdspras.
*      bdistxhkey_s-msgfn = ...
        APPEND bdistxhkey_s TO mt_mat_segment_data-t_stxhkey.
      ENDLOOP.

    ENDIF.
  ENDMETHOD.


  METHOD send_yp1t_mat_segments.
*------------------------------------------------------------------------------------------------*
* Functional Spec: Master LAETUS interface
* Technical Spec: Master LAETUS interface
* Process: Maintain product master data
* History -----------------------------------------------------------------------------------------------*
* Date       | Change           | Contributor               | Description
*--------------------------------------------------------------------------------------------------------*
*--------------------------------------------------------------------------------------------------------*
    DATA : maktkey_s TYPE bdimaktkey.
    DATA : marckey_s TYPE bdimarckey.
    DATA : mardkey_s TYPE bdimardkey.
    DATA : mpgdkey_s TYPE bdimpgdkey.
    DATA : mpopkey_s TYPE bdimpopkey.
    DATA : marmkey_s TYPE bdimarmkey.
    DATA : meankey_s TYPE bdimeankey.
    DATA : mbewkey_s TYPE bdimbewkey.
    DATA : mlgnkey_s TYPE bdimlgnkey.
    DATA : mlgtkey_s TYPE bdimlgtkey.
    DATA : mvkekey_s TYPE bdimvkekey.
    DATA : mlankey_s TYPE bdimlankey.
    DATA : stxhkey_s TYPE bdistxhkey.
    DATA : makt_t TYPE TABLE OF bdimaktkey.
    DATA : marc_t TYPE TABLE OF bdimarckey.
    DATA : mard_t TYPE TABLE OF bdimardkey.
    DATA : mpgd_t TYPE TABLE OF bdimpgdkey.
    DATA : mpop_t TYPE TABLE OF bdimpopkey.
    DATA : marm_t TYPE TABLE OF bdimarmkey.
    DATA : mean_t TYPE TABLE OF bdimeankey.
    DATA : mbew_t TYPE TABLE OF bdimbewkey.
    DATA : mlgn_t TYPE TABLE OF bdimlgnkey.
    DATA : mlgt_t TYPE TABLE OF bdimlgtkey.
    DATA : mvke_t TYPE TABLE OF bdimvkekey.
    DATA : mlan_t TYPE TABLE OF bdimlankey.
    DATA : stxh_t TYPE TABLE OF bdistxhkey.
    DATA : hindex  LIKE sy-tabix.
    DATA : created_comm_idocs_v LIKE sy-tabix,
           idoc_control_t       TYPE t_edidc.
    DATA matnr_v TYPE matnr.
    DATA stxh_found_v TYPE abap_bool VALUE abap_false. "according to note 2695632 resp 395277

    DATA:
      mkalkey_t        TYPE  TABLE OF  bdimkalkey,
      mkalkey_s        TYPE  bdimkalkey,
      matnr_range_s    TYPE  range_s_matnr,
      matnr_range_t    TYPE  range_t_matnr,
      werks_range_s    TYPE  range_s_werks,
      werks_range_t    TYPE  range_t_werks,
      lo_mkal          TYPE REF TO cl_mdg_bs_mat_mkal_api,
      mkal_selection_s TYPE mdg_bs_mat_s_mat_mkal_select,
      mkal_t           TYPE mdg_bs_mat_t_mkal.

    CLEAR: et_idoc, ev_created_idocs.
    CLEAR: makt_t, marc_t, mard_t, marm_t,
    mean_t ,mvke_t,mlan_t, mbew_t,
    mlgn_t, mlgt_t, stxh_t, mpop_t, mpgd_t.
*MAKT : Fill table makt_t for corresponding Material
    READ TABLE is_material_data-t_maktkey WITH KEY matnr = is_marakey-matnr
    BINARY SEARCH TRANSPORTING NO FIELDS.
    IF sy-subrc EQ 0.
      hindex = sy-tabix." move SY-TABIX to HINDEX.
      LOOP AT is_material_data-t_maktkey FROM hindex INTO maktkey_s.
        IF maktkey_s-matnr NE is_marakey-matnr.
          EXIT.
        ENDIF.
        APPEND maktkey_s TO makt_t.
      ENDLOOP.
    ENDIF.

* MARC : Fill table marc_t for corresponding Material
    READ TABLE is_material_data-t_marckey WITH KEY matnr = is_marakey-matnr
    BINARY SEARCH TRANSPORTING NO FIELDS.
    IF sy-subrc EQ 0.
      hindex = sy-tabix."move SY-TABIX to HINDEX.
      LOOP AT is_material_data-t_marckey FROM hindex INTO marckey_s.
        IF marckey_s-matnr NE is_marakey-matnr.
          EXIT.
        ENDIF.
        APPEND marckey_s TO marc_t.
      ENDLOOP.
    ENDIF.

*MARD : Fill table mard_t for corresponding Material
    READ TABLE is_material_data-t_mardkey WITH KEY matnr = is_marakey-matnr
    BINARY SEARCH TRANSPORTING NO FIELDS.
    IF sy-subrc EQ 0.
      "MOVE sy-tabix TO hindex.
      hindex = sy-tabix.
      LOOP AT is_material_data-t_mardkey FROM hindex INTO mardkey_s.
        IF mardkey_s-matnr NE is_marakey-matnr.
          EXIT.
        ENDIF.
        APPEND mardkey_s TO mard_t.
      ENDLOOP.
    ENDIF.
*
*MPGD : Fill table mpgd_t for corresponding Material
    READ TABLE is_material_data-t_mpgdkey WITH KEY matnr = is_marakey-matnr
    BINARY SEARCH TRANSPORTING NO FIELDS.
    IF sy-subrc EQ 0.
      "move SY-TABIX to HINDEX.
      hindex = sy-tabix.
      LOOP AT is_material_data-t_mpgdkey FROM hindex INTO mpgdkey_s.
        IF mpgdkey_s-matnr NE is_marakey-matnr.
          EXIT.
        ENDIF.
        APPEND mpgdkey_s TO mpgd_t.
      ENDLOOP.
    ENDIF.

*MPOP : Fill table mpop_t for corresponding Material
    READ TABLE is_material_data-t_mpopkey WITH KEY matnr = is_marakey-matnr
    BINARY SEARCH TRANSPORTING NO FIELDS.
    IF sy-subrc EQ 0.
      "move SY-TABIX to HINDEX.
      hindex = sy-tabix.
      LOOP AT is_material_data-t_mpopkey FROM hindex INTO mpopkey_s.
        IF mpopkey_s-matnr NE is_marakey-matnr.
          EXIT.
        ENDIF.
        APPEND mpopkey_s TO mpop_t.
      ENDLOOP.
    ENDIF.

*MARM : Fill table marm_t for corresponding Material
    READ TABLE is_material_data-t_marmkey WITH KEY matnr = is_marakey-matnr
    BINARY SEARCH TRANSPORTING NO FIELDS.
    IF sy-subrc EQ 0.
      hindex = sy-tabix. "move SY-TABIX to HINDEX.
      LOOP AT is_material_data-t_marmkey FROM hindex INTO marmkey_s.
        IF marmkey_s-matnr NE is_marakey-matnr.
          EXIT.
        ENDIF.
        APPEND marmkey_s TO marm_t.
      ENDLOOP.
    ENDIF.

*MEAN : Fill table mean_t for corresponding Material
    READ TABLE is_material_data-t_meankey WITH KEY matnr = is_marakey-matnr
    BINARY SEARCH TRANSPORTING NO FIELDS.
    IF sy-subrc EQ 0.
      "move SY-TABIX to HINDEX.
      hindex = sy-tabix.
      LOOP AT is_material_data-t_meankey FROM hindex INTO meankey_s.
        IF meankey_s-matnr NE is_marakey-matnr.
          EXIT.
        ENDIF.
        APPEND meankey_s TO mean_t.
      ENDLOOP.
    ENDIF.

*MBEW : Fill table mbew_t for corresponding Material
    READ TABLE is_material_data-t_mbewkey WITH KEY matnr = is_marakey-matnr
    BINARY SEARCH TRANSPORTING NO FIELDS.
    IF sy-subrc EQ 0.
      "move SY-TABIX to HINDEX.
      hindex = sy-tabix.
      LOOP AT is_material_data-t_mbewkey FROM hindex INTO mbewkey_s.
        IF mbewkey_s-matnr NE is_marakey-matnr.
          EXIT.
        ENDIF.
        APPEND mbewkey_s TO mbew_t.
      ENDLOOP.
    ENDIF.

*MLGN : Fill table mlgn_t for corresponding Material
    READ TABLE is_material_data-t_mlgnkey WITH KEY matnr = is_marakey-matnr
    BINARY SEARCH TRANSPORTING NO FIELDS.
    IF sy-subrc EQ 0.
      "move SY-TABIX to HINDEX.
      hindex = sy-tabix.
      LOOP AT is_material_data-t_mlgnkey FROM hindex INTO mlgnkey_s.
        IF mlgnkey_s-matnr NE is_marakey-matnr.
          EXIT.
        ENDIF.
        APPEND mlgnkey_s TO mlgn_t.
      ENDLOOP.
    ENDIF.

*MLGT : Fill table mlgt_t for corresponding Material
    READ TABLE is_material_data-t_mlgtkey WITH KEY matnr = is_marakey-matnr
    BINARY SEARCH TRANSPORTING NO FIELDS.
    IF sy-subrc EQ 0.
      "move SY-TABIX to HINDEX.
      hindex = sy-tabix.
      LOOP AT is_material_data-t_mlgtkey FROM hindex INTO mlgtkey_s.
        IF mlgtkey_s-matnr NE is_marakey-matnr.
          EXIT.
        ENDIF.
        APPEND mlgtkey_s TO mlgt_t.
      ENDLOOP.
    ENDIF.

*MVKE : Fill table mvke_t for corresponding Material
    READ TABLE is_material_data-t_mvkekey WITH KEY matnr = is_marakey-matnr
    BINARY SEARCH TRANSPORTING NO FIELDS.
    IF sy-subrc EQ 0.
      "move SY-TABIX to HINDEX.
      hindex = sy-tabix.
      LOOP AT is_material_data-t_mvkekey FROM hindex INTO mvkekey_s.
        IF mvkekey_s-matnr NE is_marakey-matnr.
          EXIT.
        ENDIF.
        APPEND mvkekey_s TO mvke_t.
      ENDLOOP.
    ENDIF.

*MLAN : Fill table mlan_t for corresponding Material
    READ TABLE is_material_data-t_mlankey WITH KEY matnr = is_marakey-matnr
    BINARY SEARCH TRANSPORTING NO FIELDS.
    IF sy-subrc EQ 0.
      "move SY-TABIX to HINDEX.
      hindex = sy-tabix.
      LOOP AT is_material_data-t_mlankey FROM hindex INTO mlankey_s.
        IF mlankey_s-matnr NE is_marakey-matnr.
          EXIT.
        ENDIF.
        APPEND mlankey_s TO mlan_t.
      ENDLOOP.
    ENDIF.

*STXH : Fill table STXH_T for corresponding Material.
    stxh_found_v = abap_false.
    LOOP AT is_material_data-t_stxhkey INTO stxhkey_s.
      IF stxhkey_s-tdobject EQ 'MVKE'."sales Text
        IF strlen( stxhkey_s-tdname ) GT 24.
          matnr_v = stxhkey_s-tdname(40).
        ELSE.
          matnr_v = stxhkey_s-tdname(18).
        ENDIF.
      ELSEIF stxhkey_s-tdobject EQ 'MDTXT'."Plant text
        IF strlen( stxhkey_s-tdname ) GT 23.
          matnr_v = stxhkey_s-tdname(40).
        ELSE.
          matnr_v = stxhkey_s-tdname(18).
        ENDIF.
      ELSE.
        matnr_v = stxhkey_s-tdname.
      ENDIF.
      IF matnr_v NE is_marakey-matnr.
        IF stxh_found_v = abap_true.
          EXIT.
        ELSE.
          CONTINUE.
        ENDIF.
      ENDIF.
      APPEND stxhkey_s TO stxh_t.
      stxh_found_v = abap_true.
    ENDLOOP.

*Call to replicate Material.
    CLEAR : created_comm_idocs_v, matnr_range_s,
    werks_range_s, matnr_range_t, werks_range_t.

    """ Handle MKAL
    LOOP AT marc_t INTO marckey_s.
      matnr_range_s-option = 'EQ'.
      matnr_range_s-sign = 'I'.
      matnr_range_s-low = marckey_s-matnr.
      APPEND matnr_range_s TO matnr_range_t.

      werks_range_s-option = 'EQ'.
      werks_range_s-sign = 'I'.
      werks_range_s-low = marckey_s-werks.
      APPEND werks_range_s TO werks_range_t.
    ENDLOOP.

    mkal_selection_s-matnr_range = matnr_range_t.
    mkal_selection_s-werks_range = werks_range_t.

    IF mkal_selection_s IS NOT INITIAL.
      CREATE OBJECT lo_mkal.
      CALL METHOD lo_mkal->read
        EXPORTING
          is_selection = mkal_selection_s
        IMPORTING
          et_mkal      = mkal_t.
    ENDIF.

    LOOP AT mkal_t INTO DATA(mkal_s).
      MOVE-CORRESPONDING mkal_s TO mkalkey_s.
      APPEND mkalkey_s TO mkalkey_t.
    ENDLOOP.



    READ TABLE gt_mat3060 INTO DATA(mat3060_s)
          WITH KEY matnr = is_marakey-matnr  .
    rc = sy-subrc.

*    DATA(matmas_ehsphr_t_t) = gt_matmas_ehsphr_t[].
    "DELETE matmas_ehsphr_t_t WHERE matnr NE is_marakey-matnr  .

*Begin of changes, WI#, TR#D1TK9A2QN3
    DATA(crtdate) = sy-datum.
    DATA(crttime) = sy-uzeit.
    convert_timestamp( CHANGING c_date =   crtdate
                                c_time =   crttime     ).
*End of changes, WI#, TR#D1TK9A2QN3

    CALL FUNCTION 'ZV_MIA_DRF_YP1T_LTS_MM_CRE'
      EXPORTING
        marakey             = is_marakey
        rcvpfc              = ' '
        rcvprn              = is_idoc_control-rcvprn
        rcvprt              = is_idoc_control-rcvprt
        sndpfc              = ' '
        sndprn              = '          '
        sndprt              = ' '
        message_type        = iv_mesgtype
        sendconfig          = gv_sendconfig
        business_system     = is_bus_sys_tech-business_system
        credatutc           = crtdate
        cretimutc           = crttime
      IMPORTING
        created_comm_idocs  = created_comm_idocs_v
      TABLES
        maktkey             = makt_t
        marckey             = marc_t
        mardkey             = mard_t
        marmkey             = marm_t
        meankey             = mean_t
        mvkekey             = mvke_t
        mlankey             = mlan_t
        mbewkey             = mbew_t
        mlgnkey             = mlgn_t
        mlgtkey             = mlgt_t
        stxhkey             = stxh_t
        mpopkey             = mpop_t
        mpgdkey             = mpgd_t
        mkalkey             = mkalkey_t
        te_idoc_control     = idoc_control_t
        classallocations    = mat3060_s-classallocations[]
        classvaluationschar = mat3060_s-classvaluationschar[]
        classvaluationscurr = mat3060_s-classvaluationscurr[]
        classvaluationsnum  = mat3060_s-classvaluationsnum[]
        "ehsphr              = matmas_ehsphr_t_t[]
      .

    INSERT LINES OF idoc_control_t INTO TABLE et_idoc.
    ev_created_idocs = created_comm_idocs_v.

    "{
    READ TABLE idoc_control_t INTO DATA(idoc_control) INDEX 1.
    IF sy-subrc EQ 0.

      DATA key TYPE mdg_bs_mat_drf_s_matnr_key.
      DATA lr_key TYPE REF TO mdg_bs_mat_drf_s_matnr_key.
      key-matnr = is_marakey-matnr.
      GET REFERENCE OF key INTO lr_key.

      CALL METHOD ms_runtime_param-bal->add_msg_idoc
        EXPORTING
          iv_idoc_number = idoc_control-docnum
          iv_serv_impl   = ms_runtime_param-outb_impl
          ir_object      = lr_key.
    ENDIF.
    "}



  ENDMETHOD.


  METHOD send_yp1t_mes_matmas_idoc.

    DATA : created_comm_idocs_v LIKE sy-tabix,
           total_idoc_v         LIKE sy-tabix VALUE 0.

    DATA : BEGIN OF select_mestyp_s,
             mestyp TYPE edmsg-msgtyp,
             dummy  TYPE c,
           END OF select_mestyp_s.

    DATA : idoc_control_s TYPE edidc,
           idoc_control_t TYPE t_edidc
           .
    .
    DATA  object_id_v    TYPE drf_object_id.


    FIELD-SYMBOLS: <marakey_s> TYPE bdimarakey.

    READ TABLE ct_idoc_cntrl INTO idoc_control_s INDEX 1.
    DATA(rc) = sy-subrc ##needed.
    CLEAR ct_idoc_cntrl.

    CALL METHOD cl_im_mdg_bs_mat_id_value=>set_called_from_drf. "parameter is set to true to notify in ID/Value mapping that the call comes from DRFOUT


    LOOP AT is_material_data-t_marakey ASSIGNING <marakey_s> .
      object_id_v = <marakey_s>-matnr.
*      idoc_control_s-mestyp = 'P1T_MES_MATMAS'.
*      idoc_control_s-idoctp = 'P1T_MES_MATMAS01'.

      idoc_control_s-mestyp = 'P1T_LTS_MATMAS'.
      idoc_control_s-idoctp = 'ZV_MIA_YP1T_MES_MATMAS01'.



      send_yp1t_mat_segments(
      EXPORTING
        is_material_data =   is_material_data  " Structure for storing material segment keys data
        is_marakey       =    <marakey_s> " Transfer structure: MARA key fields
        is_idoc_control  =   idoc_control_s  " Control record (IDoc)
        iv_mesgtype      =   select_mestyp_s-mestyp  " Message Type
        is_bus_sys_tech  = is_bus_sys_tech
      IMPORTING
        et_idoc          = idoc_control_t
        ev_created_idocs =   created_comm_idocs_v
        ).

      APPEND LINES OF idoc_control_t TO ct_idoc_cntrl.
      total_idoc_v =  total_idoc_v + created_comm_idocs_v.

      CALL METHOD me->update_replication_data
        EXPORTING
          iv_object_id   = object_id_v
          it_idoc_result = idoc_control_t
          iv_messagetype = 'MATMAS'
        CHANGING
          ct_obj_rep_sta = ct_obj_rep_sta.




*
    ENDLOOP.
    """    endif.




    "{
**Add message for matmas
**    CALL METHOD ms_runtime_param-bal->add_msg
**      EXPORTING
**        iv_msgty = 'I'
**        iv_msgno = '000'
**        iv_msgid = 'MDG_BS_MAT_DRF_MSG'
**        iv_msgv1 = 'P1T_MES_MATMAS'
**        iv_msgv2 = total_idoc_v.

*    LOOP AT ct_idoc_cntrl INTO idoc_control_s.
*      CALL METHOD ms_runtime_param-bal->add_msg_idoc
*        EXPORTING
*          iv_idoc_number = idoc_control_s-docnum
*          iv_serv_impl   = ms_runtime_param-outb_impl.
*      CLEAR idoc_control_s.
*
*      "ir_object      =                            " Outbound Message Log
*    ENDLOOP.
    "}{

  ENDMETHOD.                    "send_matmas_idoc


  METHOD update_replication_data.

    DATA: idoc_control_s TYPE edidc.

    FIELD-SYMBOLS : <mat_obj_rep_s> TYPE drf_s_obj_rep_sta_attr.

    IF iv_messagetype = 'MATMAS'.
**Update replication parameter.
      LOOP AT it_idoc_result INTO idoc_control_s.
        READ TABLE ct_obj_rep_sta ASSIGNING <mat_obj_rep_s> WITH KEY object_id = iv_object_id.
        DATA(rc) = sy-subrc ##needed.
        <mat_obj_rep_s>-msg_link    = idoc_control_s-docnum. " msg_link_v.
      ENDLOOP.

    ENDIF.
  ENDMETHOD.
ENDCLASS.