*----------------------------------------------------------------------*
*       CLASS CL_MDG_MAT_IDOC_DRF DEFINITION
*----------------------------------------------------------------------*
*
*----------------------------------------------------------------------*
class ZCL_DRF_REF_MM_OUT_GMES definition
  public
  create public .

  public section.

    interfaces if_drf_outbound .

    types:
      "interfaces IF_MDG_MAT_DRF_CONSTANTS .
      begin of ts_segment_transfer ,
        segtyp  type edidd-segnam,
        parseg  type edidd-segnam,
        send(1) type c,
      end of ts_segment_transfer .
    types:
      tt_segment_transfer type standard table of ts_segment_transfer .
    types:
      t_edidc type standard table of edidc .
    types:
      "TT_KEY_TABLE type sorted table of MDG_BS_MAT_DRF_S_MATNR_KEY  with unique key MATNR .
      tt_key_table type sorted table of Zp_mia_mm_mes_drf_flt_s with unique key matnr .

    methods constructor .
    class-methods get_mapping_data
      importing
        !iv_fieldname type Zp_mia_drf_out_fname
        !iv_bus_sys   type mdg_business_system optional
        !iv_plant     type werks_d optional
        !iv_mtart     type mtart optional
        !iv_mstae     type mstae optional
        !iv_uom       type meins optional
        !iv_tbtxt     type tbtxt optional
        !iv_rbtxt     type rbtxt optional
      exporting
        !ev_esb_plant type werks_d
        !ev_esb_mtart type mtart
        !ev_esb_mstae type mstae
        !ev_esb_uom   type meins
        !ev_bus_sys   type mdg_business_system
        !ev_esb_tbtxt type tbtxt .
  protected section.
*"* protected components of class ZCL_DRF_REF_MM_OUT_GMES
*"* do not include other source files here!!!
  private section.

    types:
      begin of t_mat3060,
        matnr               type  bapibatchkey-material,
        plant               type  bapibatchkey-plant,
        classallocations    type  bapi3060_allocations,
        classvaluationschar type  bapi3060_valuations_char,
        classvaluationscurr type  bapi3060_valuations_curr,
        classvaluationsnum  type  bapi3060_valuations_num,
      end of t_mat3060 .
    types:
      tt_mat3060 type table of t_mat3060 with key matnr .
    types:
      begin of t_mdg_bus_sys_tech_logsys,
        business_system	type mdg_business_system,
        bus_sys_id      type mdg_business_system_id,
        logsys          type logsys,
      end of t_mdg_bus_sys_tech_logsys .
    types:
      tt_mdg_bus_sys_tech type sorted table of t_mdg_bus_sys_tech_logsys with unique key business_system .

    data mv_logsys_default type logsys .
    constants c_logsys_default_parameter_id type Zs_efr_filter_value value 'LOGSYS_DEFAULT' ##NO_TEXT.
    constants c_application_id type Zs_efr_app_id value 'ZP_MES' ##NO_TEXT.
    "  constants C_CLASNUM_02 type KLASSE_D value 'MM_PROD_GENERAL' ##NO_TEXT.
    "data CLASSCHARACTERISTICS type TT_BAPI1003_CHARACT_R .
    "  constants C_CLASNUM_01 type KLASSE_D value 'MM_MES' ##NO_TEXT.
    data mt_bapicharactvaldescr_mes_dis type tt_bapicharactvaluesdescr .
    data mt_mdg_bus_sys_tech_logsys type tt_mdg_bus_sys_tech .
    class-data gv_sendconfig type mgale-sendall .
    data mo_id_matching_api type ref to if_mdg_id_matching_api_bs .
    data mv_own_system_id type mdg_business_system .
    data mt_bus_sys_tech type mdg_t_bus_sys_tech .
    data mt_mat_segment_data type mdg_bs_mat_drf_s_key_data .
    class-data gv_repl_mode type drf_dlmod .
    data ms_runtime_param type drf_s_runtime_parameter_ext .
    data mv_count_call type c value '0' ##NO_TEXT.
    "  data MV_SEGMENT_IND type BOOLE_D value ' ' ##NO_TEXT.
    data mt_class_data type mdg_bs_mat_drf_t_clf_key_data .
    "class-data GR_DRF_MAT type ref to CL_MDG_MAT_IDOC_DRF .  "
    class-data gr_drf_mat type ref to ZCL_DRF_REF_MM_OUT_GMES .
    data mt_inob_map type mdg_bs_clf_t_objnum_map .
    data mt_change_pointer type mdg_cp_t_cp .
    data gt_mat3060 type tt_mat3060 .
    data gt_matmas_ehsphr_t type Zp_mia_mes_matmas_ehsphr_t .
    data ex_object_cx_root type ref to cx_root .
    data ex_text type string .
    data ex_text_long type string .
    data rc type sysubrc .
    data mt_charactreristics type tt_bapi1003_charact_r .
    constants gc_mat_key_tab type string value 'MDG_BS_MAT_DRF_T_MATNR_KEY' ##NO_TEXT.
    constants gc_mbew_segment type tbnam value 'MDG_BS_MAT_S_MBEW' ##NO_TEXT.
    constants gc_marc_segment type tbnam value 'MDG_BS_MAT_S_MARC' ##NO_TEXT.
    constants gc_mara_segment type tbnam value 'MDG_BS_MAT_S_MARA' ##NO_TEXT.
    constants gc_marm_segment type tbnam value 'MDG_BS_MAT_S_MARM' ##NO_TEXT.
    constants gc_mard_segment type tbnam value 'MDG_BS_MAT_S_MARD' ##NO_TEXT.
    constants gc_makt_segment type tbnam value 'MDG_BS_MAT_S_MAKT' ##NO_TEXT.
    constants gc_mean_segment type tbnam value 'MDG_BS_MAT_S_MEAN' ##NO_TEXT.
    constants gc_rcvprt type char2 value 'LS' ##NO_TEXT.
    constants gc_outb_impl type drf_outb_impl value 'YMES_MM' ##NO_TEXT.
    constants c_logsys_default type logsys value 'MULESOFT' ##NO_TEXT.
    constants c_cust_bc_mes_dist type atnam value 'MM_MES_DIST' ##NO_TEXT.

    methods read_text_keys
      importing
        !it_matnr_range type range_t_matnr
        !it_marc        type mdg_bs_mat_t_marc
        !it_mvke        type mdg_bs_mat_t_mvke .
    methods check_id_mapping
      importing
        !iv_matnr     type kssk-objek
        !iv_target_bs type mdg_business_system
      exporting
        !ev_error     type abap_bool .
    methods update_replication_data
      importing
        !iv_object_id   type drf_object_id optional
        !it_idoc_result type t_edidc
        !iv_messagetype type edi_doctyp
      changing
        !ct_obj_rep_sta type drf_t_obj_rep_sta_full optional .
    methods send_yp1t_mes_matmas_idoc
      importing
        !is_material_data type mdg_bs_mat_drf_s_key_data
        !is_bus_sys_tech  type mdg_s_bus_sys_tech
      changing
        !ct_idoc_cntrl    type t_edidc
        !ct_obj_rep_sta   type drf_t_obj_rep_sta_full .
    methods map_mat_segment_data
      importing
        !is_mat_data type mdg_bs_mat_s_mat_data .
    methods check_aennr
      importing
        !iv_aennr      type aennr
      changing
        !cv_valid_from type datuv .
    methods handle_mat_data
      importing
        !iv_packet_size type i
      exporting
        !et_class_data  type mdg_bs_mat_drf_t_clf_key_data
      changing
        !cs_mat_data    type mdg_bs_mat_drf_s_key_data .
    methods call_filter
      importing
        !iv_filter_obj        type drf_filter_object
        !it_external_criteria type rsds_trange
        !iv_ignore_filter     type abap_bool
      changing
        !it_unfilt            type any table
        !et_filt              type any table .
    methods read_mat_data_pack
      importing
        !it_relevant_objects type sorted table
      raising
        cx_drf_process_messages .
    methods send_yp1t_mat_segments
      importing
        !is_material_data type mdg_bs_mat_drf_s_key_data
        !is_marakey       type bdimarakey
        !is_idoc_control  type edidc
        !iv_mesgtype      type edmsg-msgtyp
        !is_bus_sys_tech  type mdg_s_bus_sys_tech
      exporting
        !et_idoc          type t_edidc
        !ev_created_idocs type sy-tabix .
    methods business_sys_to_logsys
      importing
        value(iv_business_system) type mdg_business_system optional
      returning
        value(rv_logsys)          type logsys .
    methods business_sys_to_cust_bc_mes_dist
      importing
        value(iv_business_system) type mdg_business_system optional
      returning
        value(rv_cust_bc_mes_dist)    type Zp_mia_ymm_mes_dist .
    methods diag
      exporting
        value(e_ex_text_long) type string
        value(e_ex_text)      type string
        value(e_rc)           type sysubrc .
ENDCLASS.



