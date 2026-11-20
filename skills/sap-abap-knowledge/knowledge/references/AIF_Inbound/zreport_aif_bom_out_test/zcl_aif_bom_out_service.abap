CLASS zcl_aif_bom_out_service DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

*"! <p class="shorttext synchronized">BOM outbound business service — builds ZBOM AIF message and sends via zcl_aif_outbound_util</p>
*"!
*"! Extracted from ZREPORT_AIF_BOM_OUT_TEST (derived from zcl_m1t_dcn_bom_out_impl).
*"! Separates BOM business logic (read MAST/STKO/STPO/MARA + map to the
*"! zzbomreplicate_request proxy structure) from the AIF engine interaction,
*"! which is delegated to the generic zcl_aif_outbound_util.
*"!
*"! Flow:
*"!   1. read_bom_data( ranges ) -> fills internal header/items buffer
*"!   2. build_aif_message( )     -> fills ms_aif_message (zzbomreplicate_request)
*"!   3. send( mode, ... )        -> delegates to zcl_aif_outbound_util
*"!      'A' = async (transfer_to_aif), 'R' = real-time (/AIF/SEND_WITH_PROXY)
*"!
*"! Send result is exposed read-only via get_msgguid / get_msgguid_out / get_subrc /
*"! get_error_string / is_success / get_return (forwarded to the util), so callers
*"! inspect the outcome through the service facade, without reaching into the util.
*"!
*"! Field mapping (FS §7, ID01-ID17) is identical to zcl_m1t_dcn_bom_out_impl:
*"!   ID01 material, ID02 component, ID03 quantity, ID04/05 validity,
*"!   ID06 BOM creation date, ID07 variant, ID08 BOM number, ID09 ECN,
*"!   ID10 usage, ID11/12 validity dates, ID13 base qty, ID14 base unit,
*"!   ID15 component unit, ID16 operation scrap, ID17 component scrap.

  PUBLIC SECTION.

    " Local BOM buffer types (SAP source values, FS §7 17 fields)
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
      ty_bom_items TYPE STANDARD TABLE OF ty_bom_item WITH EMPTY KEY.

    " Range types for read_bom_data.
    " Method parameter typing cannot use "TYPE RANGE OF" inline (ABAP typing rule:
    " RANGE OF is a standalone type declaration only allowed in TYPES/DATA/etc.).
    " Therefore the ranges are declared here once and referenced by name.
    TYPES:
      ty_rng_matnr TYPE RANGE OF mast-matnr,
      ty_rng_werks TYPE RANGE OF mast-werks,
      ty_rng_stlan TYPE RANGE OF mast-stlan,
      ty_rng_stlal TYPE RANGE OF mast-stlal,
      ty_rng_stlnr TYPE RANGE OF stko-stlnr.

    METHODS constructor
      IMPORTING
        !iv_ns           TYPE /aif/ns
        !iv_ifname       TYPE /aif/ifname
        !iv_ifversion    TYPE /aif/ifversion
        !iv_logical_port TYPE prx_logical_port_name
        !iv_recipient    TYPE string
        !iv_plant        TYPE werks_d DEFAULT 'Q511'.

    " ① 取数：MAST/STKO/STPO/MARA -> 内部缓冲（本服务只取第一条 BOM）
    METHODS read_bom_data
      IMPORTING
        !it_matnr       TYPE ty_rng_matnr
        !it_werks       TYPE ty_rng_werks
        !it_stlan       TYPE ty_rng_stlan
        !it_stlal       TYPE ty_rng_stlal
        !it_stlnr       TYPE ty_rng_stlnr
      RETURNING
        VALUE(rv_found) TYPE abap_bool.

    " ② 构建 zzbomreplicate_request（AIF sap_struct）
    METHODS build_aif_message
      RETURNING
        VALUE(rv_ok) TYPE abap_bool.

    " ③ 发送（A=异步 / R=实时），委托 zcl_aif_outbound_util
    METHODS send
      IMPORTING
        !iv_mode        TYPE char1 DEFAULT 'A'
        !iv_test        TYPE abap_bool DEFAULT abap_true
        !iv_persist_xml TYPE abap_bool DEFAULT abap_false
        !iv_queue       TYPE abap_bool DEFAULT abap_false
        !iv_update      TYPE abap_bool DEFAULT abap_false
        !iv_queue_name  TYPE /aif/pers_rtcfgr_name DEFAULT 'T01'
      RETURNING
        VALUE(rv_ok)    TYPE abap_bool.

    " 访问器
    METHODS get_aif_message
      RETURNING
        VALUE(rs_message) TYPE zzbomreplicate_request.

    " 结果只读访问器（转发到 zcl_aif_outbound_util）：
    " 调用方经本服务层即可读取发送结果，无需（也无法）深入 util，保持服务层封装。
    " 语义与 zcl_aif_outbound_util 的对应访问器一致：
    "   get_msgguid       消息 GUID（ev_msgguid，异步模式）
    "   get_msgguid_out   出站消息 GUID（ximsgguid_out，实时模式）
    "   get_subrc         /AIF/SEND_WITH_PROXY 原始 sy-subrc（0=成功，1=persistency_error 容忍，2..7=硬错误）
    "   get_error_string  硬错误文本（业务级 E/A 错误时为空）
    "   is_success        发送成功（业务级 E/A 错误为 false）
    "   get_return        add_return_tab（bapiret2），实时模式返回码
    METHODS get_msgguid
      RETURNING
        VALUE(rv_msgguid) TYPE sxmsmguid.
    METHODS get_msgguid_out
      RETURNING
        VALUE(rv_msgguid_out) TYPE sxmsmguid.
    METHODS get_subrc
      RETURNING
        VALUE(rv_subrc) TYPE syst_subrc.
    METHODS get_error_string
      RETURNING
        VALUE(rv_error_string) TYPE string.
    METHODS is_success
      RETURNING
        VALUE(rv_success) TYPE abap_bool.
    METHODS get_return
      RETURNING
        VALUE(rt_return) TYPE bapiret2_t.

  PRIVATE SECTION.

    DATA ms_header      TYPE ty_bom_header.
    DATA mt_items       TYPE ty_bom_items.
    DATA ms_aif_message TYPE zzbomreplicate_request.
    DATA mo_util        TYPE REF TO zcl_aif_outbound_util.
    DATA mv_plant       TYPE werks_d.
    DATA mv_recipient   TYPE string.

    " 构建业务头（UUID / creation_date_time / 收发业务系统）
    METHODS build_business_header
      RETURNING
        VALUE(rs_header) TYPE zbusiness_document_message_hea.

