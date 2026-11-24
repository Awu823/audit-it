*&---------------------------------------------------------------------*
*& Report ZPROG_AIF_SEND_PROXY_TEST
*&---------------------------------------------------------------------*
*& Standalone test program for function module /AIF/SEND_WITH_PROXY.
*&
*& Extracted from ZCL_M1T_DCN_BOM_CHANGE (send_message / build_aif_message /
*& build_business_header), stripped of all DRF-framework dependencies so the
*& AIF connectivity / payload / logical-port / exception handling can be
*& verified in isolation without running the full DRF outbound cycle.
*&
*& Message: ppint_mfg_prodn_vers_inf (ManufacturingProdnVersInfo_Out outbound
*&          service, aligned with the reference /RGS/CL_P_DCB_DRF_PRODVER_OUT).
*&
*& Usage:
*&   1. Fill the AIF interface block (defaults match the production config).
*&   2. Fill one BOM header + one component as test payload.
*&   3. Tick "Dry run" to build & display the sap_struct payload only (no send).
*&   4. Untick "Dry run" to actually call /AIF/SEND_WITH_PROXY and inspect the
*&      returned GUIDs, add_return_tab, error_string and sy-subrc.
*&---------------------------------------------------------------------*
REPORT zprog_aif_send_proxy_test.

*====================================================================*
* Types & data
*====================================================================*
TYPES:
  BEGIN OF ty_aif_params,
    ns           TYPE /aif/ns,
    ifname       TYPE /aif/ifname,
    ifversion    TYPE /aif/ifversion,
    logical_port TYPE prx_logical_port_name,
    persist_xml  TYPE abap_bool,
    dry_run      TYPE abap_bool,
  END OF ty_aif_params,
  " Mirror of ZCL_M1T_DCN_BOM_CHANGE local types bom_header_ty / bom_item_ty,
  " reduced to the 17 FS §7 fields so the test payload matches production.
  BEGIN OF ty_bom_test_data,
    " Header (ID01, ID06-ID14)
    cop_exg_no        TYPE matnr,   " ID01 header material
    bom_creation      TYPE datuv,   " ID06 (no XML landing point, kept for parity)
    alternative_bom   TYPE stlal,   " ID07
    bom_no            TYPE stnum,   " ID08
    change_no         TYPE aennr,   " ID09
    bom_usage         TYPE stlan,   " ID10
    header_start_date TYPE datuv,   " ID11
    header_end_date   TYPE datuv,   " ID12 (type DATUB)
    header_qty        TYPE bmenge,   " ID13
    header_unit       TYPE meins,   " ID14
    " Item (ID02-ID05, ID15-ID17) — one component for the test payload
    cop_img_no        TYPE idnrk,   " ID02
    quantity          TYPE kmpmg,   " ID03
    valid_from        TYPE datuv,   " ID04
    valid_to          TYPE datuv,   " ID05 (type DATUB)
    component_unit    TYPE meins,   " ID15
    operation_scrap   TYPE ausch,   " ID16 (no XML landing point, kept for parity)
    component_scrap   TYPE ausch,   " ID17
  END OF ty_bom_test_data.

*====================================================================*
* Selection screen
*====================================================================*
SELECTION-SCREEN BEGIN OF BLOCK aif WITH FRAME TITLE TEXT-aif.
PARAMETERS:
  p_ns     TYPE /aif/ns              DEFAULT 'YPMES'     MODIF ID aif,
  p_ifname TYPE /aif/ifname          DEFAULT 'YOMES_PV'  MODIF ID aif,
  p_ifver  TYPE /aif/ifversion       DEFAULT '1'        MODIF ID aif,
  p_lport  TYPE prx_logical_port_name DEFAULT 'YMESPVOUT' MODIF ID aif,
  p_pers   AS CHECKBOX               DEFAULT 'X'        MODIF ID aif,
  p_dry    AS CHECKBOX               DEFAULT 'X'        MODIF ID aif.
SELECTION-SCREEN END OF BLOCK aif.

