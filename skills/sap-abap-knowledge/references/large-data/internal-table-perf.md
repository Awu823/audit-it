# 大数据量处理参考（内表 + 循环实测）

> 面向"大内表 / 大数据量"场景的实测参考与决策表。
> 来源：
> - GitHub `benmeijs/ABAP_ITAB`（嵌套循环 + 内表类型对比实测，GET RUN TIME）
> - GitHub `pokrakam/abap_itab_perf`（100 万次查找基准：存在性检查 vs READ vs SELECT）
> - 官方 `SAP-samples/abap-cheat-sheets`（32 Performance Notes / 01 Internal Tables）
> 官方逐条性能说明见 `../abap/32_performance_notes.md`；本文件聚焦**大数据量场景的实测结论与决策表**。

## 1. 场景决策表

| 场景 | 推荐表类型 / 访问方式 | 原因 |
|---|---|---|
| 大数据量、极少修改、高频按键读取 | **HASHED**（UNIQUE KEY 完整指定） | O(1) 恒定访问，不受表大小影响 |
| 需要按键遍历 + 范围访问、数据量中等 | **SORTED**（键访问须**左对齐、无缺口**） | 自动二分 O(log n)；非左对齐键会退化为线性 |
| 小数据量、顺序处理、纯写入 | **STANDARD** | 结构简单；大表线性查找很慢 |
| 标准表需要按键查找 | 加**二级表键**（Secondary Table Key） | 仅对"大表 + 填一次 + 少改 + 多读"值得，组件尽量少 |
| 嵌套循环（N×M 两表按 key 匹配） | 先 SORT 两表，**并行游标（parallel tabix）** 一次遍历 | 实测比"内层 LOOP ... WHERE"快得多（见 §2.2） |
| 大内表判存在 | `line_exists( itab[...] )` 或 `READ TABLE ... TRANSPORTING NO FIELDS` | 免整行复制（见 §3） |
| 大内表取行值 | 先 `ASSIGN`/`REF #( ... OPTIONAL )` 再读，避免多次表表达式 | 每次表表达式都重定位行 |

## 2. 内表类型实测结论（benmeijs/ABAP_ITAB）

该测试程序（`zz_itab_performance_comparison`）对比了 7 种"外大表 × 内大表"处理方式，数据量从 2 行到 8192 行递增（内表行数 = 外表 ×10）：

### 2.1 READ in LOOP（外循环内做按键读取）

| 方式 | 实测结论 |
|---|---|
| 内表 STANDARD + `READ TABLE ... WITH KEY`（线性） | 最慢，随表增长线性劣化 |
| STANDARD + `BINARY SEARCH` | 比线性快，但需先 SORT，且表必须保持有序 |
| 内表 SORTED + `WITH TABLE KEY`（左对齐） | 远优于标准表；表大时仍比 hashed 慢 |
| 内表 HASHED + `WITH TABLE KEY`（完整键） | **最快**，各表大小下优势明显 |

### 2.2 LOOP in LOOP（嵌套循环按 key 匹配）

| 方式 | 实测结论 |
|---|---|
| 双 STANDARD + `LOOP AT 内 WHERE key = 外-key` | 最慢（每外层行都遍历内表） |
| 内表 SORTED + `LOOP ... WHERE` | 显著快于双标准表 |
| 双 STANDARD **先 SORT + 并行 tabix**（内层 `LOOP AT 内 FROM 上次 tabix`，键序比较到 `>` 即 EXIT） | **最快**——O(n+m) 一次遍历，实测各规模下最快 |

> 并行 tabix 模式要点（见 §2.3 代码骨架）：
> - 两表必须先按同一键 `SORT ... BY key`；
> - 外层每换 key，内层 `LOOP ... FROM <上次 sy-tabix>`，用结构比较 `IF 内key > 外key EXIT`；
> - 内表"一行对应外行多个"（1:N）时注意：同 key 多行都要处理完再推进游标，
>   实现时内层用 `LOOP AT 内 FROM ...` + `END` 推进，外层用 `IF 外key > 当前内key` 推进内层起点。

### 2.3 并行游标代码骨架（官方风格 7.50+）

```abap
SORT lta_outer BY key1.
SORT lta_inner BY key1.

DATA ltp_tabix TYPE i VALUE 0.
LOOP AT lta_outer INTO DATA(lv_out).
  ltp_tabix += 1.
  " 推进内层游标：内层 key <= 外层 key 的行都要处理
  DO.
    ltp_tabix += 1.
    READ TABLE lta_inner INTO DATA(lv_in) INDEX ltp_tabix TRANSPORTING key1.
    IF sy-subrc <> 0.
      ltp_tabix -= 1.  " 回到最后一个有效行
      EXIT.             " 内表用尽
    ENDIF.
    IF lv_in-key1 > lv_out-key1.
      ltp_tabix -= 1.
      EXIT.
    ENDIF.
    " 处理 (lv_out, lv_in)
  ENDDO.
ENDLOOP.
```

> 注：官方 7.50 写法更常用 `LOOP AT 内表 FROM <起点>` 配合结构比较推进（benmeijs 原始实现），
> 上面是等价的 7.50 READ 风格骨架；两者核心思想相同——**一次线性扫描替代 N×M 二次遍历**。

