*&---------------------------------------------------------------------*
*& Report ZPROG_AIF_SEND_PROXY_TEST_WSDL
*&---------------------------------------------------------------------*
*& Standalone test program for function module /AIF/SEND_WITH_PROXY.
*&
*& Extracted from ZCL_M1T_DCN_BOM_OUT_IMPL (new WSDL variant —
*& ZBOMReplicateReq_Async_Out, BOM-centric custom WSDL), stripped of all
*& DRF-framework dependencies so the AIF connectivity / payload /
*& logical-port / proxy-controller / exception handling can be verified
*& in isolation without running the full DRF outbound cycle.
*&
*& Message: zzbomreplicate_request (root sap_struct registered in /aif/cust),
*&          BOM-centric (components directly under BOM, no PV/workflow nesting).
*&          All 17 FS §7 fields mapped (ID01-ID17), including ID06
*&          (BOMCreationDate) and ID16 (OperationScrapInPercent) which were
*&          unmappable in the PV structure variant.
*&
*& ZBOM-specific elements preserved 1:1 from the source class:
*&   - AIF constants AIF_NS / AIF_IFNAME / 1 / AIF_LOGICAL_PORT
*&   - CONVERSION_EXIT_MATN1_OUTPUT for materials (ID01, ID02)
*&   - CONVERSION_EXIT_CUNIT_OUTPUT for units (ID14, ID15) + shift/trim
*&   - fill_proxy_controllers (PRXCTRLTAB flags at every level — without
*&     these the proxy runtime serializes an EMPTY XML body)
*&   - convert_timestamp (CET→UTC with 24:00:00 midnight rollover)
*&   - creation_date_time override at send time (must reflect the actual
*&     send moment, not the build moment)
*&   - local copy of sap_struct (protects against FM mutation)
*&   - PERSISTENCY_ERROR (=1) tolerated; E/A scan of add_return_tab
*&   - cx_bs_soa_exception / cx_ai_system_fault catch
*&
*& Usage:
*&   1. Fill the AIF interface block (defaults match the ZBOM config).
*&   2. Fill one BOM header + one component as test payload.
*&   3. Tick "Dry run" to build & display the sap_struct payload only (no send).
*&   4. Untick "Dry run" to actually call /AIF/SEND_WITH_PROXY and inspect the
*&      returned GUIDs, add_return_tab, error_string, sy-subrc and exception.
*&---------------------------------------------------------------------*
REPORT zprog_drf_ref_aif_send_test_wsdl.

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
  " Mirror of ZCL_M1T_DCN_BOM_OUT_IMPL local types bom_header_ty /
  " bom_item_ty — 17 FS §7 fields. ID06/ID16 ARE mappable in the ZBOM WSDL
  " (unlike the PV structure variant), so they are first-class here.
  BEGIN OF ty_bom_test_data,
    " Header (ID01, ID06-ID14)
    cop_exg_no        TYPE matnr,   " ID01 header material
    bom_creation      TYPE datuv,   " ID06 BOMCreationDate  (NEW in ZBOM WSDL)
    alternative_bom   TYPE stlal,   " ID07
    bom_no            TYPE stnum,   " ID08
    change_no         TYPE aennr,   " ID09
    bom_usage         TYPE stlan,   " ID10
    header_start_date TYPE datuv,   " ID11
    header_end_date   TYPE datub,   " ID12
    header_qty        TYPE bmenge,   " ID13
    header_unit       TYPE meins,   " ID14
    " Item (ID02-ID05, ID15-ID17) — one component for the test payload
    cop_img_no        TYPE idnrk,   " ID02
    quantity          TYPE kmpmg,   " ID03
    valid_from        TYPE datuv,   " ID04
    valid_to          TYPE datub,   " ID05
    component_unit    TYPE meins,   " ID15
    operation_scrap   TYPE ausch,   " ID16 OperationScrapInPercent (NEW in ZBOM WSDL)
    component_scrap   TYPE ausch,   " ID17
  END OF ty_bom_test_data.