SELECTION-SCREEN BEGIN OF BLOCK hdr WITH FRAME TITLE TEXT-hdr.
PARAMETERS:
  p_matnr TYPE matnr    MODIF ID hdr,                 " ID01 copExgNo
  p_werks TYPE werks_d  DEFAULT 'Q511' MODIF ID hdr,  " plant (default per FS §4)
  p_stlal TYPE stlal    MODIF ID hdr,                 " ID07 alternativeBom
  p_stlan TYPE stlan    DEFAULT '1'   MODIF ID hdr,   " ID10 useTo
  p_stlnr TYPE stnum    MODIF ID hdr,                 " ID08 bomNo
  p_aennr TYPE aennr    MODIF ID hdr,                 " ID09 changeNo
  p_hqty  TYPE bmenge   MODIF ID hdr,                 " ID13 copExgQty
  p_hunit TYPE meins    MODIF ID hdr,                 " ID14 copExgUnit
  p_hdatu TYPE datuv    MODIF ID hdr,                 " ID11 bomStartDate
  p_hdatb TYPE datuv    MODIF ID hdr.                 " ID12 bomEndDate (DATUB)
SELECTION-SCREEN END OF BLOCK hdr.

SELECTION-SCREEN BEGIN OF BLOCK itm WITH FRAME TITLE TEXT-itm.
PARAMETERS:
  p_idnrk TYPE idnrk  MODIF ID itm,                   " ID02 copImgNo
  p_menge TYPE kmpmg  MODIF ID itm,                   " ID03 decCm
  p_iunit TYPE meins  MODIF ID itm,                   " ID15 copImgUnit
  p_avoau TYPE ausch  MODIF ID itm,                   " ID16 operationScrap
  p_ausch TYPE ausch  MODIF ID itm,                   " ID17 componentScrap
  p_idatu TYPE datuv  MODIF ID itm,                   " ID04 component valid-from
  p_idatb TYPE datuv  MODIF ID itm.                   " ID05 component valid-to (DATUB)
SELECTION-SCREEN END OF BLOCK itm.

*====================================================================*
* Local class — AIF send logic (extracted & standalone)
*====================================================================*
CLASS lcl_aif_send_test DEFINITION FINAL.
  PUBLIC SECTION.

    " AIF interface constants (copied verbatim from ZCL_M1T_DCN_BOM_CHANGE,
    " so the test program exercises the same namespace / interface / port as
    " production — BOM uses ManufacturingProdnVersInfo_Out outbound service).
    CONSTANTS:
      gc_ns           TYPE /aif/ns        VALUE 'YPMES'   ##NO_TEXT,
      gc_ifname       TYPE /aif/ifname    VALUE 'YOMES_PV' ##NO_TEXT,
      gc_ifver        TYPE /aif/ifversion VALUE '1'        ##NO_TEXT,
      gc_logical_port TYPE prx_logical_port_name VALUE 'YMESPVOUT' ##NO_TEXT,
      gc_aif_service  TYPE string         VALUE 'ManufacturingProdnVersInfo_Out' ##NO_TEXT,
      gc_default_werks TYPE werks_d VALUE 'Q511' ##NO_TEXT.

    CLASS-METHODS:
      build_business_header
        RETURNING VALUE(rs_header) TYPE ppint_busdoc_msg_hdr,

      build_aif_message
        IMPORTING is_data        TYPE ty_bom_test_data
        RETURNING VALUE(rs_msg) TYPE ppint_mfg_prodn_vers_inf,

      send
        IMPORTING is_params      TYPE ty_aif_params
                  is_data        TYPE ty_bom_test_data
        EXPORTING es_msg         TYPE ppint_mfg_prodn_vers_inf
                  ev_msgguid     TYPE sxmsmguid
                  ev_msgguid_out TYPE sxmsmguid
                  et_return      TYPE bapiret2_t
                  ev_error_str   TYPE string
                  ev_error_long  TYPE string
                  ev_subrc       TYPE sysubrc
                  ev_sent_ok     TYPE abap_bool
                  ev_except_text TYPE string
                  ev_exception   TYPE string.
