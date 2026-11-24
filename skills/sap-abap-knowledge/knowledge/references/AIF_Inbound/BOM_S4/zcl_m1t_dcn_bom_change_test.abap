CLASS zcl_m1t_dcn_bom_change_test DEFINITION FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS.
  PRIVATE SECTION.
    DATA: cut_obj TYPE REF TO zcl_m1t_dcn_bom_change.
    " class_setup/class_teardown 是静态方法，需用 CLASS-DATA 持有环境与 mock 数据
    CLASS-DATA: osql_env TYPE REF TO if_osql_test_environment.
    CLASS-DATA: mast TYPE STANDARD TABLE OF mast,
                stko TYPE STANDARD TABLE OF stko,
                stpo TYPE STANDARD TABLE OF stpo,
                mara TYPE STANDARD TABLE OF mara,
                aenr TYPE STANDARD TABLE OF aenr.
    CLASS-METHODS:
      class_setup,
      class_teardown.
    METHODS:
      setup,
      teardown,
      test_finalize_delete       FOR TESTING,
      test_finalize_keep         FOR TESTING,
      test_enrich_defaults       FOR TESTING,
      test_enrich_keep_interface FOR TESTING,
      test_analyze_by_others       FOR TESTING,
      test_analyze_by_cp_offset  FOR TESTING,
      test_read_complete_data_dedup FOR TESTING,
      test_read_complete_data_prefetched FOR TESTING,
      test_map_items_no_cross_alternative FOR TESTING,
      test_send_message_missing_header FOR TESTING.
ENDCLASS.