CLASS ZCL_DRF_REF_MM_OUT_GMES IMPLEMENTATION.


  method business_sys_to_logsys.

    if mt_mdg_bus_sys_tech_logsys[] is initial.
      " SELECT business_system ,  logsys  FROM mdg_bus_sys_tech
      select business_system ,  logsys  from Zp_mcn_mdg_bus_sys_tech
      where disabled is initial
      into corresponding fields of table @mt_mdg_bus_sys_tech_logsys
      .
      if sy-subrc ne 0.
        message id sy-msgid type sy-msgty number sy-msgno
        with sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4.
      endif.
    endif.


    try.
        rv_logsys = mt_mdg_bus_sys_tech_logsys[ business_system = iv_business_system ]-logsys.

      catch cx_sy_itab_line_not_found.
        message id sy-msgid type sy-msgty number sy-msgno
        with sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4.
    endtry.

    if   rv_logsys is initial.
      rv_logsys = mv_logsys_default.  " ZCL_S_EFR=>GET_PARAMETER_VALUE( exporting  I_PARAMETER_ID = C_LOGSYS_DEFAULT_PARAMETER_ID .

    if   rv_logsys is initial.
      rv_logsys = c_logsys_default.
    endif.

  endmethod.


  method business_sys_to_cust_bc_mes_dist.


    rv_cust_bc_mes_dist = iv_business_system.

    data return_t type bapiret2_tab.

    if  mt_bapicharactvaldescr_mes_dis is initial.
      call function 'BAPI_CHARACT_GETDETAIL'
        exporting
          charactname        = c_cust_bc_mes_dist
          keydate            = sy-datum
          language           = 'E'
        tables
          charactvaluesdescr = mt_bapicharactvaldescr_mes_dis
          return             = return_t.
    endif.

    read table mt_bapicharactvaldescr_mes_dis with key value_char = iv_business_system(30) into data(charactvalues_s).
    if sy-subrc eq 0.
      rv_cust_bc_mes_dist = charactvalues_s-value_char.
    else.
      read table mt_bapicharactvaldescr_mes_dis with key description = iv_business_system  into charactvalues_s.
      if sy-subrc eq 0.
        rv_cust_bc_mes_dist = charactvalues_s-value_char.
      else.
        "to do ignore
        rv_cust_bc_mes_dist = iv_business_system.
      endif.
    endif.

  endmethod.


  method call_filter.
*------------------------------------------------------------------------------------------------*
* Functional Spec: Master MES GNE interface
* Technical Spec: Master MES GNE interface
* Process: Maintain product master data
* History ---------------------------------------------------------------------------------------*
* Date       | Change           | Contributor               | Description
*------------------------------------------------------------------------------------------------*
*------------------------------------------------------------------------------------------------*




    data use_object_ref_v     type abap_bool.

    data lo_node_inst_fobj     type ref to cl_drf_filter_object.
    try.
        cl_mdg_drf_node_inst_fobj=>apply_filter_all_in_one(
        exporting
          iv_appl               = ms_runtime_param-appl
          iv_business_system    = ms_runtime_param-business_system
          iv_filter_object      = iv_filter_obj
          iv_outb_impl          = ms_runtime_param-outb_impl
          io_bal                = ms_runtime_param-bal
          iv_dlmod              = ms_runtime_param-dlmod
          iv_runmod             = ms_runtime_param-runmod
          iv_fobj               = iv_filter_obj
          iv_use_object_ref     = use_object_ref_v
          it_external_criteria  = it_external_criteria
          iv_ignore_filter      = iv_ignore_filter
        changing
          it_unfiltered_objects = it_unfilt
          co_filter_object      = lo_node_inst_fobj
          et_filtered_objects   = et_filt
          ).
**      catch CX_DRF_FILTER_OBJECT .
**        ##NO_HANDLER
**      catch CX_DRF_EXCEPTION .
**        ##NO_HANDLER
      catch cx_root into data(ex_object_cx_root).
        data(ex_text) = ex_object_cx_root->get_text( ) ##needed.
        data(ex_text_long) = ex_object_cx_root->get_longtext( ) ##needed.


    endtry.
  endmethod.                  "call_filter


  method check_aennr.

    data:
      ecn_effectivity_v type csdata-xfeld,    "ECM with parameters
      xccin             type ccin.                      "structure for change mgtm.

* check type of change number
    call function 'CCCN_ECN_WITH_EFFECTIVITY'
      exporting
        eaennr          = iv_aennr
      importing
        flg_effectivity = ecn_effectivity_v
      exceptions
        no_record_found = 1.

    data(rc) = sy-subrc ##needed.
    if ecn_effectivity_v is initial.

*   Get date of change number
      xccin-aennr = iv_aennr.
      xccin-aeobj = '5'.
      xccin-aeclt = '3'.

      call function 'CC_CHANGE_NUMBER_CHECK'
        exporting
          eccin                     = xccin
        importing
          adatuv                    = cv_valid_from
        exceptions
          error_aenr                = 1
          error_class               = 2
          error_create              = 3
          error_date_restriction    = 4
          error_generate            = 5
          error_no_omr_for_material = 6
          error_index               = 7
          error_input               = 8
          error_obj_lock            = 9
          error_tcc01               = 10
          error_status              = 11
          error_lock                = 12
          error_authority           = 13
          error_released            = 14
          marked_for_deletion       = 15
          error_leader              = 16
          error_baseline            = 17
          others                    = 18.
      rc = sy-subrc.
    else.

*   Init ECM processor
      call function 'CLEF_ECM_PROCESSOR_INIT'
        exporting
          key_date            = cv_valid_from
          i_aennr             = iv_aennr
          i_maintain_flag     = 'X'
        exceptions
          ecm_init_error      = 1
          exit_from_dynpro    = 2
          no_maintenance_data = 3
          others              = 4.
      if not sy-subrc is initial.
        message id sy-msgid type sy-msgty number sy-msgno
        with sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4.
      endif.
    endif.





  endmethod.                    "check_aennr


  method check_id_mapping.

    data:
      matching_s       type mdg_s_get_matching_easy_bs,
      matching_t       type mdg_t_get_matching_easy_bs,
      error_occurred_v type abap_bool ##needed,
      object_key_s     type mdg_s_object_key_bs,
      object_key_t     type mdg_t_object_key_bs,
      bs_attr_t        type mgd_t_bus_sys_attr.

    call method cl_mdg_bs_access_cust_data=>select_bs_data
      exporting
        iv_business_system = iv_target_bs
      importing
        et_bs_attr         = bs_attr_t.

    read table bs_attr_t transporting no fields with key business_system = iv_target_bs
    business_object = if_mdg_otc_const=>material
    comm_channel = '2' "IDoc
    obj_correlation = '2' " Key Mapping
    upd_km = abap_true.

    check sy-subrc = 0.

    if  mo_id_matching_api is not bound.
      try.
          call method cl_mdg_id_matching_api_bs=>get_instance
            exporting
              iv_direct_db_insert       = abap_false
              iv_set_lcl_system_by_api  = abap_true
            importing
              er_if_mdg_id_matching_api = mo_id_matching_api
              ev_lcl_business_system    = mv_own_system_id.
        catch cx_mdg_id_matching_bs .
          error_occurred_v = abap_true.
        catch cx_mdg_no_api_instance .
          error_occurred_v = abap_true.
        catch cx_mdg_lcl_bus_sys_not_found .
          error_occurred_v = abap_true.
      endtry.
    endif.

    object_key_s-object_type_code = if_mdg_otc_const=>material.
    object_key_s-identifier_key-id_value = iv_matnr.
    object_key_s-identifier_key-ident_defining_scheme_code = if_mdg_idsc_const=>material_id.
    object_key_s-identifier_key-business_system_id = iv_target_bs.

    append object_key_s to object_key_t.
    try.
        call method mo_id_matching_api->get_matching
          exporting
            it_search_key       = object_key_t    " Multiple Object Keys inlcuding Object Type Code
            iv_target_system    = mv_own_system_id    " Key Name of Business System
          importing
            et_matching_objects = matching_t.    " Identifier Set data of multiple pairs of mapped objects
      catch cx_mdg_missing_input_parameter.    " Missing Input parameter in a method
        error_occurred_v = abap_true.
      catch cx_mdg_missing_id_data.    " One or more ID data are missing
        error_occurred_v = abap_true.
      catch cx_mdg_otc_idm_error.    " Key Mapping related OTC Error
        error_occurred_v = abap_true.
      catch cx_mdg_id_matching_bs.    " General Key Mapping Messages
        error_occurred_v = abap_true.
      catch cx_mdg_idsc_invalid.    " Key Mapping related OITC code error
        error_occurred_v = abap_true.
      catch cx_mdg_no_ctrl_reg_defined.    " For OTC no central registry defined in KM
        error_occurred_v = abap_true.
      catch cx_mdg_km_invalid_id_value.    " Invalid ID value
        error_occurred_v = abap_true.
    endtry.

    read table matching_t into matching_s with key search_key-object_type_code = object_key_s-object_type_code
    search_key-identifier_key-ident_defining_scheme_code = object_key_s-identifier_key-ident_defining_scheme_code
    search_key-identifier_key-id_value = object_key_s-identifier_key-id_value
    search_key-identifier_key-business_system_id = iv_target_bs.

    if sy-subrc is not initial or matching_s-no_matching_objects_found = abap_true.
      ev_error = abap_true.
    endif.

  endmethod.


  method constructor.
*------------------------------------------------------------------------------------------------*
* Functional Spec: Master MES GNE interface
* Technical Spec: Master MES GNE interface
* Process: Maintain product master data
* History ---------------------------------------------------------------------------------------*
* Date       | Change           | Contributor               | Description
*------------------------------------------------------------------------------------------------*
*------------------------------------------------------------------------------------------------*

    data classcharacteristics type tt_bapi1003_charact_r .


    "SELECT class FROM klah
    select classnumber as class from Zs_b_klah
      where classtype = '001'
      and classnumber like 'Y%'   "
      into table @data(class_t).
    rc = sy-subrc.
    loop at class_t assigning field-symbol(<class>).

      try.
          call function 'BAPI_CLASS_GETDETAIL'
            exporting
              classtype            = '001'
              classnum             = <class>-class "'cust_bm_INTRAMATERIALS'
            tables
              classcharacteristics = classcharacteristics.

          append lines of classcharacteristics to mt_charactreristics.

        catch cx_root into ex_object_cx_root.
          ex_text = ex_object_cx_root->get_text( ).
          ex_text_long = ex_object_cx_root->get_longtext( ).
      endtry.

    endloop.

    sort  mt_charactreristics by name_char department_view. "# no pragma EC CI_SORTSEQ
    delete adjacent duplicates from  mt_charactreristics comparing name_char department_view.


    try.
        data(application_object) = Zcl_s_efr=>factory( i_application_id = c_application_id ).
        data: l_result_value type Zs_efr_parameter_value.
        application_object->get_parameter_value( exporting
          i_parameter_id = c_logsys_default_parameter_id
        changing
          c_parameter_value = l_result_value ).

        mv_logsys_default = l_result_value.
      catch Zcx_s_efr into data(exception_ref).
        message exception_ref type 'I' display like exception_ref->message_type.
        return.
    endtry.

  endmethod.


  method diag.
    e_ex_text_long = ex_text_long.
    e_ex_text = ex_text.
    e_rc = rc.
  endmethod.


  method get_mapping_data.
