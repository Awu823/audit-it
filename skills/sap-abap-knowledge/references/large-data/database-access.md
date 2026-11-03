# 大数据量数据访问参考（DB 侧 + 现代语法）

> 面向"大表 / 大数据量"场景的数据库访问与 7.50+ 语法模式。
> 官方逐条说明见 `../abap/32_performance_notes.md`；本文件聚焦**大表场景的实测模式与写法对照**。

## 1. 大表 SELECT 模式对照

### 1.1 只取需要的列、行

```abap
" 慢：读整张 5000 万行大表
SELECT * FROM mara INTO TABLE @DATA(lt_all).

" 快：只取所需列（7.50 用 FIELDS 更灵活）
SELECT vbeln, netwr, kwmbl
  FROM vbrk
  INTO TABLE @DATA(lt_vbrk).

" 只要前 100 行（Top-N）：
SELECT * FROM mara UP TO 100 ROWS INTO TABLE @DATA(lt_top).

" 只要一条记录（比读全表过滤快得多）：
SELECT SINGLE matnr FROM mara WHERE matnr = @lv_matnr.

" 7.50+ 只读部分列：
SELECT FIELDS matnr, mtype FROM mara WHERE mtyp EQ 'R' INTO TABLE @DATA(lt_mara).
```

### 1.2 大表 WHERE 的索引要求

- 大表的 WHERE 应落在**有索引的字段**上；`NOT`、`OR` 会显著降低 DB 优化器走索引的概率。
- 用 `=` / `AND` 组合的**最左前缀**条件：如索引是 `(a, b, c)`，
  `WHERE a = 1 AND b = 2` 走索引，`WHERE b = 2 AND c = 3` 不走。
- `IN` / `EXISTS` / 子查询下推 DB；`FOR ALL ENTRIES` 在大内表时生成巨大 OR 串，
  **超过 ~100 个元素时改用 JOIN 或 AMDP**（见 §4）。

### 1.3 大表 JOIN（替代 FAE / 循环 DB 访问）

```abap
" 慢：两个表分别 SELECT + 内表匹配
SELECT matnr FROM mara WHERE ... INTO TABLE @DATA(lt_mara).
SELECT * FROM mard INTO TABLE @DATA(lt_mard).
" 然后内表匹配...

" 快：单条 JOIN，DB 侧一次完成
SELECT m~matnr, a~werks, a~istok
  FROM mara AS m INNER JOIN mard AS a
    ON m~matnr = a~matnr
 WHERE m~mtype = @lv_mtype
  INTO TABLE @DATA(lt_result).

" 大内表匹配 DB 数据（7.50 现代写法，替代 FOR ALL ENTRIES）：
SELECT * FROM mard WHERE matnr IN (@lt_keys) INTO TABLE @DATA(lt_mard).
"  lt_keys 是 TABLE OF 大表；空表需先判空（同 FAE 判空要求）
```

## 2. 大内表 JOIN（7.52+，免 DB 访问）

> 7.52 起支持内表 JOIN，把原来"SELECT + FAE/匹配"两步合成一步内存计算：

```abap
" 大内表 × 大内表 匹配（纯内存，免 DB）
SELECT * FROM mara AS m
  INNER JOIN @lt_mara_keys AS k ON m~matnr = k~matnr
 WHERE m~mtype = @lv_mtype
  INTO TABLE @DATA(lt_result).
```

## 3. 大表 UPDATE / DELETE 批量模式

```abap
" 慢：循环内逐行 UPDATE
LOOP AT lt_items INTO DATA(lv_wa).
  UPDATE mara SET mtype = 'R' WHERE matnr = lv_wa-matnr.
ENDLOOP.

" 快：块级 UPDATE（一次 DB 访问）
UPDATE mara FROM TABLE @lt_items SET matnr, mtype.

" 指定列 UPDATE（少改列时用 SET，比改工作区整行再 UPDATE 快）：
UPDATE mara SET wergb = @lv_wergb WHERE matnr = @lv_matnr.
```

## 4. 大表的 7.50+ 语法模式

### 4.1 批量读：SELECT INTO TABLE + 聚合

```abap
" 大表统计：聚合下推 DB（比读全表 + ABAP 内统计快）
SELECT SUM( netwr ) AS sum_netwr, COUNT( * ) AS cnt
  FROM vbrk WHERE erdat = @lv_date
  INTO @DATA(lv_result).
```

### 4.2 批量写：VALUE #  + 块级 INSERT

```abap
" 循环逐行 APPEND 比一次性批量构造慢
" 快：构造器表达式批量构造
lt_items = VALUE #(
  ( matnr = 'A' mtype = 'R' )
  ( matnr = 'B' mtype = 'D' )
  " ... 从源表映射
  CORRESPONDING #( lt_src DISCARDING DUPLICATES )
).

" 批量插入 DB
INSERT mara FROM TABLE @lt_items.
```

### 4.3 大数据内存管理

- 大内表用完 **`FREE itab`**（释放内存），循环内复用用 **`CLEAR itab`**。
- 哈希表大键场景：HASHED 表插入比 STANDARD 略慢，但读 O(1)——
  先按序装临时 STANDARD 再整体 `INSERT LINES OF` 到 HASHED 通常更快。

## 5. 定位工具

- **ST05**（SQL Trace）：定位慢 SQL，看 DB 侧执行计划。
- **SAT**（SE30 旧）：Runtime Analysis，定位 ABAP 语句热点。
- **HANA SQL Analyzer**：DB 侧优化。
- **ABAP Trace / Cross Trace**：语句级跟踪（GitHub 官方 teched2025-DT266）。

## 6. 与官方 32 号文档的分工

- 本文件：**大表 / 大数据量场景的写法对照**（SELECT 模式、JOIN、批量 UPDATE、聚合）。
- `../abap/32_performance_notes.md`：官方逐条性能说明（含 `UP TO n ROWS` / `DISTINCT` / `CDS push-down` / `WHILE vs DO` / 传引用等）。
- 审计整改引用官方逐条细节时以 32 号为准，**大表场景决策**优先读本文件。

## 7. 来源

- `SAP-samples/abap-cheat-sheets` `32_Performance_Notes.md` / `03_ABAP_SQL.md`（官方逐条说明）
- `SAP-samples/abap-cheat-sheets` `12_AMDP.md`（AMDP，大表下推 DB 计算）
- 7.50 语法变更参见 `../abap-new-syntax/README.md` 的官方 PDF
