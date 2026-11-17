CLASS ZCL_DRF_REF_PROCORD_FLTR DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.

    INTERFACES if_drf_filter .
  PROTECTED SECTION.
private section.

  constants C_MAX_ROWS type I value 5000 ##NO_TEXT.
  data MO_DRF_WRAPPER type ref to LIF_DRF_WRAPPER .
  data M_RGS_P_DRF_AUTH_CHECK type ABAP_BOOLEAN .

"  data MT_JSTAT_BY_AUFNR type ZCL_DRF_REF_PROCORD_OUT=>TT_JSTAT_BY_AUFNR .
  methods GET_DRF_WRAPPER
    returning
      value(RO_DRF_WRAPPER) type ref to LIF_DRF_WRAPPER .
  methods CONVERT_FIELD_TO_CONDITION
    importing
      !IV_FIELD_NAME type STRING
      !IV_FIELD_VALUE type ANY
    returning
      value(RV_RESULT) type STRING .
  methods GET_CONDITION_FOR_FILTER_LINE
    importing
      !IS_KEY_FILTER type ZP_DCB_PO_DRF_FLTR_S
    returning
      value(RV_RESULT) type STRING .
  methods GET_OBJECT_FILTER
    importing
      !IT_UNFILTERED_OBJECTS type SORTED TABLE
    returning
      value(RV_RESULT) type STRING .
  methods GET_EXTERNAL_FILTER
    importing
      !IT_EXTERNAL_CRITERIA type RSDS_TRANGE
    returning
      value(RT_RESULT) type RSDS_WHERE_TAB .
ENDCLASS.



CLASS ZCL_DRF_REF_PROCORD_FLTR IMPLEMENTATION.


  method CONVERT_FIELD_TO_CONDITION.
    RV_RESULT = CL_ABAP_DYN_PRG=>QUOTE( IV_FIELD_VALUE ).
    if RV_RESULT ca '*+'.
      translate RV_RESULT using '*%'.
      translate RV_RESULT using '+_'.
      RV_RESULT = |( | && IV_FIELD_NAME && | LIKE | && RV_RESULT && | )|.
    else.
      RV_RESULT = |( | && IV_FIELD_NAME && | EQ | && RV_RESULT && | )|.
    endif.
  endmethod.


  method GET_CONDITION_FOR_FILTER_LINE.

    if IS_KEY_FILTER-AUFNR <> ''.
      if RV_RESULT is not initial.
        RV_RESULT = RV_RESULT && | AND |.
      endif.
      RV_RESULT = RV_RESULT && CONVERT_FIELD_TO_CONDITION(
      IV_FIELD_NAME  = 'AUFNR'
      IV_FIELD_VALUE = IS_KEY_FILTER-AUFNR
      ).
    endif.


    if IS_KEY_FILTER-AUART  <> ''.
      if RV_RESULT is not initial.
        RV_RESULT = RV_RESULT && | AND |.
      endif.
      RV_RESULT = RV_RESULT && CONVERT_FIELD_TO_CONDITION(
      IV_FIELD_NAME  = 'AUART'
      IV_FIELD_VALUE = IS_KEY_FILTER-AUART
      ).
    endif.


    if IS_KEY_FILTER-WERKS <> ''.
      if RV_RESULT is not initial.
        RV_RESULT = RV_RESULT && | AND |.
      endif.
      RV_RESULT = CONVERT_FIELD_TO_CONDITION(
      IV_FIELD_NAME  = 'WERKS'
      IV_FIELD_VALUE = IS_KEY_FILTER-WERKS
      ).
    endif.

    if IS_KEY_FILTER-PLNBEZ <> ''.
      if RV_RESULT is not initial.
        RV_RESULT = RV_RESULT && | AND |.
      endif.
      RV_RESULT = CONVERT_FIELD_TO_CONDITION(
      IV_FIELD_NAME  = 'PLNBEZ'
      IV_FIELD_VALUE = IS_KEY_FILTER-PLNBEZ
      ).
    endif.


    " No charge in filter