CLASS zcl_m1t_dcn_bom_change_test IMPLEMENTATION.

  METHOD class_setup.
    " 类级 setup：仅在所有测试方法执行前运行一次。
    " 创建 OSQL 测试环境并注入 mock 数据，供全部测试方法共享。
    osql_env = cl_osql_test_environment=>create(
      i_dependency_list = VALUE #( ( 'MAST' ) ( 'STKO' ) ( 'STPO' ) ( 'STAS' ) ( 'MARA' ) ( 'AENR' ) ) ).

    CLEAR: mast, stko, stpo, mara, aenr.
    " MAT-0001 = 有效 ECN(ECN-0001)；MAT-0002 = 未释放 ECN(ECN-0002) 用于过滤测试
    mast = VALUE #(
      ( matnr = 'MAT-0001' stlan = '1' werks = 'Q511' stlal = '1' stlnr = '00000001' )
      ( matnr = 'MAT-0002' stlan = '1' werks = 'Q511' stlal = '1' stlnr = '00000002' ) ).
    stko = VALUE #(
      ( stlnr = '00000001' stlty = 'M' aennr = 'ECN-0001'
        andat = '20240101' datuv = '20240101' bmeng = '1' bmein = 'EA'
        stlst = '01' )
      ( stlnr = '00000002' stlty = 'M' aennr = 'ECN-0002'
        andat = '20240101' datuv = '20240101' bmeng = '1' bmein = 'EA'
        stlst = '01' ) ).
    stpo = VALUE #(
      ( stlnr = '00000001' stlty = 'M' idnrk = 'COMP-0001' posnr = '000010'
        menge = '2' meins = 'EA' datuv = '20240101' avoau = '5' ausch = '3'
        aennr = 'ECN-0001' ) ).
    mara = VALUE #(
      ( matnr = 'MAT-0001'  meins = 'EA' )
      ( matnr = 'COMP-0001' meins = 'PCS' ) ).
    aenr = VALUE #( ( aennr = 'ECN-0001' aenst = '2' ) ).

    " 注入 mock 表（create 后环境已启用，INSERT 写内存，一次即可）
    INSERT mast FROM TABLE mast.
    INSERT stko FROM TABLE stko.
    INSERT stpo FROM TABLE stpo.
    INSERT mara FROM TABLE mara.
    INSERT aenr FROM TABLE aenr.
  ENDMETHOD.

  METHOD class_teardown.
    " 类级 teardown：仅在所有测试方法执行完后运行一次。
    " 销毁 OSQL 测试环境（实例方法 destroy），释放 mock 表。
    IF osql_env IS BOUND.
      osql_env->destroy( ).
      CLEAR osql_env.
    ENDIF.
  ENDMETHOD.

  METHOD setup.
    " 方法级 setup：每个测试方法执行前运行，仅创建被测对象。
    cut_obj = NEW zcl_m1t_dcn_bom_change( ).
  ENDMETHOD.

  METHOD teardown.
    " 方法级 teardown：每个测试方法执行完后运行，清理被测对象。
    CLEAR cut_obj.
  ENDMETHOD.

  METHOD test_finalize_delete.
    DATA: del TYPE boole_d.
    cut_obj->finalize(
      EXPORTING it_erroneous_objects     = VALUE #( )
                it_relevant_objects      = VALUE #( )
                iv_repeated_initial_run  = abap_false
      IMPORTING ev_delete_change_pointer = del ).
    cl_abap_unit_assert=>assert_equals( exp = abap_true act = del ).
  ENDMETHOD.

  METHOD test_finalize_keep.
    DATA: del TYPE boole_d,
          err TYPE zcl_m1t_dcn_bom_change=>key_table_ty.
    err = VALUE #( ( stlan = '1' werks = 'Q511' matnr = 'MAT-0001'
                        stlal = '1' stlty = 'M' aennr = 'ECN-0001' ) ).
    cut_obj->finalize(
      EXPORTING it_erroneous_objects     = err
                it_relevant_objects      = VALUE #( )
                iv_repeated_initial_run  = abap_false
      IMPORTING ev_delete_change_pointer = del ).
    cl_abap_unit_assert=>assert_equals( exp = abap_false act = del ).
  ENDMETHOD.

  METHOD test_enrich_defaults.
    DATA: criteria TYPE rsds_trange,
          out      TYPE rsds_trange,
          stat     TYPE drf_s_stat_info.
    DATA: found_werks TYPE abap_bool VALUE abap_false,
          found_stlan TYPE abap_bool VALUE abap_false.
    cut_obj->enrich_filter_criteria(
      EXPORTING it_external_criteria     = criteria
      IMPORTING es_stat_info             = stat
                et_add_external_criteria = out ).
    " 空输入 → 输出 MAST 条件含 WERKS=Q511、STLAN=1（默认补齐）
    LOOP AT out INTO DATA(seltab) WHERE tablename = 'MAST'.
      LOOP AT seltab-frange_t INTO DATA(frange).
        IF frange-fieldname = 'WERKS'.
          LOOP AT frange-selopt_t INTO DATA(opt).
            IF opt-low = 'Q511'. found_werks = abap_true. ENDIF.
          ENDLOOP.
        ENDIF.
        IF frange-fieldname = 'STLAN'.
          LOOP AT frange-selopt_t INTO DATA(opt2).
            IF opt2-low = '1'. found_stlan = abap_true. ENDIF.
          ENDLOOP.
        ENDIF.
      ENDLOOP.
    ENDLOOP.
    cl_abap_unit_assert=>assert_equals( exp = abap_true act = found_werks ).
    cl_abap_unit_assert=>assert_equals( exp = abap_true act = found_stlan ).
  ENDMETHOD.

  METHOD test_enrich_keep_interface.
    DATA: criteria TYPE rsds_trange,
          out      TYPE rsds_trange,
          stat     TYPE drf_s_stat_info.
    DATA: seltab TYPE rsds_range,
          frange TYPE rsds_frange,
          opt    TYPE rsdsselopt.
    DATA: keep TYPE abap_bool VALUE abap_false.
    " 输入界面 WERKS='P001' → 应保留，不被默认 Q511 覆盖
    seltab-tablename = 'MAST'.
    frange-fieldname = 'WERKS'.
    opt-sign   = 'I'.
    opt-option = 'EQ'.
    opt-low    = 'P001'.
    APPEND opt TO frange-selopt_t.
    APPEND frange TO seltab-frange_t.
    APPEND seltab TO criteria.
    cut_obj->enrich_filter_criteria(
      EXPORTING it_external_criteria     = criteria
      IMPORTING es_stat_info             = stat
                et_add_external_criteria = out ).
    LOOP AT out INTO DATA(seltab2) WHERE tablename = 'MAST'.
      LOOP AT seltab2-frange_t INTO DATA(frange2) WHERE fieldname = 'WERKS'.
        LOOP AT frange2-selopt_t INTO DATA(opt2).
          IF opt2-low = 'P001'. keep = abap_true. ENDIF.
        ENDLOOP.
      ENDLOOP.
    ENDLOOP.
    cl_abap_unit_assert=>assert_equals( exp = abap_true act = keep ).
  ENDMETHOD.

  METHOD test_analyze_by_others.
    DATA: keys TYPE zcl_m1t_dcn_bom_change=>key_table_ty,
          stat TYPE drf_s_stat_info.
    cut_obj->analyze_changes_by_others(
      IMPORTING et_changed_objects = keys
                es_stat_info       = stat ).
    " MAST 有 MAT-0001（ECN-0001 released）与 MAT-0002（ECN-0002 未释放）
    " → 仅 MAT-0001 被选中（ECN 过滤生效）
    cl_abap_unit_assert=>assert_equals( exp = 1 act = lines( keys ) ).
    READ TABLE keys INTO DATA(key) INDEX 1.
    cl_abap_unit_assert=>assert_equals( exp = 'MAT-0001' act = key-matnr ).
  ENDMETHOD.

  METHOD test_analyze_by_cp_offset.
    DATA: cp     TYPE drf_s_bdcp,
          cp_tab TYPE drf_t_bdcp,
          keys TYPE zcl_m1t_dcn_bom_change=>key_table_ty,
          stat TYPE drf_s_stat_info.
    " MAST 变更指针：CDOBJID = MATNR(18)+WERKS(4)+STLAN(1)+STLAL(2)
    cp-tabname = 'MAST'.
    cp-cdobjid = |{ 'MAT-0001' WIDTH = 18 }{ 'Q511' }{ '1' }{ '1' WIDTH = 2 }|.
    APPEND cp TO cp_tab.
    cut_obj->analyze_changes_by_chg_pointer(
      EXPORTING it_change_pointer  = cp_tab
      IMPORTING et_changed_objects = keys
                es_stat_info       = stat ).
    " 偏移解析 → MAT-0001 命中
    cl_abap_unit_assert=>assert_equals( exp = 1 act = lines( keys ) ).
    READ TABLE keys INTO DATA(key) INDEX 1.
    cl_abap_unit_assert=>assert_equals( exp = 'MAT-0001' act = key-matnr ).
    cl_abap_unit_assert=>assert_equals( exp = 'Q511'     act = key-werks ).
    cl_abap_unit_assert=>assert_equals( exp = '1'        act = key-stlan ).
    cl_abap_unit_assert=>assert_equals( exp = '1'        act = key-stlal ).
  ENDMETHOD.

  METHOD test_read_complete_data_dedup.
    " 回归测试：同一 STLNR 关联多个 (matnr/stlan/stlal) 组合时，
    " STKO/STPO 不得因 INNER JOIN @mast 被放大（组件重复发送/数量翻倍）。
    " 本测试用独立 OSQL 环境（不干扰 class_setup 共享数据），
    " 且经 FRIENDS 访问 private stko/stpo 直接断言去重效果。
    DATA: lo_env TYPE REF TO if_osql_test_environment,
          keys TYPE zcl_m1t_dcn_bom_change=>key_table_ty,
          mast TYPE STANDARD TABLE OF mast,
          stko TYPE STANDARD TABLE OF stko,
          stpo TYPE STANDARD TABLE OF stpo,
          mara TYPE STANDARD TABLE OF mara,
          aenr TYPE STANDARD TABLE OF aenr.

    " 独立环境：MAST 两条不同 matnr/stlal 但同一 STLNR='00000001'
    lo_env = cl_osql_test_environment=>create(
      i_dependency_list = VALUE #( ( 'MAST' ) ( 'STKO' ) ( 'STPO' ) ( 'STAS' ) ( 'MARA' ) ( 'AENR' ) ) ).

    CLEAR: mast, stko, stpo, mara, aenr.
    mast = VALUE #(
      ( matnr = 'MAT-D1' stlan = '1' werks = 'Q511' stlal = '1' stlnr = '00000001' )
      ( matnr = 'MAT-D2' stlan = '1' werks = 'Q511' stlal = '2' stlnr = '00000001' ) ).
    stko = VALUE #(
      ( stlnr = '00000001' stlty = 'M' aennr = 'ECN-0001'
        andat = '20240101' datuv = '20240101' bmeng = '1' bmein = 'EA'
        stlst = '01' ) ).
    stpo = VALUE #(
      ( stlnr = '00000001' stlty = 'M' idnrk = 'COMP-0001' posnr = '000010'
        menge = '2' meins = 'EA' datuv = '20240101' avoau = '5' ausch = '3'
        aennr = 'ECN-0001' ) ).
    mara = VALUE #(
      ( matnr = 'MAT-D1' meins = 'EA' )
      ( matnr = 'COMP-0001' meins = 'PCS' ) ).
    aenr = VALUE #( ( aennr = 'ECN-0001' aenst = '2' ) ).

    INSERT mast FROM TABLE mast.
    INSERT stko FROM TABLE stko.
    INSERT stpo FROM TABLE stpo.
    INSERT mara FROM TABLE mara.
    INSERT aenr FROM TABLE aenr.

    " 两个对象键（同 STLNR、不同 matnr/stlal）→ mast 应 2 行
    keys = VALUE #(
      ( matnr = 'MAT-D1' stlan = '1' werks = 'Q511' stlal = '1' stlty = 'M' aennr = 'ECN-0001' )
      ( matnr = 'MAT-D2' stlan = '1' werks = 'Q511' stlal = '2' stlty = 'M' aennr = 'ECN-0001' ) ).

    cut_obj->read_complete_data( CHANGING ct_relevant_objects = keys ).

    " 断言：mast=2（两组合），但 STKO/STPO 去重后仅各 1 行（未放大）
    cl_abap_unit_assert=>assert_equals( exp = 2 act = lines( cut_obj->mast_list ) ).
    cl_abap_unit_assert=>assert_equals( exp = 1 act = lines( cut_obj->stko_list ) ).
    cl_abap_unit_assert=>assert_equals( exp = 1 act = lines( cut_obj->stpo_list ) ).

    lo_env->destroy( ).
    CLEAR lo_env.
  ENDMETHOD.

  METHOD test_read_complete_data_prefetched.
    " Path A（filter 预查 stlnr）回归测试：对象键已带 stlnr → biz 从对象键合成
    " mast_list（不查 MAST），并按 stlnr 装载 STKO/STPO。
    " 本测试用独立 OSQL 环境，且 MAST 故意不注入任何记录——
    " 若 biz 误走 Path B（回退查 MAST），mast_list 将为 0 行，断言即失败。
    DATA: lo_env TYPE REF TO if_osql_test_environment,
          keys TYPE zcl_m1t_dcn_bom_change=>key_table_ty,
          stko TYPE STANDARD TABLE OF stko,
          stpo TYPE STANDARD TABLE OF stpo,
          mara TYPE STANDARD TABLE OF mara,
          aenr TYPE STANDARD TABLE OF aenr.

    lo_env = cl_osql_test_environment=>create(
      i_dependency_list = VALUE #( ( 'MAST' ) ( 'STKO' ) ( 'STPO' ) ( 'STAS' ) ( 'MARA' ) ( 'AENR' ) ) ).

    CLEAR: stko, stpo, mara, aenr.
    " MAST 故意不注入：Path A 不查 MAST，应仍能合成 mast_list
    stko = VALUE #(
      ( stlnr = '00000001' stlty = 'M' aennr = 'ECN-0001'
        andat = '20240101' datuv = '20240101' bmeng = '1' bmein = 'EA'
        stlst = '01' ) ).
    stpo = VALUE #(
      ( stlnr = '00000001' stlty = 'M' idnrk = 'COMP-0001' posnr = '000010'
        menge = '2' meins = 'EA' datuv = '20240101' avoau = '5' ausch = '3'
        aennr = 'ECN-0001' ) ).
    mara = VALUE #(
      ( matnr = 'MAT-P1' meins = 'EA' )
      ( matnr = 'COMP-0001' meins = 'PCS' ) ).
    aenr = VALUE #( ( aennr = 'ECN-0001' aenst = '2' ) ).

    INSERT stko FROM TABLE stko.
    INSERT stpo FROM TABLE stpo.
    INSERT mara FROM TABLE mara.
    INSERT aenr FROM TABLE aenr.

    " 对象键带 stlnr（模拟 filter 预查输出，经框架同名映射入对象键）
    keys = VALUE #(
      ( matnr = 'MAT-P1' stlan = '1' werks = 'Q511' stlal = '1'
        stlty = 'M' aennr = 'ECN-0001' stlnr = '00000001' ) ).

    cut_obj->read_complete_data( CHANGING ct_relevant_objects = keys ).

    " Path A 断言：MAST 无记录仍合成 mast_list（来自对象键），且 stko/stpo 按 stlnr 装载
    cl_abap_unit_assert=>assert_equals( exp = 1 act = lines( cut_obj->mast_list ) ).
    READ TABLE cut_obj->mast_list INTO DATA(mast_line) INDEX 1.
    cl_abap_unit_assert=>assert_equals( exp = 'MAT-P1'   act = mast_line-matnr ).
    cl_abap_unit_assert=>assert_equals( exp = '00000001' act = mast_line-stlnr ).
    cl_abap_unit_assert=>assert_equals( exp = 1 act = lines( cut_obj->stko_list ) ).
    cl_abap_unit_assert=>assert_equals( exp = 1 act = lines( cut_obj->stpo_list ) ).

    lo_env->destroy( ).
    CLEAR lo_env.
  ENDMETHOD.

  METHOD test_map_items_no_cross_alternative.
    " STAS 收敛回归测试：同一 STLNR 下两个备选（STLAL=1/2），组件经 STAS 节点（STLKN）区分，
    " 映射仅取对象键所属备选的组件（COMP-A），不得混入另一备选（COMP-B）。
    " 本测试用独立 OSQL 环境（不干扰 class_setup 共享数据），且 MAST 故意不注入——
    " 走 Path A（对象键带 stlnr），验证 read_complete_data + map_data2message 全链路收敛。
    DATA: lo_env TYPE REF TO if_osql_test_environment,
          keys TYPE zcl_m1t_dcn_bom_change=>key_table_ty,
          key  TYPE zcl_m1t_dcn_bom_change=>bom_key_ty,
          key_ref TYPE REF TO data,
          mast TYPE STANDARD TABLE OF mast,
          stko TYPE STANDARD TABLE OF stko,
          stpo TYPE STANDARD TABLE OF stpo,
          stas TYPE STANDARD TABLE OF stas,
          mara TYPE STANDARD TABLE OF mara,
          aenr TYPE STANDARD TABLE OF aenr.

    lo_env = cl_osql_test_environment=>create(
      i_dependency_list = VALUE #( ( 'MAST' ) ( 'STKO' ) ( 'STPO' ) ( 'STAS' ) ( 'MARA' ) ( 'AENR' ) ) ).

    CLEAR: mast, stko, stpo, stas, mara, aenr.
    " MAST 故意不注入：Path A 从对象键合成 mast_list（不查 MAST）
    stko = VALUE #(
      ( stlnr = '00000001' stlty = 'M' aennr = 'ECN-0001'
        andat = '20240101' datuv = '20240101' bmeng = '1' bmein = 'EA'
        stlst = '01' ) ).
    " 两个备选：STLAL=1 → 节点 0001（COMP-A）；STLAL=2 → 节点 0002（COMP-B）
    stas = VALUE #(
      ( stlnr = '00000001' stlty = 'M' stlal = '1' stlkn = '0001' )
      ( stlnr = '00000001' stlty = 'M' stlal = '2' stlkn = '0002' ) ).
    stpo = VALUE #(
      ( stlnr = '00000001' stlty = 'M' stlkn = '0001' idnrk = 'COMP-A' posnr = '000010'
        menge = '2' meins = 'EA' datuv = '20240101' avoau = '5' ausch = '3' aennr = 'ECN-0001' )
      ( stlnr = '00000001' stlty = 'M' stlkn = '0002' idnrk = 'COMP-B' posnr = '000020'
        menge = '3' meins = 'EA' datuv = '20240101' avoau = '5' ausch = '3' aennr = 'ECN-0001' ) ).
    mara = VALUE #(
      ( matnr = 'MAT-P1' meins = 'EA' )
      ( matnr = 'COMP-A' meins = 'PCS' )
      ( matnr = 'COMP-B' meins = 'PCS' ) ).
    aenr = VALUE #( ( aennr = 'ECN-0001' aenst = '2' ) ).

    INSERT stko FROM TABLE stko.
    INSERT stpo FROM TABLE stpo.
    INSERT stas FROM TABLE stas.
    INSERT mara FROM TABLE mara.
    INSERT aenr FROM TABLE aenr.

    " 对象键 = 备选 1（MAT-P1, stlal=1），带 stlnr 走 Path A
    keys = VALUE #(
      ( matnr = 'MAT-P1' stlan = '1' werks = 'Q511' stlal = '1'
        stlty = 'M' aennr = 'ECN-0001' stlnr = '00000001' ) ).
    READ TABLE keys INTO key INDEX 1.
    GET REFERENCE OF key INTO key_ref.

    cut_obj->read_complete_data( CHANGING ct_relevant_objects = keys ).
    cut_obj->map_data2message( EXPORTING ir_relevant_object = key_ref ).

    " 仅备选 1 组件（COMP-A）被映射；备选 2 组件（COMP-B）不得混入
    cl_abap_unit_assert=>assert_equals( exp = 1 act = lines( cut_obj->bom_message-items ) ).
    READ TABLE cut_obj->bom_message-items INTO DATA(item) INDEX 1.
    cl_abap_unit_assert=>assert_equals( exp = 'COMP-A' act = item-cop_img_no ).

    lo_env->destroy( ).
    CLEAR lo_env.
  ENDMETHOD.

  METHOD test_send_message_missing_header.
    " send_message 早期分支（Header 必填校验，位于 /AIF 调用之前，无需 mock 函数模块）：
    " Header 为空但 Items 非空 → 对象标 SE + et_message 追加 1 条，且不触发 AIF 发送。
    " 注：若 Header 与 Items 均为空，send_message 提前 RETURN（不标错），
    "     故构造"Items 非空 + Header 空"以进入必填校验的错误分支。
    " 经 FRIENDS 直接设置 private bom_message 以构造该场景。
    DATA: file      TYPE drf_s_file_info,
          file_data TYPE drf_t_file_oi_content,
          msg       TYPE drf_t_message,
          sta       TYPE drf_t_obj_rep_sta_full,
          sta_line  LIKE LINE OF sta.

    " Items 非空（header 保持空）→ 通过提前返回检查，命中必填校验分支
    cut_obj->bom_message-items = VALUE #( ( cop_img_no = 'COMP-0001' quantity = '2' ) ).

    sta_line-bo_key = 'MAT-0001'.
    APPEND sta_line TO sta.

    cut_obj->send_message(
      EXPORTING is_file_info    = file
                iv_object_count = 1
      IMPORTING et_file_data    = file_data
                et_message      = msg
      CHANGING  ct_obj_rep_sta  = sta ).

    " 空 Header → 标 SE，不发送（et_message 1 条错误；et_file_data 始终为空）
    cl_abap_unit_assert=>assert_equals( exp = 'SE' act = sta[ 1 ]-repstatus ).
    cl_abap_unit_assert=>assert_equals( exp = 1   act = lines( msg ) ).
    cl_abap_unit_assert=>assert_equals( exp = 0   act = lines( file_data ) ).
  ENDMETHOD.
ENDCLASS.
