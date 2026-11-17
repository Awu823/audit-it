# 10 · 生产订单（Manufacturing / Process Order）出站模式

> 沉淀自生产订单出站实现（`<CL_OUT>`，3,300+ 行）。这是与 BOM 出站**完全不同**的第二套接口范式，
> 核心差异在**变更判定方式**（快照比对而非 ECN 过滤）、**映射方式**（标准 PP 映射而非手工字段映射）、
> **过滤方式**（配置规则表而非对象级过滤）、**发送方式**（SOAP 代理而非 `/AIF/SEND_WITH_PROXY`）。
> 所有对象、表、类名已脱敏为通用占位符（见文末占位符表）。

## 一、业务对象与驱动键

- 业务对象：**生产订单**（`AUFNR`）。
- DRF 复制对象键：`<KEY_STRUCT>`（**仅 `AUFNR` 一列**，与 BOM 的 6 列复合键不同）。
- 目标系统：**MES**（`<TARGET_SYS>`），经 AIF（namespace `<AIF_NS>`、interface `<AIF_IFNAME>`、port `<AIF_LOGICAL_PORT>`）发送。
- 载荷：`PPINT_MFGORD_EXECT_REQ_V2`（标准 PP 制造订单执行请求 V2）。

## 二、三层数据边界（数据字典）

与 BOM 一样是"批级缓冲 → 对象级切片 → 出站载荷"三层，但生产订单的数据源表**完全不同于 BOM**：

| 边界 | 前缀 | 生命周期 | 关键成员 | 说明 |
|---|---|---|---|---|
| 批级共享缓存 | `mt_` | 整个复制运行期 | `mt_caufv_bt`(CAUFVDB 抬头)、`mt_afvg_bt`(AFVGB 工序)、`mt_resb_bt`(RESBB 组件预留)、`mt_afpo_bt`(AFPOB 订单项)、`mt_affl_bt`(工序关系)、`mt_rserob`(序列号)、`mt_afabb`(工序确认)、`mt_affhd_bt`(关系抬头)、`mt_jstat_by_aufnr`(JEST 状态) | 批读一次，全批共享 |
| 对象级切片 | `lt_` | 单个订单映射期间 | `lt_caufv_bt`、`lt_afvg_bt`、`lt_resb_bt`、`lt_afpo_bt`、`lt_affl_bt`、`lt_affhd_bt`、`lt_afabb` | 按 `aufnr` DELETE 切片 |
| 出站载荷 | `ms_` | 映射产出 → 发送清场 | `ms_manufacturing_order_v2`、`ms_runtime_parameter_ext` | V2 载荷 + 运行时上下文 |

> 生产订单的主数据源是 **PP 相关表**（CAUFV/AFPO/AFFL/AFVG/RESB/AFABB），而非 BOM 的 MAST/STKO/STAS/STPO。
> 这是"主数据出站"（BOM）与"事务数据出站"（订单）的本质差别。

## 三、模式 1：快照比对式变更判定（`change_is_valid_for_drf`）

**这是本接口最核心、与 BOM 完全不同的模式。** BOM 靠 ECN 状态过滤决定是否发送；生产订单则**把当前订单与"上次发送快照"逐项比对**，有实质差异才置位变更标志。

### 3.1 判定链路（7 处能置位 `change_is_valid`）

| 步骤 | 置位条件 | 置位值 | 消息 |
|---|---|---|---|
| ① 取数闸门 | `BAPI_PROCORD_GET_DETAIL` 返回空抬头 | `'BAPI error - replication forced'` | 007 |
| ② 快照锚点 | `/rgs/p_dcb_aif_1` 查不到该订单历史发送记录 | `'New Order - never before sent'` | 032 |
| ③ 抬头快照 | `/rgs/p_dcb_po_s` 按 msgguid 查不到抬头快照 | `err_po_s` | 008 |
| ④ 工序快照 | `/rgs/p_dcb_po_58` 查不到工序快照 | `err_55` | 008 |
| ⑤ 组件快照 | `/rgs/p_dcb_po_60` 查不到组件快照 | `err_57` | 008 |
| ⑥ 新工序 | AIF 快照中不存在该工序 | `'New operation'` | 030 |
| ⑦ 删工序 | SAP 当前不存在该工序（AIF 有） | `'New operation v2'` | 029 |

