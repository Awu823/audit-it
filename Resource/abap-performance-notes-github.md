# ABAP 性能笔记 — GitHub 官方来源（Performance Notes）

> 从 **GitHub 官方 SAP 仓库**整理编译，作为 `sap-abap-audit` 的权威性能整改参考。
> 与 `Resource/abap-performance-optimization.md`（Web 来源版）互补。检索日期：2026-10-30。

## 来源（Sources，均为 GitHub 官方仓库）

| 来源 | 内容 |
|---|---|
| [SAP-samples/abap-cheat-sheets → 32_Performance_Notes.md](https://github.com/SAP-samples/abap-cheat-sheets/blob/main/32_Performance_Notes.md) | **官方 ABAP 性能笔记**：DB 访问、内表处理、杂项；含可执行示例类 `zcl_demo_abap` |
| [SAP-samples/abap-cheat-sheets](https://github.com/SAP-samples/abap-cheat-sheets) | 官方 cheat sheets 仓库（01_Internal_Tables / 03_ABAP_SQL / 06_Dynamic_Programming 等） |
| [SAP/styleguides → clean-abap/CleanABAP.md](https://github.com/SAP/styleguides/blob/main/clean-abap/CleanABAP.md) | Clean ABAP：性能相关规则（表类型、循环目标、LINE_EXISTS、LOOP AT WHERE 等） |
| [SAP-samples/teched2025-DT266](https://github.com/SAP-samples/teched2025-DT266) | TechEd 2025「Troubleshoot and optimize ABAP Cloud extensions」：ABAP Trace / SQL Trace / Memory Inspector / 表缓冲 / 二级索引 / 嵌套循环 / CDS code push-down |

---

## 1. 数据库访问（Database Access）

### 1.1 减少结果集（Reducing the Result Set）
- `WHERE` 尽量使用；仅当确需全表内容才省略。
- `HAVING` 配合 `GROUP BY` 进一步限制分组行。
- `SELECT SINGLE` 只读单条；`UP TO n ROWS` 限行；`DISTINCT` 去重。
- ⚠ 复杂 WHERE/HAVING 影响性能：`=`/`EQ` + `AND` 最高效；`NOT`/`OR` 更费 DB 检索。

### 1.2 减少数据量（Reducing the Data Volume）
- **指定具体列**替代 `SELECT *`。
- `UPDATE ... SET` 指定列比整工作区 UPDATE 更高效。
- 聚合 `SUM`/`AVG`/`COUNT` 可下推 DB 计算，减少传输量（但 DB 侧有成本，视情况）。

### 1.3 减少数据库访问（Reducing Database Accesses）
- **块级操作**（`INSERT`/`UPDATE`/`DELETE` 内表作操作数）代替逐行。
- **避免循环内重复 DB 访问**（LOOP 内 SELECT）；ABAP EML 同样不应在循环内用（应一次读 + 一次 modify request）。
- **避免嵌套 SELECT 循环**：内层访问次数 = 外层 × 内层，大数据集严重劣化。
- **JOIN / 子查询优先**：多源数据用 JOIN；`WHERE EXISTS` 子查询不传数据；现代 ABAP 可用**内表 JOIN**匹配内表条目（避免 `FOR ALL ENTRIES` 空表读全表风险）。

### 1.4 CDS 视图（code push-down）
- 复杂计算/JOIN 下推到 HANA 数据库执行，而非 ABAP 内存。
- 数据密集型操作用 released CDS view 显著提升性能。

### 1.5 动态 vs 静态 SQL
- 动态 token（数据源/键）需运行时求值；**静态规范性能更优**。

### 1.6 表缓冲 & 索引
- DDIC 表/CDS 实体可缓冲（technical settings / 注解），ABAP SQL 隐式生效。
- 索引提升查询；勿过度创建（写维护开销）。

---

## 2. 内表处理（Processing Internal Tables）

### 2.1 表类型选用（表类型选择核心）
- **STANDARD**：小数据集 + 顺序处理；键查找是**线性**的。
- **SORTED**：需始终有序、逐块填充或需修改；主键访问优化（O(log n)）；**左对齐无缝隙**的部分键仍可优化。
- **HASHED**：超大表 + 极少修改；键访问 O(1)；**须指定完整键**才优化。
- 三类均可加**二级表键**提供优化访问。

### 2.2 单行访问（主键 vs 自由键）
- `READ TABLE ... WITH TABLE KEY`（主键）/ 表表达式 `TABLE KEY`：Sorted 优化、Hashed 恒定、Standard 线性。
- `READ TABLE ... WITH KEY`（自由键）：**线性**；旧式 `BINARY SEARCH` 需先 `SORT`（昂贵），**建议改用二级表键**。

### 2.3 多行访问 & WHERE 优化
- 避免全表迭代；`LOOP ... WHERE` / `FROM` / `TO` 限定。
- WHERE 优化前提：条件可转为键值对、键字段 `=` + `AND`、操作数类型一致（否则类型转换开销）。
- `READ TABLE ... WHERE` 若可用 `WITH KEY` 应改用 `WITH KEY`（更高效）。

### 2.4 减少内容传输（Reducing Content Transfer）
- `TRANSPORTING` 指定字段（`NO FIELDS` 仅需系统字段时）。
- **用 FIELD-SYMBOL / 数据引用替代工作区**：避免整行复制；深结构（嵌套）尤其显著；简单表或小读次数工作区未必更差。

### 2.5 块级处理
- `INSERT ... LINES OF` / `APPEND ... LINES OF` 批量比逐行复制高效。
- `FIND/REPLACE ... IN TABLE` 一步完成比逐行搜替高效。

### 2.6 二级表键（Secondary Table Keys）
- 三类表均可；**慎用**（管理开销），大表 + 填一次 + 少改 + 频繁读为宜。
- 组件数宜少；唯一二级键 + 频繁更新会有额外成本。

### 2.7 排序键（Sort Key）
- `SORT` 有隐式排序成本；**显式指定排序键**（而非标准键隐式）更清晰且防误用。

### 2.8 CLEAR vs FREE
- `CLEAR`：删内容但**保留内存**（再填充时性能优）。
- `FREE`：删内容并**释放内存**（大表处理完用；再填充需重新分配）。

### 2.9 动态 vs 静态
- 动态键规范需运行时求值；静态更优。

### 2.10 过度使用表表达式
- 多次访问同一行用多个表表达式 → 应先用 FIELD-SYMBOL / 数据引用**引用该行**再访问。
- 官方示例：第二版（引用+少表表达式）运行时显著短于第一版（多次表表达式）。

---

## 3. 杂项（Miscellaneous Contexts）

- **DO vs WHILE**：`WHILE` 可能比 `DO`（含显式 `EXIT`）更快。
- **字符串**：变长 `string` 对变长操作可能快于定长 `c`；纯字面量模板用反引号字符串字面量；模式搜索用比较操作符+IF 优于 `FIND PCRE`。
- **避免隐式类型转换**：增加运行时成本、可能意外结果。
- **传引用 vs 传值**：`VALUE` 参数（传值）会创建并赋值本地对象；**传引用**（REFERENCE 默认）更适合大数据集、无需改动时。
- **并行处理**：`CL_ABAP_PARALLEL` 等支持并行，适合数据密集型。

---

## 4. 排查工具（来自 teched2025-DT266，官方）

| 工具 | 用途 |
|---|---|
| **ABAP Trace / ABAP Cross Trace** | 追踪执行流与资源消耗；跨运行时组件（含 Fiori/ABAP Cloud） |
| **SQL Trace**（+ HANA SQL Analyzer in VS Code） | 看执行计划、定位慢 SQL |
| **Memory Inspector** | 内存消耗与增长（OOM 定位） |
| **Table Comparison Tool** | 优化前后结果比对（防优化引入功能错误） |
| **Feed Reader / ABAP Debugger** | 运行时错误根因定位 |

- 优化流程：先用工具定位热点 → 针对性优化 → 用 Table Comparison Tool 校验结果一致。

---

## 5. 与 `sap-abap-audit` 规则映射（补充）

| 审计规则 | 对应本节 | 备注 |
|---|---|---|
| `SELECT_ALL` | §1.2 | 指定列 |
| `SELECT_NO_WHERE` | §1.1 | WHERE 建议（省略需确需全表） |
| `SELECT_IN_LOOP` | §1.3 | 循环内 DB 访问、嵌套 SELECT |
| `FOR_ALL_ENTRIES_NO_EMPTY_CHECK` | §1.3 | 空表读全表（官方明示） |
| `FAE_NO_DEDUP` | §2.6/§2.7 | 内表 JOIN 替代 FAE；去重 |
| `MODIFY_INSERT_IN_LOOP` | §2.5 | 块级处理 |
| `WORKAREA_INSTEAD_OF_FS` | §2.4 | FIELD-SYMBOL/引用 vs 工作区 |
| `APPEND_COLLECT_LEGACY` | §2.5/§2.8 | `LINES OF` 批量 / 构造器 |
| `CONCATENATE_LEGACY` | §3 | 字符串模板 / 反引号字面量 |

> 本文件为 **GitHub 官方来源**版；Web 来源版见 `Resource/abap-performance-optimization.md`。
> 技能内精简引用：`skills/sap-abap-audit/references/performance-optimization.md`。
