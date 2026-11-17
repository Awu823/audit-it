# 03 · BOM 表模型与字段映射

> 沉淀自 BOM 出站。覆盖 BOM 相关表（MAST/STKO/**STAS**/STPO/MARA/AENR）的关联关系，
> 以及把 BOM 数据映射为外部系统消息结构（header + items）的字段对照。

## 核心表与关联

| 表 | 角色 | 主键 | 本接口取用字段 |
|---|---|---|---|
| **MAST** | BOM 链接（物料 ↔ BOM 头） | `MATNR+WERKS+STLAN+STLAL+STLNR` | matnr, werks, stlan, stlal, stlnr |
| **STKO** | BOM 头（每 BOM 版本） | `STLTY+STLNR+STLAL+AENNR+DATUV` | stlty, stlnr, stlal, aennr, andat, datuv, valid_to, bmeng |
| **STAS** | **BOM 项选择（表头 ↔ 明细链接表）** | `STLTY+STLNR+STLAL+STLKN` | stlty, stlnr, stlal, stlkn |
| **STPO** | BOM 组件行 | `STLTY+STLNR+STLKN+POSNR` | stlnr, stlty, stlkn, idnrk, menge, datuv, valid_to, meins, avoau, ausch |
| **MARA** | 物料主数据 | `MATNR` | matnr, meins |
| **AENR** | 工程变更主数据 | `MANDT+AENNR` | aennr, aenst |

### 关联链

```
MATNR+WERKS+STLAN+STLAL ──MAST──> STLNR ──STKO──> STLTY/AENNR（BOM 头）
                                        │
                                        └─STAS(STLAL)→STLKN──> STPO 组件行（IDNRK/MENGE/...）
```

> **`STAS` 是表头 ↔ 明细的必备链接表**：`STPO` 本身**不含 `STLAL`**，同一 `STLNR` 下多个备选 BOM（STLAL=1/2/3…）的组件必须**经 `STAS` 按 `STLAL` 解析出 `STLKN` 节点**后才能精确定位。关联键：
> - `STKO → STAS`：`STLTY + STLNR + STLAL`
> - `STAS → STPO`：`STLTY + STLNR + STLKN`

- **MAST 无 STLTY/AENNR**——这两字段由 **STKO** 提供（MAST 只有四列 + STLNR）。
- **`STAS` 必备**：`STPO` 无 `STLAL`，表头↔明细必须经 `STAS`（按 `STLAL` 解析 `STLKN`）；**仅按 `STLNR` 关联 STPO 会把多备选（STLAL）/多版本（AENNR）的组件混入**。
- **AENR 主键 = MANDT + AENNR**，**状态字段 = AENST**，**无工厂维度字段**、**无 AENNR_AUF**（曾误记为 `MAENR.AENST_M`，实为笔误）。
- STKO **无 DATUB** 字段，有效结束日期用 **`valid_to`**（类型 DATUB）。
- 组件损耗/工序损耗：`STPO-AUSCH`（组件，类型 KAUSF）/ `STPO-AVOAU`（工序），二者独立列。

## 消息结构（`<CL_BIZ>` 内定义，header + items）

```abap
TYPES:
  BEGIN OF <HEADER_TY>,
    cop_exg_no        TYPE matnr,    " ID01 物料
    bom_creation      TYPE datuv,    " ID06 BOM 创建
    alternative_bom   TYPE stlal,    " ID07 备选 BOM
    bom_no            TYPE stnum,    " ID08 BOM 编号
    change_no         TYPE aennr,    " ID09 ECN
    bom_usage         TYPE stlan,    " ID10 BOM 用途
    header_start_date TYPE datuv,    " ID11 Header 生效开始
    header_end_date   TYPE datub,    " ID12 Header 生效结束
    header_qty        TYPE bmenge,   " ID13 Header 数量
    header_unit       TYPE meins,    " ID14 Header UoM
  END OF <HEADER_TY>,
  BEGIN OF <ITEM_TY>,
    cop_img_no      TYPE idnrk,      " ID02 组件物料
    quantity        TYPE kmpmg,      " ID03 组件数量
    valid_from      TYPE datuv,      " ID04 组件生效开始
    valid_to        TYPE datub,      " ID05 组件生效结束
    component_unit  TYPE meins,      " ID15 组件 UoM
    operation_scrap TYPE ausch,      " ID16 工序损耗
    component_scrap TYPE ausch,      " ID17 组件损耗
  END OF <ITEM_TY>,
  <ITEMS_TY> TYPE STANDARD TABLE OF <ITEM_TY> WITH EMPTY KEY,
  BEGIN OF <MESSAGE_TY>,
    header TYPE <HEADER_TY>,
    items  TYPE <ITEMS_TY>,
  END OF <MESSAGE_TY>.
```

