# BOM → TARGET_SYSTEM 接口：用人话说的开发需求

> 来源：BOM Outbound FS v1.0
> 本文用自然语言描述需求，方便新人快速理解"我们要做什么、为什么做、怎么做"

---

## 一、一句话概括

> **把 SAP 里的生产 BOM（物料清单）数据，定时或手动推送到 TARGET_SYSTEM（海关管理系统），中间经过 MuleSoft 做格式转换。**

TARGET_SYSTEM 是海关管理系统，需要知道每个产品的 BOM 结构（包含哪些组件、各用多少量）来处理进出口报关。SAP 是数据源， nightly 23:00 批量推送，也支持手动按需推送。

---

## 二、整体流程（数据怎么走）

```
SAP (BOM 数据)
  │
  │  DRF 框架触发（手动 DRFOUT 或定时作业）
  │
  ▼
AIF_MSGID（我们的 DRF 出站实现）
  │  1. 找出变更的 BOM
  │  2. 读取完整 BOM 数据（MAST/STKO/STPO/MARA）
  │  3. 映射成 TARGET_SYSTEM 要的格式（17 个字段）
  │  4. 通过 AIF 发送
  │
  ▼
MuleSoft（中间件，只做格式转换：XML → JSON）
  │
  ▼
TARGET_SYSTEM（海关管理系统，负责合并多批次）
```

关键点：
- **值转换和过滤都在 SAP 侧完成**，MuleSoft 只做技术映射
- **每次调用都有响应**（成功/错误），通过 AIF 监控
- **TARGET_SYSTEM 负责合并多批次**（如果一次推送的数据太多，拆成多批，TARGET_SYSTEM 自己合并）
- **SAP 标准接口**：Bill of Material API (API_BILL_OF_MATERIAL_SRV; v=2)，需按本 FS 增强
- **数据访问**：无敏感/法律要求；MuleSoft 需即时响应；成功时消息经 MuleSoft 传递，无发送顺序要求；失败时 MuleSoft 或 MuleSoft→TARGET_SYSTEM 失败
- **消息转换**：XML 生成后需映射为 JSON（映射细节见 MW 文档）；TARGET_SYSTEM 数据格式已捕获；源字段 vs 目标字段映射在 MuleSoft 完成

---

## 三、什么时候触发推送

三种触发方式：

| 触发方式 | 谁触发 | 什么时候 | 过滤条件 |
|---|---|---|---|
| **初始加载** | 人工手动 | 站点上线时 | 工厂、BOM 用途 |
| **夜间批量** | 定时作业 | 每晚 23:00 | 物料、工厂、BOM 用途、生效日期（含变更指针） |
| **手动按需** | 人工手动 | 随时 | 物料、工厂、BOM 用途、ECN、生效日期 |

**DRF 选择参数**（用户在 DRFOUT 界面输入的条件）：
- 工厂（WERKS）：**必填**，默认 DEFAULT_WERKS（苏州）
- 物料（MATNR）：可选
- BOM 用途（STLAN）：**必填**，默认 1（生产 BOM）
- 备选 BOM（STLAL）：可选
- 生效开始日期（DATUV）：可选
- 生效结束日期（DATUB）：可选

---

## 四、什么 BOM 变更会触发推送

不是所有 BOM 变更都推送，只有以下变更才触发：

| 变更类型 | 具体内容 | 涉及表/字段 |
|---|---|---|
| Header 基本数量变化 | 数量、单位 | STKO: BMENG, BMEIN |
| Header 生效日期变化 | 开始/结束日期 | STKO: DATUV, DATUB |
| Item 组件数量/单位变化 | 数量、单位 | STPO: MEINS, MENGE |
| Item 新增/删除/修改组件 | 组件物料 | STPO 新增记录 |
| Item 组件生效日期变化 | 开始/结束日期 | STPO: DATUV, DATUB, AENNR |
| Item 组件损耗变化 | 损耗百分比/数量 | STPO: AUSCH |
| Item 工序损耗变化 | 工序损耗 | STPO: AVOAU |

**注意**：以上所有变更类型均**需要 ECN**（工程变更号），ECN 是触发推送的必要条件。

**简单说**：BOM 的 Header 数量/日期变了，或者 Item 的组件/数量/日期/损耗变了，就要推送。其他不重要的字段变更不推送。

---

## 五、ECN（工程变更号）处理

ECN 是工程变更号，BOM 变更通常伴随 ECN。处理逻辑：

1. **提取**：从 STKO/STPO 表中提取 ECN 号（AENNR）和生效日期（DATUV），AENNR 作为 ChangeMasterID / ECN_Number 写入推送消息
2. **校验**：只推送已释放的 ECN，未释放/被阻塞的 ECN 的 BOM 不推送（检查 AENR）
3. **未来生效日期**：DRF 按目标评估日期（默认 SY-DATUM）提取；如果 ECN 的 DATUV > SY-DATUM，显式传递 DATUV，让 TARGET_SYSTEM 知道"这个变更未来才生效"，TARGET_SYSTEM 会在本地排期切换

---

## 六、字段映射（SAP → TARGET_SYSTEM）

TARGET_SYSTEM 需要 17 个字段，其中 6 个是**必填**（M），11 个是**可选**（O）：