**    if IS_KEY_FILTER-CHARG <> ''.
**      if RV_RESULT is not initial.
**        RV_RESULT = RV_RESULT && | AND |.
**      endif.
**      RV_RESULT = RV_RESULT && CONVERT_FIELD_TO_CONDITION(
**        IV_FIELD_NAME  = 'charg'
**        IV_FIELD_VALUE = IS_KEY_FILTER-CHARG
**      ).
**    endif.

    if IS_KEY_FILTER-SFCPF <> ''.
      if RV_RESULT is not initial.
        RV_RESULT = RV_RESULT && | AND |.
      endif.
      RV_RESULT = RV_RESULT && CONVERT_FIELD_TO_CONDITION(
      IV_FIELD_NAME  = 'SFCPF'
      IV_FIELD_VALUE = IS_KEY_FILTER-SFCPF
      ).
    endif.

    if IS_KEY_FILTER-DISPO <> ''.
      if RV_RESULT is not initial.
        RV_RESULT = RV_RESULT && | AND |.
      endif.
      RV_RESULT = RV_RESULT && CONVERT_FIELD_TO_CONDITION(
      IV_FIELD_NAME  = 'DISPO'
      IV_FIELD_VALUE = IS_KEY_FILTER-DISPO
      ).
    endif.

    if IS_KEY_FILTER-MES  <> ''.
      if RV_RESULT is not initial.
        RV_RESULT = RV_RESULT && | AND |.
      endif.
      RV_RESULT = RV_RESULT && CONVERT_FIELD_TO_CONDITION(
      IV_FIELD_NAME  = 'MES'
      IV_FIELD_VALUE = IS_KEY_FILTER-MES
      ).
    endif.


    if IS_KEY_FILTER-GSTRP  <> ''.
      if RV_RESULT is not initial.
        RV_RESULT = RV_RESULT && | AND |.
      endif.
      RV_RESULT = RV_RESULT && CONVERT_FIELD_TO_CONDITION(
      IV_FIELD_NAME  = 'GSTRP'
      IV_FIELD_VALUE = IS_KEY_FILTER-GSTRP
      ).
    endif.


    if IS_KEY_FILTER-GSUZP  <> ''.
      if RV_RESULT is not initial.
        RV_RESULT = RV_RESULT && | AND |.
      endif.
      RV_RESULT = RV_RESULT && CONVERT_FIELD_TO_CONDITION(
      IV_FIELD_NAME  = 'GSUZP'
      IV_FIELD_VALUE = IS_KEY_FILTER-GSUZP
      ).
    endif.

    if IS_KEY_FILTER-GLTRP  <> ''.
      if RV_RESULT is not initial.
        RV_RESULT = RV_RESULT && | AND |.
      endif.
      RV_RESULT = RV_RESULT && CONVERT_FIELD_TO_CONDITION(
      IV_FIELD_NAME  = 'GLTRP'
      IV_FIELD_VALUE = IS_KEY_FILTER-GLTRP
      ).
    endif.

    if IS_KEY_FILTER-GLUZP  <> ''.
      if RV_RESULT is not initial.
        RV_RESULT = RV_RESULT && | AND |.
      endif.
      RV_RESULT = RV_RESULT && CONVERT_FIELD_TO_CONDITION(
      IV_FIELD_NAME  = 'GLUZP'
      IV_FIELD_VALUE = IS_KEY_FILTER-GLUZP
      ).
    endif.

    if IS_KEY_FILTER-GSTRS  <> ''.
      if RV_RESULT is not initial.
        RV_RESULT = RV_RESULT && | AND |.
      endif.
      RV_RESULT = RV_RESULT && CONVERT_FIELD_TO_CONDITION(
      IV_FIELD_NAME  = 'GSTRS'
      IV_FIELD_VALUE = IS_KEY_FILTER-GSTRS
      ).
    endif.

    if IS_KEY_FILTER-GSUZS  <> ''.
      if RV_RESULT is not initial.
        RV_RESULT = RV_RESULT && | AND |.
      endif.
      RV_RESULT = RV_RESULT && CONVERT_FIELD_TO_CONDITION(
      IV_FIELD_NAME  = 'GSUZS'
      IV_FIELD_VALUE = IS_KEY_FILTER-GSUZS
      ).
    endif.

    if IS_KEY_FILTER-GLTRS  <> ''.
      if RV_RESULT is not initial.
        RV_RESULT = RV_RESULT && | AND |.
      endif.
      RV_RESULT = RV_RESULT && CONVERT_FIELD_TO_CONDITION(
      IV_FIELD_NAME  = 'GLTRS'
      IV_FIELD_VALUE = IS_KEY_FILTER-GLTRS
      ).
    endif.

    if IS_KEY_FILTER-GLUZS  <> ''.
      if RV_RESULT is not initial.
        RV_RESULT = RV_RESULT && | AND |.
      endif.
      RV_RESULT = RV_RESULT && CONVERT_FIELD_TO_CONDITION(
      IV_FIELD_NAME  = 'GLUZS'
      IV_FIELD_VALUE = IS_KEY_FILTER-GLUZS
      ).
    endif.

  endmethod.


  METHOD get_drf_wrapper.
    IF mo_drf_wrapper IS NOT BOUND.
      mo_drf_wrapper = NEW lcl_drf_wrapper( ).
    ENDIF.

    ro_drf_wrapper = mo_drf_wrapper.
  ENDMETHOD.


  METHOD get_external_filter.
