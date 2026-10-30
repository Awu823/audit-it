*"! <p class="shorttext synchronized">DRF BOM 出站：业务处理单例（S4H → ECMS）</p>
*"!
*"! 承载全部业务逻辑：变更分析、过滤、批量取数、消息映射、AIF 发送、结果回写。
*"! 由框架适配层 ZCL_DCN_PBOM_OUT 通过 CLASS-DATA 单例引用调用。
*"! 对应 FS：BOM SAP to ECMS interface (ZCN_ECMS / ZDCN_PBOM)
CLASS zcl_dcn_pbom_biz DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

*"! BOM 对象键表类型
    TYPES:
      BEGIN OF ty_bom_key,
        stlan TYPE stlan,   " BOM usage
        werks TYPE werks_d, " Plant
        matnr TYPE matnr,   " Material
        stlal TYPE stlal,   " Alternative BOM
        stlty TYPE stlty,   " BOM Category
        aennr TYPE aennr,   " ECN
      END OF ty_bom_key,
      tt_key_table TYPE SORTED TABLE OF ty_bom_key
               WITH UNIQUE KEY stlan werks matnr stlal stlty aennr.
    DATA ms_runtime_parameter_ext TYPE drf_s_runtime_parameter_ext.

    METHODS analyze_changes_by_chg_pointer
      IMPORTING it_change_pointer  TYPE drf_t_bdcp
      EXPORTING et_changed_objects TYPE tt_key_table
                es_stat_info       TYPE drf_s_stat_info
      RAISING   cx_drf_analyze_changes
                cx_drf_exception.

    METHODS analyze_changes_by_others
      EXPORTING et_changed_objects TYPE tt_key_table
                es_stat_info       TYPE drf_s_stat_info
      RAISING   cx_drf_analyze_changes
                cx_drf_exception.

    METHODS enrich_filter_criteria
      IMPORTING it_external_criteria     TYPE rsds_trange
      EXPORTING es_stat_info             TYPE drf_s_stat_info
                et_add_external_criteria TYPE rsds_trange
      RAISING   cx_drf_exception.

    METHODS read_complete_data
      CHANGING ct_relevant_objects TYPE tt_key_table
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
      IMPORTING it_erroneous_objects     TYPE tt_key_table
                it_relevant_objects      TYPE tt_key_table
                iv_repeated_initial_run  TYPE boole_d
      EXPORTING ev_delete_change_pointer TYPE boole_d.

  PRIVATE SECTION.

*" --- AIF 接口参数（来自 FS 配置） ---
    CONSTANTS iv_ns            TYPE /aif/ns        VALUE 'ZDECMS'  ##NO_TEXT.
    CONSTANTS iv_ifname        TYPE /aif/ifname    VALUE 'ZO_PBOM' ##NO_TEXT.
    CONSTANTS iv_ifver         TYPE /aif/ifversion VALUE '1'        ##NO_TEXT.
    CONSTANTS iv_logical_port  TYPE string         VALUE 'ZECMSBOMOUT' ##NO_TEXT.
    CONSTANTS gc_msgid         TYPE symsgid        VALUE 'ZDCN_PBOM'  ##NO_TEXT.

*" --- BOM 变更指针相关常量 ---
    CONSTANTS gc_cp_tabname_mast TYPE cdtabkey   VALUE 'MAST'  ##NO_TEXT.
    CONSTANTS gc_cp_tabname_stko TYPE cdtabkey   VALUE 'STKO'  ##NO_TEXT.
    CONSTANTS gc_cp_tabname_stpo TYPE cdtabkey   VALUE 'STPO'  ##NO_TEXT.

*" --- ECN 状态常量 ---
    CONSTANTS gc_ecn_status_released TYPE aenst VALUE '2' ##NO_TEXT.  " '2'=Released

*" --- 量级控制常量（FS §14：站点上线割接期最小 300/天，最大 1000/天） ---
    " analyze_changes_by_others（Initial / 手动按需）单次取数的对象上限。
    " 对齐 FS §14 最大 1000 文档/天，防止无界面输入时按默认条件全量扫描超限。
    CONSTANTS gc_initial_max_rows TYPE i VALUE 1000 ##NO_TEXT.

    " --- ECMS 消息结构（17 个字段，FS §7） ---
    TYPES:
      BEGIN OF ty_bom_header,
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
      END OF ty_bom_header,
      BEGIN OF ty_bom_item,
        cop_img_no      TYPE idnrk,
        quantity        TYPE kmpmg,
        valid_from      TYPE datuv,
        valid_to        TYPE datub,
        component_unit  TYPE meins,
        operation_scrap TYPE ausch,
        component_scrap TYPE ausch,
      END OF ty_bom_item,
      ty_bom_items TYPE STANDARD TABLE OF ty_bom_item WITH EMPTY KEY,
      BEGIN OF ty_bom_message,
        header TYPE ty_bom_header,
        items  TYPE ty_bom_items,
      END OF ty_bom_message.

    DATA mt_mast         TYPE STANDARD TABLE OF mast.
    DATA mt_stko         TYPE STANDARD TABLE OF stko.
    DATA mt_stpo         TYPE STANDARD TABLE OF stpo.
    DATA mt_aenr         TYPE STANDARD TABLE OF aenr WITH EMPTY KEY.
    DATA mt_mara         TYPE STANDARD TABLE OF mara.
    DATA ms_bom_header   TYPE ty_bom_header.
    DATA ms_bom_items    TYPE ty_bom_items.
    DATA ms_bom_message  TYPE ty_bom_message.

    METHODS is_ecn_valid
      IMPORTING iv_aennr        TYPE aennr
      RETURNING VALUE(rv_valid) TYPE boole_d.

    METHODS map_bom_header
      IMPORTING is_stko TYPE stko
                is_mast TYPE mast
                is_mara TYPE mara
      CHANGING  cs_bom  TYPE ty_bom_header.

    METHODS map_bom_item
      IMPORTING is_stpo TYPE stpo
      CHANGING  cs_item TYPE ty_bom_item.

