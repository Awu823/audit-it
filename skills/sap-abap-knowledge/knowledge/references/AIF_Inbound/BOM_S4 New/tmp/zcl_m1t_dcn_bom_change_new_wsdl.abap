*"! <p class="shorttext synchronized">DRF BOM Outbound: Business Singleton — ZBOM WSDL adapted</p>
*"!
*"! Based on 命名规范改造/zcl_m1t_dcn_bom_change_en.abap, adapted for the custom
*"! ZBOM_REPLICATE_REQ_ASYNC_OUT service (BOM-centric WSDL).
*"!
*"! Key changes from the source file:
*"!   1. AIF constants → ZBOM namespace (ZBOM / ZO_BOM_REPL / ZBOMOUT)
*"!   2. AIF message structure → ZBOM WSDL types (BOM-centric, no PV nesting)
*"!   3. send_message rewritten: single message, no /AIF/CREATE_APPL_LOG,
*"!      TRY/CATCH cx_bs_soa_exception / cx_ai_system_fault, lv_sent_ok
*"!   4. New methods: build_aif_message, build_business_header
*"!   5. All 17 FS fields mapped (ID01-ID17) including ID06 (BOMCreationDate)
*"!      and ID16 (OperationScrapInPercent) — new in ZBOM WSDL, absent in PV structure.
*"!
*"! ZBOM message types use generated DDIC proxy structures (package $TMP):
*"!   zzbomreplicate_request  — root sap_struct (AIF /aif/cust), wraps `parameters`
*"!   zbomreplicate_request   — inner proxy structure (message_header + bom)
*"!   zbomtype / zbomheader_type / zbomcomponent_type[_tab]
*"!   zbusiness_document_message_hea / zquantity / etc.
CLASS zcl_m1t_dcn_bom_out_impl DEFINITION
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

*" --- AIF interface parameters (ZBOM custom service) ---
*"   Service: ZBOMReplicateReq_Async_Out (custom BOM-centric WSDL)
*"   AIF namespace/interface/logical port to be configured after proxy generation.
    CONSTANTS gc_ns            TYPE /aif/ns        VALUE 'ZDEMO'      ##NO_TEXT.
    CONSTANTS gc_ifname        TYPE /aif/ifname    VALUE 'ZDEMOIF' ##NO_TEXT.
    CONSTANTS gc_ifver         TYPE /aif/ifversion VALUE '1'          ##NO_TEXT.
    CONSTANTS gc_logical_port  TYPE prx_logical_port_name VALUE 'ZBOMOUT' ##NO_TEXT.
    CONSTANTS gc_aif_service   TYPE string         VALUE 'ZBOMReplicateReq_Async_Out' ##NO_TEXT.
    CONSTANTS gc_msgid         TYPE symsgid        VALUE 'ZDCN_PBOM'  ##NO_TEXT.

*" --- BOM change-pointer related constants ---
    CONSTANTS gc_cp_tabname_mast TYPE cdtabkey   VALUE 'MAST'  ##NO_TEXT.
    CONSTANTS gc_cp_tabname_stko TYPE cdtabkey   VALUE 'STKO'  ##NO_TEXT.
    CONSTANTS gc_cp_tabname_stpo TYPE cdtabkey   VALUE 'STPO'  ##NO_TEXT.

*" --- ECN status constants ---
    CONSTANTS gc_ecn_status_released TYPE aenst VALUE '2' ##NO_TEXT.

*" --- Default filter condition constants (FS §4) ---
    CONSTANTS gc_default_werks TYPE werks_d VALUE 'Q511' ##NO_TEXT.
    CONSTANTS gc_default_stlan TYPE stlan   VALUE '1'   ##NO_TEXT.

*" --- CDOBJID field length constants ---
    CONSTANTS gc_len_matnr TYPE i VALUE 18 ##NO_TEXT.
    CONSTANTS gc_len_werks TYPE i VALUE 4  ##NO_TEXT.
    CONSTANTS gc_len_stlan TYPE i VALUE 1  ##NO_TEXT.
    CONSTANTS gc_len_stlal TYPE i VALUE 2  ##NO_TEXT.
    CONSTANTS gc_len_stlnr TYPE i VALUE 8  ##NO_TEXT.

*" --- Volume control constants (FS §14) ---
    CONSTANTS gc_initial_max_rows TYPE i VALUE 1000 ##NO_TEXT.
    CONSTANTS gc_initial_min_rows TYPE i VALUE 300  ##NO_TEXT.

    " --- Local BOM buffer types (SAP source values, FS §7 17 fields) ---
    "   Intermediate assembly in map_data2message; build_aif_message maps these to ZBOM WSDL structure.
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
      BEGIN OF ecn_status_ty,
        aennr TYPE aennr,
        aenst TYPE c LENGTH 1,
      END OF ecn_status_ty,
      ecn_status TYPE SORTED TABLE OF ecn_status_ty WITH UNIQUE KEY aennr,
      ecn_key    TYPE SORTED TABLE OF aennr WITH UNIQUE KEY table_line.

