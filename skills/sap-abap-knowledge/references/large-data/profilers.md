# 性能剖析参考（Profiler / 定位工具）

> 用官方与社区工具定位 ABAP 程序的性能瓶颈。
> 来源：官方 `32_performance_notes.md` 推荐 + 社区 `EugeneKrapivin/BenchmarkingAndOptimizationSnippins` + ST05/SAT。

## 1. 官方推荐工具（32 号文档明确列出）

官方 cheat sheet 只给**结论**，详细的工具用法要查官方文档：

- **ABAP Profiling（ADT）**：SAP 官方推荐"用可用的工具做性能与运行时间分析"。
  - 参考：[SAP Help Portal 文档](https://help.sap.com/docs/abap-cloud/abap-development-tools-user-guide/profiling-abap-code?state=CLOUD&version=sap_btp)
  - 参考视频：[Explore ABAP Profiling with the ABAP Development Tools](https://www.youtube.com/watch?v=CSv-0YGfDS8)
- **32 号文档的可执行示例**（`zcl_demo_abap`）演示了"两次 `utclong_current( )` 取时间戳 + 多次循环取平均"的手工测量模式，
  但**明确说明不适合准确性能测试**——正式分析必须用官方 profile 工具。

## 2. ST05（SQL Trace）

| 项目 | 内容 |
|---|---|
| 入口 | `ST05`（事务码） |
| 用途 | 抓 DB 侧执行：`SELECT` 耗时、行数、索引使用情况 |
| 重点看 | "Top SQL" 排行（按总耗时）、重复 SQL、未走索引的 `SELECT` |
| 配套 | HANA SQL Analyzer（DB 侧优化） |

## 3. SAT（SE30）/ Runtime Analysis

| 项目 | 内容 |
|---|---|
| 入口 | `SAT`（新）/ `SE30`（旧） |
| 用途 | ABAP 语句级热点：哪个方法/语句占总耗时最多 |
| 重点看 | "Top 10 语句"、循环次数 × 单次耗时的估算 |

## 4. ABAP Trace / Cross Trace（官方 teched2025-DT266）

- **ABAP Trace**：语句级跟踪（比 SAT 更细），看某条语句的真实行数。
- **Cross Trace**：跨 workprocess 调用（如后台 job 的 BAdI 调用链）。
- 适合：跨 LUW 的写场景，或 BAdI / 增强引发的慢路径。

## 5. Memory Inspector（官方 teched2025-DT266）

- 看**内表驻留内存**：大内表没 `FREE` 时会持续增长。
- 重点看：`sy-tlwb`（workprocess 占用的内存）是否异常。

## 6. 社区参考

### 6.1 `EugeneKrapivin/BenchmarkingAndOptimizationSnippins`

- C# 侧（非 ABAP），用于**非 ABAP 端**的性能基准（如 .NET 侧调用 ABAP RFC 的延迟）。
- 对本 skill 用处有限，**不在默认触发范围内**；
  仅当用户明确问"ABAP 之外（.NET/Java 端）的性能瓶颈"时引用。

### 6.2 `benmeijs/ABAP_ITAB` + `pokrakam/abap_itab_perf`

- ABAP 内表性能实测（详见 `internal-table-perf.md`），用 `GET RUN TIME` 做**相对**趋势判断。
- **正式分析**仍推荐 ST05/SAT/ABAP Trace，不用手工 `GET RUN TIME` 数字做结论。

## 7. 定位流程（推荐顺序）

```
1. ST05 抓 SQL  Top10
   └─ 哪条 SELECT 最慢？走没走索引？
2. SAT 看 ABAP 热点
   └─ 哪个方法/循环耗时最多？
3. ABAP Trace 语句级
   └─ 该循环里哪条语句慢？
4. Memory Inspector
   └─ 内表驻留内存是否异常？
5. 对照 32 号文档 + 本 large-data/ 三文件
   └─ 决定改法（JOIN / HASHED / 批量 / 并行）
```

> 关键原则（官方 32 号文档）：**绝大多数 Clean Code 规则没有性能负效应，
> 10% 的代码常占 90% 的运行时间且 ABAP 多为 DB 时间 → 用 profile 定位热点做针对性优化，
> 不要过早优化。**

## 8. 与官方 32 号文档的分工

- `../abap/32_performance_notes.md`：性能优化的**结论**（该怎么写），并明确"用 profile 工具分析"。
- 本文件：**工具清单**（ST05/SAT/ABAP Trace/Memory Inspector）+ 定位流程 + 社区参考。

## 9. 来源

- `SAP-samples/abap-cheat-sheets` `32_Performance_Notes.md`（官方推荐 profile 工具）
- `EugeneKrapivin/BenchmarkingAndOptimizationSnippins`（C# 基准，仅参考）
- SAP Help Portal：ABAP Profiling 官方文档
- `teched2025-DT266`（官方性能/内存工具清单）