*------------------------------------------------------------------------------------------------*
* Functional Spec: Process order MES interface
* Technical Spec: Process order MES interface
* Process: Manage and Release Orders
* History ---------------------------------------------------------------------------------------------------*
* Date       | Change           | Contributor               | Description
*------------------------------------------------------------------------------------------------------------*
*------------------------------------------------------------------------------------------------------------*


    DATA(lt_external_where_cond) = VALUE rsds_twhere( ).
    CALL FUNCTION 'FREE_SELECTIONS_RANGE_2_WHERE'
      EXPORTING
        field_ranges  = it_external_criteria
      IMPORTING
        where_clauses = lt_external_where_cond.
    READ TABLE lt_external_where_cond REFERENCE INTO DATA(lr_external_where_cond)
      WITH KEY tablename =  'ZP_DCB_PO_DRF_FLTR_S' . "'ZP_S_MCN_DRF_BATCH_SELECT'.  "
    IF sy-subrc = 0.
      rt_result = lr_external_where_cond->where_tab.
    ENDIF.


  ENDMETHOD.


  METHOD get_object_filter.
    "DATA(lt_key_filter) = CONV ZCL_DRF_REF_PROCORD_OUT=>tt_key_table( it_unfiltered_objects ).


    DATA(lt_key_filter) = CONV  ZP_DCB_PO_DRF_FLTR_T( it_unfiltered_objects ).

    LOOP AT lt_key_filter INTO DATA(ls_key_filter).
      IF rv_result IS NOT INITIAL.
        rv_result = rv_result && | OR |.
      ENDIF.
      DATA(lv_line_cond) = get_condition_for_filter_line(
        is_key_filter = ls_key_filter
      ).
      IF lv_line_cond IS NOT INITIAL.
        rv_result = rv_result && |( | && lv_line_cond && | )|.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD if_drf_filter~apply_filter.
*------------------------------------------------------------------------------------------------*
* Functional Spec: Process order MES interface
* Technical Spec: Process order MES interface
* Process: Manage and Release Orders
* History ---------------------------------------------------------------------------------------------------*
* Date       | Change           | Contributor               | Description
*------------------------------------------------------------------------------------------------------------*
*------------------------------------------------------------------------------------------------------------*


    CLEAR et_filtered_objects.
    DATA(lt_external_filter) = get_external_filter( it_external_criteria ).

    " {
    " DRFOUT authoriz. for YP_MES
    DATA:
      drf_appl   TYPE drf_appl,
      drf_serv   TYPE drf_outb_impl,
      drf_receiv TYPE drf_business_system.


 "   GET PARAMETER ID 'ZP_DCB_GT_P_DRF' FIELD m_rgs_p_drf_auth_check.
 "   IF sy-subrc <> 0.
 "     m_rgs_p_drf_auth_check = abap_false.
 "   ENDIF.