## 字段映射（FS 约定 ID 字段 → 消息字段 → 数据来源）

### Header（`map_bom_header`）
| ID | 消息字段 | 来源 | 备注 |
|---|---|---|---|
| ID01 | `cop_exg_no` | MAST-MATNR | Header 物料（M 必填）|
| ID06 | `bom_creation` | STKO-ANDAT | BOM 创建日期 |
| ID07 | `alternative_bom` | MAST-STLAL | 备选 BOM |
| ID08 | `bom_no` | MAST-STLNR | BOM 编号 |
| ID09 | `change_no` | STKO-AENNR | ECN（AENR 主键=AENNR，STKO 引用同值）|
| ID10 | `bom_usage` | MAST-STLAN | BOM 用途 |
| ID11 | `header_start_date` | STKO-DATUV | 未来生效：直接透传，> sy-datum 即隐含"未来生效" |
| ID12 | `header_end_date` | STKO-valid_to | STKO 无 DATUB |
| ID13 | `header_qty` | STKO-BMENG | Header 数量（M 必填）|
| ID14 | `header_unit` | MARA-MEINS | 成品/半成品 UoM |

### Item（`map_bom_item`，每条组件一行）
| ID | 消息字段 | 来源 | 备注 |
|---|---|---|---|
| ID02 | `cop_img_no` | STPO-IDNRK | 组件物料（M 必填）|
| ID03 | `quantity` | STPO-MENGE | 组件数量（M 必填）|
| ID04 | `valid_from` | STPO-DATUV | 组件生效开始 |
| ID05 | `valid_to` | STPO-valid_to | STPO 无 DATUB |
| ID15 | `component_unit` | STPO-MEINS | 组件 UoM |
| ID16 | `operation_scrap` | STPO-AVOAU | 工序损耗（M，≥0）|
| ID17 | `component_scrap` | STPO-AUSCH | 组件损耗（M，≥0）|

## 组装流程（`map_data2message`，单对象）

```
1. 对象键（ir_relevant_object ->* <KEY_STRUCT>）→ READ mast_list（4 列键）→ stlnr
2. READ stko_list（stlnr + stlty + stlal + aennr；filter 预查路径 stlty 为空则按 stlnr 匹配）
3. 经 STAS 解析节点：stas_list WHERE stlnr/stlty/stlal → stlkn 集合
4. STPO 过滤：stpo_list WHERE stlnr/stlty AND stlkn ∈ 该备选 stlkn 集合
5. map_bom_header（stko/mast/mara）→ header
6. 每条 STPO → map_bom_item → append item
7. <MESSAGE_TY>-header = header; <MESSAGE_TY>-items = items
```

### 关键点

1. **STKO 匹配兼容 filter 预查**：对象键的 `stlty`/`aennr` 在 filter 预查路径下为空，不能用它们匹配；需按 `stlnr` 匹配唯一 BOM 头。
2. **`STAS` 决定组件归属**：对象键的 `stlal`（备选）必须经 `stas_list` 解析出 `stlkn` 节点集合，再据此过滤 `stpo_list`——**不可**只按 `stlnr`/`stlty` 取 STPO，否则多备选/多版本组件混入。
3. **STPO 的 `stlty` 过滤**：从**已命中的 STKO** 取实际 `stlty`（对象键 stlty 为空时不能用）。
4. **必填校验**在发送前（见 [06](06_aif_send.md)）：Header 的 `cop_exg_no`/`header_qty`、Item 的 `cop_img_no`/`quantity`/`operation_scrap`/`component_scrap`。