ENDCLASS.


CLASS zcl_aif_bom_out_service IMPLEMENTATION.


  METHOD constructor.

    mv_plant     = iv_plant.
    mv_recipient = iv_recipient.

    mo_util = NEW zcl_aif_outbound_util(
      iv_ns           = iv_ns
      iv_ifname       = iv_ifname
      iv_ifversion    = iv_ifversion
      iv_logical_port = iv_logical_port ).

  ENDMETHOD.


  METHOD read_bom_data.

    DATA: lt_mast TYPE STANDARD TABLE OF mast,
          lt_stpo TYPE STANDARD TABLE OF stpo,
          ls_mast TYPE mast,
          ls_stko TYPE stko,
          ls_stpo TYPE stpo,
          ls_mara TYPE mara,
          ls_item TYPE ty_bom_item.

    rv_found = abap_false.
    CLEAR: ms_header, mt_items, ms_aif_message.

    " MAST
    SELECT matnr, stlan, werks, stlal, stlnr
      FROM mast
      INTO CORRESPONDING FIELDS OF TABLE @lt_mast
      WHERE matnr IN @it_matnr
        AND werks IN @it_werks
        AND stlan IN @it_stlan
        AND stlal IN @it_stlal
        AND stlnr IN @it_stlnr.

    IF lt_mast IS INITIAL.
      RETURN.
    ENDIF.

    " 本服务只发 1 条 BOM 消息：取第一条
    ls_mast = VALUE #( lt_mast[ 1 ] ).

    " STKO（BOM 头）
    SELECT SINGLE stlnr, stlty, aennr, andat, datuv, bmeng, valid_to
      FROM stko
      INTO CORRESPONDING FIELDS OF @ls_stko
      WHERE stlnr = @ls_mast-stlnr
        AND stlty = 'M'.
    IF ls_stko IS INITIAL.
      RETURN.
    ENDIF.

    " STPO（BOM 行项目）
    SELECT stlnr, stlty, stlkn, idnrk, menge, datuv, valid_to, meins, avoau, ausch
      FROM stpo
      INTO CORRESPONDING FIELDS OF TABLE @lt_stpo
      WHERE stlnr = @ls_stko-stlnr
        AND stlty = 'M'.

    " MARA（物料基本单位）
    SELECT SINGLE matnr, meins
      FROM mara
      INTO @ls_mara
      WHERE matnr = @ls_mast-matnr.

    " 映射 header
    ms_header-cop_exg_no        = ls_mast-matnr.
    ms_header-bom_creation      = ls_stko-andat.
    ms_header-alternative_bom   = ls_mast-stlal.
    ms_header-bom_no            = ls_mast-stlnr.
    ms_header-change_no         = ls_stko-aennr.
    ms_header-bom_usage         = ls_mast-stlan.
    ms_header-header_start_date = ls_stko-datuv.
    ms_header-header_end_date   = ls_stko-valid_to.
    ms_header-header_qty        = ls_stko-bmeng.
    ms_header-header_unit       = ls_mara-meins.

    " 映射 items
    LOOP AT lt_stpo INTO ls_stpo.
      CLEAR ls_item.
      ls_item-cop_img_no      = ls_stpo-idnrk.
      ls_item-quantity        = ls_stpo-menge.
      ls_item-valid_from      = ls_stpo-datuv.
      ls_item-valid_to        = ls_stpo-valid_to.
      ls_item-component_unit  = ls_stpo-meins.
      ls_item-operation_scrap = ls_stpo-avoau.
      ls_item-component_scrap = ls_stpo-ausch.
      APPEND ls_item TO mt_items.
    ENDLOOP.

    rv_found = abap_true.

  ENDMETHOD.


  METHOD build_aif_message.

    DATA: ls_component       TYPE zbomcomponent_type,
          lv_material_ext    TYPE matnr,
          lv_commercial_unit TYPE c LENGTH 3.

    rv_ok = abap_false.
    CLEAR ms_aif_message.

    " ① 业务头（UUID / creation_date_time / 收发业务系统）
    ms_aif_message-parameters-message_header = build_business_header( ).

    " ② BOM 头（ID01, ID06-ID14）
    " ID01: 物料 -> 外部格式
    CALL FUNCTION 'CONVERSION_EXIT_MATN1_OUTPUT'
      EXPORTING
        input  = ms_header-cop_exg_no
      IMPORTING
        output = lv_material_ext.
    ms_aif_message-parameters-bom-bomheader-material = lv_material_ext.

    ms_aif_message-parameters-bom-bomheader-plant                           = mv_plant.
    ms_aif_message-parameters-bom-bomheader-bomcategory                     = 'M'.
    ms_aif_message-parameters-bom-bomheader-bill_of_material                = ms_header-bom_no.           " ID08
    ms_aif_message-parameters-bom-bomheader-bill_of_material_variant        = ms_header-alternative_bom.  " ID07
    ms_aif_message-parameters-bom-bomheader-bill_of_material_variant_usage  = ms_header-bom_usage.        " ID10
    ms_aif_message-parameters-bom-bomheader-bomheader_quantity_in_base_uni  = ms_header-header_qty.       " ID13

    " ID14: 基本单位 -> 商业格式
    CALL FUNCTION 'CONVERSION_EXIT_CUNIT_OUTPUT'
      EXPORTING
        input          = ms_header-header_unit
        language       = 'E'
      IMPORTING
        output         = lv_commercial_unit
      EXCEPTIONS
        unit_not_found = 1
        OTHERS         = 2.
    IF sy-subrc = 0.
      ms_aif_message-parameters-bom-bomheader-bomheader_base_unit = lv_commercial_unit.
    ELSE.
      ms_aif_message-parameters-bom-bomheader-bomheader_base_unit = ms_header-header_unit.
    ENDIF.
    SHIFT ms_aif_message-parameters-bom-bomheader-bomheader_base_unit RIGHT DELETING TRAILING space.
    SHIFT ms_aif_message-parameters-bom-bomheader-bomheader_base_unit LEFT  DELETING LEADING space.

    ms_aif_message-parameters-bom-bomheader-bomheader_ecn            = ms_header-change_no.         " ID09
    ms_aif_message-parameters-bom-bomheader-bomcreation_date         = ms_header-bom_creation.      " ID06
    ms_aif_message-parameters-bom-bomheader-bomvalidity_start_date   = ms_header-header_start_date. " ID11
    ms_aif_message-parameters-bom-bomheader-bomvalidity_end_date     = ms_header-header_end_date.   " ID12

    " ③ BOM 行项目（ID02-ID05, ID15-ID17）
    LOOP AT mt_items ASSIGNING FIELD-SYMBOL(<ls_item>).
      CLEAR ls_component.

      " ID02: 组件物料 -> 外部格式
      CALL FUNCTION 'CONVERSION_EXIT_MATN1_OUTPUT'
        EXPORTING
          input  = <ls_item>-cop_img_no
        IMPORTING
          output = lv_material_ext.
      ls_component-bill_of_material_component = lv_material_ext.

      ls_component-bill_of_material_item_quantity-content = <ls_item>-quantity.   " ID03

      " ID15: 组件单位 -> 商业格式
      CALL FUNCTION 'CONVERSION_EXIT_CUNIT_OUTPUT'
        EXPORTING
          input          = <ls_item>-component_unit
          language       = 'E'
        IMPORTING
          output         = lv_commercial_unit
        EXCEPTIONS
          unit_not_found = 1
          OTHERS         = 2.
      IF sy-subrc = 0.
        ls_component-bill_of_material_item_quantity-unit_code = lv_commercial_unit.
      ELSE.
        ls_component-bill_of_material_item_quantity-unit_code = <ls_item>-component_unit.
      ENDIF.
      SHIFT ls_component-bill_of_material_item_quantity-unit_code RIGHT DELETING TRAILING space.
      SHIFT ls_component-bill_of_material_item_quantity-unit_code LEFT  DELETING LEADING space.

      ls_component-validity_start_date     = <ls_item>-valid_from.        " ID04
      ls_component-validity_end_date       = <ls_item>-valid_to.          " ID05
      ls_component-component_scrap_in_percent  = <ls_item>-component_scrap.  " ID17
      ls_component-operation_scrap_in_percent  = <ls_item>-operation_scrap.  " ID16
      APPEND ls_component TO ms_aif_message-parameters-bom-bomcomponent.
    ENDLOOP.

    rv_ok = abap_true.

  ENDMETHOD.


  METHOD send.

    rv_ok = abap_false.

    " 覆盖 creation_date_time at send time（CET -> UTC -> zglobal_date_time）
    " 经 zcl_aif_outbound_util=>get_current_xsd_datetime( )（内部：sy-datum/sy-uzeit + convert_timestamp + map_xsddatetime_long_z_out）
    ms_aif_message-parameters-message_header-creation_date_time =
      zcl_aif_outbound_util=>get_current_xsd_datetime( ).

    " 测试运行：不实际发送
    IF iv_test = abap_true.
      rv_ok = abap_true.
      RETURN.
    ENDIF.

    IF iv_mode = 'A'.
      " 异步：send_async（transfer_to_aif + 可选持久化 + 可选队列）一次调用
      rv_ok = mo_util->send_async(
        is_message     = ms_aif_message
        iv_persist_xml = iv_persist_xml
        iv_queue       = iv_queue
        iv_queue_name  = iv_queue_name ).

    ELSE.
      " 实时：/AIF/SEND_WITH_PROXY（登记 + 立即推送），委托 zcl_aif_outbound_util。
      " 工具类对 sy-subrc=0/1（0=成功，1=persistency_error 仅 XML 持久化失败但已推送）
      " 视为成功并容忍，仅 2..7 为硬错误；精确错误码经 get_subrc( ) 获取，
      " 调用方可据此区分硬错误（非 0/1）与业务错误（0/1 且 add_return_tab 含 E/A 行）。
      IF mo_util->send_with_proxy(
          EXPORTING
           iv_persist_xml = abap_true
           CHANGING
             cs_message = ms_aif_message ) = abap_true.
        rv_ok = abap_true.
      ELSE.
        " 失败：get_error_text( ) 已封装"硬错误文本优先、否则按 subrc 生成可读概要"，
        " 保证 set_error_status 总有可写内容。
        DATA(lv_err_text) = mo_util->get_error_text( ).
        " 可选：失败时写状态
        IF iv_update = abap_true.
          mo_util->set_error_status(
            iv_msgguid    = mo_util->get_msgguid_out( )
            is_message    = ms_aif_message
            iv_error_text = lv_err_text ).
        ENDIF.
      ENDIF.
    ENDIF.

  ENDMETHOD.


  METHOD get_aif_message.
    rs_message = ms_aif_message.
  ENDMETHOD.


  METHOD get_msgguid.
    rv_msgguid = mo_util->get_msgguid( ).
  ENDMETHOD.


  METHOD get_msgguid_out.
    rv_msgguid_out = mo_util->get_msgguid_out( ).
  ENDMETHOD.


  METHOD get_subrc.
    rv_subrc = mo_util->get_subrc( ).
  ENDMETHOD.


  METHOD get_error_string.
    rv_error_string = mo_util->get_error_string( ).
  ENDMETHOD.


  METHOD is_success.
    rv_success = mo_util->is_success( ).
  ENDMETHOD.


  METHOD get_return.
    rt_return = mo_util->get_return( ).
  ENDMETHOD.


  METHOD build_business_header.

    DATA: lv_guid_32   TYPE guid_32,
          lv_timestamp TYPE timestamp,
          lv_date      LIKE sy-datum,
          lv_time      LIKE sy-uzeit.

    TRY.
        lv_guid_32 = cl_system_uuid=>create_uuid_c32_static( ).
      CATCH cx_uuid_error.
        CLEAR lv_guid_32.
    ENDTRY.

    rs_header-id-content   = lv_guid_32.
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
              iv_date         = lv_date
              iv_time         = lv_time
            IMPORTING
              ev_xsd_datetime = rs_header-creation_date_time ).
        CATCH cx_bs_soa_exception.
          CLEAR rs_header-creation_date_time.
      ENDTRY.
    ENDIF.

    " 发送方业务系统 ID：取本系统
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

    " 接收方业务系统 ID（调用方提供）
    rs_header-recipient_business_system_id = mv_recipient.

  ENDMETHOD.

ENDCLASS.
