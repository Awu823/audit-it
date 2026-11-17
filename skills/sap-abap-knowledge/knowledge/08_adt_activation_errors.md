# 08 · ADT 激活报错与修复（踩坑实录）

> 沉淀自 BOM 出站类激活过程中的连续报错与修复。这些坑在**类定义区（DEFINITION）**尤为突出，
> 是 ABAP 语法检查"逐阶段推进"导致的连环错误。**强烈建议通读**——同类报错可直接照方抓药。

## 背景：报错为何"连环出现"

ADT 语法检查是**分阶段**推进的：先解析类型 → 再解析语句 → 再匹配参数。前一阶段失败会**掩盖**后一阶段问题。
本套件修复过程正是"修好一个、暴露下一个"，最终按顺序排完：
1. 类型可见性 → 2. 类型定义方式 → 3. 匿名内联表类型 → 4. 参数名一致性。

---

## 坑 1：`Unable to interpret "AENR"`

**报错**：`Unable to interpret "AENR"`（类定义 line 147，方法参数类型）。

**根因**：方法参数用 `TYPE SORTED TABLE OF aenr WITH UNIQUE KEY aennr`——`aenr` 是**表**（DDIC 表），
作为**表行类型**在方法参数里无法解释。而同文件 `iv_aennr TYPE aennr`（`aennr` 是 **data element**）与
`SELECT ... FROM aenr`（表引用）都不报错——问题只在把**表结构当行类型**。

**修复**：改用**局部结构类型**，不依赖表结构作行类型。

```abap
TYPES: BEGIN OF <ECN_STATUS_TY_STRUCT>,
         aennr TYPE aennr,        " data element AENNR（已验证可用）
         aenst TYPE c LENGTH 1,   " AENST 为 1 字符
       END OF <ECN_STATUS_TY_STRUCT>.
```

- `TYPE aennr`（data element）**可行**；`TYPE aenr`（表结构）**不可行**——区别对待。
- `SELECT aennr, aenst FROM aenr`（表查询）**保留**——用表**列名**，不依赖表结构。
- `INTO CORRESPONDING FIELDS` 自动映射列名到局部结构组件。

---

## 坑 2：`Unable to interpret "ECN_STATUS_TY"`

**报错**：`Unable to interpret "ECN_STATUS_TY"`（方法参数引用局部类型）。

**根因**：`TYPES ecn_status_ty` 定义放在了 **`DATA` 声明之后**（`DATA bom_message` 与 `METHODS` 之间）。
ADT 单遍解析下，**该位置的类型未注册为可见**，方法参数引用时不可解释。
对比：顶部 `TYPES:` 块内定义的 `bom_header_ty` 等被 `DATA ... TYPE bom_header_ty` 成功引用——**TYPES 块内才可见**。

**修复**：把该 `TYPES` **移入类定义顶部已验证的 `TYPES:` 块**（与其它结构类型同级，位于所有 `DATA` 之前）。

```abap
TYPES:
  BEGIN OF bom_header_ty, ... END OF bom_header_ty,
  ...
  BEGIN OF <ECN_STATUS_TY_STRUCT>,
    aennr TYPE aennr,
    aenst TYPE c LENGTH 1,
  END OF <ECN_STATUS_TY_STRUCT>.
```

> **规则**：类定义区的类型定义**统一放顶部 `TYPES:` 块**（所有 `DATA`/`METHODS` 之前），
> 不要单独插在 `DATA` 之后。

---

## 坑 3：匿名内联表类型不可靠

**报错**：用户/编译器判断 `DATA(x) = VALUE SORTED TABLE OF aennr WITH UNIQUE KEY table_line( )`
与 `it_aenr_status TYPE SORTED TABLE OF ecn_status_ty WITH UNIQUE KEY aennr` 均为错误定义。

**根因**：**匿名内联表类型**（`VALUE SORTED TABLE OF <type>( )` / `TYPE SORTED TABLE OF <type>`）在
ADT/语法检查下不可靠，必须**单独定义命名 TYPES** 再引用。

**修复**：单独定义命名表类型，参数与 `VALUE` 构造都引用之。

