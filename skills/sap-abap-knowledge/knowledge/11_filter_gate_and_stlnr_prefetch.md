# 11 · filter 门控与 stlnr 预取：read_complete_data 取数前置模式

> 沉淀自 BOM 出站 `read_complete_data` 的取数前置改造。核心结论：
> **filter（`IF_DRF_FILTER~APPLY_FILTER`）是 DRF 出站的门控，必跑；`et_filtered_objects` 为空则 impl 根本不会被调到 `read_complete_data`。**
> 因此 biz 不该用"内容扫描探测 filter 是否跑过"来分支取数路径，而应按 runmod 判断：
> 正常 runmod 框架已调 filter（stlnr 已预取进对象键），`RUNMOD_BYPASS_FILTER` 时自行调 `apply_filter` 补上——之后无条件用对象键里的 stlnr，不再重查 MAST。

## 适用场景

- 实现 `IF_DRF_OUTBOUND~read_complete_data` 时，需要从对象键取一个**非键字段**（如 BOM 的 stlnr），该字段由 filter 预查注入。
- 想知道"filter 到底跑没跑、预查字段在不在对象键里"。
- 对齐在产参考实现 `CL_P_DCB_DRF_PROCORD_OUT~read_complete_data` 的 runmod 兜底写法。

## 框架事实（必须先厘清）

### 1. filter 是门控，必跑

DRF 出站生命周期：

```
analyze_changes_*  →  enrich_filter_criteria  →  apply_filter(IF_DRF_FILTER)
                   →  read_complete_data      →  map_data2message
                   →  send_message            →  finalize
```

- `apply_filter` 在 `read_complete_data` **之前**执行。
- `et_filtered_objects` 为空 → `CL_DRF_OUTBOUND` 的 `<lt_relevant_objects>` 为空 → impl 的 `read_complete_data` / `map_data2message` 不会被调到。
- 所以**能进 `read_complete_data`，意味着 filter 已产出了非空结果集**。

> **不存在"filter 没跑"的执行态。** 唯一的变量是"按条件筛 vs 全量过"——两种情况下 filter 都跑了，都产出了结果。

### 2. 预查字段由 filter 注入，同名回填进对象键

以 BOM 的 stlnr 为例。filter 的 `apply_filter` 做 `SELECT matnr, werks, stlan, stlal, stlnr FROM mast`，输出 `et_filtered_objects`。框架按**同名字段映射**把 filter 输出回填进对象键：

| 阶段 | stlty/aennr | stlnr |
|---|---|---|
| analyze（CP / others） | ✅ 从 STKO 取 | ❌ 不赋值 |
| filter（必跑）MAST SELECT → 同名回填 | 可能为空（filter 结构无这两列） | ✅ 注入 |
| read_complete_data 收到 ct_relevant_objects | 可能为空 | ✅ 一定存在 |

所以正常 runmod 下，到 `read_complete_data` 时 stlnr **必然在对象键里**。

### 3. 唯一例外：RUNMOD_BYPASS_FILTER

`if_drf_const=>runmod_bypass_filter`：框架**跳过** `apply_filter`。此时 `ct_relevant_objects` 直接来自 analyze（有 stlty/aennr，无 stlnr）。

参考实现 `CL_P_DCB_DRF_PROCORD_OUT~read_complete_data` 的兜底写法：

```abap
IF ms_runtime_parameter_ext-runmod <> if_drf_const=>runmod_bypass_filter.
  " 框架已调过 filter（含外部条件）→ 无需再过滤
ELSE.
  " 框架跳过了 filter → 自己调 apply_filter（it_external_criteria 必须为空，runmod 规定）
  get_procord_filter( )->apply_filter(
    EXPORTING ... it_external_criteria = VALUE #( ) ... ).
  ct_relevant_objects = lt_filtered_object.
ENDIF.
```

## 正确模式：runmod 判断 + 无条件用预取字段

```abap
METHOD read_complete_data.
  ...
  IF ct_relevant_objects IS NOT INITIAL.
    " bypass_filter 时自行调 apply_filter 补上预查字段
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
          it_external_criteria  = VALUE #( )   " runmod 规定必须为空
        IMPORTING
          et_filtered_objects   = lt_filtered ).
      ct_relevant_objects = lt_filtered.
    ENDIF.

    " 预查字段此刻必然已在对象键里，直接用，不重查源表
    LOOP AT ct_relevant_objects INTO DATA(ls_bom_key).
      DATA(ls_mast) = CORRESPONDING mast( ls_bom_key ).
      APPEND ls_mast TO mast_list.
      INSERT ls_bom_key-stlnr INTO TABLE bom_number_set.
    ENDLOOP.
    ...
ENDMETHOD.

METHOD get_bom_filter.
  IF mo_bom_filter IS NOT BOUND.
    mo_bom_filter = NEW <CL_FILTER>( ).
  ENDIF.
  ro_bom_filter = mo_bom_filter.
ENDMETHOD.
```

配套：类私有段持有 filter 引用，懒加载：

```abap
DATA mo_bom_filter TYPE REF TO if_drf_filter.
METHODS get_bom_filter RETURNING VALUE(ro_bom_filter) TYPE REF TO if_drf_filter.
```

## 反模式与误区（踩过的坑）

### ❌ 反模式 1：内容扫描探测 filter 是否跑过