ENDCLASS.

CLASS lcl_aif_send_test IMPLEMENTATION.

  METHOD build_business_header.
    " Verbatim extraction of ZCL_M1T_DCN_BOM_CHANGE~build_business_header:
    "   - id-content / uuid-content: UUID C32
    "   - creation_date_time: system time -> UTC -> XSD dateTime (long, Z)
    "   - sender_business_system_id: LCR_GET_OWN_BUSINESS_SYSTEM
    "   - recipient_business_system_id: caller-provided target (here: logical port
    "     name, since the standalone test has no runtime_parameter_ext-business_system)
    DATA: lv_guid_32   TYPE guid_32,
          lv_timestamp TYPE timestamp,
          lv_date      LIKE sy-datum,
          lv_time      LIKE sy-uzeit.

    TRY.
        lv_guid_32 = cl_system_uuid=>create_uuid_c32_static( ).
      CATCH cx_uuid_error.
        CLEAR lv_guid_32.
    ENDTRY.

    rs_header-id-content   = lv_guid_32.
    rs_header-uuid-content = lv_guid_32.

    TRY.
        cl_abap_tstmp=>systemtstmp_syst2utc(
          EXPORTING
            syst_date = sy-datum
            syst_time = sy-uzeit
          IMPORTING
            utc_tstmp = lv_timestamp ).
      CATCH cx_parameter_invalid_range.
        CLEAR lv_timestamp.
    ENDTRY.

    IF lv_timestamp IS NOT INITIAL.
      CONVERT TIME STAMP lv_timestamp TIME ZONE 'UTC' INTO DATE lv_date TIME lv_time.
      TRY.
          cl_bs_soa_convert_xsddatetime=>map_xsddatetime_long_z_out(
            EXPORTING
              iv_date = lv_date
              iv_time = lv_time
            IMPORTING
              ev_xsd_datetime = rs_header-creation_date_time ).
        CATCH cx_bs_soa_exception.
          CLEAR rs_header-creation_date_time.
      ENDTRY.
    ENDIF.

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
    " sy-subrc intentionally ignored: an empty sender is tolerated by the test.

    " Recipient: the test program has no runtime_parameter_ext-business_system,
    " so the logical port name is used as the target system identifier (purely
    " informational for the business header; the real routing is driven by the
    " logical_port_name parameter of /AIF/SEND_WITH_PROXY).
    rs_header-recipient_business_system_id = gc_logical_port.
  ENDMETHOD.

  METHOD build_aif_message.
    " Extraction of ZCL_M1T_DCN_BOM_CHANGE~build_aif_message: assembles the
    " local 17-field BOM message into the standard AIF structure
    " ppint_mfg_prodn_vers_inf (the sap_struct passed to /AIF/SEND_WITH_PROXY).
    " Component landing points per map2xml.md:
    "   ID01 copExgNo   -> production_version_information-material
    "   ID07 alternativeBom -> bill_of_material_variant
    "   ID10 useTo      -> bill_of_material_variant_usage
    "   ID08 bomNo      -> bill_of_material
    "   ID09 changeNo   -> bom_header_ecn
    "   ID11/ID12      -> bom_extra_data[]-bom_validity_start/end_date
    "   ID13 copExgQty  -> quantity_in_base_unit
    "   ID14 copExgUnit -> base_unit
    "   ID02-ID05/ID15/ID17 -> bill_of_operations_activity_ne-co (component alloc)
    "   ID06/ID16       -> no standard landing point (kept in local struct only)
    DATA: ls_pv_line   TYPE ppint_prodn_vers_information,
          ls_compalloc TYPE ppint_boo_acty_comp_alloc,
          ls_acty_ne   TYPE ppint_mfg_boo_acty_ntwk_elmnts,
          lt_compalloc TYPE STANDARD TABLE OF ppint_boo_acty_comp_alloc.

    CLEAR rs_msg.

    " Business header (message-level id / creation_date_time / sender-recipient)
    rs_msg-manufacturing_prodn_vers_info-message_header = build_business_header( ).

    " Production version information row (ID01/ID07/ID10)
    ls_pv_line-material = is_data-cop_exg_no.
    ls_pv_line-plant    = gc_default_werks.
    ls_pv_line-bill_of_material_variant       = is_data-alternative_bom. " ID07
    ls_pv_line-bill_of_material_variant_usage = is_data-bom_usage.        " ID10
    APPEND ls_pv_line TO rs_msg-manufacturing_prodn_vers_info-production_version_information.

    " BOM header root-level components (n1:* section)
    rs_msg-manufacturing_prodn_vers_info-bill_of_material         = is_data-bom_no.        " ID08
    rs_msg-manufacturing_prodn_vers_info-bom_category             = 'M'.                  " material BOM
    rs_msg-manufacturing_prodn_vers_info-quantity_in_base_unit    = is_data-header_qty.   " ID13
    rs_msg-manufacturing_prodn_vers_info-base_unit                = is_data-header_unit.  " ID14
    rs_msg-manufacturing_prodn_vers_info-bom_header_ecn           = is_data-change_no.    " ID09

    " BOM header validity period (ID11/ID12) -> bom_extra_data
    DATA(ls_bom_extra) = VALUE /rgs/p_dcb_pv_rgs_p_dcb_pv_bom(
      bom_header_ecn            = is_data-change_no
      bom_validity_start_date   = |{ is_data-header_start_date DATE = ISO }|
      bom_validity_end_date     = |{ is_data-header_end_date   DATE = ISO }|
      quantity_in_base_unit     = is_data-header_qty
      bom_header_base_unit      = is_data-header_unit ).
    APPEND ls_bom_extra TO rs_msg-manufacturing_prodn_vers_info-bom_extra_data.

    " Component details (ID02-ID05/ID15/ID17) -> bill_of_operations_activity_ne-co
    CLEAR ls_compalloc.
    ls_compalloc-bill_of_material_category   = 'M'.
    ls_compalloc-bill_of_material            = is_data-bom_no.
    ls_compalloc-bill_of_material_component  = is_data-cop_img_no.                " ID02
    ls_compalloc-bill_of_material_item_quantity-content    = is_data-quantity.     " ID03
    ls_compalloc-bill_of_material_item_quantity-unit_code  = is_data-component_unit. " ID15
    ls_compalloc-validity_start_date         = is_data-valid_from.                " ID04
    ls_compalloc-validity_end_date           = is_data-valid_to.                  " ID05
    ls_compalloc-component_scrap_in_percent  = is_data-component_scrap.           " ID17
    APPEND ls_compalloc TO lt_compalloc.

    ls_acty_ne-bill_of_operations_activity_co = lt_compalloc.
    APPEND ls_acty_ne TO rs_msg-manufacturing_prodn_vers_info-bill_of_operations_activity_ne.
  ENDMETHOD.

  METHOD send.
    " Extraction of ZCL_M1T_DCN_BOM_CHANGE~send_message (AIF send core),
    " without DRF framework pieces (repstatus, add_msg_xi, bal). The FM call,
    " the tolerated PERSISTENCY_ERROR (=1), the business-error (E/A) scan of
    " add_return_tab, and the cx_bs_soa_exception / cx_ai_system_fault catch
    " are all preserved 1:1 so the test exercises the same failure surface.
    DATA: lt_return   TYPE bapiret2_t,
          lv_msgguid  TYPE sxmsmguid,
          lv_subrc    TYPE sysubrc,
          lv_sent_ok  TYPE abap_bool VALUE abap_true,
          lv_err_str  TYPE string,
          lv_err_long TYPE string.

    CLEAR: es_msg, ev_msgguid, ev_msgguid_out, et_return,
           ev_error_str, ev_error_long, ev_subrc,
           ev_sent_ok, ev_except_text, ev_exception.

    " Build the AIF message (local copy: /AIF/SEND_WITH_PROXY may mutate
    " sap_struct, aligned with reference ls_message_data_outbound = ms_output).
    es_msg = build_aif_message( is_data = is_data ).

    IF is_params-dry_run = abap_true.
      " Dry run: return the assembled payload only, skip the actual send.
      ev_sent_ok = abap_true.
      ev_subrc   = 0.
      RETURN.
    ENDIF.

    TRY.
        CLEAR lt_return.
        CALL FUNCTION '/AIF/SEND_WITH_PROXY'
          EXPORTING
            ns                   = is_params-ns
            ifname               = is_params-ifname
            ifversion            = is_params-ifversion
            appl_log_function    = 'AIF_SEND_WITH_PROXY'
            msgguid              = lv_msgguid
            iv_persist_xml       = COND #( WHEN is_params-persist_xml = abap_true THEN 'X' ELSE space )
            logical_port_name    = is_params-logical_port
          IMPORTING
            ximsgguid            = lv_msgguid
            ximsgguid_out        = ev_msgguid_out
          TABLES
            add_return_tab       = lt_return
          CHANGING
            sap_struct           = es_msg
            error_string         = lv_err_str
            error_long_text      = lv_err_long
          EXCEPTIONS
            persistency_error    = 1
            status_update_failed = 2
            missing_keys         = 3
            interface_not_found  = 4
            transformation_error = 5
            general_error        = 6
            OTHERS               = 7.

        lv_subrc = sy-subrc.
        et_return      = lt_return.
        ev_msgguid     = lv_msgguid.
        ev_error_str   = lv_err_str.
        ev_error_long  = lv_err_long.
        ev_subrc       = lv_subrc.

        " Failure rule 1: non-zero sy-subrc, except the tolerated
        " PERSISTENCY_ERROR (=1) — aligned with the reference implementation.
        IF lv_subrc <> 0 AND lv_subrc <> 1.
          lv_sent_ok = abap_false.
        ENDIF.

        " Failure rule 2: business-level error (E/A) in add_return_tab, even
        " when sy-subrc = 0 — the FM can succeed structurally yet report a
        " proxy/mapping business error here.
        DATA(lv_has_biz_error) = abap_false.
        LOOP AT lt_return INTO DATA(ls_ret)
          WHERE type = 'E' OR type = 'A'.
          lv_has_biz_error = abap_true.
          EXIT.
        ENDLOOP.
        IF lv_has_biz_error = abap_true.
          lv_sent_ok = abap_false.
        ENDIF.

        ev_sent_ok = lv_sent_ok.

      CATCH cx_bs_soa_exception INTO DATA(lx_soa).
        ev_sent_ok     = abap_false.
        ev_exception   = 'CX_BS_SOA_EXCEPTION'.
        ev_except_text = |{ lx_soa->get_text( ) } / { lx_soa->get_longtext( ) }|.
        et_return      = VALUE #( BASE et_return
          ( type = 'E' id = 'AIF_TEST' number = '001'
            message = ev_except_text ) ).

      CATCH cx_ai_system_fault INTO DATA(lx_fault).
        ev_sent_ok     = abap_false.
        ev_exception   = 'CX_AI_SYSTEM_FAULT'.
        ev_except_text = |{ lx_fault->get_text( ) } / { lx_fault->get_longtext( ) }|.
        et_return      = VALUE #( BASE et_return
          ( type = 'E' id = 'AIF_TEST' number = '001'
            message = ev_except_text ) ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.

