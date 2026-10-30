# ABAP 7.4 / 7.5 New Syntax — Consolidated Notes

> 本目录是从 `SAP-ABAP-7.5-syntax-main` 原始笔记中**去重后**提炼的独有价值内容。
> 与官方 cheat sheets 重复的主题（内联声明、`FOR`/`VALUE`/`REDUCE`、`CORRESPONDING`、
> `CONV`/`NEW`/`COND`、`FILTER`、`FOR ALL ENTRIES`、`INNER JOIN`、`OPEN SQL` 等）
> 已**移除**，请直接查阅 `references/abap/` 下对应 cheat sheet。
>
> 两份官方 PDF 也一并保留在此目录：`ABAP 7.40 Quick Reference` 与 `new-features-in-abap-7-4`。

---

## 目录

- [1. ABAP 7.5 SELECT 的 FIELDS 关键字](#1-abap-75-select-的-fields-关键字)
- [2. SEGMENT 函数](#2-segment-函数)
- [3. COMMIT WORK vs COMMIT WORK AND WAIT](#3-commit-work-vs-commit-work-and-wait)
- [4. Open SQL vs Native SQL：能力与限制](#4-open-sql-vs-native-sql能力与限制)
- [5. ABAP 调用外部 REST 服务（IF_HTTP_CLIENT）](#5-abap-调用外部-rest-服务if_http_client)
- [6. 内表转 JSON（/UI2/CL_JSON）](#6-内表转-jsonui2cl_json)
- [7. Eclipse 代码编辑器快捷键](#7-eclipse-代码编辑器快捷键)
- [8. 经典 MIGO/MIRO 批量过账 Include 骨架](#8-经典-migomiro-批量过账-include-骨架)
- [9. 学习资源链接](#9-学习资源链接)

---

## 1. ABAP 7.5 SELECT 的 FIELDS 关键字

- 7.5 在 `SELECT` 中新增 **`FIELDS`** 关键字，用于显式指定选择列。
- 始终把 `INTO` 子句放在 `SELECT` 语句**最后**（7.5 引入 `UNION`/`UNION ALL`，这些关键字只能在 `INTO` 之后使用；`WHERE` 条件须在 `INTO` 之前）。

```abap
SELECT FROM ekpo
       FIELDS ebeln, ebelp, werks, netpr,
              CASE WHEN netpr > 100
                   THEN 'High Value'
                   ELSE 'Low Value'
              END AS pur_type
       INTO TABLE @DATA(it_data).
```

**`FIELDS` 的好处**：
1. 提升代码可读性。
2. 在 `SELECT` 语句内启用列名模糊搜索（`CTRL + SPACE`），老版本对 `SELECT` 无模糊搜索。

## 2. SEGMENT 函数

按分隔符拆分字符串，按索引取片段（索引**可为负数**，-1 表示最后一段；越界抛异常 `CX_SY_STRING_PAR_VAL`）。

```abap
DATA(lv_Result) = segment( val = 'S,A,T,H,I,S,H', index = 1, sep = ',' ).  " -> S
DATA(lv_Result) = segment( val = 'S,A,T,H,I,S,H', index = -1, sep = ',' ). " -> H

" 越界需 try/catch，否则 dump
TRY.
    DATA(lv_x) = segment( val = 'S,A,T', index = 9, sep = ',' ).
  CATCH cx_sy_string_par_val.
    WRITE 'No index'.
ENDTRY.

" 遍历所有片段
DATA(lv_r) TYPE string.
DO.
  TRY.
      lv_r = segment( val = 'S,A,T,H', index = sy-index, sep = ',' ).
      WRITE / lv_r.
    CATCH cx_sy_string_par_val.
      EXIT.
  ENDTRY.
ENDDO.
```

## 3. COMMIT WORK vs COMMIT WORK AND WAIT

| 语句 | 模式 | 行为 | 适用 |
|---|---|---|---|
| `COMMIT WORK` | 异步 | 触发数据库更新后立即继续执行下一条语句 | 速度更快；但若后台更新失败，程序可能不知道，产生不一致数据 |
| `COMMIT WORK AND WAIT` | 同步 | 等待数据库更新完成并收到确认后才继续 | 更安全；可即时捕获更新失败，保证数据一致 |

```abap
UPDATE ztable SET field = 'value' WHERE condition.
COMMIT WORK.            " 异步，程序继续
WRITE: / 'Update triggered'.

UPDATE ztable SET field = 'another value' WHERE condition.
COMMIT WORK AND WAIT.   " 同步，程序等待
WRITE: / 'Update completed'.
```

## 4. Open SQL vs Native SQL：能力与限制

**Native SQL 限制**（相对 Open SQL）：
1. 无固定值与计算列
2. 无 `CASE` 表达式
3. 无 `RIGHT OUTER JOIN`
4. 无 `UNION`
5. `SELECT` 内无子查询

**新版 Open SQL 特性**：
1. SQL `CASE`
2. `COALESCE`
3. 算术表达式：`+ - * /`
4. `CAST` 类型转换
5. 算术函数：`DIV / MOD / ABS / ROUND / FLOOR / CEIL`
6. 聚合函数：`SUM / COUNT / AVG`
7. 字符串拼接：`&&`
8. `RIGHT OUTER JOIN`
9. 最大连接表数提升至 50
10. 子查询数量上限提高
11. `UNION` / `UNION ALL`：把第二个查询的结果追加到第一个查询填充的内表

## 5. ABAP 调用外部 REST 服务（IF_HTTP_CLIENT）

用 `IF_HTTP_CLIENT` + `IF_HTTP_ENTITY` 调用外部 REST API，可结合屏幕单选按钮切换端点、拼接 JSON 请求体。

```abap
REPORT ysat_dtest.
PARAMETERS : p_e RADIOBUTTON GROUP rad USER-COMMAND rad,
             p_r RADIOBUTTON GROUP rad.
DATA : lv_service_url TYPE string,
       lo_http_client  TYPE REF TO if_http_client,
       lo_http_request TYPE REF TO if_http_entity.

START-OF-SELECTION.
  lv_service_url = |https://example.com/reimbursementapi/entityset|.
  " 拼接 JSON 请求体（可用 CONCATENATE 或字符串模板）
  " 创建客户端：cl_http_client=>create_by_url(...)
  " 发送请求：lo_http_client->request->set_header_field(...)
  "          lo_http_client->request->set_cdata( gs_json )
  "          lo_http_client->send( )
  " 读取响应：lo_http_client->receive( ) -> response->get_cdata( )
```

> 完整可运行示例（含屏幕组控制 `MODIF ID`、日期格式化、`api_key` 组装）见原始笔记
> `SAP ABAP-REST-Service-Test`。更深入的 REST 处理落地（含 ZIP 包）见
> `External API Integration in SAP using REST handlers - PART 2 _ SAP Blogs.zip`（原始仓库中）。

## 6. 内表转 JSON（/UI2/CL_JSON）

用 `types` 定义结构/内表（字段名以 `_` 开头可对齐外部 JSON 键），再经 `/UI2/CL_JSON=>SERIALIZE` 转换。

```abap
TYPES : BEGIN OF lty_body,
          _name            TYPE string,
          _account_number  TYPE string,
          _annual_revenue  TYPE string,
          _payment___terms TYPE string,
        END OF lty_body.
TYPES : BEGIN OF lty_request,
          method       TYPE string,
          url          TYPE string,
          reference_id TYPE string,
          body         TYPE lty_body,
        END OF lty_request.
DATA(ls_request) = VALUE lty_request(
  method       = 'get'
  url          = 'https://example.com'
  reference_id = 'New request'
  body         = VALUE lty_body( _name = 'X' _account_number = '123' ) ).
" DATA(lv_json) = /ui2/cl_json=>serialize( data = ls_request ).
```

## 7. Eclipse 代码编辑器快捷键

| 快捷键 | 作用 |
|---|---|
| `SHIFT + CTRL + <` | 注释当前行 |
| `SHIFT + CTRL + >` | 取消注释当前行 |

## 8. 经典 MIGO/MIRO 批量过账 Include 骨架

ZFI MIGO/MIRO 自动过账的 `_TOP` include 通常包含：`TABLES: mkpf, ekpo, sscrfields`，
最终输出结构 `gty_final`（含 `ebeln/ebelp/matnr/menge/zuonr/xblnr/mwskz/netpr/lifnr/werks/vbeln/gjahr/msg/icon` 等字段），
以及 `cl_gui_alv_grid` 容器 `g_container`。可用于 ALV 展示、逐行校验、批量 MIRO/MIGO 场景。

## 9. 学习资源链接

- ABAP 7.4 新语法视频（YouTube）：`https://www.youtube.com/watch?v=gFfqoe_jX7o&list=PLQh9AF8VRrlvOBJZCV2T9-qmTDOZKCRxa`
- SAP DevCenter 学习课程：`https://learning.sap.com/courses?page=1&query=ABAP`
- 异常类课程：`https://learning.sap.com/courses/deepening-your-abap-programming-knowledge/working-with-exception-classes_acd9568c-be4e-445a-a454-14c6f2cfcd2e`
