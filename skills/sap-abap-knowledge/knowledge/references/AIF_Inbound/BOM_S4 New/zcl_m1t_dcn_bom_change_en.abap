*"! <p class="shorttext synchronized">DRF BOM Outbound: Business Processing Singleton (S4H → ECMS)</p>
*"!
*"! Contains all business logic: change analysis, filtering, bulk data retrieval, message mapping, AIF sending, result write-back.
*"! Invoked by the framework adapter layer ZCL_M1T_DCN_BOM_OUT through a CLASS-DATA singleton reference.
*"! Corresponds to FS: BOM SAP to ECMS interface (ZCN_ECMS / ZDCN_PBOM)
CLASS zcl_m1t_dcn_bom_change DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

*"! BOM object key table type
    TYPES:
      BEGIN OF bom_key_ty,
        stlan TYPE stlan,   " BOM usage
        werks TYPE werks_d, " Plant
        matnr TYPE matnr,   " Material
        stlal TYPE stlal,   " Alternative BOM
        stlty TYPE stlty,   " BOM Category
        aennr TYPE aennr,   " ECN
        stlnr TYPE stnum,   " BOM number (pre-fetched by filter, non-key field)
      END OF bom_key_ty,
      key_table_ty TYPE SORTED TABLE OF bom_key_ty
               WITH UNIQUE KEY stlan werks matnr stlal stlty aennr.
    DATA runtime_parameter_ext TYPE drf_s_runtime_parameter_ext.

    METHODS analyze_changes_by_chg_pointer
      IMPORTING it_change_pointer  TYPE drf_t_bdcp
      EXPORTING et_changed_objects TYPE key_table_ty
                es_stat_info       TYPE drf_s_stat_info
      RAISING   cx_drf_analyze_changes
                cx_drf_exception.

    METHODS analyze_changes_by_others
      EXPORTING et_changed_objects TYPE key_table_ty
                es_stat_info       TYPE drf_s_stat_info
      RAISING   cx_drf_analyze_changes
                cx_drf_exception.

    METHODS enrich_filter_criteria
      IMPORTING it_external_criteria     TYPE rsds_trange
      EXPORTING es_stat_info             TYPE drf_s_stat_info
                et_add_external_criteria TYPE rsds_trange
      RAISING   cx_drf_exception.

    METHODS read_complete_data
      CHANGING ct_relevant_objects TYPE key_table_ty
      RAISING  cx_drf_process_messages
               cx_drf_exception.

    METHODS map_data2message
      IMPORTING ir_relevant_object TYPE REF TO data
      RAISING   cx_drf_process_messages
                cx_drf_exception.

    METHODS send_message
      IMPORTING is_file_info    TYPE drf_s_file_info
                iv_object_count TYPE drf_package_size
      EXPORTING et_file_data    TYPE drf_t_file_oi_content
                et_message      TYPE drf_t_message
      CHANGING  ct_obj_rep_sta  TYPE drf_t_obj_rep_sta_full
      RAISING   cx_drf_process_messages
                cx_drf_exception.

    METHODS finalize
      IMPORTING it_erroneous_objects     TYPE key_table_ty
                it_relevant_objects      TYPE key_table_ty
                iv_repeated_initial_run  TYPE boole_d
      EXPORTING ev_delete_change_pointer TYPE boole_d.

  PRIVATE SECTION.

*" --- AIF interface parameters (FS erratum 3: BOM uses the ManufacturingProdnVersInfo_Out
*"     outbound service; aligned with reference /RGS/CL_P_DCB_DRF_PRODVER_OUT:
*"     YPMES namespace + YOMES_PV / YMESPVOUT) ---
    CONSTANTS gc_ns            TYPE /aif/ns        VALUE 'YPMES'  ##NO_TEXT.
    CONSTANTS gc_ifname        TYPE /aif/ifname    VALUE 'YOMES_PV' ##NO_TEXT.  " ManufacturingProdnVersInfo_Out outbound service
    CONSTANTS gc_ifver         TYPE /aif/ifversion VALUE '1'        ##NO_TEXT.
    CONSTANTS gc_logical_port  TYPE prx_logical_port_name VALUE 'YMESPVOUT' ##NO_TEXT.
    CONSTANTS gc_aif_service   TYPE string         VALUE 'ManufacturingProdnVersInfo_Out' ##NO_TEXT.  " service name for exception logs (aligned with reference lc_matgrp_service)
    CONSTANTS gc_msgid         TYPE symsgid        VALUE 'ZDCN_PBOM'  ##NO_TEXT.

*" --- BOM change-pointer related constants ---
    CONSTANTS gc_cp_tabname_mast TYPE cdtabkey   VALUE 'MAST'  ##NO_TEXT.
    CONSTANTS gc_cp_tabname_stko TYPE cdtabkey   VALUE 'STKO'  ##NO_TEXT.
    CONSTANTS gc_cp_tabname_stpo TYPE cdtabkey   VALUE 'STPO'  ##NO_TEXT.

*" --- ECN status constants ---
    CONSTANTS gc_ecn_status_released TYPE aenst VALUE '2' ##NO_TEXT.  " '2'=Released

*" --- Default filter condition constants (FS §4) ---
    CONSTANTS gc_default_werks TYPE werks_d VALUE 'Q511' ##NO_TEXT.  " FS §4 default Plant
    CONSTANTS gc_default_stlan TYPE stlan   VALUE '1'   ##NO_TEXT.  " FS §4 default BOM Usage

*" --- CDOBJID field length constants (aligned to DDIC primary key lengths) ---
    " MAST primary key: MATNR(18)+WERKS(4)+STLAN(1)+STLAL(2); STKO/STPO: STLTY(1)+STLNR(8).
    " If field lengths change, update here only, to avoid hardcoded offset misalignment.
    CONSTANTS gc_len_matnr TYPE i VALUE 18 ##NO_TEXT.
    CONSTANTS gc_len_werks TYPE i VALUE 4  ##NO_TEXT.
    CONSTANTS gc_len_stlan TYPE i VALUE 1  ##NO_TEXT.
    CONSTANTS gc_len_stlal TYPE i VALUE 2  ##NO_TEXT.
    CONSTANTS gc_len_stlnr TYPE i VALUE 8  ##NO_TEXT.

*" --- Volume control constants (FS §14: min 300/day, max 1000/day during site go-live cutover) ---
    " Object upper limit per retrieval in analyze_changes_by_others (Initial / manual on-demand).
    " Aligned to FS §14 max 1000 documents/day; prevents exceeding the limit on full scans with default conditions when no screen input.
    CONSTANTS gc_initial_max_rows TYPE i VALUE 1000 ##NO_TEXT.
    CONSTANTS gc_initial_min_rows TYPE i VALUE 300  ##NO_TEXT.  " FS §14 lower limit

    " --- ECMS message structure (FS §7 17 fields) ---
    " Local structure bom_header_ty / bom_item_ty: SAP-side data buffers (MAST/STKO/STPO/MARA source fields),
    " used only as intermediate assembly in map_data2message;
    " The AIF outbound message structure aif_bom_message_ty directly uses the standard type
    " ppint_mfg_prodn_vers_inf (the AIF service ManufacturingProdnVersInfo_Out message type,
    " aligned with reference /RGS/CL_P_DCB_DRF_PRODVER_OUT~map_data2message and the sap_struct
    " passed to /AIF/SEND_WITH_PROXY).
    "
    " ppint_mfg_prodn_vers_inf component landing points (mapped to the XML elements in map2xml.md):
    "   - production_version_information (ppint_prodn_vers_information table):
    "       ID01 copExgNo   -> material
    "       ID07 alternativeBom -> bill_of_material_variant
    "       ID10 useTo      -> bill_of_material_variant_usage
    "   - Root-level BOM Header components:
    "       ID08 bomNo        -> bill_of_material
    "       ID09 changeNo     -> bom_header_ecn
    "       ID11/ID12        -> bom_extra_data[]-bom_validity_start/end_date
    "       ID13 copExgQty   -> quantity_in_base_unit
    "       ID14 copExgUnit  -> base_unit
    "       ID17 componentScrap -> component scrap (carried via the component allocation row)
    "   - bill_of_operations_activity_ne (process network element) -> activity_co (component allocation):
    "       ID02 copImgNo -> bill_of_material_component
    "       ID03 decCm    -> bill_of_material_item_quantity-content
    "       ID04/ID05    -> validity_start_date / validity_end_date
    "       ID15 copImgUnit -> bill_of_material_item_quantity-unit_code
    "   - ID06 bomCreation (STKO-ANDAT) and ID16 operationScrap (STPO-AVOAU):
    "       No standard XML landing point (see map2xml.md §3.3); retained in the local structure,
    "       mapped/defaulted on the MuleSoft side.
    TYPES:
      BEGIN OF bom_header_ty,
        cop_exg_no        TYPE matnr,
        bom_creation      TYPE datuv,
        alternative_bom   TYPE stlal,
        bom_no            TYPE stnum,
        change_no         TYPE aennr,
        bom_usage         TYPE stlan,
        header_start_date TYPE datuv,
        header_end_date   TYPE datub,
        header_qty        TYPE bmenge,
        header_unit       TYPE meins,
      END OF bom_header_ty,
      BEGIN OF bom_item_ty,
        cop_img_no      TYPE idnrk,
        quantity        TYPE kmpmg,
        valid_from      TYPE datuv,
        valid_to        TYPE datub,
        component_unit  TYPE meins,
        operation_scrap TYPE ausch,
        component_scrap TYPE ausch,
      END OF bom_item_ty,
      bom_items_ty TYPE STANDARD TABLE OF bom_item_ty WITH EMPTY KEY,
      BEGIN OF bom_message_ty,
        header TYPE bom_header_ty,
        items  TYPE bom_items_ty,
      END OF bom_message_ty,
      " AIF outbound message: standard structure (matches the reference /AIF/SEND_WITH_PROXY sap_struct)
      aif_bom_message_ty TYPE ppint_mfg_prodn_vers_inf,
      " Local ECN status row type: avoids the `TYPE SORTED TABLE OF aenr` parameter issue
      " where the `aenr` structure cannot be interpreted (ADT reports Unable to interpret "AENR").
      " Only the two columns needed by is_ecn_valid: aennr (data element, verified usable) + aenst (1 char).
      BEGIN OF ecn_status_ty,
        aennr TYPE aennr,
        aenst TYPE c LENGTH 1,
      END OF ecn_status_ty,
      " Named table types: anonymous inline `SORTED TABLE OF ...` definitions are unreliable
      " under ADT, so the types must be defined separately for method parameters and VALUE.
      ecn_status TYPE SORTED TABLE OF ecn_status_ty WITH UNIQUE KEY aennr,
      ecn_key    TYPE SORTED TABLE OF aennr WITH UNIQUE KEY table_line.

    DATA mast_list    TYPE STANDARD TABLE OF mast.
    DATA stko_list    TYPE STANDARD TABLE OF stko.
    DATA stpo_list    TYPE STANDARD TABLE OF stpo.
    DATA stas_list    TYPE STANDARD TABLE OF stas.
    DATA mara_list    TYPE STANDARD TABLE OF mara.
    DATA bom_header   TYPE bom_header_ty.
    DATA bom_items    TYPE bom_items_ty.
    DATA bom_message  TYPE bom_message_ty.
    " AIF outbound message (standard structure ppint_mfg_prodn_vers_inf, sent via /AIF/SEND_WITH_PROXY)
    DATA aif_bom_message TYPE aif_bom_message_ty.

    " Screen-derived STKO date ranges (parsed in enrich_filter_criteria, applied in read_complete_data).
    " The framework routes DATUV/DATUB under tablename='STKO', but neither the CP CDOBJID nor the filter's
    " MAST query can apply them (MAST has no date columns; STKO CP CDOBJID = stlty+stlnr has no dates).
    " read_complete_data is the only layer that queries STKO directly, so it must enforce the date filter.
    " Empty range = match all (no screen input) -> behavior unchanged.
    DATA mt_stko_datuv TYPE rsds_selopt_t.   " screen DATUV (valid-from), applied to STKO~datuv
    DATA mt_stko_datub TYPE rsds_selopt_t.   " screen DATUB (valid-to), applied to STKO~valid_to

    " Filter instance - kept locally so read_complete_data can invoke apply_filter itself when the
    " framework bypassed it (RUNMOD_BYPASS_FILTER), mirroring reference CL_P_DCB_DRF_PROCORD_OUT.
    DATA mo_bom_filter TYPE REF TO if_drf_filter.

    " AIF outbound tool instance - kept locally so send_message delegates /AIF/SEND_WITH_PROXY.
    " The business layer never calls the AIF engine FM directly; it interacts with AIF only via
    " zcl_aif_outbound_util (mirrors the delegation pattern of zcl_aif_bom_out_service).
    DATA mo_aif_util TYPE REF TO zcl_aif_outbound_util.

    METHODS get_aif_util
      RETURNING VALUE(ro_aif_util) TYPE REF TO zcl_aif_outbound_util.

    METHODS get_bom_filter
      RETURNING VALUE(ro_bom_filter) TYPE REF TO if_drf_filter.

    METHODS is_ecn_valid
      IMPORTING iv_aennr        TYPE aennr
                it_aenr_status  TYPE ecn_status
      RETURNING VALUE(rv_valid) TYPE boole_d.

    METHODS map_bom_header
      IMPORTING is_stko TYPE stko
                is_mast TYPE mast
                is_mara TYPE mara
      CHANGING  cs_bom  TYPE bom_header_ty.

    METHODS map_bom_item
      IMPORTING is_stpo TYPE stpo
      CHANGING  cs_item TYPE bom_item_ty.

    METHODS build_aif_message
      IMPORTING is_bom_message TYPE bom_message_ty
      CHANGING cs_aif_message  TYPE aif_bom_message_ty.

    METHODS build_business_header
      RETURNING VALUE(rs_header) TYPE ppint_busdoc_msg_hdr.

