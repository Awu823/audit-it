class /RGS/CL_P_DCB_DRF_PRODVER_OUT definition
  public
  final
  create public .

public section.

  interfaces IF_DRF_OUTBOUND .

  types:
    tt_prodnvers TYPE TABLE OF i_productionversion .
  types:
    BEGIN OF ts_data_buffer,
        matnr          TYPE  matnr,
        werks          TYPE  werks_d,
        verid          TYPE  verid,
        pv_fulldata    TYPE i_productionversion,

        recipe_message TYPE ppint_mfg_mstr_rcp_info_msg,  "TIMESTAMP_PLACEHOLDER DEVELOPER

      END OF ts_data_buffer .
  types:
    tt_data_buffer TYPE TABLE OF ts_data_buffer .
  types:
    BEGIN OF ts_output_buffer,
        matnr  TYPE  matnr,
        werks  TYPE  werks_d,
        verid  TYPE  verid,
        output TYPE ppint_mfg_prodn_vers_inf,
      END OF ts_output_buffer .
  types:
    tt_output_buffer TYPE TABLE OF ts_output_buffer .

  data MT_DATA_BUFFER type TT_DATA_BUFFER .
  data MS_OUTPUT type PPINT_MFG_PRODN_VERS_INF .
  data:
        "mt_output TYPE TABLE OF  ppint_mfg_prodn_vers_inf .
    mt_output_buffer TYPE TABLE OF ts_output_buffer .             "byPS
  class-data MS_RUNTIME_PARAM type DRF_S_RUNTIME_PARAMETER_EXT .
    "constants MC_TABLETYPE type STRING value 'COMES_T_DRF_STD_PRODN_VERS_KEY'
  constants MC_TABLETYPE type STRING value '/RGS/P_DCB_DRF_T_PRODVERS_KEY' ##NO_TEXT.
  data MO_ERROR type ref to CX_AI_SYSTEM_FAULT .
  data MO_BS_SOA_EXCEPTION type ref to CX_BS_SOA_EXCEPTION .
    "class-data MS_KEYSTR type COMES_S_DRF_STD_PRODN_VERS_KEY .
    "Recipe
  data MS_RECIPE_MESSAGE type PPINT_MFG_MSTR_RCP_INFO_MSG .
  class-data MS_KEYSTR type /RGS/P_DCB_DRF_S_PRODVERS_KEY .
  class-data MO_DRF_APPL_LOG type ref to CL_DRF_BAL .

  methods CONSTRUCTOR .
  class-methods GET_BUSINESS_HEADER
    importing
      !IS_RUNTIME_PARAM type DRF_S_RUNTIME_PARAMETER_EXT
    returning
      value(RS_HEADER) type PPINT_BUSDOC_MSG_HDR .
  class-methods CONVERT_UNIT_SAP_TO_ISO
    importing
      !IV_SAPCODE type MSEHI
    exporting
      value(RV_ISOCODE) type ISOCD_UNIT
      !IV_ISOCHECK type BOOLEAN .
  methods SEND_MESSAGE_FIN0002
    importing
      !IS_FILE_INFO type DRF_S_FILE_INFO optional
      !IV_OBJECT_COUNT type DRF_PACKAGE_SIZE optional
      !IS_BUS_SYS_TECH type MDG_S_BUS_SYS_TECH optional
    exporting
      !ET_FILE_DATA type DRF_T_FILE_OI_CONTENT
      !ET_MESSAGE type DRF_T_MESSAGE
    changing
      !CT_OBJ_REP_STA type DRF_T_OBJ_REP_STA_FULL optional
    raising
      CX_DRF_PROCESS_MESSAGES
      CX_DRF_EXCEPTION .
  methods RECIPE_READ_COMPLETE_DATA
    importing
      value(I_VERID) type VERID optional
    changing
      !CT_RELEVANT_OBJECTS type SORTED TABLE
    returning
      value(R_RECIPE_MESSAGE) type PPINT_MFG_MSTR_RCP_INFO_MSG
    raising
      CX_DRF_PROCESS_MESSAGES
      CX_DRF_EXCEPTION .
  methods RECIPE_MAP_DATA_TO_MESSAGE
    importing
      !IT_MATLASSGMT type CL_PPPI_SOA_MASTER_RECIPE=>TT_MAPL
      !IT_MAINHEADER type CL_PPPI_SOA_MASTER_RECIPE=>TT_PLKZ
      !IT_HEADER type CL_PPPI_SOA_MASTER_RECIPE=>TT_PLKO
      !IT_ACTIVITY type CL_PPPI_SOA_MASTER_RECIPE=>TT_OPR
      !IT_COMPALLOC type CL_PPPI_SOA_MASTER_RECIPE=>TT_PLMZ
      !IT_RELATIONS type CL_PPPI_SOA_MASTER_RECIPE=>TT_PLAB
    exporting
      !ES_MESSAGE type PPINT_MFG_MSTR_RCP_INFO_MSG .
  PROTECTED SECTION.

    DATA mv_auart TYPE auart .
PRIVATE SECTION.

  DATA dcb_marc_tab TYPE TABLE OF /rgs/p_s_dcb_marc .

  DATA mt_prodnversdata TYPE tt_prodnvers  ##NEEDED.
  DATA mt_relations TYPE cl_pppi_soa_master_recipe=>tt_plab .
  DATA mo_routing TYPE REF TO /rgs/cl_p_dcb_drf_prodver_out  ##NEEDED.

  CONSTANTS mc_recipe_mrctyp TYPE plnty VALUE '2' ##NO_TEXT.
  DATA mo_master_recipe TYPE REF TO cl_pppi_soa_master_recipe .
  DATA mt_activity TYPE cl_pppi_soa_master_recipe=>tt_opr .
  DATA mt_compalloc TYPE cl_pppi_soa_master_recipe=>tt_plmz .
  DATA mt_header TYPE cl_pppi_soa_master_recipe=>tt_plko .
  DATA mt_mainheader TYPE cl_pppi_soa_master_recipe=>tt_plkz .
  DATA mt_matlassgmt TYPE cl_pppi_soa_master_recipe=>tt_mapl .

  CONSTANTS mc_keystr TYPE string VALUE '/RGS/P_DCB_DRF_S_PRODVERS_KEY' ##NO_TEXT.

  CONSTANTS mc_billofoperationstype TYPE plnty VALUE '2' ##NO_TEXT.
  CONSTANTS mc_startevent TYPE ppint_boo_acty_node_type VALUE cl_ppint_soa_mfg_ord_mapping=>c_node_type_start_event ##NO_TEXT.
  CONSTANTS mc_endevent TYPE ppint_boo_acty_node_type VALUE cl_ppint_soa_mfg_ord_mapping=>c_node_type_end_event ##NO_TEXT.
  CONSTANTS mc_mimetype TYPE char25 VALUE 'text/plain' ##NO_TEXT.
  CONSTANTS mc_highdate TYPE dats VALUE '99991231' ##NO_TEXT.


  DATA mt_key_noiso TYPE cl_pppi_soa_master_recipe=>tt_noiso_key .
  DATA ms_curr_key TYPE cl_pppi_soa_master_recipe=>ty_curr_key .
  CONSTANTS mc_key_structure TYPE string VALUE 'COMES_S_DRF_MSTRRCP_KEY' ##NO_TEXT.
  DATA ex_object_cx_root TYPE REF TO cx_root .
  DATA ex_text TYPE string .
  DATA ex_text_long TYPE string .
  DATA rc TYPE sysubrc .
  DATA:
    mt_p_dcb_po_rt         TYPE TABLE OF /rgs/p_dcb_po_rt .
  DATA:
    mt_p_dcb_po_rt_no_send TYPE TABLE OF /rgs/p_dcb_po_rt .
  DATA mo_filter TYPE REF TO if_drf_filter .
  CLASS-DATA mv_keydate TYPE sy-datum .

  "]CL_PPPI_SOA_MASTER_RECIPE
  METHODS convert_material_input
    IMPORTING
      !iv_input  TYPE data
    EXPORTING
      !ev_output TYPE data .
  METHODS build_master_recipe_rel
    IMPORTING
      !iv_plnnr     TYPE plnnr
      !iv_plnal     TYPE plnal
      !it_phases    TYPE cl_pppi_soa_master_recipe=>tt_phase
      !it_relations TYPE cl_pppi_soa_master_recipe=>tt_relations
    EXPORTING
      !et_events    TYPE ppint_bill_of_operations_r_tab .
  METHODS recipe_read_key_for_object_sel
    CHANGING
      !ct_key TYPE comes_t_drf_mstrrcp_key .
  METHODS recipe_conversion_exit_alpha_o
    IMPORTING
      !iv_input  TYPE clike
    EXPORTING
      !ev_output TYPE clike .
  METHODS recipe_conversion_exit_isola_o
    IMPORTING
      !iv_input        TYPE clike
    EXPORTING
      VALUE(ev_output) TYPE clike .
  METHODS recipe_convert_unit_sap_to_iso
    IMPORTING
      !iv_sapcode       TYPE msehi
    RETURNING
      VALUE(rv_isocode) TYPE isocd_unit .
  METHODS map_current_recipe_to_vari
    IMPORTING
      !iv_matnr TYPE matnr
      !iv_werks TYPE werks_d
      !iv_plnnr TYPE plnnr
      !iv_plnal TYPE plnal .
  METHODS build_wrk_cntr_frmla_param
    IMPORTING
      !iv_crhd_par                        TYPE paramid
      !iv_tc21_par                        TYPE paramid
      !iv_crhd_werks                      TYPE werks_d
      !iv_plpo_vgwrt                      TYPE vgwrt
      !iv_plpo_vgwrteh                    TYPE vgwrteh
      !iv_plpo_lstar                      TYPE lstar
    RETURNING
      VALUE(rs_work_center_formula_param) TYPE ppint_wrk_cntr_frmla_param_str .
  METHODS recipe_convert_material_to_o
    IMPORTING
      !iv_input        TYPE data
    EXPORTING
      VALUE(ev_output) TYPE data .
  METHODS recipe_convert_unit_sap_2_iso
    IMPORTING
      !iv_sapcode       TYPE msehi
    RETURNING
      VALUE(rv_isocode) TYPE isocd_unit .
  METHODS get_relationship_type
    IMPORTING
      !iv_relshptypcode   TYPE aobky
    RETURNING
      VALUE(rv_relshptyp) TYPE char2 .
  METHODS recipe_read_standard_value_key
    IMPORTING
      !iv_vgwts      TYPE vorgschl
    RETURNING
      VALUE(rs_tc21) TYPE tc21 .
  METHODS determine_predecessors
    IMPORTING
      !is_phase_key        TYPE cl_pppi_soa_master_recipe=>ty_phase_key
      !it_rel_int          TYPE cl_pppi_soa_master_recipe=>tt_relations
      !iv_keydate          TYPE dats
      !iv_validto          TYPE dats
    CHANGING
      !ct_processed_phases TYPE cl_pppi_soa_master_recipe=>tt_proc_phs_pre .
  METHODS build_operation_control_prof
    IMPORTING
      !iv_steus              TYPE steus
    RETURNING
      VALUE(rs_control_prof) TYPE ppint_operation_control_prfl .
  METHODS get_control_key_attributes
    IMPORTING
      !iv_controlkey TYPE steus
    RETURNING
      VALUE(rs_t430) TYPE t430 .
  METHODS determine_successors
    IMPORTING
      !is_phase_key        TYPE cl_pppi_soa_master_recipe=>ty_phase_key
      !it_rel_int          TYPE cl_pppi_soa_master_recipe=>tt_relations
      !iv_keydate          TYPE dats
      !iv_validto          TYPE dats
    CHANGING
      !ct_processed_phases TYPE cl_pppi_soa_master_recipe=>tt_proc_phs_suc .
  METHODS get_parameter_text
    IMPORTING
      !iv_parid TYPE paramid
      !iv_plant TYPE werks_d
    EXPORTING
      !ev_txt   TYPE paratext
      !ev_txtlg TYPE paraltxt
      !ev_langu TYPE laiso .
  METHODS get_keydates_for_relshp
    IMPORTING
      !it_phases         TYPE cl_pppi_soa_master_recipe=>tt_phase
      !it_relations      TYPE cl_pppi_soa_master_recipe=>tt_relations
    RETURNING
      VALUE(rt_keydates) TYPE cl_pppi_soa_master_recipe=>tt_rel_keydate .
  METHODS recipe_raise_message
    IMPORTING
      !is_key TYPE comes_s_drf_mstrrcp_key .
  METHODS calculate_validity_end_date
    CHANGING
      !ct_pre TYPE cl_pppi_soa_master_recipe=>tt_proc_phs_pre
      !ct_suc TYPE cl_pppi_soa_master_recipe=>tt_proc_phs_suc .
  METHODS get_plant_language
    IMPORTING
      !iv_plant          TYPE werks_d
    RETURNING
      VALUE(rv_language) TYPE spras .
  METHODS diag
    EXPORTING
      VALUE(e_ex_text_long) TYPE string
      VALUE(e_ex_text)      TYPE string
      VALUE(e_rc)           TYPE sysubrc .
  METHODS get_filter
    RETURNING
      VALUE(ro_filter) TYPE REF TO if_drf_filter .
  METHODS convert_timestamp
    CHANGING
      !c_time TYPE uzeit
      !c_date TYPE datum .
ENDCLASS.



CLASS /RGS/CL_P_DCB_DRF_PRODVER_OUT IMPLEMENTATION.


  METHOD build_master_recipe_rel.
    CONSTANTS: lc_phase      TYPE ppint_boo_acty_node_type VALUE cl_ppint_soa_mfg_ord_mapping=>c_node_type_phase,
               lc_sucrel     TYPE c LENGTH 6 VALUE cl_ppint_soa_mfg_ord_mapping=>c_rel_type_gen_successor_soap,
               lc_startevent TYPE c LENGTH 6 VALUE cl_ppint_soa_mfg_ord_mapping=>c_suffix_start_event_node_id,
               lc_endevent   TYPE c LENGTH 6 VALUE cl_ppint_soa_mfg_ord_mapping=>c_suffix_end_event_node_id.

    DATA: ls_phase_key TYPE cl_pppi_soa_master_recipe=>ty_phase_key,
          lt_pre       TYPE cl_pppi_soa_master_recipe=>tt_proc_phs_pre,
          lt_suc       TYPE cl_pppi_soa_master_recipe=>tt_proc_phs_suc,
          ls_events    LIKE LINE OF et_events,
          lv_plnnr     TYPE plnnr,
          lv_plnal     TYPE plnal.

    lv_plnnr = |{ iv_plnnr ALPHA = IN }|.
    lv_plnal = |{ iv_plnal ALPHA = IN }|.

    DATA(lt_keydate) = get_keydates_for_relshp( EXPORTING it_phases = it_phases it_relations = it_relations ).

    "DATA: ls_keydate LIKE LINE OF lt_keydate.  "TIMESTAMP_PLACEHOLDER DEVELOPER

    CLEAR: et_events.

    LOOP AT it_phases ASSIGNING FIELD-SYMBOL(<fs_phase>)
      WHERE plnnr = iv_plnnr
      AND plnal = iv_plnal.
      CLEAR: ls_phase_key.
      MOVE-CORRESPONDING <fs_phase> TO ls_phase_key.
      "LOOP AT lt_keydate INTO ls_keydate  "TIMESTAMP_PLACEHOLDER DEVELOPER
      LOOP AT lt_keydate ASSIGNING FIELD-SYMBOL(<ls_keydate>)
      WHERE datuv BETWEEN <fs_phase>-datuv AND <fs_phase>-datub.
        determine_predecessors(
          EXPORTING
            is_phase_key        = ls_phase_key
            it_rel_int          = it_relations
            iv_keydate          = <ls_keydate>-datuv "ls_keydate-datuv "TIMESTAMP_PLACEHOLDER DEVELOPER
            iv_validto          = <fs_phase>-datub
          CHANGING
            ct_processed_phases = lt_pre ).

        determine_successors(
          EXPORTING
            is_phase_key        = ls_phase_key
            it_rel_int          = it_relations
            iv_keydate          = <ls_keydate>-datuv "ls_keydate-datuv "TIMESTAMP_PLACEHOLDER DEVELOPER
            iv_validto          = <fs_phase>-datub
          CHANGING
            ct_processed_phases = lt_suc ).
      ENDLOOP.
    ENDLOOP.

    calculate_validity_end_date(
      CHANGING
        ct_pre = lt_pre
        ct_suc = lt_suc ).

    SELECT plnnr,plnal,plnkn,MIN( datuv ) AS datuv,MAX( datub ) AS datub
      FROM @lt_pre AS itab
      WHERE 1 = 1 "20220221-2326
      GROUP BY plnnr,plnal,plnkn,datub,has_predecessor
      HAVING has_predecessor = @abap_false
      ORDER BY plnnr,plnal,plnkn,datuv
      INTO TABLE @DATA(lt_pre_final).

    rc = sy-subrc.

    SELECT plnnr,plnal,plnkn,MIN( datuv ) AS datuv,MAX( datub ) AS datub
      FROM @lt_suc AS itab
      WHERE 1 = 1 "20220221-2326
      GROUP BY plnnr,plnal,plnkn,datub,has_successor
      HAVING has_successor = @abap_false
      ORDER BY plnnr,plnal,plnkn,datuv
      INTO TABLE @DATA(lt_suc_final).
    rc = sy-subrc.

    LOOP AT lt_pre_final ASSIGNING FIELD-SYMBOL(<fs_pre>).
      CLEAR: ls_events.
      ls_events-predecessor_boonode_type = mc_startevent.
      ls_events-predecessor_boonode_id = mc_billofoperationstype && lv_plnnr && lv_plnal && lc_startevent.
      ls_events-successor_boonode_type = lc_phase.
      ls_events-successor_boonode_id = mc_billofoperationstype && <fs_pre>-plnnr && <fs_pre>-plnal && <fs_pre>-plnkn.
      ls_events-boorelationship_type = lc_sucrel.
      ls_events-validity_start_date = <fs_pre>-datuv.
      ls_events-validity_end_date = <fs_pre>-datub.
      APPEND ls_events TO et_events.
    ENDLOOP.
    UNASSIGN: <fs_pre>.

    LOOP AT lt_suc_final ASSIGNING FIELD-SYMBOL(<fs_suc>).
      CLEAR: ls_events.
      ls_events-predecessor_boonode_type = lc_phase.
      ls_events-predecessor_boonode_id = mc_billofoperationstype && <fs_suc>-plnnr && <fs_suc>-plnal && <fs_suc>-plnkn.
      ls_events-successor_boonode_type = mc_endevent.
      ls_events-successor_boonode_id = mc_billofoperationstype && lv_plnnr && lv_plnal && lc_endevent.
      ls_events-boorelationship_type = lc_sucrel.
      ls_events-validity_start_date = <fs_suc>-datuv.
      ls_events-validity_end_date = <fs_suc>-datub.
      APPEND ls_events TO et_events.
    ENDLOOP.
    UNASSIGN: <fs_suc>.
    CLEAR: lv_plnnr,lv_plnal,lt_pre,lt_suc,
           lt_pre_final,lt_suc_final,lt_keydate.
  ENDMETHOD.


  METHOD build_operation_control_prof.
    CONSTANTS: lc_cnf_milestone    TYPE ruek      VALUE '1',
               lc_cnf_required     TYPE ruek      VALUE '2',
               lc_cnf_not_possible TYPE ruek      VALUE '3',
               lc_cnf_optional     TYPE ruek      VALUE space.
    DATA: ls_completion_confirmation TYPE ppint_completion_confirmation.

    CLEAR: rs_control_prof.
    DATA(ls_t430) = get_control_key_attributes( iv_steus ).
    rs_control_prof-operation_control_key = ls_t430-steus.
    rs_control_prof-operation_is_scheduled = ls_t430-term.
    rs_control_prof-capacity_requirements_are_dtmn = ls_t430-kapa.
    rs_control_prof-gris_posted_automatic = ls_t430-autwe.
    rs_control_prof-op_is_not_mesrlvt = ls_t430-not_mes_rel.
    CASE ls_t430-ruek.
      WHEN lc_cnf_milestone.
        ls_completion_confirmation-confirmation_is_milestone_conf = abap_true.
      WHEN lc_cnf_required.
        ls_completion_confirmation-confirmation_is_required = abap_true.
      WHEN lc_cnf_not_possible.
        ls_completion_confirmation-confirmation_is_not_possible = abap_true.
      WHEN lc_cnf_optional.
        ls_completion_confirmation-confirmation_is_optional = abap_true.
      WHEN OTHERS.
        CLEAR ls_completion_confirmation.
    ENDCASE.
    ls_completion_confirmation-completion_confirmation_code = ls_t430-ruek.
    rs_control_prof-completion_confirmation = ls_completion_confirmation.

  ENDMETHOD.


  METHOD build_wrk_cntr_frmla_param.
    DATA: lv_param TYPE paramid,
          lv_txtlg TYPE paraltxt,
          lv_langu TYPE laiso.

    CLEAR rs_work_center_formula_param.
    IF iv_crhd_par IS NOT INITIAL.
      lv_param = iv_crhd_par.
    ELSEIF iv_tc21_par IS NOT INITIAL.
      lv_param = iv_tc21_par.
    ELSE.
      CLEAR lv_param.
    ENDIF.
    IF lv_param IS NOT INITIAL.
      rs_work_center_formula_param-work_center_formula_param_id = lv_param.
      get_parameter_text( EXPORTING
                            iv_parid = lv_param
                            iv_plant = iv_crhd_werks
                          IMPORTING
                            ev_txtlg = lv_txtlg
                            ev_langu = lv_langu ).
      rs_work_center_formula_param-standard_work_formula_param_na-content = lv_txtlg.
      rs_work_center_formula_param-standard_work_formula_param_na-language_code = lv_langu.
      rs_work_center_formula_param-work_center_standard_work_qty-content = iv_plpo_vgwrt.
      rs_work_center_formula_param-work_center_standard_work_qty-unit_code = recipe_convert_unit_sap_to_iso( iv_plpo_vgwrteh ).
      "TIMESTAMP_PLACEHOLDER DEVELOPER
      DATA commercial_unit(3) TYPE c.
      CALL FUNCTION 'CONVERSION_EXIT_CUNIT_OUTPUT'
        EXPORTING
          input          = iv_plpo_vgwrteh
          language       = 'E'
        IMPORTING
          output         = commercial_unit
        EXCEPTIONS
          unit_not_found = 1
          OTHERS         = 2.
      IF sy-subrc EQ 0.
        rs_work_center_formula_param-work_center_standard_work_qty-unit_code = commercial_unit.
      ENDIF.

      rs_work_center_formula_param-cost_ctr_activity_type = iv_plpo_lstar.
    ENDIF.
  ENDMETHOD.


  METHOD calculate_validity_end_date.
    "Check all Pre (Has_Pre = ' ')
    LOOP AT ct_pre ASSIGNING FIELD-SYMBOL(<fs_pre_t>)
     WHERE has_predecessor = abap_false.
      LOOP AT ct_pre ASSIGNING FIELD-SYMBOL(<fs_pre_t1>) "Check if node have a pre in future
        WHERE has_predecessor = abap_true
        AND plnkn = <fs_pre_t>-plnkn
        AND datuv >= <fs_pre_t>-datuv.                 "#EC CI_SORTSEQ.
        <fs_pre_t>-datub = <fs_pre_t1>-datuv - 1.
        EXIT.
      ENDLOOP.
    ENDLOOP.
    UNASSIGN: <fs_pre_t>,<fs_pre_t1>.

    "Check all Suc (Has_Suc = ' ')
    LOOP AT ct_suc ASSIGNING FIELD-SYMBOL(<fs_suc_t>)
      WHERE has_successor = abap_false.                "#EC CI_SORTSEQ.
      LOOP AT ct_suc ASSIGNING FIELD-SYMBOL(<fs_suc_t1>) "Check if node have a suc in future
        WHERE has_successor = abap_true
        AND plnkn = <fs_suc_t>-plnkn
        AND datuv >= <fs_suc_t>-datuv.                 "#EC CI_SORTSEQ.
        <fs_suc_t>-datub = <fs_suc_t1>-datuv - 1.
        EXIT.
      ENDLOOP.
    ENDLOOP.
    UNASSIGN: <fs_suc_t>,<fs_suc_t1>.
  ENDMETHOD.


  METHOD constructor.

  ENDMETHOD.


  METHOD convert_material_input.
    CLEAR: ev_output.

    CALL FUNCTION 'CONVERSION_EXIT_MATN1_INPUT'
      EXPORTING
        input        = iv_input
      IMPORTING
        output       = ev_output
      EXCEPTIONS
        length_error = 1
        OTHERS       = 2.

    rc = sy-subrc.

  ENDMETHOD.


  METHOD convert_timestamp.
************************************************************************
* Functional Spec: FS_REF Process Order MES interface                *
* Design Spec    : DS_REF Process Order MES interface                *
* Process        : Process Order MES interface                         *
* History -------------------------------------------------------------*
* Date       | Change      | Contributor | Description                 *
*----------------------------------------------------------------------*
* DATE_PLACEHOLDER | WI_PLACEHOLDER  | DEVELOPER     | Initial version           *
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
*
*    CALL FUNCTION 'RSIQMX_CONVERT_LOCAL_TO_UTC'
*      EXPORTING
*        time_stamp_local = time_stamp_plant
*      IMPORTING
*        time_stamp_utc   = time_stamp_utc.
*    DATA(rc) = sy-subrc.
*    CONVERT TIME STAMP time_stamp_utc TIME ZONE 'UTC' INTO DATE DATA(date1) TIME DATA(time1).

    CONVERT DATE c_date TIME c_time INTO TIME STAMP time_stamp_utc TIME ZONE 'CET'.
    rc = sy-subrc.
    CONVERT TIME STAMP time_stamp_utc TIME ZONE 'UTC' INTO DATE DATA(date1) TIME DATA(time1).

    IF rc EQ 0 AND sy-subrc EQ 0.
      c_date = date1.
      c_time = time1.
    ENDIF.
  ENDMETHOD.


  METHOD convert_unit_sap_to_iso.
    DATA: ls_cont TYPE bal_s_cont.
    CLEAR: ls_cont.
    iv_isocheck = abap_true.
    IF iv_sapcode <> space.
      TRY.
*Conversion of field unit from SAP to ISO
          cl_co_fm_access_factory=>scv0( )->unit_of_measure_sap_to_iso(
            EXPORTING
              sap_code = iv_sapcode
            IMPORTING
              iso_code = rv_isocode ).
        CATCH cx_co_fm_access INTO DATA(lo_ex) ##needed.
* To Populate sy-message fields
          MESSAGE e000(pph_prodn_vers) WITH iv_sapcode ms_keystr-matnr ms_keystr-werks ms_keystr-verid INTO DATA(lv_dummy) ##needed.

          ls_cont-tabname = mc_keystr.

          CONCATENATE  ms_keystr-matnr ms_keystr-werks ms_keystr-verid
            INTO ls_cont-value RESPECTING BLANKS.