*====================================================================*
* Selection screen
*====================================================================*
SELECTION-SCREEN BEGIN OF BLOCK aif WITH FRAME TITLE TEXT-aif.
PARAMETERS:
  p_ns     TYPE /aif/ns              DEFAULT 'AIF_NS'    MODIF ID aif,
  p_ifname TYPE /aif/ifname          DEFAULT 'AIF_IFNAME'  MODIF ID aif,
  p_ifver  TYPE /aif/ifversion       DEFAULT '1'        MODIF ID aif,
  p_lport  TYPE prx_logical_port_name DEFAULT 'AIF_LOGICAL_PORT' MODIF ID aif,
  p_pers   AS CHECKBOX               DEFAULT 'X'        MODIF ID aif,
  p_dry    AS CHECKBOX               DEFAULT 'X'        MODIF ID aif.
SELECTION-SCREEN END OF BLOCK aif.

SELECTION-SCREEN BEGIN OF BLOCK hdr WITH FRAME TITLE TEXT-hdr.
PARAMETERS:
  p_matnr TYPE matnr    MODIF ID hdr,                 " ID01 copExgNo
  p_werks TYPE werks_d  DEFAULT 'DEFAULT_WERKS' MODIF ID hdr,  " plant (default per FS §4)
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
  p_avoau TYPE ausch  MODIF ID itm,                   " ID16 operationScrap (NEW)
  p_ausch TYPE ausch  MODIF ID itm,                   " ID17 componentScrap
  p_idatu TYPE datuv  MODIF ID itm,                   " ID04 component valid-from
  p_idatb TYPE datuv  MODIF ID itm.                   " ID05 component valid-to (DATUB)
SELECTION-SCREEN END OF BLOCK itm.

*====================================================================*
* Local class — ZBOM AIF send logic (extracted & standalone)
*====================================================================*
CLASS lcl_zbom_send_test DEFINITION FINAL.
  PUBLIC SECTION.

    " AIF interface constants (copied verbatim from ZCL_M1T_DCN_BOM_OUT_IMPL,
    " so the test program exercises the same namespace / interface / port as
    " production — ZBOM custom service ZBOMReplicateReq_Async_Out).
    CONSTANTS:
      gc_ns            TYPE /aif/ns        VALUE 'AIF_NS'   ##NO_TEXT,
      gc_ifname        TYPE /aif/ifname    VALUE 'AIF_IFNAME' ##NO_TEXT,
      gc_ifver         TYPE /aif/ifversion VALUE '1'        ##NO_TEXT,
      gc_logical_port  TYPE prx_logical_port_name VALUE 'AIF_LOGICAL_PORT' ##NO_TEXT,
      gc_aif_service   TYPE string         VALUE 'ZBOMReplicateReq_Async_Out' ##NO_TEXT,
      gc_default_werks TYPE werks_d VALUE 'DEFAULT_WERKS' ##NO_TEXT.

    CLASS-METHODS:
      build_business_header
        RETURNING VALUE(rs_header) TYPE zbusiness_document_message_hea,

      convert_timestamp
        CHANGING
          c_date TYPE datum
          c_time TYPE uzeit,

      build_aif_message
        IMPORTING is_data        TYPE ty_bom_test_data
        RETURNING VALUE(rs_msg) TYPE zzbomreplicate_request,

      fill_proxy_controllers
        CHANGING
          cs_msg TYPE zzbomreplicate_request,

      send
        IMPORTING is_params      TYPE ty_aif_params
                  is_data        TYPE ty_bom_test_data
        EXPORTING es_msg         TYPE zzbomreplicate_request
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

