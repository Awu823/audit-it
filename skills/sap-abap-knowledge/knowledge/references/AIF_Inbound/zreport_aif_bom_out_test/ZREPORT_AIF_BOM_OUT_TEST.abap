*&---------------------------------------------------------------------*
*& Report zdemo_aif_out_test
*&---------------------------------------------------------------------*
* 独立触发 AIF BOM 出站（不依赖 DRF 框架）
*
* 业务逻辑与 AIF 逻辑已提取到可复用类：
*   - zcl_aif_outbound_util   通用 AIF 出站工具（任意接口可复用）
*   - zcl_aif_bom_out_service BOM 业务服务（取数 + 构建消息 + 委托发送）
*
* 本 Report 只保留屏幕选择与结果展示，作为上述类的薄壳驱动。
*
* 发送模式（p_mode）：
*   A = 异步：transfer_to_aif（只登记到 AIF 引擎，不实际推送外部系统）
*   R = 实时：/AIF/SEND_WITH_PROXY + 逻辑端口（登记 + 立即推送到 MuleSoft）
*
* 可选 AIF 补充动作：
*   p_pst = 持久化 XML（异步模式下 Mule 拉取消息体）
*   p_queue   = 进出站队列（异步模式下 Mule 拉取触发）
*   p_update  = 失败时写状态（实时模式下失败时写错误）
*
* 前置条件（目标系统必须已配置）：
*   - /AIF/CUST 登记接口 ZDEMO/ZDEMOIF/1（direction=Outbound）
*   - DDIC 结构 zzbomreplicate_request + 子结构已激活
*   - 业务系统已登记（LCR_GET_OWN_BUSINESS_SYSTEM 取本系统）
*   - （仅实时模式 R 需要）逻辑端口 ZBOMOUT 已配置
*&---------------------------------------------------------------------*

REPORT zdemo_aif_out_test.

TABLES: mast, stko.
*&--------------------------------------------------------------------*
*& 屏幕选择参数
*&--------------------------------------------------------------------*
SELECTION-SCREEN BEGIN OF BLOCK b1 WITH FRAME TITLE TEXT-001.
  SELECT-OPTIONS: s_matnr FOR mast-matnr,
                  s_werks FOR mast-werks,
                  s_stlan FOR mast-stlan,
                  s_stlal FOR mast-stlal,
                  s_stlnr FOR stko-stlnr.
  PARAMETERS:
    p_bukrs  TYPE bukrs DEFAULT 'Q511',                  " 工厂
    p_mode   TYPE c LENGTH 1 AS LISTBOX VISIBLE LENGTH 10 DEFAULT 'A',  " 发送模式：A=异步 / R=实时
    p_lp     TYPE prx_logical_port_name DEFAULT 'ZBOMOUT', " 逻辑端口（仅 R 模式需要）
    p_recip  TYPE string DEFAULT 'MES_BS_IMP_LM',  " 接收方业务系统 ID
    p_test   TYPE abap_bool AS CHECKBOX DEFAULT 'X',    " 测试运行（不实际发送）
    p_pst    TYPE abap_bool AS CHECKBOX,               " 持久化 XML（异步模式有意义）
    p_queue  TYPE abap_bool AS CHECKBOX,               " 进出站队列（异步模式 Mule 拉取）
    p_update TYPE abap_bool AS CHECKBOX.               " 失败时写状态（实时模式有意义）
SELECTION-SCREEN END OF BLOCK b1.

*&--------------------------------------------------------------------*
*& 事件
*&--------------------------------------------------------------------*
INITIALIZATION.

  CALL FUNCTION 'VRM_SET_VALUES'
    EXPORTING
      id              = 'P_MODE'
      values          = VALUE vrm_values( ( key = 'A' text = 'Asynchronous' )
                                          ( key = 'R' text = 'Real time' ) )
    EXCEPTIONS
      id_illegal_name = 1
      OTHERS          = 2.

*&--------------------------------------------------------------------*
*& 事件
*&--------------------------------------------------------------------*
START-OF-SELECTION.

  " ① 服务实例化（AIF 接口键 + 逻辑端口 + 接收方 + 工厂）
  DATA(lo_svc) = NEW zcl_aif_bom_out_service(
    iv_ns           = 'ZDEMO'
    iv_ifname       = 'ZDEMOIF'
    iv_ifversion    = '1'
    iv_logical_port = p_lp
    iv_recipient    = p_recip
    iv_plant        = p_bukrs ).

  " ② 取数（MAST/STKO/STPO/MARA）
  IF lo_svc->read_bom_data(
       it_matnr = s_matnr[]
       it_werks = s_werks[]
       it_stlan = s_stlan[]
       it_stlal = s_stlal[]
       it_stlnr = s_stlnr[] ) = abap_false.
    MESSAGE '无匹配 BOM 数据（MAST/STKO/STPO/MARA）' TYPE 'S'.
    RETURN.
  ENDIF.

  " ③ 构建 zzbomreplicate_request
  IF lo_svc->build_aif_message( ) = abap_false.
    MESSAGE 'AIF 消息构建失败' TYPE 'E'.
    RETURN.
  ENDIF.

  " ④ 发送（委托 zcl_aif_outbound_util）
  DATA(lv_ok) = lo_svc->send(
    iv_mode        = p_mode
    iv_test        = p_test
    iv_persist_xml = p_pst
    iv_queue       = p_queue
    iv_update      = p_update
    iv_queue_name  = 'T01' ).

  " ⑤ 显示结果（经服务层访问器读取，不深入 util）
  " get_return( ) 返回按值拷贝（右值），不可作 CHANGING 实参 → 先赋局部变量
  DATA(lt_return) = lo_svc->get_return( ).

  IF p_mode = 'R' AND lt_return IS NOT INITIAL.
    cl_salv_table=>factory(
      IMPORTING
        r_salv_table = DATA(lo_alv)
      CHANGING
        t_table      = lt_return ).
    TRY.
        DATA(lo_display) = lo_alv->get_display_settings( ).
        lo_display->set_list_header( 'AIF 实时发送返回码' ).
        lo_alv->display( ).
      CATCH cx_salv_error INTO DATA(lo_exc).
        " 显示失败不影响主流程
    ENDTRY.
  ENDIF.

  IF p_test = abap_true.
    MESSAGE |测试运行模式：未实际发送（GUID 未生成）| TYPE 'S'.
  ELSEIF lv_ok = abap_true.
    " 异步只产生 msgguid（ev_msgguid）；实时才产生 msgguid_out（ximsgguid_out）
    IF p_mode = 'A'.
      MESSAGE |AIF 异步登记成功，消息 GUID = { lo_svc->get_msgguid( ) }（未实际推送外部系统）| TYPE 'S'.
    ELSE.
      MESSAGE |AIF 实时发送成功，消息 GUID = { lo_svc->get_msgguid_out( ) }| TYPE 'S'.
    ENDIF.
  ELSE.
    MESSAGE |AIF 发送失败：{ lo_svc->get_error_string( ) }| TYPE 'E'.
  ENDIF.