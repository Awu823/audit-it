*"! 模板：ECN 状态批量预加载 + 内存校验（消除 N+1，脱敏）
*"! 替换占位符：<ECN_STATUS_TY>/<ECN_KEY_TY>/<KEYS>/<KEY>/<KEYS_VALID>/<ECN_FILTERED_CNT>
*"! 依赖类型：<ECN_STATUS_TY>（SORTED TABLE OF ecn_status_ty）、<ECN_KEY_TY>（SORTED TABLE OF aennr）

    " 1) 收集去重 AENNR（SORTED 表自动去重）
    DATA(<ecn_set>) = VALUE <ECN_KEY_TY>( ).
    LOOP AT <KEYS> INTO <KEY>.
      IF <KEY>-aennr IS NOT INITIAL.
        INSERT <KEY>-aennr INTO TABLE <ecn_set>.
      ENDIF.
    ENDLOOP.

    " 2) 批量预加载 AENR 状态（FAE 空守卫）
    DATA(<lt_aenr_status>) = VALUE <ECN_STATUS_TY>( ).
    IF <ecn_set> IS NOT INITIAL.
      SELECT aennr, aenst FROM aenr
        INTO CORRESPONDING FIELDS OF TABLE @<lt_aenr_status>
        FOR ALL ENTRIES IN @<ecn_set>
        WHERE aennr = @<ecn_set>-table_line.
    ENDIF.

    " 3) 循环内内存校验（替代每对象 SELECT SINGLE）
    DATA(<keys_valid>) = VALUE <KEY_TABLE_TY>( ).
    LOOP AT <KEYS> INTO <KEY>.
      IF <KEY>-aennr IS NOT INITIAL
         AND is_ecn_valid( iv_aennr = <KEY>-aennr
                           it_aenr_status = <lt_aenr_status> ) = abap_true.
        INSERT <KEY> INTO TABLE <keys_valid>.
      ELSE.
        <ECN_FILTERED_CNT> = <ECN_FILTERED_CNT> + 1.   " 统计被过滤对象数
      ENDIF.
    ENDLOOP.
    et_changed_objects = <keys_valid>.

" ---------------------------------------------------------------
" is_ecn_valid 实现（内存校验，参数 it_aenr_status TYPE <ECN_STATUS_TY>）
" ---------------------------------------------------------------
  METHOD is_ecn_valid.
    rv_valid = abap_false.
    IF iv_aennr IS INITIAL.
      RETURN.
    ENDIF.
    READ TABLE it_aenr_status WITH KEY aennr = iv_aennr INTO DATA(status_line).
    IF sy-subrc <> 0.
      rv_valid = abap_false.      " AENR 无记录：ECN 不存在
      RETURN.
    ENDIF.
    IF status_line-aenst IS INITIAL.
      rv_valid = abap_false.      " AENST 空：未赋状态
    ELSEIF status_line-aenst = gc_ecn_status_released.   " '2' = Released
      rv_valid = abap_true.
    ELSE.
      rv_valid = abap_false.
    ENDIF.
  ENDMETHOD.