*Log message to DRF Application LOG
          mo_drf_appl_log = ms_runtime_param-bal.
          TRY.
              CALL METHOD mo_drf_appl_log->add_msg
                EXPORTING
                  iv_msgty   = sy-msgty                " Message Category
                  iv_msgno   = sy-msgno                " Message Number
                  iv_msgid   = sy-msgid                " Message Identification
                  iv_msgv1   = sy-msgv1               " Message Variable
                  iv_msgv2   = sy-msgv2               " Message Variable
                  iv_msgv3   = sy-msgv3                " Message Variable
                  iv_msgv4   = sy-msgv4             " Message Variable
                  is_context = ls_cont.
              iv_isocheck = abap_false.

            CATCH cx_root INTO DATA(ex_object_cx_root_2).
              DATA(ex_text_stat_2) = ex_object_cx_root_2->get_text( ) ##needed.


          ENDTRY.

        CATCH cx_root INTO DATA(ex_object_cx_root).
          DATA(ex_text_stat) = ex_object_cx_root->get_text( ) ##needed.


      ENDTRY.
    ENDIF.
  ENDMETHOD.


  METHOD determine_predecessors.
    "Finish-Start   = 1
    "Start-Start    = 2
    "Finish-Finish  = 3
    "Start-Finish   = 4

    DATA: "ls_phase_key  TYPE cl_pppi_soa_master_recipe=>ty_phase_key,
      ls_proc_phs   TYPE cl_pppi_soa_master_recipe=>ty_processed_phases_pre,
      lv_pre_exists TYPE abap_bool.

    CLEAR: lv_pre_exists.

    MOVE-CORRESPONDING is_phase_key TO ls_proc_phs.

    "Check finish-start relations for predecessor
    LOOP AT it_rel_int ASSIGNING FIELD-SYMBOL(<fs_rel>)
      WHERE plnal_nch = is_phase_key-plnal
      AND plnkn_nch = is_phase_key-plnkn
      AND aobky = '1'
      AND datuv <= iv_keydate
      AND datub >= iv_keydate.
      "Predecessor found -> leave
      ls_proc_phs-has_predecessor = abap_true.
      ls_proc_phs-datuv = <fs_rel>-datuv.
      ls_proc_phs-datub = <fs_rel>-datub.
      ls_proc_phs-knnrn = <fs_rel>-plnkn_vor.
      INSERT ls_proc_phs INTO TABLE ct_processed_phases.
      lv_pre_exists = abap_true.
    ENDLOOP.
    UNASSIGN: <fs_rel>.

    "Check start-finish relations for predecessor
    LOOP AT it_rel_int ASSIGNING <fs_rel>
      WHERE plnnr_vor = is_phase_key-plnnr
      AND plnal_vor = is_phase_key-plnal
      AND plnkn_vor = is_phase_key-plnkn
      AND aobky = '4'
      AND datuv <= iv_keydate
      AND datub >= iv_keydate.
      "Predecessor found -> leave
      ls_proc_phs-has_predecessor = abap_true.
      ls_proc_phs-datuv = <fs_rel>-datuv.
      ls_proc_phs-datub = <fs_rel>-datub.
      ls_proc_phs-knnrn = <fs_rel>-plnkn_nch.
      INSERT ls_proc_phs INTO TABLE ct_processed_phases.
      lv_pre_exists = abap_true.
    ENDLOOP.
    UNASSIGN: <fs_rel>.

    "Check start-start relations for predecessor
    LOOP AT it_rel_int ASSIGNING <fs_rel>
      WHERE plnnr_nch = is_phase_key-plnnr
      AND plnal_nch = is_phase_key-plnal
      AND plnkn_nch = is_phase_key-plnkn
      AND aobky = '2'
      AND datuv <= iv_keydate
      AND datub >= iv_keydate.
      ls_proc_phs-has_predecessor = abap_true.
      ls_proc_phs-datuv = <fs_rel>-datuv.
      ls_proc_phs-datub = <fs_rel>-datub.
      ls_proc_phs-knnrn = <fs_rel>-plnkn_vor.
      INSERT ls_proc_phs INTO TABLE ct_processed_phases.
      lv_pre_exists = abap_true.
    ENDLOOP.
    IF lv_pre_exists IS INITIAL.
      ls_proc_phs-has_predecessor = abap_false.
      ls_proc_phs-datuv = iv_keydate.
      ls_proc_phs-datub = iv_validto.
      INSERT ls_proc_phs INTO TABLE ct_processed_phases.
    ENDIF.


*-------------------------------------Working----------------------------------------------------
*    LOOP AT it_rel_int ASSIGNING FIELD-SYMBOL(<fs_rel>)
*      WHERE plnnr_nch = is_phase_key-plnnr
*      AND plnal_nch = is_phase_key-plnal
*      AND plnkn_nch = is_phase_key-plnkn
*      AND aobky = '2'. "Start-Start
*      IF iv_start_start_interchanged = abap_false.
*        ls_phase_key-plnnr = <fs_rel>-plnnr_vor.
*        ls_phase_key-plnal = <fs_rel>-plnal_vor.
*        ls_phase_key-plnkn = <fs_rel>-plnkn_vor.
*
*        search_predecessors(
*          EXPORTING
*            is_phase_key                = ls_phase_key
*            it_rel_int                  = it_rel_int
*            iv_start_start_interchanged = abap_false
*            CHANGING
*              ct_start_phases           = ct_start_phases ).
*        READ TABLE ct_start_phases TRANSPORTING NO FIELDS
*          WITH KEY plnnr = ls_phase_key-plnnr
*                   plnal = ls_phase_key-plnal
*                   plnkn = ls_phase_key-plnkn.
*        IF sy-subrc IS INITIAL.
*          READ TABLE ct_start_phases TRANSPORTING NO FIELDS
*            WITH KEY plnnr = is_phase_key-plnnr
*                     plnal = is_phase_key-plnal
*                     plnkn = is_phase_key-plnkn.
*          IF NOT sy-subrc IS INITIAL.
*            APPEND INITIAL LINE TO ct_start_phases ASSIGNING FIELD-SYMBOL(<fs_sp>).
*            MOVE-CORRESPONDING is_phase_key TO <fs_sp>.
*          ENDIF.
*        ENDIF.
*      ELSE.
*        APPEND INITIAL LINE TO ct_start_phases ASSIGNING <fs_sp>.
*        MOVE-CORRESPONDING is_phase_key TO <fs_sp>.
*      ENDIF.
*    ENDLOOP.
*    UNASSIGN: <fs_rel>,<fs_sp>.
*
*    IF NOT sy-subrc IS INITIAL.
*      LOOP AT it_rel_int ASSIGNING <fs_rel>
*        WHERE plnnr_vor = is_phase_key-plnnr
*        AND plnal_vor = is_phase_key-plnal
*        AND plnkn_vor = is_phase_key-plnkn
*        AND aobky = '2'.
*        CLEAR: ls_phase_key.
*        ls_phase_key-plnnr = <fs_rel>-plnnr_nch.
*        ls_phase_key-plnal = <fs_rel>-plnal_nch.
*        ls_phase_key-plnkn = <fs_rel>-plnkn_nch.
*        search_predecessors(
*          EXPORTING
*            is_phase_key                = ls_phase_key
*            it_rel_int                  = it_rel_int
*            iv_start_start_interchanged = abap_true
*            CHANGING
*              ct_start_phases           = ct_start_phases ).
*        READ TABLE ct_start_phases TRANSPORTING NO FIELDS
*          WITH KEY plnnr = ls_phase_key-plnnr
*                   plnal = ls_phase_key-plnal
*                   plnkn = ls_phase_key-plnkn.
*        IF sy-subrc IS INITIAL.
*          READ TABLE ct_start_phases TRANSPORTING NO FIELDS
*            WITH KEY plnnr = is_phase_key-plnnr
*                     plnal = is_phase_key-plnal
*                     plnkn = is_phase_key-plnkn.
*          IF NOT sy-subrc IS INITIAL.
*            APPEND INITIAL LINE TO ct_start_phases ASSIGNING <fs_sp>.
*            MOVE-CORRESPONDING is_phase_key TO <fs_sp>.
*          ENDIF.
*        ENDIF.
*      ENDLOOP.
*      IF NOT sy-subrc IS INITIAL.
*        APPEND INITIAL LINE TO ct_start_phases ASSIGNING <fs_sp>.
*        MOVE-CORRESPONDING is_phase_key TO <fs_sp>.
*      ENDIF.
*    ENDIF.
  ENDMETHOD.


  METHOD determine_successors.
    "Finish-Start   = 1
    "Start-Start    = 2
    "Finish-Finish  = 3
    "Start-Finish   = 4

    DATA: "ls_phase_key  TYPE cl_pppi_soa_master_recipe=>ty_phase_key,
      ls_proc_phs   TYPE cl_pppi_soa_master_recipe=>ty_processed_phases_suc,
      lv_suc_exists TYPE abap_bool.

    CLEAR: lv_suc_exists.

    MOVE-CORRESPONDING is_phase_key TO ls_proc_phs.

    "Check start-finish relations for successor
    LOOP AT it_rel_int ASSIGNING FIELD-SYMBOL(<fs_rel>)
      WHERE plnnr_nch = is_phase_key-plnnr
      AND plnal_nch = is_phase_key-plnal
      AND plnkn_nch = is_phase_key-plnkn
      AND aobky = '4'
      AND datuv <= iv_keydate
      AND datub >= iv_keydate.
      ls_proc_phs-has_successor = abap_true.
      ls_proc_phs-datuv = <fs_rel>-datuv.
      ls_proc_phs-datub = <fs_rel>-datub.
      ls_proc_phs-knnrn = <fs_rel>-plnkn_vor.
      INSERT ls_proc_phs INTO TABLE ct_processed_phases.
      lv_suc_exists = abap_true.
    ENDLOOP.
    UNASSIGN: <fs_rel>.

    "Check finish-start relations for successor
    LOOP AT it_rel_int ASSIGNING <fs_rel>
     WHERE plnnr_vor = is_phase_key-plnnr
     AND plnal_vor = is_phase_key-plnal
     AND plnkn_vor = is_phase_key-plnkn
      AND aobky = '1'
      AND datuv <= iv_keydate
      AND datub >= iv_keydate.
      ls_proc_phs-has_successor = abap_true.
      ls_proc_phs-datuv = <fs_rel>-datuv.
      ls_proc_phs-datub = <fs_rel>-datub.
      ls_proc_phs-knnrn = <fs_rel>-plnkn_nch.
      INSERT ls_proc_phs INTO TABLE ct_processed_phases.
      lv_suc_exists = abap_true.
    ENDLOOP.
    UNASSIGN: <fs_rel>.

    "Check finish-finish relations for successor
    LOOP AT it_rel_int ASSIGNING <fs_rel>
      WHERE plnnr_vor = is_phase_key-plnnr
      AND plnal_vor = is_phase_key-plnal
      AND plnkn_vor = is_phase_key-plnkn
      AND aobky = '3'
      AND datuv <= iv_keydate
      AND datub >= iv_keydate.
      ls_proc_phs-has_successor = abap_true.
      ls_proc_phs-datuv = <fs_rel>-datuv.
      ls_proc_phs-datub = <fs_rel>-datub.
      ls_proc_phs-knnrn = <fs_rel>-plnkn_nch.
      INSERT ls_proc_phs INTO TABLE ct_processed_phases.
      lv_suc_exists = abap_true.
    ENDLOOP.
    IF lv_suc_exists IS INITIAL.
      ls_proc_phs-has_successor = abap_false.
      ls_proc_phs-datuv = iv_keydate.
      ls_proc_phs-datub = iv_validto.
      INSERT ls_proc_phs INTO TABLE ct_processed_phases.
    ENDIF.


*---------------------------Working-----------------------------------------------
*    LOOP AT it_rel_int ASSIGNING FIELD-SYMBOL(<fs_rel>)
*      WHERE plnnr_vor = is_phase_key-plnnr
*      AND plnal_vor = is_phase_key-plnal
*      AND plnkn_vor = is_phase_key-plnkn
*      AND aobky = '3'. "Finish-Finish
*      IF iv_finish_finish_interchanged = abap_false.
*        ls_phase_key-plnnr = <fs_rel>-plnnr_nch.
*        ls_phase_key-plnal = <fs_rel>-plnal_nch.
*        ls_phase_key-plnkn = <fs_rel>-plnkn_nch.
*
*        search_successors(
*          EXPORTING
*            is_phase_key                  = ls_phase_key
*            it_rel_int                    = it_rel_int
*            iv_finish_finish_interchanged = abap_false
*            CHANGING
*              ct_end_phases               = ct_end_phases ).
*        READ TABLE ct_end_phases TRANSPORTING NO FIELDS
*          WITH KEY plnnr = ls_phase_key-plnnr
*                   plnal = ls_phase_key-plnal
*                   plnkn = ls_phase_key-plnkn.
*        IF sy-subrc IS INITIAL.
*          READ TABLE ct_end_phases TRANSPORTING NO FIELDS
*            WITH KEY plnnr = is_phase_key-plnnr
*                     plnal = is_phase_key-plnal
*                     plnkn = is_phase_key-plnkn.
*          IF NOT sy-subrc IS INITIAL.
*            APPEND INITIAL LINE TO ct_end_phases ASSIGNING FIELD-SYMBOL(<fs_sp>).
*            MOVE-CORRESPONDING is_phase_key TO <fs_sp>.
*          ENDIF.
*        ENDIF.
*      ELSE.
*        APPEND INITIAL LINE TO ct_end_phases ASSIGNING <fs_sp>.
*        MOVE-CORRESPONDING is_phase_key TO <fs_sp>.
*      ENDIF.
*    ENDLOOP.
*    UNASSIGN: <fs_rel>,<fs_sp>.
*
*    IF NOT sy-subrc IS INITIAL.
*      IF iv_finish_finish_interchanged = abap_false.
*        LOOP AT it_rel_int ASSIGNING <fs_rel>
*          WHERE plnnr_nch = is_phase_key-plnnr
*          AND plnal_nch = is_phase_key-plnal
*          AND plnkn_nch = is_phase_key-plnkn
*          AND aobky = '3'.
*          CLEAR: ls_phase_key.
*          ls_phase_key-plnnr = <fs_rel>-plnnr_nch.
*          ls_phase_key-plnal = <fs_rel>-plnal_nch.
*          ls_phase_key-plnkn = <fs_rel>-plnkn_nch.
*          search_successors(
*            EXPORTING
*              is_phase_key                  = ls_phase_key
*              it_rel_int                    = it_rel_int
*              iv_finish_finish_interchanged = abap_true
*              CHANGING
*                ct_end_phases               = ct_end_phases ).
*          READ TABLE ct_end_phases TRANSPORTING NO FIELDS
*            WITH KEY plnnr = ls_phase_key-plnnr
*                     plnal = ls_phase_key-plnal
*                     plnkn = ls_phase_key-plnkn.
*          IF sy-subrc IS INITIAL.
*            READ TABLE ct_end_phases TRANSPORTING NO FIELDS
*              WITH KEY plnnr = is_phase_key-plnnr
*                       plnal = is_phase_key-plnal
*                       plnkn = is_phase_key-plnkn.
*            IF NOT sy-subrc IS INITIAL.
*              APPEND INITIAL LINE TO ct_end_phases ASSIGNING <fs_sp>.
*              MOVE-CORRESPONDING is_phase_key TO <fs_sp>.
*            ENDIF.
*          ENDIF.
*        ENDLOOP.
*        IF NOT sy-subrc IS INITIAL.
*          APPEND INITIAL LINE TO ct_end_phases ASSIGNING <fs_sp>.
*          MOVE-CORRESPONDING is_phase_key TO <fs_sp>.
*        ENDIF.
*      ELSE.
*        APPEND INITIAL LINE TO ct_end_phases ASSIGNING <fs_sp>.
*        MOVE-CORRESPONDING is_phase_key TO <fs_sp>.
*      ENDIF.
*    ENDIF.
  ENDMETHOD.


  METHOD diag.
    e_ex_text_long = ex_text_long.
    e_ex_text = ex_text.
    e_rc = rc.
  ENDMETHOD.


  METHOD get_business_header.
    DATA: lv_guid_32   TYPE guid_32,
          lv_timestamp TYPE timestamp,
          tz           TYPE ttzz-tzone,
          lv_date      LIKE sy-datum,
          lv_time      LIKE sy-uzeit.

    TRY.
        lv_guid_32 = cl_system_uuid=>create_uuid_c32_static( ).
        TEST-SEAM error1.
        END-TEST-SEAM.
      CATCH cx_uuid_error.
        CLEAR lv_guid_32.
    ENDTRY.

    rs_header-id-content = lv_guid_32.
    rs_header-uuid-content = lv_guid_32.

    TRY.
        cl_abap_tstmp=>systemtstmp_syst2utc(
          EXPORTING
            syst_date = sy-datum
            syst_time = sy-uzeit
          IMPORTING
            utc_tstmp = lv_timestamp
        ).
        TEST-SEAM error2.
        END-TEST-SEAM.
      CATCH cx_parameter_invalid_range INTO DATA(ex_parameter_invalid_range).
        DATA(ex_text_stat) = ex_parameter_invalid_range->get_text( ) ##needed.
    ENDTRY.

    CONVERT TIME STAMP lv_timestamp TIME ZONE tz INTO DATE lv_date TIME lv_time.

    TRY.
        cl_bs_soa_convert_xsddatetime=>map_xsddatetime_long_z_out(
              EXPORTING
                iv_date = lv_date
                iv_time = lv_time
              IMPORTING
                ev_xsd_datetime = rs_header-creation_date_time
        ).
        TEST-SEAM error3.
        END-TEST-SEAM.
      CATCH cx_bs_soa_exception.
        CLEAR rs_header-creation_date_time.
    ENDTRY.

    CALL FUNCTION 'LCR_GET_OWN_BUSINESS_SYSTEM'
      IMPORTING
        bs_key_name            = rs_header-sender_business_system_id
      EXCEPTIONS
        no_business_system     = 1
        no_rfc_destination     = 2
        no_landscape_directory = 3
        illegal_arguments      = 4
        communication_error    = 5
        ld_error               = 6
        OTHERS                 = 7 ##FM_SUBRC_OK.
    DATA(rc_local) = sy-subrc ##needed.

    rs_header-recipient_business_system_id = is_runtime_param-business_system.



  ENDMETHOD.


  METHOD get_control_key_attributes.
    DATA: ls_tca01 TYPE tca01.
    CLEAR rs_t430.

    TRY.
        cl_co_fm_access_factory=>cota( )->co_ta_tca01_read(
          EXPORTING
            plnty  = mc_billofoperationstype
          IMPORTING
            struct = ls_tca01 ).
      CATCH cx_co_fm_access.
        ls_tca01-plnaw = '*'.
    ENDTRY.

    TRY.
        cl_co_fm_access_factory=>cota( )->co_ta_t430_read(
          EXPORTING
            plnaw  = ls_tca01-plnaw
            steus  = iv_controlkey
          IMPORTING
            struct = rs_t430 ).
      CATCH cx_co_fm_access  INTO DATA(ex_co_fm_access).
        ex_text = ex_co_fm_access->get_text( ).##no_handler.

    ENDTRY.
  ENDMETHOD.


  METHOD get_filter.
    IF mo_filter IS NOT BOUND.
      mo_filter = NEW /rgs/cl_p_dcb_drf_prodver_fltr( ).
    ENDIF.

    ro_filter = mo_filter.
  ENDMETHOD.


  METHOD get_keydates_for_relshp.
    DATA: ls_keydate  LIKE LINE OF rt_keydates,
          ls_keydate1 LIKE LINE OF rt_keydates.
    LOOP AT it_phases INTO DATA(ls_phase).
      CLEAR: ls_keydate.
      ls_keydate-plnkn = ls_phase-plnkn.
      IF ls_phase-datuv > mv_keydate.
        ls_keydate-datuv = ls_phase-datuv - 1.
        APPEND ls_keydate TO rt_keydates.
        ls_keydate-datuv = ls_phase-datuv.
        APPEND ls_keydate TO rt_keydates.
      ELSE.
        ls_keydate-datuv = mv_keydate.
        APPEND ls_keydate TO rt_keydates.
      ENDIF.
      IF ls_phase-datub NE mc_highdate.
        ls_keydate-datuv = ls_phase-datub + 1.
        APPEND ls_keydate TO rt_keydates.
      ENDIF.
    ENDLOOP.
    LOOP AT it_relations INTO DATA(ls_relation).
      CLEAR: ls_keydate,ls_keydate1.
      ls_keydate-plnkn = ls_relation-plnkn_vor.
      ls_keydate1-plnkn = ls_relation-plnkn_nch.
      IF ls_relation-datuv > mv_keydate.
        ls_keydate-datuv = ls_relation-datuv - 1.
        ls_keydate1-datuv = ls_relation-datuv - 1.
        APPEND: ls_keydate TO rt_keydates,
                ls_keydate1 TO rt_keydates.
        ls_keydate-datuv = ls_relation-datuv.
        ls_keydate1-datuv = ls_relation-datuv.
        APPEND: ls_keydate TO rt_keydates,
                ls_keydate1 TO rt_keydates.
      ELSE.
        ls_keydate-datuv = mv_keydate.
        ls_keydate1-datuv = mv_keydate.
        APPEND: ls_keydate TO rt_keydates,
                ls_keydate1 TO rt_keydates.
      ENDIF.
      IF ls_relation-datub NE mc_highdate.
        ls_keydate-datuv = ls_relation-datub + 1.
        ls_keydate1-datuv = ls_relation-datub + 1.
        APPEND: ls_keydate TO rt_keydates,
                ls_keydate1 TO rt_keydates.
      ENDIF.
    ENDLOOP.
    SORT: rt_keydates ASCENDING BY datuv.
    DELETE ADJACENT DUPLICATES FROM: rt_keydates COMPARING datuv.
    DELETE: rt_keydates WHERE datuv < mv_keydate.
  ENDMETHOD.


  METHOD get_parameter_text.

    DATA: ls_tc20t   TYPE tc20t,
          lv_no_text TYPE abap_bool.

    "Determine plant language
    DATA(lv_langu) = get_plant_language( iv_plant ).
    IF lv_langu IS INITIAL.
      "No language maintained for plant => Take logon language of user
      lv_langu = sy-langu.
    ENDIF.

    TRY.
        cl_co_fm_access_factory=>ceta( )->ceta_tc20_read(
          EXPORTING
            parid     = iv_parid
            spras     = lv_langu
          IMPORTING
            no_text   = lv_no_text
            tc20t_exp = ls_tc20t ).
      CATCH cx_co_fm_access.
        CLEAR: ev_langu,
               ev_txt,
               ev_txtlg.
        RETURN.
    ENDTRY.

    IF lv_no_text = abap_true.
      "Now try to read a text in English
      lv_langu = 'E'.
      TRY.
          cl_co_fm_access_factory=>ceta( )->ceta_tc20_read(
            EXPORTING
              parid     = iv_parid
              spras     = lv_langu
            IMPORTING
              no_text   = lv_no_text
              tc20t_exp = ls_tc20t ).
        CATCH cx_co_fm_access.
          CLEAR: ev_langu,
                 ev_txt,
                 ev_txtlg.
          RETURN.
      ENDTRY.
    ENDIF.

    IF lv_no_text = abap_false.
      "Text was found
      recipe_conversion_exit_isola_o( EXPORTING iv_input  = lv_langu
                                    IMPORTING ev_output = ev_langu ).
      ev_txt   = ls_tc20t-txt.
      ev_txtlg = ls_tc20t-txtlg.
    ELSE.
      "No text found
      CLEAR: ev_langu,
             ev_txt,
             ev_txtlg.
    ENDIF.
  ENDMETHOD.


  METHOD get_plant_language.
    DATA: ls_t001wwa TYPE t001w.

    TRY.
        cl_co_fm_access_factory=>cota( )->co_ta_t001w_read(
          EXPORTING
            t001w_werk = iv_plant
          IMPORTING
            t001wwa    = ls_t001wwa ).
        rv_language = ls_t001wwa-spras.
      CATCH cx_co_fm_access ##no_handler.
        CLEAR rv_language.
    ENDTRY.
  ENDMETHOD.


  METHOD get_relationship_type.
    CASE iv_relshptypcode.
      WHEN 1.
        rv_relshptyp = cl_ppint_soa_mfg_ord_mapping=>c_rel_type_finish_start_soap.
      WHEN 2.
        rv_relshptyp = cl_ppint_soa_mfg_ord_mapping=>c_rel_type_start_start_soap.
      WHEN 3.
        rv_relshptyp = cl_ppint_soa_mfg_ord_mapping=>c_rel_type_finish_finish_soap.
      WHEN 4.
        rv_relshptyp = cl_ppint_soa_mfg_ord_mapping=>c_rel_type_start_finish_soap.
      when OTHERS.
        rc = 12.

    ENDCASE.
  ENDMETHOD.


  METHOD if_drf_outbound~analyze_changes_by_chg_pointer.
*--------------------------------------------------------------------------------------------------------------*
* Functional Spec: DS_REF BOM PV MES interface
* Technical Spec:  DS_REF BOM PV MES interface
* Process:         Make- 4.3.2.2  Manage and Release order
*                  S4H Outbound BOM and PV MES
* History -----------------------------------------------------------------------------------------------------*
* Date       | Change     | Contributor                | Description
*--------------------------------------------------------------------------------------------------------------*
* DATE_PLACEHOLDER | WI_PLACEHOLDER |  DEVELOPER             | Initial version
* DATE_PLACEHOLDER | WI_PLACEHOLDER |  DEVELOPER             | PV interface filters not working  properly
* DATE_PLACEHOLDER | WI_PLACEHOLDER |  DEVELOPER             | TICKET_PLACEHOLDER: PO change pointers enhanc
* DATE_PLACEHOLDER | WI_PLACEHOLDER |  DEVELOPER             | TICKET_PLACEHOLDER:Rout IF to MES_PV filter
* DATE_PLACEHOLDER | WI_PLACEHOLDER | DEVELOPER              | TICKET_PLACEHOLDER PV change pointer comp del
*--------------------------------------------------------------------------------------------------------------*



    DATA key TYPE /rgs/p_dcb_drf_s_prodvers_key.
    DATA key_tab TYPE TABLE OF /rgs/p_dcb_drf_s_prodvers_key.

    DATA: lv_matnr TYPE string.

    DATA tabname_prev TYPE tabname.

    DATA  msgno TYPE symsgno.

    DATA change_pointer_t TYPE   drf_t_bdcp.


    TYPES: BEGIN OF  ty_mkal_tabkey_suffix,
             werks TYPE werks_d,
             verid TYPE verid,
           END OF ty_mkal_tabkey_suffix.



    DATA cp_date TYPE datum.

    DATA(business_system)  =  ms_runtime_param-business_system.
    DATA(ir_application_log) = ms_runtime_param-bal.

    SELECT  werks,   auart,   phseq, business_system   ,no_send
    FROM /rgs/p_dcb_po_rt INTO TABLE @DATA(p_dcb_po_rt) ##needed
          WHERE business_system = @business_system
          AND no_send NE 'X'.

    rc = sy-subrc.


    change_pointer_t[] = it_change_pointer[].

    SORT change_pointer_t ASCENDING BY cdobjcl cdobjid tabname tabkey cretime.
    DELETE ADJACENT DUPLICATES FROM: change_pointer_t COMPARING cdobjcl cdobjid tabname tabkey.

    SORT change_pointer_t ASCENDING BY cdobjcl tabname tabkey  usrname cdobjid cretime .

    ir_application_log->increase_msg_level( EXPORTING iv_description =  |{ `Change pointers analysis for `  && business_system }| ).
    LOOP AT change_pointer_t ASSIGNING FIELD-SYMBOL(<bdcp>).


      IF tabname_prev IS INITIAL
      OR  tabname_prev NE <bdcp>-tabname.

        IF tabname_prev IS NOT INITIAL.
          ir_application_log->decrease_msg_level( ).
        ENDIF.
        ir_application_log->increase_msg_level( EXPORTING iv_description = |{  `Analysis of `  && <bdcp>-tabname }| ).
      ENDIF.

      cp_date = <bdcp>-cretime(8).

      IF <bdcp>-tabname NE 'AEOI' .
        ir_application_log->add_msg( iv_msgid = '/RGS/P_DCB_PRODVER'
        iv_msgty = if_drf_const=>msg_type_info
        iv_msgno = '011'  "Change Pointer &1  &2 &3 &4 &5
        iv_msgv1 = |{  cp_date && ` `   && <bdcp>-usrname }|
        iv_msgv2 = <bdcp>-tabname
        iv_msgv3 = <bdcp>-tabkey
        iv_msgv4 = <bdcp>-cdchgno
        ).
      ENDIF.


      CASE <bdcp>-cdobjcl.
