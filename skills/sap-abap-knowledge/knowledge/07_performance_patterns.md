# 07 · 性能优化模式

> 沉淀自 BOM 出站的性能优化实战（本次改造核心成果）。
> 四个可复用的数据库访问优化模式 + 若干配套细节。

## 模式 P1：N+1 查询 → 批量预加载

**问题**：循环内每对象一次 `SELECT SINGLE`（如 ECN 校验），1000 对象 = 1000 次查询。

**解法**：循环外一次批量 `SELECT ... FOR ALL ENTRIES` 预加载到内存表，循环内只做 `READ TABLE` 内存查找。

```abap
" 循环外：一次批量预加载
DATA(<status_tab>) = VALUE <ECN_STATUS_TY>( ).
IF <ecn_set> IS NOT INITIAL.
  SELECT aennr, aenst FROM aenr
    INTO CORRESPONDING FIELDS OF TABLE @<status_tab>
    FOR ALL ENTRIES IN @<ecn_set>
    WHERE aennr = @<ecn_set>-table_line.
ENDIF.

" 循环内：纯内存校验（READ TABLE ... WITH KEY，O(log n)）
LOOP AT keys INTO key.
  IF key-aennr IS NOT INITIAL
     AND is_ecn_valid( iv_aennr = key-aennr
                       it_aenr_status = <status_tab> ) = abap_true.
    INSERT key INTO TABLE keys_valid.
  ENDIF.
ENDLOOP.
```

**效果**：1000 对象 1000 次查询 → **1 次**（-99.9%）。

## 模式 P2a：双重查询统一

**问题**：同一数据源被两条路径重复查询。BOM 场景：
- MAST 变更指针（`mast_cp_keys`）先查 `stlnr`；
- 再按 `stlnr` 二次反查 MAST 四列（`mast_lookup`）；
- 两次 MAST 查询。

**解法**：MAST CP 反查**一次拿全 5 列（含 `stlnr`）**；仅对 STKO/STPO CP 专属的 `stlnr` 单独反查，合并后 `SORT` + `DELETE ADJACENT DUPLICATES` 去重。

```abap
" MAST CP：一次拿全 5 列（含 stlnr），避免二次反查
SELECT matnr, stlan, werks, stlal, stlnr
  FROM mast INTO CORRESPONDING FIELDS OF TABLE @<mast_all>
  FOR ALL ENTRIES IN @<mast_cp_keys> WHERE <4 列匹配>.

" STKO/STPO CP：专属 stlnr 单独反查（仅此路径需要）
SELECT matnr, stlan, werks, stlal, stlnr
  FROM mast INTO CORRESPONDING FIELDS OF TABLE @<stko_stpo_mast>
  WHERE stlnr IN @<stko_stpo_range>.
APPEND LINES OF <stko_stpo_mast> TO <mast_all>.

" 去重：同一 stlnr 可能同时命中 MAST CP 与 STKO/STPO CP
SORT <mast_all> BY matnr werks stlan stlal stlnr.
DELETE ADJACENT DUPLICATES FROM <mast_all> COMPARING matnr werks stlan stlal stlnr.
```

**效果**：MAST-CP-only 场景省 1 次 MAST FAE 查询。

## 模式 P2b：冗余查询移除 + 简化映射

**问题**：取数阶段查了 AENR（`aenr_list`），映射阶段又用 `aenr_list` 兜底回填 `change_no`——AENR 查询实际冗余。

**解法**：AENR 主键 = `AENNR`，STKO 引用之，**同值**。因此 `change_no` 直接 = `STKO-AENNR`，移除 AENR 查询与兜底逻辑。

```abap
cs_bom-change_no = is_stko-aennr.   " AENR 主键=AENNR，STKO 引用同值，无需再查 AENR
```

**效果**：省 1 次 AENR FAE 查询 + 简化映射逻辑。

## 配套细节（每个模式都需遵守）

### FAE 空守卫（必查）
`FOR ALL ENTRIES IN @itab` 中 **`itab` 为空会匹配全表**。必须 `IF <itab> IS NOT INITIAL` 再 SELECT。

```abap
IF <itab> IS NOT INITIAL.        " 空守卫：否则匹配全表，误取所有数据
  SELECT ... FOR ALL ENTRIES IN @<itab> WHERE ...
ENDIF.
```

### 去重（`SORTED` 表 + `UNIQUE KEY table_line`）
收集去重键时用 `SORTED TABLE OF <elem> WITH UNIQUE KEY table_line`，天然去重（`INSERT ... INTO TABLE` 自动去重）。

```abap
DATA(<dedup_set>) = VALUE <ECN_KEY_TY>( ).   " SORTED TABLE OF aennr WITH UNIQUE KEY table_line
LOOP AT keys INTO key.
  IF key-aennr IS NOT INITIAL.
    INSERT key-aennr INTO TABLE <dedup_set>.   " 自动去重
  ENDIF.
ENDLOOP.
```

### 排序 + 二分查找（BINARY SEARCH）
循环内按键查内存表时，先 `SORT` 目标表再 `READ TABLE ... WITH KEY ... BINARY SEARCH`，或直接建 SORTED 表用唯一键查找。

```abap
SORT <stko_lookup> BY STLNR.
READ TABLE <stko_lookup> INTO DATA(<stko_line>) WITH KEY stlnr = <mast_line>-stlnr BINARY SEARCH.
```

> 注：SORTED 表（含唯一键）用 `READ TABLE ... WITH KEY <unique_key>` 走哈希/树查找，无需显式 BINARY SEARCH；STANDARD 表需先 SORT 再 BINARY SEARCH。

### 单层键查找替代嵌套循环
原先"外层 LOOP MAST + 内层 LOOP STKO ... WHERE ... EXIT"是 O(n×m)；改为**一次批量 SELECT STKO → 内存表 → 单层 `READ TABLE ... WITH KEY stlnr`**（O(n log m)），语义等价（取每个 STLNR 首条 STKO 头）。

## 性能验证要点

- 用 `ST05`（SQL 跟踪）对比优化前后：SELECT 次数、单条耗时、总耗时。
- 关键指标：**SELECT 语句数量**（而非仅耗时），批量预加载后应接近常数。
- 行为等价性：优化必须**不改消息结果**，只消除冗余查询（改后跑 DRF 对比前后输出）。
