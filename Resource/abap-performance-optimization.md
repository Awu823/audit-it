# ABAP 代码性能优化参考（Performance Optimization Reference）

> 从网络权威来源整理编译，供 `sap-abap-audit` 等技能作为性能整改参考。
> 纯知识整理，非 SAP 官方文档；每条标注来源。检索日期：2026-10-30。

## 来源（Sources）

| 来源 | 标题 | 侧重点 |
|---|---|---|
| [S4Pedia](https://www.s4pedia.com/post/for-all-entries-when-a-performance-optimization-turns-into-a-performance-issue) | FOR ALL ENTRIES: When a Performance Optimization Turns into a Performance Issue | FAE 正确/错误用法、空表判空、去重、vs JOIN |
| [MDP Group](https://mdpgroup.com/en/blog/improve-abap-code-performance-practical-techniques-and-examples/) | Improve ABAP Code Performance: Practical Techniques and Examples | SELECT/CDS、循环、FIELD-SYMBOLS、新语法、SORTED TABLE、清理、ST05/SAT |
| [Koenig Solutions](https://www.koenig-solutions.com/blog/sap-abap-ecc) | Performance Optimization in SAP ABAP ECC: Best Practices | SELECT *、WHERE、INNER JOIN、索引、HASHED/SORTED、LOOP AT WHERE、缓冲、并行 |
| [SAP Community](https://community.sap.com/t5/technology-blog-posts-by-sap/compare-performance-between-select-for-all-entries-and-amdp/ba-p/13399425) | Compare performance between SELECT FOR ALL ENTRIES and AMDP（标题引用，正文 403 拦截） | FAE vs AMDP vs 内表 JOIN（7.52+） |
| [SAP Community](https://community.sap.com/t5/technology-blog-posts-by-members/abap-code-optimization-techniques-in-7-50/ba-p/14033015) | ABAP Code Optimization Techniques in 7.50+（标题引用，正文 403 拦截） | 7.50+ 优化技术 |

---

## 1. 数据库访问优化（Database Optimization）

### 1.1 只读所需字段，避免 `SELECT *`
- **坏**：`SELECT * FROM mara INTO TABLE lt_mara.`
- **好**：`SELECT matnr, mtart, matkl FROM mara INTO TABLE lt_mara.`
- **收益**：减少传输量、内存占用与 DB 负载。7.5 可用 `FIELDS col1, col2`。
- **来源**：Koenig §1.1，MDP §"Fetch Only the Fields You Need"。

### 1.2 用 WHERE 限定数据量
- **坏**：无 WHERE 全表读取。
- **好**：`SELECT matnr, mtart FROM mara INTO TABLE lt_mara WHERE mtart = 'FERT'.`
- **收益**：减少返回行数。WHERE 应只传最小必要数据，避免 NOT 条件（难以走索引）。
- **来源**：Koenig §1.2，SAP Community（SQL 优化）。

### 1.3 优先 INNER JOIN 替代嵌套 SELECT
- **坏**（循环内多次 SELECT SINGLE）：
  ```abap
  SELECT matnr FROM mara INTO TABLE lt_mara WHERE matkl = '001'.
  LOOP AT lt_mara INTO wa_mara.
    SELECT maktx FROM makt INTO wa_makt WHERE matnr = wa_mara-matnr.
  ENDLOOP.
  ```
- **好**（JOIN）：
  ```abap
  SELECT a.matnr, b.maktx
    FROM mara AS a
    INNER JOIN makt AS b ON a.matnr = b.matnr
    INTO TABLE lt_data
    WHERE a.matkl = '001'.
  ```
- **收益**：减少 DB 往返；JOIN 比嵌套 SELECT/FAE 更易被优化器利用索引。
- **来源**：Koenig §1.3，S4Pedia §Wrong Usage 3，MDP §"Avoid Unnecessary SELECT"。

### 1.4 善用索引
- WHERE 用**索引字段**（如 MATNR、MANDT 等）加速查询；避免在索引列上做函数/通配符运算。
- ⚠ 索引并非越多越好：过多索引增加写入维护开销。
- **来源**：Koenig §1.4。

### 1.5 表缓冲（Buffering）
- 高频读、低频改的小表（如 T001）在 SE11 开启缓冲，可改从内存读，减少 DB 往返。
- 注意：FAE 不绕过 SAP buffering，对缓冲表 FAE 可能反而更省。
- **来源**：Koenig §3.1，SAP Help（FAE 缓冲说明）。

---

## 2. FOR ALL ENTRIES（FAE）专项

> FAE 本意：把 SELECT 移出循环、减少 DB 往返。但"用错会变成性能坑"。以下为 4 大常见错误用法。

### 2.1 错误用法 1：内表过大
```abap
SELECT * FROM vbak INTO TABLE gt_vbak
  FOR ALL ENTRIES IN gt_vbeln
  WHERE vbeln = gt_vbeln-vbeln.
```
- **问题**：内表大 → DB 生成复杂 OR 条件 → 索引无法有效利用。
- **结果**：只执行一条 SELECT，但非常昂贵，**整体反而更慢**。
- **对策**：评估数据量；可改 JOIN、内表 JOIN（7.52+）、或分块（blocking factor，Note 634263 提到 max 1000 自 6.10）。
- **来源**：S4Pedia §Wrong Usage 1。

### 2.2 错误用法 2：未去重
- FAE 直接把内表内容传给 DB，重复 key 会给 DB 接口/内核增加不必要的重复处理开销。
- **对策**：
  ```abap
  SORT gt_vbeln BY vbeln.
  DELETE ADJACENT DUPLICATES FROM gt_vbeln COMPARING vbeln.
  ```
  或 7.4+ 用 `DATA(...) = VALUE #( ... )` / `CORRESPONDING #( ... DISCARDING DUPLICATES ... )`。
- **来源**：S4Pedia §Wrong Usage 2，MDP §"Clean Up Unused Data"。

### 2.3 错误用法 3：可用 JOIN 却用 FAE
- FAE 适合"内表驱动 + 单表回填"；若目标是多表关联，INNER JOIN 更高效、更省应用服务器内存。
- **来源**：S4Pedia §Wrong Usage 3，Koenig §1.3。

### 2.4 错误用法 4：空内表未判空（**最危险**）
```abap
IF gt_vbeln IS NOT INITIAL.
  SELECT ...
    FOR ALL ENTRIES IN gt_vbeln
    ...
ENDIF.
```
- **问题**：内表为空时 **WHERE 条件被完全忽略**，DB **读取整张表** → 全表扫描、生产性能问题。
- **官方**（SAP Help）："If the internal table itab is empty, the entire WHERE condition is ignored and all lines from the database are placed in the result set"。
- **对策**：判空守卫必须引用**同一个**内表（`IF <itab>[] IS NOT INITIAL` / `line_exists( <itab> )`），否则护不住 FAE。
- **来源**：S4Pedia §Wrong Usage 4，SAP Help / Note 634263。

### 2.5 正确用法小结
- FAE 只在内表**适度大小、已去重、确实单表回填**时使用。
- 大内表 / 需 JOIN / 可走 HANA → 考虑 AMDP 或内表 JOIN（7.52+，需 FDA 开启）。
- **来源**：S4Pedia Conclusion，SAP Community（FAE vs AMDP）。

---

## 3. 内表与循环优化（Internal Tables & Loops）

### 3.1 表类型选择：STANDARD / SORTED / HASHED
- **需搜索大表** → HASHED（唯一键，O(1)）或 SORTED（自动二分，O(log n)）。
- **纯写入** → STANDARD（追加快）。
- **坏**：`READ TABLE lt_mara WITH KEY matnr = '1000001'.`（STANDARD 线性扫描 O(n)）。
- **好**：`DATA lt_mara TYPE HASHED TABLE OF mara WITH UNIQUE KEY matnr.`
- **现代写法**：SORTED TABLE 自动二分，直接 `data(result) = products[ product = '1000001' ].` 无需 READ TABLE。
- **来源**：Koenig §2.1，MDP §"Use Binary Search"。

### 3.2 循环内判等 → LOOP AT ... WHERE
- **坏**：`LOOP AT lt_mara INTO wa_mara. IF wa_mara-mtart = 'FERT'. ... ENDIF. ENDLOOP.`
- **好**：`LOOP AT lt_mara INTO wa_mara WHERE mtart = 'FERT'.`
- **收益**：减少迭代次数。
- **来源**：Koenig §2.2。

### 3.3 嵌套循环 → 排序 + line_exists / 二分
- **坏**：两层 LOOP 内层 WHERE 逐行扫。
- **好**：先 `SORT ... BY ebeln`，外层用 `line_exists( itab[ ebeln = ... ] )` 判断，或 `READ TABLE ... BINARY SEARCH`。
- **来源**：MDP §"Optimize Your LOOPs"。

### 3.4 FIELD-SYMBOLS / ASSIGNING（免复制）
- **好**：`LOOP AT products ASSIGNING FIELD-SYMBOL(<product>). <product>-mtart = 'FERT'. ENDLOOP.`
- **收益**：引用式访问避免整行复制，大结构/大表尤其显著。
- **来源**：MDP §"Use FIELD-SYMBOLS and ASSIGN"，Koenig §2.1。

### 3.5 循环内 MODIFY/INSERT
- **坏**：循环内逐行 `MODIFY ... INDEX` / `INSERT ... INDEX/WHERE`（O(n²) 或定位重排）。
- **好**：批量 `VALUE #( )` / `CORRESPONDING` 一次构建，或按 key 排序后批量 `MODIFY TABLE`。
- **说明**：`INSERT ... INTO TABLE`（追加）是惯用法，O(log n)，不在此列。
- **来源**：MDP §"Code Shortening with New Syntax"。

### 3.6 清理无用数据（FREE vs CLEAR）
- `CLEAR` 只清内容，`FREE` **释放内存**——大内表处理完用 `FREE`。
- 去重用 `CORRESPONDING #( ... DISCARDING DUPLICATES ... )` 比循环内 APPEND + 事后 `DELETE ADJACENT DUPLICATES` 更干净。
- **来源**：MDP §"Clean Up Unused Data"。

---

## 4. 现代语法 / 代码级优化（7.50+）

- **构造器**：`APPEND VALUE #( ... ) TO itab` 替代 DATA/CLEAR/MOVE 三段式；`VALUE #( ... )` 批量赋值。
- **字符串模板**：`|...|` 替代 `CONCATENATE`。
- **行内声明**：`DATA(...)`、`@( )` 宿主表达式。
- **CDS 视图**：用 released CDS view 作为数据源，配合 FAE/IN 减少查询、走 DB 层优化。
- **并行处理**：长任务 `CALL FUNCTION ... IN BACKGROUND TASK`。
- **来源**：MDP §"Code Shortening"、§"CDS Views"；Koenig §3.2。

---

## 5. 性能分析工具（用于定位瓶颈）

| 工具 | 用途 |
|---|---|
| **ST05**（SQL Trace） | 监测 DB 级查询与耗时，找低效/慢 SQL |
| **SAT**（Runtime Analysis，旧 SE30） | 逐行定位耗时热点 |
| **SLIN**（Extended Check） | 代码结构/逻辑检查（如过度全局变量、缺 CHECK、低效 SELECT） |

- 三件套结合使用，全面评估性能与代码质量。
- **来源**：MDP §"Use SQL Trace (ST05) and Runtime Analysis (SAT)"；Koenig §3.3。

---

## 6. 与 `sap-abap-audit` 规则映射

本参考可直接指导以下审计规则的整改，建议在审计报告中引用：

| 审计规则 | 对应本节 |
|---|---|
| `SELECT_ALL` | §1.1 |
| `SELECT_NO_INTO` | §1.2（目标子句 INTO/APPENDING） |
| `FOR_ALL_ENTRIES_NO_EMPTY_CHECK` | §2.4（重点）、§2.1-2.3 |
| `MODIFY_INSERT_IN_LOOP` | §3.5 |
| `WORKAREA_INSTEAD_OF_FS` | §3.4 |
| `CONCATENATE_LEGACY` | §4 |
| `APPEND_COLLECT_LEGACY` | §4 |
| `COMMIT_IN_LOOP` | （LUW 原子性，非性能；见知识库 `17_sap_luw.md`） |

> 引用路径约定：`../sap-abap-knowledge/references/` 为知识库语法参考；本文件为**性能专项**参考，
> 可交叉引用。建议后续在 `sap-abap-audit/references/` 放置精简版以配合技能自包含。