**************************************************************************************************
        WHEN  'MATERIAL'.
          IF <bdcp>-tabname EQ 'DMKAL' .

            "DATA l_mkal TYPE mkal.
            DATA mkal_tabkey_suffix TYPE ty_mkal_tabkey_suffix.

            TRY.
                cl_abap_container_utilities=>read_container_c(
                EXPORTING
                  im_container           = <bdcp>-tabkey
                IMPORTING
                  "ex_value               = l_mkal
                  ex_value               =  mkal_tabkey_suffix
                 EXCEPTIONS illegal_parameter_type = 1 OTHERS = 2 ).
                rc = sy-subrc.
              CATCH cx_root INTO ex_object_cx_root.
                ex_text = ex_object_cx_root->get_text( ) .
                ex_text_long = ex_object_cx_root->get_longtext( ) .
            ENDTRY.


            key-matnr = <bdcp>-cdobjid.
            key-werks = mkal_tabkey_suffix-werks. "<bdcp>-tabkey(4).
            key-verid = mkal_tabkey_suffix-verid.  "<bdcp>-tabkey+4(4).

            "TIMESTAMP_PLACEHOLDER DEVELOPER APPEND key TO key_tab.

            GET REFERENCE OF key INTO DATA(lr_key_dmkal) .
            lv_matnr = |{ key-matnr  ALPHA = OUT }|.

            "   IF lv_matnr(1) NE '0'.          "no DIA "TIMESTAMP_PLACEHOLDER DEVELOPER
            APPEND key TO key_tab.
            ir_application_log->add_msg( iv_msgid = '/RGS/P_DCB_PRODVER'
            iv_msgty = if_drf_const=>msg_type_info
            iv_msgv1 = |{  lv_matnr   }|
            iv_msgv2 = |{ key-werks }|
            iv_msgv3 = |{ key-verid }|
            ir_object =  lr_key_dmkal
            iv_msgno = '018' )."Adding PV &3 of material &1 plant &2 to analysis for &4
            " ENDIF. "TIMESTAMP_PLACEHOLDER DEVELOPER


          ENDIF.

**************************************************************************************************
        WHEN  'PLAN'. "Recipe

          CASE <bdcp>-tabname.
            WHEN 'MAPL'.
              DATA l_mapl TYPE mapl.
              TRY.
                  cl_abap_container_utilities=>read_container_c(
                  EXPORTING
                    im_container           = <bdcp>-tabkey
                  IMPORTING
                    ex_value               = l_mapl
                 EXCEPTIONS illegal_parameter_type = 1 OTHERS = 2 ).
                  rc = sy-subrc.
                CATCH cx_root INTO ex_object_cx_root.
                  ex_text = ex_object_cx_root->get_text( ) .
                  ex_text_long = ex_object_cx_root->get_longtext( ) .
              ENDTRY.


              SELECT SINGLE matnr , werks , plnty , plnnr , plnal , zkriz , zaehl , datuv , techv , aennr , loekz
                FROM mapl                "TIMESTAMP_PLACEHOLDER DEVELOPER
                "FROM  /RGS/P_S_DCB_MAPL   "TIMESTAMP_PLACEHOLDER DEVELOPER
                INTO  @DATA(mapl4mapl)

                    WHERE
                    matnr EQ @l_mapl-matnr
                    AND werks EQ @l_mapl-werks
                    AND plnty EQ @l_mapl-plnty
                    AND plnnr EQ @l_mapl-plnnr
                    AND plnal EQ @l_mapl-plnal
                    AND zkriz EQ @l_mapl-zkriz
                    AND zaehl EQ @l_mapl-zaehl


                    .
              rc = sy-subrc.
              "MAPL PLPO
              IF rc EQ 0 AND mapl4mapl IS NOT INITIAL.
                SELECT matnr,  werks,  verid , plnty , plnnr , alnal FROM mkal
                "APPENDING CORRESPONDING FIELDS OF TABLE @data(key_tab_plpo)
                INTO TABLE @DATA(key_tab_plpo4mapl)
                      WHERE
                      matnr = @mapl4mapl-matnr
                      AND  werks = @mapl4mapl-werks
                      AND  plnty = @mapl4mapl-plnty
                      AND  plnnr = @mapl4mapl-plnnr
                      AND alnal =   @mapl4mapl-plnal  "TIMESTAMP_PLACEHOLDER DEVELOPER

                      .
                rc = sy-subrc.

              ENDIF.

              IF rc EQ 0.
                ir_application_log->increase_msg_level( EXPORTING iv_description = 'MAPL analysis for '  && <bdcp>-tabname && ` change` ).

                SORT key_tab_plpo4mapl BY  werks matnr verid. "#EC CI_SORTLOOP
                DELETE ADJACENT DUPLICATES FROM key_tab_plpo4mapl COMPARING  werks matnr verid.

                LOOP AT key_tab_plpo4mapl ASSIGNING FIELD-SYMBOL(<key_plpo4mapl>).

                  MOVE-CORRESPONDING <key_plpo4mapl> TO key.
                  "TIMESTAMP_PLACEHOLDER DEVELOPER APPEND key TO key_tab.

                  GET REFERENCE OF key INTO DATA(lr_key_plpo4mapl) .
                  lv_matnr = |{ <key_plpo4mapl>-matnr  ALPHA = OUT }|.
                  CLEAR key.

                  "IF lv_matnr(1) NE '0'.          "no DIA "TIMESTAMP_PLACEHOLDER DEVELOPER

                  ir_application_log->add_msg( iv_msgid = '/RGS/P_DCB_PRODVER'
                  iv_msgty = if_drf_const=>msg_type_info
                  iv_msgv1 = |{  lv_matnr   }|
                  iv_msgv2 = |{ <key_plpo4mapl>-werks }|
                  iv_msgv3 = |{ <key_plpo4mapl>-verid }|

                  iv_msgv4 = |{ ` recipe `  && <key_plpo4mapl>-plnty && `  `  && <key_plpo4mapl>-plnnr }|
                  ir_object =  lr_key_plpo4mapl
                  iv_msgno = '023' )."Adding PV &3 of material &1 plant &2 to analysis for &4


                  MOVE-CORRESPONDING <key_plpo4mapl> TO key.
                  APPEND key TO key_tab.
                  "ENDIF. "no DIA "TIMESTAMP_PLACEHOLDER DEVELOPER
                ENDLOOP.
                ir_application_log->decrease_msg_level( ).
              ENDIF.



              "ToDo
**************************************************************************************************
            WHEN 'PLMZ'.  "ToDo  - test
              DATA l_plmz TYPE plmz.
              TRY.
                  cl_abap_container_utilities=>read_container_c(
                  EXPORTING
                    im_container           = <bdcp>-tabkey
                  IMPORTING
                    ex_value               = l_plmz
                   EXCEPTIONS illegal_parameter_type = 1 OTHERS = 2 ).
                  rc = sy-subrc.

                CATCH cx_root INTO ex_object_cx_root.
                  ex_text = ex_object_cx_root->get_text( ) .
                  ex_text_long = ex_object_cx_root->get_longtext( ) .
              ENDTRY.

              SELECT SINGLE plnty, plnnr, zuonr, zaehl, datuv, techv, aennr, loekz, parkz, plnal, plnfl, plnkn, stlty, stlnr, stlal
              FROM plmz              "TIMESTAMP_PLACEHOLDER DEVELOPER
              "FROM  /RGS/P_S_DCB_PLMZ "TIMESTAMP_PLACEHOLDER DEVELOPER
              INTO @DATA(ls_plmz)
                    WHERE
                    plnty EQ @l_plmz-plnty
                    AND plnnr EQ @l_plmz-plnnr
                    AND zuonr EQ @l_plmz-zuonr
                    AND zaehl EQ @l_plmz-zaehl
                    .
              IF sy-subrc EQ 0.
                SELECT matnr , werks , plnty , plnnr , plnal , zkriz , zaehl , datuv , techv , aennr , loekz
                FROM mapl                "TIMESTAMP_PLACEHOLDER DEVELOPER
                "FROM  /rgs/p_s_dcb_mapl   "TIMESTAMP_PLACEHOLDER DEVELOPER
                  INTO TABLE @DATA(mapl4plmz_tab)

                      WHERE "matnr = l_matnr
                      " AND werks = l_werks  "to do - Curent Werks for Business system !!!!
                      plnty = @ls_plmz-plnty
                      AND plnnr = @ls_plmz-plnnr
                      AND plnal = @ls_plmz-plnal
                      "   AND loekz NE 'X'.
                      .
                rc = sy-subrc.
              ENDIF.

              "MKAL PLMZ
              IF rc EQ 0 AND mapl4plmz_tab[] IS NOT INITIAL.
                SELECT matnr,  werks,  verid , plnty , plnnr , alnal FROM mkal
                "APPENDING CORRESPONDING FIELDS OF TABLE @data(key_tab_plpo)
                INTO TABLE @DATA(key_tab_plmz)
                      FOR ALL ENTRIES IN @mapl4plmz_tab
                      WHERE
                      matnr = @mapl4plmz_tab-matnr
                      AND  werks = @mapl4plmz_tab-werks
                      AND  plnty = @mapl4plmz_tab-plnty
                      AND  plnnr = @mapl4plmz_tab-plnnr
                      AND alnal =  @mapl4plmz_tab-plnal  "TIMESTAMP_PLACEHOLDER DEVELOPER

                      .
                rc = sy-subrc.

                ir_application_log->increase_msg_level( EXPORTING iv_description = 'PLMZ analysis for ' && <bdcp>-tabname && ` change` ).

                SORT key_tab_plmz BY  werks matnr verid. "#EC CI_SORTLOOP
                DELETE ADJACENT DUPLICATES FROM key_tab_plmz COMPARING  werks matnr verid.

                LOOP AT key_tab_plmz  ASSIGNING FIELD-SYMBOL(<key_plmz>).

                  MOVE-CORRESPONDING <key_plmz> TO key.
                  "TIMESTAMP_PLACEHOLDER DEVELOPER APPEND key TO key_tab.

                  GET REFERENCE OF key INTO DATA(lr_key_plmz) .
                  lv_matnr = |{ <key_plmz>-matnr  ALPHA = OUT }|.
                  "IF lv_matnr(1) NE '0'.          "no DIA "TIMESTAMP_PLACEHOLDER DEVELOPER

                  ir_application_log->add_msg( iv_msgid = '/RGS/P_DCB_PRODVER'
                  iv_msgty = if_drf_const=>msg_type_info
                  iv_msgv1 = |{  lv_matnr   }|
                  iv_msgv2 = |{ <key_plmz>-werks }|
                  iv_msgv3 = |{ <key_plmz>-verid }|

                  iv_msgv4 = |{ ` recipe `  && <key_plmz>-plnty && `  `  && <key_plmz>-plnnr }|
                  ir_object =  lr_key_plmz
                  iv_msgno = '024' )."Adding PV &3 of material &1 plant &2 to analysis for &4



                  APPEND key TO key_tab.
                  "ENDIF.   "TIMESTAMP_PLACEHOLDER DEVELOPER


                ENDLOOP.
                ir_application_log->decrease_msg_level( ).

              ENDIF.





              " MOVE-CORRESPONDING l_plmz TO plko_key.
              "APPEND plko_key TO plko_key_tab.


**************************************************************************************************
            WHEN 'PLPO'.
              DATA l_plpo_tabkey TYPE plpo.
              TRY.
                  cl_abap_container_utilities=>read_container_c(
                  EXPORTING
                    im_container           = <bdcp>-tabkey
                  IMPORTING
                    ex_value               = l_plpo_tabkey
                EXCEPTIONS illegal_parameter_type = 1 OTHERS = 2 ).
                  rc = sy-subrc.
                CATCH cx_root INTO ex_object_cx_root.
                  ex_text = ex_object_cx_root->get_text( ) .
                  ex_text_long = ex_object_cx_root->get_longtext( ) .
              ENDTRY.

              SELECT plnty , plnnr , plnkn , zaehl, aedat, aennr  , aenam , vornr , objty  , werks , ktsch ,  ltxa1
              FROM plpo INTO TABLE @DATA(plpo_tab)
                    WHERE plnty = @l_plpo_tabkey-plnty
                    AND plnnr = @l_plpo_tabkey-plnnr
                    AND plnkn = @l_plpo_tabkey-plnkn

                    AND loekz NE 'X'

                    .
              rc = sy-subrc.

              SORT  plpo_tab  BY plnty plnnr plnkn.    "#EC CI_SORTLOOP
              DELETE ADJACENT DUPLICATES FROM plpo_tab  COMPARING plnty plnnr plnkn.


              IF rc EQ 0 AND plpo_tab[] IS NOT INITIAL.
                SELECT  plnty , plnnr , plnal , plnfl , plnkn , zaehl , datuv , techv , aennr ", werks
                FROM plas INTO TABLE @DATA(plas_tab)
                      FOR ALL ENTRIES IN @plpo_tab
                      WHERE plnty = @plpo_tab-plnty
                      AND plnnr = @plpo_tab-plnnr  "group
                      AND plnkn = @plpo_tab-plnkn  "node
                      AND loekz NE 'X'
                      .
                rc = sy-subrc.
              ENDIF.

              IF rc EQ 0 AND plas_tab[] IS NOT INITIAL.
                SORT plas_tab BY plnty plnnr plnal.    "#EC CI_SORTLOOP
                DELETE ADJACENT DUPLICATES FROM plas_tab COMPARING plnty plnnr plnal.


                SELECT plnty , plnnr , plnal , zaehl , datuv , techv , aennr , loekz , parkz , andat , annam , aedat , aenam ,
                verwe , werks
                FROM plko INTO TABLE @DATA(plko_tab)
                      FOR ALL ENTRIES IN @plas_tab
                      WHERE plnty = @plas_tab-plnty
                      AND plnnr = @plas_tab-plnnr
                      AND plnal = @plas_tab-plnal
                      "AND ( andat EQ @cp_date  OR aedat EQ @cp_date )

                      AND loekz NE 'X'
                      "AND werks EQ @plas_tab-werks
                      " AND aennr = @l_plpo-aennr  ""is it??  To Check
                      .
                rc = sy-subrc.
              ENDIF.

              LOOP AT plko_tab ASSIGNING FIELD-SYMBOL(<plko>).
                ir_application_log->add_msg( iv_msgid = '/RGS/P_DCB_PRODVER'
                iv_msgty = if_drf_const=>msg_type_info
                "IR_OBJECT =  LR_ORDER
                iv_msgno = '014'  "Recipe Group &1 Recipe &2 changed for plant &3
                iv_msgv1 = <plko>-plnnr
                iv_msgv2 = <plko>-plnal
                iv_msgv3 = <plko>-werks
                iv_msgv4 = 'PLKO' ).
              ENDLOOP.

              "MAPL
              IF rc EQ 0 AND plko_tab[] IS NOT INITIAL.
                SELECT matnr , werks , plnty , plnnr , plnal , zkriz , zaehl , datuv , techv , aennr , loekz
                FROM mapl INTO TABLE @DATA(mapl_tab)
                      FOR ALL ENTRIES IN @plko_tab "#EC CI_FAE_LINES_ENSURED
                      WHERE "matnr = l_matnr
                      " AND werks = l_werks  "to do - Curent Werks for Business system !!!!
                      plnty = @plko_tab-plnty
                      AND plnnr = @plko_tab-plnnr
                      AND plnal = @plko_tab-plnal
                      AND loekz NE 'X'
                      AND werks EQ @plko_tab-werks
                      .
                rc = sy-subrc.
              ENDIF.

              "MKAL PLPO
              IF rc EQ 0 AND mapl_tab[] IS NOT INITIAL.
                SELECT matnr,  werks,  verid , plnty , plnnr , alnal FROM mkal
                "APPENDING CORRESPONDING FIELDS OF TABLE @data(key_tab_plpo)
                INTO TABLE @DATA(key_tab_plpo)
                      FOR ALL ENTRIES IN @mapl_tab
                      WHERE
                      matnr = @mapl_tab-matnr
                      AND  werks = @mapl_tab-werks
                      AND  plnty = @mapl_tab-plnty
                      AND  plnnr = @mapl_tab-plnnr
                      AND alnal =  @mapl_tab-plnal  "TIMESTAMP_PLACEHOLDER DEVELOPER

                      .
                rc = sy-subrc.

                ir_application_log->increase_msg_level( EXPORTING iv_description = 'PLPO analysis for ' && <bdcp>-tabname && ` change` ).

                SORT key_tab_plpo BY  werks matnr verid. "#EC CI_SORTLOOP
                DELETE ADJACENT DUPLICATES FROM key_tab_plpo COMPARING  werks matnr verid.

                LOOP AT key_tab_plpo ASSIGNING FIELD-SYMBOL(<key_plpo>).

                  MOVE-CORRESPONDING <key_plpo> TO key.
                  "TIMESTAMP_PLACEHOLDER DEVELOPER APPEND key TO key_tab.

                  GET REFERENCE OF key INTO DATA(lr_key_plpo) .
                  lv_matnr = |{ <key_plpo>-matnr  ALPHA = OUT }|.

                  ir_application_log->add_msg( iv_msgid = '/RGS/P_DCB_PRODVER'
                  iv_msgty = if_drf_const=>msg_type_info
                  iv_msgv1 = |{  lv_matnr   }|
                  iv_msgv2 = |{ <key_plpo>-werks }|
                  iv_msgv3 = |{ <key_plpo>-verid }|

                  iv_msgv4 = |{ ` recipe `  && <key_plpo>-plnty && `  `  && <key_plpo>-plnnr }|
                  ir_object =  lr_key_plpo
                  iv_msgno = '022' )."Adding PV &3 of material &1 plant &2 to analysis for &4

                  CLEAR key.
                  "IF <key_plpo>-plnty EQ '2'."TIMESTAMP_PLACEHOLDER DEVELOPER TICKET_PLACEHOLDER
                  MOVE-CORRESPONDING <key_plpo> TO key.
                  APPEND key TO key_tab.  "TIMESTAMP_PLACEHOLDER DEVELOPER TICKET_PLACEHOLDER
                  "ENDIF.


                ENDLOOP.
                ir_application_log->decrease_msg_level( ).







              ENDIF.
              "alnal = @plko_key-plnal

              "TIMESTAMP_PLACEHOLDER DEVELOPER{
            WHEN 'PLKZ'.
              DATA l_plkz_tabkey TYPE plkz.
              TRY.
                  cl_abap_container_utilities=>read_container_c(
                  EXPORTING
                    im_container           = <bdcp>-tabkey
                  IMPORTING
                    ex_value               = l_plkz_tabkey
                  EXCEPTIONS illegal_parameter_type = 1 OTHERS = 2 ).
                  rc = sy-subrc.
                CATCH cx_root INTO ex_object_cx_root.
                  ex_text = ex_object_cx_root->get_text( ) .
                  ex_text_long = ex_object_cx_root->get_longtext( ) .
              ENDTRY.

              SELECT plnty , plnnr , plnal
              FROM plkz INTO TABLE @DATA(plkz_tab)
                    WHERE plnty = @l_plkz_tabkey-plnty
                    AND plnnr = @l_plkz_tabkey-plnnr
                    AND plnal = @l_plkz_tabkey-plnal
                    .
              rc = sy-subrc.

              SORT  plkz_tab  BY plnty plnnr plnal.    "#EC CI_SORTLOOP
              DELETE ADJACENT DUPLICATES FROM plkz_tab  COMPARING plnty plnnr plnal.


              IF rc EQ 0 AND plkz_tab[] IS NOT INITIAL.
                SELECT  plnty , plnnr , plnal , plnfl , plnkn , zaehl , datuv , techv , aennr ", werks
                FROM plas INTO TABLE @DATA(plas4plkz_tab)
                      FOR ALL ENTRIES IN @plkz_tab
                      WHERE plnty = @plkz_tab-plnty
                      AND plnnr = @plkz_tab-plnnr  "group
                      AND plnal = @plkz_tab-plnal  "node
                      AND loekz NE 'X'
                      .
                rc = sy-subrc.
              ENDIF.

              IF rc EQ 0 AND plas4plkz_tab[] IS NOT INITIAL.
                SORT plas4plkz_tab BY plnty plnnr plnal. "#EC CI_SORTLOOP
                DELETE ADJACENT DUPLICATES FROM plas4plkz_tab COMPARING plnty plnnr plnal.


                SELECT plnty , plnnr , plnal , zaehl , datuv , techv , aennr , loekz , parkz , andat , annam , aedat , aenam ,
                verwe , werks
                FROM plko INTO TABLE @DATA(plko4plkz_tab)
                      FOR ALL ENTRIES IN @plas4plkz_tab
                      WHERE plnty = @plas4plkz_tab-plnty
                      AND plnnr = @plas4plkz_tab-plnnr
                      AND plnal = @plas4plkz_tab-plnal
                      "AND ( andat EQ @cp_date  OR aedat EQ @cp_date )

                      AND loekz NE 'X'
                      "AND werks EQ @plas4plkz_tab-werks
                      " AND aennr = @l_PLKZ-aennr  ""is it??  To Check
                      .
                rc = sy-subrc.
              ENDIF.

              LOOP AT plko4plkz_tab ASSIGNING FIELD-SYMBOL(<plko4plkz>).
                ir_application_log->add_msg( iv_msgid = '/RGS/P_DCB_PRODVER'
                iv_msgty = if_drf_const=>msg_type_info
                "IR_OBJECT =  LR_ORDER
                iv_msgno = '014'  "Recipe Group &1 Recipe &2 changed for plant &3
                iv_msgv1 = <plko4plkz>-plnnr
                iv_msgv2 = <plko4plkz>-plnal
                iv_msgv3 = <plko4plkz>-werks
                iv_msgv4 = 'PLKZ' ).
              ENDLOOP.

              "MAPL
              IF rc EQ 0 AND plko4plkz_tab[] IS NOT INITIAL.
                SELECT matnr , werks , plnty , plnnr , plnal , zkriz , zaehl , datuv , techv , aennr , loekz
                FROM mapl INTO TABLE @DATA(mapl4plkz_tab)
                      FOR ALL ENTRIES IN @plko4plkz_tab "#EC CI_FAE_LINES_ENSURED
                      WHERE "matnr = l_matnr
                      " AND werks = l_werks  "to do - Curent Werks for Business system !!!!
                      plnty = @plko4plkz_tab-plnty
                      AND plnnr = @plko4plkz_tab-plnnr
                      AND plnal = @plko4plkz_tab-plnal
                      AND loekz NE 'X'
                      AND werks EQ @plko4plkz_tab-werks
                      .
                rc = sy-subrc.
              ENDIF.

              "MKAL PLKZ
              IF rc EQ 0 AND mapl4plkz_tab[] IS NOT INITIAL.
                SELECT matnr,  werks,  verid , plnty , plnnr , alnal FROM mkal
                "APPENDING CORRESPONDING FIELDS OF TABLE @data(key_tab_PLKZ)
                INTO TABLE @DATA(key_tab_plkz)
                      FOR ALL ENTRIES IN @mapl4plkz_tab
                      WHERE
                      matnr = @mapl4plkz_tab-matnr
                      AND  werks = @mapl4plkz_tab-werks
                      AND  plnty = @mapl4plkz_tab-plnty
                      AND  plnnr = @mapl4plkz_tab-plnnr
                      AND alnal =  @mapl4plkz_tab-plnal  "TIMESTAMP_PLACEHOLDER DEVELOPER

                      .
                rc = sy-subrc.

                ir_application_log->increase_msg_level( EXPORTING iv_description = 'PLKZ analysis for ' && <bdcp>-tabname && ` change` ).

                SORT key_tab_plkz BY  werks matnr verid. "#EC CI_SORTLOOP
                DELETE ADJACENT DUPLICATES FROM key_tab_plkz COMPARING  werks matnr verid.

                LOOP AT key_tab_plkz ASSIGNING FIELD-SYMBOL(<key_plkz>).

                  MOVE-CORRESPONDING <key_plkz> TO key.
                  "TIMESTAMP_PLACEHOLDER DEVELOPER APPEND key TO key_tab.

                  GET REFERENCE OF key INTO DATA(lr_key_plkz) .
                  lv_matnr = |{ <key_plkz>-matnr  ALPHA = OUT }|.

                  "IF lv_matnr(1) NE '0'. "TIMESTAMP_PLACEHOLDER DEVELOPER
                  ir_application_log->add_msg( iv_msgid = '/RGS/P_DCB_PRODVER'
                  iv_msgty = if_drf_const=>msg_type_info
                  iv_msgv1 = |{  lv_matnr   }|
                  iv_msgv2 = |{ <key_plkz>-werks }|
                  iv_msgv3 = |{ <key_plkz>-verid }|

                  iv_msgv4 = |{ ` recipe `  && <key_plkz>-plnty && `  `  && <key_plkz>-plnnr }|
                  ir_object =  lr_key_plkz
                  iv_msgno = '022' )."Adding PV &3 of material &1 plant &2 to analysis for &4

                  "no DIA "TIMESTAMP_PLACEHOLDER DEVELOPER


                  MOVE-CORRESPONDING <key_plkz> TO key.
                  APPEND key TO key_tab.
                  "ENDIF.  "TIMESTAMP_PLACEHOLDER DEVELOPER


                ENDLOOP.
                ir_application_log->decrease_msg_level( ).

              ENDIF.

              "}TIMESTAMP_PLACEHOLDER DEVELOPER




**************************************************************************************************

**              "APPEND plko_key TO plko_key_tab.
**
**              "PL
****          TASK List TYPE  2 2 PLNTY
****          GROUP 50000037  50000037  PLNNR
****          TASK List Node  00000383  00000383  PLNKN
****          Counter 00000383  00000383  ZAEHL
**
**
            WHEN OTHERS.
              ex_text = |{  <bdcp>-tabname && <bdcp>-cdobjcl }|.
          ENDCASE.
**************************************************************************************************


