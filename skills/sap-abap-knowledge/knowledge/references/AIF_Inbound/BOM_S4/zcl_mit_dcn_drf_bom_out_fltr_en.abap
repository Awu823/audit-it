*"! <p class="shorttext synchronized">DRF BOM Outbound: Object-Level Filter (S4H → ECMS)</p>
*"!
*"! This class implements IF_DRF_FILTER for object-level relevance filtering:
*"! ① Dynamically build the WHERE condition from the BOM selection structure
*"!    (ZMCN_BOM_DRF_FLTR_S: matnr/werks/stlan/stlal);
*"! ② Merge with external criteria (rsds_trange, filter selection structure scope) as AND;
*"! ③ Check MAST for an existing BOM link, keeping only real BOM links.
*"! Corresponding FS: BOM SAP to ECMS interface (ZCN_ECMS / ZDCN_PBOM)
*"! Reference production: /RGS/CL_P_DCB_DRF_PROCORD_FLTR (production order → MES object-level filter)
CLASS zcl_mit_dcn_drf_bom_out_fltr DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    INTERFACES if_drf_filter.

  PRIVATE SECTION.

    CONSTANTS c_max_rows TYPE i VALUE 5000 ##NO_TEXT.

    " Filter selection structure (aligned with production /RGS/P_DCB_PO_DRF_FLTR_S):
    " The line type of it_unfiltered_objects / it_external_criteria is the filter's selection
    " structure, NOT the outbound implementation's object-key table (key_table_ty).
    " The filter works on this structure scope for both input and output.
    TYPES filter_struct_ty TYPE ZMCN_BOM_DRF_FLTR_S.
    " Use STANDARD table instead of SORTED: the MAST four columns (matnr/werks/stlan/stlal) can repeat
    " (the actual MAST key is matnr/werks/stlan/stlal/stlnr, five columns), so SORT + DELETE ADJACENT
    " DUPLICATES is used for explicit dedup (aligned with production L367-368); SORTED tables do not allow SORT.
    TYPES filter_table_ty   TYPE STANDARD TABLE OF filter_struct_ty WITH EMPTY KEY.

    METHODS convert_field_to_condition
      IMPORTING iv_field_name  TYPE string
                iv_field_value TYPE any
      RETURNING VALUE(rv_result) TYPE string.

    METHODS get_condition_for_filter_line
      IMPORTING is_key_filter TYPE filter_struct_ty
      RETURNING VALUE(rv_result) TYPE string.

    METHODS get_object_filter
      IMPORTING it_key_filter TYPE filter_table_ty
      RETURNING VALUE(rv_result) TYPE string.

    METHODS get_external_filter
      IMPORTING it_external_criteria TYPE rsds_trange
      RETURNING VALUE(rt_result) TYPE rsds_where_tab.

ENDCLASS.


