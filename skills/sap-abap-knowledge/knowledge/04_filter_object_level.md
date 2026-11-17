# 04 · 对象级过滤（`IF_DRF_FILTER`）

> 沉淀自 BOM 出站的对象级过滤器。核心：**动态拼 WHERE（含通配符）+ 反查存在性校验 + 预查 stlnr**。

## 角色与输入输出

- 实现 `IF_DRF_FILTER`，在 DRF 配置中作为**对象级过滤器**挂载。
- 输入：`it_unfiltered_objects`（候选对象，行类型 = **filter 的 selection structure**，非对象键表）、`it_external_criteria`（`rsds_trange`，界面选择条件）、`iv_appl`/`iv_outb_impl`/`iv_business_system`（用于授权检查）。
- 输出：`et_filtered_objects`（过滤后对象，**同一 selection structure 口径**）。

> **重要**：filter 的输入/输出是 **filter selection structure**（如 `<FILTER_SEL_STRUCT>`），
> 不是出站实现的对象键表（`<KEY_TABLE_TY>`）。filter 的字段名与目标表列名一致时可直接拼 SQL。

## 类型

```abap
" 用 STANDARD 表而非 SORTED：目标表主键多列可重复（如 MAST 五列），
" 需 SORT + DELETE ADJACENT DUPLICATES 显式去重；SORTED 表不允许 SORT 命令。
TYPES <FILTER_TABLE_TY> TYPE STANDARD TABLE OF <FILTER_SEL_STRUCT> WITH EMPTY KEY.
CONSTANTS c_max_rows TYPE i VALUE 5000.
```

## 动态条件片段（通配符 LIKE / 精确 EQ）

```abap
METHOD convert_field_to_condition.
  " 单字段 → 动态条件片段：含通配符（* +）用 LIKE（转义 % _），否则用 EQ
  rv_result = cl_abap_dyn_prg=>quote( iv_field_value ).   " 引号转义防注入
  IF rv_result CA '*+'.
    TRANSLATE rv_result USING '*%'.
    TRANSLATE rv_result USING '+_'.
    rv_result = |( | && iv_field_name && | LIKE | && rv_result && | )|.
  ELSE.
    rv_result = |( | && iv_field_name && | EQ | && rv_result && | )|.
  ENDIF.
ENDMETHOD.
```

- 用 `cl_abap_dyn_prg=>quote` 做引号转义，防止动态 SQL 注入。
- 通配符 `*`/`+` 转义为 `%`/`_` 后用 `LIKE`；否则 `EQ`。

## 外部条件（`rsds_trange` → WHERE 表）

```abap
CALL FUNCTION 'FREE_SELECTIONS_RANGE_2_WHERE'
  EXPORTING field_ranges  = it_external_criteria
  IMPORTING where_clauses = lt_external_where_cond.
" where_clauses 中 tablename 指向 filter 的 selection structure，不是数据库表名
READ TABLE lt_external_where_cond REFERENCE INTO DATA(lr) WITH KEY tablename = '<FILTER_SEL_STRUCT>'.
IF sy-subrc = 0.
  rt_result = lr->where_tab.   " 字段名与目标表列名一致时可并入 SELECT
ENDIF.
```

## 主流程（`apply_filter`）

```abap
METHOD if_drf_filter~apply_filter.
  CLEAR et_filtered_objects.

  " 候选对象 → selection structure 表（filter 口径）
  DATA(lt_key_filter) = CONV <FILTER_TABLE_TY>( it_unfiltered_objects ).

  " 对象条件 + 外部条件：并列 AND；两者都为空才提前返回（防动态 SQL 空 WHERE）
  DATA(lv_object_filter) = get_object_filter( lt_key_filter ).
  DATA(lt_external_filter) = get_external_filter( it_external_criteria ).
  IF lv_object_filter IS INITIAL AND lt_external_filter IS INITIAL.
    RETURN.
  ENDIF.

  " 反查目标表校验存在性 + 预查关联键（如 MAST 的 stlnr）
  DATA(lt_filtered) = VALUE <FILTER_TABLE_TY>( ).
  SELECT matnr, werks, stlan, stlal, stlnr      " 含预查列（stlnr）
    FROM mast
    WHERE (lv_object_filter)
      AND (lt_external_filter)
    INTO TABLE @lt_filtered
    UP TO @c_max_rows ROWS.

  " 显式去重（候选可能重复）
  SORT lt_filtered BY matnr werks stlan stlal.
  DELETE ADJACENT DUPLICATES FROM lt_filtered COMPARING matnr werks stlan stlal.

  et_filtered_objects = lt_filtered.

  " 达量级上限告警
  IF lines( et_filtered_objects ) >= c_max_rows AND io_bal IS BOUND.
    io_bal->add_msg( iv_msgty = if_drf_const=>msg_type_warning
                     iv_msgid = '<AIF_MSGID>' iv_msgno = '001'
                     iv_msgv1 = |{ c_max_rows }| ).
  ENDIF.
ENDMETHOD.
```

## 关键点

1. **空条件守卫**：对象条件与外部条件**都为空**才提前 `RETURN`，否则动态 WHERE 可能为空报错或全表扫描；任一为空时另一条件照常生效。
2. **存在性校验即过滤**：`SELECT ... FROM mast WHERE (对象条件) AND (外部条件)` 的结果本身已是"候选 ∩ 存在 ∩ 外部条件"，**无需再 LOOP 候选回流匹配**。
3. **预查 `stlnr`**：在 filter 阶段就查出 MAST 的 `stlnr`（BOM 号）随对象键带出，biz 的 `map_data2message` 免查 MAST（性能优化，见 [07](07_performance_patterns.md)）。biz 对象键中 `stlnr` 为**非键字段**。
4. **selection structure 口径**：filter 输入/输出行类型是 `<FILTER_SEL_STRUCT>`，字段名与目标表列一致才可直拼 SQL。
5. **授权检查**：如需 DRFOUT 授权，定义 BOM 专属 auth object 后放开 `AUTHORITY-CHECK`（`ACTVT='16'` + `DRF_APPL` + `DRF_SERV` + `DRF_RECEIV`）。
