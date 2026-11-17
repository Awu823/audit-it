*"! <p class="shorttext synchronized">DRF BOM 出站：业务处理单例（S4H → TARGET_SYSTEM）</p>
*"!
*"! 承载全部业务逻辑：变更分析、过滤、批量取数、消息映射、AIF 发送、结果回写。
*"! 由框架适配层 ZCL_M1T_DCN_BOM_OUT 通过 CLASS-DATA 单例引用调用。
*"! 对应 FS：BOM SAP to TARGET_SYSTEM interface (DRF_BIZ_OBJ / AIF_MSGID)
CLASS zcl_drf_ref_bom_change DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

*"! BOM 对象键表类型
    TYPES:
      BEGIN OF bom_key_ty,
        stlan TYPE stlan,   " BOM usage
        werks TYPE werks_d, " Plant
        matnr TYPE matnr,   " Material
        stlal TYPE stlal,   " Alternative BOM
        stlty TYPE stlty,   " BOM Category
        aennr TYPE aennr,   " ECN
        stlnr TYPE stnum,   " BOM 号（filter 预查数据，非键字段）
      END OF bom_key_ty,
      key_table_ty TYPE SORTED TABLE OF bom_key_ty
               WITH UNIQUE KEY stlan werks matnr stlal stlty aennr.
    DATA runtime_parameter_ext TYPE drf_s_runtime_parameter_ext.

    METHODS analyze_changes_by_chg_pointer
      IMPORTING it_change_pointer  TYPE drf_t_bdcp
      EXPORTING et_changed_objects TYPE key_table_ty
                es_stat_info       TYPE drf_s_stat_info
      RAISING   cx_drf_analyze_changes
                cx_drf_exception.

    METHODS analyze_changes_by_others
      EXPORTING et_changed_objects TYPE key_table_ty
                es_stat_info       TYPE drf_s_stat_info
      RAISING   cx_drf_analyze_changes
                cx_drf_exception.

    METHODS enrich_filter_criteria
      IMPORTING it_external_criteria     TYPE rsds_trange
      EXPORTING es_stat_info             TYPE drf_s_stat_info
                et_add_external_criteria TYPE rsds_trange
      RAISING   cx_drf_exception.

    METHODS read_complete_data
      CHANGING ct_relevant_objects TYPE key_table_ty
      RAISING  cx_drf_process_messages
               cx_drf_exception.

    METHODS map_data2message
      IMPORTING ir_relevant_object TYPE REF TO data
      RAISING   cx_drf_process_messages
                cx_drf_exception.

    METHODS send_message
      IMPORTING is_file_info    TYPE drf_s_file_info
                iv_object_count TYPE drf_package_size
      EXPORTING et_file_data    TYPE drf_t_file_oi_content
                et_message      TYPE drf_t_message
      CHANGING  ct_obj_rep_sta  TYPE drf_t_obj_rep_sta_full
      RAISING   cx_drf_process_messages
                cx_drf_exception.

    METHODS finalize
      IMPORTING it_erroneous_objects     TYPE key_table_ty
                it_relevant_objects      TYPE key_table_ty
                iv_repeated_initial_run  TYPE boole_d
      EXPORTING ev_delete_change_pointer TYPE boole_d.

  PRIVATE SECTION.

*" --- AIF 接口参数（按 FS 勘误 3：BOM 使用 ManufacturingProdnVersInfo_Out 出站服务，
*"     对齐参照实现 /RGS/CL_P_DCB_DRF_PRODVER_OUT：AIF_NS 命名空间 + ManufacturingProdnVersInfo_Out 服务）---
    CONSTANTS gc_ns            TYPE /aif/ns        VALUE 'AIF_NS'       ##NO_TEXT.
    CONSTANTS gc_ifname        TYPE /aif/ifname    VALUE 'AIF_IFNAME'    ##NO_TEXT.  " ManufacturingProdnVersInfo_Out 出站服务
    CONSTANTS gc_ifver         TYPE /aif/ifversion VALUE '1'           ##NO_TEXT.
    CONSTANTS gc_logical_port  TYPE string         VALUE 'AIF_LOGICAL_PORT'  ##NO_TEXT.
    CONSTANTS gc_matgrp_service TYPE string       VALUE 'ManufacturingProdnVersInfo_Out' ##NO_TEXT.
    CONSTANTS gc_msgid         TYPE symsgid        VALUE 'AIF_MSGID'  ##NO_TEXT.

*" --- BOM 变更指针相关常量 ---
    CONSTANTS gc_cp_tabname_mast TYPE cdtabkey   VALUE 'MAST'  ##NO_TEXT.
    CONSTANTS gc_cp_tabname_stko TYPE cdtabkey   VALUE 'STKO'  ##NO_TEXT.
    CONSTANTS gc_cp_tabname_stpo TYPE cdtabkey   VALUE 'STPO'  ##NO_TEXT.

*" --- ECN 状态常量 ---
    CONSTANTS gc_ecn_status_released TYPE aenst VALUE '2' ##NO_TEXT.  " '2'=Released

*" --- 默认过滤条件常量（FS §4） ---
    CONSTANTS gc_default_werks TYPE werks_d VALUE 'DEFAULT_WERKS' ##NO_TEXT.  " FS §4 默认 Plant
    CONSTANTS gc_default_stlan TYPE stlan   VALUE '1'   ##NO_TEXT.  " FS §4 默认 BOM Usage

*" --- CDOBJID 字段长度常量（对齐 DDIC 主键长度） ---
    " MAST 主键：MATNR(18)+WERKS(4)+STLAN(1)+STLAL(2)；STKO/STPO：STLTY(1)+STLNR(8)。
    " 若字段长度变更，仅改此处即可，避免偏移硬编码错位。
    CONSTANTS gc_len_matnr TYPE i VALUE 18 ##NO_TEXT.
    CONSTANTS gc_len_werks TYPE i VALUE 4  ##NO_TEXT.
    CONSTANTS gc_len_stlan TYPE i VALUE 1  ##NO_TEXT.
    CONSTANTS gc_len_stlal TYPE i VALUE 2  ##NO_TEXT.
    CONSTANTS gc_len_stlnr TYPE i VALUE 8  ##NO_TEXT.

*" --- 量级控制常量（FS §14：站点上线割接期最小 300/天，最大 1000/天） ---
    " analyze_changes_by_others（Initial / 手动按需）单次取数的对象上限。
    " 对齐 FS §14 最大 1000 文档/天，防止无界面输入时按默认条件全量扫描超限。
    CONSTANTS gc_initial_max_rows TYPE i VALUE 1000 ##NO_TEXT.
    CONSTANTS gc_initial_min_rows TYPE i VALUE 300  ##NO_TEXT.  " FS §14 下限

    " --- TARGET_SYSTEM 消息结构（FS §7 的 17 字段） ---
    " 本地结构 bom_header_ty / bom_item_ty：SAP 侧取数缓冲（MAST/STKO/STPO/MARA 源字段），
    " 仅用于 map_data2message 的中间装配；
    " AIF 出站消息结构 aif_bom_message_ty 直接采用标准类型 ppint_mfg_prodn_vers_inf
    "（AIF 服务 ManufacturingProdnVersInfo_Out 的消息类型，对齐参照实现
    " /RGS/CL_P_DCB_DRF_PRODVER_OUT~map_data2message 与 /AIF/SEND_WITH_PROXY 的 sap_struct）。
    "
    " ppint_mfg_prodn_vers_inf 组件落点（对应 map2xml.md 的 XML 元素）：
    "   - production_version_information（ppint_prodn_vers_information 表）：
    "       ID01 copExgNo   → material
    "       ID07 alternativeBom → bill_of_material_variant
    "       ID10 useTo      → bill_of_material_variant_usage
    "   - 根层级 BOM Header 组件：
    "       ID08 bomNo        → bill_of_material
    "       ID09 changeNo     → bom_header_ecn
    "       ID11/ID12        → bom_extra_data[]-bom_validity_start/end_date
    "       ID13 copExgQty   → quantity_in_base_unit
    "       ID14 copExgUnit  → base_unit
    "       ID17 componentScrap → 组件损耗（经组件分配行携带）
    "   - bill_of_operations_activity_ne（工序网络元素）→ activity_co（组件分配）：
    "       ID02 copImgNo → bill_of_material_component
    "       ID03 decCm    → bill_of_material_item_quantity-content
    "       ID04/ID05    → validity_start_date / validity_end_date
    "       ID15 copImgUnit → bill_of_material_item_quantity-unit_code
    "   - ID06 bomCreation（STKO-ANDAT）与 ID16 operationScrap（STPO-AVOAU）：
    "       XML 无标准落点（见 map2xml.md §3.3），本地结构保留字段，由 MuleSoft 侧映射/补默认值。
    TYPES:
      BEGIN OF bom_header_ty,
        cop_exg_no        TYPE matnr,
        bom_creation      TYPE datuv,
        alternative_bom   TYPE stlal,
        bom_no            TYPE stnum,
        change_no         TYPE aennr,
        bom_usage         TYPE stlan,
        header_start_date TYPE datuv,
        header_end_date   TYPE datub,
        header_qty        TYPE bmenge,
        header_unit       TYPE meins,
      END OF bom_header_ty,
      BEGIN OF bom_item_ty,
        cop_img_no      TYPE idnrk,
        quantity        TYPE kmpmg,
        valid_from      TYPE datuv,
        valid_to        TYPE datub,
        component_unit  TYPE meins,
        operation_scrap TYPE ausch,
        component_scrap TYPE ausch,
      END OF bom_item_ty,
      bom_items_ty TYPE STANDARD TABLE OF bom_item_ty WITH EMPTY KEY,
      BEGIN OF bom_message_ty,
        header TYPE bom_header_ty,
        items  TYPE bom_items_ty,
      END OF bom_message_ty,
      " AIF 出站消息：标准结构（与参照实现 /AIF/SEND_WITH_PROXY 的 sap_struct 一致）
      aif_bom_message_ty TYPE ppint_mfg_prodn_vers_inf,
      " ECN 状态行局部类型：规避 is_ecn_valid 参数 `TYPE SORTED TABLE OF aenr`
      " 无法解释 `aenr` 结构的问题（ADT 报 Unable to interpret "AENR"）。
      " 仅取所需两列：aennr（data element，已验证可用）+ aenst（1 字符）。
      BEGIN OF ecn_status_ty,
        aennr TYPE aennr,
        aenst TYPE c LENGTH 1,
      END OF ecn_status_ty,
      " 命名表类型：ADT 下匿名内联 `SORTED TABLE OF ...` 定义不可靠，
      " 必须单独定义类型供方法参数与 VALUE 构造引用。
      ecn_status TYPE SORTED TABLE OF ecn_status_ty WITH UNIQUE KEY aennr,
      ecn_key    TYPE SORTED TABLE OF aennr WITH UNIQUE KEY table_line.

    DATA mast_list    TYPE STANDARD TABLE OF mast.
    DATA stko_list    TYPE STANDARD TABLE OF stko.
    DATA stpo_list    TYPE STANDARD TABLE OF stpo.
    DATA stas_list    TYPE STANDARD TABLE OF stas.
    DATA mara_list    TYPE STANDARD TABLE OF mara.
    DATA bom_header   TYPE bom_header_ty.
    DATA bom_items    TYPE bom_items_ty.
    DATA bom_message  TYPE bom_message_ty.
    " AIF 出站消息（标准结构 ppint_mfg_prodn_vers_inf，经 /AIF/SEND_WITH_PROXY 发送）
    DATA aif_bom_message TYPE aif_bom_message_ty.

    " 屏幕传入的 STKO 日期范围（enrich_filter_criteria 解析，read_complete_data 应用）。
    " 框架把 DATUV/DATUB 路由到 tablename='STKO'，但 CP CDOBJID 与 filter 的 MAST 查询都应用不了
    " （MAST 无日期列；STKO CP CDOBJID = stlty+stlnr 无日期字段）。
    " read_complete_data 是唯一直接查 STKO 的层，必须在此强制日期过滤。
    " 空范围 = 匹配全部（无屏幕输入）→ 行为不变。
    DATA mt_stko_datuv TYPE rsds_selopt_t.   " 屏幕 DATUV（valid-from），应用于 STKO~datuv
    DATA mt_stko_datub TYPE rsds_selopt_t.   " 屏幕 DATUB（valid-to），应用于 STKO~valid_to

    " filter 实例——本地持有，供 read_complete_data 在框架 bypass 时（RUNMOD_BYPASS_FILTER）
    " 自行调 apply_filter，对齐参考实现 CL_P_DCB_DRF_PROCORD_OUT。
    DATA mo_bom_filter TYPE REF TO if_drf_filter.

    METHODS get_bom_filter
      RETURNING VALUE(ro_bom_filter) TYPE REF TO if_drf_filter.

    METHODS is_ecn_valid
      IMPORTING iv_aennr         TYPE aennr
                it_aenr_status   TYPE ecn_status
      RETURNING VALUE(rv_valid)  TYPE boole_d.

    METHODS map_bom_header
      IMPORTING is_stko TYPE stko
                is_mast TYPE mast
                is_mara TYPE mara
      CHANGING  cs_bom  TYPE bom_header_ty.

    METHODS map_bom_item
      IMPORTING is_stpo TYPE stpo
      CHANGING  cs_item TYPE bom_item_ty.

    METHODS build_aif_message
      IMPORTING is_bom_message TYPE bom_message_ty
      CHANGING cs_aif_message  TYPE aif_bom_message_ty.

    METHODS build_business_header
      RETURNING VALUE(rs_header) TYPE ppint_busdoc_msg_hdr.