*" --- ZBOM AIF message type ---
*"   Uses generated DDIC proxy structure zzbomreplicate_request (the sap_struct
*"   registered in /aif/cust for the ZBOMReplicateReq_Async_Out interface).
*"
*"   DDIC structure layout (proxy-generated, package $TMP):
*"     zzbomreplicate_request            (root = sap_struct)
*"       ├─ controller   prxctrltab
*"       └─ parameters   zbomreplicate_request        (inner proxy structure)
*"          ├─ controller       prxctrltab
*"          ├─ message_header   zbusiness_document_message_hea
*"          │   ├─ id / uuid / creation_date_time(zglobal_date_time, dec21,7)
*"          │   └─ sender_business_system_id / recipient_business_system_id
*"          └─ bom              zbomtype
*"             ├─ bomheader     zbomheader_type         — ID01, ID06-ID14
*"             └─ bomcomponent  zbomcomponent_type_tab  — ID02-ID05, ID15-ID17

*" --- Data buffers ---
    DATA mast_list    TYPE STANDARD TABLE OF mast.
    DATA stko_list    TYPE STANDARD TABLE OF stko.
    DATA stpo_list    TYPE STANDARD TABLE OF stpo.
    DATA stas_list    TYPE STANDARD TABLE OF stas.
    DATA mara_list    TYPE STANDARD TABLE OF mara.
    DATA bom_header   TYPE bom_header_ty.
    DATA bom_items    TYPE bom_items_ty.
    DATA bom_message  TYPE bom_message_ty.
    " ZBOM AIF outbound message (populated by build_aif_message, sent by send_message)
    " sap_struct for /AIF/SEND_WITH_PROXY — DDIC proxy type zzbomreplicate_request (/aif/cust)
    DATA aif_message  TYPE zzbomreplicate_request.

    DATA mt_stko_datuv TYPE rsds_selopt_t.
    DATA mt_stko_datub TYPE rsds_selopt_t.
    DATA mo_bom_filter TYPE REF TO if_drf_filter.

*" --- Method declarations ---
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
      CHANGING  cs_aif_message TYPE zzbomreplicate_request.

    METHODS build_business_header
      RETURNING VALUE(rs_header) TYPE zbusiness_document_message_hea.

*" Populate PRXCTRLTAB controller flags at every proxy-structure level so the
*" proxy runtime serializes the populated fields (otherwise XML body is empty).
    METHODS fill_proxy_controllers
      CHANGING
        cs_msg TYPE zzbomreplicate_request.

*" Convert CET local date/time → UTC (aligned with reference convert_timestamp)
    METHODS convert_timestamp
      CHANGING
        c_date TYPE datum
        c_time TYPE uzeit.

ENDCLASS.