**************************************************************************************************
        WHEN  'STUE_V'.

          CASE <bdcp>-tabname.
            WHEN 'CSBOM'.
              DATA l_csbom_tabkey TYPE csbom.
              TRY.
                  cl_abap_container_utilities=>read_container_c(
                  EXPORTING
                    im_container           = <bdcp>-tabkey
                  IMPORTING
                    ex_value               = l_csbom_tabkey
                  EXCEPTIONS illegal_parameter_type = 1 OTHERS = 2 ).
                  rc = sy-subrc.
                CATCH cx_root INTO ex_object_cx_root.
                  ex_text = ex_object_cx_root->get_text( ) .
                  ex_text_long = ex_object_cx_root->get_longtext( ) .
              ENDTRY.
              "MOVE-CORRESPONDING l_stko TO stko_key.
              "APPEND stko_key TO stko_key_tab.

              SELECT matnr , werks , losbs , andat , annam , aedat , aenam ,  stlnr , stlal , stlan
              FROM mast
              INTO TABLE @DATA(mast4csbom_tab)
                    WHERE
                    "werks = @l_stko_tabkey-werks
                    "stlty = @l_stko_tabkey-stlty
                    stlan = 1 "production
                    AND stlnr = @l_csbom_tabkey-stlnr

                    .
              rc = sy-subrc.
              DATA(csbom_aennr) = <bdcp>-cdobjid+24(12).
              msgno = '025'. "csbom
            WHEN OTHERS.
              ex_text = |{  <bdcp>-tabname && <bdcp>-cdobjcl }|.
          ENDCASE.

          IF rc EQ 0 AND mast4csbom_tab[] IS NOT INITIAL.
            SELECT matnr,  werks,  verid
              FROM mkal
              INTO TABLE @DATA(key_tab_csbom_0) "
                  "APPENDING CORRESPONDING FIELDS OF TABLE @key_tab
                  FOR ALL ENTRIES IN @mast4csbom_tab
                  WHERE
                  matnr = @mast4csbom_tab-matnr
                  AND  werks = @mast4csbom_tab-werks
                  AND  stlal = @mast4csbom_tab-stlal
                  AND  stlan = 1

                  "AND  plnty = @mast4csbom_tab-plnty
                  "AND  plnnr = @mapl_tab-plnnr.
                  .
            rc = sy-subrc.
          ENDIF.

          SORT key_tab_csbom_0 BY matnr werks verid.   "#EC CI_SORTLOOP
          DELETE ADJACENT DUPLICATES FROM key_tab_csbom_0 COMPARING matnr werks verid.


          IF rc EQ 0 AND key_tab_csbom_0[] IS NOT INITIAL.
            SELECT matnr,  werks,  verid , aennr
            FROM mkal_aend
            INTO TABLE @DATA(key_tab_csbom)
              FOR ALL ENTRIES IN @key_tab_csbom_0
                    WHERE
                  matnr EQ  @key_tab_csbom_0-matnr
                  AND werks EQ  @key_tab_csbom_0-werks
                  AND verid EQ  @key_tab_csbom_0-verid
                  AND aennr EQ @csbom_aennr.

            rc = sy-subrc.
          ENDIF.

          SORT key_tab_csbom BY matnr werks verid aennr  . "#EC CI_SORTLOOP
          DELETE ADJACENT DUPLICATES FROM key_tab_csbom COMPARING matnr werks verid aennr.

          ir_application_log->increase_msg_level( EXPORTING iv_description = `CSBOM analysis for ` && <bdcp>-tabname && ` change no ` && csbom_aennr ).
          LOOP AT key_tab_csbom ASSIGNING FIELD-SYMBOL(<key_csbom>).


            GET REFERENCE OF <key_csbom> INTO DATA(lr_key_csbom) .
            lv_matnr = |{ <key_csbom>-matnr  ALPHA = OUT }|.

            CLEAR key.
            "IF lv_matnr(1) NE '0'.   "TIMESTAMP_PLACEHOLDER DEVELOPER

            ir_application_log->add_msg( iv_msgid = '/RGS/P_DCB_PRODVER'
            iv_msgty = if_drf_const=>msg_type_info
            iv_msgv1 = |{ ` Material ` &&   lv_matnr   }|
            iv_msgv2 = |{ ` PV `  && <key_csbom>-verid }|
            ir_object =  lr_key_csbom
            iv_msgno = '026' )."Analysis of &4 change).

            "no DIA "TIMESTAMP_PLACEHOLDER DEVELOPER
            MOVE-CORRESPONDING <key_csbom> TO key.
            APPEND key TO key_tab.
            "ENDIF.  "TIMESTAMP_PLACEHOLDER DEVELOPER

          ENDLOOP.
          ir_application_log->decrease_msg_level( ).
          CLEAR: mast4csbom_tab[].


        WHEN 'STUE' .

          CASE <bdcp>-tabname.

            WHEN 'STKO'.
              DATA l_stko_tabkey TYPE stko.
              TRY.
                  cl_abap_container_utilities=>read_container_c(
                  EXPORTING
                    im_container           = <bdcp>-tabkey
                  IMPORTING
                    ex_value               = l_stko_tabkey
                  EXCEPTIONS illegal_parameter_type = 1 OTHERS = 2 ).
                  rc = sy-subrc.
                CATCH cx_root INTO ex_object_cx_root.
                  ex_text = ex_object_cx_root->get_text( ) .
                  ex_text_long = ex_object_cx_root->get_longtext( ) .
              ENDTRY.
              "MOVE-CORRESPONDING l_stko TO stko_key.
              "APPEND stko_key TO stko_key_tab.

              SELECT matnr , werks , losbs , andat , annam , aedat , aenam ,  stlnr , stlal , stlan
              FROM mast
              "INTO CORRESPONDING FIELDS OF TABLE @mast_tab
                 INTO TABLE @DATA(mast_tab)
              WHERE
              "werks = @l_stko_tabkey-werks
              "stlty = @l_stko_tabkey-stlty
              stlan = 1 "production
              AND stlnr = @l_stko_tabkey-stlnr
              AND stlal = @l_stko_tabkey-stlal
              "AND werks EQ @l_stko_tabkey-werks
              .
              rc = sy-subrc.

              msgno = '015'. "STKO

              "} STKO

            WHEN 'STPO' OR 'STAS'.


              IF <bdcp>-tabname EQ 'STPO'.

                DATA l_stpo TYPE stpo.
                TRY.
                    cl_abap_container_utilities=>read_container_c(
                    EXPORTING
                      im_container           = <bdcp>-tabkey
                    IMPORTING
                      ex_value               = l_stpo
                   EXCEPTIONS illegal_parameter_type = 1 OTHERS = 2 ).
                    rc = sy-subrc.
                  CATCH cx_root INTO ex_object_cx_root.
                    ex_text = ex_object_cx_root->get_text( ) .
                    ex_text_long = ex_object_cx_root->get_longtext( ) .
                ENDTRY.

**            MOVE-CORRESPONDING l_stpo TO stko_key.
**            APPEND stko_key TO stko_key_tab.

                SELECT  stlty, stlnr, stlal, stlkn, stasz, datuv , aennr FROM stas
                WHERE stlty = @l_stpo-stlty
                AND stlnr = @l_stpo-stlnr
                AND stlkn = @l_stpo-stlkn  "TIMESTAMP_PLACEHOLDER DEVELOPER
                "TIMESTAMP_PLACEHOLDER DEVELOPER WI_PLACEHOLDER: TICKET_PLACEHOLDER PV change pointer comp del
                "TIMESTAMP_PLACEHOLDER DEVELOPER AND lkenz IS INITIAL
                INTO TABLE @DATA(stas_tab)
                      .

                rc = sy-subrc.
                msgno = '016'. "STPO
              ENDIF.

              IF <bdcp>-tabname EQ 'STAS'.  "TIMESTAMP_PLACEHOLDER DEVELOPER

                DATA l_stas TYPE stas.
                TRY.
                    cl_abap_container_utilities=>read_container_c(
                    EXPORTING
                      im_container           = <bdcp>-tabkey
                    IMPORTING
                      ex_value               = l_stas
                    EXCEPTIONS illegal_parameter_type = 1 OTHERS = 2 ).
                    rc = sy-subrc.
                  CATCH cx_root INTO ex_object_cx_root.
                    ex_text = ex_object_cx_root->get_text( ) .
                    ex_text_long = ex_object_cx_root->get_longtext( ) .
                ENDTRY.

**            MOVE-CORRESPONDING l_stpo TO stko_key.
**            APPEND stko_key TO stko_key_tab.

                SELECT  stlty, stlnr, stlal, stlkn, stasz, datuv , aennr FROM stas
                WHERE stlty = @l_stas-stlty
                AND stlal = @l_stas-stlal
                AND stlnr = @l_stas-stlnr
                AND stlkn = @l_stas-stlkn  "TIMESTAMP_PLACEHOLDER DEVELOPER
                AND stasz = @l_stas-stasz
                "TIMESTAMP_PLACEHOLDER DEVELOPER TICKET_PLACEHOLDER PV change pointer comp del
                "TIMESTAMP_PLACEHOLDER DEVELOPER AND lkenz IS INITIAL
                INTO TABLE @stas_tab
                .

                rc = sy-subrc.
                msgno = '013'. "STAS
              ENDIF.  "TIMESTAMP_PLACEHOLDER DEVELOPER




              IF rc EQ 0 AND stas_tab[] IS NOT INITIAL.

                SELECT stlty , stlnr , stlal , stkoz " ,werks
                FROM stko
                FOR ALL ENTRIES IN @stas_tab
                WHERE stlty = @stas_tab-stlty
                AND stlnr = @stas_tab-stlnr
                AND stlal = @stas_tab-stlal   "alterative
                "AND stkoz = @stas_tab-stkoz
                "AND datuv = @stas_tab-datuv
                "AND techv = @stas_tab-techv
                "AND aennr = @stas_tab-aennr
                AND lkenz IS INITIAL
                AND loekz IS INITIAL
                INTO TABLE @DATA(stko4stpo_tab)
                      .
                rc = sy-subrc.

              ENDIF.

              IF rc EQ 0 AND stko4stpo_tab[] IS NOT INITIAL.

                SELECT matnr , werks , losbs , andat , annam , aedat , aenam ,  stlnr , stlal
                FROM mast
                INTO CORRESPONDING FIELDS OF TABLE @mast_tab
                FOR ALL ENTRIES IN @stko4stpo_tab
                WHERE
                "werks = @l_stko_tabkey-werks
                "stlty = @l_stko_tabkey-stlty
                stlan = 1 "production
                AND stlnr = @stko4stpo_tab-stlnr
                AND stlal = @stko4stpo_tab-stlal
                " AND werks EQ @stko4stpo_tab-werks
                .
                rc = sy-subrc.
                " msgno = '016' || '013'. "STPO || STAS  "TIMESTAMP_PLACEHOLDER DEVELOPER
              ENDIF.



              " } STPO

            WHEN 'STZU'.
              DATA l_stzu TYPE stzu.
              TRY.
                  cl_abap_container_utilities=>read_container_c(
                  EXPORTING
                    im_container           = <bdcp>-tabkey
                  IMPORTING
                    ex_value               = l_stzu
                  EXCEPTIONS illegal_parameter_type = 1 OTHERS = 2 ).
                  rc = sy-subrc.
                CATCH cx_root INTO ex_object_cx_root.
                  ex_text = ex_object_cx_root->get_text( ) .
                  ex_text_long = ex_object_cx_root->get_longtext( ) .
              ENDTRY.