*------------------------------------------------------------------------------------------------*
* Functional Spec: Master MES GNE interface
* Technical Spec: Master MES GNE interface
* Process: Maintain product master data
* History ---------------------------------------------------------------------------------------*
* Date       | Change           | Contributor               | Description
*------------------------------------------------------------------------------------------------*
*------------------------------------------------------------------------------------------------*
    data: app_obj type ref to Zcl_s_efr.
    "CLEAR rt_parameters.
    clear:ev_esb_plant,ev_esb_mtart,ev_esb_mstae,ev_esb_uom,ev_bus_sys.


    try.
        if    app_obj is not bound.
          Zcl_s_efr=>factory(
            exporting
              i_application_id  =    'ZP_MIA_GNEMES'              " Application Id
            receiving
              r_application     =  app_obj                 ).             " Customer Enhancement Framework

        endif.
        check app_obj is bound.
        case iv_fieldname.

          when 'WERKS'.
            select single esbwerks,legacybusinesssystem
             from Zs_b_mia_gmesm
             where businesssystem = @iv_bus_sys
             and   werks          = @iv_plant
             into ( @ev_esb_plant, @ev_bus_sys ).
            if sy-subrc <> 0.
              clear :ev_esb_plant, ev_bus_sys.
            endif.


          when 'MSTAE'.
            app_obj->get_parameter_values(
              exporting
                i_parameter_id     =     'MSTAE_MAP'           " Parameter Identifierw
              receiving
                r_parameter_values =     data(parameters_tab)  ).          " Parameter Values

            data(param_value) = value #( parameters_tab[ filter = iv_mstae ]-parameter_value optional ). "#EC CI_SORTSEQ
            if param_value is not initial.
              translate param_value to upper case.
              split param_value at '/' into data(mes_rel) ev_esb_mstae.
              if mes_rel <> 'YES'.
                clear ev_esb_mstae.
              endif.
              clear mes_rel.
            endif.

          when 'MTART'.
            app_obj->get_parameter_values(
            exporting
              i_parameter_id     =     'MTART_MAP'           " Parameter Identifierw
              receiving
              r_parameter_values =     parameters_tab  ).          " Parameter Values

            param_value = value #( parameters_tab[ filter = iv_mtart ]-parameter_value optional ).  "#EC CI_SORTSEQ
            if param_value is not initial.
              translate param_value to upper case.
              split param_value at '/' into mes_rel ev_esb_mtart.
              if mes_rel <> 'YES'.
                clear ev_esb_mtart.
              endif.
              clear mes_rel.
            endif.


          when 'MEINS'.

            app_obj->get_parameter_values(
            exporting
              i_parameter_id     =     'UOM_MAP'           " Parameter Identifierw
              receiving
              r_parameter_values =     parameters_tab  ).          " Parameter Values

            ev_esb_uom = value #( parameters_tab[ filter = iv_uom ]-parameter_value optional ). "#EC CI_SORTSEQ

          when 'SYSTEM'.
            select single legacybusinesssystem
                         from Zs_b_mia_gmesm
                         where businesssystem = @iv_bus_sys
                         "AND   werks          = @iv_plant
                         into @ev_bus_sys.
            if sy-subrc <> 0.
              clear  ev_bus_sys.
            endif.
          when 'TBTXT'.
            app_obj->get_parameter_values(
            exporting
              i_parameter_id     =     'TBTXT_RBTXT_MAP'           " Parameter Identifierw
              receiving
              r_parameter_values =     parameters_tab  ).          " Parameter Values

            data(temp_store_cond) = |{ iv_tbtxt }/{ iv_rbtxt }|.
            condense temp_store_cond.

            ev_esb_tbtxt = value #( parameters_tab[ filter = temp_store_cond ]-parameter_value optional ).  "#EC CI_SORTSEQ
          when others.
            clear:ev_esb_plant,ev_esb_mtart,ev_esb_mstae,ev_esb_uom,ev_bus_sys.
        endcase.

      catch Zcx_s_efr. " Exceptions - Customer Enhancement Framework
        clear parameters_tab.
    endtry.
  endmethod.


  method handle_mat_data.

    data:object_count_v type i,
         objek_v        type cuobn,
         matnr_v        type matnr.

    data:matnr_s    type rsdsselopt,
         marakey_s  type bdimarakey,
         inob_map_s type mdg_bs_clf_s_objnum_map,
         stxhkey_s  type bdistxhkey.

    data:matnr_t      type rsdsselopt_t,
         class_data_t type mdg_bs_mat_drf_t_clf_key_data,
         inob_map_t   type mdg_bs_clf_t_objnum_map.

    object_count_v = iv_packet_size + 1.

* Delete the records which are more then the packet size and replicate which comes under the packet size
    delete cs_mat_data-t_marakey from object_count_v.

    loop at cs_mat_data-t_marakey into marakey_s.
      matnr_s-low = marakey_s-matnr.
      matnr_s-option = 'EQ'.
      matnr_s-sign = 'I'.
      append matnr_s to matnr_t.
    endloop.

* Operate on class data of the corresponding materials
    if mt_class_data is not initial.
      inob_map_t = mt_inob_map.
      class_data_t    = mt_class_data.
      delete class_data_t where objek not in matnr_t.
      delete mt_class_data where objek in matnr_t.
      if inob_map_t is not initial. " check whether class type is valid for multiple objects


        " for ATC only
         "
        delete inob_map_t where objek not in matnr_t.   "#EC CI_SORTSEQ

        loop at inob_map_t into inob_map_s.
          "move INOB_MAP_S-CUOBJ to OBJEK_V.
          objek_v =  inob_map_s-cuobj.

          "LOOP AT mt_class_data INTO class_data_s WHERE objek EQ objek_v
          loop at mt_class_data assigning field-symbol(<class_data_s>) where objek eq objek_v
          or objek eq inob_map_s-objek.
            insert <class_data_s> into table class_data_t.
            delete mt_class_data where objek = <class_data_s>-objek." delete the entry for current object
          endloop.
          delete table mt_inob_map from inob_map_s. " delete the netry for current object
        endloop.
      endif.
    endif.

    " delete duplicated entries for the same class type.
    data: class_prev_s like line of mt_class_data.
    sort class_data_t by objek obtab klart clint.
*    LOOP AT class_data_t INTO class_data_s.
    loop at class_data_t assigning <class_data_s>.
      if <class_data_s>-klart <> class_prev_s-klart or
      <class_data_s>-objek <> class_prev_s-objek or
      <class_data_s>-obtab <> class_prev_s-obtab or
      <class_data_s>-aennr <> class_prev_s-aennr or
      <class_data_s>-datuv <> class_prev_s-datuv.
        class_prev_s = <class_data_s>.
      else.
        delete class_data_t index sy-tabix.
      endif.
    endloop.

    delete cs_mat_data-t_maktkey where matnr not in matnr_t.
    delete cs_mat_data-t_marckey where matnr not in matnr_t. "# not-pragma EC CI_SORTSEQ
    delete cs_mat_data-t_mardkey where matnr not in matnr_t.
    delete cs_mat_data-t_mpgdkey where matnr not in matnr_t.
    delete cs_mat_data-t_mpopkey where matnr not in matnr_t.
    delete cs_mat_data-t_marmkey where matnr not in matnr_t.
    delete cs_mat_data-t_meankey where matnr not in matnr_t.
    delete cs_mat_data-t_mbewkey where matnr not in matnr_t.
    delete cs_mat_data-t_mlgnkey where matnr not in matnr_t.
    delete cs_mat_data-t_mlgtkey where matnr not in matnr_t.
    delete cs_mat_data-t_mvkekey where matnr not in matnr_t.
    delete cs_mat_data-t_mlankey where matnr not in matnr_t.

    loop at cs_mat_data-t_stxhkey into stxhkey_s.
      if stxhkey_s-tdobject = 'MVKE' or stxhkey_s-tdobject = 'MDTXT'.
        matnr_v = stxhkey_s-tdname+0(18).
        read table matnr_t with key low = matnr_v transporting no fields.
        if sy-subrc ne 0.
          delete cs_mat_data-t_stxhkey where tdname eq matnr_v..
        endif.
      else.
        delete cs_mat_data-t_stxhkey where tdname not in matnr_t and tdobject ne 'MVKE' and tdobject ne 'MDTXT'.
      endif.
    endloop.

    delete cs_mat_data-t_mprwkey where matnr not in matnr_t.
    delete cs_mat_data-t_mvegkey where matnr not in matnr_t.
    delete cs_mat_data-t_mveukey where matnr not in matnr_t.
    delete cs_mat_data-t_mkalkey where matnr not in matnr_t.

* Delete the entries which will be replicated and keep the rest
    delete mt_mat_segment_data-t_marakey to iv_packet_size.
    delete mt_mat_segment_data-t_maktkey where matnr in matnr_t.
    delete mt_mat_segment_data-t_marckey where matnr in matnr_t. "# not-pragma EC CI_SORTSEQ
    delete mt_mat_segment_data-t_mardkey where matnr in matnr_t.
    delete mt_mat_segment_data-t_mpgdkey where matnr in matnr_t.
    delete mt_mat_segment_data-t_mpopkey where matnr in matnr_t.
    delete mt_mat_segment_data-t_marmkey where matnr in matnr_t.
    delete mt_mat_segment_data-t_meankey where matnr in matnr_t.
    delete mt_mat_segment_data-t_mbewkey where matnr in matnr_t.
    delete mt_mat_segment_data-t_mlgnkey where matnr in matnr_t.
    delete mt_mat_segment_data-t_mlgtkey where matnr in matnr_t.
    delete mt_mat_segment_data-t_mvkekey where matnr in matnr_t.
    delete mt_mat_segment_data-t_mlankey where matnr in matnr_t.
    delete mt_mat_segment_data-t_stxhkey where tdobject in matnr_t.
    delete mt_mat_segment_data-t_mprwkey where matnr in matnr_t.
    delete mt_mat_segment_data-t_mvegkey where matnr in matnr_t.
    delete mt_mat_segment_data-t_mveukey where matnr in matnr_t.
    delete mt_mat_segment_data-t_mkalkey where matnr in matnr_t.

    et_class_data = class_data_t.
  endmethod.                    "handle_mat_data


  METHOD if_drf_outbound~analyze_changes_by_chg_pointer.