ENDCLASS.


CLASS zcl_dcn_pbom_biz IMPLEMENTATION.

  METHOD analyze_changes_by_chg_pointer.
    " 变更分析（Change Pointer 模式）：从变更指针表提取 BOM 对象键。
    " FS §5 变更触发矩阵：DRF_T_BDCP 对象级凝聚，无字段级过滤。
    " CDOBJID 格式（按标准 SAP 主键顺序拼接）：
    "   MAST: MATNR(18)+WERKS(4)+STLAN(1)+STLAL(2)   ← P0-2 修正
    "   STKO: STLTY(1)+STLNR(8)
    "   STPO: STLTY(1)+STLNR(8)+POSNR(6)

    DATA lt_cp          TYPE drf_t_bdcp.
    DATA lt_keys        TYPE tt_key_table.
    DATA ls_key         TYPE ty_bom_key.
    DATA lt_range       TYPE RANGE OF stnum.
    DATA lt_mast_lookup TYPE STANDARD TABLE OF mast WITH EMPTY KEY.

    " 临时：MAST CDOBJID 解析结果，用于批量反查 STLNR
    TYPES:
      BEGIN OF ty_mast_cp_key,
        matnr TYPE matnr,
        werks TYPE werks_d,
        stlan TYPE stlan,
        stlal TYPE stlal,
      END OF ty_mast_cp_key.
    DATA lt_mast_cp_keys TYPE STANDARD TABLE OF ty_mast_cp_key WITH EMPTY KEY.

    lt_cp = it_change_pointer.

    " NOTE: DRF_T_BDCP 是"Storage-Optimized Change Pointer"（对象级凝聚），
    " 不携带字段级信息，故仅按对象维度去重。
    " drf_s_bdcp 结构字段：cpident / tabname / tabkey / fldname / cdobjcl / cdobjid 等；
    " 本处按 tabname+cdobjid 排序去重（tabname 区分 MAST/STKO/STPO）。
    SORT lt_cp BY tabname cdobjid.
    DELETE ADJACENT DUPLICATES FROM lt_cp COMPARING tabname cdobjid.

    " 注：DRF 选择参数（WERKS/MATNR/STLAN/STLAL/DATUV/DATUB）由 DRF 框架在查询
    "     CDHDR 生成变更指针时已按配置表过滤，业务代码不应假设 ms_runtime_parameter_ext
    "     中存在 sel_mara/sel_stko 等具体字段（DRF_S_RUNTIME_PARAMETER_EXT 结构不含此等组件）。
    "     业务代码在此只处理已由框架过滤后的对象级变更指针。

    " --- 1. MAST 变更：解析 CDOBJID → 批量反查 STLNR 并入 lt_range ---
    "        修复 P0-2：CDOBJID 偏移必须与 SAP 标准 MAST 主键顺序一致
    "        (MATNR+WERKS+STLAN+STLAL)；修复 P0-3：对象不再被 100% 丢弃
    LOOP AT lt_cp INTO DATA(ls_cp) WHERE tabname = gc_cp_tabname_mast.
      INSERT VALUE ty_mast_cp_key(
        matnr = ls_cp-cdobjid+0(18)
        werks = ls_cp-cdobjid+18(4)
        stlan = ls_cp-cdobjid+22(1)
        stlal = ls_cp-cdobjid+23(2) ) INTO TABLE lt_mast_cp_keys.
    ENDLOOP.

    IF lt_mast_cp_keys IS NOT INITIAL.
      SELECT m~stlnr
        FROM mast AS m
        INTO TABLE @DATA(lt_mast_stlnr_res)
        FOR ALL ENTRIES IN @lt_mast_cp_keys
        WHERE m~matnr = @lt_mast_cp_keys-matnr
          AND m~werks = @lt_mast_cp_keys-werks
          AND m~stlan = @lt_mast_cp_keys-stlan
          AND m~stlal = @lt_mast_cp_keys-stlal.
      LOOP AT lt_mast_stlnr_res INTO DATA(ls_ms).
        INSERT VALUE #( sign = 'I' option = 'EQ' low = ls_ms-stlnr )
          INTO TABLE lt_range.
      ENDLOOP.
    ENDIF.

    " --- 2. STKO 变更：对象级触发（DRF_T_BDCP 不含字段级信息） ---
    LOOP AT lt_cp INTO DATA(ls_cp2) WHERE tabname = gc_cp_tabname_stko.
      INSERT VALUE #( sign = 'I' option = 'EQ' low = ls_cp2-cdobjid+1(8) )
        INTO TABLE lt_range.
    ENDLOOP.

    " --- 3. STPO 变更：对象级触发（DRF_T_BDCP 不含字段级信息） ---
    LOOP AT lt_cp INTO DATA(ls_cp3) WHERE tabname = gc_cp_tabname_stpo.
      INSERT VALUE #( sign = 'I' option = 'EQ' low = ls_cp3-cdobjid+1(8) )
        INTO TABLE lt_range.
    ENDLOOP.

    " --- 4. 反查 MAST/STKO 获取完整 BOM 键及 ECN ---
    "       STLNR 已由 CP 的 CDOBJID 精确定位；此处不再追加 STLAN 过滤
    "       （CP 本身已含工厂/BOM 用途维度，追加过滤反而可能漏发多 MAST 关联场景）。
    IF lt_range IS NOT INITIAL.
      " 按 STLNR 反查 MAST（STLTY/AENNR 由 STKO 提供，MAST 中无此二字段）
      " 说明：同一 STLNR 在 MAST 中可关联多个 (matnr/werks/stlan/stlal) 组合，
      "       全部返回以便下游为每个 BOM 链接发一条消息。
      SELECT matnr, stlan, werks, stlal, stlnr
        FROM mast
        INTO CORRESPONDING FIELDS OF TABLE @lt_mast_lookup
        WHERE stlnr IN @lt_range.
      " 读取 STKO 的 STLTY/AENNR
      SELECT stlnr, stlty, aennr
        FROM stko
        INTO TABLE @DATA(lt_stko_aennr)
        FOR ALL ENTRIES IN @lt_mast_lookup
        WHERE stlnr = @lt_mast_lookup-stlnr.
      LOOP AT lt_mast_lookup INTO DATA(ls_m).
        CLEAR ls_key.
        ls_key-stlan = ls_m-stlan.
        ls_key-werks = ls_m-werks.
        ls_key-matnr = ls_m-matnr.
        ls_key-stlal = ls_m-stlal.
        " 从 STKO 获取 STLTY 与 AENNR（同一 STLNR 首个 ECN 版本）
        LOOP AT lt_stko_aennr INTO DATA(ls_stko_a) WHERE stlnr = ls_m-stlnr.
          ls_key-stlty = ls_stko_a-stlty.
          ls_key-aennr = ls_stko_a-aennr.
          EXIT.
        ENDLOOP.
        INSERT ls_key INTO TABLE lt_keys.
      ENDLOOP.
    ENDIF.

    " --- 5. ECN 状态校验（FS §5：所有变更类型均需 ECN） ---
    "       修复 N-4：统计被过滤的对象数（无 ECN 或 ECN 未释放），
    "       便于运维在 DRF 运行日志中识别"因 ECN 被过滤"的对象。
    DATA lv_ecn_filtered_cnt TYPE i.
    LOOP AT lt_keys INTO ls_key.
      IF ls_key-aennr IS NOT INITIAL
         AND is_ecn_valid( ls_key-aennr ) = abap_true.
        INSERT ls_key INTO TABLE et_changed_objects.
      ELSE.
        lv_ecn_filtered_cnt = lv_ecn_filtered_cnt + 1.
      ENDIF.
    ENDLOOP.

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
    " 拿不到界面值。Initial 场景按 FS §4 默认值（WERKS='Q511'、STLAN='1'）取数
    " 作为候选范围，实际过滤由框架在 CP 查询阶段用 enrich_filter_criteria 返回的
    " 条件收紧（见 enrich_filter_criteria，仅在配置了 filter object 时生效）。
    DATA: lv_werks TYPE werks_d VALUE 'Q511',   " FS §4 默认 Plant
          lv_stlan TYPE stlan   VALUE '1'.      " FS §4 默认 BOM Usage

    DATA lt_mast_all TYPE STANDARD TABLE OF mast WITH EMPTY KEY.
    DATA lt_keys     TYPE tt_key_table.
    DATA ls_key      TYPE ty_bom_key.

    " 默认过滤条件（FS §4）：WERKS='Q511', STLAN='1'
    " 注：MAST 中不含 STLTY/AENNR，二者由 STKO 提供
    " 量级控制（FS §14）：上线割接期最大 1000/天，UP TO 上限防止无界面输入时
    " 按默认条件全量扫描超限；增量由 Nightly CP 模式（变更指针）承担，
    " Initial 模式仅做基础加载 + 量级上限兜底。
    SELECT matnr, stlan, werks, stlal, stlnr
      FROM mast
      INTO CORRESPONDING FIELDS OF TABLE @lt_mast_all
      UP TO @gc_initial_max_rows ROWS
      WHERE werks = @lv_werks
        AND stlan = @lv_stlan.

    IF lt_mast_all IS NOT INITIAL.
      " 批量反查 STKO 获取 STLTY/AENNR（ECN）
      SELECT stlnr, stlty, aennr
        FROM stko
        INTO TABLE @DATA(lt_stko_aennr)
        FOR ALL ENTRIES IN @lt_mast_all
        WHERE stlnr = @lt_mast_all-stlnr.
      LOOP AT lt_mast_all INTO DATA(ls_m).
        CLEAR ls_key.
        ls_key-stlan = ls_m-stlan.
        ls_key-werks = ls_m-werks.
        ls_key-matnr = ls_m-matnr.
        ls_key-stlal = ls_m-stlal.
        LOOP AT lt_stko_aennr INTO DATA(ls_stko_a) WHERE stlnr = ls_m-stlnr.
          ls_key-stlty = ls_stko_a-stlty.
          ls_key-aennr = ls_stko_a-aennr.
          EXIT.
        ENDLOOP.
        " ECN 是必要条件（FS §5）：仅保留有有效 ECN 的 BOM
        IF ls_key-aennr IS NOT INITIAL
           AND is_ecn_valid( ls_key-aennr ) = abap_true.
          INSERT ls_key INTO TABLE lt_keys.
        ENDIF.
      ENDLOOP.
      et_changed_objects = lt_keys.
    ENDIF.

    " "
    es_stat_info-object_count_out = lines( et_changed_objects ).
  ENDMETHOD.


  METHOD enrich_filter_criteria.
    " DRF 选择参数（FS §4）由 DRFOUT 界面输入，框架以 rsds_trange 经 it_external_criteria
    " 传入（tablename='MAST'/'STKO'，fieldname=字段名，selopt_t=sign/option/low/high）。
    " 本方法解析界面值，按 FS §4 补齐必填默认值，重建为 et_add_external_criteria：
    "   MAST-WERKS  必填，缺省 Q511
    "   MAST-MATNR  可选
    "   MAST-STLAN  必填，缺省 1
    "   MAST-STLAL  可选
    "   STKO-DATUV  可选（Valid-From）
    "   STKO-DATUB  可选（Valid-To）
    " 参考资源 CL_P_MCN_DRF_BATCH_OUT.abap:736-780 / CL_P_DCB_DRF_PROCORD_OUT.abap:1173-1202
    DATA: lt_werks    TYPE rsds_selopt_t, lt_matnr TYPE rsds_selopt_t,
          lt_stlan    TYPE rsds_selopt_t, lt_stlal TYPE rsds_selopt_t,
          lt_datuv    TYPE rsds_selopt_t, lt_datub TYPE rsds_selopt_t,
          ls_selopt   TYPE rsdsselopt,
          ls_selfield TYPE rsds_frange,
          ls_seltab   TYPE rsds_range.

    " 修复 M-1：始终解析界面选择条件并输出 et_add_external_criteria（参考在产实现
    " CL_P_MCN_DRF_BATCH_OUT.abap:736-780，enrich_filter_criteria 不因 fobj 短路）。
    " DRF 框架用返回的条件收窄 change pointer 查询（CP 模式：Nightly/Ad-Hoc 生效），
    " 确保界面输入 WERKS/MATNR/STLAN/STLAL/DATUV/DATUB 对取数生效。
    " 注：Initial（by_others）模式受 DRF 架构限制拿不到界面值，由 analyze_changes_by_others
    "     的默认条件（FS §4: WERKS=Q511/STLAN=1）兜底。

    " 1. 解析界面输入（it_external_criteria），按 tablename/fieldname 分流
    LOOP AT it_external_criteria ASSIGNING FIELD-SYMBOL(<ls_range>).
      LOOP AT <ls_range>-frange_t ASSIGNING FIELD-SYMBOL(<ls_frange>).
        CASE <ls_frange>-fieldname.
          WHEN 'WERKS'.
            APPEND LINES OF <ls_frange>-selopt_t TO lt_werks.
          WHEN 'MATNR'.
            APPEND LINES OF <ls_frange>-selopt_t TO lt_matnr.
          WHEN 'STLAN'.
            APPEND LINES OF <ls_frange>-selopt_t TO lt_stlan.
          WHEN 'STLAL'.
            APPEND LINES OF <ls_frange>-selopt_t TO lt_stlal.
          WHEN 'DATUV'.
            APPEND LINES OF <ls_frange>-selopt_t TO lt_datuv.
          WHEN 'DATUB'.
            APPEND LINES OF <ls_frange>-selopt_t TO lt_datub.
        ENDCASE.
      ENDLOOP.
    ENDLOOP.

    " 2. FS §4 必填项缺省补齐（WERKS=Q511、STLAN=1）
    IF lines( lt_werks ) = 0.
      ls_selopt-sign   = 'I'.
      ls_selopt-option = 'EQ'.
      ls_selopt-low    = 'Q511'.
      APPEND ls_selopt TO lt_werks.
      CLEAR ls_selopt.
    ENDIF.
    IF lines( lt_stlan ) = 0.
      ls_selopt-sign   = 'I'.
      ls_selopt-option = 'EQ'.
      ls_selopt-low    = '1'.
      APPEND ls_selopt TO lt_stlan.
      CLEAR ls_selopt.
    ENDIF.

    " 3. 重建 et_add_external_criteria：MAST 表（WERKS/MATNR/STLAN/STLAL）
    ls_seltab-tablename = 'MAST'.
    IF lines( lt_werks ) > 0.
      ls_selfield-fieldname = 'WERKS'.
      APPEND LINES OF lt_werks TO ls_selfield-selopt_t.
      APPEND ls_selfield TO ls_seltab-frange_t.
      CLEAR ls_selfield.
    ENDIF.
    IF lines( lt_matnr ) > 0.
      ls_selfield-fieldname = 'MATNR'.
      APPEND LINES OF lt_matnr TO ls_selfield-selopt_t.
      APPEND ls_selfield TO ls_seltab-frange_t.
      CLEAR ls_selfield.
    ENDIF.
    IF lines( lt_stlan ) > 0.
      ls_selfield-fieldname = 'STLAN'.
      APPEND LINES OF lt_stlan TO ls_selfield-selopt_t.
      APPEND ls_selfield TO ls_seltab-frange_t.
      CLEAR ls_selfield.
    ENDIF.
    IF lines( lt_stlal ) > 0.
      ls_selfield-fieldname = 'STLAL'.
      APPEND LINES OF lt_stlal TO ls_selfield-selopt_t.
      APPEND ls_selfield TO ls_seltab-frange_t.
      CLEAR ls_selfield.
    ENDIF.
    IF lines( ls_seltab-frange_t ) > 0.
      APPEND ls_seltab TO et_add_external_criteria.
    ENDIF.
    CLEAR ls_seltab.

    " 4. STKO 表（DATUV/DATUB，有效日期区间）
    ls_seltab-tablename = 'STKO'.
    IF lines( lt_datuv ) > 0.
      ls_selfield-fieldname = 'DATUV'.
      APPEND LINES OF lt_datuv TO ls_selfield-selopt_t.
      APPEND ls_selfield TO ls_seltab-frange_t.
      CLEAR ls_selfield.
    ENDIF.
    IF lines( lt_datub ) > 0.
      ls_selfield-fieldname = 'DATUB'.
      APPEND LINES OF lt_datub TO ls_selfield-selopt_t.
      APPEND ls_selfield TO ls_seltab-frange_t.
      CLEAR ls_selfield.
    ENDIF.
    IF lines( ls_seltab-frange_t ) > 0.
      APPEND ls_seltab TO et_add_external_criteria.
    ENDIF.
    CLEAR ls_seltab.
  ENDMETHOD.


  METHOD read_complete_data.
    " 批量读取 BOM 完整数据到缓冲区。
    " 流程：清空缓冲区 → 读取 MAST/STKO/STPO/MARA → 填充缓冲区

    CLEAR: mt_mast, mt_stko, mt_stpo, mt_mara.

    IF ct_relevant_objects IS NOT INITIAL.
      " 读取 MAST (BOM link) — 用 INNER JOIN 匹配 ct_relevant_objects 的 4 列主键
      " 说明：MAST 中不含 AENNR / STLTY，二者需由 STKO 补全。
      SELECT m~matnr, m~stlan, m~werks, m~stlal, m~stlnr
        FROM mast AS m
        INNER JOIN @ct_relevant_objects AS r
          ON  m~matnr = r~matnr
          AND m~stlan = r~stlan
          AND m~werks = r~werks
          AND m~stlal = r~stlal
        INTO CORRESPONDING FIELDS OF TABLE @mt_mast.

      IF mt_mast IS NOT INITIAL.
        " 读取 STKO (BOM header) — 提供 STLTY / AENNR / ANDAT / DATUV / BMENG / valid_to
        " 修复 B-2：Open SQL 禁止 SELECT * 与 JOIN 并用，改为显式列名 + CORRESPONDING
        SELECT k~stlnr, k~stlty, k~aennr, k~andat, k~datuv, k~bmeng, k~valid_to
          FROM stko AS k
          INNER JOIN @mt_mast AS m
            ON k~stlnr = m~stlnr
          INTO CORRESPONDING FIELDS OF TABLE @mt_stko.

        " 读取 STPO (BOM item) — 提供 IDNRK/MENGE/DATUV/valid_to/MEINS/AVOAU/AUSCH/AENNR
        " 修复 B-2：Open SQL 禁止 SELECT * 与 JOIN 并用，改为显式列名 + CORRESPONDING
        SELECT p~stlnr, p~stlty, p~idnrk, p~menge, p~datuv, p~valid_to,
               p~meins, p~avoau, p~ausch, p~aennr
          FROM stpo AS p
          INNER JOIN @mt_mast AS m
            ON p~stlnr = m~stlnr
          INTO CORRESPONDING FIELDS OF TABLE @mt_stpo.
      ENDIF.

      " 读取 MARA (Header UoM - ID14, Component UoM - ID15)
      DATA lt_matnr_set TYPE SORTED TABLE OF matnr WITH UNIQUE KEY table_line.
      LOOP AT mt_mast INTO DATA(ls_mm).
        INSERT ls_mm-matnr INTO TABLE lt_matnr_set.
      ENDLOOP.
      LOOP AT mt_stpo INTO DATA(ls_sp).
        INSERT ls_sp-idnrk INTO TABLE lt_matnr_set.
      ENDLOOP.
      IF lt_matnr_set IS NOT INITIAL.
        SELECT matnr, meins FROM mara
          INTO CORRESPONDING FIELDS OF TABLE @mt_mara
          FOR ALL ENTRIES IN @lt_matnr_set
          WHERE matnr = @lt_matnr_set-table_line.
      ENDIF.

      " 读取 AENR (工程变更主表) — 提供 AENNR 用于 ID09 changeNo（FS §7）
      DATA lt_aennr_set TYPE SORTED TABLE OF aennr WITH UNIQUE KEY table_line.
      LOOP AT ct_relevant_objects INTO DATA(ls_key_aenr).
        IF ls_key_aenr-aennr IS NOT INITIAL.
          INSERT ls_key_aenr-aennr INTO TABLE lt_aennr_set.
        ENDIF.
      ENDLOOP.
      IF lt_aennr_set IS NOT INITIAL.
        SELECT aennr FROM aenr
          INTO CORRESPONDING FIELDS OF TABLE @mt_aenr
          FOR ALL ENTRIES IN @lt_aennr_set
          WHERE aennr = @lt_aennr_set-table_line.
      ENDIF.
    ENDIF.

  ENDMETHOD.


  METHOD map_data2message.
    " 将 BOM 数据映射到 ECMS 消息结构。
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

    FIELD-SYMBOLS <ls_key> TYPE ty_bom_key.
    DATA lv_stlnr TYPE stnum.
    DATA lv_stlty TYPE stlty.
    DATA ls_mara  TYPE mara.
    DATA ls_stko  TYPE stko.

    CLEAR: ms_bom_header, ms_bom_items.

    IF ir_relevant_object IS NOT BOUND.
      RAISE EXCEPTION TYPE cx_drf_exception.
    ENDIF.

    " 使用 FIELD-SYMBOLS 读取对象键字段（REF TO data 无法直接 ->* 成员）。
    ASSIGN ir_relevant_object->* TO <ls_key>.
    IF sy-subrc <> 0.
      RAISE EXCEPTION TYPE cx_drf_exception.
    ENDIF.

    READ TABLE mt_mast WITH KEY stlan = <ls_key>-stlan
                                werks = <ls_key>-werks
                                matnr = <ls_key>-matnr
                                stlal = <ls_key>-stlal
      INTO DATA(ls_mast).
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    lv_stlnr = ls_mast-stlnr.
    lv_stlty = <ls_key>-stlty.

    " 获取 STKO (BOM Header - ID06/09/11/12/13)，按对象键 ECN 版本对齐（修复 H-2）
    READ TABLE mt_stko WITH KEY stlnr = lv_stlnr stlty = lv_stlty aennr = <ls_key>-aennr
      INTO ls_stko.
    IF sy-subrc <> 0.
      " 兜底：对象键无 ECN 或 STKO 无该版本时，取该 STLNR 的首条记录
      READ TABLE mt_stko WITH KEY stlnr = lv_stlnr stlty = lv_stlty
        INTO ls_stko.
    ENDIF.

    " 获取 MARA (Header UoM - ID14)
    READ TABLE mt_mara WITH KEY matnr = ls_mast-matnr INTO ls_mara.

    " 映射 Header (ID01, ID06-ID14)
    map_bom_header(
      EXPORTING is_stko = ls_stko
                is_mast = ls_mast
                is_mara = ls_mara
      CHANGING  cs_bom  = ms_bom_header
                 ).

    " 映射 Items (ID02-ID05, ID15-ID17)
    " 冗余清理：ID15 COMPONENT_UNIT 直接取自 STPO-MEINS（FS §7），
    " 原逻辑按组件物料 READ TABLE mt_mara 查 UoM 后经 is_mara 传入，
    " 但 map_bom_item 从未使用 is_mara，故移除该冗余读取与传参。
    LOOP AT mt_stpo INTO DATA(ls_stpo) WHERE stlnr = lv_stlnr AND stlty = lv_stlty.
      DATA ls_item TYPE ty_bom_item.
      map_bom_item(
        EXPORTING is_stpo = ls_stpo
        CHANGING  cs_item = ls_item
                  ).
      APPEND ls_item TO ms_bom_items.
    ENDLOOP.

    ms_bom_message-header = ms_bom_header.
    ms_bom_message-items  = ms_bom_items.

  ENDMETHOD.


  METHOD send_message.
    " AIF 发送逻辑（FS §3）。
    " CONSTANTS: iv_ns='ZDECMS', iv_ifname='ZO_PBOM', iv_ifver='1'

    " FS §10：错误对象五要素（MATNR/WERKS/IDNRK/AENNR）预取首个组件的 IDNRK
    DATA: ls_errmsg  TYPE drf_s_message,
          lr_bapiret TYPE REF TO bapiret2,
          lv_idnrk   TYPE idnrk.
    IF lines( ms_bom_items ) > 0.
      lv_idnrk = ms_bom_items[ 1 ]-cop_img_no.
    ENDIF.

    IF ms_bom_message-header IS INITIAL AND ms_bom_message-items IS INITIAL.
      RETURN.
    ENDIF.

    " 修复 P2-7：发送前做必填字段非空校验（FS §7 M 标记）。
    "   Header 级 M 字段：ID01 copExgNo、ID13 headerQty
    "   Item 级 M 字段：ID02 copImgNo、ID03 quantity、ID16 operationScrap、ID17 componentScrap
    "   若 Header 无值或 Header 必填字段缺失，直接标 E 返回，避免空消息送达 ECMS。
    IF ms_bom_message-header IS INITIAL
       OR ms_bom_message-header-cop_exg_no IS INITIAL
       OR ms_bom_message-header-header_qty IS INITIAL.
      LOOP AT ct_obj_rep_sta ASSIGNING FIELD-SYMBOL(<ls_sta_init>).
        <ls_sta_init>-repstatus = 'SE'.
      ENDLOOP.
      " FS §10：错误对象五要素 → AIF 错误上下文（drf_s_message-message → bapiret2）
      CREATE DATA lr_bapiret.
      lr_bapiret->type       = 'E'.
      lr_bapiret->id         = gc_msgid.
      lr_bapiret->number     = '001'.
      lr_bapiret->message_v1 = ms_bom_header-cop_exg_no.   " Parent Material (MATNR)
      lr_bapiret->message_v2 = 'Q511'.                     " Plant (WERKS, FS §10 固定)
      lr_bapiret->message_v3 = lv_idnrk.                   " Component Item (IDNRK)
      lr_bapiret->message_v4 = ms_bom_header-change_no.    " ECN (AENNR)
      ls_errmsg-bo_type       = 'BILL_OF_MATERIAL'.        " Production BOM 主对象
      ls_errmsg-bo_key        = ms_bom_header-cop_exg_no.  " 对象 ID (MATNR)
      ls_errmsg-target_system = iv_logical_port.           " ECMS 目标系统
      ls_errmsg-message       = lr_bapiret.
      APPEND ls_errmsg TO et_message.
      CLEAR: ls_errmsg, lr_bapiret.
      " 修复 M-3：对象级 AIF 错误日志（FS §10/§11 五要素上下文）
      IF ms_runtime_parameter_ext-bal IS BOUND.
        ms_runtime_parameter_ext-bal->add_msg(
          iv_msgty = if_drf_const=>msg_type_error
          iv_msgid = gc_msgid
          iv_msgno = '001'
          iv_msgv1 = ms_bom_header-cop_exg_no
          iv_msgv2 = 'Q511'
          iv_msgv3 = lv_idnrk
          iv_msgv4 = ms_bom_header-change_no ).
      ENDIF.
      CLEAR: ms_bom_message, ms_bom_header, ms_bom_items.
      RETURN.
    ENDIF.
    " Item 级必填字段校验：仅当 items 非空时逐条检查，避免"仅 Header BOM"被误拒
    LOOP AT ms_bom_message-items ASSIGNING FIELD-SYMBOL(<ls_item_chk>).
      IF <ls_item_chk>-cop_img_no IS INITIAL
         OR <ls_item_chk>-quantity IS INITIAL
         OR <ls_item_chk>-operation_scrap < 0
         OR <ls_item_chk>-component_scrap < 0.
        LOOP AT ct_obj_rep_sta ASSIGNING FIELD-SYMBOL(<ls_sta_miss>).
          <ls_sta_miss>-repstatus = 'SE'.
        ENDLOOP.
        " FS §10：错误对象五要素 → AIF 错误上下文（drf_s_message-message → bapiret2）
        CREATE DATA lr_bapiret.
        lr_bapiret->type       = 'E'.
        lr_bapiret->id         = gc_msgid.
        lr_bapiret->number     = '001'.
        lr_bapiret->message_v1 = ms_bom_header-cop_exg_no.   " Parent Material (MATNR)
        lr_bapiret->message_v2 = 'Q511'.                     " Plant (WERKS, FS §10 固定)
        lr_bapiret->message_v3 = <ls_item_chk>-cop_img_no.   " Component Item (IDNRK)
        lr_bapiret->message_v4 = ms_bom_header-change_no.    " ECN (AENNR)
        ls_errmsg-bo_type       = 'BILL_OF_MATERIAL'.        " Production BOM 主对象
        ls_errmsg-bo_key        = ms_bom_header-cop_exg_no.  " 对象 ID (MATNR)
        ls_errmsg-target_system = iv_logical_port.           " ECMS 目标系统
        ls_errmsg-message       = lr_bapiret.
        APPEND ls_errmsg TO et_message.
        CLEAR: ls_errmsg, lr_bapiret.
        " 修复 M-3：对象级 AIF 错误日志（FS §10/§11 五要素上下文）
        IF ms_runtime_parameter_ext-bal IS BOUND.
          ms_runtime_parameter_ext-bal->add_msg(
            iv_msgty = if_drf_const=>msg_type_error
            iv_msgid = gc_msgid
            iv_msgno = '001'
            iv_msgv1 = ms_bom_header-cop_exg_no
            iv_msgv2 = 'Q511'
            iv_msgv3 = <ls_item_chk>-cop_img_no
            iv_msgv4 = ms_bom_header-change_no ).
        ENDIF.
        CLEAR: ms_bom_message, ms_bom_header, ms_bom_items.
        RETURN.
      ENDIF.
    ENDLOOP.

    " 沿用与在产实现 CL_P_DCB_DRF_PROCORD_OUT.abap 行 2984-3039 一致的
    " /AIF/SEND_WITH_PROXY 函数模块路径；/AIF/CL_ENABLER 类不存在。
    " 注：/AIF/CL_ENABLER_XML 等子类虽存在，但需自建日志与 return 收集，
    " 与在产实现不一致，不推荐（见 analysis result/BOM_S4_代码校对报告.md §P0-6）。
    " 分片发送（FS §2.2）：XML 单文件最大 2000 行，超量拆分为多批次 API 调用。

    DATA: lt_return         TYPE STANDARD TABLE OF bapiret2,
          lv_msgguid        TYPE  sxmsmguid,
          lv_msgguid_out    TYPE  sxmsmguid,
          lv_error_string   TYPE string,
          lv_error_long     TYPE string,
          lv_all_ok         TYPE abap_bool VALUE abap_true,
          lv_pkg_size       TYPE i VALUE 2000,
          lv_total          TYPE i,
          lv_start          TYPE i,
          lv_end            TYPE i,
          ls_batch_msg      TYPE ty_bom_message,
          lt_batch_items    TYPE ty_bom_items,
          lv_batch_idx      TYPE i,
          lv_header         TYPE bal_s_log,
          lv_subobject      TYPE balsubobj,
          lr_bom_msg        TYPE REF TO ty_bom_message,
          lo_wsproto_msg_id TYPE REF TO if_wsprotocol_message_id.

    lv_total = lines( ms_bom_message-items ).
    lv_pkg_size = 2000.
    " 至少 1 批（含仅 Header BOM 的场景）；超量按 2000 条组件拆批
    lv_batch_idx = 1.
    IF lv_total > 0.
      lv_batch_idx = ( lv_total + lv_pkg_size - 1 ) DIV lv_pkg_size.
    ENDIF.

    DO lv_batch_idx TIMES.
      lv_start = ( sy-index - 1 ) * lv_pkg_size + 1.
      lv_end = nmin( val1 = sy-index * lv_pkg_size  val2 = lv_total ).
      CLEAR: lt_batch_items, ls_batch_msg.
      IF lv_total > 0.
        LOOP AT ms_bom_message-items INTO DATA(ls_batch_item) FROM lv_start TO lv_end.
          APPEND ls_batch_item TO lt_batch_items.
        ENDLOOP.
      ENDIF.
      ls_batch_msg-header = ms_bom_message-header.
      ls_batch_msg-items  = lt_batch_items.

      CLEAR lt_return.

      " 建立 AIF 应用日志（对齐在产实现行 2984-2991）
      lv_header-aldate    = sy-datum.
      lv_header-aluser    = sy-uname.
      lv_header-alchuser  = sy-uname.
      CONCATENATE iv_ns iv_ifname INTO lv_subobject SEPARATED BY space.
      lv_header-object    = /aif/if_globals=>gc_aif_log_obj.
      lv_header-subobject = lv_subobject.
      CALL FUNCTION '/AIF/CREATE_APPL_LOG'
        EXPORTING
          is_header_log = lv_header
          iv_ns         = iv_ns
          iv_ifname     = iv_ifname
          iv_ifversion  = iv_ifver
        CHANGING
          ct_return     = lt_return.

      CALL FUNCTION '/AIF/SEND_WITH_PROXY'
        EXPORTING
          ns                   = iv_ns
          ifname               = iv_ifname
          ifversion            = iv_ifver
          appl_log_function    = 'AIF_SEND_WITH_PROXY'
          msgguid              = lv_msgguid
          iv_persist_xml       = 'X'
          logical_port_name    = iv_logical_port
        IMPORTING
          ximsgguid            = lv_msgguid
          ximsgguid_out        = lv_msgguid_out
        TABLES
          add_return_tab       = lt_return
        CHANGING
          sap_struct           = ls_batch_msg
          error_string         = lv_error_string
          error_long_text      = lv_error_long
        EXCEPTIONS
          persistency_error    = 1
          status_update_failed = 2
          missing_keys         = 3
          interface_not_found  = 4
          transformation_error = 5
          general_error        = 6
          OTHERS               = 7.

      IF sy-subrc <> 0.
        lv_all_ok = abap_false.
        " FS §10：错误对象五要素 → AIF 错误上下文（drf_s_message-message → bapiret2）
        CREATE DATA lr_bapiret.
        lr_bapiret->type       = 'E'.
        lr_bapiret->id         = gc_msgid.
        lr_bapiret->number     = '002'.
        lr_bapiret->message_v1 = ms_bom_header-cop_exg_no.   " Parent Material (MATNR)
        lr_bapiret->message_v2 = 'Q511'.                     " Plant (WERKS, FS §10 固定)
        lr_bapiret->message_v3 = lv_idnrk.                   " Component Item (IDNRK)
        lr_bapiret->message_v4 = ms_bom_header-change_no.    " ECN (AENNR)
        ls_errmsg-bo_type       = 'BILL_OF_MATERIAL'.        " Production BOM 主对象
        ls_errmsg-bo_key        = ms_bom_header-cop_exg_no.  " 对象 ID (MATNR)
        ls_errmsg-target_system = iv_logical_port.           " ECMS 目标系统
        ls_errmsg-message       = lr_bapiret.
        APPEND ls_errmsg TO et_message.
        CLEAR: ls_errmsg, lr_bapiret.
        " 修复 M-3：对象级 AIF 错误日志（FS §10/§11 五要素上下文）
        IF ms_runtime_parameter_ext-bal IS BOUND.
          ms_runtime_parameter_ext-bal->add_msg(
            iv_msgty = if_drf_const=>msg_type_error
            iv_msgid = gc_msgid
            iv_msgno = '002'
            iv_msgv1 = ms_bom_header-cop_exg_no
            iv_msgv2 = 'Q511'
            iv_msgv3 = lv_idnrk
            iv_msgv4 = ms_bom_header-change_no ).
        ENDIF.
      ENDIF.

      " 对象级 AIF 日志：关联 GUID + 载荷（对齐在产实现行 3092-3100）
      " BOM 经 /AIF/SEND_WITH_PROXY 发送，无 SOAP proxy → io_message_id_protocol 传空引用
      GET REFERENCE OF ms_bom_message INTO lr_bom_msg.
      IF ms_runtime_parameter_ext-bal IS BOUND.
        ms_runtime_parameter_ext-bal->add_msg_xi(
          iv_xi_msg_guid         = lv_msgguid_out
          iv_object_count        = iv_object_count
          io_message_id_protocol = lo_wsproto_msg_id
          iv_outb_impl           = ms_runtime_parameter_ext-outb_impl
          ir_object              = lr_bom_msg
          is_message_out         = ms_bom_message ).
      ENDIF.
    ENDDO.

    " 修复 N-1：恢复并修正返回处理块（按全批次聚合结果）。
    " 语义：所有批次 sy-subrc = 0（成功）时把对象标记为 'SN'（Sent/No error）；
    "       任一批次失败则标记为 'SE'。DRF drf_repstat 域常用值：'SN'=成功、'E'=错误。
    IF lv_all_ok = abap_true.
      LOOP AT ct_obj_rep_sta ASSIGNING FIELD-SYMBOL(<ls_sta_ok>).
        <ls_sta_ok>-repstatus = 'SN'.
      ENDLOOP.
      " 修复 M-3：对象级 AIF 成功日志（FS §11 监控）
      IF ms_runtime_parameter_ext-bal IS BOUND.
        ms_runtime_parameter_ext-bal->add_msg(
          iv_msgty = if_drf_const=>msg_type_success
          iv_msgid = gc_msgid
          iv_msgno = '001'
          iv_msgv1 = ms_bom_header-cop_exg_no ).
      ENDIF.
    ELSE.
      LOOP AT ct_obj_rep_sta ASSIGNING FIELD-SYMBOL(<ls_sta_err>).
        <ls_sta_err>-repstatus = 'SE'.
      ENDLOOP.
    ENDIF.

    CLEAR: ms_bom_message, ms_bom_header, ms_bom_items.
  ENDMETHOD.


  METHOD finalize.
    " FS §10：仅在无错误对象时删除变更指针，否则保留以便重执行。
    " 修复 N-6：区分 Initial Run 重跑场景——重复初始加载下框架本就不生成 CP，
    "           此时不应删除（避免与残留错误对象冲突）；同时保留对 relevant 的引用
    "           以便后续扩展（例如统计最终成功数）。
    IF it_erroneous_objects IS INITIAL
       AND iv_repeated_initial_run = abap_false.
      ev_delete_change_pointer = abap_true.
    ELSE.
      ev_delete_change_pointer = abap_false.
    ENDIF.
  ENDMETHOD.


  METHOD is_ecn_valid.
    " ECN 状态校验：过滤未释放/被阻塞的 ECN（FS §6.2）。
    " 检查 AENR 主表状态；AENR 无记录 / 状态为空 / 状态非 '2' 均视为未释放。
    " 修复 P1-5 + P2-11：原逻辑对 AENST 初值（'00'/空）没有兜底判据，
    "                     会被误当作"有效"放行；同时未做 MAENR 校验。
    " 注：MAENR（BOM/ECN 关联表）按工厂维度生效，如启用需传入 werks，
    "     当前先聚焦 AENR 主表；MAENR 校验留 TODO 供后续扩展。

    rv_valid = abap_false.

    IF iv_aennr IS INITIAL.
      RETURN.
    ENDIF.

    SELECT SINGLE aenst FROM aenr INTO @DATA(lv_status)
      WHERE aennr = @iv_aennr.
    IF sy-subrc <> 0.
      " AENR 无记录：ECN 不存在，判定为无效
      rv_valid = abap_false.
      RETURN.
    ENDIF.

    IF lv_status IS INITIAL.
      " AENST 为空/'00'：ECN 尚未被明确赋状态，视为未释放
      rv_valid = abap_false.
    ELSE.
      IF lv_status = gc_ecn_status_released.
        rv_valid = abap_true.
      ELSE.
        rv_valid = abap_false.
      ENDIF.
    ENDIF.

    " TODO: P1-5 扩展——增加 MAENR 工厂维度校验：
    "   IF lv_status = gc_ecn_status_released.
    "     SELECT SINGLE datub FROM maenr
    "       WHERE stlnr=? AND aennr=? AND werks=? INTO ...
    "     IF sy-subrc = 0. " 该工厂下 ECN 已生效，视为有效
    "   ENDIF.
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
    " 优先从 AENR 主表取 AENNR（FS §7 指定源为 AENR-AENNR），找不到则兜底用 STKO-AENNR
    READ TABLE mt_aenr WITH KEY aennr = is_stko-aennr INTO DATA(ls_aenr).
    IF sy-subrc = 0 AND ls_aenr-aennr IS NOT INITIAL.
      cs_bom-change_no = ls_aenr-aennr.
    ENDIF.
    cs_bom-bom_usage       = is_mast-stlan.
    " 修复 M-2（FS §6.3）：未来生效日期——若 ECN 的 DATUV > SY-DATUM，则显式传递 DATUV
    " 供 ECMS 本地排期切换。此处直接透传 is_stko-datuv 作为 header_start_date，
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

ENDCLASS.
