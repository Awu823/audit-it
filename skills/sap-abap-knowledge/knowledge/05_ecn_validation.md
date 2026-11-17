# 05 · ECN 校验（工程变更）

> 沉淀自 BOM 出站。ECN（Engineering Change Number）是 BOM/主数据的生效开关：
> 仅**已释放**的 ECN 才允许出站。核心：**AENR 状态校验 + 批量预加载（消除 N+1）**。

## 校验规则（FS 语义）

- **ECN 必要条件**：所有变更类型（MAST/STKO/STPO）都需有效 ECN 才发送。
- **释放判定**：`AENR.AENST = '2'`（`'2'` = Released）。以下情况均判为**未释放**：
  - AENR 无记录（ECN 不存在）；
  - `AENST` 为空 / `'00'`（未明确赋状态）；
  - `AENST` ≠ `'2'`。
- **数据口径确认**：AENR 主键 = `MANDT+AENNR` **唯一**，状态字段 = `AENST`，**无工厂维度字段**、**无 AENNR_AUF**。因此校验就是 `AENR.AENST='2'`，无需工厂维度扩展。

## 批量预加载（消除 N+1）

最初实现是 `is_ecn_valid` 内 `SELECT SINGLE aenst FROM aenr`（每对象一次），1000 对象 = 1000 次查询。
优化为**两处 `analyze_changes` 各一次批量预加载**，循环内纯内存校验。

```abap
" 1) 收集去重 AENNR
DATA(<ecn_set>) = VALUE <ECN_KEY_TY>( ).   " SORTED TABLE OF aennr WITH UNIQUE KEY table_line
LOOP AT keys INTO key.
  IF key-aennr IS NOT INITIAL.
    INSERT key-aennr INTO TABLE <ecn_set>.
  ENDIF.
ENDLOOP.

" 2) 批量预加载 AENR 状态（aennr/aenst 两列）
DATA(<lt_aenr_status>) = VALUE <ECN_STATUS_TY>( ).   " SORTED TABLE OF ecn_status_ty WITH UNIQUE KEY aennr
IF <ecn_set> IS NOT INITIAL.                          " FAE 空守卫
  SELECT aennr, aenst FROM aenr
    INTO CORRESPONDING FIELDS OF TABLE @<lt_aenr_status>
    FOR ALL ENTRIES IN @<ecn_set>
    WHERE aennr = @<ecn_set>-table_line.
ENDIF.

" 3) 循环内内存校验（替代每对象 SELECT SINGLE）
LOOP AT keys INTO key.
  IF key-aennr IS NOT INITIAL
     AND is_ecn_valid( iv_aennr = key-aennr
                       it_aenr_status = <lt_aenr_status> ) = abap_true.
    INSERT key INTO TABLE keys_valid.
  ELSE.
    <ecn_filtered_cnt> = <ecn_filtered_cnt> + 1.   " 统计被过滤对象数，写运行日志
  ENDIF.
ENDLOOP.
et_changed_objects = keys_valid.
```

## 内存校验方法（`is_ecn_valid`）

```abap
METHOD is_ecn_valid.
  rv_valid = abap_false.
  IF iv_aennr IS INITIAL.
    RETURN.
  ENDIF.
  READ TABLE it_aenr_status WITH KEY aennr = iv_aennr INTO DATA(status_line).
  IF sy-subrc <> 0.
    rv_valid = abap_false.       " AENR 无记录：ECN 不存在
    RETURN.
  ENDIF.
  IF status_line-aenst IS INITIAL.
    rv_valid = abap_false.       " AENST 空：未赋状态
  ELSEIF status_line-aenst = gc_ecn_status_released.   " '2'
    rv_valid = abap_true.
  ELSE.
    rv_valid = abap_false.
  ENDIF.
ENDMETHOD.
```

## 类型定义（含 ADT 激活兼容注意）

```abap
TYPES:
  BEGIN OF <ECN_STATUS_TY_STRUCT>,   " ecn_status_ty
    aennr TYPE aennr,                " data element AENNR（非表 aenr 结构！）
    aenst TYPE c LENGTH 1,           " AENST 为 1 字符
  END OF <ECN_STATUS_TY_STRUCT>,
  <ECN_STATUS_TY> TYPE SORTED TABLE OF <ECN_STATUS_TY_STRUCT> WITH UNIQUE KEY aennr,  " ecn_status
  <ECN_KEY_TY>    TYPE SORTED TABLE OF aennr WITH UNIQUE KEY table_line.              " ecn_key
```

> **ADT 激活踩坑**（详见 [08](08_adt_activation_errors.md)）：
> 1. `TYPE SORTED TABLE OF aenr`（**表 aenr 结构**作行类型）→ `Unable to interpret "AENR"`。**必须用局部结构**（`aennr TYPE aennr` data element + `aenst TYPE c LENGTH 1`），不依赖表结构。
> 2. 匿名内联 `VALUE SORTED TABLE OF ...` → 不可靠。**必须单独定义命名 TYPES**（`<ECN_STATUS_TY>`/`<ECN_KEY_TY>`）再引用。
> 3. 参数名一致性：签名 `iv_aennr`，调用处必须同拼写（`iv_aenr` 会报 "formal parameter does not exist"）。

## 关键点

1. **`SELECT aennr, aenst FROM aenr`**（表查询）没问题——用 AENR 表**列名**，不依赖 `aenr` 结构作为行类型。
2. **`INTO CORRESPONDING FIELDS`** 自动映射 `AENNR→aennr`、`AENST→aenst` 到局部结构。
3. **计数 `ecn_filtered_cnt`**：便于运维在 DRF 运行日志中识别"因 ECN 被过滤"的对象。
4. `is_ecn_valid` 的 `it_aenr_status` 表需与循环外的预加载**同一表实例**（一次预加载，多次复用）。