CLASS zcl_m1t_dcn_bom_out_impl IMPLEMENTATION.

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
    DATA stko_stpo_range        TYPE RANGE OF stnum.
    DATA mast_all               TYPE STANDARD TABLE OF mast WITH EMPTY KEY.
    DATA stko_stpo_mast         TYPE STANDARD TABLE OF mast WITH EMPTY KEY.
    DATA stko_aennr_lookup      TYPE STANDARD TABLE OF stko WITH EMPTY KEY.
    DATA ecn_filtered_cnt       TYPE i.

    TYPES:
      BEGIN OF mast_cp_key,
        matnr TYPE matnr,
        werks TYPE werks_d,
        stlan TYPE stlan,
        stlal TYPE stlal,
      END OF mast_cp_key.
    DATA mast_cp_keys TYPE STANDARD TABLE OF mast_cp_key WITH EMPTY KEY.

    change_pointer_table = it_change_pointer.

    SORT change_pointer_table BY tabname cdobjid.
    DELETE ADJACENT DUPLICATES FROM change_pointer_table COMPARING tabname cdobjid.

    " --- 1. MAST changes: parse CDOBJID -> bulk look up the complete BOM key (incl. STLNR) ---
    LOOP AT change_pointer_table INTO DATA(mast_change_pointer) WHERE tabname = gc_cp_tabname_mast.
      INSERT VALUE mast_cp_key(
        matnr = mast_change_pointer-cdobjid+0(gc_len_matnr)
        werks = mast_change_pointer-cdobjid+18(gc_len_werks)
        stlan = mast_change_pointer-cdobjid+22(gc_len_stlan)
        stlal = mast_change_pointer-cdobjid+23(gc_len_stlal) ) INTO TABLE mast_cp_keys.
    ENDLOOP.

    IF mast_cp_keys IS NOT INITIAL.
      SELECT matnr, stlan, werks, stlal, stlnr
        FROM mast
        INTO CORRESPONDING FIELDS OF TABLE @mast_all
        FOR ALL ENTRIES IN @mast_cp_keys
        WHERE matnr = @mast_cp_keys-matnr
          AND werks = @mast_cp_keys-werks
          AND stlan = @mast_cp_keys-stlan
          AND stlal = @mast_cp_keys-stlal.
    ENDIF.

    " --- 2/3. STKO/STPO changes ---
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

    " --- 4. Look up MAST/STKO for complete BOM key + ECN ---
    IF mast_all IS NOT INITIAL.
      SORT mast_all BY matnr werks stlan stlal stlnr.
      DELETE ADJACENT DUPLICATES FROM mast_all
        COMPARING matnr werks stlan stlal stlnr.
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
        READ TABLE stko_aennr_lookup INTO DATA(stko_line) WITH KEY stlnr = mast_line-stlnr.
        IF sy-subrc = 0.
          key-stlty = stko_line-stlty.
          key-aennr = stko_line-aennr.
        ENDIF.
        INSERT key INTO TABLE keys.
      ENDLOOP.
    ENDIF.

    " --- 5. ECN status check (FS §5) — bulk pre-load AENR status ---
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
    DATA: werks TYPE werks_d VALUE gc_default_werks,
          stlan TYPE stlan   VALUE gc_default_stlan.
    DATA mast_all TYPE STANDARD TABLE OF mast WITH EMPTY KEY.
    DATA keys     TYPE key_table_ty.
    DATA key      TYPE bom_key_ty.

    DATA(max_rows_plus1) = gc_initial_max_rows + 1.
    SELECT matnr, stlan, werks, stlal, stlnr
      FROM mast
      INTO CORRESPONDING FIELDS OF TABLE @mast_all
      UP TO @max_rows_plus1 ROWS
      WHERE werks = @werks
        AND stlan = @stlan
      ORDER BY matnr, werks, stlan, stlal.

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
      runtime_parameter_ext-bal->add_msg(
        iv_msgty = if_drf_const=>msg_type_info
        iv_msgid = gc_msgid
        iv_msgno = '001'
        iv_msgv1 = |{ lines( mast_all ) }|
        iv_msgv2 = 'Initial candidates below the FS §14 lower limit of 300' ).
    ENDIF.

    IF mast_all IS NOT INITIAL.
      SELECT stlnr, stlty, aennr
        FROM stko
        INTO TABLE @DATA(stko_aennr_lookup)
        FOR ALL ENTRIES IN @mast_all
        WHERE stlnr = @mast_all-stlnr.
      SORT stko_aennr_lookup BY stlnr.
      LOOP AT mast_all INTO DATA(mast_line).
        CLEAR key.
        key-stlan = mast_line-stlan.
        key-werks = mast_line-werks.
        key-matnr = mast_line-matnr.
        key-stlal = mast_line-stlal.
        READ TABLE stko_aennr_lookup INTO DATA(stko_line) WITH KEY stlnr = mast_line-stlnr BINARY SEARCH.
        IF sy-subrc = 0.
          key-stlty = stko_line-stlty.
          key-aennr = stko_line-aennr.
        ENDIF.
        INSERT key INTO TABLE keys.
      ENDLOOP.

      " Bulk pre-load AENR status
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
        ENDIF.
      ENDLOOP.
      et_changed_objects = keys_valid.
    ENDIF.

    es_stat_info-object_count_out = lines( et_changed_objects ).
    es_stat_info-exception_raised = abap_false.
  ENDMETHOD.


  METHOD enrich_filter_criteria.
    " Parse screen selection criteria and fill FS §4 mandatory defaults.
    DATA: werks    TYPE rsds_selopt_t, matnr TYPE rsds_selopt_t,
          stlan    TYPE rsds_selopt_t, stlal TYPE rsds_selopt_t,
          datuv    TYPE rsds_selopt_t, datub TYPE rsds_selopt_t,
          selopt   TYPE rsdsselopt,
          selfield TYPE rsds_frange,
          seltab   TYPE rsds_range.

    LOOP AT it_external_criteria ASSIGNING FIELD-SYMBOL(<range>).
      LOOP AT <range>-frange_t ASSIGNING FIELD-SYMBOL(<frange>).
        CASE <frange>-fieldname.
          WHEN 'WERKS'.  APPEND LINES OF <frange>-selopt_t TO werks.
          WHEN 'MATNR'.  APPEND LINES OF <frange>-selopt_t TO matnr.
          WHEN 'STLAN'.  APPEND LINES OF <frange>-selopt_t TO stlan.
          WHEN 'STLAL'.  APPEND LINES OF <frange>-selopt_t TO stlal.
          WHEN 'DATUV'.  APPEND LINES OF <frange>-selopt_t TO datuv.
          WHEN 'DATUB'.  APPEND LINES OF <frange>-selopt_t TO datub.
          WHEN OTHERS.
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

    mt_stko_datuv = datuv.
    mt_stko_datub = datub.

    IF lines( werks ) = 0.
      APPEND VALUE #( sign = 'I' option = 'EQ' low = gc_default_werks ) TO werks.
    ENDIF.
    IF lines( stlan ) = 0.
      APPEND VALUE #( sign = 'I' option = 'EQ' low = gc_default_stlan ) TO stlan.
    ENDIF.

    seltab-tablename = 'MAST'.
    IF lines( werks ) > 0.
      selfield-fieldname = 'WERKS'.
      APPEND LINES OF werks TO selfield-selopt_t.
      APPEND selfield TO seltab-frange_t. CLEAR selfield.
    ENDIF.
    IF lines( matnr ) > 0.
      selfield-fieldname = 'MATNR'.
      APPEND LINES OF matnr TO selfield-selopt_t.
      APPEND selfield TO seltab-frange_t. CLEAR selfield.
    ENDIF.
    IF lines( stlan ) > 0.
      selfield-fieldname = 'STLAN'.
      APPEND LINES OF stlan TO selfield-selopt_t.
      APPEND selfield TO seltab-frange_t. CLEAR selfield.
    ENDIF.
    IF lines( stlal ) > 0.
      selfield-fieldname = 'STLAL'.
      APPEND LINES OF stlal TO selfield-selopt_t.
      APPEND selfield TO seltab-frange_t. CLEAR selfield.
    ENDIF.
    IF lines( seltab-frange_t ) > 0.
      APPEND seltab TO et_add_external_criteria.
    ENDIF.
    CLEAR seltab.

    seltab-tablename = 'STKO'.
    IF lines( datuv ) > 0.
      selfield-fieldname = 'DATUV'.
      APPEND LINES OF datuv TO selfield-selopt_t.
      APPEND selfield TO seltab-frange_t. CLEAR selfield.
    ENDIF.
    IF lines( datub ) > 0.
      selfield-fieldname = 'VALID_TO'.
      APPEND LINES OF datub TO selfield-selopt_t.
      APPEND selfield TO seltab-frange_t. CLEAR selfield.
    ENDIF.
    IF lines( seltab-frange_t ) > 0.
      APPEND seltab TO et_add_external_criteria.
    ENDIF.
  ENDMETHOD.


  METHOD get_bom_filter.
    IF mo_bom_filter IS NOT BOUND.
      mo_bom_filter = NEW zcl_mit_dcn_drf_bom_out_fltr( ).
    ENDIF.
    ro_bom_filter = mo_bom_filter.
  ENDMETHOD.


  METHOD read_complete_data.
    " Bulk read complete BOM data into buffers.
    DATA bom_number_set TYPE SORTED TABLE OF stnum WITH UNIQUE KEY table_line.
    DATA material_set   TYPE SORTED TABLE OF matnr WITH UNIQUE KEY table_line.

    CLEAR: mast_list, stko_list, stpo_list, stas_list, mara_list.

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

    LOOP AT ct_relevant_objects INTO DATA(ls_bom_key).
      DATA(ls_mast) = CORRESPONDING mast( ls_bom_key ).
      APPEND ls_mast TO mast_list.
      INSERT ls_bom_key-stlnr INTO TABLE bom_number_set.
    ENDLOOP.

    IF mast_list IS NOT INITIAL.
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

      SELECT stas_alias~stlty, stas_alias~stlnr,
             stas_alias~stlal, stas_alias~stlkn
        FROM stas AS stas_alias
        INNER JOIN @bom_number_set AS bom_number
          ON stas_alias~stlnr = bom_number~table_line
        WHERE stas_alias~stlty = 'M'
        INTO CORRESPONDING FIELDS OF TABLE @stas_list.
    ENDIF.

    material_set = VALUE #( FOR ls_tmp_mast IN mast_list ( ls_tmp_mast-matnr ) ).
    LOOP AT stpo_list INTO DATA(stpo_line).
      INSERT stpo_line-idnrk INTO TABLE material_set.
    ENDLOOP.
    IF material_set IS NOT INITIAL.
      SELECT matnr, meins FROM mara
        INTO CORRESPONDING FIELDS OF TABLE @mara_list
        FOR ALL ENTRIES IN @material_set
        WHERE matnr = @material_set-table_line.
    ENDIF.
  ENDMETHOD.


  METHOD map_data2message.
    " Maps BOM data to the local message buffer, then builds the ZBOM AIF message.
    " Field mapping (FS §7): ID01-ID17

    FIELD-SYMBOLS <bom_key> TYPE bom_key_ty.
    DATA bom_number TYPE stnum.
    DATA bom_type   TYPE stlty.
    DATA mara_line  TYPE mara.
    DATA stko_line  TYPE stko.
    DATA item       TYPE bom_item_ty.
    DATA lt_stlkn_set TYPE SORTED TABLE OF stlkn WITH UNIQUE KEY table_line.

    CLEAR: bom_header, bom_items.

    IF ir_relevant_object IS NOT BOUND.
      RAISE EXCEPTION TYPE cx_drf_exception.
    ENDIF.

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

    IF <bom_key>-stlty IS NOT INITIAL.
      READ TABLE stko_list WITH KEY stlnr = bom_number stlty = <bom_key>-stlty aennr = <bom_key>-aennr
        INTO stko_line.
      IF sy-subrc <> 0.
        READ TABLE stko_list WITH KEY stlnr = bom_number stlty = <bom_key>-stlty
          INTO stko_line.
      ENDIF.
    ELSE.
      READ TABLE stko_list WITH KEY stlnr = bom_number
        INTO stko_line.
    ENDIF.
    IF sy-subrc <> 0.
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

    bom_type = stko_line-stlty.

    READ TABLE mara_list WITH KEY matnr = mast_line-matnr INTO mara_line.

    map_bom_header(
      EXPORTING
        is_stko = stko_line
        is_mast = mast_line
        is_mara = mara_line
      CHANGING
        cs_bom  = bom_header ).

    LOOP AT stas_list INTO DATA(stas_line)
        WHERE stlnr = bom_number AND stlty = bom_type AND stlal = mast_line-stlal.
      INSERT stas_line-stlkn INTO TABLE lt_stlkn_set.
    ENDLOOP.

    LOOP AT stpo_list INTO DATA(stpo_line) WHERE stlnr = bom_number AND stlty = bom_type.
      IF lt_stlkn_set IS NOT INITIAL.
        READ TABLE lt_stlkn_set WITH KEY table_line = stpo_line-stlkn TRANSPORTING NO FIELDS.
        IF sy-subrc <> 0.
          CONTINUE.
        ENDIF.
      ENDIF.
      CLEAR item.
      map_bom_item(
        EXPORTING
          is_stpo = stpo_line
        CHANGING
          cs_item = item ).
      APPEND item TO bom_items.
    ENDLOOP.

    bom_message-header = bom_header.
    bom_message-items  = bom_items.

    " Build ZBOM AIF message (BOM-centric structure for /AIF/SEND_WITH_PROXY)
    CLEAR aif_message.
    build_aif_message(
      EXPORTING
        is_bom_message = bom_message
      CHANGING
        cs_aif_message = aif_message ).

  ENDMETHOD.


  METHOD send_message.
    " AIF send logic (FS §3).
    " ZBOM service: ZBOMReplicateReq_Async_Out (custom BOM-centric WSDL).
    " Aligned with reference CL_P_DCB_DRF_PRODVER_OUT~send_message:
    "   - Single message (no 2000-row batching — ZBOM is one BOM per message)
    "   - No /AIF/CREATE_APPL_LOG (DRF framework manages application log via bal)
    "   - TRY/CATCH cx_bs_soa_exception / cx_ai_system_fault
    "   - lv_sent_ok for success/failure; PERSISTENCY_ERROR (=1) tolerated
    "   - Object key restored from ct_obj_rep_sta[1]-object_id

    " --- Method-local declarations ---
    DATA: errmsg            TYPE drf_s_message,
          error_return      TYPE REF TO bapiret2,
          idnrk             TYPE idnrk,
          msgguid           TYPE sxmsmguid,
          msgguid_out       TYPE sxmsmguid,
          error_string      TYPE string,
          error_long        TYPE string,
          lv_sent_ok        TYPE abap_bool VALUE abap_true,
          lv_dummy          TYPE char20,
          bom_key           TYPE bom_key_ty,
          bom_key_ref       TYPE REF TO bom_key_ty,
          wsprotocol_msg_id TYPE REF TO if_wsprotocol_message_id,
          return_send       TYPE STANDARD TABLE OF bapiret2.

    IF lines( bom_items ) > 0.
      idnrk = bom_items[ 1 ]-cop_img_no.
    ENDIF.

    IF bom_message-header IS INITIAL AND bom_message-items IS INITIAL.
      RETURN.
    ENDIF.

    " Build BOM object key (from ct_obj_rep_sta[1]-object_id, fallback to header fields)
    READ TABLE ct_obj_rep_sta INTO DATA(ls_obj_rep_sta) INDEX 1.
    IF sy-subrc = 0.
      bom_key = CONV bom_key_ty( ls_obj_rep_sta-object_id ).
      GET REFERENCE OF bom_key INTO bom_key_ref.
    ELSE.
      bom_key-matnr = bom_message-header-cop_exg_no.
      bom_key-werks = gc_default_werks.
      bom_key-stlal = bom_message-header-alternative_bom.
      bom_key-aennr = bom_message-header-change_no.
      GET REFERENCE OF bom_key INTO bom_key_ref.
    ENDIF.

    " Mandatory field validation (FS §7 M flag)
    IF bom_message-header IS INITIAL
       OR bom_message-header-cop_exg_no IS INITIAL
       OR bom_message-header-header_qty IS INITIAL.
      LOOP AT ct_obj_rep_sta ASSIGNING FIELD-SYMBOL(<rep_status_init>).
        <rep_status_init>-repstatus = 'SE'.
      ENDLOOP.
      CREATE DATA error_return.
      error_return->type       = 'E'.
      error_return->id         = gc_msgid.
      error_return->number     = '001'.
      error_return->message_v1 = bom_header-cop_exg_no.
      error_return->message_v2 = gc_default_werks.
      error_return->message_v3 = idnrk.
      error_return->message_v4 = bom_header-change_no.
      errmsg-bo_type       = 'BILL_OF_MATERIAL'.
      errmsg-bo_key        = bom_header-cop_exg_no.
      errmsg-target_system = gc_logical_port.
      errmsg-message       = error_return.
      APPEND errmsg TO et_message.
      CLEAR: errmsg, error_return.
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

    LOOP AT bom_message-items ASSIGNING FIELD-SYMBOL(<item_chk>).
      IF <item_chk>-cop_img_no IS INITIAL
         OR <item_chk>-quantity IS INITIAL
         OR <item_chk>-operation_scrap < 0
         OR <item_chk>-component_scrap < 0.
        LOOP AT ct_obj_rep_sta ASSIGNING FIELD-SYMBOL(<rep_status_miss>).
          <rep_status_miss>-repstatus = 'SE'.
        ENDLOOP.
        CREATE DATA error_return.
        error_return->type       = 'E'.
        error_return->id         = gc_msgid.
        error_return->number     = '001'.
        error_return->message_v1 = bom_header-cop_exg_no.
        error_return->message_v2 = gc_default_werks.
        error_return->message_v3 = <item_chk>-cop_img_no.
        error_return->message_v4 = bom_header-change_no.
        errmsg-bo_type       = 'BILL_OF_MATERIAL'.
        errmsg-bo_key        = bom_header-cop_exg_no.
        errmsg-target_system = gc_logical_port.
        errmsg-message       = error_return.
        APPEND errmsg TO et_message.
        CLEAR: errmsg, error_return.
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

    " Override creation_date_time at send time (aligned with reference
    " CL_P_DCB_DRF_PRODVER_OUT~send_message — timestamp must reflect the actual
    " send moment, not the map_data2message moment). convert_timestamp does
    " CET→UTC; cl_bs_soa_convert produces the packed-decimal zglobal_date_time.
    DATA: lv_send_date TYPE datum,
          lv_send_time TYPE uzeit.

    lv_send_date = sy-datum.
    lv_send_time = sy-uzeit.
    convert_timestamp( CHANGING c_date = lv_send_date c_time = lv_send_time ).
    TRY.
        cl_bs_soa_convert_xsddatetime=>map_xsddatetime_long_z_out(
          EXPORTING
            iv_date         = lv_send_date
            iv_time         = lv_send_time
          IMPORTING
            ev_xsd_datetime = aif_message-parameters-message_header-creation_date_time ).
      CATCH cx_bs_soa_exception.
        CLEAR aif_message-parameters-message_header-creation_date_time.
    ENDTRY.

    " Local copy for the AIF send (aligned with reference: ls_message_data_outbound = ms_output
    " — protects the instance attribute from modification by /AIF/SEND_WITH_PROXY).
    DATA(ls_aif_message) = aif_message.

    " Single AIF send (ZBOM message — one BOM per message, no batching)
    TRY.
        IF runtime_parameter_ext-testrun = abap_false.
          CLEAR return_send.
          CALL FUNCTION '/AIF/SEND_WITH_PROXY'
            EXPORTING
              ns                   = gc_ns
              ifname               = gc_ifname
              ifversion            = gc_ifver
              appl_log_function    = 'AIF_SEND_WITH_PROXY'
              msgguid              = msgguid
              iv_persist_xml       = 'X'
              logical_port_name    = gc_logical_port
            IMPORTING
              ximsgguid            = msgguid
              ximsgguid_out        = msgguid_out
            TABLES
              add_return_tab       = return_send
            CHANGING
              sap_struct           = ls_aif_message
              error_string         = error_string
              error_long_text      = error_long
            EXCEPTIONS
              persistency_error    = 1
              status_update_failed = 2
              missing_keys         = 3
              interface_not_found  = 4
              transformation_error = 5
              general_error        = 6
              OTHERS               = 7.

          IF sy-subrc <> 0 AND sy-subrc <> 1.  " tolerate PERSISTENCY_ERROR
            lv_sent_ok = abap_false.
            " Log AIF error details — error_string / error_long_text carry the specific
            " failure reason (proxy class not found, structure mismatch, logical port, etc.)
            IF runtime_parameter_ext-bal IS BOUND.
              runtime_parameter_ext-bal->add_msg(
                iv_msgty = if_drf_const=>msg_type_error
                iv_msgid = gc_msgid
                iv_msgno = '001'
                iv_msgv1 = |AIF send failed (sy-subrc={ sy-subrc })|
                iv_msgv2 = error_string
                iv_msgv3 = error_long ).
            ENDIF.
          ELSE.
            " Check for business errors in the return table
            DATA(has_biz_error) = abap_false.
            LOOP AT return_send INTO DATA(ret_send)
              WHERE type = if_drf_const=>msg_type_error
                 OR type = 'A'.
              has_biz_error = abap_true.
              EXIT.
            ENDLOOP.
            IF has_biz_error = abap_true.
              lv_sent_ok = abap_false.
            ENDIF.

            " Object-level AIF log: associate GUID + payload (only when not a hard error)
            IF runtime_parameter_ext-bal IS BOUND.
              runtime_parameter_ext-bal->add_msg_xi(
                iv_xi_msg_guid         = msgguid_out
                iv_object_count        = iv_object_count
                io_message_id_protocol = wsprotocol_msg_id
                iv_outb_impl           = runtime_parameter_ext-outb_impl
                ir_object              = bom_key_ref
                is_message_out         = ls_aif_message ).
            ENDIF.
          ENDIF.
        ELSE.
          " Test run: do not send, log info message (aligned with reference)
          MESSAGE s322(drf_outbound) INTO lv_dummy.
          IF runtime_parameter_ext-bal IS BOUND.
            runtime_parameter_ext-bal->add_msg_re(
              iv_msgno = sy-msgno
              iv_msgid = sy-msgid ).
          ENDIF.
        ENDIF.

      CATCH cx_bs_soa_exception INTO DATA(lx_soa).
        LOOP AT ct_obj_rep_sta ASSIGNING FIELD-SYMBOL(<rep_status_soa>).
          <rep_status_soa>-repstatus = 'SE'.
        ENDLOOP.
        DATA(lv_soa_text) = lx_soa->get_text( ).
        DATA(lv_soa_long) = lx_soa->get_longtext( ).
        MESSAGE s015(drf_outbound) WITH gc_aif_service lv_soa_text lv_soa_long INTO lv_dummy ##needed.
        IF runtime_parameter_ext-bal IS BOUND.
          runtime_parameter_ext-bal->add_msg_re(
            iv_msgno             = sy-msgno
            iv_msgid             = sy-msgid
            iv_msgv1             = gc_aif_service
            iv_msgv2             = lv_soa_text
            ix_exception_catched = lx_soa ).
        ENDIF.

      CATCH cx_ai_system_fault INTO DATA(lx_fault).
        LOOP AT ct_obj_rep_sta ASSIGNING FIELD-SYMBOL(<rep_status_fault>).
          <rep_status_fault>-repstatus = 'SE'.
        ENDLOOP.
        DATA(lv_fault_text) = lx_fault->get_text( ).
        DATA(lv_fault_long) = lx_fault->get_longtext( ).
        MESSAGE s015(drf_outbound) WITH gc_aif_service lv_fault_text lv_fault_long INTO lv_dummy ##needed.
        IF runtime_parameter_ext-bal IS BOUND.
          runtime_parameter_ext-bal->add_msg_re(
            iv_msgno             = sy-msgno
            iv_msgid             = sy-msgid
            iv_msgv1             = gc_aif_service
            iv_msgv2             = lv_fault_text
            ix_exception_catched = lx_fault ).
        ENDIF.
    ENDTRY.

    " Status finalization
    IF lv_sent_ok = abap_true.
      LOOP AT ct_obj_rep_sta ASSIGNING FIELD-SYMBOL(<rep_status_ok>).
        <rep_status_ok>-repstatus = 'SN'.
      ENDLOOP.
      IF runtime_parameter_ext-bal IS BOUND.
        runtime_parameter_ext-bal->add_msg(
          iv_msgty = if_drf_const=>msg_type_success
          iv_msgid = gc_msgid
          iv_msgno = '001'
          iv_msgv1 = bom_header-cop_exg_no ).
      ENDIF.
    ELSE.
      " Send failed — mark all objects as 'SE' (sent with error)
      LOOP AT ct_obj_rep_sta ASSIGNING FIELD-SYMBOL(<rep_status_err>).
        <rep_status_err>-repstatus = 'SE'.
      ENDLOOP.
    ENDIF.

    CLEAR: bom_message, bom_header, bom_items.
  ENDMETHOD.


  METHOD finalize.
    IF it_erroneous_objects IS INITIAL
       AND iv_repeated_initial_run = abap_false.
      ev_delete_change_pointer = abap_true.
    ELSE.
      ev_delete_change_pointer = abap_false.
    ENDIF.

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
    rv_valid = abap_false.
    IF iv_aennr IS INITIAL.
      RETURN.
    ENDIF.
    READ TABLE it_aenr_status WITH KEY aennr = iv_aennr INTO DATA(status_line).
    IF sy-subrc <> 0.
      rv_valid = abap_false.
      RETURN.
    ENDIF.
    IF status_line-aenst IS INITIAL.
      rv_valid = abap_false.
    ELSEIF status_line-aenst = gc_ecn_status_released.
      rv_valid = abap_true.
    ELSE.
      rv_valid = abap_false.
    ENDIF.
  ENDMETHOD.


  METHOD map_bom_header.
    cs_bom-cop_exg_no      = is_mast-matnr.
    cs_bom-bom_creation    = is_stko-andat.
    cs_bom-alternative_bom = is_mast-stlal.
    cs_bom-bom_no          = is_mast-stlnr.
    cs_bom-change_no       = is_stko-aennr.
    cs_bom-bom_usage       = is_mast-stlan.
    cs_bom-header_start_date = is_stko-datuv.
    cs_bom-header_end_date   = is_stko-valid_to.
    cs_bom-header_qty        = is_stko-bmeng.
    cs_bom-header_unit       = is_mara-meins.
  ENDMETHOD.


  METHOD map_bom_item.
    cs_item-cop_img_no      = is_stpo-idnrk.
    cs_item-quantity        = is_stpo-menge.
    cs_item-valid_from      = is_stpo-datuv.
    cs_item-valid_to        = is_stpo-valid_to.
    cs_item-component_unit  = is_stpo-meins.
    cs_item-operation_scrap = is_stpo-avoau.
    cs_item-component_scrap = is_stpo-ausch.
  ENDMETHOD.


  METHOD build_aif_message.
    " Map local BOM buffer (bom_message_ty, 17 SAP source fields) to the ZBOM DDIC proxy
    " structure zzbomreplicate_request (the sap_struct registered in /aif/cust).
    " BOM-centric: components directly under BOM — no PV/workflow nesting, no empty network node hack.
    " All 17 FS fields mapped (ID01-ID17), including ID06 (BOMCreationDate) and
    " ID16 (OperationScrapInPercent) which were unmappable in the PV structure.
    "
    " DDIC sap_struct path: cs_aif_message-parameters-bom-bomheader / bomcomponent[]
    "
    " Conversions (aligned with reference CL_P_DCB_DRF_PRODVER_OUT):
    "   - Material: CONVERSION_EXIT_MATN1_OUTPUT (SAP internal → external format)
    "   - Unit:     CONVERSION_EXIT_CUNIT_OUTPUT (SAP internal → commercial format) + shift/trim

    DATA: ls_component       TYPE zbomcomponent_type,
          lv_material_ext    TYPE matnr,
          lv_commercial_unit TYPE c LENGTH 3.

    CLEAR cs_aif_message.

    " Message header (UUID, creation datetime, sender/recipient)
    cs_aif_message-parameters-message_header = build_business_header( ).

    " BOM header (ID01, ID06-ID14) — DDIC field names from zbomheader_type

    " ID01: Material — convert to external format (CONVERSION_EXIT_MATN1_OUTPUT)
    CALL FUNCTION 'CONVERSION_EXIT_MATN1_OUTPUT'
      EXPORTING
        input  = is_bom_message-header-cop_exg_no
      IMPORTING
        output = lv_material_ext.
    cs_aif_message-parameters-bom-bomheader-material = lv_material_ext.

    cs_aif_message-parameters-bom-bomheader-plant                           = gc_default_werks.
    cs_aif_message-parameters-bom-bomheader-bomcategory                     = 'M'.
    cs_aif_message-parameters-bom-bomheader-bill_of_material                = is_bom_message-header-bom_no.            " ID08
    cs_aif_message-parameters-bom-bomheader-bill_of_material_variant        = is_bom_message-header-alternative_bom.   " ID07
    cs_aif_message-parameters-bom-bomheader-bill_of_material_variant_usage  = is_bom_message-header-bom_usage.         " ID10
    cs_aif_message-parameters-bom-bomheader-bomheader_quantity_in_base_uni  = is_bom_message-header-header_qty.       " ID13

    " ID14: Base unit — convert to commercial format (CONVERSION_EXIT_CUNIT_OUTPUT)
    CALL FUNCTION 'CONVERSION_EXIT_CUNIT_OUTPUT'
      EXPORTING
        input          = is_bom_message-header-header_unit
        language       = 'E'
      IMPORTING
        output         = lv_commercial_unit
      EXCEPTIONS
        unit_not_found = 1
        OTHERS         = 2.
    IF sy-subrc = 0.
      cs_aif_message-parameters-bom-bomheader-bomheader_base_unit = lv_commercial_unit.
    ELSE.
      cs_aif_message-parameters-bom-bomheader-bomheader_base_unit = is_bom_message-header-header_unit.
    ENDIF.
    SHIFT cs_aif_message-parameters-bom-bomheader-bomheader_base_unit RIGHT DELETING TRAILING space.
    SHIFT cs_aif_message-parameters-bom-bomheader-bomheader_base_unit LEFT  DELETING LEADING space.

    cs_aif_message-parameters-bom-bomheader-bomheader_ecn                   = is_bom_message-header-change_no.         " ID09
    cs_aif_message-parameters-bom-bomheader-bomcreation_date                = is_bom_message-header-bom_creation.      " ID06 (NEW)
    cs_aif_message-parameters-bom-bomheader-bomvalidity_start_date          = is_bom_message-header-header_start_date. " ID11
    cs_aif_message-parameters-bom-bomheader-bomvalidity_end_date            = is_bom_message-header-header_end_date.   " ID12

    " BOM components (ID02-ID05, ID15-ID17) — directly under BOM, no nesting
    LOOP AT is_bom_message-items ASSIGNING FIELD-SYMBOL(<ls_item>).
      CLEAR ls_component.

      " ID02: Component material — convert to external format (CONVERSION_EXIT_MATN1_OUTPUT)
      CALL FUNCTION 'CONVERSION_EXIT_MATN1_OUTPUT'
        EXPORTING
          input  = <ls_item>-cop_img_no
        IMPORTING
          output = lv_material_ext.
      ls_component-bill_of_material_component = lv_material_ext.

      ls_component-bill_of_material_item_quantity-content = <ls_item>-quantity.          " ID03

      " ID15: Component unit — convert to commercial format (CONVERSION_EXIT_CUNIT_OUTPUT)
      CALL FUNCTION 'CONVERSION_EXIT_CUNIT_OUTPUT'
        EXPORTING
          input          = <ls_item>-component_unit
          language       = 'E'
        IMPORTING
          output         = lv_commercial_unit
        EXCEPTIONS
          unit_not_found = 1
          OTHERS         = 2.
      IF sy-subrc = 0.
        ls_component-bill_of_material_item_quantity-unit_code = lv_commercial_unit.
      ELSE.
        ls_component-bill_of_material_item_quantity-unit_code = <ls_item>-component_unit.
      ENDIF.
      SHIFT ls_component-bill_of_material_item_quantity-unit_code RIGHT DELETING TRAILING space.
      SHIFT ls_component-bill_of_material_item_quantity-unit_code LEFT  DELETING LEADING space.

      ls_component-validity_start_date                      = <ls_item>-valid_from.        " ID04
      ls_component-validity_end_date                        = <ls_item>-valid_to.          " ID05
      ls_component-component_scrap_in_percent               = <ls_item>-component_scrap.   " ID17
      ls_component-operation_scrap_in_percent               = <ls_item>-operation_scrap.   " ID16 (NEW)
      APPEND ls_component TO cs_aif_message-parameters-bom-bomcomponent.
    ENDLOOP.

    " Proxy structures only serialize fields whose controller flag is set.
    " Without this the persisted/sent XML body is empty even though the ABAP
    " structure is filled. Mirrors the controller population the AIF mapping
    " engine performs for fully-configured interfaces (e.g. YOMES_PV).
    fill_proxy_controllers( CHANGING cs_msg = cs_aif_message ).

  ENDMETHOD.


  METHOD fill_proxy_controllers.
