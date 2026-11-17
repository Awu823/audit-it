# 02 · DRF 出站生命周期与对象键

> 沉淀自 BOM 出站。涵盖 `IF_DRF_OUTBOUND` 生命周期方法、对象键表类型、变更指针 `CDOBJID` 解析。
> BOM 表关联细节见 [03](03_bom_data_model_and_mapping.md)。

## 对象键结构（`bom_key_ty`）

```abap
TYPES:
  BEGIN OF <KEY_STRUCT>,
    stlan TYPE stlan,   " BOM usage（用途）
    werks TYPE werks_d, " Plant（工厂）
    matnr TYPE matnr,   " Material（物料）
    stlal TYPE stlal,   " Alternative BOM（备选 BOM）
    stlty TYPE stlty,   " BOM Category（BOM 类别）
    aennr TYPE aennr,   " ECN（工程变更号）
    stlnr TYPE stnum,   " BOM 号（filter 预查数据，非键字段）
  END OF <KEY_STRUCT>,
  <KEY_TABLE_TY> TYPE SORTED TABLE OF <KEY_STRUCT>
    WITH UNIQUE KEY stlan werks matnr stlal stlty aennr.
```

### 关键设计点

- **唯一键 = `stlan werks matnr stlal stlty aennr`**（MAST 主键 + STKO 的 STLTY/AENNR）。
- **`stlnr` 是"非键字段"**：BOM 号（STLNR）由 filter 预查得到，随对象键传递，避免 biz 再反查 MAST（性能优化点，见 [07](07_performance_patterns.md)）。
- `stlty`/`aennr` 在 **filter 预查路径下为空**（filter 只输出 matnr/werks/stlan/stlal/stlnr），biz 需兼容：
  - 用 `stlnr` 匹配 STKO 时，若 `stlty` 为空则按 `stlnr` 匹配唯一 BOM 头；
  - STPO 过滤用的 `stlty` 从已命中的 STKO 取实际值。

## 生命周期方法（`IF_DRF_OUTBOUND`）

| 方法 | 职责 | 要点 |
|---|---|---|
| `initialize` | 创建 biz 单例、设 `table_type_name`、`package_size` | 见 [01](01_drf_outbound_architecture.md) |
| `analyze_changes_by_chg_pointer` | **变更指针模式**：解析 DRF_T_BDCP → 变更对象键 | CDOBJID 偏移解析（见下） |
| `analyze_changes_by_others` | **初始/手动**：按默认/外部条件批量取变更对象 | 量级上限控制 |
| `enrich_filter_criteria` | 追加外部过滤条件 | 通常转发外部条件 |
| `read_complete_data` | **批量取数**：MAST/STKO/STPO/MARA → 内存表 | 去重 + FAE 批量查询 |
| `map_data2message` | 单对象 → 消息结构 | 每对象一次，产出 header+items |
| `send_data` / `send_message` | **AIF 发送** | 见 [06](06_aif_send.md) |
| `finalize` | 收尾（是否删变更指针） | `ev_delete_change_pointer` |

## 变更指针 CDOBJID 解析

`DRF_T_BDCP` 的 `CDOBJID` 是对象主键字段**按表主键顺序拼接**的字符串。BOM 主键长度（DDIC）：

```
MAST 主键：MATNR(18) + WERKS(4) + STLAN(1) + STLAL(2)     → CDOBJID 偏移 0/18/22/23
STKO 主键：STLTY(1)  + STLNR(8)                            → CDOBJID 偏移 0/1
STPO 主键：STLTY(1)  + STLNR(8) + POSNR(6)                 → CDOBJID 偏移 0/1/9
```