*------------------------------------------------------------------------------------------------*
* Functional Spec: Master MES GNE interface
* Technical Spec: Master MES GNE interface
* Process: Maintain product master data
* History ---------------------------------------------------------------------------------------*
* Date       | Change           | Contributor               | Description
*------------------------------------------------------------------------------------------------*
*------------------------------------------------------------------------------------------------*




    DATA change_pointer_t TYPE  bdcp_tab.
    DATA change_pointer_s TYPE bdcp.
    "DATA temp_cust_bc_mes_dist TYPE Zp_mcn_cust_bc_mes_dist.  "
    DATA temp_cust_bc_mes_dist TYPE  Zp_mia_ymm_mes_dist.  "
    DATA(business_system)  =  gr_drf_mat->ms_runtime_param-business_system.
    DATA objs_t TYPE TABLE OF mdg_bs_mat_drf_s_matnr_key.
    DATA key_s  TYPE mdg_bs_mat_drf_s_matnr_key.

    DATA l_objek TYPE cuobn.
    "data T_OBJEK_ABAUSP type MDG_BS_CLF_T_OBJNUM.
    DATA t_cuobj  TYPE TABLE OF  cuobj. "COMT_VBX_OBJ_NO_BTT.
    DATA l_cuobj TYPE cuobj.

    DATA l_atinn TYPE atinn.
    DATA l_atnam TYPE atnam.


    temp_cust_bc_mes_dist = business_sys_to_cust_bc_mes_dist( business_system ).

    LOOP AT it_change_pointer ASSIGNING FIELD-SYMBOL(<cp>).
      MOVE-CORRESPONDING <cp> TO change_pointer_s.
      APPEND change_pointer_s TO change_pointer_t.
    ENDLOOP.

    LOOP AT change_pointer_t ASSIGNING FIELD-SYMBOL(<lc_bdcp>).
      IF <lc_bdcp>-tabname = 'ABAUSP'. "Characteristics change
        l_cuobj = <lc_bdcp>-tabkey(18).
        APPEND  l_cuobj TO  t_cuobj.
      ENDIF.
    ENDLOOP.

    IF  t_cuobj[] IS NOT INITIAL.
      "SELECT cuobj , objek FROM inob INTO TABLE @DATA(t_objek_abausp) "@data(T_OBJEK_ABAUSP)
      SELECT clfnobjectinternalid AS cuobj , clfnobjectid AS objek FROM Zs_b_inob INTO TABLE @DATA(t_objek_abausp) "@data(T_OBJEK_ABAUSP)
            FOR ALL ENTRIES IN @t_cuobj
            WHERE clfnobjectinternalid = @t_cuobj-table_line.
      IF sy-subrc <> 0.
        MESSAGE ID sy-msgid TYPE sy-msgty NUMBER sy-msgno
        WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4 INTO ex_text.
      ENDIF.
    ENDIF.


    LOOP AT change_pointer_t ASSIGNING <lc_bdcp>.
      "loop at CHANGE_POINTER_T assigning field-symbol(<LC_BDCP>).
      CASE <lc_bdcp>-tabname.
        WHEN 'MARA'
          OR 'MARC'.  "MARC -matnr = <lc_bdcp>-tabkey+3(40).
          APPEND key_s TO objs_t.

        WHEN 'DMAKT'.
          IF <lc_bdcp>-cdobjcl = 'MATERIAL'.
            key_s-matnr =  <lc_bdcp>-cdobjid(40).

            APPEND key_s TO objs_t.
          ENDIF.
          " {
        WHEN 'DMARM'.
          IF <lc_bdcp>-cdobjcl = 'MATERIAL'.
            key_s-matnr =  <lc_bdcp>-cdobjid(40).

            APPEND key_s TO objs_t.
          ENDIF.
          "} 

        WHEN 'HSMT_DT'
          OR 'HSMT_DN'.
          IF <lc_bdcp>-cdobjcl = 'HSM_MASTER'.
            key_s-matnr =  <lc_bdcp>-cdobjid(18).
            APPEND key_s TO objs_t.
          ENDIF.
          .

        WHEN 'ABAUSP'. "Characteristics change
          l_cuobj = <lc_bdcp>-tabkey(18).

          READ TABLE  t_objek_abausp INTO DATA(objek_abausp_s) WITH KEY cuobj = l_cuobj.
          "select single OBJEK from INOB into L_OBJEK where CUOBJ = L_CUOBJ.   "ATC exception raised

          IF sy-subrc EQ 0.
            l_objek =  objek_abausp_s-objek.
            key_s-matnr = l_objek(39).
            l_atinn = <lc_bdcp>-tabkey+18(10).

            CALL FUNCTION 'CONVERSION_EXIT_ATINN_OUTPUT'
              EXPORTING
                input  = l_atinn
              IMPORTING
                output = l_atnam.

            " characteristics for material ?
            READ TABLE  mt_charactreristics WITH KEY name_char =  l_atnam INTO DATA(l_charact).
            IF sy-subrc EQ 0 AND l_charact-department_view CS 'M'.  "reject characteristics change if not in 'M' Org Area
              APPEND key_s TO objs_t.
            ENDIF.

          ENDIF.

        WHEN OTHERS.
          ex_text = <lc_bdcp>-tabname.

      ENDCASE.


    ENDLOOP.


    SORT objs_t BY matnr.
    DELETE ADJACENT DUPLICATES FROM objs_t COMPARING  matnr.


    IF objs_t[] IS NOT INITIAL.
      SELECT DISTINCT matnr
      FROM Zp_s_mia_drf_mat_filter
      INTO TABLE @ct_changed_objects
      FOR ALL ENTRIES IN @objs_t
      WHERE matnr = @objs_t-matnr
      AND cust_bc_mes_dist = @temp_cust_bc_mes_dist .
      IF sy-subrc <> 0.
        MESSAGE ID sy-msgid TYPE sy-msgty NUMBER sy-msgno
        WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4 INTO ex_text.
      ENDIF.

    ENDIF.



  ENDMETHOD.                    "IF_DRF_OUTBOUND~ANALYZE_CHANGES_BY_CHG_POINTER


  METHOD IF_DRF_OUTBOUND~ANALYZE_CHANGES_BY_MDG_CP.
*
*    data: CHANGE_POINTER_S type MDG_CP_S_CP_FULL,
*          MAT_KEY_S        type MDG_BS_MAT_DRF_S_MATNR_KEY,
*          CHANGE_POINTER_T type MDG_CP_T_CP.
*
*    CHANGE_POINTER_T = IT_CHANGE_POINTER.
*
***Delete duplicate records from the cahnge pointer table
*    sort CHANGE_POINTER_T by OBJECT_KEY.
*    delete adjacent duplicates from CHANGE_POINTER_T comparing OBJECT_KEY.
*
*** Object keys are fetched from the change pointer
*    loop at CHANGE_POINTER_T into CHANGE_POINTER_S.
*      MAT_KEY_S-MATNR = CHANGE_POINTER_S-OBJECT_KEY.
*      insert MAT_KEY_S into table CT_CHANGED_OBJECTS.
*    endloop.

  ENDMETHOD.                    "if_drf_outbound~analyze_changes_by_mdg_cp


  METHOD IF_DRF_OUTBOUND~ANALYZE_CHANGES_BY_OTHERS.

  ENDMETHOD.                    "IF_DRF_OUTBOUND~ANALYZE_CHANGES_BY_OTHERS


  METHOD IF_DRF_OUTBOUND~APPLY_NODE_INST_FILTER_MULTI.
    RETURN.
  ENDMETHOD.                    "if_drf_outbound~apply_node_inst_filter_multi


  METHOD IF_DRF_OUTBOUND~APPLY_NODE_INST_FILTER_SINGLE.
    RETURN.
  ENDMETHOD.                    "IF_DRF_OUTBOUND~APPLY_NODE_INST_FILTER_SINGLE


  METHOD IF_DRF_OUTBOUND~BUILD_PARALLEL_PACKAGE.

  ENDMETHOD.                    "IF_DRF_OUTBOUND~BUILD_PARALLEL_PACKAGE


  METHOD IF_DRF_OUTBOUND~ENRICH_FILTER_CRITERIA.


*
    DATA(business_system)  =  gr_drf_mat->ms_runtime_param-business_system.
*  DATA TEMP_cust_bc_MES_DIST TYPE ZP_MCN_cust_bc_MES_DIST.
*
*
    DATA(temp_cust_bc_mes_dist) = business_sys_to_cust_bc_mes_dist( business_system ).