*====================================================================*
* Main
*====================================================================*
START-OF-SELECTION.

  " 1. Gather AIF parameters (use the class defaults when the screen field is empty,
  "    so the program works out-of-the-box with the production config).
  DATA(ls_params) = VALUE ty_aif_params(
    ns           = COND #( WHEN p_ns     IS NOT INITIAL THEN p_ns     ELSE lcl_aif_send_test=>gc_ns )
    ifname       = COND #( WHEN p_ifname IS NOT INITIAL THEN p_ifname ELSE lcl_aif_send_test=>gc_ifname )
    ifversion    = COND #( WHEN p_ifver  IS NOT INITIAL THEN p_ifver  ELSE lcl_aif_send_test=>gc_ifver )
    logical_port = COND #( WHEN p_lport  IS NOT INITIAL THEN p_lport  ELSE lcl_aif_send_test=>gc_logical_port )
    persist_xml  = p_pers
    dry_run      = p_dry ).

  " 2. Build the test payload (header + one component).
  DATA(ls_data) = VALUE ty_bom_test_data(
    cop_exg_no        = p_matnr
    bom_creation      = sy-datum                " ID06 — no XML landing point, kept for parity
    alternative_bom   = p_stlal                 " ID07
    bom_no            = p_stlnr                 " ID08
    change_no         = p_aennr                 " ID09
    bom_usage         = p_stlan                 " ID10
    header_start_date = p_hdatu                 " ID11
    header_end_date   = p_hdatb                 " ID12
    header_qty        = p_hqty                  " ID13
    header_unit       = p_hunit                 " ID14
    cop_img_no        = p_idnrk                 " ID02
    quantity          = p_menge                 " ID03
    valid_from        = p_idatu                 " ID04
    valid_to          = p_idatb                 " ID05
    component_unit    = p_iunit                 " ID15
    operation_scrap   = p_avoau                 " ID16 — no XML landing point, kept for parity
    component_scrap   = p_ausch                 " ID17
  ).

  " 3. Send (or dry-run).
  DATA: ls_msg         TYPE ppint_mfg_prodn_vers_inf,
        lv_msgguid     TYPE sxmsmguid,
        lv_msgguid_out TYPE sxmsmguid,
        lt_return      TYPE bapiret2_t,
        lv_err_str     TYPE string,
        lv_err_long    TYPE string,
        lv_subrc       TYPE sysubrc,
        lv_sent_ok     TYPE abap_bool,
        lv_except_text TYPE string,
        lv_exception   TYPE string.

  lcl_aif_send_test=>send(
    EXPORTING is_params      = ls_params
              is_data        = ls_data
    IMPORTING es_msg         = ls_msg
              ev_msgguid     = lv_msgguid
              ev_msgguid_out = lv_msgguid_out
              et_return      = lt_return
              ev_error_str   = lv_err_str
              ev_error_long  = lv_err_long
              ev_subrc       = lv_subrc
              ev_sent_ok     = lv_sent_ok
              ev_except_text = lv_except_text
              ev_exception   = lv_exception ).

  " 4. Report results.
  WRITE: / '==== /AIF/SEND_WITH_PROXY test result ====' COLOR COL_HEADING.
  ULINE.

  WRITE: / 'AIF interface' COLOR COL_TOTAL,
         / '  namespace     :', ls_params-ns,
         / '  ifname        :', ls_params-ifname,
         / '  ifversion     :', ls_params-ifversion,
         / '  logical port  :', ls_params-logical_port,
         / '  persist_xml   :', ls_params-persist_xml,
         / '  mode          :', COND #( WHEN ls_params-dry_run = abap_true THEN 'DRY RUN (no send)' ELSE 'SEND' ).

  ULINE.
  WRITE: / 'Payload (ppint_mfg_prodn_vers_inf)' COLOR COL_TOTAL.
  WRITE: / '  business header id      :', ls_msg-manufacturing_prodn_vers_info-message_header-id-content.
  WRITE: / '  creation_date_time      :', ls_msg-manufacturing_prodn_vers_info-message_header-creation_date_time.
  WRITE: / '  sender_business_system  :', ls_msg-manufacturing_prodn_vers_info-message_header-sender_business_system_id.
  WRITE: / '  recipient_business_system:', ls_msg-manufacturing_prodn_vers_info-message_header-recipient_business_system_id.
  IF lines( ls_msg-manufacturing_prodn_vers_info-production_version_information ) > 0.
    DATA(ls_pv) = ls_msg-manufacturing_prodn_vers_info-production_version_information[ 1 ].
    WRITE: / '  PV.material             :', ls_pv-material,
           / '  PV.plant                :', ls_pv-plant,
           / '  PV.bom_variant          :', ls_pv-bill_of_material_variant,
           / '  PV.bom_variant_usage    :', ls_pv-bill_of_material_variant_usage.
  ENDIF.
  WRITE: / '  bill_of_material        :', ls_msg-manufacturing_prodn_vers_info-bill_of_material,
         / '  bom_category            :', ls_msg-manufacturing_prodn_vers_info-bom_category,
         / '  quantity_in_base_unit   :', ls_msg-manufacturing_prodn_vers_info-quantity_in_base_unit,
         / '  base_unit               :', ls_msg-manufacturing_prodn_vers_info-base_unit,
         / '  bom_header_ecn          :', ls_msg-manufacturing_prodn_vers_info-bom_header_ecn.
  LOOP AT ls_msg-manufacturing_prodn_vers_info-bom_extra_data INTO DATA(ls_extra).
    WRITE: / '  bom_extra_data-bom_validity_start:', ls_extra-bom_validity_start_date,
           / '  bom_extra_data-bom_validity_end  :', ls_extra-bom_validity_end_date.
  ENDLOOP.
  LOOP AT ls_msg-manufacturing_prodn_vers_info-bill_of_operations_activity_ne INTO DATA(ls_ne).
    WRITE: / '  activity_ne component count :', lines( ls_ne-bill_of_operations_activity_co ).
    LOOP AT ls_ne-bill_of_operations_activity_co INTO DATA(ls_co).
      WRITE: / '    component          :', ls_co-bill_of_material_component,
             / '    quantity.content   :', ls_co-bill_of_material_item_quantity-content,
             / '    quantity.unit_code :', ls_co-bill_of_material_item_quantity-unit_code,
             / '    validity_start     :', ls_co-validity_start_date,
             / '    validity_end       :', ls_co-validity_end_date,
             / '    component_scrap %  :', ls_co-component_scrap_in_percent.
    ENDLOOP.
  ENDLOOP.

  IF ls_params-dry_run = abap_true.
    ULINE.
    WRITE: / 'Dry run complete — payload built, /AIF/SEND_WITH_PROXY was NOT called.' COLOR COL_POSITIVE.
    RETURN.
  ENDIF.

  ULINE.
  WRITE: / 'Send result' COLOR COL_TOTAL.
  WRITE: / '  sy-subrc        :', lv_subrc.
  WRITE: / '  msgguid (in)    :', lv_msgguid.
  WRITE: / '  msgguid_out     :', lv_msgguid_out.
  WRITE: / '  sent_ok         :', lv_sent_ok.
  WRITE: / '  error_string    :', lv_err_str.
  WRITE: / '  error_long_text :', lv_err_long.
  IF lv_exception IS NOT INITIAL.
    WRITE: / '  exception class :', lv_exception COLOR COL_NEGATIVE.
    WRITE: / '  exception text  :', lv_except_text COLOR COL_NEGATIVE.
  ENDIF.

  ULINE.
  WRITE: / 'add_return_tab (bapiret2)' COLOR COL_TOTAL.
  IF lines( lt_return ) = 0.
    WRITE: / '  (empty)'.
  ELSE.
    LOOP AT lt_return INTO DATA(ls_ret).
      WRITE: / ls_ret-type, ls_ret-id, ls_ret-number, ls_ret-message.
    ENDLOOP.
  ENDIF.

  ULINE.
  IF lv_sent_ok = abap_true AND lv_exception IS INITIAL.
    WRITE: / 'VERDICT: send OK (sy-subrc=0 or tolerated PERSISTENCY_ERROR=1; no E/A in add_return_tab).' COLOR COL_POSITIVE.
  ELSE.
    WRITE: / 'VERDICT: send FAILED — inspect sy-subrc / error_string / add_return_tab / exception above.' COLOR COL_NEGATIVE.
  ENDIF.