*                  MOVE-CORRESPONDING l_stzu TO stko_key.
*                  APPEND stko_key TO stko_key_tab.

              " } STZU
              SELECT matnr , werks , losbs , andat , annam , aedat , aenam ,  stlnr , stlal , stlan
              FROM mast
              INTO CORRESPONDING FIELDS OF TABLE @mast_tab
              WHERE
              stlan = 1 "production
              "AND werks =  l_stzu-werks  "ToDo - ToConfirm
              AND stlnr = @l_stzu-stlnr
              .
              rc = sy-subrc.
              msgno = '017'. "STZU

            WHEN OTHERS.
              rc = 12.

          ENDCASE.


          LOOP AT mast_tab ASSIGNING FIELD-SYMBOL(<mast>).
            ir_application_log->add_msg( iv_msgid = '/RGS/P_DCB_PRODVER'
            iv_msgty = if_drf_const=>msg_type_info
            "IR_OBJECT =  LR_ORDER
            iv_msgno = msgno  "BOM &1  &2 changed for plant &3
            iv_msgv1 = <mast>-stlnr
            iv_msgv2 = <mast>-stlal
            iv_msgv3 = <mast>-werks
            iv_msgv4 = <mast>-matnr
            ).
          ENDLOOP.

          IF rc EQ 0 AND mast_tab[] IS NOT INITIAL.
            SELECT matnr,  werks,  verid FROM mkal INTO TABLE @DATA(key_tab_stko) "
                  "APPENDING CORRESPONDING FIELDS OF TABLE @key_tab
                  FOR ALL ENTRIES IN @mast_tab
                  WHERE
                  matnr = @mast_tab-matnr
                  AND  werks = @mast_tab-werks
                  AND  stlal = @mast_tab-stlal
                  AND  stlan = 1 "
                  "AND  plnty = @mast_tab-plnty
                  "AND  plnnr = @mapl_tab-plnnr.
                  .
            rc = sy-subrc.
          ENDIF.

          SORT key_tab_stko BY matnr werks verid.      "#EC CI_SORTLOOP
          DELETE ADJACENT DUPLICATES FROM key_tab_stko COMPARING matnr werks verid.



          ir_application_log->increase_msg_level( EXPORTING iv_description = `STKO analysis for ` && <bdcp>-tabname && ` change` ).
          LOOP AT key_tab_stko ASSIGNING FIELD-SYMBOL(<key_stko>).


            GET REFERENCE OF <key_stko> INTO DATA(lr_key_stko) .
            lv_matnr = |{ <key_stko>-matnr  ALPHA = OUT }|.

            ir_application_log->add_msg( iv_msgid = '/RGS/P_DCB_PRODVER'
            iv_msgty = if_drf_const=>msg_type_info
            iv_msgv1 = |{ ` Material ` &&   lv_matnr   }|
            iv_msgv2 = |{ ` PV `  && <key_stko>-verid }|
            ir_object =  lr_key_stko
            iv_msgno = '020' )."Analysis of &4 change).

            "IF lv_matnr(1) NE '0'.          "no DIA "TIMESTAMP_PLACEHOLDER DEVELOPER
            CLEAR key.
            MOVE-CORRESPONDING <key_stko> TO key.
            APPEND key TO key_tab.
            "ENDIF. "TIMESTAMP_PLACEHOLDER DEVELOPER

          ENDLOOP.
          ir_application_log->decrease_msg_level( ).
          CLEAR: mast_tab[], stko4stpo_tab[] , stas_tab[], l_stko_tabkey.

        WHEN 'AENNR_S4H'.
          CASE <bdcp>-tabname.
            WHEN 'AEOI'.

              DATA l_aeoi TYPE aeoi.
              TRY.
                  cl_abap_container_utilities=>read_container_c(
                  EXPORTING
                    im_container           = <bdcp>-tabkey
                  IMPORTING
                    ex_value               = l_aeoi
                 EXCEPTIONS illegal_parameter_type = 1 OTHERS = 2 ).
                  rc = sy-subrc.
                CATCH cx_root INTO ex_object_cx_root.
                  ex_text = ex_object_cx_root->get_text( ) .
                  ex_text_long = ex_object_cx_root->get_longtext( ) .
              ENDTRY.
              IF l_aeoi-aetyp NE 2.
                CONTINUE.
              ENDIF.




            WHEN OTHERS.
              ex_text =  ex_text = |{  <bdcp>-tabname && ` ` && <bdcp>-cdobjcl }|  ##needed.
          ENDCASE.



        WHEN OTHERS.
          ex_text =  ex_text = |{  <bdcp>-tabname && ` ` && <bdcp>-cdobjcl }| ##needed.

      ENDCASE.

      tabname_prev = <bdcp>-tabname.

    ENDLOOP.


    ir_application_log->decrease_msg_level( ).





    SORT key_tab BY matnr werks verid.
    DELETE ADJACENT DUPLICATES FROM key_tab COMPARING  matnr werks verid.


    IF key_tab[] IS NOT INITIAL.
      SELECT DISTINCT matnr , werks , verid
      "TIMESTAMP_PLACEHOLDER DEVELOPER , aennr  "TIMESTAMP_PLACEHOLDER DEVELOPER
      "FROM /rgs/p_s_dcb_prodver_flt1
      FROM /rgs/p_s_dcb_prodver_flt_aenn2  "TIMESTAMP_PLACEHOLDER DEVELOPER
      INTO TABLE @ct_changed_objects
      FOR ALL ENTRIES IN @key_tab
      WHERE matnr = @key_tab-matnr
      AND werks = @key_tab-werks
      AND verid = @key_tab-verid

      """   AND aennr = @key_tab-aennr "TIMESTAMP_PLACEHOLDER DEVELOPER

      "AND ybc_mes_dist = @temp_ybc_mes_dist .

      .
      IF sy-subrc <> 0.
        MESSAGE ID sy-msgid TYPE sy-msgty NUMBER sy-msgno
        WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4 INTO ex_text.
      ENDIF.

    ENDIF.






**    ASSIGN: ls_changed TO <fs_changed>.
**    LOOP AT change_pointer_t ASSIGNING FIELD-SYMBOL(<fs_cp>).
**      MOVE <fs_cp>-object_key TO <fs_changed>.
**      INSERT <fs_changed> INTO TABLE ct_changed_objects.
**    ENDLOOP.
  ENDMETHOD.


  METHOD if_drf_outbound~analyze_changes_by_mdg_cp.
    "DATA: lt_change_pointers TYPE TABLE OF mdg_cp_s_cp_full,
    RETURN.
  ENDMETHOD.


  METHOD if_drf_outbound~analyze_changes_by_others.
  ENDMETHOD.


  METHOD if_drf_outbound~apply_node_inst_filter_multi.
    RETURN.
  ENDMETHOD.


  METHOD if_drf_outbound~apply_node_inst_filter_single.
  ENDMETHOD.


  METHOD if_drf_outbound~build_parallel_package.
  ENDMETHOD.


  METHOD if_drf_outbound~enrich_filter_criteria.
  ENDMETHOD.


  METHOD if_drf_outbound~finalize.
    CLEAR: ev_delete_change_pointer.
    ms_runtime_param-bal->decrease_msg_level( ).
    ev_delete_change_pointer = abap_true.
  ENDMETHOD.


  METHOD if_drf_outbound~initialize.

    DATA: lo_drf_prodn_vers_out TYPE REF TO /rgs/cl_p_dcb_drf_prodver_out.

*   Create Object reference for DRF Implementaion Class
    CREATE OBJECT lo_drf_prodn_vers_out.

*   Clear Export Paramater
    CLEAR: es_runtime_param_out_impl.

    MOVE-CORRESPONDING is_runtime_param TO lo_drf_prodn_vers_out->ms_runtime_param.

    eo_if_drf_outbound = lo_drf_prodn_vers_out.


*   Define the table of relevant data to replicate
    es_runtime_param_out_impl-table_type_name = mc_tabletype.

    mv_keydate = sy-datum. "Recipe "TIMESTAMP_PLACEHOLDER DEVELOPER



    mo_drf_appl_log = ms_runtime_param-bal.




  ENDMETHOD.


  METHOD if_drf_outbound~map_data2message.
*-----------------------------------------------------------------------------------------------*
* Functional Spec: DS_REF BOM PV MES interface
* Technical Spec:  DS_REF BOM PV MES interface
* Process:         Make- 4.3.2.2  Manage and Release order
*                  S4H Outbound BOM and PV MES
* History --------------------------------------------------------------------------------------*
* Date       | Change     | Contributor                | Description
*-----------------------------------------------------------------------------------------------*
* DATE_PLACEHOLDER | WI_PLACEHOLDER |  DEVELOPER             | Initial version
* DATE_PLACEHOLDER | WI_PLACEHOLDER |  DEVELOPER             | S4H-MES Mapping updates
* DATE_PLACEHOLDER | WI_PLACEHOLDER |  DEVELOPER             | BOM Header validity data
* DATE_PLACEHOLDER | WI_PLACEHOLDER |  DEVELOPER             | CHG_PLACEHOLDER_BOM ECN send wrong to MES
* DATE_PLACEHOLDER | WI_PLACEHOLDER |  DEVELOPER             | TICKET_PLACEHOLDER: Enhance PV/BoM MES IF
* DATE_PLACEHOLDER | WI_PLACEHOLDER |  DEVELOPER             | Space in BOMHeaderQuantityInBaseUnit val
* DATE_PLACEHOLDER | WI_PLACEHOLDER |  DEVELOPER             | PV interface - component segments issue
* DATE_PLACEHOLDER | WI_PLACEHOLDER:|  DEVELOPER             | Multiple ECN segments in message
*-----------------------------------------------------------------------------------------------*

    DATA: wa_pvdata             TYPE i_productionversion,
          wa_message            TYPE ppint_prodn_vers_information,
          lv_currconvrsioncheck TYPE boolean,
          lv_rv_isocode         TYPE isocd_unit,
          ls_output_buffer      TYPE ts_output_buffer.

    CLEAR mt_output_buffer[].


    FIELD-SYMBOLS <key_s> TYPE /rgs/p_dcb_drf_s_prodvers_key.
    ASSIGN ir_relevant_object->* TO <key_s>.
    IF sy-subrc EQ 0.
      READ TABLE mt_data_buffer WITH KEY
        matnr = <key_s>-matnr
        werks = <key_s>-werks
        verid = <key_s>-verid

      ASSIGNING FIELD-SYMBOL(<data_buffer>).
    ELSE.
      RETURN.
    ENDIF.

    CHECK sy-subrc EQ 0.


    wa_pvdata = <data_buffer>-pv_fulldata.

    CLEAR ms_keystr.
    ms_keystr = VALUE #(
    matnr = wa_pvdata-material
    werks = wa_pvdata-plant
    verid = wa_pvdata-productionversion
    ).
    cl_mes_drf_prodn_vers=>convert_unit_sap_to_iso(
    EXPORTING
      iv_sapcode = wa_pvdata-materialbaseunit
    IMPORTING
      iv_isocheck = lv_currconvrsioncheck
      rv_isocode  = lv_rv_isocode
      ).

    "TIMESTAMP_PLACEHOLDER DEVELOPER

    IF lv_currconvrsioncheck EQ abap_true.
      wa_message-plant = wa_pvdata-plant.
      wa_message-material = wa_pvdata-material.
      wa_message-production_version = wa_pvdata-productionversion.
      wa_message-production_version_text = wa_pvdata-productionversiontext.
      wa_message-material_min_lot_size_quantity-content = wa_pvdata-materialminlotsizequantity.
      wa_message-material_min_lot_size_quantity-unit_code = lv_rv_isocode.
      wa_message-material_max_lot_size_quantity-content = wa_pvdata-materialmaxlotsizequantity.
      wa_message-material_max_lot_size_quantity-unit_code = lv_rv_isocode.
      wa_message-change_number = wa_pvdata-changenumber.
      wa_message-validity_start_date = wa_pvdata-validitystartdate.
      wa_message-validity_end_date = wa_pvdata-validityenddate.
      wa_message-bill_of_operations_type = wa_pvdata-billofoperationstype.
      wa_message-bill_of_operations_group = wa_pvdata-billofoperationsgroup.
      wa_message-bill_of_operations_variant = wa_pvdata-billofoperationsvariant.
      wa_message-production_version_status = wa_pvdata-productionversionstatus.
      wa_message-bill_of_material_variant = wa_pvdata-billofmaterialvariant.
      wa_message-bill_of_material_variant_usage = wa_pvdata-billofmaterialvariantusage.
      wa_message-material_cost_apportionment_st = wa_pvdata-materialcostapportionmentstruc.
      wa_message-main_product = wa_pvdata-mainproduct.
      wa_message-issuing_storage_location = wa_pvdata-issuingstoragelocation.
      wa_message-receiving_storage_location = wa_pvdata-receivingstoragelocation.
      wa_message-ware_house_no = wa_pvdata-warehouse.
      wa_message-destination_storage_bin = wa_pvdata-destinationstoragebin.
      wa_message-distribution_key = wa_pvdata-distributionkey.
      wa_message-original_batch_reference_mater = wa_pvdata-originalbatchreferencematerial.
      wa_message-production_supply_area = wa_pvdata-productionsupplyarea.
      wa_message-bomcheck_status = wa_pvdata-bomcheckstatus.

      DATA commercial_unit(3) TYPE c.
      CALL FUNCTION 'CONVERSION_EXIT_CUNIT_OUTPUT'
        EXPORTING
          input          = wa_pvdata-materialbaseunit
          language       = 'E'
        IMPORTING
          output         = commercial_unit
        EXCEPTIONS
          unit_not_found = 1
          OTHERS         = 2.
      IF sy-subrc EQ 0.
        wa_message-material_min_lot_size_quantity-unit_code = commercial_unit.
        wa_message-material_max_lot_size_quantity-unit_code = commercial_unit.
      ENDIF.

      "TIMESTAMP_PLACEHOLDER DEVELOPER add recipe
      .

      DATA(bill_of_operations_tab) = <data_buffer>-recipe_message-bill_of_operations. "TIMESTAMP_PLACEHOLDER DEVELOPER
      READ TABLE  bill_of_operations_tab INTO DATA(bill_of_operations) WITH KEY production_version = wa_pvdata-productionversion.
      IF sy-subrc EQ 0.
        MOVE-CORRESPONDING bill_of_operations TO ms_output-manufacturing_prodn_vers_info." manufacturing_prodn_vers_info.

      ENDIF.

      CLEAR ms_output-manufacturing_prodn_vers_info-production_version_information[].  "TIMESTAMP_PLACEHOLDER DEVELOPER
      APPEND wa_message  TO ms_output-manufacturing_prodn_vers_info-production_version_information.

      ms_output-manufacturing_prodn_vers_info-message_header = get_business_header( ms_runtime_param ).

      DATA(rgs_bom_header_switch) = 'X'.
      DATA(rgs_bom_header_single_switch) = space. "'X'. "TIMESTAMP_PLACEHOLDER DEVELOPER

      IF rgs_bom_header_switch EQ 'X'.
        IF rgs_bom_header_single_switch EQ 'X'.


          SELECT SINGLE "*
          billofmaterialcategory,
          billofmaterial,
          bomheadertext,
          bomalternativetext,
          bomheaderquantityinbaseunit,
          bomheaderbaseunit,

          engineeringchangedocument,  "TIMESTAMP_PLACEHOLDER DEVELOPER
          headervaliditystartdate,    "TIMESTAMP_PLACEHOLDER DEVELOPER
          headervalidityenddate       "TIMESTAMP_PLACEHOLDER DEVELOPER

          FROM a_billofmaterial
          WHERE billofmaterialvariant        = @wa_message-bill_of_material_variant
          AND billofmaterialvariantusage  = @wa_message-bill_of_material_variant_usage
          AND material              = @wa_message-material
          AND plant                 = @wa_message-plant

        AND NOT (
        headervalidityenddate       <  @wa_message-validity_start_date "valid_from
        OR headervaliditystartdate  >   @wa_message-validity_end_date )


          INTO @DATA(the_billofmaterial).

          DATA(rgs_bom_header_single_rc) = sy-subrc ##needed.

        ELSE. "TIMESTAMP_PLACEHOLDER DEVELOPER
          SELECT "SINGLE "*
          billofmaterialcategory,
          billofmaterial,
          bomheadertext,
          bomalternativetext,
          bomheaderquantityinbaseunit,
          bomheaderbaseunit,

          engineeringchangedocument,  "TIMESTAMP_PLACEHOLDER DEVELOPER
          headervaliditystartdate,    "TIMESTAMP_PLACEHOLDER DEVELOPER
          headervalidityenddate       "TIMESTAMP_PLACEHOLDER DEVELOPER

          FROM a_billofmaterial
          WHERE billofmaterialvariant        = @wa_message-bill_of_material_variant
          AND billofmaterialvariantusage  = @wa_message-bill_of_material_variant_usage
          AND material              = @wa_message-material
          AND plant                 = @wa_message-plant

           AND NOT (
                 headervalidityenddate    <  @wa_message-validity_start_date "valid_from
              OR headervaliditystartdate  >  @wa_message-validity_end_date )

          INTO TABLE @DATA(billofmaterial_tab).
          IF sy-subrc EQ 0.
            "TIMESTAMP_PLACEHOLDER DEVELOPER{

            DATA(ex_billofmaterial_tab) = billofmaterial_tab[].                 "TIMESTAMP_PLACEHOLDER DEVELOPER
            DELETE billofmaterial_tab WHERE headervalidityenddate < sy-datum ." WI_PLACEHOLDER remove expired

            "SORT billofmaterial_tab BY engineeringchangedocument DESCENDING. "WI_PLACEHOLDER removed
            "SORT billofmaterial_tab BY headervaliditystartdate ASCENDING. "WI_PLACEHOLDER WI_PLACEHOLDER "TIMESTAMP_PLACEHOLDER DEVELOPER

            "}TIMESTAMP_PLACEHOLDER DEVELOPER
            SORT billofmaterial_tab BY headervalidityenddate DESCENDING. "CHG_PLACEHOLDER_BOM ECN send wrong to MES
            READ TABLE billofmaterial_tab INDEX 1 INTO the_billofmaterial.
            DATA(rc_19) = sy-subrc ##needed.
          ENDIF.


        ENDIF.

        IF the_billofmaterial-billofmaterial IS NOT INITIAL. "TIMESTAMP_PLACEHOLDER DEVELOPER

          ms_output-manufacturing_prodn_vers_info-bom_category = the_billofmaterial-billofmaterialcategory . "TIMESTAMP_PLACEHOLDER DEVELOPER

          ms_output-manufacturing_prodn_vers_info-bill_of_material = the_billofmaterial-billofmaterial.
          ms_output-manufacturing_prodn_vers_info-bom_header_text = the_billofmaterial-bomheadertext.
          ms_output-manufacturing_prodn_vers_info-bom_alternative_header_text = the_billofmaterial-bomalternativetext.
          ms_output-manufacturing_prodn_vers_info-quantity_in_base_unit = the_billofmaterial-bomheaderquantityinbaseunit.



          CALL FUNCTION 'CONVERSION_EXIT_CUNIT_OUTPUT'
            EXPORTING
              input          = the_billofmaterial-bomheaderbaseunit
              language       = 'E'
            IMPORTING
              output         = commercial_unit
            EXCEPTIONS
              unit_not_found = 1
              OTHERS         = 2.
          IF sy-subrc EQ 0.
            the_billofmaterial-bomheaderbaseunit = commercial_unit.
          ENDIF.


          SHIFT  the_billofmaterial-bomheaderbaseunit RIGHT DELETING TRAILING space. "TIMESTAMP_PLACEHOLDER DEVELOPER WI_PLACEHOLDER
          SHIFT  the_billofmaterial-bomheaderbaseunit LEFT  DELETING LEADING space.
          ms_output-manufacturing_prodn_vers_info-base_unit = the_billofmaterial-bomheaderbaseunit.


          "TIMESTAMP_PLACEHOLDER DEVELOPER
          ms_output-manufacturing_prodn_vers_info-bom_header_ecn = the_billofmaterial-engineeringchangedocument.


        ENDIF.

        "TIMESTAMP_PLACEHOLDER DEVELOPER
        DATA ex_bom TYPE /rgs/p_dcb_pv_rgs_p_dcb_pv_bom.
        DATA(ex_bom_lines) = lines( ex_billofmaterial_tab ).                          "TIMESTAMP_PLACEHOLDER DEVELOPER
        CLEAR ms_output-manufacturing_prodn_vers_info-bom_extra_data[].               "TIMESTAMP_PLACEHOLDER DEVELOPER WI_PLACEHOLDER: Multiple ECN segments in message
        SORT ex_billofmaterial_tab BY headervaliditystartdate headervalidityenddate.  "TIMESTAMP_PLACEHOLDER DEVELOPER WI_PLACEHOLDER

        LOOP AT ex_billofmaterial_tab ASSIGNING FIELD-SYMBOL(<ex_billofmaterial>).
          CLEAR ex_bom.

          "TIMESTAMP_PLACEHOLDER DEVELOPER{
          IF sy-tabix < ex_bom_lines.
            <ex_billofmaterial>-headervalidityenddate = <ex_billofmaterial>-headervalidityenddate - 1.
          ENDIF.
          "}TIMESTAMP_PLACEHOLDER DEVELOPER

          ex_bom-bom_header_ecn   = <ex_billofmaterial>-engineeringchangedocument.
          ex_bom-bom_validity_start_date =   |{  <ex_billofmaterial>-headervaliditystartdate DATE = ISO }|.
          ex_bom-bom_validity_end_date =     |{  <ex_billofmaterial>-headervalidityenddate   DATE = ISO }|.
          ex_bom-quantity_in_base_unit = <ex_billofmaterial>-bomheaderquantityinbaseunit.
          ex_bom-bom_header_base_unit = <ex_billofmaterial>-bomheaderbaseunit.

          CALL FUNCTION 'CONVERSION_EXIT_CUNIT_OUTPUT'
            EXPORTING
              input          = <ex_billofmaterial>-bomheaderbaseunit
              language       = 'E'
            IMPORTING
              output         = commercial_unit
            EXCEPTIONS
              unit_not_found = 1
              OTHERS         = 2.
          IF sy-subrc EQ 0.
            ex_bom-bom_header_base_unit = commercial_unit.
          ENDIF.

          SHIFT  ex_bom-bom_header_base_unit RIGHT DELETING TRAILING space.   "TIMESTAMP_PLACEHOLDER DEVELOPER WI_PLACEHOLDER
          SHIFT  ex_bom-bom_header_base_unit LEFT  DELETING LEADING  space.

          SHIFT  ex_bom-quantity_in_base_unit RIGHT DELETING TRAILING space.  "TIMESTAMP_PLACEHOLDER DEVELOPER WI_PLACEHOLDER
          SHIFT  ex_bom-quantity_in_base_unit LEFT  DELETING LEADING  space.

          IF  <ex_billofmaterial>-headervalidityenddate GE sy-datum.          "TIMESTAMP_PLACEHOLDER DEVELOPER  remove old entries WI_PLACEHOLDER
            APPEND ex_bom TO ms_output-manufacturing_prodn_vers_info-bom_extra_data.
          ENDIF.                                                              "TIMESTAMP_PLACEHOLDER DEVELOPER WI_PLACEHOLDER

        ENDLOOP.
        "TIMESTAMP_PLACEHOLDER DEVELOPER





      ENDIF. "IF rgs_bom_header_switch EQ 'X'.

      ls_output_buffer-matnr =    wa_pvdata-material.
      ls_output_buffer-werks = wa_pvdata-plant.
      ls_output_buffer-verid = wa_pvdata-productionversion.
      ls_output_buffer-output = ms_output.








      APPEND ls_output_buffer TO mt_output_buffer. "byPS


    ENDIF.


  ENDMETHOD.


  METHOD if_drf_outbound~read_complete_data.
*----------------------------------------------------------------------*
* Functional Spec: DS_REF BOM PV MES interface
* Technical Spec:  DS_REF BOM PV MES interface
* Process:         Make- 4.3.2.2  Manage and Release order
*                  S4H Outbound BOM and PV MES
* History ---------------------------------------------------------------------------------*
* Date       | Change     | Contributor                | Description
*------------------------------------------------------------------------------------------*
* DATE_PLACEHOLDER | WI_PLACEHOLDER |  DEVELOPER             | Initial version
* DATE_PLACEHOLDER | 4000008352 |  DEVELOPER             | Add BOM header and item ECN
*------------------------------------------------------------------------------------------*


    CHECK ct_relevant_objects IS NOT INITIAL.
    DATA: ls_relobj TYPE /rgs/p_dcb_drf_s_prodvers_key. "fins_cfins_prod_ver.

    TYPES : BEGIN OF str1,
              material          TYPE matnr,
              plant             TYPE werks_d,
              productionversion TYPE verid,
              changenumber      TYPE aennr,
            END OF str1.


    DATA mstr_rcp_tab TYPE comes_t_drf_mstrrcp_key.
    DATA mstr_rcp TYPE comes_s_drf_mstrrcp_key.



    DATA: lt_fulldata TYPE TABLE OF i_productionversion.
    DATA: lt_filterdata TYPE TABLE OF str1.
    DATA: ls_filterdata TYPE str1.

    "TIMESTAMP_PLACEHOLDER DEVELOPER{
    IF ms_runtime_param-runmod <> if_drf_const=>runmod_bypass_filter.
      "filter class was already called by framework (incl. external criteria)
      "-> no need for filtering again
      "return.
    ELSE.
      DATA(lt_filtered_object) = VALUE /rgs/p_dcb_drf_t_prodvers_key( ).
      get_filter( )->apply_filter(
      EXPORTING
        iv_appl                 = ms_runtime_param-appl
        iv_business_system      = ms_runtime_param-business_system
        iv_outb_impl            = ms_runtime_param-outb_impl
        iv_runmod               = ms_runtime_param-runmod
        io_bal                  = ms_runtime_param-bal
        iv_dlmod                = ms_runtime_param-dlmod
        it_unfiltered_objects   = ct_relevant_objects
        is_c_fobj               = VALUE #( ) "filter config not available / required
        is_filt                 = VALUE #( ) "filter config not available / required
        it_external_criteria    = VALUE #( ) "must stay empty, stipulated by runmod
      IMPORTING
        et_filtered_objects     = lt_filtered_object
        ).
      ct_relevant_objects = lt_filtered_object.
    ENDIF.


    "}TIMESTAMP_PLACEHOLDER DEVELOPER


    LOOP AT ct_relevant_objects INTO ls_relobj.
      ls_filterdata-material = ls_relobj-matnr.
      ls_filterdata-plant = ls_relobj-werks.
      ls_filterdata-productionversion = ls_relobj-verid.
      "TIMESTAMP_PLACEHOLDER DEVELOPER ls_filterdata-changenumber = ls_relobj-aennr.
      APPEND ls_filterdata TO lt_filterdata.

    ENDLOOP.



    IF lt_filterdata[] IS NOT INITIAL.

      SELECT
        material                       ,
        plant                          ,
        productionversion              ,
        productionversiontext          ,
        materialminlotsizequantity     ,
        materialmaxlotsizequantity     ,
        materialbaseunit,
        changenumber                   ,
        validitystartdate              ,
        validityenddate                ,
        billofoperationstype           ,
        billofoperationsgroup          ,
        billofoperationsvariant        ,
        productionversionstatus        ,
        billofmaterialvariant          ,
        billofmaterialvariantusage     ,
        materialcostapportionmentstruc ,
        mainproduct                    ,
        issuingstoragelocation         ,
        receivingstoragelocation       ,
        warehouse                      ,
        destinationstoragebin          ,
        distributionkey                ,
        originalbatchreferencematerial ,
        bomcheckstatus                 ,
        productionsupplyarea
        FROM i_productionversion
        INTO CORRESPONDING FIELDS OF TABLE @lt_fulldata
        FOR ALL ENTRIES IN @lt_filterdata
        WHERE
        material = @lt_filterdata-material
        AND plant = @lt_filterdata-plant
        AND productionversion = @lt_filterdata-productionversion

    ""    AND changenumber  =  @lt_filterdata-changenumber  "TIMESTAMP_PLACEHOLDER DEVELOPER

        AND validityenddate >= @sy-datum
        AND productionversionstatus EQ '1'
        AND bomcheckstatus EQ '1'
        .
      rc = sy-subrc.
      .
    ENDIF.



    IF ( rc EQ 0 )
      AND lt_fulldata[] IS NOT INITIAL. "20220201-0641

      APPEND LINES OF lt_fulldata TO mt_prodnversdata.

      DATA data_buffer TYPE ts_data_buffer.

      LOOP AT lt_fulldata ASSIGNING FIELD-SYMBOL(<pv_fulldata>).

        CLEAR: mstr_rcp, mstr_rcp_tab[].

        data_buffer-matnr = <pv_fulldata>-material.
        data_buffer-werks = <pv_fulldata>-plant.
        data_buffer-verid = <pv_fulldata>-productionversion.
        data_buffer-pv_fulldata = <pv_fulldata>.


        mstr_rcp-matnr = <pv_fulldata>-material.
        mstr_rcp-werks = <pv_fulldata>-plant.
        mstr_rcp-plnnr = <pv_fulldata>-billofoperationsgroup.
        mstr_rcp-plnal = <pv_fulldata>-billofoperationsvariant.

        APPEND mstr_rcp TO mstr_rcp_tab.              "#EC CI_APPEND_OK


        data_buffer-recipe_message = me->recipe_read_complete_data( EXPORTING i_verid =  data_buffer-verid  "TIMESTAMP_PLACEHOLDER DEVELOPER
                                                                    CHANGING ct_relevant_objects =  mstr_rcp_tab  ).


        APPEND data_buffer TO mt_data_buffer.
        CLEAR data_buffer.
        CLEAR: ms_recipe_message, mt_mainheader[]      ,    mt_header[]       ,    mt_matlassgmt[]     , mt_activity[]
         ,  mt_compalloc[]     ,mt_relations[]. "TIMESTAMP_PLACEHOLDER DEVELOPER !!!
      ENDLOOP.


    ENDIF.  "select sy-subrc eq 0.


  ENDMETHOD.


  METHOD if_drf_outbound~send_message.
*----------------------------------------------------------------------*
* Functional Spec: DS_REF BOM PV MES interface
* Technical Spec:  DS_REF BOM PV MES interface
* Process:         Make- 4.3.2.2  Manage and Release order
*                  S4H Outbound BOM and PV MES
* History -------------------------------------------------------------*
* Date       | Change     | Contributor                | Description
*----------------------------------------------------------------------*
* DATE_PLACEHOLDER | WI_PLACEHOLDER |  DEVELOPER             | Initial version
* DATE_PLACEHOLDER | WI_PLACEHOLDER |  DEVELOPER                    | Time Zone conversion
*----------------------------------------------------------------------*



*   Local Variable and object reference Declaration
    DATA: " lo_service_proxy           TYPE REF TO co_ppint_mfg_prodn_vers,
      lv_error_text              TYPE string,
      lv_longtext                TYPE string,
      lv_soa_exception_text      TYPE string,
      lv_soa_exception_long_text TYPE string,
      ls_message_data_outbound   TYPE ppint_mfg_prodn_vers_inf.

    DATA: lo_wsprotocol_message_id TYPE REF TO if_wsprotocol_message_id.

    DATA key_ref TYPE REF TO /rgs/p_dcb_drf_s_prodvers_key.

    DATA:
      p_ns     TYPE /aif/ns VALUE 'AIF_NS',
      p_ifname TYPE /aif/ifname VALUE 'AIF_IFNAME',
      p_ifver  TYPE /aif/ifversion VALUE '1'.

*   Local Constant Declaration
    CONSTANTS:lc_matgrp_service TYPE string  VALUE 'ManufacturingProdnVersInfo_Out'.

*   Clear Exporting Parameter
    CLEAR: et_file_data,et_message.

    DATA lt_return  TYPE  bapiret2_t.
    DATA: ximsgguid     TYPE  sxmsmguid,
          ximsgguid_out TYPE  sxmsmguid.


    DATA:
      error_string    TYPE  string,
      error_long_text TYPE  string.


    READ TABLE ct_obj_rep_sta ASSIGNING FIELD-SYMBOL(<obj_rep_sta>) INDEX 1.
    IF sy-subrc NE 0.
      RETURN.
    ENDIF.



    DATA key TYPE /rgs/p_dcb_drf_s_prodvers_key.

    key = CONV /rgs/p_dcb_drf_s_prodvers_key(  <obj_rep_sta>-object_id ).
    GET REFERENCE OF key INTO  key_ref.


    READ TABLE  mt_output_buffer WITH KEY matnr = key-matnr  werks = key-werks  verid = key-verid ASSIGNING FIELD-SYMBOL(<output_buffer>).
    IF sy-subrc NE 0.
      RETURN.
    ENDIF.


    ms_output = <output_buffer>-output.
    "TIMESTAMP_PLACEHOLDER DEVELOPER{ no DIA routing
    IF ms_output-manufacturing_prodn_vers_info-bill_of_operations_type NE '2'.
      TRY.
          ms_runtime_param-bal->add_msg( iv_msgid = '/RGS/P_DCB_PRODVER'
                 iv_msgty = if_drf_const=>msg_type_warning
                 iv_msgno = '040'  "bill_of_operations_type NE '2'
                 iv_msgv1 = ms_output-manufacturing_prodn_vers_info-bill_of_operations_type
                 iv_msgv2 = ms_output-manufacturing_prodn_vers_info-production_version_information[ 1 ]-material
                 iv_msgv3 = ms_output-manufacturing_prodn_vers_info-production_version_information[ 1 ]-plant
                 iv_msgv4 = ms_output-manufacturing_prodn_vers_info-production_version_information[ 1 ]-production_version
                 ).
        CATCH cx_sy_itab_line_not_found.
          DATA(rc99) = 99 ##needed.
      ENDTRY.
      RETURN.
    ENDIF.
    "TIMESTAMP_PLACEHOLDER DEVELOPER   no DIA routing

*   If Output Data is not Blank Trigger Outbound Proxy to replicate the Routing from S4 to Target System
    IF NOT ms_output-manufacturing_prodn_vers_info-production_version_information IS INITIAL
      AND NOT ms_output-manufacturing_prodn_vers_info-bill_of_operations_activity_ne IS INITIAL. "TIMESTAMP_PLACEHOLDER DEVELOPER

*Begin of changes, WI#WI_PLACEHOLDER, TR#TR_PLACEHOLDER
      DATA(creation_date) = sy-datum.
      DATA(creation_time) = sy-uzeit.
      convert_timestamp( CHANGING c_date =   creation_date
                                  c_time =   creation_time     ).
      ms_output-manufacturing_prodn_vers_info-message_header-creation_date_time = creation_date && creation_time.
*End of changes, WI#WI_PLACEHOLDER, TR#TR_PLACEHOLDER

      "TIMESTAMP_PLACEHOLDER DEVELOPER{
      TRY.
          ASSIGN   ms_output-manufacturing_prodn_vers_info-production_version_information[ 1 ] TO FIELD-SYMBOL(<pv>).
          IF sy-subrc EQ 0.
            CALL FUNCTION 'CONVERSION_EXIT_MATN1_OUTPUT'
              EXPORTING
                input  = <pv>-material
              IMPORTING
                output = <pv>-material.
            DATA(rc_i0002c) = sy-subrc ##needed.
          ENDIF.
        CATCH cx_sy_itab_line_not_found.
          DATA(rc) = 99 ##needed.
      ENDTRY.
      "}TIMESTAMP_PLACEHOLDER DEVELOPER

      TRY.
          IF ms_runtime_param-testrun = abap_false.
            ls_message_data_outbound = ms_output.

            TRY.

                CALL FUNCTION '/AIF/SEND_WITH_PROXY'
                  EXPORTING
                    ns                   = p_ns
                    ifname               = p_ifname
                    ifversion            = p_ifver
                    appl_log_function    = 'AIF_SEND_WITH_PROXY'
                    msgguid              = ximsgguid  "TIMESTAMP_PLACEHOLDER DEVELOPER
                    iv_persist_xml       = 'X'
                    logical_port_name    = 'AIF_LOGICAL_PORT'
                  IMPORTING
                    ximsgguid            = ximsgguid
                    ximsgguid_out        = ximsgguid_out
                  TABLES
                    add_return_tab       = lt_return
                  CHANGING
                    sap_struct           = ls_message_data_outbound
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




                  mo_drf_appl_log->add_msg_xi(
                  EXPORTING
                    "IV_XI_MSG_GUID         = XIMSGGUID " LV_GUID
                    iv_xi_msg_guid         = ximsgguid_out "20211122-0004
                    iv_object_count        = iv_object_count
                    io_message_id_protocol = lo_wsprotocol_message_id
                    iv_outb_impl           = ms_runtime_param-outb_impl
                    ir_object              = key_ref
                    is_message_out         = ls_message_data_outbound ).



                ENDIF.
*       Handle the Exception and generate DRF Application Log
              CATCH cx_bs_soa_exception INTO mo_bs_soa_exception.
*         In case of data replication failure change the replication status to 'SE' from 'SN'
                LOOP AT ct_obj_rep_sta ASSIGNING FIELD-SYMBOL(<fs_obj_rep_sta>).
                  <fs_obj_rep_sta>-repstatus = 'SE'.
                ENDLOOP.
                UNASSIGN: <fs_obj_rep_sta>.

*         Get error text
                CALL METHOD mo_bs_soa_exception->get_text
                  RECEIVING
                    result = lv_soa_exception_text.

*         Get long text
                CALL METHOD mo_bs_soa_exception->get_longtext
                  RECEIVING
                    result = lv_soa_exception_long_text.

                MESSAGE s015(drf_outbound) WITH lc_matgrp_service lv_soa_exception_text lv_soa_exception_long_text INTO DATA(lv_dummy) ##needed.
*         Add message to application log, raise exception
                CALL METHOD ms_runtime_param-bal->add_msg_re
                  EXPORTING
                    iv_msgno             = sy-msgno
                    iv_msgid             = sy-msgid
                    iv_msgv1             = sy-msgv1
                    iv_msgv2             = sy-msgv2
                    iv_msgv3             = sy-msgv3
                    ix_exception_catched = mo_bs_soa_exception.
*       Handle the Exception and generate DRF Application Log


              CATCH cx_ai_system_fault INTO mo_error .
*         In case of data replication failure change the replication status to 'SE' from 'SN'
                LOOP AT ct_obj_rep_sta ASSIGNING <fs_obj_rep_sta>.
                  <fs_obj_rep_sta>-repstatus = 'SE'.
                ENDLOOP.
                UNASSIGN: <fs_obj_rep_sta>.

*         Get error text
                CALL METHOD mo_error->if_message~get_text
                  RECEIVING
                    result = lv_error_text.

*         Get long text
                CALL METHOD mo_error->if_message~get_longtext
                  RECEIVING
                    result = lv_longtext.

                MESSAGE s015(drf_outbound) WITH lc_matgrp_service lv_error_text lv_longtext INTO lv_dummy.
*         Add message to application log, raise exception
                CALL METHOD ms_runtime_param-bal->add_msg_re
                  EXPORTING
                    iv_msgno             = sy-msgno
                    iv_msgid             = sy-msgid
                    iv_msgv1             = sy-msgv1
                    iv_msgv2             = sy-msgv2
                    iv_msgv3             = sy-msgv3
                    ix_exception_catched = mo_error.
            ENDTRY.
          ELSE.
            MESSAGE s322(drf_outbound) INTO lv_dummy.
*     If Output Data is Blank then Add Error message to application log
            CALL METHOD ms_runtime_param-bal->add_msg_re
              EXPORTING
                iv_msgno = sy-msgno
                iv_msgid = sy-msgid.
          ENDIF.

        CATCH cx_root INTO  ex_object_cx_root.
          ex_text = ex_object_cx_root->get_text( ).
          ex_text_long = ex_object_cx_root->get_longtext( ) .


      ENDTRY.


    ENDIF.





  ENDMETHOD.


  METHOD map_current_recipe_to_vari.
    CLEAR: ms_curr_key.

    ms_curr_key-matnr = iv_matnr.
    ms_curr_key-werks = iv_werks.
    ms_curr_key-plnnr = iv_plnnr.
    ms_curr_key-plnal = iv_plnal.
  ENDMETHOD.


  METHOD recipe_conversion_exit_alpha_o.
    CLEAR ev_output.

    cl_co_fm_access_factory=>alfa( )->conversion_exit_alpha_output(
      EXPORTING
        input  = iv_input
      IMPORTING
        output = ev_output ).
  ENDMETHOD.


  METHOD recipe_conversion_exit_isola_o.
    CLEAR ev_output.

    cl_co_fm_access_factory=>lang( )->conversion_exit_isola_output(
      EXPORTING
        input  = iv_input
      IMPORTING
        output = ev_output ).
  ENDMETHOD.


  METHOD recipe_convert_material_to_o.
    CLEAR ev_output.

    CALL FUNCTION 'CONVERSION_EXIT_MATN1_OUTPUT'
      EXPORTING
        input  = iv_input
      IMPORTING
        output = ev_output.

  ENDMETHOD.


  METHOD recipe_convert_unit_sap_2_iso.
    CLEAR rv_isocode.
    DATA: "lv_matnr TYPE matnr,
          "lv_werks TYPE werks_d,
          ls_key   TYPE comes_s_drf_mstrrcp_key.

    CLEAR: ls_key.

    IF iv_sapcode <> space.
      TRY.
          cl_co_fm_access_factory=>scv0( )->unit_of_measure_sap_to_iso(
            EXPORTING
              sap_code = iv_sapcode
            IMPORTING
              iso_code = rv_isocode ).
        CATCH cx_co_fm_access INTO DATA(lo_ex) ##needed.
          READ TABLE mt_key_noiso TRANSPORTING NO FIELDS WITH KEY
            matnr   = ms_curr_key-matnr
            werks   = ms_curr_key-werks
            plnnr   = ms_curr_key-plnnr
            plnal   = ms_curr_key-plnal
            sapcode = iv_sapcode.

          CHECK NOT sy-subrc IS INITIAL.

          MESSAGE e000(pph_mstr_rcp) WITH ms_curr_key-plnnr ms_curr_key-plnal iv_sapcode INTO DATA(lv_dummy) ##needed.

          MOVE-CORRESPONDING ms_curr_key TO ls_key.
          recipe_raise_message( ls_key ).

          ms_curr_key-sapcode = iv_sapcode.

          INSERT ms_curr_key INTO TABLE mt_key_noiso.

          CHECK ms_curr_key-noiso IS INITIAL.

          ms_curr_key-noiso = abap_true.
      ENDTRY.
    ENDIF.
  ENDMETHOD.


  METHOD recipe_convert_unit_sap_to_iso.
    CLEAR rv_isocode.
    DATA: "lv_matnr TYPE matnr,
    "lv_werks TYPE werks_d,
    ls_key   TYPE comes_s_drf_mstrrcp_key.

    CLEAR: ls_key.

    IF iv_sapcode <> space.
      TRY.
          cl_co_fm_access_factory=>scv0( )->unit_of_measure_sap_to_iso(
            EXPORTING
              sap_code = iv_sapcode
            IMPORTING
              iso_code = rv_isocode ).
        CATCH cx_co_fm_access INTO DATA(lo_ex) ##needed.
          READ TABLE mt_key_noiso TRANSPORTING NO FIELDS WITH KEY
            matnr   = ms_curr_key-matnr
            werks   = ms_curr_key-werks
            plnnr   = ms_curr_key-plnnr
            plnal   = ms_curr_key-plnal
            sapcode = iv_sapcode.

          CHECK NOT sy-subrc IS INITIAL.

          MESSAGE e000(pph_mstr_rcp) WITH ms_curr_key-plnnr ms_curr_key-plnal iv_sapcode INTO DATA(lv_dummy) ##needed.

          MOVE-CORRESPONDING ms_curr_key TO ls_key.
          recipe_raise_message( ls_key ).

          ms_curr_key-sapcode = iv_sapcode.

          INSERT ms_curr_key INTO TABLE mt_key_noiso.

          CHECK ms_curr_key-noiso IS INITIAL.

          ms_curr_key-noiso = abap_true.
      ENDTRY.
    ENDIF.
  ENDMETHOD.


  METHOD recipe_map_data_to_message.
*-------------------------------------------------------------------------------------------------*
* Functional Spec: DS_REF BOM PV MES interface
* Technical Spec:  DS_REF BOM PV MES interface
* Process:         Make- 4.3.2.2  Manage and Release order
*                  S4H Outbound BOM and PV MES
* History ------------------------------------------------------------------------------------------*
* Date       | Change     | Contributor                | Description
*---------------------------------------------------------------------------------------------------*
* DATE_PLACEHOLDER | WI_PLACEHOLDER |  DEVELOPER             | Initial version
* DATE_PLACEHOLDER | 4000008352 |  DEVELOPER             | Add BOM header and item ECN
* DATE_PLACEHOLDER | WI_PLACEHOLDER |  DEVELOPER             | S4H-MES Mapping updates PI5
* DATE_PLACEHOLDER | WI_PLACEHOLDER |  DEVELOPER             | BOM Header validity data
* DATE_PLACEHOLDER | 3200005887 |  DEVELOPER             | MES mapping adjustments BOM component dates
* DATE_PLACEHOLDER | 4000012166 |  DEVELOPER             | PV BOM wrong validity dates for componen
* DATE_PLACEHOLDER | WI_PLACEHOLDER |  DEVELOPER             | PV interface - component segments issue
*---------------------------------------------------------------------------------------------------*



    TYPES: BEGIN OF ty_pc_valid,
             plnkn TYPE plnkn,
             datuv TYPE datuv,
             datub TYPE datub,
           END OF ty_pc_valid.

    CONSTANTS: lc_opr    TYPE ppint_boo_acty_node_type VALUE cl_ppint_soa_mfg_ord_mapping=>c_node_type_operation,
               lc_phs    TYPE ppint_boo_acty_node_type VALUE cl_ppint_soa_mfg_ord_mapping=>c_node_type_phase,
               lc_srs    TYPE ppint_boo_acty_node_type VALUE cl_ppint_soa_mfg_ord_mapping=>c_node_type_secresource,
               lc_pntchd TYPE c LENGTH 6 VALUE cl_ppint_soa_mfg_ord_mapping=>c_rel_type_parent_child_soap. "Parent-Child Relation

    DATA: lt_billofopr TYPE ppint_bill_of_operations_tab,
          ls_billofopr TYPE ppint_bill_of_operations,
          lt_boohdr    TYPE ppint_bill_of_operations_h_tab,
          ls_boohdr    TYPE ppint_bill_of_operations_heade,
          lt_hdr       TYPE cl_pppi_soa_master_recipe=>tt_plko,
          lt_acty      TYPE cl_pppi_soa_master_recipe=>tt_opr,
          lt_tidacty   TYPE cl_pppi_soa_master_recipe=>tt_opr,
          lt_calloc    TYPE cl_pppi_soa_master_recipe=>tt_plmz,
          lt_rel       TYPE cl_pppi_soa_master_recipe=>tt_plab,
          lt_mnhdr     TYPE cl_pppi_soa_master_recipe=>tt_plkz,
          ls_massign   TYPE ppint_boo_matl_assgmt,
          lt_acty_nont TYPE ppint_bill_of_operations_a_tab,
          ls_acty_nont TYPE ppint_mfg_boo_acty_ntwk_elmnts,
          lt_activity  TYPE ppint_bill_of_operations__tab2,
          ls_activity  TYPE ppint_boo_acty_ntwk_time_slice,
          lt_relations TYPE ppint_bill_of_operations_r_tab,
          lt_evnt_rel  TYPE ppint_bill_of_operations_r_tab,
          ls_relations TYPE ppint_boo_relationship,
          lt_compalloc TYPE ppint_bill_of_operations__tab1,
          ls_compalloc TYPE ppint_boo_acty_comp_alloc,
          lv_oprtyp    TYPE ppint_boo_acty_node_type,
          lv_delhdr    TYPE abap_bool,
          ls_phase     TYPE cl_pppi_soa_master_recipe=>ty_phase_key,
          lt_phase     TYPE cl_pppi_soa_master_recipe=>tt_phase,
          ls_rl        TYPE cl_pppi_soa_master_recipe=>ty_rel_key,
          lt_rl        TYPE cl_pppi_soa_master_recipe=>tt_relations,
          "ls_longtext  TYPE esh_sr_ltxt,
          lt_pc_valid  TYPE STANDARD TABLE OF ty_pc_valid,
          ls_pc_valid  LIKE LINE OF lt_pc_valid.

    CLEAR: es_message.


    DATA: BEGIN OF strucksskb  ##needed.
            INCLUDE TYPE ckssk ##needed.
    DATA:   klart TYPE klah-klart,
            class TYPE klah-class.
    DATA: END OF strucksskb.





    IF NOT it_matlassgmt IS INITIAL.
      lt_hdr[] = it_header[].
      lt_acty[] = it_activity[].
      lt_calloc[] = it_compalloc[].
      lt_rel[] = it_relations[].
      lt_mnhdr[] = it_mainheader[].
      lt_tidacty[] = it_activity[].

      SORT: lt_hdr ASCENDING BY billofoperationsgroup billofoperationsvariant,
            lt_mnhdr ASCENDING BY billofoperationsgroup billofoperationsvariant ismarkedfordeletion,
            lt_tidacty ASCENDING BY billofoperationstype billofoperationsgroup boooperationinternalid,
            lt_acty ASCENDING,
            lt_calloc ASCENDING.

      "TO get Single record for each Opr/Phs/SecRes irrespective of Change Numbers.
      DELETE ADJACENT DUPLICATES FROM: lt_tidacty COMPARING billofoperationstype billofoperationsgroup boooperationinternalid,
                                       lt_acty COMPARING ALL FIELDS,
                                       lt_calloc COMPARING ALL FIELDS.

      SORT: lt_acty ASCENDING BY billofoperationstype billofoperationsgroup operation.

      "Loop upon Material Assignment: Each Material Assignment will form one BillOfOperations
      LOOP AT it_matlassgmt ASSIGNING FIELD-SYMBOL(<fs_mapl>).
        CLEAR: ls_billofopr,ls_massign,lt_boohdr,ls_boohdr,lt_compalloc,
          ls_compalloc, ls_activity,lt_activity,ls_relations,lt_relations,
          lv_delhdr,lt_phase,lt_rl,lt_acty_nont,lt_evnt_rel.
        "Header - Time dependent
        ls_billofopr-bill_of_operations_type = <fs_mapl>-billofoperationstype.
        recipe_conversion_exit_alpha_o( EXPORTING iv_input  = <fs_mapl>-billofoperationsgroup
                                      IMPORTING ev_output = ls_billofopr-bill_of_operations_group ).
        recipe_conversion_exit_alpha_o( EXPORTING iv_input  = <fs_mapl>-billofoperationsvariant
                                      IMPORTING ev_output = ls_billofopr-bill_of_operations_variant ).
        map_current_recipe_to_vari( iv_matnr = <fs_mapl>-material iv_werks = <fs_mapl>-plant iv_plnnr = <fs_mapl>-billofoperationsgroup iv_plnal = <fs_mapl>-billofoperationsvariant ).
        "Checks if Deletion Indicator is Marked at Header Level i.e. PLKZ(Applicable across Change Numbers)




        READ TABLE lt_mnhdr TRANSPORTING NO FIELDS
          WITH KEY billofoperationsgroup = <fs_mapl>-billofoperationsgroup
                   billofoperationsvariant = <fs_mapl>-billofoperationsvariant
                   ismarkedfordeletion = abap_true BINARY SEARCH.
        IF NOT sy-subrc IS INITIAL.
          LOOP AT lt_hdr ASSIGNING FIELD-SYMBOL(<fs_plko>)
            WHERE billofoperationsgroup = <fs_mapl>-billofoperationsgroup
            AND billofoperationsvariant = <fs_mapl>-billofoperationsvariant.
            CLEAR: ls_boohdr . "ls_longtext.
            ls_boohdr-bill_of_operations_desc = <fs_plko>-billofoperationsdesc.
            ls_boohdr-bill_of_operations_status = <fs_plko>-billofoperationsstatus.
            ls_boohdr-bill_of_operations_usage = <fs_plko>-billofoperationsusage.
            ls_boohdr-bill_of_operations_plant = <fs_plko>-plant.
            ls_boohdr-boomax_lot_size_quantity-content = <fs_plko>-maximumlotsizequantity.
            ls_boohdr-boomax_lot_size_quantity-unit_code = recipe_convert_unit_sap_to_iso( <fs_plko>-billofoperationsunit ).
            "TIMESTAMP_PLACEHOLDER DEVELOPER
            DATA commercial_unit(3) TYPE c.
            CALL FUNCTION 'CONVERSION_EXIT_CUNIT_OUTPUT'
              EXPORTING
                input          = <fs_plko>-billofoperationsunit
                language       = 'E'
              IMPORTING
                output         = commercial_unit
              EXCEPTIONS
                unit_not_found = 1
                OTHERS         = 2.
            IF sy-subrc EQ 0.
              ls_boohdr-boomax_lot_size_quantity-unit_code = commercial_unit.
            ENDIF.

            ls_boohdr-boomin_lot_size_quantity-content = <fs_plko>-minimumlotsizequantity.
            ls_boohdr-boomin_lot_size_quantity-unit_code = recipe_convert_unit_sap_to_iso( <fs_plko>-billofoperationsunit ).

            CALL FUNCTION 'CONVERSION_EXIT_CUNIT_OUTPUT'
              EXPORTING
                input          = <fs_plko>-billofoperationsunit
                language       = 'E'
              IMPORTING
                output         = commercial_unit
              EXCEPTIONS
                unit_not_found = 1
                OTHERS         = 2.
            IF sy-subrc EQ 0.
              ls_boohdr-boomin_lot_size_quantity-unit_code = commercial_unit.
            ENDIF.


            ls_boohdr-change_number = <fs_plko>-changenumber.
            ls_boohdr-validity_start_date = <fs_plko>-validitystartdate.
            ls_boohdr-validity_end_date = <fs_plko>-validityenddate.
            IF NOT <fs_plko>-longtextlanguagecode IS INITIAL.
              ls_boohdr-long_text-content = <fs_plko>-plainlongtext.
              recipe_conversion_exit_isola_o( EXPORTING iv_input  = <fs_plko>-longtextlanguagecode
                                            IMPORTING ev_output = ls_boohdr-long_text-language_code ).
              ls_boohdr-long_text-mimecode = mc_mimetype.
            ENDIF.
            APPEND ls_boohdr TO lt_boohdr.
          ENDLOOP.
        ELSE.
          "Recipe Marked for Deletion
          lv_delhdr = abap_true.
          "Set Action Code = 03 => Recipe is Deleted
          ls_boohdr-action_code = if_fsbp_const_action_code=>delete.
          APPEND ls_boohdr TO lt_boohdr.
        ENDIF.
        ls_billofopr-bill_of_operations_header = lt_boohdr.
        "Material Assignment when Recipe is not deleted
        IF lv_delhdr IS INITIAL.
          "Converts material to external format
          recipe_convert_material_to_o( EXPORTING iv_input  = <fs_mapl>-material
                                      IMPORTING ev_output = ls_massign-material ).
          ls_massign-plant = <fs_mapl>-plant.
          ls_massign-change_number = <fs_mapl>-changenumber.
          ls_massign-validity_start_date = <fs_mapl>-validitystartdate.
          ls_massign-validity_end_date = <fs_mapl>-validityenddate.
          ls_billofopr-bill_of_operations_material_as = ls_massign.
          "Production Version
          ls_billofopr-production_version = <fs_mapl>-productionversion.




          "Activity Network Element - Time Independent
          LOOP AT lt_tidacty ASSIGNING FIELD-SYMBOL(<fs_tidacty>)
            WHERE billofoperationsgroup = <fs_mapl>-billofoperationsgroup
            AND billofoperationsvariant = <fs_mapl>-billofoperationsvariant.
            CLEAR: ls_relations,lt_compalloc,lv_oprtyp,ls_acty_nont,
                   lt_activity,ls_relations,ls_phase,lt_pc_valid.

            IF NOT <fs_tidacty>-boooperationissecdryrsce IS INITIAL.
              lv_oprtyp = lc_srs.
            ELSEIF NOT <fs_tidacty>-boooperationisphase IS INITIAL.
              lv_oprtyp = lc_phs.
            ELSE.
              lv_oprtyp = lc_opr.
            ENDIF.

            ls_acty_nont-bill_of_operations_node_type = lv_oprtyp.
            ls_acty_nont-bill_of_operations_node_id = <fs_tidacty>-billofoperationstype && <fs_tidacty>-billofoperationsgroup
                                                      && <fs_tidacty>-billofoperationsvariant && <fs_tidacty>-boooperationinternalid.


            "Activity Network Element Time Slices
            LOOP AT lt_acty ASSIGNING FIELD-SYMBOL(<fs_acty>)
              WHERE billofoperationsgroup = <fs_mapl>-billofoperationsgroup
              AND billofoperationsvariant = <fs_mapl>-billofoperationsvariant
              AND boooperationinternalid = <fs_tidacty>-boooperationinternalid.
              CLEAR: ls_activity. "ls_longtext.
              ls_activity-operation = <fs_acty>-operation.
              ls_activity-boooperation_internal_id = <fs_acty>-boooperationinternalid.
              ls_activity-operation_description = <fs_acty>-operationtext.
              ls_activity-validity_start_date = <fs_acty>-validitystartdate.
              ls_activity-validity_end_date = <fs_acty>-validityenddate.

              "TIMESTAMP_PLACEHOLDER DEVELOPER{
              IF ls_activity-validity_end_date = '9999-12-30'.
                ls_activity-validity_end_date  = '9999-12-31'.
              ENDIF.
              "}TIMESTAMP_PLACEHOLDER DEVELOPER



              "Operation Control Profile
              ls_activity-operation_control_profile = build_operation_control_prof( <fs_acty>-operationcontrolprofile ).
              ls_activity-change_number = <fs_acty>-changenumber.
              ls_activity-work_center_internal_id = <fs_acty>-workcenterinternalid.
              ls_activity-work_center = <fs_acty>-workcenter.
              ls_activity-operation_reference_quantity-content = <fs_acty>-operationreferencequantity.
              ls_activity-operation_reference_quantity-unit_code = recipe_convert_unit_sap_to_iso( <fs_acty>-operationunit ).

              CALL FUNCTION 'CONVERSION_EXIT_CUNIT_OUTPUT'
                EXPORTING
                  input          = <fs_acty>-operationunit
                  language       = 'E'
                IMPORTING
                  output         = commercial_unit
                EXCEPTIONS
                  unit_not_found = 1
                  OTHERS         = 2.
              IF sy-subrc EQ 0.
                ls_activity-operation_reference_quantity-unit_code = commercial_unit.
              ENDIF.






              ls_activity-op_qty_to_base_qty_nmrtr = <fs_acty>-opqtytobaseqtynmrtr.
              ls_activity-op_qty_to_base_qty_dnmntr = <fs_acty>-opqtytobaseqtydnmntr.
              ls_activity-factory_calendar = <fs_acty>-factorycalendar.
              ls_activity-operation_setup_type = <fs_acty>-operationsetuptype.
              ls_activity-operation_setup_group = <fs_acty>-operationsetupgroup.
              ls_activity-operation_setup_group_category = <fs_acty>-operationsetupgroupcategory.
              ls_activity-operation_standard_text_code = <fs_acty>-operationstandardtextcode.
              IF NOT <fs_acty>-boooperationissecdryrsce IS INITIAL.
                ls_activity-start_date_offset_duration-content = <fs_acty>-startdateoffsetduration.
                ls_activity-start_date_offset_duration-unit_code =  recipe_convert_unit_sap_to_iso( <fs_acty>-startdateoffsetdurationunit ).


                CALL FUNCTION 'CONVERSION_EXIT_CUNIT_OUTPUT'
                  EXPORTING
                    input          = <fs_acty>-startdateoffsetdurationunit
                    language       = 'E'
                  IMPORTING
                    output         = commercial_unit
                  EXCEPTIONS
                    unit_not_found = 1
                    OTHERS         = 2.
                IF sy-subrc EQ 0.
                  ls_activity-start_date_offset_duration-unit_code = commercial_unit.
                ENDIF.


                ls_activity-end_date_offset_duration-content = <fs_acty>-enddateoffsetduration.
                ls_activity-end_date_offset_duration-unit_code = recipe_convert_unit_sap_to_iso( <fs_acty>-enddateoffsetdurationunit ).


                CALL FUNCTION 'CONVERSION_EXIT_CUNIT_OUTPUT'
                  EXPORTING
                    input          = <fs_acty>-enddateoffsetdurationunit
                    language       = 'E'
                  IMPORTING
                    output         = commercial_unit
                  EXCEPTIONS
                    unit_not_found = 1
                    OTHERS         = 2.
                IF sy-subrc EQ 0.
                  ls_activity-end_date_offset_duration-unit_code = commercial_unit.
                ENDIF.





              ENDIF.


              "TIMESTAMP_PLACEHOLDER DEVELOPER{

***            plnty EQ @<fs_mapl>-billofoperationstype AND
***            plnnr EQ @<fs_mapl>-billofoperationsgroup AND
***            ""plnkn EQ  @<fs_mapl>-billofoperationsvariant AND
***            zaehl EQ @<fs_mapl>-boomatlinternalversioncounter
***            plnty EQ @<fs_tidacty>-billofoperationstype AND  "type
***            plnnr EQ @<fs_tidacty>-billofoperationsgroup AND   "group
***            plnkn EQ @<fs_tidacty>-boooperationinternalid  AND "node
***            zaehl EQ @<fs_tidacty>-booopinternalversioncounter "counter

              SELECT SINGLE phseq , slwid , usr00, usr01, usr02 ,usr03 ,
              usr04 , usr05 ,usr06, usr07, usr08 , usr09 , usr10 , usr11,
              use05 ,use06, use07 ,
              aennr  "TIMESTAMP_PLACEHOLDER DEVELOPER   4000008352

              "FROM plpo
              FROM /rgs/p_s_dcb_prodver_oper2
              WHERE
              plnty EQ @<fs_acty>-billofoperationstype AND  "type
              plnnr EQ @<fs_acty>-billofoperationsgroup AND   "group
              plnkn EQ @<fs_acty>-boooperationinternalid  AND "node
              zaehl EQ @<fs_acty>-booopinternalversioncounter "counter



              INTO @DATA(ls_plpo).
              IF sy-subrc EQ 0.
                ls_activity-crd = ls_plpo-phseq. "TIMESTAMP_PLACEHOLDER DEVELOPER
                ls_activity-usr00 = ls_plpo-usr00.
                ls_activity-usr01 = ls_plpo-usr01.
                ls_activity-usr02 = ls_plpo-usr02.
                ls_activity-usr03 = ls_plpo-usr03.
                ls_activity-usr04 = ls_plpo-usr04.
                ls_activity-usr05 = ls_plpo-usr05.
                ls_activity-usr06 = ls_plpo-usr06.
                ls_activity-usr07 = ls_plpo-usr07.
                ls_activity-usr08 = ls_plpo-usr08.
                ls_activity-usr09 = ls_plpo-usr10.
                ls_activity-usr10 = ls_plpo-usr11.

                ls_activity-use05 = ls_plpo-use05.
                ls_activity-use06 = ls_plpo-use06.
                ls_activity-use07 = ls_plpo-use07.


                ls_activity-slwid = ls_plpo-slwid.

                CALL FUNCTION 'CONVERSION_EXIT_CUNIT_OUTPUT'
                  EXPORTING
                    input          = ls_activity-use04
                    language       = 'E'
                  IMPORTING
                    output         = commercial_unit
                  EXCEPTIONS
                    unit_not_found = 1
                    OTHERS         = 2.
                IF sy-subrc EQ 0.
                  ls_activity-use04 = commercial_unit.
                ENDIF.

                CALL FUNCTION 'CONVERSION_EXIT_CUNIT_OUTPUT'
                  EXPORTING
                    input          = ls_activity-use05
                    language       = 'E'
                  IMPORTING
                    output         = commercial_unit
                  EXCEPTIONS
                    unit_not_found = 1
                    OTHERS         = 2.
                IF sy-subrc EQ 0.
                  ls_activity-use05 = commercial_unit.
                ENDIF.

                CALL FUNCTION 'CONVERSION_EXIT_CUNIT_OUTPUT'
                  EXPORTING
                    input          = ls_activity-use06
                    language       = 'E'
                  IMPORTING
                    output         = commercial_unit
                  EXCEPTIONS
                    unit_not_found = 1
                    OTHERS         = 2.
                IF sy-subrc EQ 0.
                  ls_activity-use06 = commercial_unit.
                ENDIF.


                CALL FUNCTION 'CONVERSION_EXIT_CUNIT_OUTPUT'
                  EXPORTING
                    input          = ls_activity-use07
                    language       = 'E'
                  IMPORTING
                    output         = commercial_unit
                  EXCEPTIONS
                    unit_not_found = 1
                    OTHERS         = 2.
                IF sy-subrc EQ 0.
                  ls_activity-use07 = commercial_unit.
                ENDIF.



                SHIFT ls_activity-usr00 RIGHT DELETING TRAILING space.
                SHIFT ls_activity-usr01 RIGHT DELETING TRAILING space.
                SHIFT ls_activity-usr02 RIGHT DELETING TRAILING space.
                SHIFT ls_activity-usr03 RIGHT DELETING TRAILING space.
                SHIFT ls_activity-usr04 RIGHT DELETING TRAILING space.
                SHIFT ls_activity-use04 RIGHT DELETING TRAILING space.
                SHIFT ls_activity-usr05 RIGHT DELETING TRAILING space.
                SHIFT ls_activity-use05 RIGHT DELETING TRAILING space.
                SHIFT ls_activity-usr06 RIGHT DELETING TRAILING space.
                SHIFT ls_activity-use06 RIGHT DELETING TRAILING space.
                SHIFT ls_activity-usr07 RIGHT DELETING TRAILING space.
                SHIFT ls_activity-use07 RIGHT DELETING TRAILING space.
                SHIFT ls_activity-usr08 RIGHT DELETING TRAILING space.
                SHIFT ls_activity-usr09 RIGHT DELETING TRAILING space.
                SHIFT ls_activity-usr10 RIGHT DELETING TRAILING space.
                SHIFT ls_activity-usr11 RIGHT DELETING TRAILING space.


                SHIFT ls_activity-usr00 LEFT DELETING LEADING space.
                SHIFT ls_activity-usr01 LEFT DELETING LEADING space.
                SHIFT ls_activity-usr02 LEFT DELETING LEADING space.
                SHIFT ls_activity-usr03 LEFT DELETING LEADING space.
                SHIFT ls_activity-usr04 LEFT DELETING LEADING space.
                SHIFT ls_activity-use04 LEFT DELETING LEADING space.
                SHIFT ls_activity-usr05 LEFT DELETING LEADING space.
                SHIFT ls_activity-use05 LEFT DELETING LEADING space.
                SHIFT ls_activity-usr06 LEFT DELETING LEADING space.
                SHIFT ls_activity-use06 LEFT DELETING LEADING space.
                SHIFT ls_activity-usr07 LEFT DELETING LEADING space.
                SHIFT ls_activity-use07 LEFT DELETING LEADING space.
                SHIFT ls_activity-usr08 LEFT DELETING LEADING space.
                SHIFT ls_activity-usr09 LEFT DELETING LEADING space.
                SHIFT ls_activity-usr10 LEFT DELETING LEADING space.
                SHIFT ls_activity-usr11 LEFT DELETING LEADING space.


                TRY.  "TIMESTAMP_PLACEHOLDER DEVELOPER 4000008352 {
                    DATA ls_tcn01            TYPE tcn01.

                    CALL FUNCTION 'TCN01_READ'
                      EXPORTING
                        slwid    = ls_plpo-slwid
                        spras    = sy-langu
                      IMPORTING
                        struct   = ls_tcn01
                      EXCEPTIONS
                        no_entry = 1
                        OTHERS   = 2.
                    IF sy-subrc = 0.
                      ls_activity-swrt0 = ls_tcn01-swrt0.
                      ls_activity-swrt1 = ls_tcn01-swrt1.
                      ls_activity-swrt2 = ls_tcn01-swrt2.
                      ls_activity-swrt3 = ls_tcn01-swrt3.
                      ls_activity-swrt4 = ls_tcn01-swrt4.
                      ls_activity-swrt5 = ls_tcn01-swrt5.
                      ls_activity-swrt6 = ls_tcn01-swrt6.
                      ls_activity-swrt7 = ls_tcn01-swrt7.
                      ls_activity-swrt8 = ls_tcn01-swrt8.
                      ls_activity-swrt9 = ls_tcn01-swrt9.
                      ls_activity-swrt10 = ls_tcn01-swrt10.
                      ls_activity-swrt11 = ls_tcn01-swrt11.

                      SHIFT ls_activity-swrt0 RIGHT DELETING TRAILING space.
                      SHIFT ls_activity-swrt1 RIGHT DELETING TRAILING space.
                      SHIFT ls_activity-swrt2 RIGHT DELETING TRAILING space.
                      SHIFT ls_activity-swrt3 RIGHT DELETING TRAILING space.
                      SHIFT ls_activity-swrt4 RIGHT DELETING TRAILING space.
                      SHIFT ls_activity-swrt5 RIGHT DELETING TRAILING space.
                      SHIFT ls_activity-swrt6 RIGHT DELETING TRAILING space.
                      SHIFT ls_activity-swrt7 RIGHT DELETING TRAILING space.
                      SHIFT ls_activity-swrt8 RIGHT DELETING TRAILING space.
                      SHIFT ls_activity-swrt9 RIGHT DELETING TRAILING space.
                      SHIFT ls_activity-swrt10 RIGHT DELETING TRAILING space.
                      SHIFT ls_activity-swrt11 RIGHT DELETING TRAILING space.

                      SHIFT ls_activity-swrt0 LEFT DELETING LEADING space.
                      SHIFT ls_activity-swrt1 LEFT DELETING LEADING space.
                      SHIFT ls_activity-swrt2 LEFT DELETING LEADING space.
                      SHIFT ls_activity-swrt3 LEFT DELETING LEADING space.
                      SHIFT ls_activity-swrt4 LEFT DELETING LEADING space.
                      SHIFT ls_activity-swrt5 LEFT DELETING LEADING space.
                      SHIFT ls_activity-swrt6 LEFT DELETING LEADING space.
                      SHIFT ls_activity-swrt7 LEFT DELETING LEADING space.
                      SHIFT ls_activity-swrt8 LEFT DELETING LEADING space.
                      SHIFT ls_activity-swrt9 LEFT DELETING LEADING space.
                      SHIFT ls_activity-swrt10 LEFT DELETING LEADING space.
                      SHIFT ls_activity-swrt11 LEFT DELETING LEADING space.

                    ENDIF.

                  CATCH cx_root INTO DATA(ex_object_cx_root).
                    DATA(ex_text) = ex_object_cx_root->get_text( ) ##needed.
                    DATA(ex_text_long) = ex_object_cx_root->get_longtext( ) ##needed.
                ENDTRY.
                "} TIMESTAMP_PLACEHOLDER DEVELOPER 4000008352




              ENDIF.









              "}TIMESTAMP_PLACEHOLDER DEVELOPER

              "ls_activity-crd
              "ls_activity


              "}TIMESTAMP_PLACEHOLDER DEVELOPER

              "Standard Value Key + Standard value formulas
              IF NOT <fs_acty>-workcenterinternalid IS INITIAL
                 AND ( NOT <fs_acty>-boooperationisphase IS INITIAL OR NOT <fs_acty>-boooperationissecdryrsce IS INITIAL ).
                DATA(ls_tc21) = recipe_read_standard_value_key( <fs_acty>-standardworkformulaparamgroup ).
                ls_activity-standard_work_formula_param_gr-standard_work_formula_param_gr = <fs_acty>-standardworkformulaparamgroup.
                ls_activity-standard_work_formula_param_gr-work_center_formula_param1 =
                  build_wrk_cntr_frmla_param(
                    EXPORTING
                      iv_crhd_par     = <fs_acty>-standardworkformulaparam1
                      iv_tc21_par     = ls_tc21-par01
                      iv_crhd_werks   = <fs_acty>-plant
                      iv_plpo_vgwrt   = <fs_acty>-standardworkquantity1
                      iv_plpo_vgwrteh = <fs_acty>-standardworkquantityunit1
                      iv_plpo_lstar   = <fs_acty>-costctractivitytype1 ).
                ls_activity-standard_work_formula_param_gr-work_center_formula_param2 =
                  build_wrk_cntr_frmla_param(
                    EXPORTING
                      iv_crhd_par     = <fs_acty>-standardworkformulaparam2
                      iv_tc21_par     = ls_tc21-par02
                      iv_crhd_werks   = <fs_acty>-plant
                      iv_plpo_vgwrt   = <fs_acty>-standardworkquantity2
                      iv_plpo_vgwrteh = <fs_acty>-standardworkquantityunit2
                      iv_plpo_lstar   = <fs_acty>-costctractivitytype2 ).
                ls_activity-standard_work_formula_param_gr-work_center_formula_param3 =
                  build_wrk_cntr_frmla_param(
                  EXPORTING
                      iv_crhd_par     = <fs_acty>-standardworkformulaparam3
                      iv_tc21_par     = ls_tc21-par03
                      iv_crhd_werks   = <fs_acty>-plant
                      iv_plpo_vgwrt   = <fs_acty>-standardworkquantity3
                      iv_plpo_vgwrteh = <fs_acty>-standardworkquantityunit3
                      iv_plpo_lstar   = <fs_acty>-costctractivitytype3 ).
                ls_activity-standard_work_formula_param_gr-work_center_formula_param4 =
                  build_wrk_cntr_frmla_param(
                  EXPORTING
                      iv_crhd_par     = <fs_acty>-standardworkformulaparam4
                      iv_tc21_par     = ls_tc21-par04
                      iv_crhd_werks   = <fs_acty>-plant
                      iv_plpo_vgwrt   = <fs_acty>-standardworkquantity4
                      iv_plpo_vgwrteh = <fs_acty>-standardworkquantityunit4
                      iv_plpo_lstar   = <fs_acty>-costctractivitytype4 ).
                ls_activity-standard_work_formula_param_gr-work_center_formula_param5 =
                  build_wrk_cntr_frmla_param(
                  EXPORTING
                      iv_crhd_par     = <fs_acty>-standardworkformulaparam5
                      iv_tc21_par     = ls_tc21-par05
                      iv_crhd_werks   = <fs_acty>-plant
                      iv_plpo_vgwrt   = <fs_acty>-standardworkquantity5
                      iv_plpo_vgwrteh = <fs_acty>-standardworkquantityunit5
                      iv_plpo_lstar   = <fs_acty>-costctractivitytype5 ).
                ls_activity-standard_work_formula_param_gr-work_center_formula_param6 =
                  build_wrk_cntr_frmla_param(
                  EXPORTING
                      iv_crhd_par     = <fs_acty>-standardworkformulaparam6
                      iv_tc21_par     = ls_tc21-par06
                      iv_crhd_werks   = <fs_acty>-plant
                      iv_plpo_vgwrt   = <fs_acty>-standardworkquantity6
                      iv_plpo_vgwrteh = <fs_acty>-standardworkquantityunit6
                      iv_plpo_lstar   = <fs_acty>-costctractivitytype6 ).
              ENDIF.
              IF NOT <fs_acty>-longtextlanguagecode IS INITIAL.
                ls_activity-long_text-content = <fs_acty>-plainlongtext.
                recipe_conversion_exit_isola_o( EXPORTING iv_input  = <fs_acty>-longtextlanguagecode
                                              IMPORTING ev_output = ls_activity-long_text-language_code ).
                ls_activity-long_text-mimecode = mc_mimetype.
              ENDIF.


              "TIMESTAMP_PLACEHOLDER DEVELOPER
              READ TABLE dcb_marc_tab WITH KEY phseq = ls_activity-crd  INTO DATA(dcb_marc) ##needed.
              DATA(kill_em) = sy-subrc.


              CLEAR kill_em. ""TIMESTAMP_PLACEHOLDER DEVELOPER


              IF kill_em EQ 0.


                IF NOT <fs_acty>-boooperationisphase IS INITIAL.
                  CLEAR: ls_phase.
                  ls_phase = CORRESPONDING #( <fs_acty> MAPPING plnnr = billofoperationsgroup
                                                                plnal = billofoperationsvariant
                                                                plnkn = boooperationinternalid
                                                                datuv = validitystartdate
                                                                datub = validityenddate ).
                  APPEND ls_phase TO lt_phase.
                ENDIF.



                APPEND ls_activity TO lt_activity.


                IF <fs_acty>-boooperationisphase IS NOT INITIAL OR <fs_acty>-boooperationissecdryrsce IS NOT INITIAL.
                  ls_pc_valid = CORRESPONDING #( <fs_acty> MAPPING plnkn = boooperationinternalid
                                                                   datuv = validitystartdate
                                                                   datub = validityenddate ).
                  APPEND: ls_pc_valid TO lt_pc_valid.
                  CLEAR: ls_pc_valid.
                ENDIF.




              ENDIF . "killem  "TIMESTAMP_PLACEHOLDER DEVELOPER
            ENDLOOP.

            ls_acty_nont-bill_of_operations_activity_ne = lt_activity.


            "Componenet Allocation to Operation or Phase
            "SORT lt_calloc BY  ASCENDING. "TIMESTAMP_PLACEHOLDER DEVELOPER

            DATA(lt_calloc_lines) =  lines( lt_calloc ).

            LOOP AT lt_calloc ASSIGNING FIELD-SYMBOL(<fs_comp>)
              WHERE billofoperationsgroup = <fs_tidacty>-billofoperationsgroup
                AND billofoperationsvariant = <fs_tidacty>-billofoperationsvariant
                AND boooperationinternalid = <fs_tidacty>-boooperationinternalid
                AND material = <fs_mapl>-material
                AND plant = <fs_mapl>-plant
                AND productionversion = <fs_mapl>-productionversion

              .
              CLEAR: ls_compalloc.
              ls_compalloc-validity_start_date = <fs_comp>-validitystartdate.
              ls_compalloc-validity_end_date = <fs_comp>-validityenddate.
              IF ls_compalloc-validity_end_date = '99991230'.
                ls_compalloc-validity_end_date  = '99991231'.
              ENDIF.


              ls_compalloc-change_number = <fs_comp>-changenumber.
              ls_compalloc-bill_of_material_category = <fs_comp>-billofmaterialcategory.
              ls_compalloc-bill_of_material = <fs_comp>-billofmaterial.
              recipe_conversion_exit_alpha_o( EXPORTING iv_input  = <fs_comp>-billofmaterialvariant
                                            IMPORTING ev_output = ls_compalloc-bill_of_material_variant ).
              ls_compalloc-bill_of_material_variant_usage = <fs_comp>-billofmaterialvariantusage.
              ls_compalloc-bill_of_material_item_category = <fs_comp>-billofmaterialitemcategory.
              ls_compalloc-bill_of_material_item_node_num = <fs_comp>-billofmaterialitemnodenumber.
              ls_compalloc-bill_of_material_item_number = <fs_comp>-billofmaterialitemnumber.
              recipe_convert_material_to_o( EXPORTING iv_input  = <fs_comp>-billofmaterialcomponent
                                          IMPORTING ev_output = ls_compalloc-bill_of_material_component ).
              ls_compalloc-bill_of_material_item_quantity-content = <fs_comp>-billofmaterialitemquantity.
              ls_compalloc-bill_of_material_item_quantity-unit_code = recipe_convert_unit_sap_to_iso( <fs_comp>-billofmaterialitemunit ).


              CALL FUNCTION 'CONVERSION_EXIT_CUNIT_OUTPUT'
                EXPORTING
                  input          = <fs_comp>-billofmaterialitemunit
                  language       = 'E'
                IMPORTING
                  output         = commercial_unit
                EXCEPTIONS
                  unit_not_found = 1
                  OTHERS         = 2.
              IF sy-subrc EQ 0.
                ls_compalloc-bill_of_material_item_quantity-unit_code = commercial_unit.
              ENDIF.


              ls_compalloc-matl_comp_is_marked_for_backfl = <fs_comp>-matlcompismarkedforbackflush.


              " BILLOFMATERIALITEMNODENUMBER    from CDS is INCORRECT as stated by SAP Support "TIMESTAMP_PLACEHOLDER DEVELOPER
              "TIMESTAMP_PLACEHOLDER DEVELOPER{
              DATA(logic_switch_cs_bt) = 'X'. "TIMESTAMP_PLACEHOLDER DEVELOPER

              IF logic_switch_cs_bt EQ 'X'.

                CLEAR logic_switch_cs_bt.

*                DATA: o1 TYPE c1typbom.
*                DATA: o2 TYPE c2typbom.
                "DATA o1_stpob  TYPE cs01_stpob_tab.

                FIELD-SYMBOLS: <o1_stpob> TYPE cs01_stpob_tab.

                DATA edatub    TYPE sy-datum.
                DATA edatuv    TYPE sy-datum.
                DATA estlal    TYPE stas-stlal.
                DATA estlnr    TYPE stpo-stlnr.
                DATA estlty    TYPE stpo-stlty.
                DATA no_buffer TYPE csdata-xfeld ##needed.

                estlnr =  <fs_comp>-billofmaterial.
                estlty =  <fs_comp>-billofmaterialcategory.
                estlal =  <fs_comp>-billofmaterialvariant. "Alternative BOM


                edatub = sy-datum.
                edatuv = sy-datum.

                " !!!!!!!!
                "TIMESTAMP_PLACEHOLDER DEVELOPER 4000012166{


                edatub =  <fs_comp>-validitystartdate.
                edatuv =  <fs_comp>-validityenddate.


                "}TIMESTAMP_PLACEHOLDER DEVELOPER 4000012166

                "hook to CS03 retrival
                CALL FUNCTION 'CS_BT_POSITION_READ'
                  EXPORTING
                    edatub      = edatub
                    edatuv      = edatuv
                    estlal      = estlal
                    estlnr      = estlnr
                    estlty      = estlty
                    no_buffer   = 'X'
                  EXCEPTIONS
                    key_invalid = 1
                    pos_invalid = 2
                    OTHERS      = 3.
                IF sy-subrc EQ 0.

                  ASSIGN ('(SAPLCSBT)O1-STPOB') TO <o1_stpob>.  "CS03 retrival
                  IF sy-subrc EQ 0.

                    "READ TABLE <o1_stpob> WITH KEY  posnr = <fs_comp>-billofmaterialitemnumber INTO DATA(o1_stpob).
                    READ TABLE <o1_stpob> WITH KEY  stpoz = <fs_comp>-bomiteminternalchangecount INTO DATA(o1_stpob). "20220628-2321 !!!!

                    IF sy-subrc EQ 0.
                      ls_compalloc-component_scrap_in_percent =  o1_stpob-ausch. "scarap
                      SHIFT ls_compalloc-component_scrap_in_percent RIGHT DELETING TRAILING space.
                      SHIFT ls_compalloc-component_scrap_in_percent LEFT DELETING LEADING space.
                      ls_compalloc-fixed_quantity   = o1_stpob-fmeng.

                      ls_compalloc-bom_item_ecn     = o1_stpob-aennr.   "TIMESTAMP_PLACEHOLDER DEVELOPER 4000008352  Add BOM header and item ECN
                      SHIFT  ls_compalloc-bom_item_ecn RIGHT DELETING TRAILING space.
                      SHIFT  ls_compalloc-bom_item_ecn LEFT DELETING LEADING space.


                      ls_compalloc-bom_item_ecn_to  = o1_stpob-ecn_to.  "20220420-1145
                      SHIFT  ls_compalloc-bom_item_ecn_to RIGHT DELETING TRAILING space.
                      SHIFT  ls_compalloc-bom_item_ecn_to LEFT DELETING LEADING space.
                      "TIMESTAMP_PLACEHOLDER DEVELOPER

                      "TIMESTAMP_PLACEHOLDER DEVELOPER

                      "TIMESTAMP_PLACEHOLDER DEVELOPER{
                      IF sy-tabix < lt_calloc_lines.
                        o1_stpob-valid_to = o1_stpob-valid_to - 1.
                      ENDIF.
                      "}TIMESTAMP_PLACEHOLDER DEVELOPER

                      "TIMESTAMP_PLACEHOLDER DEVELOPER{
                      ls_compalloc-bom_item_validity_start_date =   |{  o1_stpob-datuv DATE = ISO }|.
                      ls_compalloc-bom_item_validity_end_date   =   |{ o1_stpob-valid_to DATE = ISO }|.
                      "}TIMESTAMP_PLACEHOLDER DEVELOPER

                      IF  ls_compalloc-bom_item_validity_end_date = '9999-12-30'.
                        ls_compalloc-bom_item_validity_end_date  = '9999-12-31'.
                      ENDIF.
                      "TIMESTAMP_PLACEHOLDER DEVELOPER{
                      IF  ls_compalloc-validity_end_date = '99991230'.
                        ls_compalloc-validity_end_date   = '99991231'.
                      ENDIF.
                      "}TIMESTAMP_PLACEHOLDER DEVELOPER

                      logic_switch_cs_bt = 'X'.
                      "TIMESTAMP_PLACEHOLDER DEVELOPER{
                      DATA: bomitemkv TYPE /rgs/p_dcb_pv_bom_item_kv.
                      DATA: bomitemkv_tab TYPE STANDARD TABLE OF /rgs/p_dcb_pv_bom_item_kv.

                      bomitemkv-key = 'MLTBTCH_RES'.
                      bomitemkv-sequence = '1'.
                      bomitemkv-content = o1_stpob-yy1tp_dcb_mltbtch_bmi.
                      APPEND bomitemkv TO bomitemkv_tab.
                      CLEAR bomitemkv.

                      bomitemkv-key = 'WEIGHING_TP_RES'.
                      bomitemkv-sequence = '1'.
                      bomitemkv-content = o1_stpob-yy1tp_dcb_weighing_tp_bmi.
                      APPEND bomitemkv TO bomitemkv_tab.
                      CLEAR bomitemkv.

                      ls_compalloc-/rgs/p_dcb_pv_bom_item_kv = bomitemkv_tab.
                      CLEAR  bomitemkv_tab.

                      "}TIMESTAMP_PLACEHOLDER DEVELOPER



                      UNASSIGN <o1_stpob>.
                    ENDIF.
                  ENDIF. " ASSIGN ('(SAPLCSBT)O1-STPOB')

                ENDIF.
              ENDIF. "IF logic_switch_cs_bt EQ 'X'.


              "}TIMESTAMP_PLACEHOLDER DEVELOPER





              IF logic_switch_cs_bt NE 'X'.     "TIMESTAMP_PLACEHOLDER DEVELOPER WI_PLACEHOLDER disabled

                IF <fs_comp>-billofmaterialcomponent IS NOT INITIAL. "TIMESTAMP_PLACEHOLDER DEVELOPER
                  "TIMESTAMP_PLACEHOLDER DEVELOPER{
                  SELECT   stlty, stlnr, stlkn, stpoz, datuv , ausch , fmeng ,
                    valid_to,  "date to ?
                     ecn_to,   ""TIMESTAMP_PLACEHOLDER DEVELOPER 4000007073
                     aennr,    "TIMESTAMP_PLACEHOLDER DEVELOPER 4000008352
                     idnrk,
                     posnr,
                     menge,
                     meins,
                     andat,
                     aedat

                    "FROM stpo
                    FROM /rgs/p_s_dcb_stpo   "TIMESTAMP_PLACEHOLDER DEVELOPER
                    INTO TABLE @DATA(stpo_tab)
                    WHERE  stlty = @<fs_comp>-billofmaterialcategory
                       AND stlnr = @<fs_comp>-billofmaterial    " type STNUM
                       ""TIMESTAMP_PLACEHOLDER DEVELOPER AND stlkn = @<fs_comp>-billofmaterialitemnodenumber  "node
                       AND idnrk = @<fs_comp>-billofmaterialcomponent
                       AND posnr = @<fs_comp>-billofmaterialitemnumber
                       AND lkenz NE 'X'
                       AND NOT (
                         valid_to    <  @<fs_comp>-validitystartdate  "valid_from
                      OR datuv  >   @<fs_comp>-validityenddate  )
                      AND menge EQ @<fs_comp>-billofmaterialitemquantity
                      AND meins EQ @<fs_comp>-billofmaterialitemunit

                      AND stpoz EQ @<fs_comp>-bomiteminternalchangecount "TIMESTAMP_PLACEHOLDER DEVELOPER !!!

                  .
                  IF sy-subrc EQ 0.
                    "SORT stpo_tab BY stlty  stlnr stlkn  stpoz DESCENDING. "#EC CI_SORTLOOP
                    "TIMESTAMP_PLACEHOLDER DEVELOPER{
                    DELETE stpo_tab WHERE valid_to < sy-datum.  "remove expired     WI_PLACEHOLDER
                    "SORT stpo_tab BY  aedat andat DESCENDING.   "removed           WI_PLACEHOLDER
                    SORT stpo_tab BY  datuv ASCENDING.           " Valid-From Date  WI_PLACEHOLDER

                    "}20221215-1359


                    READ TABLE stpo_tab INDEX 1 INTO DATA(l_stpo).


                    rc = sy-subrc.

*                    WHILE l_stpo-ecn_to IS NOT INITIAL.
*                      READ TABLE stpo_tab WITH KEY aennr = l_stpo-ecn_to INTO l_stpo.
*                      IF sy-index GE 999.
*                        EXIT.
*                      ENDIF.
*                    ENDWHILE.

                    IF rc EQ 0.
                      ls_compalloc-component_scrap_in_percent = l_stpo-ausch. "scarap
                      SHIFT ls_compalloc-component_scrap_in_percent RIGHT DELETING TRAILING space.
                      SHIFT ls_compalloc-component_scrap_in_percent LEFT DELETING LEADING space.
                      ls_compalloc-fixed_quantity = l_stpo-fmeng.

                      ls_compalloc-bom_item_ecn = l_stpo-aennr. "TIMESTAMP_PLACEHOLDER DEVELOPER 4000008352  Add BOM header and item ECN
                      SHIFT ls_compalloc-bom_item_ecn   RIGHT DELETING TRAILING space.
                      SHIFT ls_compalloc-bom_item_ecn   LEFT DELETING LEADING space.

                      ls_compalloc-bom_item_ecn_to  = l_stpo-ecn_to.  "20220420-1145
                      SHIFT ls_compalloc-bom_item_ecn_to  RIGHT DELETING TRAILING space.
                      SHIFT ls_compalloc-bom_item_ecn_to  LEFT DELETING LEADING space.



                    ENDIF.
                  ENDIF.

                  "}TIMESTAMP_PLACEHOLDER DEVELOPER
                ENDIF. " IF <fs_comp>-billofmaterialcomponent IS NOT INITIAL. "TIMESTAMP_PLACEHOLDER DEVELOPER
              ENDIF.
              "TIMESTAMP_PLACEHOLDER DEVELOPER{
              IF ls_compalloc-bom_item_validity_end_date = '9999-12-30'.
                ls_compalloc-bom_item_validity_end_date  = '9999-12-31'.
              ENDIF.
              IF ls_compalloc-validity_end_date = '99991230'.
                ls_compalloc-validity_end_date  = '99991231'.
              ENDIF.
              "}TIMESTAMP_PLACEHOLDER DEVELOPER
              APPEND ls_compalloc TO lt_compalloc.
            ENDLOOP.


            "TIMESTAMP_PLACEHOLDER DEVELOPER{   PV interface - component segments issue WI_PLACEHOLDER
            DELETE lt_compalloc WHERE bom_item_validity_start_date IS INITIAL.
            DELETE lt_compalloc WHERE bom_item_validity_end_date   IS INITIAL.
            "TIMESTAMP_PLACEHOLDER DEVELOPER{   PV interface - component segments issue WI_PLACEHOLDER


            SORT lt_compalloc BY bill_of_material_item_number ASCENDING. "TIMESTAMP_PLACEHOLDER DEVELOPER


            ls_acty_nont-bill_of_operations_activity_co = lt_compalloc.


            "Operation to Phase Virtual Relations
            "Operation to SecdryRsce Virtual Relations
            "Phase to SecdryRsce Virtual Relations
            IF <fs_acty>-boooperationisphase IS NOT INITIAL OR <fs_acty>-boooperationissecdryrsce IS NOT INITIAL.
              SELECT SINGLE plnkn, MIN( datuv ) AS datuv, MAX( datub ) AS datub
                FROM @lt_pc_valid AS itab
                GROUP BY plnkn
                INTO @DATA(ls_actual_valid).
              rc = sy-subrc.
              IF NOT <fs_tidacty>-boooperationisphase IS INITIAL.
                ls_relations-predecessor_boonode_type = lc_opr.
                ls_relations-predecessor_boonode_id = <fs_tidacty>-billofoperationstype && <fs_tidacty>-billofoperationsgroup
                                                      && <fs_tidacty>-billofoperationsvariant && <fs_tidacty>-boophasesuperioropinternalid.
                ls_relations-successor_boonode_type = lc_phs.
                ls_relations-successor_boonode_id = <fs_tidacty>-billofoperationstype && <fs_tidacty>-billofoperationsgroup
                                                      && <fs_tidacty>-billofoperationsvariant && <fs_tidacty>-boooperationinternalid.
                ls_relations-boorelationship_type = lc_pntchd.
                ls_relations-validity_start_date = ls_actual_valid-datuv.
                ls_relations-validity_end_date = ls_actual_valid-datub.
                "TIMESTAMP_PLACEHOLDER DEVELOPER{
                IF ls_relations-validity_end_date = '9999-12-30'.
                  ls_relations-validity_end_date  = '9999-12-31'.
                ENDIF.
                "}TIMESTAMP_PLACEHOLDER DEVELOPER



                APPEND ls_relations TO lt_relations.
              ENDIF.
              IF NOT <fs_tidacty>-boooperationissecdryrsce IS INITIAL.
                IF NOT <fs_tidacty>-boosuperioroperationisphase IS INITIAL.
                  ls_relations-predecessor_boonode_type = lc_phs.
                ELSE.
                  ls_relations-predecessor_boonode_type = lc_opr.
                ENDIF.
                ls_relations-predecessor_boonode_id = <fs_tidacty>-billofoperationstype && <fs_tidacty>-billofoperationsgroup
                                                      && <fs_tidacty>-billofoperationsvariant && <fs_tidacty>-superioroperationinternalid.
                ls_relations-successor_boonode_type = lc_srs.
                ls_relations-successor_boonode_id = <fs_tidacty>-billofoperationstype && <fs_tidacty>-billofoperationsgroup
                                                      && <fs_tidacty>-billofoperationsvariant && <fs_tidacty>-boooperationinternalid.
                ls_relations-boorelationship_type = lc_pntchd.
                ls_relations-validity_start_date = ls_actual_valid-datuv.
                ls_relations-validity_end_date = ls_actual_valid-datub.
                "TIMESTAMP_PLACEHOLDER DEVELOPER{
                IF ls_relations-validity_end_date = '9999-12-30'.
                  ls_relations-validity_end_date  = '9999-12-31'.
                ENDIF.
                "}TIMESTAMP_PLACEHOLDER DEVELOPER
                APPEND ls_relations TO lt_relations.
              ENDIF.
              CLEAR: ls_actual_valid.
            ENDIF.


            IF kill_em EQ 0. "TIMESTAMP_PLACEHOLDER DEVELOPER
              APPEND ls_acty_nont TO lt_acty_nont.
            ENDIF.


            CLEAR kill_em.  "TIMESTAMP_PLACEHOLDER DEVELOPER

          ENDLOOP.

          "Relationship on DB for Master Recipe
          LOOP AT lt_rel ASSIGNING FIELD-SYMBOL(<fs_plab>)
            WHERE billofoperationstype = mc_billofoperationstype
            AND prdcssrboogroup = <fs_mapl>-billofoperationsgroup
            AND prdcssrboovariant = <fs_mapl>-billofoperationsvariant
            AND succssrboogroup = <fs_mapl>-billofoperationsgroup
            AND succssrboovariant = <fs_mapl>-billofoperationsvariant.
            CLEAR: ls_relations,ls_rl.
            ls_relations-predecessor_boonode_type = lc_phs.
            ls_relations-predecessor_boonode_id = <fs_plab>-billofoperationstype && <fs_plab>-prdcssrboogroup && <fs_plab>-prdcssrboovariant && <fs_plab>-prdcssrbooopinternalid.
            ls_relations-successor_boonode_type = lc_phs.
            ls_relations-successor_boonode_id = <fs_plab>-billofoperationstype && <fs_plab>-succssrboogroup && <fs_plab>-succssrboovariant && <fs_plab>-succssrbooopinternalid.
            ls_relations-boorelationship_type = get_relationship_type( <fs_plab>-boorelationshiptype ).
            ls_relations-validity_start_date = <fs_plab>-validitystartdate.
            ls_relations-validity_end_date = <fs_plab>-validityenddate.
            ls_relations-change_number = <fs_plab>-changenumber.
            ls_relations-factory_calendar = <fs_plab>-factorycalendar.
            ls_relations-work_center_internal_id = <fs_plab>-workcenterinternalid.
            ls_relations-work_center = <fs_plab>-workcenter.
            ls_relations-work_center_plant = <fs_plab>-plant.
            ls_relations-time_intvl_btwn_relshp-content = <fs_plab>-timeintvlbtwnrelshp.
            ls_relations-time_intvl_btwn_relshp-unit_code = recipe_convert_unit_sap_to_iso( <fs_plab>-timeintvlbtwnrelshpunit ).

            CALL FUNCTION 'CONVERSION_EXIT_CUNIT_OUTPUT'
              EXPORTING
                input          = <fs_plab>-timeintvlbtwnrelshpunit
                language       = 'E'
              IMPORTING
                output         = commercial_unit
              EXCEPTIONS
                unit_not_found = 1
                OTHERS         = 2.
            IF sy-subrc EQ 0.
              ls_relations-time_intvl_btwn_relshp-unit_code = commercial_unit.
            ENDIF.

            ls_relations-max_time_intvl_btwn_relshp-content = <fs_plab>-maxtimeintvlbtwnrelshp.
            ls_relations-max_time_intvl_btwn_relshp-unit_code = recipe_convert_unit_sap_to_iso( <fs_plab>-timeintvlbtwnrelshpunit ).

            CALL FUNCTION 'CONVERSION_EXIT_CUNIT_OUTPUT'
              EXPORTING
                input          = <fs_plab>-timeintvlbtwnrelshpunit
                language       = 'E'
              IMPORTING
                output         = commercial_unit
              EXCEPTIONS
                unit_not_found = 1
                OTHERS         = 2.
            IF sy-subrc EQ 0.
              ls_relations-max_time_intvl_btwn_relshp-unit_code = commercial_unit.
            ENDIF.




            APPEND ls_relations TO lt_relations.
            ls_rl-plnnr_vor = <fs_plab>-prdcssrboogroup.
            ls_rl-plnal_vor = <fs_plab>-prdcssrboovariant.
            ls_rl-plnkn_vor = <fs_plab>-prdcssrbooopinternalid.
            ls_rl-plnnr_nch = <fs_plab>-succssrboogroup.
            ls_rl-plnal_nch = <fs_plab>-succssrboovariant.
            ls_rl-plnkn_nch = <fs_plab>-succssrbooopinternalid.
            ls_rl-aobky = <fs_plab>-boorelationshiptype.
            ls_rl-aobar = <fs_plab>-networkactivityrelationtype.
            ls_rl-datuv = <fs_plab>-validitystartdate.
            ls_rl-datub = <fs_plab>-validityenddate.
            APPEND ls_rl TO lt_rl.
          ENDLOOP.



          "Determine Phases linked to Start Event and End Events.
          build_master_recipe_rel(
            EXPORTING
              iv_plnnr         = <fs_mapl>-billofoperationsgroup
              iv_plnal         = <fs_mapl>-billofoperationsvariant
              it_phases        = lt_phase
              it_relations     = lt_rl
            IMPORTING
              et_events        = lt_evnt_rel ).

          IF NOT lt_evnt_rel IS INITIAL.
            APPEND LINES OF lt_evnt_rel TO lt_relations.
            "Create 'Event Start' node
            READ TABLE lt_evnt_rel ASSIGNING FIELD-SYMBOL(<fs_evnt_rel>)
              WITH KEY predecessor_boonode_type = mc_startevent.
            IF sy-subrc IS INITIAL.
              APPEND INITIAL LINE TO lt_acty_nont ASSIGNING FIELD-SYMBOL(<fs_acty_ntwk>).
              <fs_acty_ntwk>-bill_of_operations_node_id = <fs_evnt_rel>-predecessor_boonode_id.
              <fs_acty_ntwk>-bill_of_operations_node_type = mc_startevent.
            ENDIF.
            UNASSIGN: <fs_evnt_rel>,<fs_acty_ntwk>.
            "Create 'Event End' node
            READ TABLE lt_evnt_rel ASSIGNING <fs_evnt_rel>
              WITH KEY successor_boonode_type = mc_endevent.
            IF sy-subrc IS INITIAL.
              APPEND INITIAL LINE TO lt_acty_nont ASSIGNING <fs_acty_ntwk>.
              <fs_acty_ntwk>-bill_of_operations_node_id = <fs_evnt_rel>-successor_boonode_id.
              <fs_acty_ntwk>-bill_of_operations_node_type = mc_endevent.
            ENDIF.
          ENDIF.

          ls_billofopr-bill_of_operations_activity_ne = lt_acty_nont.
          ls_billofopr-bill_of_operations_relationshi = lt_relations.
        ENDIF.

        IF NOT ms_curr_key-noiso IS INITIAL.
          CONTINUE.
        ENDIF.
        APPEND ls_billofopr TO lt_billofopr.
      ENDLOOP.

      SORT: lt_billofopr ASCENDING.
      DELETE ADJACENT DUPLICATES FROM: lt_billofopr COMPARING ALL FIELDS.

      DATA(lv_count) = lines( lt_billofopr ).

      DATA(rgs_verbose_recipe) = space. "TIMESTAMP_PLACEHOLDER DEVELOPER
      IF rgs_verbose_recipe EQ 'X'. " abap_true.'
        MESSAGE s001(pph_mstr_rcp) WITH lv_count INTO DATA(lv_dummy) ##needed.

        mo_drf_appl_log->add_msg(
          EXPORTING
            iv_msgty   = sy-msgty
            iv_msgno   = sy-msgno
            iv_msgid   = sy-msgid
            iv_msgv1   = sy-msgv1 ).

      ENDIF.

      es_message-bill_of_operations = lt_billofopr.
    ENDIF.

    IF lv_count IS INITIAL.
      MESSAGE e002(pph_mstr_rcp) INTO lv_dummy.

      mo_drf_appl_log->add_msg(
        EXPORTING
          iv_msgty   = sy-msgty
          iv_msgno   = sy-msgno
          iv_msgid   = sy-msgid
          iv_msgv1   = sy-msgv1 ).
    ENDIF.
  ENDMETHOD.


  METHOD recipe_raise_message.
    DATA: ls_cont TYPE bal_s_cont.

    ls_cont = mc_key_structure.

    CONCATENATE is_key-matnr is_key-werks is_key-plnnr is_key-plnal INTO ls_cont-value RESPECTING BLANKS.

    CALL METHOD mo_drf_appl_log->add_msg
      EXPORTING
        iv_msgty   = sy-msgty                " Message Category
        iv_msgno   = sy-msgno                " Message Number
        iv_msgid   = sy-msgid                " Message Identification
        iv_msgv1   = sy-msgv1                " Message Variable
        iv_msgv2   = sy-msgv2                " Message Variable
        iv_msgv3   = sy-msgv3                " Message Variable
        iv_msgv4   = sy-msgv4                " Message Variable
        is_context = ls_cont.
  ENDMETHOD.


  METHOD recipe_read_complete_data.

*-----------------------------------------------------------------------------------------*
* Functional Spec: DS_REF BOM PV MES interface
* Technical Spec:  DS_REF BOM PV MES interface
* Process:         Make- 4.3.2.2  Manage and Release order
*                  S4H Outbound BOM and PV MES
* History ---------------------------------------------------------------------------------*
* Date       | Change     | Contributor                | Description
*------------------------------------------------------------------------------------------*
* DATE_PLACEHOLDER | WI_PLACEHOLDER |  DEVELOPER             | Initial version
* DATE_PLACEHOLDER | 4000008352 |  DEVELOPER             | Add BOM header and item ECN
* DATE_PLACEHOLDER | WI_PLACEHOLDER |  DEVELOPER             | PV interface filters not working properl
*------------------------------------------------------------------------------------------*


    DATA: lt_rcp_key TYPE cl_pppi_soa_master_recipe=>tt_rcp_key.

    FIELD-SYMBOLS: <fs_mstr_rcp> TYPE comes_t_drf_mstrrcp_key.

    CHECK ct_relevant_objects IS NOT INITIAL.


    DATA(business_system)  =  ms_runtime_param-business_system.
    ASSIGN ct_relevant_objects TO <fs_mstr_rcp>.


    IF  <fs_mstr_rcp> IS ASSIGNED.


      recipe_read_key_for_object_sel( CHANGING ct_key = <fs_mstr_rcp> ).

      CHECK NOT <fs_mstr_rcp> IS INITIAL.

      lt_rcp_key = CORRESPONDING #( <fs_mstr_rcp> ).

      CALL METHOD cl_pppi_soa_master_recipe=>get_instance
        EXPORTING
          iv_keydate  = sy-datum
          io_appl_log = ms_runtime_param-bal
        RECEIVING
          ro_instance = mo_master_recipe.

      CALL METHOD mo_master_recipe->get_details_cds
        EXPORTING
          iv_dlmod      = ms_runtime_param-dlmod
          iv_skip_check = abap_true                "mv_skip_comp_check // Always skip component allocations, new feature CE2002
          it_rcp_key    = lt_rcp_key
        IMPORTING
          et_mainheader = mt_mainheader
          et_header     = mt_header
          et_matlassgmt = mt_matlassgmt
          et_activity   = mt_activity
          et_matlalloc  = mt_compalloc
          et_relations  = mt_relations.


      "TIMESTAMP_PLACEHOLDER DEVELOPER{
      IF i_verid IS SUPPLIED.
        READ TABLE mt_compalloc WITH KEY productionversion = i_verid TRANSPORTING NO FIELDS.
        IF sy-subrc EQ 0.
          DELETE mt_compalloc WHERE productionversion NE i_verid.
        ENDIF.
      ENDIF.
      "}TIMESTAMP_PLACEHOLDER DEVELOPER

      "TIMESTAMP_PLACEHOLDER DEVELOPER{  WI_PLACEHOLDER
      LOOP AT mt_compalloc ASSIGNING FIELD-SYMBOL(<compalloc>)." where validityenddate = sy-datum .
        DATA(tabix) = sy-tabix.   "check
        IF <compalloc>-validityenddate = sy-datum.
          SELECT SINGLE bom_category, bill_of_material, alternativebom, bomitemnodenumber, internal_counter
           FROM /rgs/s_b_stas
            WHERE
                  bom_category      = @<compalloc>-billofmaterialcategory
              AND bill_of_material  = @<compalloc>-billofmaterial
              AND alternativebom    = @<compalloc>-billofmaterialvariant
              AND bomitemnodenumber = @<compalloc>-billofmaterialitemnodenumber
              AND changenumber      = @<compalloc>-changenumber
              AND deletionindicator = 'X'
            INTO @DATA(a_compalloc) ##needed.
          IF sy-subrc EQ 0.
            DELETE mt_compalloc INDEX tabix.
          ENDIF.
        ENDIF.
      ENDLOOP.


      "}TIMESTAMP_PLACEHOLDER DEVELOPER  WI_PLACEHOLDER


      "TIMESTAMP_PLACEHOLDER DEVELOPER
      DATA(rgs_crd_censore) = 'X'.
      IF rgs_crd_censore EQ 'X'.

        READ TABLE <fs_mstr_rcp> INTO DATA(mstr_rcp) INDEX 1.
        rc = sy-subrc.
        "if sys-ubrc eq 0.
        SELECT SINGLE  matnr, werks, sfcpf, phseq, business_system, auart, rt_werks, co_prodprf, tco42_auart
        FROM /rgs/p_s_dcb_marc INTO @DATA(p_s_dcb_marc)
              WHERE
              matnr EQ   @mstr_rcp-matnr
              AND werks =  @mstr_rcp-werks.
        IF sy-subrc EQ 0.
          "TIMESTAMP_PLACEHOLDER DEVELOPER mv_auart = p_s_dcb_marc-tco42_auart. .
          mv_auart = p_s_dcb_marc-co_prodprf.  "TIMESTAMP_PLACEHOLDER DEVELOPER
        ENDIF.


        CLEAR mt_p_dcb_po_rt[].

        " only operations permited in /RGS/P_DCB_PO_RT are allowed
        SELECT werks, auart, phseq , business_system , no_send FROM /rgs/p_dcb_po_rt
        INTO TABLE @DATA(p_dcb_po_rt_buffer) WHERE
              auart =  @mv_auart
              AND werks = @mstr_rcp-werks
              AND business_system = @business_system .  "TIMESTAMP_PLACEHOLDER DEVELOPER
        rc = sy-subrc.


        SELECT werks, auart, phseq , business_system
        "FROM /rgs/p_dcb_po_rt
        FROM @p_dcb_po_rt_buffer AS p_dcb_po_rt_buffer
        WHERE no_send IS INITIAL
        AND auart =  @mv_auart
          AND werks =  @mstr_rcp-werks
         AND business_system = @business_system
        INTO CORRESPONDING FIELDS OF TABLE @mt_p_dcb_po_rt.
        rc = sy-subrc.

        SORT mt_p_dcb_po_rt BY phseq ASCENDING.
        READ TABLE mt_p_dcb_po_rt  INDEX 1  INTO DATA(p_dcb_po_rt_first).  "TIMESTAMP_PLACEHOLDER DEVELOPER
        rc = sy-subrc.


        "TIMESTAMP_PLACEHOLDER DEVELOPER ignore wildcards if any "real CRD rule" is there
        IF lines( mt_p_dcb_po_rt ) GT 1 AND p_dcb_po_rt_first-phseq IS INITIAL.
          DELETE mt_p_dcb_po_rt WHERE phseq IS INITIAL.
        ENDIF.

        SORT mt_p_dcb_po_rt BY phseq ASCENDING.
        READ TABLE mt_p_dcb_po_rt  INDEX 1  INTO p_dcb_po_rt_first.  "TIMESTAMP_PLACEHOLDER DEVELOPER
        rc = sy-subrc.


        SELECT werks, auart, phseq , business_system
        "FROM /rgs/p_dcb_po_rt
        FROM @p_dcb_po_rt_buffer AS p_dcb_po_rt_buffer
        WHERE
        no_send IS NOT INITIAL
         AND auart =  @mv_auart
         AND werks = @mstr_rcp-werks
         AND business_system = @business_system
        INTO CORRESPONDING FIELDS OF TABLE @mt_p_dcb_po_rt_no_send.
        rc = sy-subrc.



        IF mt_activity[] IS NOT INITIAL.
          SELECT plnty, plnnr, plnkn, zaehl, datuv, techv, aennr, aenam, sumnr, arbid, phseq, phflg ,  pvzkn,  " sumnr AS aplzl ,
          slwid, usr00, usr01, usr02, usr03, usr04, use04, usr05, use05, usr06, use06, usr07, use07, usr08, usr09, usr10, usr11

                    FROM plpo INTO TABLE @DATA(lt_afvg_bt)
                          FOR ALL ENTRIES IN @mt_activity
                          WHERE plnty = @mt_activity-billofoperationstype
                          AND plnnr = @mt_activity-billofoperationsgroup
                          AND plnkn =  @mt_activity-boooperationinternalid
                          AND zaehl = @mt_activity-booopinternalversioncounter
                          "AND plnal = @plas_tab-plnal
                          "AND ( andat EQ @cp_date  OR aedat EQ @cp_date )

                          AND loekz NE 'X'
                          "AND werks EQ @plas_tab-werks
                          " AND aennr = @l_plpo-aennr  ""is it??  To Check
                          .
          rc = sy-subrc.
        ENDIF.





        LOOP AT lt_afvg_bt ASSIGNING FIELD-SYMBOL(<fs_afvg_bt>).
          "      DATA(tabix) = sy-tabix.

          "TIMESTAMP_PLACEHOLDER DEVELOPER "read table MT_P_DCB_PO_RT with  key PHSEQ = <FS_AFVG_BT>-PHSEQ transporting no fields.
          "TIMESTAMP_PLACEHOLDER DEVELOPER {

          IF  <fs_afvg_bt>-phflg EQ 'X'. "this a phase
            READ TABLE mt_p_dcb_po_rt WITH  KEY phseq = <fs_afvg_bt>-phseq TRANSPORTING NO FIELDS.
            DATA(rt_rc) = sy-subrc.

            IF rt_rc NE 0.
              IF  p_dcb_po_rt_first-phseq IS INITIAL  "this is a wildedcarded
              AND p_dcb_po_rt_first-business_system EQ business_system. ""TIMESTAMP_PLACEHOLDER DEVELOPER
                CLEAR rt_rc.  "so allow everything
                READ TABLE mt_p_dcb_po_rt_no_send WITH  KEY phseq = <fs_afvg_bt>-phseq TRANSPORTING NO FIELDS.
                IF sy-subrc EQ 0.
                  rt_rc = 66. "but not send flag is set
                ENDIF.
              ENDIF.
            ENDIF.


          ELSE.  "this an operation

            READ TABLE lt_afvg_bt WITH KEY  pvzkn = <fs_afvg_bt>-plnkn INTO DATA(parent_afvg). "TIMESTAMP_PLACEHOLDER DEVELOPER
            IF sy-subrc EQ 0.
              DATA(parent_phase_phseq) = parent_afvg-phseq.
            ENDIF.

            IF parent_phase_phseq IS NOT  INITIAL.
              READ TABLE mt_p_dcb_po_rt WITH  KEY phseq = parent_phase_phseq TRANSPORTING NO FIELDS.
              rt_rc = sy-subrc.
            ENDIF.
**
            IF  p_dcb_po_rt_first-phseq IS INITIAL   "this is a wildedcarded Plant/Document Type / Business System
             AND p_dcb_po_rt_first-business_system EQ business_system. ""TIMESTAMP_PLACEHOLDER DEVELOPER
              CLEAR rt_rc.  "so allow everything
              IF parent_phase_phseq IS NOT INITIAL.
                READ TABLE mt_p_dcb_po_rt_no_send WITH  KEY phseq = parent_phase_phseq TRANSPORTING NO FIELDS.
                IF sy-subrc EQ 0.
                  rt_rc = 66. "but not send flag is set
                ENDIF.
              ENDIF.
**
            ENDIF.
          ENDIF.


          IF rt_rc NE 0.

            DELETE mt_activity

            WHERE  billofoperationstype =  <fs_afvg_bt>-plnty
              AND  billofoperationsgroup =  <fs_afvg_bt>-plnnr
              AND  boooperationinternalid =  <fs_afvg_bt>-plnkn
              AND  booopinternalversioncounter = <fs_afvg_bt>-zaehl
        .

            DELETE mt_relations
             WHERE
                  billofoperationstype =  <fs_afvg_bt>-plnty
                AND  prdcssrboogroup  =  <fs_afvg_bt>-plnnr
          "and PrdcssrBOOVariant
            AND prdcssrbooopinternalid = <fs_afvg_bt>-plnkn
      .
            DELETE mt_relations
            WHERE
              billofoperationstype =  <fs_afvg_bt>-plnty
              AND succssrboogroup  =  <fs_afvg_bt>-plnnr
            "and SuccssrBOOVariant,
              AND succssrbooopinternalid = <fs_afvg_bt>-plnkn.


            DELETE mt_compalloc WHERE
                    billofoperationstype = <fs_afvg_bt>-plnty
                    AND  billofoperationsgroup  =  <fs_afvg_bt>-plnnr
                    "AND  BillOfOperationsVariant
                    AND  boooperationinternalid  = <fs_afvg_bt>-plnkn.
            .

            "} TIMESTAMP_PLACEHOLDER DEVELOPER

          ENDIF.
        ENDLOOP.




        IF mt_activity[] IS INITIAL.
          DATA(ir_application_log) = ms_runtime_param-bal.
          ir_application_log->add_msg( iv_msgid = '/RGS/P_DCB_PRODVER'
        iv_msgty = if_drf_const=>msg_type_warning
          iv_msgno = '029'  "CRD Check: No valid operations for sending &1  to &2
        iv_msgv1 = |{  mstr_rcp-matnr  && ` `   && mstr_rcp-werks  && ` ` && mstr_rcp-plnnr && '/' && mstr_rcp-plnal   }|
          iv_msgv2 = business_system
          "iv_msgv3 =
          "iv_msgv4 =
          ).
        ENDIF.

      ENDIF.

      CALL METHOD recipe_map_data_to_message  "CL_PPPI_SOA_MASTER_RECIPE
        EXPORTING
          it_mainheader = mt_mainheader
          it_header     = mt_header
          it_matlassgmt = mt_matlassgmt
          it_activity   = mt_activity
          it_compalloc  = mt_compalloc
          it_relations  = mt_relations
        IMPORTING
          es_message    = ms_recipe_message.  "TIMESTAMP_PLACEHOLDER DEVELOPER

      r_recipe_message    = ms_recipe_message.



    ENDIF.
  ENDMETHOD.


  METHOD recipe_read_key_for_object_sel.
    DATA: ls_rcp_key      LIKE LINE OF ct_key ##needed,
          lt_selopt_matnr TYPE rsds_selopt_t,
          lt_selopt_werks TYPE rsds_selopt_t,
          lt_selopt_plnnr TYPE rsds_selopt_t,
          lt_selopt_plnal TYPE rsds_selopt_t,
          ls_selopt       TYPE rsdsselopt,
          lt_std_key      TYPE TABLE OF comes_s_drf_mstrrcp_key.
    DATA(lt_key) = ct_key[].
    CLEAR: ct_key[].
    LOOP AT lt_key ASSIGNING FIELD-SYMBOL(<fs>).
      CLEAR: ls_selopt,ls_rcp_key,lt_selopt_matnr,lt_selopt_werks,lt_selopt_plnnr,lt_selopt_plnal.
      ls_selopt-sign = 'I'.
      ls_selopt-option = 'EQ'.
      IF NOT <fs>-matnr IS INITIAL.
        convert_material_input( EXPORTING iv_input  = <fs>-matnr
                                IMPORTING ev_output = ls_selopt-low ).
        APPEND ls_selopt TO lt_selopt_matnr.
      ENDIF.
      IF NOT <fs>-werks IS INITIAL.
        CLEAR: ls_selopt-low.
        ls_selopt-low = <fs>-werks.
        APPEND ls_selopt TO lt_selopt_werks.
      ENDIF.
      IF NOT <fs>-plnnr IS INITIAL.
        CLEAR: ls_selopt-low.
        ls_selopt-low = <fs>-plnnr.
        APPEND ls_selopt TO lt_selopt_plnnr.
      ENDIF.
      IF  NOT <fs>-plnal IS INITIAL.
        CLEAR: ls_selopt-low.
        ls_selopt-low = <fs>-plnal.
        APPEND ls_selopt TO lt_selopt_plnal.
      ENDIF.
      SELECT matnr, werks, plnnr, plnal
         FROM mapl
         WHERE matnr IN @lt_selopt_matnr
         AND werks IN @lt_selopt_werks
         AND plnty = @mc_recipe_mrctyp
         AND plnnr IN @lt_selopt_plnnr
         AND plnal IN @lt_selopt_plnal
         APPENDING CORRESPONDING FIELDS OF TABLE @lt_std_key.
      rc = sy-subrc.
    ENDLOOP.
    SORT: lt_std_key ASCENDING BY matnr werks plnnr plnal.
    DELETE ADJACENT DUPLICATES FROM: lt_std_key COMPARING matnr werks plnnr plnal.
    ct_key[] = lt_std_key[].
  ENDMETHOD.


  METHOD recipe_read_standard_value_key.
    TRY.
        cl_co_fm_access_factory=>cpta( )->tc21_read(
          EXPORTING
            vgwts  = iv_vgwts
          IMPORTING
            struct = rs_tc21 ).
      CATCH cx_co_fm_access.
        CLEAR rs_tc21.
    ENDTRY.
  ENDMETHOD.


  METHOD send_message_fin0002.

*   Local Variable and object reference Declaration
    DATA: lo_service_proxy           TYPE REF TO co_ppint_mfg_prodn_vers,
          lv_error_text              TYPE string,
          lv_longtext                TYPE string,
          "          lv_path_message_header     TYPE string,
          lv_soa_exception_text      TYPE string,
          lv_soa_exception_long_text TYPE string,
          "          ls_output                  TYPE ppint_mfg_prodn_vers_info_msg,
          ls_message_data_outbound   TYPE ppint_mfg_prodn_vers_inf.
    TEST-SEAM data_set_seam.
    END-TEST-SEAM.
*   Local Constant Declaration
    CONSTANTS:lc_matgrp_service TYPE string  VALUE 'ManufacturingProdnVersInfo_Out'.

*   Clear Exporting Parameter
    CLEAR: et_file_data,et_message.

*   Create Object of Proxy Class
    TRY.
        CREATE OBJECT lo_service_proxy.
      CATCH cx_ai_system_fault INTO mo_error ##No_handler.
        ex_text = mo_error->get_text( ).
    ENDTRY.

*   If Output Data is not Blank Trigger Outbound Proxy to replicate the Routing from S4 to Target System
    IF NOT ms_output-manufacturing_prodn_vers_info-production_version_information IS INITIAL.
      TRY.
          IF ms_runtime_param-testrun = abap_false.
            ls_message_data_outbound = ms_output.
            DATA: lo_wrapper TYPE REF TO cl_ppint_soa_mfg_md_wrapper.
            CREATE OBJECT lo_wrapper.

            TEST-SEAM send_message.
              CALL METHOD lo_wrapper->send_mfg_md_message
                EXPORTING
                  iv_appl            = ms_runtime_param-appl
                  iv_proxy_name      = 'CO_PPINT_MFG_PRODN_VERS'
                  iv_proxy_method    = 'MANUFACTURING_PRODN_VERS_INFO'
                  iv_out_msg_typ     = 'PPINT_MFG_PRODN_VERS_INF'
                  is_out_msg         = ls_message_data_outbound
                  iv_comm_service_id = '0003'
                  iv_rcvr_logsys_id  = ms_runtime_param-logsys
                IMPORTING
                  rv_subrc           = DATA(lv_subrc).
            END-TEST-SEAM.
            IF NOT lv_subrc IS INITIAL.
              MESSAGE s099(drf_outbound) WITH TEXT-001 INTO DATA(lv_dummy) ##needed.
*     If Output Data is Blank then Add Error message to application log
              CALL METHOD ms_runtime_param-bal->add_msg_re
                EXPORTING
                  iv_msgno = sy-msgno
                  iv_msgid = sy-msgid
                  iv_msgv1 = sy-msgv1.
            ENDIF.
***             CALL METHOD lo_service_proxy->manufacturing_prodn_vers_info
***              EXPORTING
***                output = ms_output.
            TEST-SEAM error_seam.
            END-TEST-SEAM.
          ENDIF.
*       Handle the Exception and generate DRF Application Log
        CATCH cx_bs_soa_exception INTO mo_bs_soa_exception.
*         In case of data replication failure change the replication status to 'SE' from 'SN'
          LOOP AT ct_obj_rep_sta ASSIGNING FIELD-SYMBOL(<fs_obj_rep_sta>).
            <fs_obj_rep_sta>-repstatus = 'SE'.
          ENDLOOP.
          UNASSIGN: <fs_obj_rep_sta>.

*         Get error text
          CALL METHOD mo_bs_soa_exception->get_text
            RECEIVING
              result = lv_soa_exception_text.

*         Get long text
          CALL METHOD mo_bs_soa_exception->get_longtext
            RECEIVING
              result = lv_soa_exception_long_text.

          MESSAGE s015(drf_outbound) WITH lc_matgrp_service lv_soa_exception_text lv_soa_exception_long_text INTO lv_dummy.
*         Add message to application log, raise exception
          CALL METHOD ms_runtime_param-bal->add_msg_re
            EXPORTING
              iv_msgno             = sy-msgno
              iv_msgid             = sy-msgid
              iv_msgv1             = sy-msgv1
              iv_msgv2             = sy-msgv2
              iv_msgv3             = sy-msgv3
              ix_exception_catched = mo_bs_soa_exception.
*       Handle the Exception and generate DRF Application Log
        CATCH cx_ai_system_fault INTO mo_error .
*         In case of data replication failure change the replication status to 'SE' from 'SN'
          LOOP AT ct_obj_rep_sta ASSIGNING <fs_obj_rep_sta>.
            <fs_obj_rep_sta>-repstatus = 'SE'.
          ENDLOOP.
          UNASSIGN: <fs_obj_rep_sta>.

*         Get error text
         "CALL METHOD mo_error->if_message~get_text
         CALL METHOD mo_error->get_text
            RECEIVING
              result = lv_error_text.

*         Get long text
          CALL METHOD mo_error->if_message~get_longtext
            RECEIVING
              result = lv_longtext.

          MESSAGE s015(drf_outbound) WITH lc_matgrp_service lv_error_text lv_longtext INTO lv_dummy.
*         Add message to application log, raise exception
          CALL METHOD ms_runtime_param-bal->add_msg_re
            EXPORTING
              iv_msgno             = sy-msgno
              iv_msgid             = sy-msgid
              iv_msgv1             = sy-msgv1
              iv_msgv2             = sy-msgv2
              iv_msgv3             = sy-msgv3
              ix_exception_catched = mo_error.
      ENDTRY.
    ELSE.
      MESSAGE s322(drf_outbound) INTO lv_dummy.
*     If Output Data is Blank then Add Error message to application log
      CALL METHOD ms_runtime_param-bal->add_msg_re
        EXPORTING
          iv_msgno = sy-msgno
          iv_msgid = sy-msgid.
    ENDIF.
  ENDMETHOD.
ENDCLASS.