> **关键**：`analyze_changes_by_chg_pointer` 调用本方法，**仅当返回非空**才 `INSERT` 到 `ct_changed_objects`。
> 因此 `change_is_valid_for_drf` 是变更指针路径的**必要闸门**。

### 3.2 快照表（上次发送的持久化快照）

| 表 | 内容 | 比对对象 |
|---|---|---|
| `<SNAP_AIF>` | 发送历史（按 `aufnr + business_system`） | 定位上次发送 GUID（按 `create_date/create_time` 倒序取 INDEX 1） |
| `<SNAP_HEAD>` | 抬头快照 | 数量 / 计划日期时间 / 排程日期时间 |
| `<SNAP_OPER>` | 工序快照 | 资源、工序存在性 |
| `<SNAP_COMP>` | 组件快照 | 物料 / 批次 / 数量 / UoM |

### 3.3 常见坑（源码逐行核对结论）

1. **被注释的比对不触发复制**：数量、计划/排程日期、资源、新组件、物料、批次、UoM 变更的赋值**均被注释**（`Disabled 20211209`）——这些比对**只写应用日志，不改变判定**。实际能置位 `change_is_valid` 的只有上表 7 处。
2. **`CLEAR change_is_valid` 的副作用**：状态命中（GLOCK/TECO/YLCK/用户状态/非 REL-PREL）处 `CLEAR` 后 `RETURN`；但"工序未释放"处 `CLEAR` 后**不 RETURN**，会**清空此前循环已置位的判定并继续**——同一订单只要有一个未释放工序，前面已置位的 `'New operation'` 会被清掉。
3. **浮点精确比较**：数量用 `EQ` 精确比较，微小误差会导致漏检/误触发（当前因赋值被注释暂不显现）。
4. **`analyze_changes_by_mdg_cp` 通常为空实现**：MDG 合并场景下变更对象不会被发现（需确认该路径是否废弃）。

## 四、模式 2：配置规则表过滤（工序白名单 + no_send）

生产订单的**工序**按配置规则表 `<RULE_TABLE>` 过滤，决定哪些工序/阶段发给 MES：

```
SELECT * FROM <RULE_TABLE>
  WHERE auart = 订单类型 AND werks = 工厂 AND business_system = 接收系统
```

- **拆两表**：`no_send` 为空的进"可发送"表；`no_send` 非空的进"禁发"表。
- **通配符语义**：若首行 `phseq` 为空，表示该工厂/订单类型/业务系统**允许全部工序**（`CLEAR rt_rc`）。
- **白名单过滤**：命中则保留关联行；未命中则 `DELETE` 该工序及其关联表（`affl`/`afabb`/`affhd`）。
- **`no_send` 剔除**：再删一遍关联表与工序表。

> **坑**：若 `SELECT` 列表漏了 `no_send` 列，`INTO CORRESPONDING FIELDS` 不会填充它，`no_send = 'X'` 的 `READ` 条件**恒不成立**，第二道剔除**完全不生效**。

## 五、模式 3：订单状态闸门（发送前终审）

**发送前**与**变更判定时**都要做订单状态检查（`order_status_is_valid_for_drf`）：

- 查 `mt_jstat_by_aufnr`（JEST 状态表）命中 **TECO / GLOCK / YLCK**；
- 用 `STATUS_TEXT_EDIT` 查**用户状态**含 `YLCK`；
- 任一命中 → 订单无效，不发送。

> 变更判定阶段（`change_is_valid_for_drf`）与发送前终审（`send_message`）**两道状态闸门**，保证"已技术完成/锁定/关闭"的订单不发给 MES。

## 六、模式 4：标准 PP 映射（`<PP_MAPPING>`）

与 BOM 的**手工逐字段映射**（`map_bom_header`/`map_bom_item`）不同，生产订单调用 **SAP 标准 PP 映射类**一键生成 V2 载荷：

```abap
<PP_MAPPING>=>map_mfgorder_v2( ... ).   " 标准映射 + 定制字段补齐
```

映射后再做**定制补齐**：