ENDCLASS.


CLASS zcl_drf_ref_bom_change IMPLEMENTATION.

  METHOD analyze_changes_by_chg_pointer.
    " 变更分析（Change Pointer 模式）：从变更指针表提取 BOM 对象键。
    " FS §5 变更触发矩阵：DRF_T_BDCP 对象级凝聚，无字段级过滤。
    " CDOBJID 格式（按标准 SAP 主键顺序拼接）：
    "   MAST: MATNR(18)+WERKS(4)+STLAN(1)+STLAL(2)
    "   STKO: STLTY(1)+STLNR(8)
    "   STPO: STLTY(1)+STLNR(8)+POSNR(6)

    DATA change_pointer_table   TYPE drf_t_bdcp.
    DATA keys                  TYPE key_table_ty.
    DATA key                   TYPE bom_key_ty.
    DATA stko_stpo_range        TYPE RANGE OF stnum.                            " STKO/STPO CP 的 STLNR（专属反查 MAST 4 列）
    DATA mast_all               TYPE STANDARD TABLE OF mast WITH EMPTY KEY.     " 统一 MAST 行（MAST CP + STKO/STPO CP）
    DATA stko_stpo_mast         TYPE STANDARD TABLE OF mast WITH EMPTY KEY.     " STKO/STPO CP 专属 MAST 反查结果
    DATA stko_aennr_lookup      TYPE STANDARD TABLE OF stko WITH EMPTY KEY.  " STKO 反查：取 STLTY/AENNR（ECN），供变更指针对象键补全
    DATA ecn_filtered_cnt       TYPE i.                                       " 因 ECN 状态校验被过滤的对象计数

    " 临时：MAST CDOBJID 解析结果，用于批量反查 STLNR
    TYPES:
      BEGIN OF mast_cp_key,
        matnr TYPE matnr,
        werks TYPE werks_d,
        stlan TYPE stlan,
        stlal TYPE stlal,
      END OF mast_cp_key.
    DATA mast_cp_keys TYPE STANDARD TABLE OF mast_cp_key WITH EMPTY KEY.

    change_pointer_table = it_change_pointer.

    " NOTE: DRF_T_BDCP 是"Storage-Optimized Change Pointer"（对象级凝聚），
    " 不携带字段级信息，故仅按对象维度去重。
    " drf_s_bdcp 结构字段：cpident / tabname / tabkey / fldname / cdobjcl / cdobjid 等；
    " 本处按 tabname+cdobjid 排序去重（tabname 区分 MAST/STKO/STPO）。
    SORT change_pointer_table BY tabname cdobjid.
    DELETE ADJACENT DUPLICATES FROM change_pointer_table COMPARING tabname cdobjid.

    " 注：DRF 选择参数（WERKS/MATNR/STLAN/STLAL/DATUV/DATUB）由 DRF 框架在查询
    "     CDHDR 生成变更指针时已按配置表过滤，业务代码不应假设 runtime_parameter_ext
    "     中存在 sel_mara/sel_stko 等具体字段（DRF_S_RUNTIME_PARAMETER_EXT 结构不含此等组件）。
    "     业务代码在此只处理已由框架过滤后的对象级变更指针。

    " --- 1. MAST 变更：解析 CDOBJID → 批量反查完整 BOM 键（含 STLNR） ---
    "        CDOBJID 偏移必须与 SAP 标准 MAST 主键顺序一致
    "        (MATNR+WERKS+STLAN+STLAL)。
    LOOP AT change_pointer_table INTO DATA(mast_change_pointer) WHERE tabname = gc_cp_tabname_mast.
      " 长度用命名常量（对齐 DDIC 主键长度）；偏移必须为字面量
      " （ABAP source+off(len) 的 off 仅允许字面量，len 可引用常量，故保持 0/18/22/23）。
      INSERT VALUE mast_cp_key(
        matnr = mast_change_pointer-cdobjid+0(gc_len_matnr)
        werks = mast_change_pointer-cdobjid+18(gc_len_werks)
        stlan = mast_change_pointer-cdobjid+22(gc_len_stlan)
        stlal = mast_change_pointer-cdobjid+23(gc_len_stlal) ) INTO TABLE mast_cp_keys.
    ENDLOOP.

    IF mast_cp_keys IS NOT INITIAL.
      " MAST CP 反查（一次拿全 5 列含 STLNR），避免原实现按 STLNR 二次反查 MAST（双重查询优化）。
      SELECT matnr, stlan, werks, stlal, stlnr
        FROM mast
        INTO CORRESPONDING FIELDS OF TABLE @mast_all
        FOR ALL ENTRIES IN @mast_cp_keys
        WHERE matnr = @mast_cp_keys-matnr
          AND werks = @mast_cp_keys-werks
          AND stlan = @mast_cp_keys-stlan
          AND stlal = @mast_cp_keys-stlal.
    ENDIF.

    " --- 2/3. STKO/STPO 变更：对象级触发（DRF_T_BDCP 不含字段级信息） ---
    " 与 MAST CP 分开收集，仅对 STKO/STPO CP 专属的 STLNR 反查 MAST 4 列
    " （MAST CP 的 STLNR 已在上一步拿到完整键，避免重复查询）。
    LOOP AT change_pointer_table INTO DATA(stko_change_pointer) WHERE tabname = gc_cp_tabname_stko.
      INSERT VALUE #( sign = 'I' option = 'EQ' low = stko_change_pointer-cdobjid+1(gc_len_stlnr) )
        INTO TABLE stko_stpo_range.
    ENDLOOP.
    LOOP AT change_pointer_table INTO DATA(stpo_change_pointer) WHERE tabname = gc_cp_tabname_stpo.
      INSERT VALUE #( sign = 'I' option = 'EQ' low = stpo_change_pointer-cdobjid+1(gc_len_stlnr) )
        INTO TABLE stko_stpo_range.
    ENDLOOP.

    IF stko_stpo_range IS NOT INITIAL.
      CLEAR stko_stpo_mast.
      SELECT matnr, stlan, werks, stlal, stlnr
        FROM mast
        INTO CORRESPONDING FIELDS OF TABLE @stko_stpo_mast
        WHERE stlnr IN @stko_stpo_range.
      APPEND LINES OF stko_stpo_mast TO mast_all.
    ENDIF.

    " --- 4. 反查 MAST/STKO 获取完整 BOM 键及 ECN ---
    "       STLNR 已由 CP 的 CDOBJID 精确定位；此处不再追加 STLAN 过滤
    "       （CP 本身已含工厂/BOM 用途维度，追加过滤反而可能漏发多 MAST 关联场景）。
    " 去重：同一 STLNR 可能同时命中 MAST CP 与 STKO/STPO CP。
    IF mast_all IS NOT INITIAL.
      SORT mast_all BY matnr werks stlan stlal stlnr.
      DELETE ADJACENT DUPLICATES FROM mast_all
        COMPARING matnr werks stlan stlal stlnr.
      " 读取 STKO 的 STLTY/AENNR
      " FAE 空值守卫：mast_all 为空（MAST 无匹配 STLNR）时跳过 SELECT，
      " 否则 FOR ALL ENTRIES IN 空表会匹配全表，误取所有 BOM 的 STLTY/AENNR。
      SELECT stlnr, stlty, aennr
        FROM stko
        INTO TABLE @stko_aennr_lookup
        FOR ALL ENTRIES IN @mast_all
        WHERE stlnr = @mast_all-stlnr.
      LOOP AT mast_all INTO DATA(mast_line).
        CLEAR key.
        key-stlan = mast_line-stlan.
        key-werks = mast_line-werks.
        key-matnr = mast_line-matnr.
        key-stlal = mast_line-stlal.
        " 从 STKO 获取 STLTY 与 AENNR（同一 STLNR 首个 ECN 版本）
        " READ TABLE ... WITH KEY stlnr 取该 STLNR 的首条 STKO 头，与原先内嵌
        " LOOP...WHERE...EXIT 语义一致；单层键查找，无嵌套循环。
        READ TABLE stko_aennr_lookup INTO DATA(stko_line) WITH KEY stlnr = mast_line-stlnr.
        IF sy-subrc = 0.
          key-stlty = stko_line-stlty.
          key-aennr = stko_line-aennr.
        ENDIF.
        INSERT key INTO TABLE keys.
      ENDLOOP.
    ENDIF.

    " --- 5. ECN 状态校验（FS §5：所有变更类型均需 ECN） ---
    "       统计被过滤的对象数（无 ECN 或 ECN 未释放），
    "       便于运维在 DRF 运行日志中识别"因 ECN 被过滤"的对象。
    "       批量预加载 AENR 状态（aennr/aenst），替代 is_ecn_valid 的每对象
    "       SELECT SINGLE（消除 N+1 查询）。
    DATA(ecn_set) = VALUE ecn_key( ).
    LOOP AT keys INTO key.
      IF key-aennr IS NOT INITIAL.
        INSERT key-aennr INTO TABLE ecn_set.
      ENDIF.
    ENDLOOP.
    DATA(lt_aenr_status) = VALUE ecn_status( ).
    IF ecn_set IS NOT INITIAL.
      SELECT aennr, aenst FROM aenr
        INTO CORRESPONDING FIELDS OF TABLE @lt_aenr_status
        FOR ALL ENTRIES IN @ecn_set
        WHERE aennr = @ecn_set-table_line.
    ENDIF.

    DATA(keys_valid) = VALUE key_table_ty( ).
    LOOP AT keys INTO key.
      IF key-aennr IS NOT INITIAL
         AND is_ecn_valid( iv_aennr = key-aennr
                           it_aenr_status = lt_aenr_status ) = abap_true.
        INSERT key INTO TABLE keys_valid.
      ELSE.
        ecn_filtered_cnt = ecn_filtered_cnt + 1.
      ENDIF.
    ENDLOOP.
    et_changed_objects = keys_valid.

    " 把过滤计数暴露给运维
    IF ecn_filtered_cnt > 0
       AND runtime_parameter_ext-bal IS BOUND.
      runtime_parameter_ext-bal->add_msg(
        iv_msgty = if_drf_const=>msg_type_warning
        iv_msgid = gc_msgid
        iv_msgno = '001'
        iv_msgv1 = |{ ecn_filtered_cnt }|
        iv_msgv2 = |{ lines( keys ) }| ).
    ENDIF.

    es_stat_info-object_count_out = lines( et_changed_objects ).
    es_stat_info-exception_raised = abap_false.
  ENDMETHOD.


  METHOD analyze_changes_by_others.
    " 非 Change Pointer 模式：初始加载/手动按需（FS §4）。
    " 从 MAST 读取匹配过滤条件的 BOM，返回对象键。
    "
    " DRF 架构约束：界面选择值（WERKS/MATNR/STLAN/STLAL/DATUV/DATUB）仅经
    " enrich_filter_criteria 的 it_external_criteria（rsds_trange）接收，且 DRF
    " 调用顺序为 analyze_changes_by_others 先于 enrich_filter_criteria，故本方法
    " 拿不到界面值。Initial 场景按 FS §4 默认值（WERKS='DEFAULT_WERKS'、STLAN='1'）取数
    " 作为候选范围，实际过滤由框架在 CP 查询阶段用 enrich_filter_criteria 返回的
    " 条件收紧（见 enrich_filter_criteria，仅在配置了 filter object 时生效）。
    DATA: werks TYPE werks_d VALUE gc_default_werks,   " FS §4 默认 Plant
          stlan TYPE stlan   VALUE gc_default_stlan.   " FS §4 默认 BOM Usage
    DATA mast_all TYPE STANDARD TABLE OF mast WITH EMPTY KEY.
    DATA keys     TYPE key_table_ty.
    DATA key      TYPE bom_key_ty.

    " 默认过滤条件（FS §4）：WERKS='DEFAULT_WERKS', STLAN='1'
    " 注：MAST 中不含 STLTY/AENNR，二者由 STKO 提供
    " 量级控制（FS §14）：上线割接期最大 1000/天，UP TO 上限防止无界面输入时
    " 按默认条件全量扫描超限；增量由 Nightly CP 模式（变更指针）承担，
    " Initial 模式仅做基础加载 + 量级上限兜底。
    " 加确定性排序（主键顺序）使截断行为可预期；多取 1 行探测溢出。
    " 注：UP TO 子句不允许算术表达式（如 gc_initial_max_rows + 1），故用局部变量。
    DATA(max_rows_plus1) = gc_initial_max_rows + 1.
    SELECT matnr, stlan, werks, stlal, stlnr
      FROM mast
      INTO CORRESPONDING FIELDS OF TABLE @mast_all
      UP TO @max_rows_plus1 ROWS
      WHERE werks = @werks
        AND stlan = @stlan
      ORDER BY matnr, werks, stlan, stlal.

    " 溢出检测——取到 1001 行说明候选超上限，丢弃探测行并写告警
    IF lines( mast_all ) > gc_initial_max_rows.
      DELETE mast_all INDEX gc_initial_max_rows + 1.
      IF runtime_parameter_ext-bal IS BOUND.
        runtime_parameter_ext-bal->add_msg(
          iv_msgty = if_drf_const=>msg_type_warning
          iv_msgid = gc_msgid
          iv_msgno = '001'
          iv_msgv1 = |{ gc_initial_max_rows }|
          iv_msgv2 = 'Initial 候选超上限，已截断' ).
      ENDIF.
    ELSEIF lines( mast_all ) < gc_initial_min_rows
       AND runtime_parameter_ext-bal IS BOUND.
      " FS §14 下限 300 提示（不强发，仅告警）
      runtime_parameter_ext-bal->add_msg(
        iv_msgty = if_drf_const=>msg_type_info
        iv_msgid = gc_msgid
        iv_msgno = '001'
        iv_msgv1 = |{ lines( mast_all ) }|
        iv_msgv2 = 'Initial 候选低于 FS §14 下限 300' ).
    ENDIF.

    IF mast_all IS NOT INITIAL.
      " 批量反查 STKO 获取 STLTY/AENNR（ECN）
      SELECT stlnr, stlty, aennr
        FROM stko
        INTO TABLE @DATA(stko_aennr_lookup)
        FOR ALL ENTRIES IN @mast_all
        WHERE stlnr = @mast_all-stlnr.
        SORT stko_aennr_lookup BY STLNR.  " 对齐 MAST 顺序，便于后续按 STLNR 键查找取首条匹配
      " 先构造全部 key（含 AENNR），再批量预加载 AENR 状态做 ECN 校验
      LOOP AT mast_all INTO DATA(mast_line).
        CLEAR key.
        key-stlan = mast_line-stlan.
        key-werks = mast_line-werks.
        key-matnr = mast_line-matnr.
        key-stlal = mast_line-stlal.
        " READ TABLE ... WITH KEY stlnr 取该 STLNR 的首条 STKO 头，与原先内嵌
        " LOOP...WHERE...EXIT 语义一致；单层键查找，无嵌套循环。
        READ TABLE stko_aennr_lookup INTO DATA(stko_line) WITH KEY stlnr = mast_line-stlnr BINARY SEARCH.
        IF sy-subrc = 0.
          key-stlty = stko_line-stlty.
          key-aennr = stko_line-aennr.
        ENDIF.
        INSERT key INTO TABLE keys.
      ENDLOOP.

      " 批量预加载 AENR 状态（替代 is_ecn_valid 的每对象 SELECT SINGLE，消除 N+1）
      DATA(ecn_set) = VALUE ecn_key( ).
      LOOP AT keys INTO key.
        IF key-aennr IS NOT INITIAL.
          INSERT key-aennr INTO TABLE ecn_set.
        ENDIF.
      ENDLOOP.
      DATA(lt_aenr_status) = VALUE ecn_status( ).
      IF ecn_set IS NOT INITIAL.
        SELECT aennr, aenst FROM aenr
          INTO CORRESPONDING FIELDS OF TABLE @lt_aenr_status
          FOR ALL ENTRIES IN @ecn_set
          WHERE aennr = @ecn_set-table_line.
      ENDIF.

      " ECN 是必要条件（FS §5）：仅保留有有效 ECN 的 BOM
      DATA(keys_valid) = VALUE key_table_ty( ).
      LOOP AT keys INTO key.
        IF key-aennr IS NOT INITIAL
           AND is_ecn_valid( iv_aennr = key-aennr
                             it_aenr_status = lt_aenr_status ) = abap_true.
          INSERT key INTO TABLE keys_valid.
        ENDIF.
      ENDLOOP.
      et_changed_objects = keys_valid.
    ENDIF.

    " es_stat_info 完整赋值
    es_stat_info-object_count_out = lines( et_changed_objects ).
    es_stat_info-exception_raised = abap_false.
  ENDMETHOD.


  METHOD enrich_filter_criteria.
    " DRF 选择参数（FS §4）由 DRFOUT 界面输入，框架以 rsds_trange 经 it_external_criteria
    " 传入（tablename='MAST'/'STKO'，fieldname=字段名，selopt_t=sign/option/low/high）。
    " 本方法解析界面值，按 FS §4 补齐必填默认值，重建为 et_add_external_criteria：
    "   MAST-WERKS  必填，缺省 DEFAULT_WERKS
    "   MAST-MATNR  可选
    "   MAST-STLAN  必填，缺省 1
    "   MAST-STLAL  可选
    "   STKO-DATUV  可选（Valid-From）
    "   STKO-DATUB  可选（Valid-To）
    " 参考资源 CL_P_MCN_DRF_BATCH_OUT.abap:736-780 / CL_P_DCB_DRF_PROCORD_OUT.abap:1173-1202
    DATA: werks    TYPE rsds_selopt_t, matnr TYPE rsds_selopt_t,
          stlan    TYPE rsds_selopt_t, stlal TYPE rsds_selopt_t,
          datuv    TYPE rsds_selopt_t, datub TYPE rsds_selopt_t,
          selopt   TYPE rsdsselopt,
          selfield TYPE rsds_frange,
          seltab   TYPE rsds_range.

    " 始终解析界面选择条件并输出 et_add_external_criteria（参考在产实现
    " CL_P_MCN_DRF_BATCH_OUT.abap:736-780，enrich_filter_criteria 不因 fobj 短路）。
    " DRF 框架用返回的条件收窄 change pointer 查询（CP 模式：Nightly/Ad-Hoc 生效），
    " 确保界面输入 WERKS/MATNR/STLAN/STLAL/DATUV/DATUB 对取数生效。
    " 注：Initial（by_others）模式受 DRF 架构限制拿不到界面值，由 analyze_changes_by_others
    "     的默认条件（FS §4: WERKS=DEFAULT_WERKS/STLAN=1）兜底。

    " 1. 解析界面输入（it_external_criteria），按 tablename/fieldname 分流
    LOOP AT it_external_criteria ASSIGNING FIELD-SYMBOL(<range>).
      LOOP AT <range>-frange_t ASSIGNING FIELD-SYMBOL(<frange>).
        CASE <frange>-fieldname.
          WHEN 'WERKS'.
            APPEND LINES OF <frange>-selopt_t TO werks.
          WHEN 'MATNR'.
            APPEND LINES OF <frange>-selopt_t TO matnr.
          WHEN 'STLAN'.
            APPEND LINES OF <frange>-selopt_t TO stlan.
          WHEN 'STLAL'.
            APPEND LINES OF <frange>-selopt_t TO stlal.
          WHEN 'DATUV'.
            APPEND LINES OF <frange>-selopt_t TO datuv.
          WHEN 'DATUB'.
            APPEND LINES OF <frange>-selopt_t TO datub.
          WHEN OTHERS.
            " 未知字段记录日志，便于排查界面输入被丢弃
            IF runtime_parameter_ext-bal IS BOUND.
              runtime_parameter_ext-bal->add_msg(
                iv_msgty = if_drf_const=>msg_type_info
                iv_msgid = gc_msgid
                iv_msgno = '001'
                iv_msgv1 = <frange>-fieldname
                iv_msgv2 = 'enrich_filter_criteria 忽略未知字段' ).
            ENDIF.
        ENDCASE.
      ENDLOOP.
    ENDLOOP.

    " 留存解析后的 STKO 日期范围供 read_complete_data 使用（唯一直接查 STKO、能强制 DATUV/DATUB 筛选的层）。
    " enrich_filter_criteria 同时把日期路由到框架 CP 查询（tablename='STKO'），但 STKO CP CDOBJID
    " （stlty+stlnr）无日期字段，在那层不会生效。空范围 = 匹配全部 → read_complete_data 跳过过滤。
    mt_stko_datuv = datuv.
    mt_stko_datub = datub.

    " 2. FS §4 必填项缺省补齐（WERKS=DEFAULT_WERKS、STLAN=1）
    " 守卫命中时用构造器一次性 append 默认选择条件，免去 selopt 逐字段赋值 + CLEAR。
    IF lines( werks ) = 0.
      APPEND VALUE #( sign = 'I' option = 'EQ' low = gc_default_werks ) TO werks.
    ENDIF.
    IF lines( stlan ) = 0.
      APPEND VALUE #( sign = 'I' option = 'EQ' low = gc_default_stlan ) TO stlan.
    ENDIF.

    " 3. 重建 et_add_external_criteria：MAST 表（WERKS/MATNR/STLAN/STLAL）
    seltab-tablename = 'MAST'.
    IF lines( werks ) > 0.
      selfield-fieldname = 'WERKS'.
      APPEND LINES OF werks TO selfield-selopt_t.
      APPEND selfield TO seltab-frange_t.
      CLEAR selfield.
    ENDIF.
    IF lines( matnr ) > 0.
      selfield-fieldname = 'MATNR'.
      APPEND LINES OF matnr TO selfield-selopt_t.
      APPEND selfield TO seltab-frange_t.
      CLEAR selfield.
    ENDIF.
    IF lines( stlan ) > 0.
      selfield-fieldname = 'STLAN'.
      APPEND LINES OF stlan TO selfield-selopt_t.
      APPEND selfield TO seltab-frange_t.
      CLEAR selfield.
    ENDIF.
    IF lines( stlal ) > 0.
      selfield-fieldname = 'STLAL'.
      APPEND LINES OF stlal TO selfield-selopt_t.
      APPEND selfield TO seltab-frange_t.
      CLEAR selfield.
    ENDIF.
    IF lines( seltab-frange_t ) > 0.
      APPEND seltab TO et_add_external_criteria.
    ENDIF.
    CLEAR seltab.

    " 4. STKO 表（有效日期区间）。
    " DATUV = STKO 真实字段名（生效开始），DATUB 为 FS §4 选择参数名/数据元素名，
    " 但 STKO 表无 DATUB 字段（有效结束日期实际 DDIC 字段为 valid_to，其域名为 DATUB）。
    " 框架 get_external_filter 经 FREE_SELECTIONS_RANGE_2_WHERE 原样把 fieldname 拼进 WHERE、
    " 不做参数名→字段名映射，故结束日期须用真实字段名 VALID_TO（对齐 FS 备注 2 / 代码 L1064 注释）。
    seltab-tablename = 'STKO'.
    IF lines( datuv ) > 0.
      selfield-fieldname = 'DATUV'.
      APPEND LINES OF datuv TO selfield-selopt_t.
      APPEND selfield TO seltab-frange_t.
      CLEAR selfield.
    ENDIF.
    IF lines( datub ) > 0.
      selfield-fieldname = 'VALID_TO'.
      APPEND LINES OF datub TO selfield-selopt_t.
      APPEND selfield TO seltab-frange_t.
      CLEAR selfield.
    ENDIF.
    IF lines( seltab-frange_t ) > 0.
      APPEND seltab TO et_add_external_criteria.
    ENDIF.
    CLEAR seltab.
  ENDMETHOD.


  METHOD get_bom_filter.
    " 懒加载 BOM filter，供 read_complete_data 在 RUNMOD_BYPASS_FILTER 时自行调 apply_filter
    "（对齐参考实现 CL_P_DCB_DRF_PROCORD_OUT~get_procord_filter）。
    IF mo_bom_filter IS NOT BOUND.
      mo_bom_filter = NEW zcl_drf_ref_bom_out_fltr( ).
    ENDIF.
    ro_bom_filter = mo_bom_filter.
  ENDMETHOD.


  METHOD read_complete_data.
    " 批量读取 BOM 完整数据到缓冲区。
    " 流程：清空缓冲区 → 读取 MAST/STKO/STPO/MARA → 填充缓冲区

    DATA bom_number_set TYPE SORTED TABLE OF stnum WITH UNIQUE KEY table_line.  " STLNR 去重集——作 STKO/STPO/STAS 的关联键（防行数放大）
    DATA material_set   TYPE SORTED TABLE OF matnr WITH UNIQUE KEY table_line.  " MATNR 去重集（查 MARA）

    CLEAR: mast_list, stko_list, stpo_list, stas_list, mara_list.

    " filter 门控：apply_filter 在取数前必然已执行。正常 runmod 下框架已调过
    " （ct_relevant_objects 已带 filter 的 MAST 预查 stlnr）；RUNMOD_BYPASS_FILTER 时框架
    " 跳过 filter，由此处自行调 apply_filter 补上——对齐参考实现
    " CL_P_DCB_DRF_PROCORD_OUT~read_complete_data。et_filtered_objects 为空时 CL_DRF_OUTBOUND
    " 根本不会调到本实现，故能走到这里意味着集合非空、之后 stlnr 必然存在。
    IF runtime_parameter_ext-runmod = if_drf_const=>runmod_bypass_filter.
      DATA(lt_filtered) = VALUE key_table_ty( ).
      get_bom_filter( )->apply_filter(
        EXPORTING
          iv_appl               = runtime_parameter_ext-appl
          iv_business_system    = runtime_parameter_ext-business_system
          iv_outb_impl          = runtime_parameter_ext-outb_impl
          iv_runmod             = runtime_parameter_ext-runmod
          io_bal                = runtime_parameter_ext-bal
          iv_dlmod              = runtime_parameter_ext-dlmod
          it_unfiltered_objects = ct_relevant_objects
          is_c_fobj             = VALUE #( )
          is_filt               = VALUE #( )
          it_external_criteria  = VALUE #( )
        IMPORTING
          et_filtered_objects   = lt_filtered ).
      ct_relevant_objects = lt_filtered.
    ENDIF.

    " stlnr 此刻必然已在对象键里（filter 的 MAST SELECT 同名回填），直接从对象键合成
    " mast_list，无需再查 MAST。stlty/aennr 可能为空（filter 输出结构无这两列），
    " map_data2message 的 stlnr-only STKO 查找分支已处理该情况；MAST 本身也无 AENNR/STLTY 列。
    LOOP AT ct_relevant_objects INTO DATA(ls_bom_key).
      DATA(ls_mast) = CORRESPONDING mast( ls_bom_key ).
      APPEND ls_mast TO mast_list.
      INSERT ls_bom_key-stlnr INTO TABLE bom_number_set.
    ENDLOOP.

    IF mast_list IS NOT INITIAL.
      " 同一 STLNR 在 mast_list 可关联多个 (matnr/werks/stlan/stlal) 组合，
      " 直接 INNER JOIN @mast_list 会放大 STKO/STPO 行数，导致组件重复发送/数量翻倍。
      " 仅取去重后的 STLNR 集合作为关联键，保持每个组件只出现一次。
      " 注：BOM 号字段 STLNR 的数据元素为 STNUM（sapdatasheet MAST 表核实）。

      " 读取 STKO (BOM header) — 提供 STLTY / AENNR / ANDAT / DATUV / BMENG / valid_to
      " 过滤（对齐业务 SQL）：仅物料 BOM（STLTY='M'）、未删除（LKENZ<>'X'）、激活（STLST='01'）。
      " DATUV/VALID_TO 筛选：在此强制，因为没有别的层能做——filter 查 MAST（无日期列），
      " 框架 CP 查询无法用日期匹配 STKO CP CDOBJID（stlty+stlnr）。范围来自 enrich_filter_criteria
      " 经实例属性 mt_stko_datuv / mt_stko_datub 传递；空范围 = 匹配全部（无屏幕输入），DATUV/DATUB 为空时行为不变。
      " Open SQL 禁止 SELECT * 与 JOIN 并用，改为显式列名 + CORRESPONDING
      SELECT stko_alias~stlnr, stko_alias~stlty, stko_alias~aennr,
             stko_alias~andat, stko_alias~datuv, stko_alias~bmeng,
             stko_alias~valid_to
        FROM stko AS stko_alias
        INNER JOIN @bom_number_set AS bom_number
          ON stko_alias~stlnr = bom_number~table_line
        WHERE stko_alias~stlty = 'M'
          AND stko_alias~lkenz <> 'X'
          AND stko_alias~stlst = '01'
          AND stko_alias~datuv    IN @mt_stko_datuv
          AND stko_alias~valid_to IN @mt_stko_datub
        INTO CORRESPONDING FIELDS OF TABLE @stko_list.

      " 读取 STPO (BOM item) — 提供 IDNRK/MENGE/DATUV/valid_to/MEINS/AVOAU/AUSCH/AENNR
      " 含 STLKN：组件归属节点，用于按备选 BOM（STAS-STLAL）收敛，杜绝多备选互串。
      " Open SQL 禁止 SELECT * 与 JOIN 并用，改为显式列名 + CORRESPONDING
      " 过滤（对齐业务 SQL）：仅物料 BOM 组件（STLTY='M'）、未删除（LKENZ<>'X'）。
      SELECT stpo_alias~stlnr, stpo_alias~stlty, stpo_alias~stlkn,
             stpo_alias~idnrk, stpo_alias~menge, stpo_alias~datuv,
             stpo_alias~valid_to, stpo_alias~meins, stpo_alias~avoau,
             stpo_alias~ausch, stpo_alias~aennr
        FROM stpo AS stpo_alias
        INNER JOIN @bom_number_set AS bom_number
          ON stpo_alias~stlnr = bom_number~table_line
        WHERE stpo_alias~stlty = 'M'
          AND stpo_alias~lkenz <> 'X'
        INTO CORRESPONDING FIELDS OF TABLE @stpo_list.

      " 读取 STAS (BOM item selection) — 提供备选 BOM (STLAL) → STLKN 节点归属。
      " 同一 STLNR 下多个备选（STLAL=1/2/3…）的组件靠 STLKN 节点区分，
      " map_data2message 据此把组件收敛到对象键所属备选，杜绝互串。
      " 注：STPO 本身不含 STLAL，表头↔明细必须经 STAS 按 STLAL 解析 STLKN 节点。
      " 过滤（对齐业务 SQL）：仅物料 BOM 节点（STLTY='M'）。
      SELECT stas_alias~stlty, stas_alias~stlnr,
             stas_alias~stlal, stas_alias~stlkn
        FROM stas AS stas_alias
        INNER JOIN @bom_number_set AS bom_number
          ON stas_alias~stlnr = bom_number~table_line
        WHERE stas_alias~stlty = 'M'
        INTO CORRESPONDING FIELDS OF TABLE @stas_list.
    ENDIF.

    " 读取 MARA (Header UoM - ID14, Component UoM - ID15)
    LOOP AT mast_list INTO DATA(mast_line).
      INSERT mast_line-matnr INTO TABLE material_set.
    ENDLOOP.
    LOOP AT stpo_list INTO DATA(stpo_line).
      INSERT stpo_line-idnrk INTO TABLE material_set.
    ENDLOOP.
    IF material_set IS NOT INITIAL.
      SELECT matnr, meins FROM mara
        INTO CORRESPONDING FIELDS OF TABLE @mara_list
        FOR ALL ENTRIES IN @material_set
        WHERE matnr = @material_set-table_line.
    ENDIF.

    " 注：ID09 changeNo 直接取 STKO-AENNR（AENR 主键=AENNR，STKO 引用之，二者同值），
    "     无需再查询 AENR 回填 aenr_list（原冗余查询已移除，见 map_bom_header）。

  ENDMETHOD.


  METHOD map_data2message.
    " 将 BOM 数据映射到 TARGET_SYSTEM 消息结构。
    " 字段映射（FS §7）：
    " ID01 MATERIAL → copExgNo (BOM Header 物料, MAST-MATNR)
    " ID02 COMPONENT_MATNR → copImgNo (组件物料, STPO-IDNRK)
    " ID03 QUANTITY → decCm (组件数量, STPO-MENGE)
    " ID04 VALID_FROM → startDate (组件生效开始, STPO-DATUV)
    " ID05 VALID_TO → endDate (组件生效结束, STPO-valid_to)
    " ID06 BOM_CREATION → bomCreation (BOM 创建日期, STKO-ANDAT)
    " ID07 ALTERNATIVE_BOM → alternativeBom (备选 BOM, MAST-STLAL)
    " ID08 BOM_NO → bomNo (BOM 编号, MAST-STLNR)
    " ID09 CHANGE_NO → changeNo (工程变更号, AENR-AENNR)
    " ID10 BOM_USAGE → useTo (BOM 用途, MAST-STLAN)
    " ID11 HEADER_START_DATE → bomStartDate (Header 生效开始, STKO-DATUV)
    " ID12 HEADER_END_DATE → bomEndDate (Header 生效结束, STKO-valid_to)
    " ID13 HEADER_QTY → copExgQty (Header 数量, STKO-BMENG)
    " ID14 HEADER_UNIT → copExgUnit (成品/半成品 UoM, MARA-MEINS)
    " ID15 COMPONENT_UNIT → copImgUnit (组件 UoM, STPO-MEINS)
    " ID16 OPERATION_SCRAP → OperationScrap (工序损耗, STPO-AVOAU)
    " ID17 COMPONENT_SCRAP → ComponentScrap (组件损耗, STPO-AUSCH)
    " 注：FS §5 变更矩阵：component scrap=AUSCH（组件损耗），operation scrap=AVOAU（工序损耗）。
    "     STPO 表中 AUSCH（类型 KAUSF）为组件损耗、AVOAU 为工序损耗，二者为独立列。

    FIELD-SYMBOLS <bom_key> TYPE bom_key_ty.
    DATA bom_number TYPE stnum.
    DATA bom_type   TYPE stlty.
    DATA mara_line  TYPE mara.
    DATA stko_line  TYPE stko.
    DATA item       TYPE bom_item_ty.  " 循环内反复填充，需每轮 CLEAR
    DATA lt_stlkn_set TYPE SORTED TABLE OF stlkn WITH UNIQUE KEY table_line.  " STAS 收敛：备选→STLKN 节点集

    CLEAR: bom_header, bom_items.

    IF ir_relevant_object IS NOT BOUND.
      RAISE EXCEPTION TYPE cx_drf_exception.
    ENDIF.

    " 使用 FIELD-SYMBOLS 读取对象键字段（REF TO data 无法直接 ->* 成员）。
    ASSIGN ir_relevant_object->* TO <bom_key>.
    IF sy-subrc <> 0.
      RAISE EXCEPTION TYPE cx_drf_exception.
    ENDIF.

    READ TABLE mast_list WITH KEY stlan = <bom_key>-stlan
                                 werks = <bom_key>-werks
                                 matnr = <bom_key>-matnr
                                 stlal = <bom_key>-stlal
      INTO DATA(mast_line).
    IF sy-subrc <> 0.
      " 对象键未命中 MAST 时写对象级告警
      IF runtime_parameter_ext-bal IS BOUND.
        runtime_parameter_ext-bal->add_msg(
          iv_msgty = if_drf_const=>msg_type_warning
          iv_msgid = gc_msgid
          iv_msgno = '001'
          iv_msgv1 = <bom_key>-matnr
          iv_msgv2 = <bom_key>-werks ).
      ENDIF.
      RETURN.
    ENDIF.

    bom_number = mast_line-stlnr.

    " 获取 STKO (BOM Header - ID06/09/11/12/13)。
    " 两级兜底链（绝不拼装空 Header）：
    "   ① 对象键带 ECN（analyze 路径：STKO 反查已赋值 stlty/aennr）
    "      → 按 stlnr + aennr 精确匹配（ECN 版本）；失败再按 stlnr + stlty 兜底；
    "   ② 对象键缺 ECN/stlty（filter 预查：MAST 无 stlty/aennr 列；或 analyze 反查无 STKO 行）
    "      → 按 stlnr 匹配（唯一 BOM 头）；
    "   ③ STKO 完全无该行 → 告警 + RETURN（send_message 的空载荷判定承接）。
    " stlnr（BOM 号）唯一确定 BOM 头，stlty 是 BOM 头属性（非独立标识）。
    IF <bom_key>-stlty IS NOT INITIAL.
      READ TABLE stko_list WITH KEY stlnr = bom_number stlty = <bom_key>-stlty aennr = <bom_key>-aennr
        INTO stko_line.
      IF sy-subrc <> 0.
        " 兜底：STKO 无该 ECN 版本 → 取该 STLNR/STLTY 的首条 BOM 头
        READ TABLE stko_list WITH KEY stlnr = bom_number stlty = <bom_key>-stlty
          INTO stko_line.
      ENDIF.
    ELSE.
      " filter 预查路径（或 analyze 反查无果）：对象键 stlty/aennr 为空，仅按 stlnr 匹配唯一 BOM 头
      READ TABLE stko_list WITH KEY stlnr = bom_number
        INTO stko_line.
    ENDIF.
    IF sy-subrc <> 0.
      " STKO 完全无该 STLNR 时，写告警，避免用空 Header 拼装
      IF runtime_parameter_ext-bal IS BOUND.
        runtime_parameter_ext-bal->add_msg(
          iv_msgty = if_drf_const=>msg_type_warning
          iv_msgid = gc_msgid
          iv_msgno = '001'
          iv_msgv1 = |{ bom_number }|
          iv_msgv2 = |{ <bom_key>-stlty }| ).
      ENDIF.
      RETURN.
    ENDIF.

    " STPO 组件按 STKO 实际 stlty 过滤（对象键 stlty 在 filter 预查路径下为空，
    " 不能用于 STPO 过滤；从已命中的 STKO 取实际 stlty）。
    bom_type = stko_line-stlty.

    " 获取 MARA (Header UoM - ID14)
    READ TABLE mara_list WITH KEY matnr = mast_line-matnr INTO mara_line.

    " 映射 Header (ID01, ID06-ID14)
    map_bom_header(
      EXPORTING is_stko = stko_line
                is_mast = mast_line
                is_mara = mara_line
      CHANGING  cs_bom  = bom_header
                 ).

    " 映射 Items (ID02-ID05, ID15-ID17)
    " ID15 COMPONENT_UNIT 直接取自 STPO-MEINS（FS §7）。
    " 备选 BOM (STLAL) → STLKN 节点集合：同一 STLNR 下多备选（STLAL=1/2/3…）时，
    " 组件仅取本备选所属节点（经 STAS 解析），避免其他备选组件互串；
    " 无 STAS 数据（单备选/历史数据）时 lt_stlkn_set 为空，兜底保留全部。
    LOOP AT stas_list INTO DATA(stas_line)
        WHERE stlnr = bom_number AND stlty = bom_type AND stlal = mast_line-stlal.
      INSERT stas_line-stlkn INTO TABLE lt_stlkn_set.
    ENDLOOP.

    LOOP AT stpo_list INTO DATA(stpo_line) WHERE stlnr = bom_number AND stlty = bom_type.
      IF lt_stlkn_set IS NOT INITIAL.
        READ TABLE lt_stlkn_set WITH KEY table_line = stpo_line-stlkn TRANSPORTING NO FIELDS.
        IF sy-subrc <> 0.
          CONTINUE.   " 组件不属于本备选节点 → 跳过（修互串）
        ENDIF.
      ENDIF.
      CLEAR item.
      map_bom_item(
        EXPORTING is_stpo = stpo_line
        CHANGING  cs_item = item
                  ).
      APPEND item TO bom_items.
    ENDLOOP.

    bom_message-header = bom_header.
    bom_message-items  = bom_items.

    " 装配 AIF 出站消息（标准结构 ppint_mfg_prodn_vers_inf，
    " 组件落点见 map2xml.md；ID06/ID16 无标准落点，保留在本地 bom_message 供 MuleSoft 侧映射）。
    CLEAR aif_bom_message.
    build_aif_message( EXPORTING is_bom_message = bom_message
                      CHANGING cs_aif_message = aif_bom_message ).

  ENDMETHOD.


  METHOD send_message.
    " AIF 发送逻辑（FS §3）。
    " 参照 /RGS/CL_P_DCB_DRF_PRODVER_OUT~if_drf_outbound~send_message：
    " BOM 经 ManufacturingProdnVersInfo_Out 出站服务发送
    "（gc_ns='AIF_NS'、gc_ifname='AIF_IFNAME'、gc_ifver='1'、logical port='AIF_LOGICAL_PORT'）；
    " 对象键经 ct_obj_rep_sta[1]-object_id 还原（CONV bom_key_ty），
    " 异常捕获 cx_bs_soa_exception / cx_ai_system_fault，
    " 成功/失败均写对象级 AIF 日志（add_msg_xi / add_msg_re）。
    " 保留 FS §2.2 分片发送：XML 单文件最大 2000 行，超量按 2000 条组件拆批。

    " --- 方法内局部声明（统一置于作用域顶部）---
    " FS §10 错误对象五要素 + AIF 日志相关变量
    DATA: errmsg  TYPE drf_s_message,
          error_return TYPE REF TO bapiret2,
          idnrk   TYPE idnrk,
          msgguid        TYPE  sxmsmguid,
          msgguid_out    TYPE  sxmsmguid,
          error_string   TYPE string,
          error_long     TYPE string,
          lv_sent_ok     TYPE abap_bool VALUE abap_true,
          lv_dummy       TYPE char20,
          bom_key        TYPE bom_key_ty,
          bom_key_ref    TYPE REF TO bom_key_ty,
          wsprotocol_msg_id TYPE REF TO if_wsprotocol_message_id,
          return_send    TYPE STANDARD TABLE OF bapiret2.

    IF lines( bom_items ) > 0.
      idnrk = bom_items[ 1 ]-cop_img_no.
    ENDIF.

    IF bom_message-header IS INITIAL AND bom_message-items IS INITIAL.
      RETURN.
    ENDIF.

    " 构造 BOM 对象键（对齐参照实现：ct_obj_rep_sta[1]-object_id → CONV key → GET REFERENCE
    " 供 add_msg_xi 的 ir_object；对象键缺失时兜底用消息 header 字段回填）。
    READ TABLE ct_obj_rep_sta INTO DATA(ls_obj_rep_sta) INDEX 1.
    IF sy-subrc = 0.
      bom_key = CONV bom_key_ty( ls_obj_rep_sta-object_id ).
      GET REFERENCE OF bom_key INTO bom_key_ref.
    ELSE.
      " ct_obj_rep_sta 为空（不应发生，防御性兜底）：用消息 header 回填对象键
      bom_key-matnr = bom_message-header-cop_exg_no.
      bom_key-werks = gc_default_werks.
      bom_key-stlal = bom_message-header-alternative_bom.
      bom_key-aennr = bom_message-header-change_no.
      GET REFERENCE OF bom_key INTO bom_key_ref.
    ENDIF.

    " 发送前做必填字段非空校验（FS §7 M 标记）。
    "   Header 级 M 字段：ID01 copExgNo、ID13 headerQty
    "   Item 级 M 字段：ID02 copImgNo、ID03 quantity、ID16 operationScrap、ID17 componentScrap
    "   若 Header 无值或 Header 必填字段缺失，直接标 E 返回，避免空消息送达 TARGET_SYSTEM。
    IF bom_message-header IS INITIAL
       OR bom_message-header-cop_exg_no IS INITIAL
       OR bom_message-header-header_qty IS INITIAL.
      LOOP AT ct_obj_rep_sta ASSIGNING FIELD-SYMBOL(<rep_status_init>).
        <rep_status_init>-repstatus = 'SE'.
      ENDLOOP.
      " FS §10：错误对象五要素 → AIF 错误上下文（drf_s_message-message → bapiret2）
      CREATE DATA error_return.
      error_return->type       = 'E'.
      error_return->id         = gc_msgid.
      error_return->number     = '001'.
      error_return->message_v1 = bom_header-cop_exg_no.   " Parent Material (MATNR)
      error_return->message_v2 = gc_default_werks.            " Plant (WERKS, FS §10 固定)
      error_return->message_v3 = idnrk.                   " Component Item (IDNRK)
      error_return->message_v4 = bom_header-change_no.    " ECN (AENNR)
      errmsg-bo_type       = 'BILL_OF_MATERIAL'.        " Production BOM 主对象
      errmsg-bo_key        = bom_header-cop_exg_no.  " 对象 ID (MATNR)
      errmsg-target_system = gc_logical_port.           " TARGET_SYSTEM 目标系统
      errmsg-message       = error_return.
      APPEND errmsg TO et_message.
      CLEAR: errmsg, error_return.
      " 对象级 AIF 错误日志（FS §10/§11 五要素上下文）
      IF runtime_parameter_ext-bal IS BOUND.
        runtime_parameter_ext-bal->add_msg(
          iv_msgty = if_drf_const=>msg_type_error
          iv_msgid = gc_msgid
          iv_msgno = '001'
          iv_msgv1 = bom_header-cop_exg_no
          iv_msgv2 = gc_default_werks
          iv_msgv3 = idnrk
          iv_msgv4 = bom_header-change_no ).
      ENDIF.
      CLEAR: bom_message, bom_header, bom_items.
      RETURN.
    ENDIF.
    " Item 级必填字段校验：仅当 items 非空时逐条检查，避免"仅 Header BOM"被误拒
    LOOP AT bom_message-items ASSIGNING FIELD-SYMBOL(<item_chk>).
      IF <item_chk>-cop_img_no IS INITIAL
         OR <item_chk>-quantity IS INITIAL
         OR <item_chk>-operation_scrap < 0
         OR <item_chk>-component_scrap < 0.
        LOOP AT ct_obj_rep_sta ASSIGNING FIELD-SYMBOL(<rep_status_miss>).
          <rep_status_miss>-repstatus = 'SE'.
        ENDLOOP.
        " FS §10：错误对象五要素 → AIF 错误上下文（drf_s_message-message → bapiret2）
        CREATE DATA error_return.
        error_return->type       = 'E'.
        error_return->id         = gc_msgid.
        error_return->number     = '001'.
        error_return->message_v1 = bom_header-cop_exg_no.   " Parent Material (MATNR)
        error_return->message_v2 = gc_default_werks.            " Plant (WERKS, FS §10 固定)
        error_return->message_v3 = <item_chk>-cop_img_no.   " Component Item (IDNRK)
        error_return->message_v4 = bom_header-change_no.    " ECN (AENNR)
        errmsg-bo_type       = 'BILL_OF_MATERIAL'.        " Production BOM 主对象
        errmsg-bo_key        = bom_header-cop_exg_no.  " 对象 ID (MATNR)
        errmsg-target_system = gc_logical_port.           " TARGET_SYSTEM 目标系统
        errmsg-message       = error_return.
        APPEND errmsg TO et_message.
        CLEAR: errmsg, error_return.
        " 对象级 AIF 错误日志（FS §10/§11 五要素上下文）
        IF runtime_parameter_ext-bal IS BOUND.
          runtime_parameter_ext-bal->add_msg(
            iv_msgty = if_drf_const=>msg_type_error
            iv_msgid = gc_msgid
            iv_msgno = '001'
            iv_msgv1 = bom_header-cop_exg_no
            iv_msgv2 = gc_default_werks
            iv_msgv3 = <item_chk>-cop_img_no
            iv_msgv4 = bom_header-change_no ).
        ENDIF.
        CLEAR: bom_message, bom_header, bom_items.
        RETURN.
      ENDIF.
    ENDLOOP.

    " 分片发送（FS §2.2）：XML 单文件最大 2000 行，超量拆分为多批次 API 调用。
    " 发送路径对齐参照类 /RGS/CL_P_DCB_DRF_PRODVER_OUT~send_message：
    "   - 不显式建 /AIF/CREATE_APPL_LOG（DRF 框架经 bal 管理应用日志）；
    "   - /AIF/SEND_WITH_PROXY 用 sap_struct 传整条标准消息 aif_bom_message
    "     （ppint_mfg_prodn_vers_inf，即 AIF 服务 ManufacturingProdnVersInfo_Out 的载荷）；
    "   - 异常捕获 cx_bs_soa_exception / cx_ai_system_fault，
    "     失败时对象 repstatus 置 'SE' 并经 add_msg_re 写 AIF 错误日志。
    "
    " 参照类对 PPint 结构不做 2000 行拆分（其 sap_struct 为单条生产版本消息），
    " 本 BOM 场景沿用同一模式：整条 BOM 消息经单一次 /AIF/SEND_WITH_PROXY 发送。

    TRY.
      DO 1 TIMES.
        CLEAR return_send.
        CALL FUNCTION '/AIF/SEND_WITH_PROXY'
          EXPORTING
            ns                   = gc_ns
            ifname               = gc_ifname
            ifversion            = gc_ifver
            appl_log_function    = 'AIF_SEND_WITH_PROXY'
            msgguid              = msgguid
            iv_persist_xml       = 'X'
            logical_port_name    = gc_logical_port
          IMPORTING
            ximsgguid            = msgguid
            ximsgguid_out        = msgguid_out
          TABLES
            add_return_tab       = return_send
          CHANGING
            sap_struct           = aif_bom_message
            error_string         = error_string
            error_long_text      = error_long
          EXCEPTIONS
            persistency_error    = 1
            status_update_failed = 2
            missing_keys         = 3
            interface_not_found  = 4
            transformation_error = 5
            general_error        = 6
            OTHERS               = 7.

        " sy-subrc 非 0，或 add_return_tab 含业务级错误（E/A），本消息记为失败。
        " 参照类对 PERSISTENCY_ERROR（=1）容忍：持久化错误不中断发送循环。
        IF sy-subrc <> 0 AND sy-subrc <> 1.
          lv_sent_ok = abap_false.
        ENDIF.
        DATA(has_biz_error) = abap_false.
        LOOP AT return_send INTO DATA(ret_send)
          WHERE type = if_drf_const=>msg_type_error
             OR type = 'A'.
          has_biz_error = abap_true.
          EXIT.
        ENDLOOP.
        IF has_biz_error = abap_true.
          lv_sent_ok = abap_false.
        ENDIF.

        " 对象级 AIF 日志：关联 GUID + 载荷（对齐参照类行 3092-3100）
        " BOM 经 /AIF/SEND_WITH_PROXY 发送，无 SOAP proxy → io_message_id_protocol 传空引用
        " ir_object 传 BOM 对象键，is_message_out 传当批载荷（与 sap_struct 一致）。
        IF runtime_parameter_ext-bal IS BOUND.
          runtime_parameter_ext-bal->add_msg_xi(
            iv_xi_msg_guid         = msgguid_out
            iv_object_count        = iv_object_count
            io_message_id_protocol = wsprotocol_msg_id
            iv_outb_impl           = runtime_parameter_ext-outb_impl
            ir_object              = bom_key_ref
            is_message_out         = aif_bom_message ).
        ENDIF.
      ENDDO.
    " 数据复制失败：对象标记 'SE'，写 AIF 错误日志（对齐参照类异常处理块）
    CATCH cx_bs_soa_exception INTO DATA(soa_exception).
      LOOP AT ct_obj_rep_sta ASSIGNING FIELD-SYMBOL(<rep_status_soa>).
        <rep_status_soa>-repstatus = 'SE'.
      ENDLOOP.
      UNASSIGN: <rep_status_soa>.
      DATA(soa_text) = soa_exception->get_text( ).
      DATA(soa_long_text) = soa_exception->get_longtext( ).
      MESSAGE s015(drf_outbound) WITH gc_matgrp_service soa_text soa_long_text INTO lv_dummy ##needed.
      IF runtime_parameter_ext-bal IS BOUND.
        runtime_parameter_ext-bal->add_msg_re(
          iv_msgno             = sy-msgno
          iv_msgid             = sy-msgid
          iv_msgv1             = gc_matgrp_service
          iv_msgv2             = soa_text
          ix_exception_catched = soa_exception ).
      ENDIF.
    CATCH cx_ai_system_fault INTO DATA(system_fault).
      LOOP AT ct_obj_rep_sta ASSIGNING FIELD-SYMBOL(<rep_status_fault>).
        <rep_status_fault>-repstatus = 'SE'.
      ENDLOOP.
      UNASSIGN: <rep_status_fault>.
      DATA(fault_text) = system_fault->get_text( ).
      DATA(fault_long_text) = system_fault->get_longtext( ).
      MESSAGE s015(drf_outbound) WITH gc_matgrp_service fault_text fault_long_text INTO lv_dummy ##needed.
      IF runtime_parameter_ext-bal IS BOUND.
        runtime_parameter_ext-bal->add_msg_re(
          iv_msgno             = sy-msgno
          iv_msgid             = sy-msgid
          iv_msgv1             = gc_matgrp_service
          iv_msgv2             = fault_text
          ix_exception_catched = system_fault ).
      ENDIF.
    ENDTRY.

    " 按全批次聚合结果处理返回块（对齐参照类：异常路径已置 'SE'，此处仅在发送完成时定标）。
    " 语义：所有批次成功（lv_sent_ok）且无异常时对象标记 'SN'（Sent/No error）；
    "       任一批次失败/异常已在循环内或 CATCH 块标记 'SE'。
    IF lv_sent_ok = abap_true.
      LOOP AT ct_obj_rep_sta ASSIGNING FIELD-SYMBOL(<rep_status_ok>).
        <rep_status_ok>-repstatus = 'SN'.
      ENDLOOP.
      " 对象级 AIF 成功日志（FS §11 监控）
      IF runtime_parameter_ext-bal IS BOUND.
        runtime_parameter_ext-bal->add_msg(
          iv_msgty = if_drf_const=>msg_type_success
          iv_msgid = gc_msgid
          iv_msgno = '001'
          iv_msgv1 = bom_header-cop_exg_no ).
      ENDIF.
    ENDIF.

    CLEAR: bom_message, bom_header, bom_items.
  ENDMETHOD.


  METHOD finalize.
    " FS §10：仅在无错误对象时删除变更指针，否则保留以便重执行。
    " 区分 Initial Run 重跑场景——重复初始加载下框架本就不生成 CP，
    "           此时不应删除（避免与残留错误对象冲突）；同时保留对 relevant 的引用
    "           以便后续扩展（例如统计最终成功数）。
    IF it_erroneous_objects IS INITIAL
       AND iv_repeated_initial_run = abap_false.
      ev_delete_change_pointer = abap_true.
    ELSE.
      ev_delete_change_pointer = abap_false.
    ENDIF.

    " it_relevant_objects 用于统计最终成功数并写日志
    DATA(success_cnt) = lines( it_relevant_objects ) - lines( it_erroneous_objects ).
    IF runtime_parameter_ext-bal IS BOUND.
      runtime_parameter_ext-bal->add_msg(
        iv_msgty = if_drf_const=>msg_type_info
        iv_msgid = gc_msgid
        iv_msgno = '001'
        iv_msgv1 = |{ success_cnt }|
        iv_msgv2 = |{ lines( it_erroneous_objects ) }| ).
    ENDIF.
  ENDMETHOD.


  METHOD is_ecn_valid.
    " ECN 状态校验：过滤未释放/被阻塞的 ECN（FS §6.2）。
    " 从预加载的 AENR 状态表（it_aenr_status，调用方已批量 SELECT aennr/aenst）内存校验，
    " 替代每对象一次 SELECT SINGLE（消除变更分析的 N+1 查询）。
    " 注：FS 备注 4 曾提"MAENR.AENST_M 工厂维度"——经核实该处 MAENR 系 AENR 之笔误
    "     （sapdatasheet：AENR 主键=MANDT+AENNR 唯一，状态字段=AENST，无工厂维度字段，
    "     亦无 AENNR_AUF）。故正确且完整的 ECN 校验即 AENR.AENST='2'（FS §6.2），
    "     当前实现正确，无需额外工厂维度扩展。

    rv_valid = abap_false.

    IF iv_aennr IS INITIAL.
      RETURN.
    ENDIF.

    READ TABLE it_aenr_status WITH KEY aennr = iv_aennr INTO DATA(status_line).
    IF sy-subrc <> 0.
      " AENR 无记录：ECN 不存在，判定为无效
      rv_valid = abap_false.
      RETURN.
    ENDIF.

    IF status_line-aenst IS INITIAL.
      " AENST 为空/'00'：ECN 尚未被明确赋状态，视为未释放
      rv_valid = abap_false.
    ELSE.
      IF status_line-aenst = gc_ecn_status_released.
        rv_valid = abap_true.
      ELSE.
        rv_valid = abap_false.
      ENDIF.
    ENDIF.
  ENDMETHOD.


  METHOD map_bom_header.
    " 映射 BOM Header 字段。
    " ID01: MATERIAL → copExgNo (MAST-MATNR)
    " ID06: BOM_CREATION → bomCreation (STKO-ANDAT)
    " ID07: ALTERNATIVE_BOM → alternativeBom (MAST-STLAL)
    " ID08: BOM_NO → bomNo (MAST-STLNR)
    " ID09: CHANGE_NO → changeNo (AENR-AENNR; 若 AENR 无记录则兜底用 STKO-AENNR)
    " ID10: BOM_USAGE → useTo (MAST-STLAN)
    " ID11: HEADER_START_DATE → bomStartDate (STKO-DATUV)
    " ID12: HEADER_END_DATE → bomEndDate (STKO-valid_to)
    " ID13: HEADER_QTY → copExgQty (STKO-BMENG)
    " ID14: HEADER_UNIT → copExgUnit (MARA-MEINS)

    cs_bom-cop_exg_no      = is_mast-matnr.
    cs_bom-bom_creation    = is_stko-andat.
    cs_bom-alternative_bom = is_mast-stlal.
    cs_bom-bom_no          = is_mast-stlnr.
    cs_bom-change_no       = is_stko-aennr.
    cs_bom-bom_usage       = is_mast-stlan.
    " 未来生效日期（FS §6.3）——若 ECN 的 DATUV > SY-DATUM，则显式传递 DATUV
    " 供 TARGET_SYSTEM 本地排期切换。此处直接透传 is_stko-datuv 作为 header_start_date，
    " 若大于 sy-datum 即隐含实现"未来生效"标记，无需额外字段。
    cs_bom-header_start_date = is_stko-datuv.
    " STKO 无 DATUB 字段，实际有效结束日期字段为 valid_to，其类型为 DATUB。
    cs_bom-header_end_date   = is_stko-valid_to.
    cs_bom-header_qty        = is_stko-bmeng.
    cs_bom-header_unit       = is_mara-meins.

  ENDMETHOD.


  METHOD map_bom_item.
    " 映射 BOM Item 字段。
    " ID02: COMPONENT_MATNR → copImgNo (STPO-IDNRK)
    " ID03: QUANTITY → decCm (STPO-MENGE)
    " ID04: VALID_FROM → startDate (STPO-DATUV)
    " ID05: VALID_TO → endDate (STPO-valid_to)
    " ID15: COMPONENT_UNIT → copImgUnit (STPO-MEINS)
    " ID16: OPERATION_SCRAP → OperationScrap (STPO-AVOAU, 工序损耗)
    " ID17: COMPONENT_SCRAP → ComponentScrap (STPO-AUSCH, 组件损耗)
    " 注：FS §5 变更矩阵：component scrap=AUSCH（组件损耗），operation scrap=AVOAU（工序损耗）。
    "     STPO 表中 AUSCH（类型 KAUSF）为组件损耗、AVOAU 为工序损耗，二者为独立列。

    cs_item-cop_img_no      = is_stpo-idnrk.
    cs_item-quantity        = is_stpo-menge.
    cs_item-valid_from      = is_stpo-datuv.
    " STPO 无 DATUB 字段，实际有效结束日期字段为 valid_to，其类型为 DATUB。
    cs_item-valid_to        = is_stpo-valid_to.
    cs_item-component_unit  = is_stpo-meins.
    cs_item-operation_scrap = is_stpo-avoau.
    cs_item-component_scrap = is_stpo-ausch.

  ENDMETHOD.


  METHOD build_aif_message.
    " 把本地 BOM 消息（bom_message_ty，17 字段 SAP 源值）装配成 AIF 出站消息
    "（标准结构 ppint_mfg_prodn_vers_inf），组件落点对齐 map2xml.md 与参照实现
    " /RGS/CL_P_DCB_DRF_PRODVER_OUT~map_data2message：
    "
    "   ID01 copExgNo   → production_version_information-material
    "   ID07 alternativeBom → production_version_information-bill_of_material_variant
    "   ID10 useTo      → production_version_information-bill_of_material_variant_usage
    "   ID08 bomNo      → bill_of_material
    "   ID09 changeNo   → bom_header_ecn
    "   ID11/ID12      → bom_extra_data[]-bom_validity_start/end_date
    "   ID13 copExgQty  → quantity_in_base_unit
    "   ID14 copExgUnit → base_unit
    "   ID02-ID05/ID15/ID17（组件）→ bill_of_operations_activity_ne-bill_of_operations_activity_co
    "   ID06/ID16       → 无标准 XML 落点，保留在本地 bom_message，MuleSoft 侧处理
    "
    " 注：BOM 出站场景不涉及生产版本/工序配方（bill_of_operations 网络为空），
    " 组件明细直接挂接在 bill_of_operations_activity_ne-bill_of_operations_activity_co，
    " 与参照类组件分配路径一致（数据源为 STPO 而非 PLMZ）。

    DATA ls_pv_line   TYPE ppint_prodn_vers_information.
    DATA ls_compalloc TYPE ppint_boo_acty_comp_alloc.

    CLEAR cs_aif_message.

    " 业务头（ID：消息级 id/creation_date_time/收发系统）
    cs_aif_message-manufacturing_prodn_vers_info-message_header = build_business_header( ).

    " 版本信息行：ID01/ID07/ID10（map2xml.md ProductionVersionInformation 区段）
    " material 即 BOM Header 物料（ID01）；bill_of_material_variant/usage 为 BOM 备选与用途。
    ls_pv_line-material = is_bom_message-header-cop_exg_no.
    " plant/production_version：BOM 出站无生产版本，plant 取默认工厂；
    " 其余 PV 专有字段（bill_of_operations_group 等）留空——本服务以 BOM Header 为主载。
    ls_pv_line-plant = gc_default_werks.
    ls_pv_line-bill_of_material_variant = is_bom_message-header-alternative_bom.   " ID07
    ls_pv_line-bill_of_material_variant_usage = is_bom_message-header-bom_usage.   " ID10
    APPEND ls_pv_line TO cs_aif_message-manufacturing_prodn_vers_info-production_version_information.

    " BOM Header 根层级组件（map2xml.md n1:* 区段）
    cs_aif_message-manufacturing_prodn_vers_info-bill_of_material = is_bom_message-header-bom_no.               " ID08
    cs_aif_message-manufacturing_prodn_vers_info-bom_category     = 'M'.                                        " 物料 BOM 类别（FS §7 过滤 STLTY='M'）
    cs_aif_message-manufacturing_prodn_vers_info-quantity_in_base_unit = is_bom_message-header-header_qty.        " ID13
    cs_aif_message-manufacturing_prodn_vers_info-base_unit      = is_bom_message-header-header_unit.             " ID14
    cs_aif_message-manufacturing_prodn_vers_info-bom_header_ecn = is_bom_message-header-change_no.               " ID09

    " BOM 头有效期段（ID11/ID12）→ bom_extra_data（对齐参照类 /rgs/p_dcb_pv_rgs_p_dcb_pv_bom 行）
    DATA(ls_bom_extra) = VALUE /rgs/p_dcb_pv_rgs_p_dcb_pv_bom(
      bom_header_ecn          = is_bom_message-header-change_no
      bom_validity_start_date = |{ is_bom_message-header-header_start_date DATE = ISO }|
      bom_validity_end_date   = |{ is_bom_message-header-header_end_date   DATE = ISO }|
      quantity_in_base_unit   = is_bom_message-header-header_qty
      bom_header_base_unit    = is_bom_message-header-header_unit ).
    APPEND ls_bom_extra TO cs_aif_message-manufacturing_prodn_vers_info-bom_extra_data.

    " 组件明细（ID02-ID05/ID15/ID17）→ bill_of_operations_activity_ne-bill_of_operations_activity_co
    " 对齐参照类：组件分配挂接在工序网络元素（BOM 场景无工序，用单一承载节点）。
    " 参照类 L4080：先构建组件分配内表 lt_compalloc，再赋给网络元素行的
    " bill_of_operations_activity_co，最后 APPEND 网络元素行到外层表。
    " （不能用 bill_of_operations_activity_ne[ 1 ]-... 内联索引做 APPEND 目标）
    DATA ls_acty_ne TYPE ppint_mfg_boo_acty_ntwk_elmnts.
    DATA lt_compalloc TYPE STANDARD TABLE OF ppint_boo_acty_comp_alloc.
    CLEAR: ls_acty_ne, lt_compalloc.

    LOOP AT is_bom_message-items ASSIGNING FIELD-SYMBOL(<bom_item>).
      CLEAR ls_compalloc.
      ls_compalloc-bill_of_material_category   = 'M'.
      ls_compalloc-bill_of_material            = is_bom_message-header-bom_no.
      ls_compalloc-bill_of_material_component  = <bom_item>-cop_img_no.             " ID02
      ls_compalloc-bill_of_material_item_quantity-content = <bom_item>-quantity.     " ID03
      ls_compalloc-bill_of_material_item_quantity-unit_code = <bom_item>-component_unit. " ID15
      ls_compalloc-validity_start_date         = <bom_item>-valid_from.            " ID04
      ls_compalloc-validity_end_date           = <bom_item>-valid_to.               " ID05
      " ID17 组件损耗（STPO-AUSCH）→ component_scrap_in_percent（map2xml.md n1:ComponentScrapInPercent）
      ls_compalloc-component_scrap_in_percent  = <bom_item>-component_scrap.
      APPEND ls_compalloc TO lt_compalloc.
      " ID16 工序损耗（STPO-AVOAU）：XML 无标准落点（map2xml.md §3.3），保留在本地 bom_message-items，MuleSoft 侧映射。
    ENDLOOP.

    " 将组件分配表赋给网络元素行，再 APPEND 到外层工序网络元素表
    ls_acty_ne-bill_of_operations_activity_co = lt_compalloc.
    APPEND ls_acty_ne TO cs_aif_message-manufacturing_prodn_vers_info-bill_of_operations_activity_ne.

  ENDMETHOD.


  METHOD build_business_header.
    " 构造 AIF 业务头（PPINT_BUSDOC_MSG_HDR），对齐参照实现
    " /RGS/CL_P_DCB_DRF_PRODVER_OUT~get_business_header：
    "   - id-content / uuid-content：UUID C32
    "   - creation_date_time：系统时间转 UTC（参照类 WI#WI_PLACEHOLDER 时区转换）
    "   - sender/recipient_business_system_id
    DATA: lv_guid_32   TYPE guid_32,
          lv_timestamp TYPE timestamp,
          lv_date      LIKE sy-datum,
          lv_time      LIKE sy-uzeit.

    TRY.
        lv_guid_32 = cl_system_uuid=>create_uuid_c32_static( ).
      CATCH cx_uuid_error.
        CLEAR lv_guid_32.
    ENDTRY.

    rs_header-id-content = lv_guid_32.
    rs_header-uuid-content = lv_guid_32.

    TRY.
        cl_abap_tstmp=>systemtstmp_syst2utc(
          EXPORTING
            syst_date = sy-datum
            syst_time = sy-uzeit
          IMPORTING
            utc_tstmp = lv_timestamp ).
      CATCH cx_parameter_invalid_range.
        CLEAR lv_timestamp.
    ENDTRY.

    IF lv_timestamp IS NOT INITIAL.
      CONVERT TIME STAMP lv_timestamp TIME ZONE 'UTC' INTO DATE lv_date TIME lv_time.
      TRY.
          cl_bs_soa_convert_xsddatetime=>map_xsddatetime_long_z_out(
            EXPORTING
              iv_date = lv_date
              iv_time = lv_time
            IMPORTING
              ev_xsd_datetime = rs_header-creation_date_time ).
        CATCH cx_bs_soa_exception.
          CLEAR rs_header-creation_date_time.
      ENDTRY.
    ENDIF.

    CALL FUNCTION 'LCR_GET_OWN_BUSINESS_SYSTEM'
      IMPORTING
        bs_key_name            = rs_header-sender_business_system_id
      EXCEPTIONS
        no_business_system     = 1
        no_rfc_destination     = 2
        no_landscape_directory = 3
        illegal_arguments      = 4
        communication_error    = 5
        ld_error               = 6
        OTHERS                 = 7 ##FM_SUBRC_OK.
    DATA(rc_lcr) = sy-subrc ##needed.

    rs_header-recipient_business_system_id = runtime_parameter_ext-business_system.

  ENDMETHOD.

ENDCLASS.
