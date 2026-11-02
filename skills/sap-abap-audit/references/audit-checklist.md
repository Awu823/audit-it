# ABAP 代码审查清单（Audit Checklist）

本文件是 `sap-abap-audit` 的人工复核清单，配合规则引擎使用。规则给出**定位**，
本清单给出**人工确认与整改**的完整思路，按类别组织。
> 性能类问题（SELECT *、FOR ALL ENTRIES、循环内写、READ INTO、构造器）的详细整改与
> 权威来源，另见 `references/performance-optimization.md`（完整版 `Resource/abap-performance-optimization.md`）。

## 1. 正确性（error）

### SELECT 缺目标子句
- **现象**：`SELECT` 未带 `INTO` / `APPENDING ... TABLE`，或目标被省略。
- **后果**：运行时 `cx_sy_itab_line_not_found` 或把结果读入错误对象。
- **整改**：始终 `SELECT ... INTO [CORRESPONDING] FIELDS OF TABLE @DATA(itab)`；只取一行用 `SINGLE`。

### FOR ALL ENTRIES 未先判空
- **现象**：`FOR ALL ENTRIES IN @itab` 前没有 `IF itab[] IS NOT INITIAL` 或 `line_exists( itab[ 1 ] )`。
- **后果**：内表为空时 `FOR ALL ENTRIES` 会**匹配全表**，返回错误数据（经典坑）。
- **整改**：循环前判空并 `EXIT`/`RETURN`；或改用 `IN @itab` 表达式（7.4+）。

## 2. 性能（warn）

### SELECT *
- **现象**：`SELECT *` 读取全部字段。
- **后果**：多传数据、DB 负载上升；破坏 `INTO CORRESPONDING` 的意图。
- **整改**：只读所需列；7.5 用 `FIELDS col1, col2`。

### SELECT 无 WHERE（全表读取）
- **现象**：`SELECT` 无 `WHERE`/`UP TO`/聚合（且非 JOIN 过滤）。
- **后果**：全表读取，数据量大时显著变慢、内存激增。
- **整改**：加 WHERE 用索引列；确需全表时确认表为小表/配置表，或 `UP TO n ROWS` 限行。

### 循环内 SELECT
- **现象**：LOOP/DO/WHILE 内 `SELECT`（含 `SELECT SINGLE`）。
- **后果**：每次迭代一次 DB 往返；大数据量下性能劣化明显。
- **整改**：改为批量读取（`FOR ALL ENTRIES` / `JOIN` / `IN @itab`）并在循环外处理。

### 循环内 COMMIT WORK
- **现象**：LOOP/DO/WHILE 内 `COMMIT WORK`（且未 `AND WAIT`）。
- **后果**：LUW 被切碎、原子性丢失、频繁 DB 往返。
- **整改**：移到循环外；确需逐步确认用 `COMMIT WORK AND WAIT`。

### 循环内 MODIFY / INSERT
- **现象**：循环内逐行 `MODIFY`/`INSERT` 内表。
- **后果**：可能 O(n²)；可读性差。
- **整改**：批量 `VALUE #( )` / `CORRESPONDING`，或按 key 排序后 `MODIFY TABLE`。

### FOR ALL ENTRIES 内表未去重
- **现象**：`FOR ALL ENTRIES IN itab` 前未对 `itab` 去重（且非 SORTED/HASHED）。
- **后果**：重复 key 增加 DB 接口/内核开销；大内表下可测的性能劣化。
- **整改**：`SORT itab` + `DELETE ADJACENT DUPLICATES`，或声明 `TYPE SORTED TABLE ... WITH UNIQUE KEY`。

### READ TABLE ... INTO 建议 ASSIGNING
- **现象**：`READ TABLE ... INTO <wa>`（仅读不改）。
- **后果**：整行复制开销。
- **整改**：`READ TABLE ... ASSIGNING <fs>`。

### STANDARD 表键查找（线性）
- **现象**：`READ TABLE <itab> WITH KEY`（自由键/`WITH TABLE KEY`）在 STANDARD 表上，无 `BINARY SEARCH`、无 `INDEX`。
- **后果**：线性扫描 O(n)；大表显著变慢。
- **整改**：改用 SORTED/HASHED 表、二级表键，或 `READ TABLE ... BINARY SEARCH`（需先 `SORT`）。

### SORT 未显式指定排序键
- **现象**：`SORT <itab>.`（无 `BY`，按标准键隐式排序）。
- **后果**：隐式排序成本高，且易误用（多字符字段标准键）。
- **整改**：显式 `SORT <itab> BY field...`。

## 3. 安全（warn / info）

### 动态 SQL / 拼接注入
- **现象**：`WHERE ( ... )`、`SELECT ( ... ) FROM`、字符串 `&&` 拼接出 SQL 片段。
- **后果**：SQL 注入、维护困难、性能差（无法走 DB 计划）。
- **整改**：参数化 `@( )`、`IN @itab`、`FOR ALL ENTRIES`；确需动态时严格白名单字段/表。

### 敏感表访问未见 AUTHORITY-CHECK
- **现象**：读 `USR*`/`AGR_*`/`SUCH*`/`AUTH*` 等表无前置权限检查。
- **整改**：`AUTHORITY-CHECK OBJECT ...` 并处理 `sy-subrc <> 0`。

## 4. 现代化（warn / info）

- **TABLES:** → 具名 `TYPES`/`DATA` 或 `SELECT ... INTO @DATA(...)`。
- **PERFORM/FORM** → 类方法。
- **CONCATENATE** → 字符串模板 `|...|`。
- **APPEND/COLLECT** → `VALUE #( )` 构造器。

## 5. 质量 / 风格（info）

- **TODO/FIXME/XXX**：遗留标记，需排期处理。
- **行 > 120**：可读性换行。
- 命名约定：`lv_`（局部变量）、`lt_`（内表）、`ls_`（结构）、`mo_`（对象引用）、`cs_`（常量）。

## 建议流程

1. 跑 `python3 scripts/audit_abap.py <path> --min-severity warn` 聚焦高价值问题。
2. 逐条用「现象 → 后果 → 整改」核对（真伪、影响面）。
3. 对 error 项优先整改；warn 项按影响排序；info 项批量处理。
4. 需要业务上下文/根因时，交叉引用 `../sap-abap-knowledge/references/modules/` 对应模块。