*" Set the PRXCTRLTAB "field is filled" flag for every populated component at
*" every level of the zzbomreplicate_request proxy structure. The ABAP proxy
*" runtime only serializes components whose controller entry has value = abap_true;
*" without these flags the XML body comes out empty even when the structure is full.

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


  METHOD build_business_header.
    " Build the ZBOM message header (zbusiness_document_message_hea).
    " Aligned with reference CL_P_DCB_DRF_PRODVER_OUT~get_business_header and
    " zcl_m1t_dcn_bom_change_en~build_business_header:
    "   - id/uuid: UUID C32 (via cl_system_uuid)
    "   - creation_date_time: system time → UTC → proxy datetime via
    "     cl_bs_soa_convert_xsddatetime (zglobal_date_time is dec(21,7), NOT a string)
    "   - sender_business_system_id: LCR_GET_OWN_BUSINESS_SYSTEM
    "   - recipient_business_system_id: from runtime parameter

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
      " creation_date_time is zglobal_date_time (dec(21,7)) — proxy datetime, not a string.
      " Use cl_bs_soa_convert_xsddatetime to produce the correct packed-decimal representation.
      TRY.
          cl_bs_soa_convert_xsddatetime=>map_xsddatetime_long_z_out(
            EXPORTING
              iv_date         = lv_date
              iv_time         = lv_time
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

    rs_header-recipient_business_system_id = runtime_parameter_ext-business_system.

  ENDMETHOD.


  METHOD convert_timestamp.
*" CET local date/time → UTC (aligned with reference CL_P_DCB_DRF_PRODVER_OUT).
*" Handles the 24:00:00 midnight rollover before converting.
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

ENDCLASS.
