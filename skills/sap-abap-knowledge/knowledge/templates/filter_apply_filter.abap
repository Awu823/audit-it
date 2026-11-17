*"! 模板：DRF 对象级过滤器主流程（IF_DRF_FILTER~apply_filter，脱敏）
*"! 替换占位符：<FILTER_SEL_STRUCT>/<FILTER_TABLE_TY>/<AIF_MSGID>/<C_MAX_ROWS>
*"! 依赖私有方法：get_object_filter（候选→OR 条件）、get_external_filter（外部→WHERE 表）

  METHOD if_drf_filter~apply_filter.
    CLEAR et_filtered_objects.

    " 候选对象 → selection structure 表（filter 口径，非对象键表）
    DATA(lt_key_filter) = CONV <FILTER_TABLE_TY>( it_unfiltered_objects ).

    " 对象条件 + 外部条件：并列 AND；两者都为空才提前返回（防动态 SQL 空 WHERE）
    DATA(lv_object_filter) = get_object_filter( lt_key_filter ).
    DATA(lt_external_filter) = get_external_filter( it_external_criteria ).
    IF lv_object_filter IS INITIAL
       AND lt_external_filter IS INITIAL.
      RETURN.
    ENDIF.

    " 反查目标表校验存在性 + 预查关联键（含 stlnr 等）
    DATA(lt_filtered) = VALUE <FILTER_TABLE_TY>( ).
    SELECT matnr, werks, stlan, stlal, stlnr      " 含预查列
      FROM mast
      WHERE (lv_object_filter)
        AND (lt_external_filter)
      INTO CORRESPONDING FIELDS OF TABLE @lt_filtered
      UP TO @<C_MAX_ROWS> ROWS.

    " 显式去重（候选可能重复；SORTED 表不允许 SORT，故用 STANDARD 表）
    SORT lt_filtered BY matnr werks stlan stlal.
    DELETE ADJACENT DUPLICATES FROM lt_filtered
      COMPARING matnr werks stlan stlal.

    et_filtered_objects = lt_filtered.

    " 达量级上限告警
    IF lines( et_filtered_objects ) >= <C_MAX_ROWS>
       AND io_bal IS BOUND.
      io_bal->add_msg(
        iv_msgty = if_drf_const=>msg_type_warning
        iv_msgid = '<AIF_MSGID>'
        iv_msgno = '001'
        iv_msgv1 = |{ <C_MAX_ROWS> }| ).
    ENDIF.
  ENDMETHOD.