CLASS lcl_zbom_send_test IMPLEMENTATION.

  METHOD build_business_header.
    " Extraction of ZCL_M1T_DCN_BOM_OUT_IMPL~build_business_header:
    "   - id-content / uuid-content: UUID C32 (via cl_system_uuid)
    "   - creation_date_time: zglobal_date_time (dec(21,7)) — proxy datetime,
    "     NOT a string; produced by cl_bs_soa_convert_xsddatetime
    "   - sender_business_system_id: LCR_GET_OWN_BUSINESS_SYSTEM
    "   - recipient_business_system_id: target system
    " (Note: creation_date_time is overridden again at send time — see send().)
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

    " Recipient: the standalone test has no runtime_parameter_ext-business_system,
    " so the logical port name is used as the target system identifier (purely
    " informational; real routing is driven by logical_port_name of the FM).
    rs_header-recipient_business_system_id = gc_logical_port.
  ENDMETHOD.

  METHOD convert_timestamp.
    " CET local date/time → UTC (aligned with reference
    " CL_P_DCB_DRF_PRODVER_OUT~convert_timestamp). Handles the 24:00:00
    " midnight rollover before converting.
    DATA: time_stamp_utc TYPE timestamp.

    IF c_time = '240000'.
      CLEAR c_time.
      IF NOT c_date IS INITIAL.
        c_date = c_date + 1.
      ENDIF.
    ENDIF.

    CONVERT DATE c_date TIME c_time INTO TIME STAMP time_stamp_utc TIME ZONE 'CET'.
    IF sy-subrc = 0.
      CONVERT TIME STAMP time_stamp_utc TIME ZONE 'UTC'
        INTO DATE DATA(lv_utc_date) TIME DATA(lv_utc_time).
      IF sy-subrc = 0.
        c_date = lv_utc_date.
        c_time = lv_utc_time.
      ENDIF.
    ENDIF.
  ENDMETHOD.

  METHOD build_aif_message.
    " Extraction of ZCL_M1T_DCN_BOM_OUT_IMPL~build_aif_message: maps the local
    " 17-field BOM buffer to the ZBOM DDIC proxy structure zzbomreplicate_request
    " (the sap_struct registered in /aif/cust for ZBOMReplicateReq_Async_Out).
    "
    " BOM-centric layout (no PV/workflow nesting, no empty network-node hack):
    "   cs_msg-parameters-bom-bomheader     — ID01, ID06-ID14
    "   cs_msg-parameters-bom-bomcomponent[]— ID02-ID05, ID15-ID17
    "
    " Conversions (aligned with reference CL_P_DCB_DRF_PRODVER_OUT):
    "   - Material: CONVERSION_EXIT_MATN1_OUTPUT (SAP internal → external)
    "   - Unit:     CONVERSION_EXIT_CUNIT_OUTPUT (SAP internal → commercial) + shift/trim
    " All 17 FS fields mapped — including ID06 (BOMCreationDate) and
    " ID16 (OperationScrapInPercent) which have NO landing point in the PV structure.
    DATA: ls_component       TYPE zbomcomponent_type,
          lv_material_ext    TYPE matnr,
          lv_commercial_unit TYPE c LENGTH 3.

    CLEAR rs_msg.

    " Message header (UUID, creation datetime, sender/recipient)
    " (creation_date_time will be overridden at send time — see send().)
    rs_msg-parameters-message_header = build_business_header( ).

    " --- BOM header (ID01, ID06-ID14) ---

    " ID01: Material — convert to external format
    CALL FUNCTION 'CONVERSION_EXIT_MATN1_OUTPUT'
      EXPORTING
        input  = is_data-cop_exg_no
      IMPORTING
        output = lv_material_ext.
    rs_msg-parameters-bom-bomheader-material = lv_material_ext.

    rs_msg-parameters-bom-bomheader-plant                          = gc_default_werks.
    rs_msg-parameters-bom-bomheader-bomcategory                    = 'M'.
    rs_msg-parameters-bom-bomheader-bill_of_material               = is_data-bom_no.            " ID08
    rs_msg-parameters-bom-bomheader-bill_of_material_variant       = is_data-alternative_bom.   " ID07
    rs_msg-parameters-bom-bomheader-bill_of_material_variant_usage = is_data-bom_usage.         " ID10
    rs_msg-parameters-bom-bomheader-bomheader_quantity_in_base_uni = is_data-header_qty.       " ID13

    " ID14: Base unit — convert to commercial format
    CALL FUNCTION 'CONVERSION_EXIT_CUNIT_OUTPUT'
      EXPORTING
        input          = is_data-header_unit
        language       = 'E'
      IMPORTING
        output         = lv_commercial_unit
      EXCEPTIONS
        unit_not_found = 1
        OTHERS         = 2.
    IF sy-subrc = 0.
      rs_msg-parameters-bom-bomheader-bomheader_base_unit = lv_commercial_unit.
    ELSE.
      rs_msg-parameters-bom-bomheader-bomheader_base_unit = is_data-header_unit.
    ENDIF.
    SHIFT rs_msg-parameters-bom-bomheader-bomheader_base_unit RIGHT DELETING TRAILING space.
    SHIFT rs_msg-parameters-bom-bomheader-bomheader_base_unit LEFT  DELETING LEADING space.

    rs_msg-parameters-bom-bomheader-bomheader_ecn            = is_data-change_no.         " ID09
    rs_msg-parameters-bom-bomheader-bomcreation_date         = is_data-bom_creation.      " ID06 (NEW)
    rs_msg-parameters-bom-bomheader-bomvalidity_start_date   = is_data-header_start_date. " ID11
    rs_msg-parameters-bom-bomheader-bomvalidity_end_date     = is_data-header_end_date.   " ID12

    " --- BOM component (ID02-ID05, ID15-ID17) — one row ---
    CLEAR ls_component.

    " ID02: Component material — convert to external format
    CALL FUNCTION 'CONVERSION_EXIT_MATN1_OUTPUT'
      EXPORTING
        input  = is_data-cop_img_no
      IMPORTING
        output = lv_material_ext.
    ls_component-bill_of_material_component = lv_material_ext.

    ls_component-bill_of_material_item_quantity-content = is_data-quantity.     " ID03

    " ID15: Component unit — convert to commercial format
    CALL FUNCTION 'CONVERSION_EXIT_CUNIT_OUTPUT'
      EXPORTING
        input          = is_data-component_unit
        language       = 'E'
      IMPORTING
        output         = lv_commercial_unit
      EXCEPTIONS
        unit_not_found = 1
        OTHERS         = 2.
    IF sy-subrc = 0.
      ls_component-bill_of_material_item_quantity-unit_code = lv_commercial_unit.
    ELSE.
      ls_component-bill_of_material_item_quantity-unit_code = is_data-component_unit.
    ENDIF.
    SHIFT ls_component-bill_of_material_item_quantity-unit_code RIGHT DELETING TRAILING space.
    SHIFT ls_component-bill_of_material_item_quantity-unit_code LEFT  DELETING LEADING space.

    ls_component-validity_start_date        = is_data-valid_from.        " ID04
    ls_component-validity_end_date          = is_data-valid_to.          " ID05
    ls_component-component_scrap_in_percent = is_data-component_scrap.   " ID17
    ls_component-operation_scrap_in_percent = is_data-operation_scrap.   " ID16 (NEW)
    APPEND ls_component TO rs_msg-parameters-bom-bomcomponent.

    " CRITICAL: proxy structures only serialize fields whose controller flag
    " is set. Without this the persisted/sent XML body is empty even though the
    " ABAP structure is filled.
    fill_proxy_controllers( CHANGING cs_msg = rs_msg ).
  ENDMETHOD.

  METHOD fill_proxy_controllers.
    " Set the PRXCTRLTAB "field is filled" flag for every populated component
    " at every level of zzbomreplicate_request. The ABAP proxy runtime only
    " serializes components whose controller entry has value = abap_true;
    " without these flags the XML body comes out empty even when full.
    " Extraction of ZCL_M1T_DCN_BOM_OUT_IMPL~fill_proxy_controllers.

    " Root: zzbomreplicate_request
    cs_msg-controller = VALUE #( ( field = 'PARAMETERS' value = abap_true ) ).

    " parameters: zbomreplicate_request
    cs_msg-parameters-controller = VALUE #(
      ( field = 'MESSAGE_HEADER' value = abap_true )
      ( field = 'BOM'            value = abap_true ) ).

    " message_header: zbusiness_document_message_hea
    cs_msg-parameters-message_header-controller = VALUE #(
      ( field = 'ID'                           value = abap_true )
      ( field = 'UUID'                         value = abap_true )
      ( field = 'CREATION_DATE_TIME'           value = abap_true )
      ( field = 'SENDER_BUSINESS_SYSTEM_ID'    value = abap_true )
      ( field = 'RECIPIENT_BUSINESS_SYSTEM_ID' value = abap_true ) ).
    cs_msg-parameters-message_header-id-controller   = VALUE #( ( field = 'CONTENT' value = abap_true ) ).
    cs_msg-parameters-message_header-uuid-controller = VALUE #( ( field = 'CONTENT' value = abap_true ) ).

    " bom: zbomtype
    cs_msg-parameters-bom-controller = VALUE #(
      ( field = 'BOMHEADER'    value = abap_true )
      ( field = 'BOMCOMPONENT' value = abap_true ) ).

    " bomheader: zbomheader_type — all 12 populated fields
    cs_msg-parameters-bom-bomheader-controller = VALUE #(
      ( field = 'MATERIAL'                       value = abap_true )
      ( field = 'PLANT'                          value = abap_true )
      ( field = 'BOMCATEGORY'                    value = abap_true )
      ( field = 'BILL_OF_MATERIAL'               value = abap_true )
      ( field = 'BILL_OF_MATERIAL_VARIANT'       value = abap_true )
      ( field = 'BILL_OF_MATERIAL_VARIANT_USAGE' value = abap_true )
      ( field = 'BOMHEADER_QUANTITY_IN_BASE_UNI' value = abap_true )
      ( field = 'BOMHEADER_BASE_UNIT'            value = abap_true )
      ( field = 'BOMHEADER_ECN'                  value = abap_true )
      ( field = 'BOMCREATION_DATE'               value = abap_true )
      ( field = 'BOMVALIDITY_START_DATE'         value = abap_true )
      ( field = 'BOMVALIDITY_END_DATE'           value = abap_true ) ).

    " bomcomponent rows: zbomcomponent_type — per row
    LOOP AT cs_msg-parameters-bom-bomcomponent ASSIGNING FIELD-SYMBOL(<ls_comp>).
      <ls_comp>-controller = VALUE #(
        ( field = 'BILL_OF_MATERIAL_COMPONENT'     value = abap_true )
        ( field = 'BILL_OF_MATERIAL_ITEM_QUANTITY' value = abap_true )
        ( field = 'VALIDITY_START_DATE'            value = abap_true )
        ( field = 'VALIDITY_END_DATE'              value = abap_true )
        ( field = 'COMPONENT_SCRAP_IN_PERCENT'     value = abap_true )
        ( field = 'OPERATION_SCRAP_IN_PERCENT'     value = abap_true ) ).
      <ls_comp>-bill_of_material_item_quantity-controller = VALUE #(
        ( field = 'CONTENT'   value = abap_true )
        ( field = 'UNIT_CODE' value = abap_true ) ).
    ENDLOOP.
  ENDMETHOD.

  METHOD send.
    " Extraction of ZCL_M1T_DCN_BOM_OUT_IMPL~send_message (AIF send core),
    " without DRF framework pieces (repstatus, add_msg_xi, bal, testrun flag).
    " Preserved 1:1:
    "   - creation_date_time override at send time (convert_timestamp CET→UTC)
    "   - local copy of sap_struct (protects against FM mutation)
    "   - CALL FUNCTION '/AIF/SEND_WITH_PROXY'
    "   - tolerated PERSISTENCY_ERROR (=1)
    "   - business-error (E/A) scan of add_return_tab
    "   - error_string / error_long_text captured for diagnostics
    "   - cx_bs_soa_exception / cx_ai_system_fault catch
    DATA: lt_return   TYPE bapiret2_t,
          lv_msgguid  TYPE sxmsmguid,
          lv_subrc    TYPE sysubrc,
          lv_sent_ok  TYPE abap_bool VALUE abap_true,
          lv_err_str  TYPE string,
          lv_err_long TYPE string,
          lv_send_date TYPE datum,
          lv_send_time TYPE uzeit.

    CLEAR: es_msg, ev_msgguid, ev_msgguid_out, et_return,
           ev_error_str, ev_error_long, ev_subrc,
           ev_sent_ok, ev_except_text, ev_exception.

    " Build the AIF message.
    es_msg = build_aif_message( is_data = is_data ).

    IF is_params-dry_run = abap_true.
      " Dry run: return the assembled payload only, skip the actual send.
      ev_sent_ok = abap_true.
      ev_subrc   = 0.
      RETURN.
    ENDIF.

    " Override creation_date_time at send time (aligned with reference
    " CL_P_DCB_DRF_PRODVER_OUT~send_message — timestamp must reflect the actual
    " send moment, not the build moment). convert_timestamp does CET→UTC;
    " cl_bs_soa_convert produces the packed-decimal zglobal_date_time.
    lv_send_date = sy-datum.
    lv_send_time = sy-uzeit.
    convert_timestamp( CHANGING c_date = lv_send_date c_time = lv_send_time ).
    TRY.
        cl_bs_soa_convert_xsddatetime=>map_xsddatetime_long_z_out(
          EXPORTING
            iv_date         = lv_send_date
            iv_time         = lv_send_time
          IMPORTING
            ev_xsd_datetime = es_msg-parameters-message_header-creation_date_time ).
      CATCH cx_bs_soa_exception.
        CLEAR es_msg-parameters-message_header-creation_date_time.
    ENDTRY.

    " Local copy for the AIF send (aligned with reference:
    " ls_message_data_outbound = ms_output — protects the built message from
    " modification by /AIF/SEND_WITH_PROXY).
    DATA(ls_aif_message) = es_msg.

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
            sap_struct           = ls_aif_message
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
        " Return the (possibly mutated) local copy back to the caller so the
        " caller can inspect what the proxy runtime produced.
        es_msg     = ls_aif_message.
        et_return  = lt_return.
        ev_msgguid = lv_msgguid.
        ev_error_str  = lv_err_str.
        ev_error_long = lv_err_long.
        ev_subrc      = lv_subrc.

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
  "    so the program works out-of-the-box with the ZBOM config).
  DATA(ls_params) = VALUE ty_aif_params(
    ns           = COND #( WHEN p_ns     IS NOT INITIAL THEN p_ns     ELSE lcl_zbom_send_test=>gc_ns )
    ifname       = COND #( WHEN p_ifname IS NOT INITIAL THEN p_ifname ELSE lcl_zbom_send_test=>gc_ifname )
    ifversion    = COND #( WHEN p_ifver  IS NOT INITIAL THEN p_ifver  ELSE lcl_zbom_send_test=>gc_ifver )
    logical_port = COND #( WHEN p_lport  IS NOT INITIAL THEN p_lport  ELSE lcl_zbom_send_test=>gc_logical_port )
    persist_xml  = p_pers
    dry_run      = p_dry ).

  " 2. Build the test payload (header + one component, all 17 fields).
  DATA(ls_data) = VALUE ty_bom_test_data(
    cop_exg_no        = p_matnr
    bom_creation      = sy-datum                " ID06 — BOMCreationDate (NEW in ZBOM WSDL)
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
    operation_scrap   = p_avoau                 " ID16 — OperationScrapInPercent (NEW in ZBOM WSDL)
    component_scrap   = p_ausch                 " ID17
  ).

  " 3. Send (or dry-run).
  DATA: ls_msg         TYPE zzbomreplicate_request,
        lv_msgguid     TYPE sxmsmguid,
        lv_msgguid_out TYPE sxmsmguid,
        lt_return      TYPE bapiret2_t,
        lv_err_str     TYPE string,
        lv_err_long    TYPE string,
        lv_subrc       TYPE sysubrc,
        lv_sent_ok     TYPE abap_bool,
        lv_except_text TYPE string,
        lv_exception   TYPE string.

  lcl_zbom_send_test=>send(
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
  WRITE: / '==== /AIF/SEND_WITH_PROXY test result (ZBOM WSDL) ====' COLOR COL_HEADING.
  ULINE.

  WRITE: / 'AIF interface' COLOR COL_TOTAL,
         / '  namespace     :', ls_params-ns,
         / '  ifname        :', ls_params-ifname,
         / '  ifversion     :', ls_params-ifversion,
         / '  logical port  :', ls_params-logical_port,
         / '  persist_xml   :', ls_params-persist_xml,
         / '  mode          :', COND #( WHEN ls_params-dry_run = abap_true THEN 'DRY RUN (no send)' ELSE 'SEND' ).

  ULINE.
  WRITE: / 'Payload (zzbomreplicate_request — BOM-centric)' COLOR COL_TOTAL.
  WRITE: / '  message_header.id.content        :', ls_msg-parameters-message_header-id-content.
  WRITE: / '  message_header.uuid.content      :', ls_msg-parameters-message_header-uuid-content.
  WRITE: / '  message_header.creation_date_time :', ls_msg-parameters-message_header-creation_date_time.
  WRITE: / '  message_header.sender_business   :', ls_msg-parameters-message_header-sender_business_system_id.
  WRITE: / '  message_header.recipient_business:', ls_msg-parameters-message_header-recipient_business_system_id.
  ULINE.
  WRITE: / '  bom.bomheader (ID01, ID06-ID14)' COLOR COL_GROUP.
  DATA(ls_h) = ls_msg-parameters-bom-bomheader.
  WRITE: / '    ID01 material              :', ls_h-material.
  WRITE: / '         plant                 :', ls_h-plant.
  WRITE: / '         bomcategory           :', ls_h-bomcategory.
  WRITE: / '    ID08 bill_of_material      :', ls_h-bill_of_material.
  WRITE: / '    ID07 bom_variant           :', ls_h-bill_of_material_variant.
  WRITE: / '    ID10 bom_variant_usage     :', ls_h-bill_of_material_variant_usage.
  WRITE: / '    ID13 qty_in_base_unit      :', ls_h-bomheader_quantity_in_base_uni.
  WRITE: / '    ID14 base_unit             :', ls_h-bomheader_base_unit.
  WRITE: / '    ID09 bomheader_ecn         :', ls_h-bomheader_ecn.
  WRITE: / '    ID06 bomcreation_date      :', ls_h-bomcreation_date.
  WRITE: / '    ID11 validity_start_date   :', ls_h-bomvalidity_start_date.
  WRITE: / '    ID12 validity_end_date     :', ls_h-bomvalidity_end_date.
  ULINE.
  WRITE: / '  bom.bomcomponent[] (ID02-ID05, ID15-ID17)' COLOR COL_GROUP.
  WRITE: / '    component count :', lines( ls_msg-parameters-bom-bomcomponent ).
  LOOP AT ls_msg-parameters-bom-bomcomponent INTO DATA(ls_c).
    WRITE: / '    --- row', sy-tabix, '---'.
    WRITE: / '    ID02 component              :', ls_c-bill_of_material_component.
    WRITE: / '    ID03 quantity.content       :', ls_c-bill_of_material_item_quantity-content.
    WRITE: / '    ID15 quantity.unit_code     :', ls_c-bill_of_material_item_quantity-unit_code.
    WRITE: / '    ID04 validity_start_date    :', ls_c-validity_start_date.
    WRITE: / '    ID05 validity_end_date      :', ls_c-validity_end_date.
    WRITE: / '    ID17 component_scrap_%      :', ls_c-component_scrap_in_percent.
    WRITE: / '    ID16 operation_scrap_%      :', ls_c-operation_scrap_in_percent.
  ENDLOOP.
  ULINE.
  WRITE: / '  proxy controller flags (PRXCTRLTAB)' COLOR COL_GROUP.
  WRITE: / '    root PARAMETERS              :', lines( ls_msg-controller ).
  WRITE: / '    parameters (MSGHDR/BOM)      :', lines( ls_msg-parameters-controller ).
  WRITE: / '    message_header               :', lines( ls_msg-parameters-message_header-controller ).
  WRITE: / '    bom (BOMHDR/BOMCOMP)         :', lines( ls_msg-parameters-bom-controller ).
  WRITE: / '    bomheader                    :', lines( ls_msg-parameters-bom-bomheader-controller ).
  LOOP AT ls_msg-parameters-bom-bomcomponent INTO ls_c.
    WRITE: / '    component row', sy-tabix, 'ctrls:', lines( ls_c-controller ).
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