## 3. 大内表存在性检查实测（pokrakam/abap_itab_perf）

基准条件：SORTED 表 10235 行，**同一查找各测 100 万次**，"查找存在"与"查找不存在"
（不存在需遍历确认，更重）各一组；计时用 `GET RUN TIME`（秒级整数，结果**只反映
相对趋势**，非精确基准——正式分析见 §6 与 `profilers.md`）。

该基准对比 12 种方式（按源码测试顺序，**非按快慢**——源码只打印各自行运行时间供
手工对比）：

| 方式 | 说明 |
|---|---|
| `IF line_exists( itab[ id = x ] )` | 纯存在性检查，不复制行 |
| `READ TABLE ... TRANSPORTING NO FIELDS` | 等价存在性检查 |
| `READ TABLE ... INTO row WITH KEY` | 取整行到工作区（复制） |
| `line_index( itab[ ... ] )` + 按索引读 | 两次访问 |
| `ASSIGN itab[ ... ] TO <fs>` | 赋字段符号（不复制行） |
| `REF #( itab[ ... ] OPTIONAL )` | 取行引用（不复制行内容） |
| `ROW = VALUE #( itab[ ... ] OPTIONAL )` | 取整行副本 |
| `VALUE #( itab[ ... ] DEFAULT 默认行 )` | 取行副本 + 默认值兜底 |
| `TRY ... itab[ ... ] CATCH` | 表表达式异常路径 |
| `SELECT SINGLE FROM usr01`（DB 单行） | 对比项：有网络往返，纯内存查找仍快得多 |

**本 skill 的工程结论**（基于官方 32 号文档 § 减少内容传输 + 该基准的相对排序）：

- 只判"有没有"→ 用 `line_exists( )` 或 `READ TABLE ... TRANSPORTING NO FIELDS`，
  免整行复制；**不要**用 `VALUE #( itab[ ... ] )`（每次都是整行副本）。
- 循环里反复取行 → `ASSIGN` 一次复用 field-symbol，避免每个循环步重新表表达式定位。
- 要"不存在则默认值" → `VALUE #( itab[ ... ] DEFAULT 默认行 )` 语义最清晰
  （是否比 `line_exists` + 分支快要看数据形态，两者都避免 `IF` 分支时实测接近）。

## 4. 大内表内存管理

- **循环内反复填充的大内表**：每轮 `CLEAR itab`（留内存，下轮复用，快）；
  循环结束、不再需要时 `FREE itab`（连内存一起释放，避免驻留）。
- **一次性巨表**（如千万行）：避免 `APPEND wa` 逐行，用批量
  `INSERT LINES OF src INTO TABLE dst` 或 `SELECT ... INTO TABLE` 一次性装载；
  用完 `FREE`。
- **二级表键的写放大**：对带 UNIQUE 二级键的表，每次写（INSERT/MODIFY 影响键字段）
  都要维护哈希/索引，运行时开销高——**只在"填一次 + 多读"时使用**。
- **哈希表建表**：HASHED 表的 INSERT 比 STANDARD 的 APPEND 略慢（要计算哈希），
  但读取 O(1)——先按序 APPEND 到临时 STANDARD 再整体转 HASHED 通常更快
  （7.50 可用 `VALUE #( ( TYPE 行 ) ... )` 或先装 STANDARD 后 `INSERT LINES OF`）。

## 5. 大内表排序

- `SORT` 始终**显式指定排序键**（`SORT itab BY key1 key2`）——
  无键时用标准键（行全字段）排序，大表上代价最高。
- 只需顺序遍历不需要保序：排序代价可接受，但先评估能否用 HASHED/SORTED 表避免。
- 大量去重：`SORT ... DELETE ADJACENT DUPLICATES` 或
  `CORRESPONDING #( tab DISCARDING DUPLICATES )`（键去重）。

## 6. 与官方 32 号文档的分工

- 本文件：**大数据量场景的决策 + 实测数字**（嵌套循环、哈希 vs 排序、存在性检查、内存管理）。
- `../abap/32_performance_notes.md`：官方逐条性能说明（SQL 侧 WHERE/聚合/JOIN、内表侧 TRANSPORTING/块级/二级键/CLEAR-FREE、杂项 DO vs WHILE/字符串/传引用/并行）。
- 两者互补；审计整改引用官方逐条细节时以 32 号为准，**大数据量决策**优先读本文件。

## 7. 来源

| 仓库 | 内容 | 许可 |
|---|---|---|
| `benmeijs/ABAP_ITAB` | `Z_ITAB_PERFORMANCE_COMPARISON.TXT`：嵌套循环 + 内表类型 GET RUN TIME 对比 | MIT |
| `pokrakam/abap_itab_perf` | `ztest_itab_search_perf.prog.abap`：100 万次查找基准（line_exists/READ/VALUE/SELECT SINGLE） | MIT |
| `SAP-samples/abap-cheat-sheets` | 32 Performance Notes / 01 Internal Tables（官方逐条说明） | MIT |

> 注意：GET RUN TIME 秒级测量 + 单次运行的数字**只反映相对趋势**，
> 正式性能分析请用 ST05/SAT/ABAP Trace（见 `../abap/32_performance_notes.md` 的说明与 audit skill §5 定位工具）。