| 补齐项 | 处理 | 说明 |
|---|---|---|
| 物料号 | `CONVERSION_EXIT_MATN1` INPUT 与 OUTPUT | 内外码转换（成品 + 组件） |
| 成本中心 / WBS | `cobrb` | 抬头补充 |
| 主/次订单 | KV 表 `LeadingOrder` / `SuperiorOrder` | 订单层级 |
| 用户字段 | `afvu` / `afvc` / `afvv` + `TCN01_READ` 标准文本 | 工序增强字段 |
| 日期时间 | `convert_timestamp`（工厂时区 → UTC） | 时区转换 |

## 七、模式 5：SOAP 代理发送（与 `/AIF/SEND_WITH_PROXY` 不同）

生产订单用**代理对象**直接发送 SOAP（而非 BOM 的 `/AIF/SEND_WITH_PROXY`）：

```
CREATE OBJECT lr_proxy ...   " 代理对象，取 if_wsprotocol_message_id
```

发送块关键点（`send_message`）：

1. **三道硬守卫**（都在任何发送动作前 `RETURN`）：`get_data_change_flag` 为空、`ms_manufacturing_order_v2` 为空、`ct_obj_rep_sta` 读不到 INDEX 1。
2. **`repstatus = 'SN'` 位于 `TRY...ENDTRY` 之外**：AIF 失败或 `cx_ai_system_fault` 被 `CATCH` 捕获后，订单**仍被标记为已发送**——这是"失败被误标成功"的直接成因。
3. **失败分支常为空**：`IF sy-subrc NE 0 AND sy-subrc NE 1.` 体内可能**没有任何语句**，`error_string`/`error_long_text` 被接收但从不使用。
4. **只读 `ct_obj_rep_sta` 的 INDEX 1**：DRF 批量传多对象时**只发第一个**，其余漏发（风险点）。
5. **代理创建异常后的隐患**：`lo_wsprotocol_message_id` 保持初始，后续 `->get_message_id( )` 触发 `CX_SY_REF_IS_INITIAL`（非 `cx_ai_system_fault`），不被 `CATCH` 捕获 → 直接中止 `send_message`。
6. **`set_distribution_status` 可能不生效**：内部开关初始化为 `space`，`I0048`（DISB）状态从不置位。

## 八、模式 6：变更分析两条补充路径

| 路径 | 说明 |
|---|---|
| `analyze_changes_by_others` | 非 CP 模式（初始/手动）：按 `JCDS` 状态变更取数（常取**最近一天** `sy-datum - 1`），过滤 `FOR ALL ENTRIES IN @jcds_tab` |
| `analyze_changes_by_mdg_cp` | MDG 变更指针：常为空实现（`break struzikp.`），不产生对象 |

## 九、占位符约定（替换为实际命名）

| 占位符 | 含义 | 本次项目实例 |
|---|---|---|
| `<CL_OUT>` | 生产订单出站适配类 | `/RGS/CL_P_DCB_DRF_PROCORD_OUT` |
| `<KEY_STRUCT>` | 对象键结构（仅 AUFNR） | `comes_s_drf_prod_key` |
| `<AIF_NS>` / `<AIF_IFNAME>` / `<AIF_IFVER>` / `<AIF_LOGICAL_PORT>` | AIF 命名空间/接口/版本/逻辑端口 | `YPMES` / `YOMES_PO` / `1` / `YMESPOOUT` |
| `<TARGET_SYS>` | 目标系统名 | `MES` |
| `<RULE_TABLE>` | 工序过滤规则表（phseq 白名单 + no_send） | `/rgs/p_dcb_po_rt` |
| `<SNAP_AIF>` / `<SNAP_HEAD>` / `<SNAP_OPER>` / `<SNAP_COMP>` | 发送历史/抬头/工序/组件快照表 | `/rgs/p_dcb_aif_1` / `/rgs/p_dcb_po_s` / `/rgs/p_dcb_po_58` / `/rgs/p_dcb_po_60` |
| `<PP_MAPPING>` | 标准 PP 映射类 | `cl_ppint_soa_mfg_ord_mapping` |
| `<PAYLOAD_V2>` | V2 出站载荷结构 | `ppint_manufacturing_order_v2` |

> 数据流图与逐行核对说明见项目 `docs/part1-4.md`（5 张 Mermaid 图）；完整源码见 `references/ZCL_DRF_REF_PROCORD_OUT.abap`。
