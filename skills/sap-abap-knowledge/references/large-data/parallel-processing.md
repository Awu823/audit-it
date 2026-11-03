# 并行处理参考（CL_ABAP_PARALLEL）

> 官方并行处理框架，把数据密集任务切分到多个后台工作进程并行执行。
> 适用：大数据量纯计算 / 独立子任务；**不适合**有跨任务依赖或需要共享 LUW 的场景。

## 1. 何时用并行

| 场景 | 适合并行？ | 说明 |
|---|---|---|
| 纯内存计算，任务相互独立（如对 N 行数据分别做复杂换算） | ✅ | 经典场景 |
| 各子任务只读 DB、结果汇总写回 | ⚠️ 读多写少可并行；写要归一后一次提交 | |
| 需要跨任务共享状态 / 同表写回 | ❌ | 并行各自有独立 LUW，最后汇总写 |
| 任务间有依赖（A 完成才做 B） | ❌ | 拆成阶段 |

## 2. 基本用法（官方骨架）

> **重要**：`CL_ABAP_PARALLEL` 的 API 随 ABAP 版本演进（7.50+ 起可用）。
> 写代码前务必查当前系统里 `CL_ABAP_PARALLEL` 的类文档（ADT F1 / Help Portal），
> 确认 `new` / `start` / 结果收集方法的确切签名，**不要照抄下方骨架**。

官方骨架（方法名/参数以当前系统类文档为准）：

```abap
" 1. 创建并行框架实例
DATA(lo_parallel) = NEW cl_abap_parallel( ).

" 2. 定义任务函数（纯函数，签名以类文档为准；接收输入、RETURNING 结果）
"    CLASS lcl_task DEFINITION.
"      PUBLIC SECTION.
"        CLASS-METHODS run IMPORTING i_from TYPE i i_to TYPE i
"                          RETURNING VALUE(result) TYPE <自定义结果结构>.
"    ENDCLASS.

" 3. 把任务分块分发（每块一个 worker；块数 = worker 数）
"    分块模式见 §4

" 4. 等待全部 worker 完成并收集结果（get_next / is_completed 等，以类文档为准）
```

> 官方 cheat sheet `32_performance_notes.md` 的可执行示例里有完整用法
> （`zcl_demo_abap` 的 `misc_07_parallel_processing_*` 方法），
> 可直接参考示例确认当前 API 细节。

## 3. 关键限制（务必遵守）

- **任务函数必须是纯函数**：内部不能 `COMMIT WORK`（并行各自 LUW）、
  不能写全局/共享状态、不能依赖 `SY-SUBRC`。
- 每个并行进程独立，**结果必须显式收集**（RETURNING 值 / 写回表）。
- 任务粒度：过细（每任务 <1ms）时调度开销 > 计算收益；
  典型场景是"大内表分块"——每块 1 万~100 万行。
- **不能**在 `LOOP AT` 里逐行启动任务；要**先分块**再每块一个任务。

## 4. 分块模式（大数据量标准做法）

```abap
" 大内表按行号切块
DATA(lt_chunks) = VALUE itab_chunk(
  ( idx_from = 1       idx_to = 1000000 )
  ( idx_from = 1000001 idx_to = 2000000 )
  ( idx_from = 2000001 idx_to = 3000000 )
).

" 每块一个任务：任务函数接收 idx_from/idx_to，处理该区间
" 任务函数内部：
"   LOOP AT lt_source TRANSPORTING ... WHERE index >= <from> AND index <= <to>.
```

> 分块大小经验值：让每块计算时间 ≈ 几百 ms ~ 几秒，
> 块数 ≈ 4~8（匹配常用 worker 数）。太小调度开销大，太大并行度浪费。

## 5. 替代：后台批处理（不在前台 ABAP 内并行）

- **SM36/SM37 批量 job**：把大任务拆成多个后台 job 并发跑（不同 workprocess），
  适合跨多个 workprocess 的写场景。
- **后台 job 执行**：对会超时的大任务，用后台批处理（`SM36` 手动提交 /
  `CALL FUNCTION 'SAPMBCS'` 程序后台调用），避免前台会话锁死。
- **HANA CDS push-down**：若瓶颈是 DB 计算，优先 CDS 视图 + 聚合下推，
  比 ABAP 侧并行更高效（数据不过网络）。

## 6. 与官方 cheat sheet 的分工

- `../abap/32_performance_notes.md`：只给"可用 `CL_ABAP_PARALLEL` 做并行"的结论与示例。
- 本文件：分块模式、限制、替代方案（后台 job / CDS push-down）。
- 写实际代码前：**查当前系统 `CL_ABAP_PARALLEL` 的官方文档**确认方法签名。

## 7. 来源

- `SAP-samples/abap-cheat-sheets` `32_Performance_Notes.md` § Parallel Processing
- SAP Help Portal `CL_ABAP_PARALLEL` 类文档
- SAP Blogs 社区关于"大数据量后台 job 分块"的实践贴（需以当前系统能力为准）