"    IF m_rgs_p_drf_auth_check = abap_true.
      drf_appl = iv_appl.
      drf_serv = iv_outb_impl.
      drf_receiv = iv_business_system.

      AUTHORITY-CHECK OBJECT 'ZP_DRF'
       ID 'ACTVT' FIELD '16'  "  Execute
       ID 'DRF_APPL' FIELD drf_appl
       ID 'DRF_SERV' FIELD  drf_serv
       ID 'DRF_RECEIV' FIELD  drf_receiv.
      IF sy-subrc <> 0.
        io_bal->add_msg( iv_msgty = 'E' iv_msgid = 'ZP_DCB_PROCORD'  iv_msgno = '062' iv_msgv1 = drf_appl iv_msgv2 = drf_serv iv_msgv3 = drf_receiv  ).
        RETURN.
      ENDIF.


"    ENDIF.
    " }   DRFOUT authoriz. for YP_MES

    DATA(lv_object_filter) = get_object_filter( it_unfiltered_objects ).

    SELECT DISTINCT aufnr
      "AUART , WERKS , PLNBEZ , "CHARG , "
      "GSTRP , GSUZP , GLTRP , GLUZP , GSTRS , GSUZS , GLTRS , GLUZS , MES
      FROM ZP_S_PROCORD_FLT1   " ZP_S_FL1
    WHERE (lv_object_filter)
      AND (lt_external_filter)
      " and MES eq @IV_BUSINESS_SYSTEM    "ENRICH_FILTER "
      INTO TABLE @DATA(l_filtered_objects)
      UP TO @c_max_rows ROWS.

    DATA(rc1) = sy-subrc.


    SELECT DISTINCT aufnr
    FROM ZP_S_PROCORD_FLT2   " "
    WHERE (lv_object_filter)
    "AND (lt_external_filter)          "

    "APPENDING CORRESPONDING FIELDS OF TABLE @et_filtered_objects "
    APPENDING TABLE @l_filtered_objects
    UP TO @c_max_rows ROWS.
    DATA(rc2) = sy-subrc.

    SORT l_filtered_objects BY aufnr. "
    DELETE ADJACENT DUPLICATES FROM l_filtered_objects COMPARING aufnr.

    "{
    IF l_filtered_objects[] IS NOT INITIAL.
      SELECT DISTINCT aufnr
         FROM ZP_S_PROCORD_FLT1
      FOR ALL ENTRIES IN   @l_filtered_objects
      WHERE (lv_object_filter)
      AND (lt_external_filter)
      AND aufnr = @l_filtered_objects-aufnr                     "

      " and MES eq @IV_BUSINESS_SYSTEM                          "ENRICH_FILTER "
      "INTO CORRESPONDING FIELDS OF TABLE @et_filtered_objects  "
      INTO TABLE @DATA(l_filtered_objects_2)
      .
      DATA(rc_2) = sy-subrc ##needed.
    ENDIF.
    "}


    et_filtered_objects[] = l_filtered_objects_2[].


    IF rc1 NE 0 AND rc2 NE 0.
      io_bal->add_msg( iv_msgty = 'I' iv_msgid = 'ZP_DCB_PROCORD'  iv_msgno = '002' ).
      RETURN.
    ELSE.
      IF lines( et_filtered_objects ) GE c_max_rows.
        io_bal->add_msg( iv_msgty = 'W' iv_msgid = 'ZP_DCB_PROCORD'  iv_msgno = '005'  iv_msgv1 = c_max_rows ).
      ENDIF.
    ENDIF.



    "


  ENDMETHOD.
ENDCLASS.