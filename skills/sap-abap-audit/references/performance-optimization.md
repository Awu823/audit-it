# ABAP 性能优化参考（审计整改用）

> 精简版，供 `sap-abap-audit` 规则整改时引用。完整版含来源与示例：
> `Resource/abap-performance-optimization.md`（工作区，含 S4Pedia / MDP Group / Koenig 来源）。

## 1. 数据库访问
- **只读所需列**，避免 `SELECT *`；7.5 用 `FIELDS col1, col2`。
- **WHERE 限定数据量**，只用必要字段；避免 NOT 条件。
- **INNER JOIN 替代嵌套 SELECT**（减少 DB 往返，更易走索引）。
- WHERE 用**索引字段**；但勿建过多索引（增加写维护）。

## 2. FOR ALL ENTRIES（FAE）——四大坑
1. **内表过大** → DB 生成复杂 OR，索引失效，整体更慢。评估数据量，改 JOIN / AMDP / 内表 JOIN（7.52+）。
2. **未去重** → 重复 key 增加 DB 接口开销。`SORT ... DELETE ADJACENT DUPLICATES` 或 `CORRESPONDING #( ... DISCARDING DUPLICATES ... )`。
3. **可用 JOIN 却用 FAE** → 多表关联应 INNER JOIN，FAE 只适合单表回填。
4. **空内表未判空（最危险）** → WHERE 被忽略、**全表扫描**。必须 `IF <itab>[] IS NOT INITIAL`（**同一**内表），或 `line_exists(<itab>)`。

## 3. 内表与循环
- **搜索大表** → HASHED（O(1)）/ SORTED（自动二分 O(log n)）；**纯写入** → STANDARD。
- **循环内判等** → `LOOP AT ... WHERE ...`。
- **嵌套循环** → 先 SORT，用 `line_exists( itab[...] )` / `READ TABLE ... BINARY SEARCH`。
- **FIELD-SYMBOLS / ASSIGNING** → 引用访问免整行复制。
- **循环内 MODIFY/INSERT**（INDEX/WHERE 定位写）→ 批量 `VALUE #( )` / `CORRESPONDING`；`INSERT ... INTO TABLE`（追加）是惯用法。
- 大表用完 **`FREE`**（释放内存），去重用 `CORRESPONDING #( ... DISCARDING DUPLICATES ... )`。

## 4. 现代语法（7.50+）
- `APPEND VALUE #( ... )` / 批量 `VALUE #( )` 替代 DATA/CLEAR/MOVE。
- 字符串模板 `|...|` 替代 `CONCATENATE`。
- released CDS view 作为数据源，配合 FAE/IN 走 DB 层优化。

## 5. 定位工具
- **ST05** SQL Trace、**SAT**（旧 SE30）Runtime Analysis、**SLIN** Extended Check。

## 规则映射
| 审计规则 | 本节 |
|---|---|
| `SELECT_ALL` | §1 |
| `FOR_ALL_ENTRIES_NO_EMPTY_CHECK` | §2.4（重点） |
| `MODIFY_INSERT_IN_LOOP` | §3 |
| `WORKAREA_INSTEAD_OF_FS` | §3 |
| `CONCATENATE_LEGACY` / `APPEND_COLLECT_LEGACY` | §4 |