```abap
TYPES:
  <ECN_STATUS_TY> TYPE SORTED TABLE OF <ECN_STATUS_TY_STRUCT> WITH UNIQUE KEY aennr,  " 供参数 + VALUE
  <ECN_KEY_TY>    TYPE SORTED TABLE OF aennr WITH UNIQUE KEY table_line.             " 供去重集

" 参数引用命名类型
it_aenr_status TYPE <ECN_STATUS_TY>
" 构造引用命名类型
DATA(<lt_aenr_status>) = VALUE <ECN_STATUS_TY>( ).
DATA(<ecn_set>)        = VALUE <ECN_KEY_TY>( ).
```

---

## 坑 4：`DATA(...) = VALUE STANDARD TABLE OF ...`

**报错**：`DATA(stko_stpo_mast) = VALUE STANDARD TABLE OF mast WITH EMPTY KEY( ).` 同样属匿名内联表类型。

**修复**：与既有 `DATA mast_all TYPE STANDARD TABLE OF mast WITH EMPTY KEY.` 一致——**声明区定义 + 主体 `CLEAR`**。

```abap
" 声明区（方法顶部，与其它 DATA 并列）
DATA <stko_stpo_mast> TYPE STANDARD TABLE OF mast WITH EMPTY KEY.
" 主体
IF <stko_stpo_range> IS NOT INITIAL.
  CLEAR <stko_stpo_mast>.
  SELECT ... FROM mast INTO CORRESPONDING FIELDS OF TABLE @<stko_stpo_mast> ...
ENDIF.
```

> **通用规则**：内联表类型（`VALUE ... TABLE OF`/`DATA(...) = VALUE ...`）一律改为
> **声明区 `DATA ... TYPE`**（或命名 `TYPES`）+ 主体 `CLEAR`/`VALUE #( )`。
> 检索所有 `VALUE (STANDARD|SORTED|HASHED) TABLE OF` 确保无残留。

---

## 坑 5：`The formal parameter "IV_AENR" does not exist`

**报错**：`The formal parameter "IV_AENR" does not exist. However, the parameter "IV_AENNR" has a similar name.`

**根因**：方法签名参数 `iv_aennr`（双 n），但调用处写了 `iv_aenr =`（单 n）——**拼写不一致**。
前几轮类型解析错误掩盖了此问题，类型修复后参数匹配阶段暴露。

**修复**：调用处参数名与签名**完全一致**。

```abap
is_ecn_valid( iv_aennr = key-aennr        " 与签名 IMPORTING iv_aennr 一致
              it_aenr_status = <status_tab> )
```

> **规则**：方法签名参数名与调用处必须逐字一致。建议先定义签名，调用处从签名复制参数名。

---

## 排障清单（激活报错快速排查）

| 报错特征 | 根因方向 | 修复 |
|---|---|---|
| `Unable to interpret "<表名>"` | 表结构作行类型 | 用局部结构 / data element，不引用表结构 |
| `Unable to interpret "<类型名>"` | 类型定义位置不可见 | 移入顶部 `TYPES:` 块（DATA 前） |
| 匿名内联表类型报错 | `VALUE ... TABLE OF` / 内联 `TYPE` | 命名 `TYPES` 或声明区 `DATA ... TYPE` + `CLEAR` |
| `formal parameter "X" does not exist... similar name` | 参数名拼写不一致 | 调用处与签名逐字一致 |
| `TYPE SORTED TABLE OF <data element>` 不可靠 | data element 作行类型 + 内联 | 命名 `TYPES` 表类型 |

## 预防性检查（激活前）

1. **grep 所有 `VALUE (STANDARD|SORTED|HASHED) TABLE OF`** → 应为空（无匿名内联表类型）。
2. **所有方法签名参数名**与调用处一致（`iv_`/`it_`/`is_`/`cs_`/`et_` 前缀规范）。
3. **类定义区类型**统一在顶部 `TYPES:` 块，`DATA`/`METHODS` 前。
4. **表结构 vs data element**：引用 data element（`TYPE aennr`）可，引用表结构（`TYPE aenr`）不行。
5. **命名类型优先**：任何表类型先 `TYPES xxx TYPE ...` 命名，再在参数/`VALUE`/`DATA` 引用。