*


    DATA: t_selopt   TYPE rsds_selopt_t.


    DATA: wa_selopt   TYPE rsdsselopt,
          wa_selfield TYPE rsds_frange,
          wa_seltab   TYPE rsds_range.

    wa_seltab-tablename   = 'ZP_MIA_MM_MES_DRF_FLT_S'.
    wa_selfield-fieldname = 'cust_bc_MES_DIST'.
    wa_selopt-sign    = 'I'.
    wa_selopt-option  = 'EQ'.
    wa_selopt-low     = temp_cust_bc_mes_dist .
    APPEND wa_selopt TO t_selopt.


    CLEAR wa_selopt.
    APPEND LINES OF t_selopt TO wa_selfield-selopt_t.
    CLEAR t_selopt.
    APPEND wa_selfield TO wa_seltab-frange_t.
    CLEAR wa_selfield.
    APPEND wa_seltab TO et_add_external_criteria.
    CLEAR wa_seltab.








  ENDMETHOD.                    "if_drf_outbound~enrich_filter_criteria


  METHOD IF_DRF_OUTBOUND~FINALIZE.

  ENDMETHOD.                    "IF_DRF_OUTBOUND~FINALIZE


  METHOD IF_DRF_OUTBOUND~INITIALIZE.



    gv_repl_mode = is_runtime_param-dlmod.

    CREATE OBJECT gr_drf_mat.

    "move IS_RUNTIME_PARAM to GR_DRF_MAT->MS_RUNTIME_PARAM.
    gr_drf_mat->ms_runtime_param = is_runtime_param .

    es_runtime_param_out_impl-table_type_name =  gc_mat_key_tab.
    eo_if_drf_outbound = gr_drf_mat.





  ENDMETHOD.                    "if_drf_outbound~initialize


  method if_drf_outbound~map_data2message.
  endmethod.


  METHOD IF_DRF_OUTBOUND~READ_COMPLETE_DATA.
*------------------------------------------------------------------------------------------------*
* Functional Spec: Master MES GNE interface
* Technical Spec: Master MES GNE interface
* Process: Maintain product master data
* History ---------------------------------------------------------------------------------------*
* Date       | Change           | Contributor               | Description
*------------------------------------------------------------------------------------------------*
*------------------------------------------------------------------------------------------------*
    DATA :
      class_data_s TYPE mdg_bs_mat_drf_s_clf_key_data,
      inob_map_s   TYPE mdg_bs_clf_s_objnum_map,
      obj_key_s    TYPE cuobn,
      class_s      TYPE if_mdg_bs_clf_access=>ty_s_classasgn.
    DATA:
      lo_mat_clf    TYPE REF TO cl_mdg_mat_drf_clf,
      lx_mdg_bs_clf TYPE REF TO cx_mdg_bs_clf_gen.
    DATA:
      inob_map_t TYPE mdg_bs_clf_t_objnum_map,
      obj_key_t  TYPE mdg_bs_clf_t_objnum,
      class_t    TYPE if_mdg_bs_clf_access=>ty_ts_classasgn,
      marakey_s  TYPE bdimarakey.

    FIELD-SYMBOLS : <relv_obj_s> TYPE mdg_bs_mat_drf_s_matnr_key.

**** The range tables are filled for fetching complete data of material

    "DELETE ADJACENT DUPLICATES FROM ct_relevant_objects.


    LOOP AT ct_relevant_objects ASSIGNING <relv_obj_s> .
      obj_key_s = <relv_obj_s>-matnr.
      "APPEND obj_key_s TO obj_key_t.
      INSERT obj_key_s INTO TABLE obj_key_t. " - dumps -matnr = <relv_obj_s>-matnr.
      marakey_s-mandt = sy-mandt.
      INSERT marakey_s INTO TABLE mt_mat_segment_data-t_marakey.
    ENDLOOP.

*** The method is called to get the classification data of the materials
*-----------------------------------------------------------
    CREATE OBJECT lo_mat_clf.

    TRY.
        CLEAR class_t.
        CALL METHOD cl_mdg_bs_clf_access=>check_out_classasgn
          EXPORTING
            io_context_cntl = lo_mat_clf
            iv_objtype      = 'MARA'
            its_objnum      = obj_key_t
          IMPORTING
            ets_classasgn   = class_t
            ets_objnum_map  = inob_map_t.

      CATCH cx_mdg_bs_clf_gen INTO lx_mdg_bs_clf.
        CALL METHOD ms_runtime_param-bal->add_msg_re
          EXPORTING
            iv_msgno             = sy-msgno
            ix_exception_catched = lx_mdg_bs_clf.
    ENDTRY.
* Collect
    mt_inob_map = inob_map_t.

*** Class data are read for materials and stored in a global object for later access.
    IF class_t IS NOT INITIAL.
      CLEAR class_s.
      LOOP AT class_t INTO class_s.
        READ TABLE inob_map_t INTO inob_map_s WITH KEY objek = class_s-key-id-objnum
        objtype = class_s-key-id-objtype classtype = class_s-key-id-classtype .
        IF sy-subrc EQ 0.
          class_data_s-objek = inob_map_s-cuobj.
          class_data_s-obtab = inob_map_s-objtype.
        ELSE.
          class_data_s-objek = class_s-key-id-objnum.
          class_data_s-obtab = class_s-key-id-objtype.
        ENDIF.
        class_data_s-klart = class_s-key-id-classtype.
        class_data_s-aennr = class_s-key-id-changeno.
        class_data_s-datuv = class_s-att-datuv.
        class_data_s-clint = class_s-att-clint.
        class_data_s-adzhl = class_s-att-adzhl.
        class_data_s-mafid = class_s-att-mafid.
        class_data_s-matnr = class_s-key-id-objnum.
        APPEND class_data_s TO mt_class_data.
        CLEAR inob_map_s.
      ENDLOOP.
    ENDIF.
    SORT  mt_class_data BY klart objek obtab aennr.
    DELETE ADJACENT DUPLICATES FROM mt_class_data.


    me->read_mat_data_pack( it_relevant_objects = ct_relevant_objects ).  " mat3060_s TYPE t_mat3060.
    DATA return TYPE bapiret2_t.
    "DATA(IR_APPLICATION_LOG) = MO_ ->MS_RUNTIME_PARAMETER_EXT-BAL.



    LOOP AT ct_relevant_objects ASSIGNING <relv_obj_s> .
      CALL FUNCTION 'ZP_MIA_MATERIAL_READ_DATA'
        EXPORTING
          material            = <relv_obj_s>-matnr
        TABLES
          return              = return
          classallocations    = mat3060_s-classallocations[]
          classvaluationschar = mat3060_s-classvaluationschar[]
          classvaluationscurr = mat3060_s-classvaluationscurr[]
          classvaluationsnum  = mat3060_s-classvaluationsnum[].



      DATA(err_material_read_data) = sy-subrc ##needed.





      mat3060_s-matnr = <relv_obj_s>-matnr.

      APPEND mat3060_s TO gt_mat3060.


      DATA return_ehs             TYPE STANDARD TABLE OF bapiret2.

      CALL FUNCTION 'ZP_MIA_EHS_READ_DATA_V2'     "
        EXPORTING
          material           = <relv_obj_s>-matnr
          business_system    = ms_runtime_param-rtime_ext_bus_sys-business_system   " - KambleT1 : 27.03.2026
        IMPORTING
          rc                 = rc
        TABLES
          return             = return_ehs
        CHANGING
          ct_matmas_ehsphr_t = gt_matmas_ehsphr_t.
      "


      rc = sy-subrc + rc.

    ENDLOOP.





  ENDMETHOD.                    "if_drf_outbound~read_complete_data


  METHOD IF_DRF_OUTBOUND~SEND_MESSAGE.

    DATA :
      bus_sys_tech_s        TYPE mdg_s_bus_sys_tech,
      obj_rep_s             TYPE drf_s_obj_rep_sta_attr,
      idoc_control_s        TYPE edidc,
      idoc_matmas_control_t TYPE t_edidc,
      idoc_clfmas_control_t TYPE t_edidc ##needed,
      class_data_t          TYPE mdg_bs_mat_drf_t_clf_key_data ##needed,
      mat_data_s            TYPE mdg_bs_mat_drf_s_key_data.

    CLEAR mt_change_pointer."For each business system refresh the change pointer table



    "data(BUSINESS_SYSTEM)  =  MO_DRF_MES_BATCH_OUT->MS_RUNTIME_PARAMETER_EXT-BUSINESS_SYSTEM.  "

* Fetch the business system for the replication model
    IF mv_count_call EQ 0.
      mv_count_call = 1.
      CALL METHOD cl_drf_access_cust_data=>select_business_sys_for_appl
        EXPORTING
          iv_appl         = ms_runtime_param-appl
          iv_outb_impl    = ms_runtime_param-outb_impl
        IMPORTING
          et_bus_sys_tech = mt_bus_sys_tech.
    ENDIF.

    READ TABLE ct_obj_rep_sta INTO obj_rep_s INDEX 1.
    DATA(rc) = sy-subrc ##needed.

    READ TABLE mt_bus_sys_tech INTO bus_sys_tech_s WITH KEY business_system = obj_rep_s-business_system.
    rc = sy-subrc.
    idoc_control_s-rcvprn = bus_sys_tech_s-logsys.
    idoc_control_s-rcvprt =  gc_rcvprt.

    APPEND idoc_control_s TO idoc_matmas_control_t.
    APPEND idoc_control_s TO idoc_clfmas_control_t.
    mat_data_s = mt_mat_segment_data .


    SORT mat_data_s-t_stxhkey BY tdname(18).

    IF iv_object_count > 0.
      CALL METHOD me->handle_mat_data
        EXPORTING
          iv_packet_size = iv_object_count
        IMPORTING
          et_class_data  = class_data_t
        CHANGING
          cs_mat_data    = mat_data_s.
    ENDIF.


* Send Matmas IDOC
    IF mat_data_s IS NOT INITIAL.
      CALL METHOD send_yp1t_mes_matmas_idoc
        EXPORTING
          is_material_data = mat_data_s
          is_bus_sys_tech  = bus_sys_tech_s "IS_BUS_SYS_TECH 
          ct_idoc_cntrl    = idoc_matmas_control_t
          ct_obj_rep_sta   = ct_obj_rep_sta.
    ENDIF.



    DATA(cp_postproces) = space.

    IF cp_postproces EQ 'X'.
      IF ms_runtime_param-outb_impl =  gc_outb_impl."Execute change pointer and new message types only in case of new outbound implmentation
        " Set Change pointer to processed for current system
        IF mt_change_pointer IS NOT INITIAL.
          SORT mt_change_pointer.
          DELETE ADJACENT DUPLICATES FROM mt_change_pointer.
          cl_mdg_change_pointer=>set_cp_status_per_bus_sys(
          EXPORTING
            it_change_pointer  = mt_change_pointer
            iv_business_system = obj_rep_s-business_system
            iv_status          = cl_mdg_change_pointer=>gc_status_cp ).
        ENDIF.
      ENDIF.
    ENDIF.
  ENDMETHOD.                    "if_drf_outbound~send_message


  method map_mat_segment_data.