ENDCLASS.


CLASS zcl_m1t_dcn_bom_change IMPLEMENTATION.

  METHOD analyze_changes_by_chg_pointer.
    " Change analysis (Change Pointer mode): extracts BOM object keys from the change pointer table.
    " FS §5 change trigger matrix: DRF_T_BDCP object-level aggregation, no field-level filtering.
    " CDOBJID format (concatenated in standard SAP primary key order):
    "   MAST: MATNR(18)+WERKS(4)+STLAN(1)+STLAL(2)
    "   STKO: STLTY(1)+STLNR(8)
    "   STPO: STLTY(1)+STLNR(8)+POSNR(6)

    DATA change_pointer_table   TYPE drf_t_bdcp.
    DATA keys                  TYPE key_table_ty.
    DATA key                   TYPE bom_key_ty.
    DATA stko_stpo_range        TYPE RANGE OF stnum.                            " STLNR of STKO/STPO CP (dedicated reverse lookup of MAST 4 cols)
    DATA mast_all               TYPE STANDARD TABLE OF mast WITH EMPTY KEY.     " Unified MAST rows (MAST CP + STKO/STPO CP)
    DATA stko_stpo_mast         TYPE STANDARD TABLE OF mast WITH EMPTY KEY.     " STKO/STPO CP-specific MAST reverse-lookup result
    DATA stko_aennr_lookup      TYPE STANDARD TABLE OF stko WITH EMPTY KEY.  " STKO reverse lookup: STLTY/AENNR (ECN) for the change-pointer MAST rows
    DATA ecn_filtered_cnt       TYPE i.                                       " Count of objects dropped by the ECN status check

    " Temporary: MAST CDOBJID parse result, used to look up STLNR in bulk
    TYPES:
      BEGIN OF mast_cp_key,
        matnr TYPE matnr,
        werks TYPE werks_d,
        stlan TYPE stlan,
        stlal TYPE stlal,
      END OF mast_cp_key.
    DATA mast_cp_keys TYPE STANDARD TABLE OF mast_cp_key WITH EMPTY KEY.

    change_pointer_table = it_change_pointer.

    " NOTE: DRF_T_BDCP is a "Storage-Optimized Change Pointer" (object-level aggregation),
    " it carries no field-level information, so deduplicate only by object dimension.
    " drf_s_bdcp structure fields: cpident / tabname / tabkey / fldname / cdobjcl / cdobjid etc.;
    " here we sort by tabname+cdobjid and deduplicate (tabname distinguishes MAST/STKO/STPO).
    SORT change_pointer_table BY tabname cdobjid.
    DELETE ADJACENT DUPLICATES FROM change_pointer_table COMPARING tabname cdobjid.

    " Note: DRF selection parameters (WERKS/MATNR/STLAN/STLAL/DATUV/DATUB) are filtered by the DRF framework when querying
    "     CDHDR to generate change pointers per the config table; business code should not assume runtime_parameter_ext
    "     contains specific fields such as sel_mara/sel_stko (the DRF_S_RUNTIME_PARAMETER_EXT structure does not contain such components).
    "     Business code here only handles object-level change pointers already filtered by the framework.

    " --- 1. MAST changes: parse CDOBJID -> bulk look up the complete BOM key (incl. STLNR) ---
    "        CDOBJID offsets must match the standard SAP MAST primary key order
    "        (MATNR+WERKS+STLAN+STLAL).
    LOOP AT change_pointer_table INTO DATA(mast_change_pointer) WHERE tabname = gc_cp_tabname_mast.
      " Lengths use named constants (aligned to DDIC primary key lengths); offsets must be literals
      " (ABAP source+off(len) allows only literals for off, len may reference a constant, so keep 0/18/22/23).
      INSERT VALUE mast_cp_key(
        matnr = mast_change_pointer-cdobjid+0(gc_len_matnr)
        werks = mast_change_pointer-cdobjid+18(gc_len_werks)
        stlan = mast_change_pointer-cdobjid+22(gc_len_stlan)
        stlal = mast_change_pointer-cdobjid+23(gc_len_stlal) ) INTO TABLE mast_cp_keys.
    ENDLOOP.

    IF mast_cp_keys IS NOT INITIAL.
      " MAST CP reverse lookup (fetch all 5 columns including STLNR in one pass),
      " avoiding the former second MAST lookup by STLNR (dual-query optimization).
      SELECT matnr, stlan, werks, stlal, stlnr
        FROM mast
        INTO CORRESPONDING FIELDS OF TABLE @mast_all
        FOR ALL ENTRIES IN @mast_cp_keys
        WHERE matnr = @mast_cp_keys-matnr
          AND werks = @mast_cp_keys-werks
          AND stlan = @mast_cp_keys-stlan
          AND stlal = @mast_cp_keys-stlal.
    ENDIF.

    " --- 2/3. STKO/STPO changes: object-level trigger (DRF_T_BDCP carries no field-level information) ---
    " Collected separately from MAST CP; only the STKO/STPO CP-specific STLNR triggers the MAST
    " 4-column reverse lookup (MAST CP STLNR already got its complete key in the previous step).
    LOOP AT change_pointer_table INTO DATA(stko_change_pointer) WHERE tabname = gc_cp_tabname_stko.
      INSERT VALUE #( sign = 'I' option = 'EQ' low = stko_change_pointer-cdobjid+1(gc_len_stlnr) )
        INTO TABLE stko_stpo_range.
    ENDLOOP.
    LOOP AT change_pointer_table INTO DATA(stpo_change_pointer) WHERE tabname = gc_cp_tabname_stpo.
      INSERT VALUE #( sign = 'I' option = 'EQ' low = stpo_change_pointer-cdobjid+1(gc_len_stlnr) )
        INTO TABLE stko_stpo_range.
    ENDLOOP.

    IF stko_stpo_range IS NOT INITIAL.
      CLEAR stko_stpo_mast.
      SELECT matnr, stlan, werks, stlal, stlnr
        FROM mast
        INTO CORRESPONDING FIELDS OF TABLE @stko_stpo_mast
        WHERE stlnr IN @stko_stpo_range.
      APPEND LINES OF stko_stpo_mast TO mast_all.
    ENDIF.

    " --- 4. Look up MAST/STKO to get the complete BOM key and ECN ---
    "       STLNR is already precisely located by the CP's CDOBJID; no additional STLAN filter here
    "       (the CP already contains the plant/BOM usage dimension; adding a filter may miss multi-MAST association scenarios).
    " Dedup: the same STLNR may hit both MAST CP and STKO/STPO CP.
    IF mast_all IS NOT INITIAL.
      SORT mast_all BY matnr werks stlan stlal stlnr.
      DELETE ADJACENT DUPLICATES FROM mast_all
        COMPARING matnr werks stlan stlal stlnr.
      " Read STLTY/AENNR from STKO
      " FAE empty-guard: skip the SELECT when mast_all is empty (no MAST match
      " for the given STLNR), otherwise FOR ALL ENTRIES IN an empty table matches
      " the whole table and pulls STLTY/AENNR for all BOMs.
      SELECT stlnr, stlty, aennr
        FROM stko
        INTO TABLE @stko_aennr_lookup
        FOR ALL ENTRIES IN @mast_all
        WHERE stlnr = @mast_all-stlnr.
      LOOP AT mast_all INTO DATA(mast_line).
        CLEAR key.
        key-stlan = mast_line-stlan.
        key-werks = mast_line-werks.
        key-matnr = mast_line-matnr.
        key-stlal = mast_line-stlal.
        " Get STLTY and AENNR from STKO (first ECN version for the same STLNR)
        " READ TABLE ... WITH KEY stlnr retrieves the first matching STKO header for the
        " given STLNR, consistent with the former nested LOOP...WHERE...EXIT semantics;
        " single-level key lookup with no nested loop.
        READ TABLE stko_aennr_lookup INTO DATA(stko_line) WITH KEY stlnr = mast_line-stlnr.
        IF sy-subrc = 0.
          key-stlty = stko_line-stlty.
          key-aennr = stko_line-aennr.
        ENDIF.
        INSERT key INTO TABLE keys.
      ENDLOOP.
    ENDIF.

    " --- 5. ECN status check (FS §5: all change types require an ECN) ---
    "       Count of filtered objects (no ECN or ECN not released),
    "       to let operations identify objects "filtered due to ECN" in the DRF run log.
    "       Bulk pre-load AENR status (aennr/aenst), replacing the per-object SELECT SINGLE
    "       in is_ecn_valid (eliminates the N+1 query).
    DATA(ecn_set) = VALUE ecn_key( ).
    LOOP AT keys INTO key.
      IF key-aennr IS NOT INITIAL.
        INSERT key-aennr INTO TABLE ecn_set.
      ENDIF.
    ENDLOOP.
    DATA(lt_aenr_status) = VALUE ecn_status( ).
    IF ecn_set IS NOT INITIAL.
      SELECT aennr, aenst FROM aenr
        INTO CORRESPONDING FIELDS OF TABLE @lt_aenr_status
        FOR ALL ENTRIES IN @ecn_set
        WHERE aennr = @ecn_set-table_line.
    ENDIF.

    DATA(keys_valid) = VALUE key_table_ty( ).
    LOOP AT keys INTO key.
      IF key-aennr IS NOT INITIAL
         AND is_ecn_valid( iv_aennr = key-aennr
                           it_aenr_status = lt_aenr_status ) = abap_true.
        INSERT key INTO TABLE keys_valid.
      ELSE.
        ecn_filtered_cnt = ecn_filtered_cnt + 1.
      ENDIF.
    ENDLOOP.
    et_changed_objects = keys_valid.

    " Expose the filter count to operations
    IF ecn_filtered_cnt > 0
       AND runtime_parameter_ext-bal IS BOUND.
      runtime_parameter_ext-bal->add_msg(
        iv_msgty = if_drf_const=>msg_type_warning
        iv_msgid = gc_msgid
        iv_msgno = '001'
        iv_msgv1 = |{ ecn_filtered_cnt }|
        iv_msgv2 = |{ lines( keys ) }| ).
    ENDIF.

    es_stat_info-object_count_out = lines( et_changed_objects ).
    es_stat_info-exception_raised = abap_false.
  ENDMETHOD.


  METHOD analyze_changes_by_others.
    " Non-Change-Pointer mode: initial load / manual on-demand (FS §4).
    " Reads BOMs from MAST matching the filter criteria and returns the object keys.
    "
    " DRF architecture constraint: screen selection values (WERKS/MATNR/STLAN/STLAL/DATUV/DATUB) are received only via
    " enrich_filter_criteria's it_external_criteria (rsds_trange), and DRF
    " calls analyze_changes_by_others before enrich_filter_criteria, so this method
    " cannot access the screen values. In the Initial scenario, data is read with the FS §4 defaults (WERKS='Q511', STLAN='1')
    " as the candidate range; the actual filtering is done by the framework in the CP query phase using the criteria returned by enrich_filter_criteria
    " (see enrich_filter_criteria; takes effect only when a filter object is configured).
    DATA: werks TYPE werks_d VALUE gc_default_werks,   " FS §4 default Plant
          stlan TYPE stlan   VALUE gc_default_stlan.   " FS §4 default BOM Usage
    DATA mast_all TYPE STANDARD TABLE OF mast WITH EMPTY KEY.
    DATA keys     TYPE key_table_ty.
    DATA key      TYPE bom_key_ty.

    " Default filter criteria (FS §4): WERKS='Q511', STLAN='1'
    " Note: MAST does not contain STLTY/AENNR; both are provided by STKO
    " Volume control (FS §14): max 1000/day during go-live cutover; the UP TO limit prevents
    " exceeding the limit on full scans with default conditions; increments are handled by the Nightly CP mode (change pointer),
    " the Initial mode only does the base load plus the volume limit fallback.
    " Deterministic sort (primary key order) makes truncation predictable; fetch 1 extra row to detect overflow.
    " Note: the UP TO clause does not allow arithmetic expressions (e.g. gc_initial_max_rows + 1), so a local variable is used.
    DATA(max_rows_plus1) = gc_initial_max_rows + 1.
    SELECT matnr, stlan, werks, stlal, stlnr
      FROM mast
      INTO CORRESPONDING FIELDS OF TABLE @mast_all
      UP TO @max_rows_plus1 ROWS
      WHERE werks = @werks
        AND stlan = @stlan
      ORDER BY matnr, werks, stlan, stlal.

    " Overflow detection - fetching 1001 rows means candidates exceed the limit; drop the probe row and write a warning
    IF lines( mast_all ) > gc_initial_max_rows.
      DELETE mast_all INDEX gc_initial_max_rows + 1.
      IF runtime_parameter_ext-bal IS BOUND.
        runtime_parameter_ext-bal->add_msg(
          iv_msgty = if_drf_const=>msg_type_warning
          iv_msgid = gc_msgid
          iv_msgno = '001'
          iv_msgv1 = |{ gc_initial_max_rows }|
          iv_msgv2 = 'Initial candidates exceed the limit; truncated' ).
      ENDIF.
    ELSEIF lines( mast_all ) < gc_initial_min_rows
       AND runtime_parameter_ext-bal IS BOUND.
      " FS §14 lower limit 300 notice (not forcibly sent, only a warning)
      runtime_parameter_ext-bal->add_msg(
        iv_msgty = if_drf_const=>msg_type_info
        iv_msgid = gc_msgid
        iv_msgno = '001'
        iv_msgv1 = |{ lines( mast_all ) }|
        iv_msgv2 = 'Initial candidates below the FS §14 lower limit of 300' ).
    ENDIF.

    IF mast_all IS NOT INITIAL.
      " Bulk look up STKO for STLTY/AENNR (ECN)
      SELECT stlnr, stlty, aennr
        FROM stko
        INTO TABLE @DATA(stko_aennr_lookup)
        FOR ALL ENTRIES IN @mast_all
        WHERE stlnr = @mast_all-stlnr.
      SORT stko_aennr_lookup BY stlnr.  " Align with MAST order for subsequent key lookup of the first match
      LOOP AT mast_all INTO DATA(mast_line).
        CLEAR key.
        key-stlan = mast_line-stlan.
        key-werks = mast_line-werks.
        key-matnr = mast_line-matnr.
        key-stlal = mast_line-stlal.
        " READ TABLE ... WITH KEY stlnr retrieves the first matching STKO header for the
        " given STLNR, consistent with the former nested LOOP...WHERE...EXIT semantics.
        READ TABLE stko_aennr_lookup INTO DATA(stko_line) WITH KEY stlnr = mast_line-stlnr BINARY SEARCH.
        IF sy-subrc = 0.
          key-stlty = stko_line-stlty.
          key-aennr = stko_line-aennr.
        ENDIF.
        " ECN is a mandatory condition (FS §5): keep only BOMs with a valid ECN
        INSERT key INTO TABLE keys.
      ENDLOOP.

      " Bulk pre-load AENR status (replacing the per-object SELECT SINGLE in is_ecn_valid, N+1)
      DATA(ecn_set) = VALUE ecn_key( ).
      LOOP AT keys INTO key.
        IF key-aennr IS NOT INITIAL.
          INSERT key-aennr INTO TABLE ecn_set.
        ENDIF.
      ENDLOOP.
      DATA(lt_aenr_status) = VALUE ecn_status( ).
      IF ecn_set IS NOT INITIAL.
        SELECT aennr, aenst FROM aenr
          INTO CORRESPONDING FIELDS OF TABLE @lt_aenr_status
          FOR ALL ENTRIES IN @ecn_set
          WHERE aennr = @ecn_set-table_line.
      ENDIF.

      " Filter: keep only BOMs with a valid ECN (FS §5)
      DATA(keys_valid) = VALUE key_table_ty( ).
      LOOP AT keys INTO key.
        IF key-aennr IS NOT INITIAL
           AND is_ecn_valid( iv_aennr = key-aennr
                             it_aenr_status = lt_aenr_status ) = abap_true.
          INSERT key INTO TABLE keys_valid.
        ENDIF.
      ENDLOOP.
      et_changed_objects = keys_valid.
    ENDIF.

    " Full assignment of es_stat_info
    es_stat_info-object_count_out = lines( et_changed_objects ).
    es_stat_info-exception_raised = abap_false.
  ENDMETHOD.


  METHOD enrich_filter_criteria.
    " DRF selection parameters (FS §4) are entered on the DRFOUT screen; the framework passes them as rsds_trange via it_external_criteria
    " (tablename='MAST'/'STKO', fieldname=field name, selopt_t=sign/option/low/high).
    " This method parses the screen values, fills the mandatory defaults per FS §4, and rebuilds et_add_external_criteria:
    "   MAST-WERKS  mandatory, default Q511
    "   MAST-MATNR  optional
    "   MAST-STLAN  mandatory, default 1
    "   MAST-STLAL  optional
    "   STKO-DATUV  optional (Valid-From)
    "   STKO-DATUB  optional (Valid-To)
    " Reference resources CL_P_MCN_DRF_BATCH_OUT.abap:736-780 / CL_P_DCB_DRF_PROCORD_OUT.abap:1173-1202
    DATA: werks    TYPE rsds_selopt_t, matnr TYPE rsds_selopt_t,
          stlan    TYPE rsds_selopt_t, stlal TYPE rsds_selopt_t,
          datuv    TYPE rsds_selopt_t, datub TYPE rsds_selopt_t,
          selopt   TYPE rsdsselopt,
          selfield TYPE rsds_frange,
          seltab   TYPE rsds_range.

    " Always parse the screen selection criteria and output et_add_external_criteria (see the in-production implementation
    " CL_P_MCN_DRF_BATCH_OUT.abap:736-780; enrich_filter_criteria does not short-circuit on fobj).
    " The DRF framework narrows the change pointer query with the returned criteria (CP mode: Nightly/Ad-Hoc active),
    " ensuring the screen inputs WERKS/MATNR/STLAN/STLAL/DATUV/DATUB take effect on data retrieval.
    " Note: Initial (by_others) mode cannot access the screen values due to the DRF architecture; it is covered by the defaults in analyze_changes_by_others
    "      (FS §4: WERKS=Q511/STLAN=1).

    " 1. Parse screen input (it_external_criteria), route by tablename/fieldname
    LOOP AT it_external_criteria ASSIGNING FIELD-SYMBOL(<range>).
      LOOP AT <range>-frange_t ASSIGNING FIELD-SYMBOL(<frange>).
        CASE <frange>-fieldname.
          WHEN 'WERKS'.
            APPEND LINES OF <frange>-selopt_t TO werks.
          WHEN 'MATNR'.
            APPEND LINES OF <frange>-selopt_t TO matnr.
          WHEN 'STLAN'.
            APPEND LINES OF <frange>-selopt_t TO stlan.
          WHEN 'STLAL'.
            APPEND LINES OF <frange>-selopt_t TO stlal.
          WHEN 'DATUV'.
            APPEND LINES OF <frange>-selopt_t TO datuv.
          WHEN 'DATUB'.
            APPEND LINES OF <frange>-selopt_t TO datub.
          WHEN OTHERS.
            " Unknown fields are logged to help trace dropped screen inputs
            IF runtime_parameter_ext-bal IS BOUND.
              runtime_parameter_ext-bal->add_msg(
                iv_msgty = if_drf_const=>msg_type_info
                iv_msgid = gc_msgid
                iv_msgno = '001'
                iv_msgv1 = <frange>-fieldname
                iv_msgv2 = 'enrich_filter_criteria ignored an unknown field' ).
            ENDIF.
        ENDCASE.
      ENDLOOP.
    ENDLOOP.

    " Retain the parsed STKO date ranges for read_complete_data (the only layer that queries STKO
    " and can enforce DATUV/DATUB screening). enrich_filter_criteria also routes them to the framework's
    " CP query under tablename='STKO', but STKO CP CDOBJID (stlty+stlnr) has no date fields, so they
    " would not take effect there. Empty range = match all -> read_complete_data skips the filter.
    mt_stko_datuv = datuv.
    mt_stko_datub = datub.

    " 2. Fill FS §4 mandatory defaults (WERKS=Q511, STLAN=1)
    " When the guard hits, append the default selection criteria in one shot via
    " a constructor expression, avoiding per-field assignment + CLEAR on selopt.
    IF lines( werks ) = 0.
      APPEND VALUE #( sign = 'I' option = 'EQ' low = gc_default_werks ) TO werks.
    ENDIF.
    IF lines( stlan ) = 0.
      APPEND VALUE #( sign = 'I' option = 'EQ' low = gc_default_stlan ) TO stlan.
    ENDIF.

    " 3. Rebuild et_add_external_criteria: MAST table (WERKS/MATNR/STLAN/STLAL)
    seltab-tablename = 'MAST'.
    IF lines( werks ) > 0.
      selfield-fieldname = 'WERKS'.
      APPEND LINES OF werks TO selfield-selopt_t.
      APPEND selfield TO seltab-frange_t.
      CLEAR selfield.
    ENDIF.
    IF lines( matnr ) > 0.
      selfield-fieldname = 'MATNR'.
      APPEND LINES OF matnr TO selfield-selopt_t.
      APPEND selfield TO seltab-frange_t.
      CLEAR selfield.
    ENDIF.
    IF lines( stlan ) > 0.
      selfield-fieldname = 'STLAN'.
      APPEND LINES OF stlan TO selfield-selopt_t.
      APPEND selfield TO seltab-frange_t.
      CLEAR selfield.
    ENDIF.
    IF lines( stlal ) > 0.
      selfield-fieldname = 'STLAL'.
      APPEND LINES OF stlal TO selfield-selopt_t.
      APPEND selfield TO seltab-frange_t.
      CLEAR selfield.
    ENDIF.
    IF lines( seltab-frange_t ) > 0.
      APPEND seltab TO et_add_external_criteria.
    ENDIF.
    CLEAR seltab.

    " 4. STKO table (validity date range).
    " DATUV = actual STKO field name (valid-from). DATUB is the FS §4 selection-parameter /
    " data-element name, but STKO has no DATUB field (the actual DDIC field for valid-to is
    " valid_to, whose data element is DATUB). The framework get_external_filter
    " (FREE_SELECTIONS_RANGE_2_WHERE) splices fieldname verbatim into WHERE without any
    " parameter->field mapping, so valid-to must use the real field name VALID_TO
    " (aligned with FS remark 2 / code comment L1064).
    seltab-tablename = 'STKO'.
    IF lines( datuv ) > 0.
      selfield-fieldname = 'DATUV'.
      APPEND LINES OF datuv TO selfield-selopt_t.
      APPEND selfield TO seltab-frange_t.
      CLEAR selfield.
    ENDIF.
    IF lines( datub ) > 0.
      selfield-fieldname = 'VALID_TO'.
      APPEND LINES OF datub TO selfield-selopt_t.
      APPEND selfield TO seltab-frange_t.
      CLEAR selfield.
    ENDIF.
    IF lines( seltab-frange_t ) > 0.
      APPEND seltab TO et_add_external_criteria.
    ENDIF.
    CLEAR seltab.
  ENDMETHOD.


  METHOD get_bom_filter.
    " Lazy-instantiate the BOM filter so read_complete_data can call apply_filter itself in
    " RUNMOD_BYPASS_FILTER (mirrors reference CL_P_DCB_DRF_PROCORD_OUT~get_procord_filter).
    IF mo_bom_filter IS NOT BOUND.
      mo_bom_filter = NEW zcl_mit_dcn_drf_bom_out_fltr( ).
    ENDIF.
    ro_bom_filter = mo_bom_filter.
  ENDMETHOD.


  METHOD get_aif_util.
    " Lazy-instantiate the AIF outbound tool: the business layer interacts with the AIF engine only
    " through this tool (mirrors zcl_aif_bom_out_service), never calling /AIF/SEND_WITH_PROXY directly.
    " Constructor arguments come from this class's AIF interface constants (FS correction 3:
    " ManufacturingProdnVersInfo_Out outbound service).
    IF mo_aif_util IS NOT BOUND.
      mo_aif_util = NEW zcl_aif_outbound_util(
        iv_ns           = gc_ns
        iv_ifname       = gc_ifname
        iv_ifversion    = gc_ifver
        iv_logical_port = gc_logical_port ).
    ENDIF.
    ro_aif_util = mo_aif_util.
  ENDMETHOD.


  METHOD read_complete_data.
    " Bulk read complete BOM data into the buffers.
    " Flow: clear buffers -> read MAST/STKO/STPO/MARA -> fill buffers

    DATA bom_number_set TYPE SORTED TABLE OF stnum WITH UNIQUE KEY table_line.  " Deduplicated STLNR set — join key for STKO/STPO/STAS (prevents row explosion)
    DATA material_set   TYPE SORTED TABLE OF matnr WITH UNIQUE KEY table_line.  " Deduplicated MATNR set (MARA lookup)

    CLEAR: mast_list, stko_list, stpo_list, stas_list, mara_list.

    " Filter gate: apply_filter always runs before the data read. In normal runmods the framework
    " already called it (ct_relevant_objects carries the filter's MAST-pre-fetched stlnr); in
    " RUNMOD_BYPASS_FILTER the framework skips it, so call apply_filter ourselves here - aligned
    " with reference CL_P_DCB_DRF_PROCORD_OUT~read_complete_data. With empty et_filtered_objects
    " CL_DRF_OUTBOUND would not invoke this implementation at all, so reaching here means the set
    " is non-empty and stlnr is guaranteed present afterwards.
    IF runtime_parameter_ext-runmod = if_drf_const=>runmod_bypass_filter.
      DATA(lt_filtered) = VALUE key_table_ty( ).
      get_bom_filter( )->apply_filter(
        EXPORTING
          iv_appl               = runtime_parameter_ext-appl
          iv_business_system    = runtime_parameter_ext-business_system
          iv_outb_impl          = runtime_parameter_ext-outb_impl
          iv_runmod             = runtime_parameter_ext-runmod
          io_bal                = runtime_parameter_ext-bal
          iv_dlmod              = runtime_parameter_ext-dlmod
          it_unfiltered_objects = ct_relevant_objects
          is_c_fobj             = VALUE #( )
          is_filt               = VALUE #( )
          it_external_criteria  = VALUE #( )
        IMPORTING
          et_filtered_objects   = lt_filtered ).
      ct_relevant_objects = lt_filtered.
    ENDIF.

    " stlnr is always present now (filter's MAST SELECT -> same-name mapped into the object key),
    " so build mast_list directly from the object key - no MAST re-query needed.
    " stlty/aennr may be empty (filter output struct lacks them); map_data2message handles that via
    " its stlnr-only STKO lookup. MAST itself has no AENNR/STLTY columns either.
    LOOP AT ct_relevant_objects INTO DATA(ls_bom_key).
      DATA(ls_mast) = CORRESPONDING mast( ls_bom_key ).
      APPEND ls_mast TO mast_list.
      INSERT ls_bom_key-stlnr INTO TABLE bom_number_set.
    ENDLOOP.

    IF mast_list IS NOT INITIAL.
      " The same STLNR in mast_list may be associated with multiple (matnr/werks/stlan/stlal) combinations,
      " a direct INNER JOIN @mast_list would multiply STKO/STPO rows, causing components to be sent twice / quantities doubled.
      " Use only the deduplicated STLNR set as the join key, keeping each component only once.
      " Note: the BOM number field STLNR has data element STNUM (verified against the sapdatasheet MAST table).

      " Read STKO (BOM header) - provides STLTY / AENNR / ANDAT / DATUV / BMENG / valid_to
      " Filter (aligned with the business SQL): only material BOMs (STLTY='M'), not deleted
      " (LKENZ<>'X'), active (STLST='01').
      " DATUV/VALID_TO screening: enforced HERE because no other layer can - the filter queries
      " MAST (no date columns), and the framework's CP query cannot match dates against STKO
      " CP CDOBJID (stlty+stlnr). Ranges come from enrich_filter_criteria via instance attrs
      " mt_stko_datuv / mt_stko_datub; empty range = match all (no screen input), so behavior is
      " unchanged when DATUV/DATUB are blank.
      " Open SQL forbids combining SELECT * with JOIN; use explicit column names + CORRESPONDING
      SELECT stko_alias~stlnr, stko_alias~stlty, stko_alias~aennr,
             stko_alias~andat, stko_alias~datuv, stko_alias~bmeng,
             stko_alias~valid_to
        FROM stko AS stko_alias
        INNER JOIN @bom_number_set AS bom_number
          ON stko_alias~stlnr = bom_number~table_line
        WHERE stko_alias~stlty = 'M'
          AND stko_alias~lkenz <> 'X'
          AND stko_alias~stlst = '01'
          AND stko_alias~datuv    IN @mt_stko_datuv
          AND stko_alias~valid_to IN @mt_stko_datub
        INTO CORRESPONDING FIELDS OF TABLE @stko_list.

      " Read STPO (BOM item) - provides IDNRK/MENGE/DATUV/valid_to/MEINS/AVOAU/AUSCH/AENNR
      " Includes STLKN: the component's owning node, used to converge components by alternative
      " BOM (STAS-STLAL) and prevent cross-alternative contamination.
      " Open SQL forbids combining SELECT * with JOIN; use explicit column names + CORRESPONDING
      " Filter (aligned with the business SQL): only material BOM components (STLTY='M'),
      " not deleted (LKENZ<>'X').
      SELECT stpo_alias~stlnr, stpo_alias~stlty, stpo_alias~stlkn,
             stpo_alias~idnrk, stpo_alias~menge, stpo_alias~datuv,
             stpo_alias~valid_to, stpo_alias~meins, stpo_alias~avoau,
             stpo_alias~ausch, stpo_alias~aennr
        FROM stpo AS stpo_alias
        INNER JOIN @bom_number_set AS bom_number
          ON stpo_alias~stlnr = bom_number~table_line
        WHERE stpo_alias~stlty = 'M'
          AND stpo_alias~lkenz <> 'X'
        INTO CORRESPONDING FIELDS OF TABLE @stpo_list.

      " Read STAS (BOM item selection) - provides alternative BOM (STLAL) -> STLKN node ownership.
      " When one STLNR has multiple alternatives (STLAL=1/2/3...), their components are distinguished
      " by the STLKN node; map_data2message uses this to converge components to the object key's
      " alternative, preventing cross-alternative contamination.
      " Note: STPO itself has no STLAL; the header<->item link must go through STAS to resolve STLKN.
      " Filter (aligned with the business SQL): only material BOM nodes (STLTY='M').
      SELECT stas_alias~stlty, stas_alias~stlnr,
             stas_alias~stlal, stas_alias~stlkn
        FROM stas AS stas_alias
        INNER JOIN @bom_number_set AS bom_number
          ON stas_alias~stlnr = bom_number~table_line
        WHERE stas_alias~stlty = 'M'
        INTO CORRESPONDING FIELDS OF TABLE @stas_list.
    ENDIF.

    " Read MARA (Header UoM - ID14, Component UoM - ID15)
    LOOP AT mast_list INTO DATA(mast_line).
      INSERT mast_line-matnr INTO TABLE material_set.
    ENDLOOP.

    material_set = VALUE #( FOR ls_tmp_mast IN mast_list
                            ( ls_tmp_mast-matnr ) ).

    LOOP AT stpo_list INTO DATA(stpo_line).
      INSERT stpo_line-idnrk INTO TABLE material_set.
    ENDLOOP.
    IF material_set IS NOT INITIAL.
      SELECT matnr, meins FROM mara
        INTO CORRESPONDING FIELDS OF TABLE @mara_list
        FOR ALL ENTRIES IN @material_set
        WHERE matnr = @material_set-table_line.
    ENDIF.

    " Note: ID09 changeNo is taken directly from STKO-AENNR (AENR primary key = AENNR, STKO references it,
    "       so they have the same value); no need to query AENR again to backfill aenr_list (the former
    "       redundant query has been removed, see map_bom_header).

  ENDMETHOD.


  METHOD map_data2message.
    " Maps BOM data to the ECMS message structure.
    " Field mapping (FS §7):
    " ID01 MATERIAL -> copExgNo (BOM header material, MAST-MATNR)
    " ID02 COMPONENT_MATNR -> copImgNo (component material, STPO-IDNRK)
    " ID03 QUANTITY -> decCm (component quantity, STPO-MENGE)
    " ID04 VALID_FROM -> startDate (component validity start, STPO-DATUV)
    " ID05 VALID_TO -> endDate (component validity end, STPO-valid_to)
    " ID06 BOM_CREATION -> bomCreation (BOM creation date, STKO-ANDAT)
    " ID07 ALTERNATIVE_BOM -> alternativeBom (alternative BOM, MAST-STLAL)
    " ID08 BOM_NO -> bomNo (BOM number, MAST-STLNR)
    " ID09 CHANGE_NO -> changeNo (engineering change number, AENR-AENNR)
    " ID10 BOM_USAGE -> useTo (BOM usage, MAST-STLAN)
    " ID11 HEADER_START_DATE -> bomStartDate (header validity start, STKO-DATUV)
    " ID12 HEADER_END_DATE -> bomEndDate (header validity end, STKO-valid_to)
    " ID13 HEADER_QTY -> copExgQty (header quantity, STKO-BMENG)
    " ID14 HEADER_UNIT -> copExgUnit (finished/semi-finished UoM, MARA-MEINS)
    " ID15 COMPONENT_UNIT -> copImgUnit (component UoM, STPO-MEINS)
    " ID16 OPERATION_SCRAP -> OperationScrap (operation scrap, STPO-AVOAU)
    " ID17 COMPONENT_SCRAP -> ComponentScrap (component scrap, STPO-AUSCH)
    " Note: FS §5 change matrix: component scrap=AUSCH (component scrap), operation scrap=AVOAU (operation scrap).
    "     In STPO, AUSCH (type KAUSF) is component scrap and AVOAU is operation scrap; they are independent columns.

    FIELD-SYMBOLS <bom_key> TYPE bom_key_ty.
    DATA bom_number TYPE stnum.
    DATA bom_type   TYPE stlty.
    DATA mara_line  TYPE mara.
    DATA stko_line  TYPE stko.
    DATA item       TYPE bom_item_ty.  " filled repeatedly in the loop; needs CLEAR each iteration
    DATA lt_stlkn_set TYPE SORTED TABLE OF stlkn WITH UNIQUE KEY table_line.  " STAS convergence: alternative -> STLKN node set

    CLEAR: bom_header, bom_items.

    IF ir_relevant_object IS NOT BOUND.
      RAISE EXCEPTION TYPE cx_drf_exception.
    ENDIF.

    " Read the object key fields with FIELD-SYMBOLS (REF TO data cannot access ->* members directly).
    ASSIGN ir_relevant_object->* TO <bom_key>.
    IF sy-subrc <> 0.
      RAISE EXCEPTION TYPE cx_drf_exception.
    ENDIF.

    READ TABLE mast_list WITH KEY stlan = <bom_key>-stlan
                                 werks = <bom_key>-werks
                                 matnr = <bom_key>-matnr
                                 stlal = <bom_key>-stlal
      INTO DATA(mast_line).
    IF sy-subrc <> 0.
      " Object key not found in MAST: write an object-level warning
      IF runtime_parameter_ext-bal IS BOUND.
        runtime_parameter_ext-bal->add_msg(
          iv_msgty = if_drf_const=>msg_type_warning
          iv_msgid = gc_msgid
          iv_msgno = '001'
          iv_msgv1 = <bom_key>-matnr
          iv_msgv2 = <bom_key>-werks ).
      ENDIF.
      RETURN.
    ENDIF.

    bom_number = mast_line-stlnr.

    " Get STKO (BOM header - ID06/09/11/12/13).
    " Two-level fallback chain (never assemble an empty header):
    "   ① Object key carries ECN (analyze path: STKO reverse-lookup populated stlty/aennr)
    "      -> match by stlnr + aennr (precise ECN version); fall back to stlnr + stlty;
    "   ② Object key lacks ECN/stlty (filter pre-fetch: MAST has no stlty/aennr columns,
    "      or analyze reverse-lookup found no STKO row) -> match by stlnr (unique BOM header);
    "   ③ No STKO row at all -> warning + RETURN (send_message's empty-payload check takes over).
    " stlnr (BOM number) uniquely identifies the BOM header; stlty is a header attribute, not an identifier.
    IF <bom_key>-stlty IS NOT INITIAL.
      READ TABLE stko_list WITH KEY stlnr = bom_number stlty = <bom_key>-stlty aennr = <bom_key>-aennr
        INTO stko_line.
      IF sy-subrc <> 0.
        " Fallback: STKO has no such ECN version -> take the first header of that STLNR/STLTY
        READ TABLE stko_list WITH KEY stlnr = bom_number stlty = <bom_key>-stlty
          INTO stko_line.
      ENDIF.
    ELSE.
      " Filter pre-fetch path (or analyze reverse-lookup miss): object key stlty/aennr empty,
      " match the unique BOM header by stlnr only.
      READ TABLE stko_list WITH KEY stlnr = bom_number
        INTO stko_line.
    ENDIF.
    IF sy-subrc <> 0.
      " When STKO has no record at all for that STLNR, write a warning to avoid assembling an empty header
      IF runtime_parameter_ext-bal IS BOUND.
        runtime_parameter_ext-bal->add_msg(
          iv_msgty = if_drf_const=>msg_type_warning
          iv_msgid = gc_msgid
          iv_msgno = '001'
          iv_msgv1 = |{ bom_number }|
          iv_msgv2 = |{ <bom_key>-stlty }| ).
      ENDIF.
      RETURN.
    ENDIF.

    " STPO items are filtered by the actual stlty of the matched STKO (object key stlty is empty
    " in the filter pre-fetch path and cannot be used for STPO filtering; take the actual stlty from the matched STKO).
    bom_type = stko_line-stlty.

    " Get MARA (Header UoM - ID14)
    READ TABLE mara_list WITH KEY matnr = mast_line-matnr INTO mara_line.

    " Map header (ID01, ID06-ID14)
    map_bom_header(
      EXPORTING
        is_stko = stko_line
        is_mast = mast_line
        is_mara = mara_line
      CHANGING
        cs_bom  = bom_header
    ).

    " Map items (ID02-ID05, ID15-ID17)
    " ID15 COMPONENT_UNIT is taken directly from STPO-MEINS (FS §7).
    " Alternative BOM (STLAL) -> STLKN node set: when one STLNR has multiple alternatives
    " (STLAL=1/2/3...), take only the components of this alternative's nodes (resolved via STAS),
    " preventing cross-alternative contamination; when there is no STAS data (single alternative /
    " historical data) lt_stlkn_set is empty and all components are kept as a fallback.
    LOOP AT stas_list INTO DATA(stas_line)
        WHERE stlnr = bom_number AND stlty = bom_type AND stlal = mast_line-stlal.
      INSERT stas_line-stlkn INTO TABLE lt_stlkn_set.
    ENDLOOP.

    LOOP AT stpo_list INTO DATA(stpo_line) WHERE stlnr = bom_number AND stlty = bom_type.
      IF lt_stlkn_set IS NOT INITIAL.
        READ TABLE lt_stlkn_set WITH KEY table_line = stpo_line-stlkn TRANSPORTING NO FIELDS.
        IF sy-subrc <> 0.
          CONTINUE.   " Component does not belong to this alternative's node -> skip (fix contamination)
        ENDIF.
      ENDIF.
      CLEAR item.
      map_bom_item(
        EXPORTING
          is_stpo = stpo_line
        CHANGING
          cs_item = item
      ).
      APPEND item TO bom_items.
    ENDLOOP.

    bom_message-header = bom_header.
    bom_message-items  = bom_items.

    " Assemble the AIF outbound message (standard structure ppint_mfg_prodn_vers_inf,
    " component landing points per map2xml.md; ID06/ID16 have no standard landing point,
    " retained in the local bom_message for MuleSoft-side mapping).
    CLEAR aif_bom_message.
    build_aif_message( EXPORTING is_bom_message = bom_message
      CHANGING cs_aif_message = aif_bom_message ).

  ENDMETHOD.


  METHOD send_message.
    " AIF send logic (FS §3).
    " Aligned with /RGS/CL_P_DCB_DRF_PRODVER_OUT~if_drf_outbound~send_message:
    " BOM is sent via the ManufacturingProdnVersInfo_Out outbound service
    " (gc_ns='YPMES', gc_ifname='YOMES_PV', gc_ifver='1', logical port='YMESPVOUT');
    " the object key is restored from ct_obj_rep_sta[1]-object_id (CONV bom_key_ty),
    " exceptions are caught as cx_bs_soa_exception / cx_ai_system_fault,
    " and success/failure both write object-level AIF logs (add_msg_xi / add_msg_re).
    " Keeps the FS §2.2 batched send: max 2000 lines per XML file; split into
    " batches of 2000 components when exceeded.

    " --- Method-local declarations (grouped at the top of the scope) ---
    " FS §10 five error-object elements + AIF log variables.
    " The AIF engine interaction (/AIF/SEND_WITH_PROXY) is delegated to zcl_aif_outbound_util,
    " so msgguid/error_string/error_long/return_send are no longer declared here - the tool encapsulates them.
    DATA: errmsg            TYPE drf_s_message,
          error_return      TYPE REF TO bapiret2,
          idnrk             TYPE idnrk,
          msgguid_out       TYPE  sxmsmguid,
          lv_sent_ok        TYPE abap_bool,
          lv_dummy          TYPE char20,
          bom_key           TYPE bom_key_ty,
          bom_key_ref       TYPE REF TO bom_key_ty,
          wsprotocol_msg_id TYPE REF TO if_wsprotocol_message_id.

    IF lines( bom_items ) > 0.
      idnrk = bom_items[ 1 ]-cop_img_no.
    ENDIF.

    IF bom_message-header IS INITIAL AND bom_message-items IS INITIAL.
      RETURN.
    ENDIF.

    " Build BOM object key (aligned with reference: ct_obj_rep_sta[1]-object_id -> CONV key
    " -> GET REFERENCE, used for add_msg_xi ir_object; falls back to the message
    " header fields when the object key is not available).
    READ TABLE ct_obj_rep_sta INTO DATA(ls_obj_rep_sta) INDEX 1.
    IF sy-subrc = 0.
      bom_key = CONV bom_key_ty( ls_obj_rep_sta-object_id ).
      GET REFERENCE OF bom_key INTO bom_key_ref.
    ELSE.
      " ct_obj_rep_sta empty (should not happen; defensive fallback): rebuild the object
      " key from the message header fields
      bom_key-matnr = bom_message-header-cop_exg_no.
      bom_key-werks = gc_default_werks.
      bom_key-stlal = bom_message-header-alternative_bom.
      bom_key-aennr = bom_message-header-change_no.
      GET REFERENCE OF bom_key INTO bom_key_ref.
    ENDIF.

    " Before sending, check mandatory fields are not empty (FS §7 M flag).
    "   Header-level M fields: ID01 copExgNo, ID13 headerQty
    "   Item-level M fields: ID02 copImgNo, ID03 quantity, ID16 operationScrap, ID17 componentScrap
    "   If the header is empty or a header mandatory field is missing, mark E and return to avoid sending an empty message to ECMS.
    IF bom_message-header IS INITIAL
       OR bom_message-header-cop_exg_no IS INITIAL
       OR bom_message-header-header_qty IS INITIAL.
      LOOP AT ct_obj_rep_sta ASSIGNING FIELD-SYMBOL(<rep_status_init>).
        <rep_status_init>-repstatus = 'SE'.
      ENDLOOP.
      " FS §10: five error-object elements -> AIF error context (drf_s_message-message -> bapiret2)
      CREATE DATA error_return.
      error_return->type       = 'E'.
      error_return->id         = gc_msgid.
      error_return->number     = '001'.
      error_return->message_v1 = bom_header-cop_exg_no.   " Parent Material (MATNR)
      error_return->message_v2 = gc_default_werks.            " Plant (WERKS, fixed per FS §10)
      error_return->message_v3 = idnrk.                   " Component Item (IDNRK)
      error_return->message_v4 = bom_header-change_no.    " ECN (AENNR)
      errmsg-bo_type       = 'BILL_OF_MATERIAL'.        " Production BOM main object
      errmsg-bo_key        = bom_header-cop_exg_no.  " Object ID (MATNR)
      errmsg-target_system = gc_logical_port.           " ECMS target system
      errmsg-message       = error_return.
      APPEND errmsg TO et_message.
      CLEAR: errmsg, error_return.
      " Object-level AIF error log (FS §10/§11 five-element context)
      IF runtime_parameter_ext-bal IS BOUND.
        runtime_parameter_ext-bal->add_msg(
          iv_msgty = if_drf_const=>msg_type_error
          iv_msgid = gc_msgid
          iv_msgno = '001'
          iv_msgv1 = bom_header-cop_exg_no
          iv_msgv2 = gc_default_werks
          iv_msgv3 = idnrk
          iv_msgv4 = bom_header-change_no ).
      ENDIF.
      CLEAR: bom_message, bom_header, bom_items.
      RETURN.
    ENDIF.
    " Item-level mandatory field check: only check item by item when items is not empty, to avoid wrongly rejecting a "header-only BOM"
    LOOP AT bom_message-items ASSIGNING FIELD-SYMBOL(<item_chk>).
      IF <item_chk>-cop_img_no IS INITIAL
         OR <item_chk>-quantity IS INITIAL
         OR <item_chk>-operation_scrap < 0
         OR <item_chk>-component_scrap < 0.
        LOOP AT ct_obj_rep_sta ASSIGNING FIELD-SYMBOL(<rep_status_miss>).
          <rep_status_miss>-repstatus = 'SE'.
        ENDLOOP.
        " FS §10: five error-object elements -> AIF error context (drf_s_message-message -> bapiret2)
        CREATE DATA error_return.
        error_return->type       = 'E'.
        error_return->id         = gc_msgid.
        error_return->number     = '001'.
        error_return->message_v1 = bom_header-cop_exg_no.   " Parent Material (MATNR)
        error_return->message_v2 = gc_default_werks.            " Plant (WERKS, fixed per FS §10)
        error_return->message_v3 = <item_chk>-cop_img_no.   " Component Item (IDNRK)
        error_return->message_v4 = bom_header-change_no.    " ECN (AENNR)
        errmsg-bo_type       = 'BILL_OF_MATERIAL'.        " Production BOM main object
        errmsg-bo_key        = bom_header-cop_exg_no.  " Object ID (MATNR)
        errmsg-target_system = gc_logical_port.           " ECMS target system
        errmsg-message       = error_return.
        APPEND errmsg TO et_message.
        CLEAR: errmsg, error_return.
        " Object-level AIF error log (FS §10/§11 five-element context)
        IF runtime_parameter_ext-bal IS BOUND.
          runtime_parameter_ext-bal->add_msg(
            iv_msgty = if_drf_const=>msg_type_error
            iv_msgid = gc_msgid
            iv_msgno = '001'
            iv_msgv1 = bom_header-cop_exg_no
            iv_msgv2 = gc_default_werks
            iv_msgv3 = <item_chk>-cop_img_no
            iv_msgv4 = bom_header-change_no ).
        ENDIF.
        CLEAR: bom_message, bom_header, bom_items.
        RETURN.
      ENDIF.
    ENDLOOP.

    " Single AIF send: the whole BOM message is sent as one ppint_mfg_prodn_vers_inf structure
    " via /AIF/SEND_WITH_PROXY, aligned with the reference /RGS/CL_P_DCB_DRF_PRODVER_OUT~send_message
    " (which sends a single production-version message and does not split into 2000-row batches).
    "   - no explicit /AIF/CREATE_APPL_LOG (the DRF framework manages the application log via bal);
    "   - the AIF engine call is delegated to zcl_aif_outbound_util~send_with_proxy (which calls
    "     /AIF/SEND_WITH_PROXY internally), passing the standard AIF message aif_bom_message as sap_struct;
    "   - exceptions caught as cx_bs_soa_exception / cx_ai_system_fault,
    "     on failure the object repstatus is set to 'SE' and the AIF error log is written via add_msg_re.

    TRY.
      " Delegate the send to the generic AIF outbound tool (FS §3): BOM is sent via the
      " ManufacturingProdnVersInfo_Out outbound service.
      " zcl_aif_outbound_util~send_with_proxy wraps /AIF/SEND_WITH_PROXY:
      "   - tolerates PERSISTENCY_ERROR(=1);
      "   - internally checks add_return_tab for E/A business errors;
      "   - fills mv_msgguid / mv_msgguid_out / mv_error_string / mv_error_long.
      " The business class no longer calls the FM directly (mirrors zcl_aif_bom_out_service).
      DATA(lo_aif_util) = get_aif_util( ).
      lv_sent_ok = lo_aif_util->send_with_proxy(
        iv_persist_xml = abap_true
        CHANGING
          cs_message = aif_bom_message ).
      msgguid_out = lo_aif_util->get_msgguid_out( ).

      IF lo_aif_util->is_hard_error( ).
        " Hard error (raw FM sy-subrc not 0/1): get_error_string( ) / get_error_long( ) carry the
        " specific failure reason (proxy class not found, structure mismatch, logical port, etc.).
        IF runtime_parameter_ext-bal IS BOUND.
          runtime_parameter_ext-bal->add_msg(
            iv_msgty = if_drf_const=>msg_type_error
            iv_msgid = gc_msgid
            iv_msgno = '001'
            iv_msgv1 = 'AIF send failed'
            iv_msgv2 = lo_aif_util->get_error_string( )
            iv_msgv3 = lo_aif_util->get_error_long( ) ).
        ENDIF.
      ELSE.
        " sy-subrc = 0 or 1 (PERSISTENCY_ERROR tolerated): success or business error —
        " the util already folded an E/A return-table error into the return value / is_success( ).
        " Object-level AIF log: associate GUID + payload (aligned to reference lines 3092-3100)
        " BOM is sent via /AIF/SEND_WITH_PROXY with no SOAP proxy -> pass an empty reference
        " for io_message_id_protocol; ir_object carries the BOM object key;
        " is_message_out carries the payload, kept consistent with the sap_struct passed to /AIF/SEND_WITH_PROXY.
        IF runtime_parameter_ext-bal IS BOUND.
          runtime_parameter_ext-bal->add_msg_xi(
            iv_xi_msg_guid         = msgguid_out
            iv_object_count        = iv_object_count
            io_message_id_protocol = wsprotocol_msg_id
            iv_outb_impl           = runtime_parameter_ext-outb_impl
            ir_object              = bom_key_ref
            is_message_out         = aif_bom_message ).
        ENDIF.
      ENDIF.
    " Data replication failure: mark the object 'SE' and write the AIF error log (aligned with the
    " reference exception-handling block)
    CATCH cx_bs_soa_exception INTO DATA(soa_exception).
      LOOP AT ct_obj_rep_sta ASSIGNING FIELD-SYMBOL(<rep_status_soa>).
        <rep_status_soa>-repstatus = 'SE'.
      ENDLOOP.
      UNASSIGN: <rep_status_soa>.
      DATA(soa_text) = soa_exception->get_text( ).
      DATA(soa_long_text) = soa_exception->get_longtext( ).
      MESSAGE s015(drf_outbound) WITH gc_aif_service soa_text soa_long_text INTO lv_dummy ##needed.
      IF runtime_parameter_ext-bal IS BOUND.
        runtime_parameter_ext-bal->add_msg_re(
          iv_msgno             = sy-msgno
          iv_msgid             = sy-msgid
          iv_msgv1             = gc_aif_service
          iv_msgv2             = soa_text
          ix_exception_catched = soa_exception ).
      ENDIF.
    CATCH cx_ai_system_fault INTO DATA(system_fault).
      LOOP AT ct_obj_rep_sta ASSIGNING FIELD-SYMBOL(<rep_status_fault>).
        <rep_status_fault>-repstatus = 'SE'.
      ENDLOOP.
      UNASSIGN: <rep_status_fault>.
      DATA(fault_text) = system_fault->get_text( ).
      DATA(fault_long_text) = system_fault->get_longtext( ).
      MESSAGE s015(drf_outbound) WITH gc_aif_service fault_text fault_long_text INTO lv_dummy ##needed.
      IF runtime_parameter_ext-bal IS BOUND.
        runtime_parameter_ext-bal->add_msg_re(
          iv_msgno             = sy-msgno
          iv_msgid             = sy-msgid
          iv_msgv1             = gc_aif_service
          iv_msgv2             = fault_text
          ix_exception_catched = system_fault ).
      ENDIF.
    ENDTRY.

    " Return handling block aggregated across all batches (aligned with the reference: the exception
    " path already set 'SE', so here we only finalize the status when sending completed).
    " Semantics: when all batches succeeded (lv_sent_ok) and no exception was raised, mark the object
    " 'SN' (Sent/No error); a failed batch or an exception already marked it 'SE'.
    IF lv_sent_ok = abap_true.
      LOOP AT ct_obj_rep_sta ASSIGNING FIELD-SYMBOL(<rep_status_ok>).
        <rep_status_ok>-repstatus = 'SN'.
      ENDLOOP.
      " Object-level AIF success log (FS §11 monitoring)
      IF runtime_parameter_ext-bal IS BOUND.
        runtime_parameter_ext-bal->add_msg(
          iv_msgty = if_drf_const=>msg_type_success
          iv_msgid = gc_msgid
          iv_msgno = '001'
          iv_msgv1 = bom_header-cop_exg_no ).
      ENDIF.
    ELSE.
      " Send failed (hard error or business error) — mark all objects as 'SE' (sent with error)
      LOOP AT ct_obj_rep_sta ASSIGNING FIELD-SYMBOL(<rep_status_err>).
        <rep_status_err>-repstatus = 'SE'.
      ENDLOOP.
    ENDIF.

    CLEAR: bom_message, bom_header, bom_items.
  ENDMETHOD.


  METHOD finalize.
    " FS §10: delete the change pointer only when there are no erroneous objects; otherwise keep it for re-execution.
    " Distinguish the Initial Run re-run scenario - under repeated initial loads the framework does not generate CPs anyway,
    "           so it should not be deleted here (to avoid conflicting with residual erroneous objects); also keep the reference to relevant
    "           for later extension (e.g. counting the final success count).
    IF it_erroneous_objects IS INITIAL
       AND iv_repeated_initial_run = abap_false.
      ev_delete_change_pointer = abap_true.
    ELSE.
      ev_delete_change_pointer = abap_false.
    ENDIF.

    " it_relevant_objects is used to count the final success count and write a log
    DATA(success_cnt) = lines( it_relevant_objects ) - lines( it_erroneous_objects ).
    IF runtime_parameter_ext-bal IS BOUND.
      runtime_parameter_ext-bal->add_msg(
        iv_msgty = if_drf_const=>msg_type_info
        iv_msgid = gc_msgid
        iv_msgno = '001'
        iv_msgv1 = |{ success_cnt }|
        iv_msgv2 = |{ lines( it_erroneous_objects ) }| ).
    ENDIF.
  ENDMETHOD.


  METHOD is_ecn_valid.
    " ECN status check: filters out unreleased/blocked ECNs (FS §6.2).
    " Checks against the pre-loaded AENR status table (it_aenr_status, the caller has already
    " SELECTed aennr/aenst in bulk), replacing the per-object SELECT SINGLE (eliminates the N+1
    " query in change analysis).
    " Note: FS note 4 mentioned "MAENR.AENST_M plant dimension" - verified that MAENR there is a typo for AENR
    "     (sapdatasheet: AENR primary key = MANDT+AENNR unique, status field = AENST, no plant-dimension field,
    "      and no AENNR_AUF either). So the correct and complete ECN check is AENR.AENST='2' (FS §6.2),
    "      the current implementation is correct and needs no additional plant-dimension extension.

    rv_valid = abap_false.

    IF iv_aennr IS INITIAL.
      RETURN.
    ENDIF.

    READ TABLE it_aenr_status WITH KEY aennr = iv_aennr INTO DATA(status_line).
    IF sy-subrc <> 0.
      " AENR has no record: ECN does not exist, judged invalid
      rv_valid = abap_false.
      RETURN.
    ENDIF.

    IF status_line-aenst IS INITIAL.
      " AENST empty/'00': ECN has not been explicitly assigned a status, treated as unreleased
      rv_valid = abap_false.
    ELSE.
      IF status_line-aenst = gc_ecn_status_released.
        rv_valid = abap_true.
      ELSE.
        rv_valid = abap_false.
      ENDIF.
    ENDIF.
  ENDMETHOD.


  METHOD map_bom_header.
    " Maps BOM header fields.
    " ID01: MATERIAL -> copExgNo (MAST-MATNR)
    " ID06: BOM_CREATION -> bomCreation (STKO-ANDAT)
    " ID07: ALTERNATIVE_BOM -> alternativeBom (MAST-STLAL)
    " ID08: BOM_NO -> bomNo (MAST-STLNR)
    " ID09: CHANGE_NO -> changeNo (AENR-AENNR; fall back to STKO-AENNR if AENR has no record)
    " ID10: BOM_USAGE -> useTo (MAST-STLAN)
    " ID11: HEADER_START_DATE -> bomStartDate (STKO-DATUV)
    " ID12: HEADER_END_DATE -> bomEndDate (STKO-valid_to)
    " ID13: HEADER_QTY -> copExgQty (STKO-BMENG)
    " ID14: HEADER_UNIT -> copExgUnit (MARA-MEINS)

    cs_bom-cop_exg_no      = is_mast-matnr.
    cs_bom-bom_creation    = is_stko-andat.
    cs_bom-alternative_bom = is_mast-stlal.
    cs_bom-bom_no          = is_mast-stlnr.
    cs_bom-change_no       = is_stko-aennr.
    cs_bom-bom_usage       = is_mast-stlan.
    " Future effective date (FS §6.3) - if the ECN's DATUV > SY-DATUM, explicitly pass DATUV
    " for ECMS local scheduling switch. Here is_stko-datuv is passed through directly as header_start_date,
    " if greater than sy-datum it implicitly implements the "future effective" flag with no extra field.
    cs_bom-header_start_date = is_stko-datuv.
    " STKO has no DATUB field; the actual validity end date field is valid_to, whose type is DATUB.
    cs_bom-header_end_date   = is_stko-valid_to.
    cs_bom-header_qty        = is_stko-bmeng.
    cs_bom-header_unit       = is_mara-meins.

  ENDMETHOD.


  METHOD map_bom_item.
    " Maps BOM item fields.
    " ID02: COMPONENT_MATNR -> copImgNo (STPO-IDNRK)
    " ID03: QUANTITY -> decCm (STPO-MENGE)
    " ID04: VALID_FROM -> startDate (STPO-DATUV)
    " ID05: VALID_TO -> endDate (STPO-valid_to)
    " ID15: COMPONENT_UNIT -> copImgUnit (STPO-MEINS)
    " ID16: OPERATION_SCRAP -> OperationScrap (STPO-AVOAU, operation scrap)
    " ID17: COMPONENT_SCRAP -> ComponentScrap (STPO-AUSCH, component scrap)
    " Note: FS §5 change matrix: component scrap=AUSCH (component scrap), operation scrap=AVOAU (operation scrap).
    "     In STPO, AUSCH (type KAUSF) is component scrap and AVOAU is operation scrap; they are independent columns.

    cs_item-cop_img_no      = is_stpo-idnrk.
    cs_item-quantity        = is_stpo-menge.
    cs_item-valid_from      = is_stpo-datuv.
    " STPO has no DATUB field; the actual validity end date field is valid_to, whose type is DATUB.
    cs_item-valid_to        = is_stpo-valid_to.
    cs_item-component_unit  = is_stpo-meins.
    cs_item-operation_scrap = is_stpo-avoau.
    cs_item-component_scrap = is_stpo-ausch.

  ENDMETHOD.


  METHOD build_aif_message.
    " Assemble the local BOM message (bom_message_ty, 17-field SAP source values) into the
    " AIF outbound message (standard structure ppint_mfg_prodn_vers_inf). Component landing
    " points are aligned with map2xml.md and the reference implementation
    " /RGS/CL_P_DCB_DRF_PRODVER_OUT~map_data2message:
    "
    "   ID01 copExgNo   -> production_version_information-material
    "   ID07 alternativeBom -> production_version_information-bill_of_material_variant
    "   ID10 useTo      -> production_version_information-bill_of_material_variant_usage
    "   ID08 bomNo      -> bill_of_material
    "   ID09 changeNo   -> bom_header_ecn
    "   ID11/ID12      -> bom_extra_data[]-bom_validity_start/end_date
    "   ID13 copExgQty  -> quantity_in_base_unit
    "   ID14 copExgUnit -> base_unit
    "   ID02-ID05/ID15/ID17 (components) -> bill_of_operations_activity_ne-bill_of_operations_activity_co
    "   ID06/ID16       -> no standard XML landing point, retained in the local bom_message, mapped on the MuleSoft side
    "
    " Note: the BOM outbound scenario does not involve production versions / process recipes
    " (the bill_of_operations network is empty); component details are attached directly to
    " bill_of_operations_activity_ne-bill_of_operations_activity_co, mirroring the reference
    " class's component allocation path (data source is STPO rather than PLMZ).

    DATA ls_pv_line   TYPE ppint_prodn_vers_information.
    DATA ls_compalloc TYPE ppint_boo_acty_comp_alloc.

    CLEAR cs_aif_message.

    " Business header (message-level id / creation_date_time / sender-recipient systems)
    cs_aif_message-manufacturing_prodn_vers_info-message_header = build_business_header( ).

    " Version information row: ID01/ID07/ID10 (the ProductionVersionInformation section of map2xml.md)
    " material is the BOM header material (ID01); bill_of_material_variant / usage are the
    " alternative BOM and BOM usage.
    ls_pv_line-material = is_bom_message-header-cop_exg_no.
    " plant / production_version: BOM outbound has no production version, so plant takes the
    " default plant; the remaining PV-specific fields (bill_of_operations_group etc.) stay empty -
    " this service carries the BOM header as its primary payload.
    ls_pv_line-plant = gc_default_werks.
    ls_pv_line-bill_of_material_variant = is_bom_message-header-alternative_bom.   " ID07
    ls_pv_line-bill_of_material_variant_usage = is_bom_message-header-bom_usage.   " ID10
    APPEND ls_pv_line TO cs_aif_message-manufacturing_prodn_vers_info-production_version_information.

    " BOM header root-level components (the n1:* section of map2xml.md)
    cs_aif_message-manufacturing_prodn_vers_info-bill_of_material = is_bom_message-header-bom_no.               " ID08
    cs_aif_message-manufacturing_prodn_vers_info-bom_category     = 'M'.                                        " material BOM category (FS §7 filters STLTY='M')
    cs_aif_message-manufacturing_prodn_vers_info-quantity_in_base_unit = is_bom_message-header-header_qty.        " ID13
    cs_aif_message-manufacturing_prodn_vers_info-base_unit      = is_bom_message-header-header_unit.             " ID14
    cs_aif_message-manufacturing_prodn_vers_info-bom_header_ecn = is_bom_message-header-change_no.               " ID09

    " BOM header validity period (ID11/ID12) -> bom_extra_data (aligned with the reference's
    " /rgs/p_dcb_pv_rgs_p_dcb_pv_bom row)
    DATA(ls_bom_extra) = VALUE /rgs/p_dcb_pv_rgs_p_dcb_pv_bom(
      bom_header_ecn          = is_bom_message-header-change_no
      bom_validity_start_date = |{ is_bom_message-header-header_start_date DATE = ISO }|
      bom_validity_end_date   = |{ is_bom_message-header-header_end_date   DATE = ISO }|
      quantity_in_base_unit   = is_bom_message-header-header_qty
      bom_header_base_unit    = is_bom_message-header-header_unit ).
    APPEND ls_bom_extra TO cs_aif_message-manufacturing_prodn_vers_info-bom_extra_data.

    " Component details (ID02-ID05/ID15/ID17) -> bill_of_operations_activity_ne-bill_of_operations_activity_co
    " Aligned with the reference: component allocation is attached to the process network element
    " (in the BOM scenario there are no processes, so a single carrier node is used).
    " Aligned with the reference: component allocation is attached to the process network element
    " (in the BOM scenario there are no processes, so a single carrier node is used).
    " Reference L4080: build the component allocation table lt_compalloc first, then assign it
    " to the network element row's bill_of_operations_activity_co, and finally APPEND the
    " network element row to the outer table.
    " (Cannot use bill_of_operations_activity_ne[ 1 ]-... inline index as an APPEND target)
    DATA ls_acty_ne TYPE ppint_mfg_boo_acty_ntwk_elmnts.
    DATA lt_compalloc TYPE STANDARD TABLE OF ppint_boo_acty_comp_alloc.
    CLEAR: ls_acty_ne, lt_compalloc.

    LOOP AT is_bom_message-items ASSIGNING FIELD-SYMBOL(<bom_item>).
      CLEAR ls_compalloc.
      ls_compalloc-bill_of_material_category   = 'M'.
      ls_compalloc-bill_of_material            = is_bom_message-header-bom_no.
      ls_compalloc-bill_of_material_component  = <bom_item>-cop_img_no.             " ID02
      ls_compalloc-bill_of_material_item_quantity-content = <bom_item>-quantity.     " ID03
      ls_compalloc-bill_of_material_item_quantity-unit_code = <bom_item>-component_unit. " ID15
      ls_compalloc-validity_start_date         = <bom_item>-valid_from.            " ID04
      ls_compalloc-validity_end_date           = <bom_item>-valid_to.               " ID05
      " ID17 component scrap (STPO-AUSCH) -> component_scrap_in_percent (map2xml.md n1:ComponentScrapInPercent)
      ls_compalloc-component_scrap_in_percent  = <bom_item>-component_scrap.
      APPEND ls_compalloc TO lt_compalloc.
      " ID16 operation scrap (STPO-AVOAU): no standard XML landing point (map2xml.md §3.3),
      " retained in the local bom_message-items for MuleSoft-side mapping.
    ENDLOOP.

    " Assign the component allocation table to the network element row, then APPEND to the outer table
    ls_acty_ne-bill_of_operations_activity_co = lt_compalloc.
    APPEND ls_acty_ne TO cs_aif_message-manufacturing_prodn_vers_info-bill_of_operations_activity_ne.

  ENDMETHOD.


  METHOD build_business_header.
    " Build the AIF business header (PPINT_BUSDOC_MSG_HDR), aligned with the reference
    " /RGS/CL_P_DCB_DRF_PRODVER_OUT~get_business_header:
    "   - id-content / uuid-content: UUID C32
    "   - creation_date_time: system time converted to UTC (reference WI#3200016485 timezone conversion)
    "   - sender / recipient business system id
    DATA: lv_guid_32   TYPE guid_32,
          lv_timestamp TYPE timestamp,
          lv_date      LIKE sy-datum,
          lv_time      LIKE sy-uzeit.

    TRY.
        lv_guid_32 = cl_system_uuid=>create_uuid_c32_static( ).
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
    DATA(rc_lcr) = sy-subrc ##needed.

    rs_header-recipient_business_system_id = runtime_parameter_ext-business_system.

  ENDMETHOD.

ENDCLASS.
