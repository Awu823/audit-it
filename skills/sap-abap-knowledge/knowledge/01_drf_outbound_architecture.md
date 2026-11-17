# 01 · DRF 出站三层架构

> 沉淀自 BOM 出站（S4H → 外部系统）的骨架设计。任何 DRF 出站接口都推荐此结构：
> **过滤器（filter）+ 框架适配层（out）+ 业务单例（biz）**。

## 为什么拆三层

| 层 | 类 | 职责 | 是否实现接口 |
|---|---|---|---|
| Filter | `<CL_FILTER>` | **对象级相关性过滤**：候选对象 → 仅保留目标系统关心的对象 | `IF_DRF_FILTER` |
| Out 适配层 | `<CL_OUT>` | **纯生命周期适配**：把 `IF_DRF_OUTBOUND` 方法转交给 biz；创建 biz 单例 | `IF_DRF_OUTBOUND` |
| Biz 单例 | `<CL_BIZ>` | **全部业务逻辑**：变更分析、过滤、批量取数、消息映射、AIF 发送、结果回写 | 不实现接口（普通类） |

- **Out 适配层极薄**：只做参数转发，不含业务，便于测试/替换。
- **Biz 单例**：由 out 的 `initialize` 创建并持有（`CLASS-DATA` 引用），框架每次调用同一实例。
- **Filter 独立**：DRF 配置中单独挂载，与 out/biz 解耦。

## 适配层骨架（`<CL_OUT>`）

```abap
CLASS <CL_OUT> DEFINITION PUBLIC FINAL CREATE PUBLIC.
  PUBLIC SECTION.
    INTERFACES if_drf_outbound.
  PRIVATE SECTION.
    " 业务单例引用（框架每次运行复用同一实例）
    CLASS-DATA <biz_instance> TYPE REF TO <CL_BIZ>.
    " 告诉框架本实现处理的对象键表类型
    CLASS-DATA gc_key_structure TYPE string
                             VALUE '<CL_BIZ>=><KEY_TABLE_TY>' ##NO_TEXT.
ENDCLASS.

CLASS <CL_OUT> IMPLEMENTATION.
  METHOD if_drf_outbound~initialize.
    " 1) 框架此刻还没有实例：先创建业务单例并传入运行时参数
    <biz_instance> = NEW <CL_BIZ>( ).
    <biz_instance>->runtime_parameter_ext = is_runtime_param.

    " 2) 框架据此构造 SORTED 对象键表（对象键结构类型名）
    es_runtime_param_out_impl-table_type_name = gc_key_structure.

    " 3) 单对象单包：避免只发最后一条消息（FS §2 分包语义）
    es_runtime_param_out_impl-package_size = 1.

    " 4) 返回本类（OUT）实例——OUT 实现接口，BIZ 不实现
    eo_if_drf_outbound = NEW <CL_OUT>( ).
  ENDMETHOD.

  METHOD if_drf_outbound~analyze_changes_by_chg_pointer.
    " 注意：BIZ 定义 IMPORTING，OUT 转发时 EXPORTING 传参、IMPORTING 收参
    <biz_instance>->analyze_changes_by_chg_pointer(
      EXPORTING it_change_pointer = it_change_pointer
      IMPORTING et_changed_objects = ct_changed_objects
                es_stat_info       = es_stat_info ).
  ENDMETHOD.

  " ... 其余生命周期方法同理逐层转发（analyze_changes_by_others /
  "     enrich_filter_criteria / read_complete_data / map_data2message /
  "     send_data / finalize）
ENDCLASS.
```

## 关键点

1. **`table_type_name` 必须是对象键表类型的全限定名**（`<CL_BIZ>=><KEY_TABLE_TY>`），框架据此知道对象键结构、构造 SORTED 表。
2. **`package_size = 1`**：单对象单包。若 >1，DRF 会把多个对象的消息压缩进一次 `map_data2message`/`send_data` 调用，容易出现"只发最后一条"的 bug。
3. **单例生命周期**：`initialize` 在每次 DRF 运行开始时被框架调用一次，此处创建 biz 单例；其余方法直接用该实例。
4. **未启用的接口方法**（如 `analyze_changes_by_mdg_cp`、`apply_node_inst_filter_*`）保持**空实现**即可，不要抛异常。
5. **业务逻辑绝不进 OUT**——否则无法单测，且多层嵌套转发会失控。

## 本套件其余文档的关系

- 生命周期方法与对象键解析 → [02](02_drf_lifecycle_and_object_keys.md)
- 对象级过滤实现 → [04](04_filter_object_level.md)
- 发送（AIF）→ [06](06_aif_send.md)