**必填字段（M）：**
| # | SAP 来源 | TARGET_SYSTEM 字段 | 说明 |
|---|---|---|---|
| 1 | MAST-MATNR | copExgNo | BOM Header 物料（含成品/半成品） |
| 2 | STPO-IDNRK | copImgNo | 组件物料号 |
| 3 | STPO-MENGE | decCm | 组件数量 |
| 4 | STKO-BMENG | copExgQty | BOM Header 数量 |
| 5 | STPO-AUSCH | OperationScrap | 工序损耗 |
| 6 | STPO-KAUSF | ComponentScrap | 组件损耗 |

**可选字段（O）：**
| # | SAP 来源 | TARGET_SYSTEM 字段 | 说明 |
|---|---|---|---|
| 7 | STPO-DATUV | startDate | 组件生效开始日期 |
| 8 | STPO-DATUB | endDate | 组件生效结束日期 |
| 9 | STKO-ANDAT | bomCreation | BOM 创建日期 |
| 10 | MAST-STLAL | alternativeBom | 备选 BOM 号 |
| 11 | MAST-STLNR | bomNo | BOM 编号 |
| 12 | AENR-AENNR | changeNo | 工程变更号 |
| 13 | MAST-STLAN | useTo | BOM 用途 |
| 14 | STKO-DATUV | bomStartDate | Header 生效开始 |
| 15 | STKO-DATUB | bomEndDate | Header 生效结束 |
| 16 | MARA-MEINS | copExgUnit | 成品/半成品单位 |
| 17 | STPO-MEINS | copImgUnit | 组件单位 |

---

## 七、错误处理

**原则**：出错了不能在 AIF 里直接重处理，要重新手动触发 DRFOUT。

错误覆盖全流程：
1. DRF 消息生成失败
2. 发送到 MuleSoft 失败
3. MuleSoft 处理失败
4. MuleSoft → TARGET_SYSTEM 失败
5. TARGET_SYSTEM 处理失败

**AIF 错误分类维度**：
- TARGET_SYSTEM 目标系统
- 错误类型
- Material（物料）
- Plant（工厂）
- 字段与值（如相关）

**AIF 错误对象**：
- 必填：Production BOM
- 附加：Parent Material (MATNR)、Plant (WERKS DEFAULT_WERKS)、Component Item (IDNRK)、ECN (AENNR)

**错误内容**：错误码（技术码）、错误描述、错误详情（失败字段/值/技术信息）

**其他要点**：
- MuleSoft 错误日志保留 21 天
- 目标系统不允许在出错时修正消息内容

---

## 八、监控与告警

- AIF 是统一监控入口，Business 和 IT 都看 AIF（AIF 为 ERP 标准组件，提供接口监控与告警）
- 集成返回 Green/Red（通过 MuleSoft 同步响应，< 60 秒）
- 支持批量/单条重处理失败消息
- **用户通知**（邮件 + SAP 告警）包含：接口类型/名称、TARGET_SYSTEM 源/目标、基于错误码的动态说明、GUID、/AIF/ERR 链接
- 邮件路由依据：接口类型/名称、TARGET_SYSTEM 源/目标、错误类型

---

## 九、授权

- 手动触发 DRFOUT：基于 SAP Plant code 授权（Auth Object: M_MATE_WRK）
- AIF 监控：需要创建授权对象，限制到字段级 — TARGET_SYSTEM 目标系统

---

## 十、性能与运维

- 端到端同步响应 < 60 秒
- 每天平均 300 文档，峰值 1000 文档
- XML 单文件最大 2000 行，超量拆分为多批次（例：3999 行 → 2000 + 1999）
- MuleSoft 错误日志保留 21 天
- 审计：完整审计历史记录于 DRF outbound 执行日志与 AIF 消息日志
- 归档：不适用；电子签名：不适用；ICFR：不适用

---

## 十一、站点上线数据加载

- 本接口用于 SITE_CODE 站点上线割接期数据加载
- 最小 300/天，最大 1000/天

---

## 十二、错误场景（测试）

| 场景 | 预期 |
|---|---|
| 前台手动发送 (DRFOUT) | 复制到 Middleware → 发送 TARGET_SYSTEM → 成功消息 → 日志记录 |
| 后台定时发送 (DRFOUT) | 同上 |
| 前台/后台失败 | 复制失败 → 错误消息 → 日志记录 |
| 重执行 (DRFOUT) | 成功复制 → 成功消息 → 日志记录 |

---

## 十三、关联文档

| 文档 | 用途 |
|---|---|
| PROJECT_CODE TARGET_SYSTEM Integration | AIF 核心配置、DRF/AIF 逻辑 |
| BOM Outbound DS Doc | MW 映射 |
| BOM Outbound FS Attachment | 字段映射附件 |
| SAP 帮助：API_BILL_OF_MATERIAL_SRV v2 | SAP 标准 BOM API |

---

## 十四、DRF/AIF 配置速查

| 配置项 | 值 |
|---|---|
| DRF Replication Model | `DRF_BIZ_OBJ` |
| DRF Outbound Implementation | `AIF_MSGID` |
| AIF Namespace | `AIF_NS` |
| AIF Interface Name | `AIF_IFNAME` |
| AIF Version | `1` |
| Logical Port | `AIF_LOGICAL_PORT` |
| 对象键 | BOM type / Plant / Material / BOM alternative / ECN |


---

*本文档用自然语言描述 FS 需求，帮助新人快速理解 BOM → TARGET_SYSTEM 接口的业务背景和实现要点。*