**** Get the relevant objects from the filter and store it in static variable

    data : mat_s_mara_s type mdg_bs_mat_s_mara .
    data : mat_s_makt_s type mdg_bs_mat_s_makt .
    data : mat_s_marc_s type mdg_bs_mat_s_marc .
    data : mat_s_mard_s type mdg_bs_mat_s_mard .
    data : mat_s_mpgd_s type mdg_bs_mat_s_mpgd .
    data : mat_s_mpop_s type mdg_bs_mat_s_mpop .
    data : mat_s_marm_s type mdg_bs_mat_s_marm .
    data : mat_s_mean_s type mdg_bs_mat_s_mean .
    data : mat_s_mbew_s type mdg_bs_mat_s_mbew .
    data : mat_s_mlgn_s type mdg_bs_mat_s_mlgn.
    data : mat_s_mlgt_s type mdg_bs_mat_s_mlgt .
    data : mat_s_mvke_s type mdg_bs_mat_s_mvke .
    data : mat_s_mlan_pr_s     type mdg_bs_mat_s_steumm.
    data : mat_s_mlan_sl_s     type mdg_bs_mat_s_steu.

    data : bdimarakey_s type bdimarakey.
    data : bdimaktkey_s type bdimaktkey.
    data : bdimarckey_s type mdg_bs_mat_drf_s_plnt_key_data.
    data : bdimardkey_s type bdimardkey.
    data : bdimpgdkey_s type bdimpgdkey.
    data : bdimpopkey_s type bdimpopkey.
    data : bdimarmkey_s type bdimarmkey.
    data : bdimeankey_s type bdimeankey.
    data : bdimbewkey_s type bdimbewkey.
    data : bdimlgnkey_s type bdimlgnkey.
    data : bdimlgtkey_s type bdimlgtkey.
    data : bdimvkekey_s type mdg_bs_mat_drf_s_sls_key_data.
    data : bdimlankey_s type bdimlankey.

    data : mara_t type standard table of mdg_bs_mat_s_mara.
    data : marc_t type standard table of mdg_bs_mat_s_marc.
    data : mard_t type standard table of mdg_bs_mat_s_mard.
    data : mbew_t type standard table of mdg_bs_mat_s_mbew.
    data : mlgn_t type standard table of mdg_bs_mat_s_mlgn.
    data : mvke_t type standard table of mdg_bs_mat_s_mvke.
    data : mlgt_t type standard table of mdg_bs_mat_s_mlgt.

    define filltable .
      LOOP AT is_mat_data-&1_tab INTO mat_s_&1_s .
        MOVE-CORRESPONDING mat_s_&1_s TO bdi&1key_s.
        APPEND bdi&1key_s TO mt_mat_segment_data-t_&1key.
      ENDLOOP.
    end-of-definition.

    define filltable_1 .
      "APPEND LINES OF is_mat_data-&1_tab TO lt_&1.
      APPEND LINES OF is_mat_data-&1_tab TO &1_t.
      IF gv_repl_mode = if_drf_const=>mode_init.
        LOOP AT &1_t INTO mat_s_&1_s WHERE lvorm NE abap_true.
          MOVE-CORRESPONDING mat_s_&1_s TO bdi&1key_s.
          APPEND bdi&1key_s TO mt_mat_segment_data-t_&1key.
        ENDLOOP.
      ELSE.
        LOOP AT &1_t INTO mat_s_&1_s .
          MOVE-CORRESPONDING mat_s_&1_s TO bdi&1key_s.
          APPEND bdi&1key_s TO mt_mat_segment_data-t_&1key.
        ENDLOOP.
      ENDIF.
    end-of-definition.

    filltable_1 mara.
    filltable_1 marc.
    filltable_1 mard.
    filltable_1 mbew.
    filltable_1 mlgn.
    filltable_1 mlgt.
    filltable_1 mvke.
    filltable makt.
    filltable mpgd.
    filltable mpop.
    filltable marm.
    filltable mean.

    loop at is_mat_data-mlan_purchase_tab into mat_s_mlan_pr_s .
      clear bdimlankey_s.
      move-corresponding mat_s_mlan_pr_s to bdimlankey_s.
      bdimlankey_s-mandt = sy-mandt.
      append bdimlankey_s to mt_mat_segment_data-t_mlankey.
    endloop.

    loop at is_mat_data-mlan_sales_tab into mat_s_mlan_sl_s.
      clear bdimlankey_s.
      move-corresponding mat_s_mlan_sl_s to bdimlankey_s.
      bdimlankey_s-msgfn = mat_s_mlan_sl_s-taxkm.
      bdimlankey_s-mandt = sy-mandt.
      append bdimlankey_s to mt_mat_segment_data-t_mlankey.
    endloop.

  endmethod.                    "map_mat_segment_data


  method read_mat_data_pack.
*------------------------------------------------------------------------------------------------*
* Functional Spec: Master MES GNE interface
* Technical Spec: Master MES GNE interface
* Process: Maintain product master data
* History ---------------------------------------------------------------------------------------*
* Date       | Change           | Contributor               | Description
*------------------------------------------------------------------------------------------------*
*------------------------------------------------------------------------------------------------*


*** the range tables are filled for fetching complete data of material

    data :mat_id_s    type range_s_matnr,
          selection_s type mdg_bs_mat_s_mat_selection,
          data_s      type mdg_bs_mat_s_mat_data,
          message_s   type mdg_bs_mat_s_mat_msg,
          sql_err_s   type scx_t100key.

    data:
      lr_mdg_mat       type ref to cl_mdg_bs_mat_api,
      lx_sql_exception type ref to cx_root.

    data:
      mat_id_t      type range_t_matnr,
      mat_segment_t type mdg_bs_mat_t_mat_tbnam,
      messages_t    type mdg_bs_mat_t_mat_msg.

    "FIELD-SYMBOLS : <relv_obj_s> TYPE mdg_bs_mat_drf_s_matnr_key.
    field-symbols : <relv_obj_s> type Zp_mia_drf_s_matnr_key. "

    loop at it_relevant_objects assigning <relv_obj_s> ##GEN_OK .
      mat_id_s-option = 'EQ'.
      mat_id_s-sign = 'I'.
      mat_id_s-low = <relv_obj_s>-matnr.
      insert mat_id_s into table mat_id_t.
    endloop.

*=================================================
*** All segments are filled for fetching the data of these segments
    append  gc_marc_segment to mat_segment_t.
    append  gc_mbew_segment to mat_segment_t.
    append  gc_mara_segment to mat_segment_t.
    append  gc_marm_segment to mat_segment_t.
    append  gc_mard_segment to mat_segment_t.
    append  gc_makt_segment to mat_segment_t.
    append  gc_mean_segment to mat_segment_t.


    create object lr_mdg_mat.

** read materials in batch of 1000 material per call to avoid huge data processing at one call
    selection_s-matnr_range = mat_id_t.

*** To get complete data of materials, this method is called.
    clear data_s.
    try.
        call method lr_mdg_mat->read
          exporting
            is_selection    = selection_s
            it_mat_segments = mat_segment_t
          importing
            es_data         = data_s
            et_message      = messages_t.

      catch cx_root into lx_sql_exception .
        call method ms_runtime_param-bal->add_msg
          exporting
            iv_msgty = 'E'
            iv_msgno = '007'
            iv_msgid = 'MDG_BS_MAT_DRF_MSG'
            iv_msgv1 = lx_sql_exception->get_longtext( ).

        sql_err_s-msgid =  'MDG_BS_MAT_DRF_MSG'.
        sql_err_s-msgno = '007'.
        sql_err_s-attr1 = lx_sql_exception->get_longtext( ).

        raise exception type cx_drf_process_messages
          exporting
            textid   = sql_err_s
            previous = lx_sql_exception->previous.

    endtry.

*** Error handling
    loop at messages_t into message_s where msgty ca 'EAX' .
      call method ms_runtime_param-bal->add_msg
        exporting
          iv_msgty = message_s-msgty
          iv_msgno = message_s-msgno
          iv_msgid = message_s-msgid
          iv_msgv1 = message_s-msgv1
          iv_msgv2 = message_s-msgv2
          iv_msgv3 = message_s-msgv3
          iv_msgv4 = message_s-msgv4.
      clear message_s.
    endloop.

*** The method is called to map the segment data of material
    call method gr_drf_mat->map_mat_segment_data
      exporting
        is_mat_data = data_s.

    call method read_text_keys
      exporting
        it_matnr_range = selection_s-matnr_range   " Range Table for Data Element MATNR
        it_marc        = data_s-marc_tab
        it_mvke        = data_s-mvke_tab.

    delete adjacent duplicates from mt_mat_segment_data-t_marakey comparing matnr.

  endmethod.                    "read_mat_data_pack


  method read_text_keys.

    data:
      selection_t  type table of thead,
      name_s       type stxdrname,
      name_t       type table of stxdrname,
      name_i_s     type stextname,
      name_i_t     type table of stextname,
      bdistxhkey_s type bdistxhkey.

    field-symbols:
      <matnr_range_s> type range_s_matnr,
      <marc_s>        type mdg_bs_mat_s_marc,
      <mvke_s>        type mdg_bs_mat_s_mvke,
      <selection_s>   type thead.