CLASS zcl_mit_dcn_drf_bom_out_fltr IMPLEMENTATION.


  METHOD convert_field_to_condition.
    " Single field → dynamic condition fragment: if it contains wildcards (* +) use LIKE (escape % _), otherwise EQ.
    " Wildcard escaping is the inherited production behavior (*→%, +→_); a literal % or _ in the
    " input is not escaped and would act as a LIKE wildcard. This is a known edge case, consistent with
    " production; it does not affect BOM key values (matnr/werks/stlan/stlal carry no literal %/_).
    rv_result = cl_abap_dyn_prg=>quote( iv_field_value ).
    IF rv_result CA '*+'.
      TRANSLATE rv_result USING '*%'.
      TRANSLATE rv_result USING '+_'.
      rv_result = |( | && iv_field_name && | LIKE | && rv_result && | )|.
    ELSE.
      rv_result = |( | && iv_field_name && | EQ | && rv_result && | )|.
    ENDIF.
  ENDMETHOD.


  METHOD get_condition_for_filter_line.
    " BOM key → AND condition fragment.
    " Note: the MAST lookup only needs matnr/werks/stlan/stlal (MAST key order);
    "     stlty/aennr are provided by STKO, MAST has neither, so they do not participate in the MAST filter.
    IF is_key_filter-matnr IS NOT INITIAL.
      IF rv_result IS NOT INITIAL.
        rv_result = rv_result && | AND |.
      ENDIF.
      rv_result = rv_result && convert_field_to_condition(
        iv_field_name  = 'MATNR'
        iv_field_value = is_key_filter-matnr ).
    ENDIF.

    IF is_key_filter-werks IS NOT INITIAL.
      IF rv_result IS NOT INITIAL.
        rv_result = rv_result && | AND |.
      ENDIF.
      rv_result = rv_result && convert_field_to_condition(
        iv_field_name  = 'WERKS'
        iv_field_value = is_key_filter-werks ).
    ENDIF.

    IF is_key_filter-stlan IS NOT INITIAL.
      IF rv_result IS NOT INITIAL.
        rv_result = rv_result && | AND |.
      ENDIF.
      rv_result = rv_result && convert_field_to_condition(
        iv_field_name  = 'STLAN'
        iv_field_value = is_key_filter-stlan ).
    ENDIF.

    IF is_key_filter-stlal IS NOT INITIAL.
      IF rv_result IS NOT INITIAL.
        rv_result = rv_result && | AND |.
      ENDIF.
      rv_result = rv_result && convert_field_to_condition(
        iv_field_name  = 'STLAL'
        iv_field_value = is_key_filter-stlal ).
    ENDIF.
  ENDMETHOD.


  METHOD get_object_filter.
    " Candidate objects (already CONV'd to filter_table_ty) → OR condition (one condition per BOM link).
    " Note: the caller already CONVs it_unfiltered_objects to lt_key_filter before passing it,
    "     so this receives it directly and does not re-CONV (eliminating two conversions of the same input).
    LOOP AT it_key_filter INTO DATA(ls_key_filter).
      DATA(lv_line_cond) = get_condition_for_filter_line(
        is_key_filter = ls_key_filter ).
      IF lv_line_cond IS NOT INITIAL.
        " Only append OR when this line actually contributes a condition,
        " avoiding a dangling "OR" when a BOM key is entirely empty.
        IF rv_result IS NOT INITIAL.
          rv_result = rv_result && | OR |.
        ENDIF.
        rv_result = rv_result && |( | && lv_line_cond && | )|.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD get_external_filter.
    " External criteria (rsds_trange) → WHERE table.
    " Note: in the where_clauses produced by FREE_SELECTIONS_RANGE_2_WHERE the tablename points to
    "     the filter's selection structure (aligned with production '/RGS/P_DCB_PO_DRF_FLTR_S'),
    "     not the database table name. Here we take the ZMCN_BOM_DRF_FLTR_S fragment; its field names
    "     (matnr/werks/stlan/stlal) match the MAST columns, so they can be appended directly to the MAST SELECT.
    DATA(lt_external_where_cond) = VALUE rsds_twhere( ).
    CALL FUNCTION 'FREE_SELECTIONS_RANGE_2_WHERE'
      EXPORTING
        field_ranges  = it_external_criteria
      IMPORTING
        where_clauses = lt_external_where_cond.
    READ TABLE lt_external_where_cond REFERENCE INTO DATA(lr_external_where_cond)
      WITH KEY tablename = 'ZMCN_BOM_DRF_FLTR_S'.
    IF sy-subrc = 0.
      rt_result = lr_external_where_cond->where_tab.
    ENDIF.
  ENDMETHOD.


  METHOD if_drf_filter~apply_filter.
    " Object-level relevance filter: keep only BOM links that actually exist in MAST.
    " Homomorphic to production /RGS/CL_P_DCB_DRF_PROCORD_FLTR, but the filtering basis changes from
    " an "order filter table" to a "MAST existence check" — BOM has no dedicated filter table,
    " the object key is the MAST primary key.

    CLEAR et_filtered_objects.

    " --- DRFOUT authorization check (BOM decision: not implemented; if needed, define a BOM-specific
    "     auth object and uncomment) ---
    " AUTHORITY-CHECK OBJECT '<BOM_AUTH_OBJECT>'
    "   ID 'ACTVT' FIELD '16'
    "   ID 'DRF_APPL' FIELD iv_appl
    "   ID 'DRF_SERV' FIELD iv_outb_impl
    "   ID 'DRF_RECEIV' FIELD iv_business_system.
    " IF sy-subrc <> 0.
    "   io_bal->add_msg( iv_msgty = 'E' iv_msgid = 'ZDCN_PBOM' iv_msgno = '001'
    "                    iv_msgv1 = iv_appl iv_msgv2 = iv_outb_impl iv_msgv3 = iv_business_system ).
    "   RETURN.
    " ENDIF.

    " Candidate objects → selection structure table (filter scope, not the object-key table).
    " Only used to generate the object OR condition (lv_object_filter) that drives the SELECT;
    " it is not fed back as output.
    DATA(lt_key_filter) = CONV filter_table_ty( it_unfiltered_objects ).

    " Object condition + external condition (MAST only) — these are parallel AND conditions (aligned with production):
    " if either is empty processing does not stop; an empty condition naturally has no effect in the dynamic WHERE,
    " while the other still applies. Only when both are empty (no filtering basis) do we return early to avoid
    " an empty dynamic WHERE error / full table scan.
    DATA(lv_object_filter) = get_object_filter( lt_key_filter ).
    DATA(lt_external_filter) = get_external_filter( it_external_criteria ).
    IF lv_object_filter IS INITIAL
       AND lt_external_filter IS INITIAL.
      RETURN.
    ENDIF.

    " Query MAST to verify the BOM link exists (four columns matnr/werks/stlan/stlal, the MAST key).
    " WHERE uses the candidate OR condition (lv_object_filter) AND the external condition in parallel;
    " the result lt_filtered is already "candidate ∩ MAST exists ∩ external condition", used directly as the filter output.
    " (The candidate already participates in the SELECT via lv_object_filter; no need to LOOP candidates back for matching.)
    " Date screening (STKO-DATUV/DATUB) is intentionally NOT part of this filter — the selection
    " structure ZMCN_BOM_DRF_FLTR_S holds only MAST columns (matnr/werks/stlan/stlal/stlnr), and MAST has
    " no date columns. Validity dates are enforced in the biz layer instead: read_complete_data reads
    " STKO with `datuv IN @mt_stko_datuv AND valid_to IN @mt_stko_datub` (screen ranges parsed in
    " enrich_filter_criteria). Do not add dates here.
    DATA(lt_filtered) = VALUE filter_table_ty( ).
    SELECT matnr, werks, stlan, stlal, stlnr
      FROM mast
      WHERE (lv_object_filter)
        AND (lt_external_filter)
      INTO CORRESPONDING FIELDS OF TABLE @lt_filtered
      UP TO @c_max_rows ROWS.

    " Sort by MAST key and dedupe (explicit dedup, guarantees no duplicate links in et_filtered_objects).
    " Dedup compares the 4 MAST columns (matnr/werks/stlan/stlal) and keeps the first stlnr per key.
    " This is safe because STLAL determines the BOM number, so (matnr,werks,stlan,stlal) maps to a
    " single STLNR in MAST. If multi-MAST-per-alternative ever occurs, dedup must include stlnr.
    SORT lt_filtered BY matnr werks stlan stlal.
    DELETE ADJACENT DUPLICATES FROM lt_filtered
      COMPARING matnr werks stlan stlal.

    et_filtered_objects = CORRESPONDING #( lt_filtered ).

    " Write a warning when the volume limit is reached (aligned with production c_max_rows warning behavior)
    IF lines( et_filtered_objects ) >= c_max_rows
       AND io_bal IS BOUND.
      io_bal->add_msg(
        iv_msgty = if_drf_const=>msg_type_warning
        iv_msgid = 'ZDCN_PBOM'
        iv_msgno = '001'
        iv_msgv1 = |{ c_max_rows }| ).
    ENDIF.
  ENDMETHOD.


ENDCLASS.
