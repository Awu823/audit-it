*"! <p class="shorttext synchronized">DRF BOM 出站：对象级过滤器（S4H → ECMS）</p>
*"!
*"! 该类实现 IF_DRF_FILTER，用于对象级相关性过滤：
*"! ① 按 BOM selection structure（ZMCN_BOM_DRF_FLTR_S，matnr/werks/stlan/stlal）动态拼 WHERE 条件；
*"! ② 与外部条件（rsds_trange，filter selection structure 口径）并列 AND 合并；
*"! ③ 反查 MAST 校验 BOM 链接是否存在，仅保留真实存在的 BOM 链接。
*"! 对应 FS：BOM SAP to ECMS interface (ZCN_ECMS / ZDCN_PBOM)
*"! 参考在产：/RGS/CL_P_DCB_DRF_PROCORD_FLTR（生产订单→MES 对象级过滤）
CLASS zcl_mit_dcn_drf_bom_out_fltr DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    INTERFACES if_drf_filter.

  PRIVATE SECTION.

    CONSTANTS c_max_rows TYPE i VALUE 5000 ##NO_TEXT.

    " Filter selection structure（对齐在产 /RGS/P_DCB_PO_DRF_FLTR_S 的做法）：
    " it_unfiltered_objects / it_external_criteria 的行类型均为 filter 的 selection structure，
    " 不是出站实现的对象键表（key_table_ty）。filter 输入/输出都在此 structure 口径上工作。
    TYPES filter_struct_ty TYPE ZMCN_BOM_DRF_FLTR_S.
    " 用 STANDARD 表而非 SORTED：MAST 四列（matnr/werks/stlan/stlal）可重复
    " （MAST 主键实为 matnr/werks/stlan/stlal/stlnr 五列），需 SORT + DELETE ADJACENT
    " DUPLICATES 显式去重（对齐在产 L367-368 的做法）；SORTED 表不允许 SORT 命令。
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
    " 单字段 → 动态条件片段：含通配符（* +）用 LIKE（转义 % _），否则用 EQ。
    " 通配符转义继承在产行为（*→%、+→_）；输入本身的字面 % 或 _ 不会转义，会在 LIKE 中当通配符。
    " 属已知边界，与在产一致；BOM 键值（matnr/werks/stlan/stlal）不含字面 %/_，不受影响。
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
    " BOM 键 → AND 条件片段。
    " 注：MAST 反查仅需 matnr/werks/stlan/stlal（MAST 主键顺序）；
    "     stlty/aennr 由 STKO 提供、MAST 无此二字段，不参与 MAST 过滤条件。
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
    " 候选对象（已 CONV 的 filter_table_ty）→ OR 条件（每个 BOM 链接一行条件）。
    " 注：调用方已把 it_unfiltered_objects 统一 CONV 为 lt_key_filter 再传入，
    "     此处直接接收，不再重复 CONV（消除同一输入的两次转换）。
    LOOP AT it_key_filter INTO DATA(ls_key_filter).
      DATA(lv_line_cond) = get_condition_for_filter_line(
        is_key_filter = ls_key_filter ).
      IF lv_line_cond IS NOT INITIAL.
        " 仅当该行确实产生条件时才追加 OR，避免 BOM 键整行全空时留下悬空 "OR"。
        IF rv_result IS NOT INITIAL.
          rv_result = rv_result && | OR |.
        ENDIF.
        rv_result = rv_result && |( | && lv_line_cond && | )|.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD get_external_filter.
    " 外部条件（rsds_trange）→ WHERE 表。
    " 注：FREE_SELECTIONS_RANGE_2_WHERE 生成的 where_clauses 中 tablename 指向
    "     filter 的 selection structure（对齐在产 '/RGS/P_DCB_PO_DRF_FLTR_S'），
    "     不是数据库表名。此处取 ZMCN_BOM_DRF_FLTR_S 对应片段，其字段名
    "     （matnr/werks/stlan/stlal）与 MAST 列名一致，可直接拼入 MAST SELECT。
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
    " 对象级相关性过滤：仅保留 MAST 中真实存在的 BOM 链接。
    " 与在产 /RGS/CL_P_DCB_DRF_PROCORD_FLTR 同构，但过滤依据从"订单过滤表"
    " 换成"MAST 存在性校验"——BOM 无独立过滤表，对象键即 MAST 主键。

    CLEAR et_filtered_objects.

    " --- DRFOUT 授权检查（BOM 决策：不落地；如需启用，定义 BOM 专属 auth object 后放开） ---
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

    " 候选对象 → selection structure 表（filter 口径，非对象键表）。
    " 仅用于生成对象 OR 条件（lv_object_filter）驱动 SELECT；不作输出回流。
    DATA(lt_key_filter) = CONV filter_table_ty( it_unfiltered_objects ).

    " 对象条件 + 外部条件（仅 MAST）—— 两者是并列的 AND 条件（对齐在产）：
    " 单独任一为空都不中断，空条件在动态 WHERE 中自然失效，另一条件照常生效。
    " 仅当两者都为空（无任何过滤依据）才提前返回，避免动态 SQL 空 WHERE 报错/全表。
    DATA(lv_object_filter) = get_object_filter( lt_key_filter ).
    DATA(lt_external_filter) = get_external_filter( it_external_criteria ).
    IF lv_object_filter IS INITIAL
       AND lt_external_filter IS INITIAL.
      RETURN.
    ENDIF.

    " 反查 MAST 校验 BOM 链接存在（matnr+werks+stlan+stlal 四列，MAST 主键）。
    " WHERE 用候选 OR 条件（lv_object_filter）+ 外部条件并列 AND；
    " 结果 lt_filtered 已是"候选 ∩ MAST 存在 ∩ 外部条件"，直接作为过滤输出。
    " （候选已通过 lv_object_filter 参与 SELECT，无需再 LOOP 候选回流匹配。）
    " 日期筛选（STKO-DATUV/DATUB）有意不在此过滤器——selection structure
    " ZMCN_BOM_DRF_FLTR_S 只含 MAST 列（matnr/werks/stlan/stlal/stlnr），MAST 无日期列。
    " 生效日期由 biz 层强制：read_complete_data 读 STKO 时带
    " `datuv IN @mt_stko_datuv AND valid_to IN @mt_stko_datub`（enrich_filter_criteria 解析屏幕范围）。
    " 此处勿加日期条件。
    DATA(lt_filtered) = VALUE filter_table_ty( ).
    SELECT matnr, werks, stlan, stlal, stlnr
      FROM mast
      WHERE (lv_object_filter)
        AND (lt_external_filter)
      INTO CORRESPONDING FIELDS OF TABLE @lt_filtered
      UP TO @c_max_rows ROWS.

    " 按 MAST 主键排序去重（显式去重，保证 et_filtered_objects 无重复链接）。
    " 去重按 MAST 4 列（matnr/werks/stlan/stlal）比较，每个键保留首条 stlnr。
    " 安全前提：STLAL 决定 BOM 号，故 (matnr,werks,stlan,stlal) 在 MAST 中映射到唯一 STLNR。
    " 若未来出现"同 4 列多 MAST"场景，去重须加入 stlnr。
    SORT lt_filtered BY matnr werks stlan stlal.
    DELETE ADJACENT DUPLICATES FROM lt_filtered
      COMPARING matnr werks stlan stlal.

    et_filtered_objects = CORRESPONDING #( lt_filtered ).

    " 达到量级上限时写告警（对齐在产 c_max_rows 告警行为）
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