** Build the Range tables for MATNR
    loop at it_matnr_range assigning <matnr_range_s> .
      name_s-sign = <matnr_range_s>-sign .
      name_s-option = <matnr_range_s>-option .
      name_s-low = <matnr_range_s>-low .
      name_s-high = <matnr_range_s>-high .
      append name_s to name_t .
    endloop.

    if name_t[] is not initial.
      clear selection_t.
      call function 'SELECT_TEXT'
        exporting
          object                  = 'MATERIAL'
        tables
          selections              = selection_t
          t_name                  = name_t
        exceptions
          wrong_access_to_archive = 1
          others                  = 2.
      data(rc) = sy-subrc ##needed.


      loop at selection_t assigning <selection_s>.
        clear bdistxhkey_s.
        bdistxhkey_s-mandt = <selection_s>-mandt.
        bdistxhkey_s-tdid = <selection_s>-tdid.
        bdistxhkey_s-tdname = <selection_s>-tdname.
        bdistxhkey_s-tdobject = <selection_s>-tdobject.
        bdistxhkey_s-tdspras = <selection_s>-tdspras.
*      bdistxhkey_s-msgfn = ...
        append bdistxhkey_s to mt_mat_segment_data-t_stxhkey.
      endloop.

    endif.
    " Plant Text
    clear : name_t, name_s, name_i_t, name_i_s.
    loop at it_marc assigning <marc_s> .
      concatenate <marc_s>-matnr <marc_s>-werks into name_i_s separated by space respecting blanks.
      append name_i_s to name_i_t.
    endloop.
    if name_i_t[] is not initial.
** Call function SELECT_TEXT
      clear selection_t.
      call function 'SELECT_TEXT'
        exporting
          object                  = 'MDTXT'
          id                      = 'LTXT'
        tables
          selections              = selection_t
          i_name                  = name_i_t
        exceptions
          wrong_access_to_archive = 1
          others                  = 2.

      rc = sy-subrc.

      loop at selection_t assigning <selection_s>.
        clear bdistxhkey_s.
        bdistxhkey_s-mandt = <selection_s>-mandt.
        bdistxhkey_s-tdid = <selection_s>-tdid.
        bdistxhkey_s-tdname = <selection_s>-tdname.
        bdistxhkey_s-tdobject = <selection_s>-tdobject.
        bdistxhkey_s-tdspras = <selection_s>-tdspras.
*      bdistxhkey_s-msgfn = ...
        append bdistxhkey_s to mt_mat_segment_data-t_stxhkey.
      endloop.

    endif.

    " Sales Text
    clear : name_i_t, name_i_s.
    loop at it_mvke assigning <mvke_s> .
      concatenate <mvke_s>-matnr <mvke_s>-vkorg <mvke_s>-vtweg into name_i_s respecting blanks.
      append name_i_s to name_i_t.
    endloop.

    if name_i_t[] is not initial.
      clear selection_t.
      call function 'SELECT_TEXT'
        exporting
          object                  = 'MVKE'
        tables
          selections              = selection_t
          i_name                  = name_i_t
        exceptions
          wrong_access_to_archive = 1
          others                  = 2.

      rc = sy-subrc.


      loop at selection_t assigning <selection_s>.
        clear bdistxhkey_s.
        bdistxhkey_s-mandt = <selection_s>-mandt.
        bdistxhkey_s-tdid = <selection_s>-tdid.
        bdistxhkey_s-tdname = <selection_s>-tdname.
        bdistxhkey_s-tdobject = <selection_s>-tdobject.
        bdistxhkey_s-tdspras = <selection_s>-tdspras.
*      bdistxhkey_s-msgfn = ...
        append bdistxhkey_s to mt_mat_segment_data-t_stxhkey.
      endloop.

    endif.
  endmethod.


  method send_yp1t_mat_segments.
*------------------------------------------------------------------------------------------------*
* Functional Spec: Master MES GNE interface
* Technical Spec: Master MES GNE interface
* Process: Maintain product master data
* History ---------------------------------------------------------------------------------------*
* Date       | Change           | Contributor               | Description
*------------------------------------------------------------------------------------------------*
*------------------------------------------------------------------------------------------------*




    data : maktkey_s type bdimaktkey.
    data : marckey_s type bdimarckey.
    data : mardkey_s type bdimardkey.
    data : mpgdkey_s type bdimpgdkey.
    data : mpopkey_s type bdimpopkey.
    data : marmkey_s type bdimarmkey.
    data : meankey_s type bdimeankey.
    data : mbewkey_s type bdimbewkey.
    data : mlgnkey_s type bdimlgnkey.
    data : mlgtkey_s type bdimlgtkey.
    data : mvkekey_s type bdimvkekey.
    data : mlankey_s type bdimlankey.
    data : stxhkey_s type bdistxhkey.
    data : makt_t type table of bdimaktkey.
    data : marc_t type table of bdimarckey.
    data : mard_t type table of bdimardkey.
    data : mpgd_t type table of bdimpgdkey.
    data : mpop_t type table of bdimpopkey.
    data : marm_t type table of bdimarmkey.
    data : mean_t type table of bdimeankey.
    data : mbew_t type table of bdimbewkey.
    data : mlgn_t type table of bdimlgnkey.
    data : mlgt_t type table of bdimlgtkey.
    data : mvke_t type table of bdimvkekey.
    data : mlan_t type table of bdimlankey.
    data : stxh_t type table of bdistxhkey.
    data : hindex  like sy-tabix.
    data : created_comm_idocs_v like sy-tabix,
           idoc_control_t       type t_edidc.
    data matnr_v type matnr.
    data stxh_found_v type abap_bool value abap_false. "according to note 2695632 resp 395277

    data:
      mkalkey_t        type  table of  bdimkalkey,
      mkalkey_s        type  bdimkalkey,
      matnr_range_s    type  range_s_matnr,
      matnr_range_t    type  range_t_matnr,
      werks_range_s    type  range_s_werks,
      werks_range_t    type  range_t_werks,
      lo_mkal          type ref to cl_mdg_bs_mat_mkal_api,
      mkal_selection_s type mdg_bs_mat_s_mat_mkal_select,
      mkal_t           type mdg_bs_mat_t_mkal.

    clear: et_idoc, ev_created_idocs.
    clear: makt_t, marc_t, mard_t, marm_t,
    mean_t ,mvke_t,mlan_t, mbew_t,
    mlgn_t, mlgt_t, stxh_t, mpop_t, mpgd_t.
*MAKT : Fill table makt_t for corresponding Material
    read table is_material_data-t_maktkey with key matnr = is_marakey-matnr
    binary search transporting no fields.
    if sy-subrc eq 0.
      hindex = sy-tabix." move SY-TABIX to HINDEX.
      loop at is_material_data-t_maktkey from hindex into maktkey_s.
        if maktkey_s-matnr ne is_marakey-matnr.
          exit.
        endif.
        append maktkey_s to makt_t.
      endloop.
    endif.

* MARC : Fill table marc_t for corresponding Material
    read table is_material_data-t_marckey with key matnr = is_marakey-matnr
    binary search transporting no fields.
    if sy-subrc eq 0.
      hindex = sy-tabix."move SY-TABIX to HINDEX.
      loop at is_material_data-t_marckey from hindex into marckey_s.
        if marckey_s-matnr ne is_marakey-matnr.
          exit.
        endif.
        append marckey_s to marc_t.
      endloop.
    endif.

*MARD : Fill table mard_t for corresponding Material
    read table is_material_data-t_mardkey with key matnr = is_marakey-matnr
    binary search transporting no fields.
    if sy-subrc eq 0.
      "MOVE sy-tabix TO hindex.
      hindex = sy-tabix.
      loop at is_material_data-t_mardkey from hindex into mardkey_s.
        if mardkey_s-matnr ne is_marakey-matnr.
          exit.
        endif.
        append mardkey_s to mard_t.
      endloop.
    endif.
*
*MPGD : Fill table mpgd_t for corresponding Material
    read table is_material_data-t_mpgdkey with key matnr = is_marakey-matnr
    binary search transporting no fields.
    if sy-subrc eq 0.
      "move SY-TABIX to HINDEX.
      hindex = sy-tabix.
      loop at is_material_data-t_mpgdkey from hindex into mpgdkey_s.
        if mpgdkey_s-matnr ne is_marakey-matnr.
          exit.
        endif.
        append mpgdkey_s to mpgd_t.
      endloop.
    endif.

*MPOP : Fill table mpop_t for corresponding Material
    read table is_material_data-t_mpopkey with key matnr = is_marakey-matnr
    binary search transporting no fields.
    if sy-subrc eq 0.
      "move SY-TABIX to HINDEX.
      hindex = sy-tabix.
      loop at is_material_data-t_mpopkey from hindex into mpopkey_s.
        if mpopkey_s-matnr ne is_marakey-matnr.
          exit.
        endif.
        append mpopkey_s to mpop_t.
      endloop.
    endif.

*MARM : Fill table marm_t for corresponding Material
    read table is_material_data-t_marmkey with key matnr = is_marakey-matnr
    binary search transporting no fields.
    if sy-subrc eq 0.
      hindex = sy-tabix. "move SY-TABIX to HINDEX.
      loop at is_material_data-t_marmkey from hindex into marmkey_s.
        if marmkey_s-matnr ne is_marakey-matnr.
          exit.
        endif.
        append marmkey_s to marm_t.
      endloop.
    endif.

*MEAN : Fill table mean_t for corresponding Material
    read table is_material_data-t_meankey with key matnr = is_marakey-matnr
    binary search transporting no fields.
    if sy-subrc eq 0.
      "move SY-TABIX to HINDEX.
      hindex = sy-tabix.
      loop at is_material_data-t_meankey from hindex into meankey_s.
        if meankey_s-matnr ne is_marakey-matnr.
          exit.
        endif.
        append meankey_s to mean_t.
      endloop.
    endif.

*MBEW : Fill table mbew_t for corresponding Material
    read table is_material_data-t_mbewkey with key matnr = is_marakey-matnr
    binary search transporting no fields.
    if sy-subrc eq 0.
      "move SY-TABIX to HINDEX.
      hindex = sy-tabix.
      loop at is_material_data-t_mbewkey from hindex into mbewkey_s.
        if mbewkey_s-matnr ne is_marakey-matnr.
          exit.
        endif.
        append mbewkey_s to mbew_t.
      endloop.
    endif.

