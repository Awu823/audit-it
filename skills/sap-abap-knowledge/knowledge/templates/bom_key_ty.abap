*"! 模板：DRF 出站对象键表类型 + ECN 校验类型（脱敏）
*"! 替换占位符：<KEY_STRUCT>/<KEY_TABLE_TY>/<ECN_STATUS_TY_STRUCT>/<ECN_STATUS_TY>/<ECN_KEY_TY>
*"! 注意：所有表类型必须【命名 TYPES】后再引用（ADT 匿名内联不可靠，见 08_adt_activation_errors.md）

    TYPES:
      " --- 对象键结构 ---
      BEGIN OF <KEY_STRUCT>,
        stlan TYPE stlan,   " BOM usage（用途）
        werks TYPE werks_d, " Plant（工厂）
        matnr TYPE matnr,   " Material（物料）
        stlal TYPE stlal,   " Alternative BOM（备选 BOM）
        stlty TYPE stlty,   " BOM Category（BOM 类别）
        aennr TYPE aennr,   " ECN（工程变更号）
        stlnr TYPE stnum,   " BOM 号（filter 预查数据，非键字段）
      END OF <KEY_STRUCT>,
      " 对象键表（SORTED UNIQUE）
      <KEY_TABLE_TY> TYPE SORTED TABLE OF <KEY_STRUCT>
        WITH UNIQUE KEY stlan werks matnr stlal stlty aennr,

      " --- ECN 校验类型 ---
      " 局部结构（data element，不依赖 aenr 表结构——见坑 1）
      BEGIN OF <ECN_STATUS_TY_STRUCT>,
        aennr TYPE aennr,        " data element AENNR
        aenst TYPE c LENGTH 1,   " AENST 为 1 字符
      END OF <ECN_STATUS_TY_STRUCT>,
      " 命名表类型（供方法参数 + VALUE 构造——见坑 3）
      <ECN_STATUS_TY> TYPE SORTED TABLE OF <ECN_STATUS_TY_STRUCT> WITH UNIQUE KEY aennr,
      <ECN_KEY_TY>    TYPE SORTED TABLE OF aennr WITH UNIQUE KEY table_line.
