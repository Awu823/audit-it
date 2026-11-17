*"! <p class="shorttext synchronized">DRF BOM 出站：框架适配层（S4H → TARGET_SYSTEM）</p>
*"!
*"! 该类只做 IF_DRF_OUTBOUND 的生命周期适配，不含业务逻辑。
*"! 业务逻辑全部下沉到 ZCL_M1T_DCN_BOM_CHANGE（单例）。
*"! 对应 FS：BOM SAP to TARGET_SYSTEM interface (DRF_BIZ_OBJ / AIF_MSGID)
CLASS ZCL_M1T_DCN_BOM_OUT DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    INTERFACES if_drf_outbound.


  PRIVATE SECTION.

    CLASS-DATA drf_bom_out TYPE REF TO ZCL_M1T_DCN_BOM_CHANGE.
    CLASS-DATA gc_key_structure       TYPE string
                             VALUE 'ZCL_M1T_DCN_BOM_CHANGE=>key_table_ty' ##NO_TEXT.

ENDCLASS.


CLASS ZCL_M1T_DCN_BOM_OUT IMPLEMENTATION.

  METHOD if_drf_outbound~initialize.
    " 静态方法：框架此刻还没有实例，必须在此创建并交出实例引用。
    " 先创建业务单例并传入运行时参数，再创建本适配层实例返回给框架。
    drf_bom_out = NEW ZCL_M1T_DCN_BOM_CHANGE( ).
    drf_bom_out->runtime_parameter_ext = is_runtime_param.

    " 告诉框架本实现处理的对象键表类型（框架据此构造 SORTED TABLE）。
    es_runtime_param_out_impl-table_type_name = gc_key_structure.

    " Single object per package (package_size = 1), avoiding the production bug of sending only the
    " last message when multiple objects are batched together (FS §2 / §13 message semantics).
    es_runtime_param_out_impl-package_size = 1.

    " 返回本类（OUT）实例——OUT 实现 if_drf_outbound，BIZ 不实现。
    eo_if_drf_outbound = NEW ZCL_M1T_DCN_BOM_OUT( ).
  ENDMETHOD.


  METHOD if_drf_outbound~analyze_changes_by_chg_pointer.
    " BIZ 定义：IMPORTING it_change_pointer / EXPORTING et_changed_objects, es_stat_info
    " 调用方向与定义相反：EXPORTING 传参、IMPORTING 收参。
    drf_bom_out->analyze_changes_by_chg_pointer(
      EXPORTING it_change_pointer = it_change_pointer
      IMPORTING et_changed_objects = ct_changed_objects
                es_stat_info       = es_stat_info ).
  ENDMETHOD.


  METHOD if_drf_outbound~analyze_changes_by_mdg_cp.
    " MDG Change Pointer 模式：未启用时保持空实现。
  ENDMETHOD.


  METHOD if_drf_outbound~apply_node_inst_filter_multi.
    " 节点实例过滤：默认不启用，保持 ct_relevant_objects 不变。
  ENDMETHOD.


  METHOD if_drf_outbound~apply_node_inst_filter_single.
    " 节点实例过滤：默认不启用，保持 cr_relevant_object 不变。
  ENDMETHOD.


  METHOD if_drf_outbound~analyze_changes_by_others.
    drf_bom_out->analyze_changes_by_others(
      IMPORTING et_changed_objects = ct_changed_objects
                es_stat_info       = es_stat_info ).
  ENDMETHOD.


  METHOD if_drf_outbound~enrich_filter_criteria.
    " BIZ 定义：IMPORTING it_external_criteria / EXPORTING es_stat_info, et_add_external_criteria
    drf_bom_out->enrich_filter_criteria(
      EXPORTING it_external_criteria     = it_external_criteria
      IMPORTING es_stat_info             = es_stat_info
                et_add_external_criteria = et_add_external_criteria ).
  ENDMETHOD.


  METHOD if_drf_outbound~read_complete_data.
    drf_bom_out->read_complete_data(
      CHANGING ct_relevant_objects = ct_relevant_objects ).
  ENDMETHOD.


  METHOD if_drf_outbound~map_data2message.
    " 接口签名：MAP_DATA2MESSAGE 只有 ir_relevant_object(REF TO data) 一个参数。
    " BIZ 定义：IMPORTING ir_relevant_object；消息内容经业务单例属性承载，由 send_message 取出。
    drf_bom_out->map_data2message(
      EXPORTING ir_relevant_object = ir_relevant_object ).
  ENDMETHOD.


  METHOD if_drf_outbound~send_message.
    " BIZ 定义：IMPORTING is_file_info, iv_object_count / EXPORTING et_file_data, et_message / CHANGING ct_obj_rep_sta
    drf_bom_out->send_message(
      EXPORTING is_file_info    = is_file_info
                iv_object_count = iv_object_count
      IMPORTING et_file_data    = et_file_data
                et_message      = et_message
      CHANGING  ct_obj_rep_sta  = ct_obj_rep_sta ).
  ENDMETHOD.


  METHOD if_drf_outbound~build_parallel_package.
    " 并行包拆分：未启用。
  ENDMETHOD.


  METHOD if_drf_outbound~finalize.
    drf_bom_out->finalize(
      EXPORTING it_erroneous_objects   = it_erroneous_objects
                it_relevant_objects     = it_relevant_objects
                iv_repeated_initial_run = iv_repeated_initial_run
      IMPORTING ev_delete_change_pointer = ev_delete_change_pointer ).
  ENDMETHOD.

ENDCLASS.