```abap
" 反例：扫描对象键预查字段是否非空来判别 filter 是否预取
DATA(lv_prefetched) = abap_false.
LOOP AT ct_relevant_objects INTO DATA(bom_key_check).
  IF bom_key_check-stlnr IS NOT INITIAL.
    lv_prefetched = abap_true. EXIT.
  ENDIF.
ENDLOOP.
IF lv_prefetched = abap_true.
  " Path A: 用预取字段
ELSE.
  " Path B: 重查源表
ENDIF.
```

**问题**：

- 前提错误——filter 必跑，预取字段在正常 runmod 下一定在对象键里，"Path B"几乎不会触发。
- 即使 `bypass_filter`，正确做法是自行调 `apply_filter`（补上预取字段），而不是重查源表。
- 引入双路径 + 长篇注释解释"为何不能用 runmod 替代"，实际 runmod 才是正解。
- Path B 重查源表 = 把 filter 已取过的字段又查一遍，冗余。

### ❌ 反模式 2：always 重查源表（基于"filter 可能没跑"的错误前提）

```abap
" 反例：不管 filter 跑没跑，一律 INNER JOIN @ct_relevant_objects 查源表取预取字段
SELECT ... FROM mast INNER JOIN @ct_relevant_objects ... INTO TABLE @mast_list.
```

**问题**：功能上没错（能拿到正确值），但前提错误——filter 必跑、预取字段必在对象键里，重查是白查一次。且与参考实现的 runmod 模式不一致。

### ❌ 误区 1：担心"手动 apply_filter 整表替换会丢 stlty/aennr"

filter 输出结构（如 `ZMCN_BOM_DRF_FLTR_S`）只有 matnr/werks/stlan/stlal/stlnr，**没有 stlty/aennr**。整表替换 `ct_relevant_objects = lt_filtered` 后这两列为空。

**但这不是问题**：`map_data2message` 已有 stlty 为空的兜底分支（按 stlnr 唯一匹配 STKO 头）：

```abap
IF <bom_key>-stlty IS NOT INITIAL.
  READ TABLE stko_list WITH KEY stlnr = ... stlty = ... aennr = ... ...
ELSE.
  " filter 预取路径：stlty 为空，按 stlnr 唯一匹配 BOM 头
  READ TABLE stko_list WITH KEY stlnr = ... ...
ENDIF.
```

只要下游有 stlnr-only 的兜底匹配，整表替换就成立（与参考实现一致）。

### ❌ 误区 2：MAST 主键是 5 列（含 stlnr）

filter 类注释里曾写"the actual MAST key is matnr/werks/stlan/stlal/stlnr, five columns"——**这是笔误**。

**MAST 的 DDIC 主键是 4 列**：`MANDT + MATNR + WERKS + STLAN + STLAL`。stlnr 是非键字段（BOM 号，MAST 行指向它）。一个 4 列键在 MAST 里只有一行、一个 stlnr。

filter 自己的代码也印证：`SORT ... BY matnr werks stlan stlal` + `DELETE ADJACENT DUPLICATES COMPARING matnr werks stlan stlal`（按 4 列去重）。

> 这个事实是"Path A（用预取 stlnr）≡ Path B（查 MAST 取 stlnr）"的根基：4 列键唯一 stlnr，两路必然同值。但既然 filter 已预取，就该用预取值，不必走 Path B。

## 决策推演（为什么是 runmod + Path A）

| 方案 | 正常 runmod | bypass_filter | 评价 |
|---|---|---|---|
| 内容扫描 + Path A/B（原实现） | stlnr 在 → Path A | stlnr 缺 → Path B 重查 | 前提错（以为 filter 可能没跑）；双路径冗余 |
| always Path B（重查源表） | ✅ 但白查一次 | ✅ | 功能对，前提错，与参考不一致 |
| always Path A（用预取字段） | ✅ | ❌ stlnr 缺 → 丢数据 | bypass_filter 下会坏 |
| **runmod 判断 + Path A（本模式）** | ✅ 框架已预取 | ✅ 自行 apply_filter 补上 | 对齐参考，无冗余，全覆盖 |

## 自查清单

实现 `read_complete_data` 取数前置时对照：

- [ ] 是否需要从对象键取一个 filter 预查注入的非键字段（如 stlnr）？
- [ ] 该字段在正常 runmod 下是否一定在对象键里？（filter 的 SELECT 是否含该字段？）
- [ ] `RUNMOD_BYPASS_FILTER` 时是否自行调了 `apply_filter`？（对齐参考实现）
- [ ] 是否避免了"内容扫描探测 filter 是否跑过"的反模式？
- [ ] 是否避免了"无脑重查源表"的冗余？
- [ ] filter 输出结构缺少的字段（如 stlty/aennr），下游 `map_data2message` 是否有兜底分支？
- [ ] filter 引用是否懒加载（`IF mo_filter IS NOT BOUND`）？

## 关联文档

- [04_filter_object_level.md](04_filter_object_level.md) — filter 的动态 SQL / 存在性校验 / stlnr 预查实现
- [09_drf_framework_contract.md](09_drf_framework_contract.md) — `IF_DRF_FILTER` 精确签名、runmod 常量
- [02_drf_lifecycle_and_object_keys.md](02_drf_lifecycle_and_object_keys.md) — 生命周期方法顺序
- [references/CL_P_DCB_DRF_PROCORD_OUT.abap](references/) — 在产参考实现的 runmod 兜底写法