*MLGN : Fill table mlgn_t for corresponding Material
    read table is_material_data-t_mlgnkey with key matnr = is_marakey-matnr
    binary search transporting no fields.
    if sy-subrc eq 0.
      "move SY-TABIX to HINDEX.
      hindex = sy-tabix.
      loop at is_material_data-t_mlgnkey from hindex into mlgnkey_s.
        if mlgnkey_s-matnr ne is_marakey-matnr.
          exit.
        endif.
        append mlgnkey_s to mlgn_t.
      endloop.
    endif.

*MLGT : Fill table mlgt_t for corresponding Material
    read table is_material_data-t_mlgtkey with key matnr = is_marakey-matnr
    binary search transporting no fields.
    if sy-subrc eq 0.
      "move SY-TABIX to HINDEX.
      hindex = sy-tabix.
      loop at is_material_data-t_mlgtkey from hindex into mlgtkey_s.
        if mlgtkey_s-matnr ne is_marakey-matnr.
          exit.
        endif.
        append mlgtkey_s to mlgt_t.
      endloop.
    endif.

*MVKE : Fill table mvke_t for corresponding Material
    read table is_material_data-t_mvkekey with key matnr = is_marakey-matnr
    binary search transporting no fields.
    if sy-subrc eq 0.
      "move SY-TABIX to HINDEX.
      hindex = sy-tabix.
      loop at is_material_data-t_mvkekey from hindex into mvkekey_s.
        if mvkekey_s-matnr ne is_marakey-matnr.
          exit.
        endif.
        append mvkekey_s to mvke_t.
      endloop.
    endif.

*MLAN : Fill table mlan_t for corresponding Material
    read table is_material_data-t_mlankey with key matnr = is_marakey-matnr
    binary search transporting no fields.
    if sy-subrc eq 0.
      "move SY-TABIX to HINDEX.
      hindex = sy-tabix.
      loop at is_material_data-t_mlankey from hindex into mlankey_s.
        if mlankey_s-matnr ne is_marakey-matnr.
          exit.
        endif.
        append mlankey_s to mlan_t.
      endloop.
    endif.

*STXH : Fill table STXH_T for corresponding Material.
    stxh_found_v = abap_false.
    loop at is_material_data-t_stxhkey into stxhkey_s.
      if stxhkey_s-tdobject eq 'MVKE'."sales Text
        if strlen( stxhkey_s-tdname ) gt 24.
          matnr_v = stxhkey_s-tdname(40).
        else.
          matnr_v = stxhkey_s-tdname(18).
        endif.
      elseif stxhkey_s-tdobject eq 'MDTXT'."Plant text
        if strlen( stxhkey_s-tdname ) gt 23.
          matnr_v = stxhkey_s-tdname(40).
        else.
          matnr_v = stxhkey_s-tdname(18).
        endif.
      else.
        matnr_v = stxhkey_s-tdname.
      endif.
      if matnr_v ne is_marakey-matnr.
        if stxh_found_v = abap_true.
          exit.
        else.
          continue.
        endif.
      endif.
      append stxhkey_s to stxh_t.
      stxh_found_v = abap_true.
    endloop.

*Call to replicate Material.
    clear : created_comm_idocs_v, matnr_range_s,
    werks_range_s, matnr_range_t, werks_range_t.

    """ Handle MKAL
    loop at marc_t into marckey_s.
      matnr_range_s-option = 'EQ'.
      matnr_range_s-sign = 'I'.
      matnr_range_s-low = marckey_s-matnr.
      append matnr_range_s to matnr_range_t.

      werks_range_s-option = 'EQ'.
      werks_range_s-sign = 'I'.
      werks_range_s-low = marckey_s-werks.
      append werks_range_s to werks_range_t.
    endloop.

    mkal_selection_s-matnr_range = matnr_range_t.
    mkal_selection_s-werks_range = werks_range_t.

    if mkal_selection_s is not initial.
      create object lo_mkal.
      call method lo_mkal->read
        exporting
          is_selection = mkal_selection_s
        importing
          et_mkal      = mkal_t.
    endif.

    loop at mkal_t into data(mkal_s).
      move-corresponding mkal_s to mkalkey_s.
      append mkalkey_s to mkalkey_t.
    endloop.



    read table gt_mat3060 into data(mat3060_s)
          with key matnr = is_marakey-matnr  .
    rc = sy-subrc.


    data(matmas_ehsphr_t_t) = gt_matmas_ehsphr_t[].

    delete matmas_ehsphr_t_t where matnr ne is_marakey-matnr  .


    "CALL FUNCTION 'MASTERIDOC_CREATE_MATMAS'
    "CALL FUNCTION 'ZP_MIA_DRF_YP1T_MATMAS_CRE'
    call function 'ZP_MIA_DRF_MATMAS_GMES_CRE'
      exporting
        marakey             = is_marakey
        rcvpfc              = ' '
        rcvprn              = is_idoc_control-rcvprn
        rcvprt              = is_idoc_control-rcvprt
        sndpfc              = ' '
        sndprn              = '          '
        sndprt              = ' '
        message_type        = iv_mesgtype
        sendconfig          = gv_sendconfig
        business_system     = is_bus_sys_tech-business_system
      importing
        created_comm_idocs  = created_comm_idocs_v
      tables
        maktkey             = makt_t
        marckey             = marc_t
        mardkey             = mard_t
        marmkey             = marm_t
        meankey             = mean_t
        mvkekey             = mvke_t
        mlankey             = mlan_t
        mbewkey             = mbew_t
        mlgnkey             = mlgn_t
        mlgtkey             = mlgt_t
        stxhkey             = stxh_t
        mpopkey             = mpop_t
        mpgdkey             = mpgd_t
        mkalkey             = mkalkey_t
        te_idoc_control     = idoc_control_t
        classallocations    = mat3060_s-classallocations[]
        classvaluationschar = mat3060_s-classvaluationschar[]
        classvaluationscurr = mat3060_s-classvaluationscurr[]
        classvaluationsnum  = mat3060_s-classvaluationsnum[]
        ehsphr              = matmas_ehsphr_t_t[].



    insert lines of idoc_control_t into table et_idoc.
    ev_created_idocs = created_comm_idocs_v.

    " DRFOUT log: MM no. and MES not displayed
    "{
    read table idoc_control_t into data(idoc_control) index 1.
    if sy-subrc eq 0.

      data key type mdg_bs_mat_drf_s_matnr_key.
      data lr_key type ref to mdg_bs_mat_drf_s_matnr_key.
      key-matnr = is_marakey-matnr.
      get reference of key into lr_key.

      call method ms_runtime_param-bal->add_msg_idoc
        exporting
          iv_idoc_number = idoc_control-docnum
          iv_serv_impl   = ms_runtime_param-outb_impl
          ir_object      = lr_key.
    endif.
    "}


  endmethod.


  method send_yp1t_mes_matmas_idoc.
*------------------------------------------------------------------------------------------------*
* Functional Spec: Master MES GNE interface
* Technical Spec: Master MES GNE interface
* Process: Maintain product master data
* History ---------------------------------------------------------------------------------------*
* Date       | Change           | Contributor               | Description
*------------------------------------------------------------------------------------------------*
*------------------------------------------------------------------------------------------------*



    data : created_comm_idocs_v like sy-tabix,
           total_idoc_v         like sy-tabix value 0.

    data : begin of select_mestyp_s,
             mestyp type edmsg-msgtyp,
             dummy  type c,
           end of select_mestyp_s.

    data : idoc_control_s type edidc,
           idoc_control_t type t_edidc
           .
    .
    data  object_id_v    type drf_object_id.


    field-symbols: <marakey_s> type bdimarakey.

    read table ct_idoc_cntrl into idoc_control_s index 1.
    data(rc) = sy-subrc ##needed.
    clear ct_idoc_cntrl.

    call method cl_im_mdg_bs_mat_id_value=>set_called_from_drf. "parameter is set to true to notify in ID/Value mapping that the call comes from DRFOUT


    loop at is_material_data-t_marakey assigning <marakey_s> .
      object_id_v = <marakey_s>-matnr.
      idoc_control_s-mestyp = 'P1T_GNEMES_MATMAS'.
      idoc_control_s-idoctp = 'P1T_MES_MATMAS01'.

      send_yp1t_mat_segments(
      exporting
        is_material_data =   is_material_data  " Structure for storing material segment keys data
        is_marakey       =    <marakey_s> " Transfer structure: MARA key fields
        is_idoc_control  =   idoc_control_s  " Control record (IDoc)
        iv_mesgtype      =   select_mestyp_s-mestyp  " Message Type
        is_bus_sys_tech  = is_bus_sys_tech
      importing
        et_idoc          = idoc_control_t
        ev_created_idocs =   created_comm_idocs_v
        ).

      append lines of idoc_control_t to ct_idoc_cntrl.
      total_idoc_v =  total_idoc_v + created_comm_idocs_v.

      call method me->update_replication_data
        exporting
          iv_object_id   = object_id_v
          it_idoc_result = idoc_control_t
          iv_messagetype = 'MATMAS'
        changing
          ct_obj_rep_sta = ct_obj_rep_sta.


*
    endloop.

  endmethod.                    "send_matmas_idoc


  method update_replication_data.

    data:
          idoc_control_s type edidc.


    field-symbols : <mat_obj_rep_s> type drf_s_obj_rep_sta_attr.

    if iv_messagetype = 'MATMAS'.
**Update replication parameter.
      loop at it_idoc_result into idoc_control_s.
        read table ct_obj_rep_sta assigning <mat_obj_rep_s> with key object_id = iv_object_id.
        data(rc) = sy-subrc ##needed.
        <mat_obj_rep_s>-msg_link    = idoc_control_s-docnum. " msg_link_v.
      endloop.

    endif.
  endmethod.
ENDCLASS.