```abap
" 偏移必须为字面量（ABAP source+off(len) 的 off 仅允许字面量，len 可引用常量）
CONSTANTS: gc_len_matnr TYPE i VALUE 18, gc_len_werks TYPE i VALUE 4,
           gc_len_stlan TYPE i VALUE 1,  gc_len_stlal TYPE i VALUE 2,
           gc_len_stlnr TYPE i VALUE 8.

" MAST 变更指针 → 对象键（CDOBJID 按 MATNR+WERKS+STLAN+STLAL 拼接）
INSERT VALUE <MAST_CP_KEY>(
  matnr = <cp>-cdobjid+0(gc_len_matnr)
  werks = <cp>-cdobjid+18(gc_len_werks)
  stlan = <cp>-cdobjid+22(gc_len_stlan)
  stlal = <cp>-cdobjid+23(gc_len_stlal) ) INTO TABLE <mast_cp_keys>.

" STKO / STPO 变更指针 → BOM 号（对象级触发，CDOBJID 第 1 字节起 8 位 = STLNR）
"   DRF_T_BDCP 不含字段级信息，无法区分具体字段，按对象级处理
INSERT VALUE #( sign = 'I' option = 'EQ' low = <cp>-cdobjid+1(gc_len_stlnr) )
  INTO TABLE <stko_stpo_range>.
```

### 关键点

1. **`off` 只能字面量、`len` 可引用常量**——因此把主键长度定义为常量（`gc_len_*`），偏移写死（0/18/22/23）。
2. **STKO/STPO 是对象级触发**：`DRF_T_BDCP` 不携带字段级信息，只能按对象处理，无法精确到某字段变更。
3. **`STLNR` 定位**：STKO/STPO 的 `CDOBJID+1(8)` 即 BOM 号，据此反查 MAST 四列（`matnr/werks/stlan/stlal`）得到完整对象键。

## 变更分析（`analyze_changes_by_chg_pointer`）流程

```
1. 遍历 change_pointer_table（WHERE tabname = 'MAST'）→ 解析 CDOBJID → mast_cp_keys
2. MAST CP 反查：一次拿全 5 列（含 stlnr）
     SELECT matnr, stlan, werks, stlal, stlnr FROM mast
       FOR ALL ENTRIES IN @mast_cp_keys WHERE <4 列匹配>
3. STKO/STPO CP：CDOBJID+1(8) → stko_stpo_range；反查 MAST 4 列（WHERE stlnr IN range）
4. 合并 mast_all（去重：SORT BY matnr werks stlan stlal stlnr + DELETE ADJACENT DUPLICATES）
5. 反查 STKO 取 STLTY/AENNR（FAE：stlnr 匹配）→ 构造对象键
6. ECN 校验（批量预加载 AENR 状态）→ 过滤未释放 ECN → et_changed_objects
```

## `analyze_changes_by_others`（初始 / 手动）

- 无变更指针时，按**默认条件**（默认工厂 `<DEFAULT_WERKS>`、默认用途 `<DEFAULT_STLAN>`）批量取 MAST。
- **量级上限**：`gc_initial_max_rows`（对齐 FS §14，如 1000）防止全量扫描超限。
- 同样走 **MAST 反查 → STKO 反查 → ECN 校验** 流水线。

## `enrich_filter_criteria`

- 接收 `it_external_criteria`（`rsds_trange`，用户在 DRF 界面输入的选择条件）。
- 通常直接 `et_add_external_criteria = it_external_criteria` 透传（框架会并入对象级过滤）。
- 无额外条件时保持空即可。

## `read_complete_data`

- **批量取数**：对全部相关对象一次性读 MAST/STKO/STPO/MARA 到内存表（`mast_list`/`stko_list`/`stpo_list`/`mara_list`），后续 `map_data2message` 只做内存查找。
- 用 **去重集 + `FOR ALL ENTRIES`** 批量查询（见 [07](07_performance_patterns.md) 的 FAE 模式）。
- **FAE 空守卫**：`FOR ALL ENTRIES IN` 空表会匹配全表——必须先 `IF <itab> IS NOT INITIAL` 再 SELECT。

## `finalize`

- 控制是否删除已处理变更指针：成功且非重复运行 → `ev_delete_change_pointer = abap_true`。
- 可在此汇总运行统计（成功/失败对象数）写日志。
