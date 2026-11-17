CLASS ZCL_DRF_REF_BATCH_OUT DEFINITION
PUBLIC
FINAL
CREATE PUBLIC .

  PUBLIC SECTION.

    INTERFACES if_drf_outbound .

    TYPES:                "
    tt_key_table
    TYPE SORTED TABLE OF Zp_mcn_yp_mcn_flt_laeda
    WITH UNIQUE KEY matnr charg cust_bc_mes_dist laeda .  "of ZP_S_MCN_DRF_BATCH_FILTER  "
    TYPES:
      BEGIN OF ty_plant_range,
        sign   TYPE  sign,
        option TYPE  option,
        low    TYPE  werks_d,
        high   TYPE  werks_d,
      END OF ty_plant_range .
    TYPES:
    tt_plant_range TYPE STANDARD TABLE OF ty_plant_range .
    TYPES:
      BEGIN OF ty_matnr_range,
        sign   TYPE  sign,
        option TYPE  option,
        low    TYPE  matnr,
        high   TYPE  matnr,
      END OF ty_matnr_range .
    TYPES:
    tt_matnr_range TYPE STANDARD TABLE OF ty_matnr_range .
    TYPES:
      BEGIN OF ty_batch_range,
        sign   TYPE  sign,
        option TYPE  option,
        low    TYPE  charg_d,
        high   TYPE  charg_d,
      END OF ty_batch_range .
    TYPES:
    tt_batch_range TYPE STANDARD TABLE OF ty_batch_range .
    TYPES:
    "TT_MCHA_KEY    type standard table of  "ZP_MCN_DRF_MCHA_KEY  with default key.
    tt_mcha_key    TYPE STANDARD TABLE OF mcha_key WITH DEFAULT KEY .
    TYPES:
      BEGIN OF ty_date_range,
        sign   TYPE  sign,
        option TYPE  option,
        low    TYPE  dats,
        high   TYPE  dats,
      END OF ty_date_range .
    TYPES:
    tt_date_range TYPE STANDARD TABLE OF ty_date_range .

    CONSTANTS c_clasnum_01 TYPE klasse_d VALUE 'cust_bm_PRODUCT' .
    CONSTANTS c_clasnum_02 TYPE klasse_d VALUE 'cust_bm_INTRAMATERIALS' .
    CONSTANTS c_clasnum_03 TYPE klasse_d VALUE 'cust_bm_TANK'.

    "
    CONSTANTS c_clasnum_04 TYPE klasse_d VALUE 'cust_bm_API_BIOLOGICS' .   " BM interface classes
    CONSTANTS c_clasnum_05 TYPE klasse_d VALUE 'cust_bm_USED_RESIN' .      " BM interface classes
    CONSTANTS c_clasnum_06 TYPE klasse_d VALUE 'cust_bm_USED_CARTRIDGE'.   " BM interface classes
    "


    CONSTANTS c_logsys_default TYPE logsys VALUE 'MULESOFT' .
    "
    "constants C_cust_bc_MES_DIST type ATNAM value 'cust_bc_MES_DIST' ##NO_TEXT.
    CONSTANTS c_cust_bc_mes_dist TYPE atnam VALUE 'MES_SYS_DISTRIBUTION' .

    METHODS diag
      EXPORTING
        VALUE(e_ex_text_long) TYPE string
        VALUE(e_ex_text)      TYPE string
        VALUE(e_rc)           TYPE sysubrc .
    METHODS business_sys_to_logsys
      IMPORTING
        VALUE(iv_business_system) TYPE mdg_business_system OPTIONAL
      RETURNING
        VALUE(rv_logsys)          TYPE logsys .
    METHODS business_sys_to_cust_bc_mes_dist
      IMPORTING
        VALUE(iv_business_system) TYPE mdg_business_system OPTIONAL
      RETURNING
        VALUE(rv_cust_bc_mes_dist)    TYPE Zp_mcn_cust_bc_mes_dist .
    METHODS constructor .
PRIVATE SECTION.

  TYPES:
*  types:
*    begin of TY_SEGMENT,
*      MATNR    type MATNR,
*      MCHA_TAB type ref to TT_MCHA,
*    end of TY_SEGMENT .
    BEGIN OF t_mdg_bus_sys_tech_logsys,
      business_system	TYPE mdg_business_system,
      bus_sys_id      TYPE mdg_business_system_id,
      logsys          TYPE logsys,
    END OF t_mdg_bus_sys_tech_logsys .
  TYPES:
    tt_mdg_bus_sys_tech TYPE SORTED TABLE OF t_mdg_bus_sys_tech_logsys WITH UNIQUE KEY business_system .
  TYPES:
    BEGIN OF tt_batch_rec,
      matnr            TYPE matnr,
      charg            TYPE charg_d,
      cust_bc_mes_dist     TYPE Zp_mcn_cust_bc_mes_dist,
      cust_bc_canc_indi(2) TYPE c,
    END OF tt_batch_rec .
  TYPES:
*    types:
    "BD11_FLAG TYPE C,
*      begin of TY_BD11_OBJECT,
*        OBJECT_TYPE type SWOTOBJID-OBJTYPE,
*        OBJECT_KEY  type SWOTOBJID-OBJKEY,
*        LOG_SYSTEM  type SWOTOBJID-LOGSYS,
*        ELEMENT     type SWW_CONTOB-ELEMENT,
*      end of TY_BD11_OBJECT .
    " types:
    "   TY_BD11_OBJECT_TAB type table of TY_BD11_OBJECT .
    BEGIN OF t_batch,
      matnr                TYPE  bapibatchkey-material,
      charg                TYPE  bapibatchkey-batch,
      plant                TYPE  bapibatchkey-plant,
      batchattributes      TYPE  bapibatchatt,
      batchattributesx     TYPE  bapibatchattx,
      batchstatus          TYPE  bapibatchstatus,
      batchstatusx         TYPE  bapibatchstatusx,
      batchcontrolfields   TYPE  bapibatchctrl,
      batchstoragelocation TYPE  bapibatchstoloc-stge_loc,
      internalnumbercom    TYPE  bapibncom,
      extension1           TYPE  bapibncomz,
      materialevg          TYPE  bapimgvmatnr,
      materiallong         TYPE  bapibatchkey-material_long,
      serial_id            TYPE  serial-chnum,
      classallocations     TYPE  bapi3060_allocations,
      classvaluationschar  TYPE  bapi3060_valuations_char,
      classvaluationscurr  TYPE  bapi3060_valuations_curr,
      classvaluationsnum   TYPE  bapi3060_valuations_num,
    END OF t_batch .
  TYPES:
    tt_batch TYPE TABLE OF t_batch WITH KEY matnr charg .

  DATA rc TYPE sysubrc .
  DATA logsys_default TYPE logsys .
  CONSTANTS c_logsys_default_parameter_id TYPE Zs_efr_filter_value VALUE 'LOGSYS_DEFAULT' ##NO_TEXT.
  CONSTANTS c_application_id TYPE Zs_efr_app_id VALUE 'ZP_MES' ##NO_TEXT.
  DATA:
    batch_rec TYPE TABLE OF  tt_batch_rec .
  DATA bapicharactvaldescr_mes_dis TYPE tt_bapicharactvaluesdescr .
  DATA mdg_bus_sys_tech_logsys TYPE tt_mdg_bus_sys_tech .
  "    data KZDCH_V type KZDCH .
  DATA ms_runtime_parameter_ext TYPE drf_s_runtime_parameter_ext .
  DATA o_batch_filter TYPE REF TO if_drf_filter .
  DATA charactreristics TYPE tt_bapi1003_charact_r .
  CLASS-DATA o_drf_mes_batch_out TYPE REF TO ZCL_DRF_REF_BATCH_OUT .
  CLASS-DATA gc_mes_batch_key_structure TYPE string VALUE 'ZCL_DRF_REF_BATCH_OUT=>tt_key_table' ##NO_TEXT.
  "data LO_CL_LOBM_INIT_TRANSFER type ref to ZCL_P_MCN_DRF_ALE_TRANSFER .         "
  DATA iv_logsys TYPE logsys .
  DATA batches TYPE tt_batch .
  DATA class_characteristics TYPE tt_bapi1003_charact_r .
  DATA ex_object_cx_root TYPE REF TO cx_root .
  DATA ex_text TYPE string .
  DATA ex_text_long TYPE string .
  DATA obj_type TYPE serial-obj_type VALUE 'BUS1001002' ##NO_TEXT.
  DATA idoc_data TYPE edidd_tt .
  DATA created_idocs_additional TYPE edidc_tt .
  DATA idoc_control TYPE bdicontrol .

  "{
"  DATA leadingzero_mbrsh_r  TYPE RANGE OF mbrsh.
"  DATA leadingzero_mtart_r TYPE RANGE OF mtart.
  "

  METHODS get_batch_filter
    RETURNING
      VALUE(ro_batch_filter) TYPE REF TO if_drf_filter .
  METHODS convert_timestamp
    CHANGING
      !c_time TYPE uzeit
      !c_date TYPE datum .
ENDCLASS.



CLASS ZCL_DRF_REF_BATCH_OUT IMPLEMENTATION.


  METHOD business_sys_to_logsys.
*----------------------------------------------------------------------*
* Functional Spec: master MES interface
* Technical Spec: master MES interface
* Process: Create Batch Number
*                         S4 Batch master MES interface
* History -------------------------------------------------------------*
* Date       | Change              | Contributor     | Description
*----------------------------------------------------------------------*
*----------------------------------------------------------------------*


    IF mdg_bus_sys_tech_logsys[] IS INITIAL.
      SELECT business_system ,  logsys
      "FROM mdg_bus_sys_tech
      FROM Zp_mcn_mdg_bus_sys_tech "
      WHERE disabled IS INITIAL
      INTO CORRESPONDING FIELDS OF TABLE @mdg_bus_sys_tech_logsys
      .
      IF sy-subrc NE 0.
        MESSAGE ID sy-msgid TYPE sy-msgty NUMBER sy-msgno
        WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4.
      ENDIF.
    ENDIF.


    TRY.
        rv_logsys = mdg_bus_sys_tech_logsys[ business_system = iv_business_system ]-logsys.

      CATCH cx_sy_itab_line_not_found.
        MESSAGE ID sy-msgid TYPE sy-msgty NUMBER sy-msgno
        WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4.
    ENDTRY.

    IF   rv_logsys IS INITIAL.
      rv_logsys = logsys_default.  " ZCL_S_EFR=>GET_PARAMETER_VALUE( exporting  I_PARAMETER_ID = C_LOGSYS_DEFAULT_PARAMETER_ID .

    IF   rv_logsys IS INITIAL.
      rv_logsys = c_logsys_default.
    ENDIF.

  ENDMETHOD.


  METHOD business_sys_to_cust_bc_mes_dist.
*----------------------------------------------------------------------*
* Functional Spec: master MES interface
* Technical Spec: master MES interface
* Process: Create Batch Number
*                         S4 Batch master MES interface
* History -------------------------------------------------------------*
* Date       | Change              | Contributor     | Description
*----------------------------------------------------------------------*
*----------------------------------------------------------------------*


    rv_cust_bc_mes_dist = iv_business_system.

    DATA return_t TYPE bapiret2_tab.

    IF  bapicharactvaldescr_mes_dis IS INITIAL.
      CALL FUNCTION 'BAPI_CHARACT_GETDETAIL'
        EXPORTING
          charactname        = c_cust_bc_mes_dist
          keydate            = sy-datum
          language           = 'E'
        TABLES
          charactvaluesdescr = bapicharactvaldescr_mes_dis
          return             = return_t.
    ENDIF.

    READ TABLE bapicharactvaldescr_mes_dis WITH KEY value_char = iv_business_system(30) INTO DATA(charactvalues_s).
    IF sy-subrc EQ 0.
      rv_cust_bc_mes_dist = charactvalues_s-value_char.
    ELSE.
      READ TABLE bapicharactvaldescr_mes_dis WITH KEY description = iv_business_system  INTO charactvalues_s.
      IF sy-subrc EQ 0.
        rv_cust_bc_mes_dist = charactvalues_s-value_char.
      ELSE.
        "to do ignore
        rv_cust_bc_mes_dist = iv_business_system.
      ENDIF.
    ENDIF.

  ENDMETHOD.


  METHOD constructor.
*-----------------------------------------------------------------------------------------------*
* Functional Spec: master MES interface
* Technical Spec: master MES interface
* Process: Create Batch Number
*                         S4 Batch master MES interface
* History --------------------------------------------------------------------------------------*
* Date       | Change              | Contributor     | Description
*-----------------------------------------------------------------------------------------------*
*-----------------------------------------------------------------------------------------------*


    TRY.
        CALL FUNCTION 'BAPI_CLASS_GETDETAIL'
          EXPORTING
            classtype            = '023'
            classnum             = c_clasnum_01 "'cust_bm_PRODUCT'
          TABLES
            classcharacteristics = class_characteristics.

        LOOP AT class_characteristics ASSIGNING FIELD-SYMBOL(<class_charactreristic>).
          <class_charactreristic>-class_num = c_clasnum_01.
        ENDLOOP.

        APPEND LINES OF class_characteristics TO charactreristics.

      CATCH cx_root INTO ex_object_cx_root.
        ex_text = ex_object_cx_root->get_text( ).
        ex_text_long = ex_object_cx_root->get_longtext( ).

    ENDTRY.

    TRY.
        CALL FUNCTION 'BAPI_CLASS_GETDETAIL'
          EXPORTING
            classtype            = '023'
            classnum             = c_clasnum_02 "'cust_bm_INTRAMATERIALS'
          TABLES
            classcharacteristics = class_characteristics.

        LOOP AT class_characteristics ASSIGNING <class_charactreristic>.
          <class_charactreristic>-class_num = c_clasnum_02.
        ENDLOOP.


        APPEND LINES OF class_characteristics TO charactreristics.
        SORT  charactreristics BY name_char department_view class_num.
        DELETE ADJACENT DUPLICATES FROM  charactreristics COMPARING name_char department_view class_num.



      CATCH cx_root INTO ex_object_cx_root.
        ex_text = ex_object_cx_root->get_text( ).
        ex_text_long = ex_object_cx_root->get_longtext( ).

    ENDTRY.

    TRY. "          |     | Minor corrections
        CALL FUNCTION 'BAPI_CLASS_GETDETAIL'
          EXPORTING
            classtype            = '023'
            classnum             = c_clasnum_03 "'cust_bm_TANK'
          TABLES
            classcharacteristics = class_characteristics.

        LOOP AT class_characteristics ASSIGNING <class_charactreristic>.
          <class_charactreristic>-class_num = c_clasnum_03.
        ENDLOOP.

        APPEND LINES OF class_characteristics TO charactreristics.
        SORT  charactreristics BY name_char department_view class_num.
        DELETE ADJACENT DUPLICATES FROM  charactreristics COMPARING name_char department_view class_num.

      CATCH cx_root INTO ex_object_cx_root.
        ex_text = ex_object_cx_root->get_text( ).
        ex_text_long = ex_object_cx_root->get_longtext( ).
    ENDTRY.

    "  BM interface classes
    TRY.
        CALL FUNCTION 'BAPI_CLASS_GETDETAIL'
          EXPORTING
            classtype            = '023'
            classnum             = c_clasnum_04 "'cust_bm_API_BIOLOGICS
          TABLES
            classcharacteristics = class_characteristics.

        LOOP AT class_characteristics ASSIGNING <class_charactreristic>.
          <class_charactreristic>-class_num = c_clasnum_04.
        ENDLOOP.

        APPEND LINES OF class_characteristics TO charactreristics.
        SORT  charactreristics BY name_char department_view class_num.
        DELETE ADJACENT DUPLICATES FROM  charactreristics COMPARING name_char department_view class_num.

      CATCH cx_root INTO ex_object_cx_root.
        ex_text = ex_object_cx_root->get_text( ).
        ex_text_long = ex_object_cx_root->get_longtext( ).
    ENDTRY.

    TRY.
        CALL FUNCTION 'BAPI_CLASS_GETDETAIL'
          EXPORTING
            classtype            = '023'
            classnum             = c_clasnum_05 "cust_bm_USED_RESIN
          TABLES
            classcharacteristics = class_characteristics.

        LOOP AT class_characteristics ASSIGNING <class_charactreristic>.
          <class_charactreristic>-class_num = c_clasnum_05.
        ENDLOOP.

        APPEND LINES OF class_characteristics TO charactreristics.
        SORT  charactreristics BY name_char department_view class_num.
        DELETE ADJACENT DUPLICATES FROM  charactreristics COMPARING name_char department_view class_num.

      CATCH cx_root INTO ex_object_cx_root.
        ex_text = ex_object_cx_root->get_text( ).
        ex_text_long = ex_object_cx_root->get_longtext( ).
    ENDTRY.

    TRY.
        CALL FUNCTION 'BAPI_CLASS_GETDETAIL'
          EXPORTING
            classtype            = '023'
            classnum             = c_clasnum_06 "'cust_bm_USED_CARTRIDGE
          TABLES
            classcharacteristics = class_characteristics.

        LOOP AT class_characteristics ASSIGNING <class_charactreristic>.
          <class_charactreristic>-class_num = c_clasnum_06.
        ENDLOOP.

        APPEND LINES OF class_characteristics TO charactreristics.
        SORT  charactreristics BY name_char department_view class_num.
        DELETE ADJACENT DUPLICATES FROM  charactreristics COMPARING name_char department_view class_num.

      CATCH cx_root INTO ex_object_cx_root.
        ex_text = ex_object_cx_root->get_text( ).
        ex_text_long = ex_object_cx_root->get_longtext( ).
    ENDTRY.







    "}  BM interface classes
    TRY.
        DATA(application_object) = Zcl_s_efr=>factory( i_application_id = c_application_id ).
        DATA: l_result_value TYPE Zs_efr_parameter_value.
        application_object->get_parameter_value( EXPORTING
          i_parameter_id = c_logsys_default_parameter_id
        CHANGING
          c_parameter_value = l_result_value ).

        logsys_default = l_result_value.
      CATCH Zcx_s_efr INTO DATA(exception_ref).
        MESSAGE exception_ref TYPE 'I' DISPLAY LIKE exception_ref->message_type.
        RETURN.
    ENDTRY.





  ENDMETHOD.


  METHOD convert_timestamp.
************************************************************************
* Functional Spec: Process Order MES interface                *
* Design Spec    : Process Order MES interface                *
* Process        : Process Order MES interface                         *
* History -------------------------------------------------------------*
* Date       | Change      | Contributor | Description                 *
*----------------------------------------------------------------------*
*----------------------------------------------------------------------*

    DATA: time_stamp_utc TYPE timestamp.

    IF c_time = '240000'.
      CLEAR c_time.
      IF NOT c_date IS INITIAL.
        c_date = c_date + 1.
      ENDIF.
    ENDIF.

    CONVERT DATE c_date TIME c_time INTO TIME STAMP time_stamp_utc TIME ZONE 'CET'.
    rc = sy-subrc.
    CONVERT TIME STAMP time_stamp_utc TIME ZONE 'UTC' INTO DATE DATA(date1) TIME DATA(time1).

    IF rc EQ 0 AND sy-subrc EQ 0.
      c_date = date1.
      c_time = time1.
    ENDIF.
  ENDMETHOD.


  METHOD diag.
    e_ex_text_long = ex_text_long.
    e_ex_text = ex_text.
    e_rc = rc.

  ENDMETHOD.


  METHOD get_batch_filter.
*----------------------------------------------------------------------*
* Functional Spec: master MES interface
* Technical Spec: master MES interface
* Process: Create Batch Number
*                         S4 Batch master MES interface
* History -------------------------------------------------------------*
* Date       | Change              | Contributor     | Description
*----------------------------------------------------------------------*
*----------------------------------------------------------------------*


    IF o_batch_filter IS NOT BOUND.
      o_batch_filter = NEW Zcl_p_mcn_drf_batch_fltr( ).
    ENDIF.

    ro_batch_filter = o_batch_filter.
  ENDMETHOD.


  METHOD if_drf_outbound~analyze_changes_by_chg_pointer.
*--------------------------------------------------------------------------------------------------------------------*
* Functional Spec: master MES interface
* Technical Spec: master MES interface
* Process: Create Batch Number
*                         S4 Batch master MES interface
* History -----------------------------------------------------------------------------------------------------------*
* Date       | Change              | Contributor     | Description
*--------------------------------------------------------------------------------------------------------------------*
*  1.09.2026 |           |     |ASPIRE HYPERCARE Basel BM slow performan
*--------------------------------------------------------------------------------------------------------------------*

    "CL_MDG_BS_BP_REL_IDOC_DRF


    DATA change_pointer_t TYPE  bdcp_tab.
    DATA change_pointer_s TYPE bdcp.
    DATA temp_cust_bc_mes_dist TYPE Zp_mcn_cust_bc_mes_dist.
    DATA(business_system)  =  o_drf_mes_batch_out->ms_runtime_parameter_ext-business_system.
    DATA objs_t TYPE TABLE OF Zp_mcn_yp_mcn_flt_laeda.
    DATA mcha_key_s  TYPE Zp_mcn_yp_mcn_flt_laeda.

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
      "select CUOBJ , OBJEK from INOB into table @data(T_OBJEK_ABAUSP) "@data(T_OBJEK_ABAUSP)
      SELECT cuobj , objek FROM Zq_b_mcn_inob INTO TABLE @DATA(t_objek_abausp) "@data(T_OBJEK_ABAUSP)  ALL ENTRIES IN @t_cuobj
            WHERE cuobj = @t_cuobj-table_line.
      IF sy-subrc <> 0.
        MESSAGE ID sy-msgid TYPE sy-msgty NUMBER sy-msgno
        WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4 INTO ex_text.
      ENDIF.
    ENDIF.


    SORT: change_pointer_t ASCENDING BY cdobjcl cdobjid tabname tabkey.                           " 
    DELETE ADJACENT DUPLICATES FROM: change_pointer_t COMPARING cdobjcl cdobjid tabname tabkey.   "



    LOOP AT change_pointer_t ASSIGNING <lc_bdcp>.
      CASE <lc_bdcp>-tabname.
        WHEN 'MCHA'.
          mcha_key_s-matnr = <lc_bdcp>-tabkey+3(40).
          mcha_key_s-charg = <lc_bdcp>-tabkey+47(10).
          mcha_key_s-cust_bc_mes_dist = temp_cust_bc_mes_dist.
          mcha_key_s-laeda = <lc_bdcp>-acttime(8).
          APPEND mcha_key_s TO objs_t.

        WHEN 'ABAUSP'. "Characteristics change
          l_cuobj = <lc_bdcp>-tabkey(18).

          READ TABLE  t_objek_abausp INTO DATA(objek_abausp_s) WITH KEY cuobj = l_cuobj.
          "select single OBJEK from INOB into L_OBJEK where CUOBJ = L_CUOBJ.   "ATC exception raised

          IF sy-subrc EQ 0.
            l_objek =  objek_abausp_s-objek.
            mcha_key_s-matnr = l_objek(39).

            mcha_key_s-charg = l_objek+40(10).
            mcha_key_s-cust_bc_mes_dist = temp_cust_bc_mes_dist.
            mcha_key_s-laeda = <lc_bdcp>-acttime(8).

            l_atinn = <lc_bdcp>-tabkey+18(10).

            CALL FUNCTION 'CONVERSION_EXIT_ATINN_OUTPUT'
              EXPORTING
                input  = l_atinn
              IMPORTING
                output = l_atnam.

            DATA(department_check_v2) = 'X'.


            " SELECT DISTINCT matnr, charg , cust_bc_mes_dist , laeda  " Error with Batch Master Change Pointer
            " FROM Zp_s_mcn_drf_batch_filter
"
*            SELECT DISTINCT matnr , charg  ", cust_bc_mes_dist , laeda  " Error with Batch Master Change Pointer
*              FROM Zp_s_mcn_drf_batch_select
*
*              INTO TABLE @DATA(batch_test_tab) ##NEEDED
*              WHERE matnr = @mcha_key_s-matnr
*              AND charg =  @mcha_key_s-charg
                .

            IF sy-subrc EQ 0.  " Error with Batch Master Change Pointer
              IF department_check_v2 EQ 'X'.
                DATA objecttable_imp     TYPE bapi1003_key-objecttable.
                DATA classtype_imp       TYPE bapi1003_key-classtype.
                DATA  objectkey_imp_long TYPE bapi1003_key-object_long.
                DATA alloclist           TYPE STANDARD TABLE OF bapi1003_alloc_list.
                DATA b2_return           TYPE STANDARD TABLE OF bapiret2.
                objecttable_imp = 'MCH1'.
                classtype_imp = '023'.
                objectkey_imp_long = l_objek.
                DATA(objcl_getclasses_v2) = 'X'. "space.                                   "

                IF  objcl_getclasses_v2 IS INITIAL.                                        "

                  CALL FUNCTION 'BAPI_OBJCL_GETCLASSES'
                    EXPORTING
                      objecttable_imp    = objecttable_imp
                      classtype_imp      = classtype_imp
                      objectkey_imp_long = objectkey_imp_long
                    TABLES
                      alloclist          = alloclist
                      return             = b2_return.


                  LOOP AT alloclist ASSIGNING FIELD-SYMBOL(<alloclist>).
                    READ TABLE  charactreristics WITH KEY name_char =  l_atnam class_num = <alloclist>-classnum INTO DATA(l_charact).
                    IF sy-subrc EQ 0 AND l_charact-department_view CS 'M'.  "reject characteristics change if not in 'M' Org Area
                      APPEND mcha_key_s TO objs_t.
                    ENDIF.
                  ENDLOOP.
                  "{
                ELSE.
                  SELECT  characteristic , charcvalue , clfnobjectid , classtype , charcfromnumericvalue, charctonumericvalue, charcfromnumericvalueunit,
                    charctonumericvalueunit, charcinternalid
                     FROM Zp_s_mcn_batch_characteris INTO TABLE  @DATA(alloclis_v2_t)
                      WHERE batch = @mcha_key_s-charg AND material = @mcha_key_s-matnr.
                  IF sy-subrc EQ 0.
                    LOOP AT alloclis_v2_t  ASSIGNING FIELD-SYMBOL(<alloclist_v2>).
                      READ TABLE  charactreristics WITH KEY name_char =  l_atnam
                         "class_num = <alloclist_v2>-characteristic
                         INTO DATA(l_charact_v2).
                      IF sy-subrc EQ 0 AND l_charact_v2-department_view CS 'M'.  "reject characteristics change if not in 'M' Org Area
                        APPEND mcha_key_s TO objs_t.
                      ENDIF.
                    ENDLOOP.
                  ENDIF.
                ENDIF.                                                                      "
                "}{

              ELSE.
                READ TABLE  charactreristics WITH KEY name_char =  l_atnam INTO l_charact.
                IF sy-subrc EQ 0 AND l_charact-department_view CS 'M'.  "reject characteristics change if not in 'M' Org Area
                  APPEND mcha_key_s TO objs_t.
                ENDIF.
              ENDIF.  "department_check_v2
            ENDIF.  " Error with Batch Master Change Pointer
          ENDIF. "'ABAUSP'. "Characteristics change

        WHEN OTHERS.
          ex_text = <lc_bdcp>-tabname.

      ENDCASE.


    ENDLOOP.


    SORT objs_t BY matnr charg.
    DELETE ADJACENT DUPLICATES FROM objs_t COMPARING  matnr charg.


    IF objs_t[] IS NOT INITIAL.
      SELECT DISTINCT matnr, charg , cust_bc_mes_dist , laeda
      " FROM Zp_s_mcn_drf_batch_filter
       from  Zp_s_mcn_dbatch_mes_distr  "
      INTO TABLE @ct_changed_objects
      FOR ALL ENTRIES IN @objs_t
      WHERE matnr = @objs_t-matnr
      AND charg = @objs_t-charg
      AND cust_bc_mes_dist = @business_system  "
       .
      IF sy-subrc <> 0.
        MESSAGE ID sy-msgid TYPE sy-msgty NUMBER sy-msgno
        WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4 INTO ex_text.
      ENDIF.

    ENDIF.

  ENDMETHOD.


  METHOD if_drf_outbound~analyze_changes_by_mdg_cp.

  ENDMETHOD.


  METHOD if_drf_outbound~analyze_changes_by_others.

  ENDMETHOD.


  METHOD if_drf_outbound~apply_node_inst_filter_multi.
    RETURN.
  ENDMETHOD.


  METHOD if_drf_outbound~apply_node_inst_filter_single.
    RETURN.
  ENDMETHOD.


  METHOD if_drf_outbound~build_parallel_package.
  ENDMETHOD.


  METHOD if_drf_outbound~enrich_filter_criteria.
*----------------------------------------------------------------------*
* Functional Spec: master MES interface
* Technical Spec: master MES interface
* Process: Create Batch Number
*                         S4 Batch master MES interface
* History -------------------------------------------------------------*
* Date       | Change              | Contributor     | Description
*----------------------------------------------------------------------*
*----------------------------------------------------------------------*



    DATA(business_system)  =  o_drf_mes_batch_out->ms_runtime_parameter_ext-business_system.
    DATA temp_cust_bc_mes_dist TYPE Zp_mcn_cust_bc_mes_dist.


    temp_cust_bc_mes_dist = business_sys_to_cust_bc_mes_dist( business_system ).



    DATA: t_selopt   TYPE rsds_selopt_t.


    DATA: wa_selopt   TYPE rsdsselopt,
          wa_selfield TYPE rsds_frange,
          wa_seltab   TYPE rsds_range.

    wa_seltab-tablename   = 'ZP_MCN_YP_MCN_FLT_LAEDA'.
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


  ENDMETHOD.


  METHOD if_drf_outbound~finalize.



  ENDMETHOD.


  METHOD if_drf_outbound~initialize.
*----------------------------------------------------------------------*
* Functional Spec: master MES interface
* Technical Spec: master MES interface
* Process: Create Batch Number
*                         S4 Batch master MES interface
* History -------------------------------------------------------------*
* Date       | Change              | Contributor     | Description
*----------------------------------------------------------------------*
*----------------------------------------------------------------------*



    CREATE OBJECT o_drf_mes_batch_out.
    o_drf_mes_batch_out->ms_runtime_parameter_ext = is_runtime_param.

    es_runtime_param_out_impl-table_type_name =  gc_mes_batch_key_structure.
    eo_if_drf_outbound = o_drf_mes_batch_out.

  ENDMETHOD.


  METHOD if_drf_outbound~map_data2message.
*----------------------------------------------------------------------*
* Functional Spec: master MES interface
* Technical Spec: master MES interface
* Process: Create Batch Number
*                         S4 Batch master MES interface
* History -------------------------------------------------------------*
* Date       | Change              | Contributor     | Description
*----------------------------------------------------------------------*
*----------------------------------------------------------------------*

    DATA(business_system)  =  o_drf_mes_batch_out->ms_runtime_parameter_ext-business_system.

    iv_logsys = business_sys_to_logsys( business_system  ).

    CLEAR: idoc_control.
    CLEAR: idoc_data[].

    FIELD-SYMBOLS <key_s> TYPE Zp_mcn_yp_mcn_flt_laeda.
    ASSIGN ir_relevant_object->* TO <key_s>.
    IF sy-subrc EQ 0.

      READ TABLE batches INTO DATA(batch_s)
            WITH KEY matnr = <key_s>-matnr  charg = <key_s>-charg.

      IF sy-subrc EQ 0.
        batch_s-extension1-business_system = business_system.
*Begin of changes, WI#, TR#D1TK9A2QN3
        DATA(creation_date) = sy-datum.
        DATA(creation_time) = sy-uzeit.
        convert_timestamp( CHANGING c_date =   creation_date
                                    c_time =   creation_time     ).
        batch_s-extension1-credatutc = creation_date.
        batch_s-extension1-cretimutc = creation_time.
*End of changes, WI#, TR#D1TK9A2QN3
        CALL FUNCTION 'ZP_MCN_MAP_DATA2MESSAGE'
          EXPORTING
            material             = <key_s>-matnr
            batch                = <key_s>-charg
            batchattributes      = batch_s-batchattributes
            batchattributesx     = batch_s-batchattributesx
            batchstatus          = batch_s-batchstatus
            batchstatusx         = batch_s-batchstatusx
            batchcontrolfields   = batch_s-batchcontrolfields
            batchstoragelocation = batch_s-batchstoragelocation
            internalnumbercom    = batch_s-internalnumbercom
            extension1           = batch_s-extension1
            materialevg          = batch_s-materialevg
          IMPORTING
            idoc_control         = idoc_control
          TABLES
            classallocations     = batch_s-classallocations[]
            classvaluationschar  = batch_s-classvaluationschar[]
            classvaluationscurr  = batch_s-classvaluationscurr[]
            classvaluationsnum   = batch_s-classvaluationsnum[]
            idoc_data            = idoc_data
            "CREATED_IDOCS        = CREATED_IDOCS
          EXCEPTIONS
            error_creating_idocs = 1
            OTHERS               = 2.
        IF sy-subrc <> 0.
          MESSAGE ID sy-msgid TYPE sy-msgty NUMBER sy-msgno WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4 INTO ex_text.
        ENDIF.



      ENDIF.
    ENDIF.
    "   endif.

  ENDMETHOD.


  METHOD if_drf_outbound~read_complete_data.
*----------------------------------------------------------------------*
* Functional Spec: master MES interface
* Technical Spec: master MES interface
* Process: Create Batch Number
*                         S4 Batch master MES interface
* History -------------------------------------------------------------*
* Date       | Change              | Contributor     | Description
*----------------------------------------------------------------------*
*----------------------------------------------------------------------*

    IF ms_runtime_parameter_ext-runmod <> if_drf_const=>runmod_bypass_filter.
      "filter class was already called by framework (incl. external criteria)
      "-> no need for filtering again
      " return.
    ELSE.
      DATA(filtered_object_t) = VALUE tt_key_table( ).
      get_batch_filter( )->apply_filter(
      EXPORTING
        iv_appl                 = ms_runtime_parameter_ext-appl
        iv_business_system      = ms_runtime_parameter_ext-business_system
        iv_outb_impl            = ms_runtime_parameter_ext-outb_impl
        iv_runmod               = ms_runtime_parameter_ext-runmod
        io_bal                  = ms_runtime_parameter_ext-bal
        iv_dlmod                = ms_runtime_parameter_ext-dlmod
        it_unfiltered_objects   = ct_relevant_objects
        is_c_fobj               = VALUE #( ) "filter config not available / required
        is_filt                 = VALUE #( ) "filter config not available / required
        it_external_criteria    = VALUE #( ) "must stay empty, stipulated by runmod
      IMPORTING
        et_filtered_objects     = filtered_object_t
        ).
      ct_relevant_objects = filtered_object_t.

    ENDIF.


    DATA batch_s TYPE t_batch.
    DATA return TYPE bapiret2_t.
    DATA(ir_application_log) = o_drf_mes_batch_out->ms_runtime_parameter_ext-bal.



    FIELD-SYMBOLS <relv_obj_s>  TYPE Zp_mcn_yp_mcn_flt_laeda.

    LOOP AT ct_relevant_objects ASSIGNING <relv_obj_s> .
      "CALL FUNCTION 'ZP_MCN_BATCH_READ_DATA'             "
      CALL FUNCTION 'ZP_MCN_BATCH_READ_DATA_V2'           "
        EXPORTING
          material             = <relv_obj_s>-matnr
          batch                = <relv_obj_s>-charg
        IMPORTING
          batchattributes      = batch_s-batchattributes
          batchattributesx     = batch_s-batchattributesx
          batchstatus          = batch_s-batchstatus
          batchstatusx         = batch_s-batchstatusx
          batchcontrolfields   = batch_s-batchcontrolfields
          batchstoragelocation = batch_s-batchstoragelocation
          internalnumbercom    = batch_s-internalnumbercom
          extension1           = batch_s-extension1
          materialevg          = batch_s-materialevg
          materiallong         = batch_s-materiallong
        TABLES
          return               = return
          classallocations     = batch_s-classallocations[]
          classvaluationschar  = batch_s-classvaluationschar[]
          classvaluationscurr  = batch_s-classvaluationscurr[]
          classvaluationsnum   = batch_s-classvaluationsnum[].

      IF sy-subrc NE 0.

        ir_application_log->add_msg(
        iv_msgty = if_drf_const=>msg_type_warning
        iv_msgno = '004'
        iv_msgid = 'ZP_MCN'
        iv_msgv1 = <relv_obj_s>-matnr
        iv_msgv2 = <relv_obj_s>-charg
        iv_msgv3 = space
        "ir_object      =  lr_mcha_key

        ).

      ENDIF.





      batch_s-matnr = <relv_obj_s>-matnr.
      batch_s-charg = <relv_obj_s>-charg.
      APPEND batch_s TO batches.

    ENDLOOP.


  ENDMETHOD.


  METHOD if_drf_outbound~send_message.
*----------------------------------------------------------------------------------------------------------*
* Functional Spec: master MES interface
* Technical Spec: master MES interface
* Process: Create Batch Number
*                         S4 Batch master MES interface
* History -------------------------------------------------------------------------------------------------*
* Date       | Change              | Contributor     | Description
*----------------------------------------------------------------------------------------------------------*
*----------------------------------------------------------------------------------------------------------*




    DATA mcha_key_s  TYPE Zp_mcn_yp_mcn_flt_laeda.
    DATA mcha_key_t  TYPE TABLE OF Zp_mcn_yp_mcn_flt_laeda.
    DATA lr_mcha_key TYPE REF TO Zp_mcn_yp_mcn_flt_laeda.

    DATA(ir_application_log) = o_drf_mes_batch_out->ms_runtime_parameter_ext-bal.
    DATA(business_system)  =  o_drf_mes_batch_out->ms_runtime_parameter_ext-business_system.

    DATA temp_cust_bc_mes_dist TYPE Zp_mcn_cust_bc_mes_dist.
    DATA receivers TYPE TABLE OF  bdi_logsys.

    DATA: idoc_number   TYPE ale_docnum.

    temp_cust_bc_mes_dist = business_sys_to_cust_bc_mes_dist( business_system ).


    LOOP AT ct_obj_rep_sta ASSIGNING FIELD-SYMBOL(<fs_obj_rep_sta>).
      mcha_key_s = <fs_obj_rep_sta>-object_id.
      APPEND mcha_key_s TO mcha_key_t.
    ENDLOOP.


    IF mcha_key_t[] IS NOT INITIAL.
*      SELECT  matnr, charg, cust_bc_mes_dist, cust_bc_canc_indi  FROM  Zp_s_mcn_batch_cust_bm_cl023b
*      FOR ALL ENTRIES IN @mcha_key_t
*      WHERE
*      matnr = @mcha_key_t-matnr
*      AND  charg = @mcha_key_t-charg
*      AND  cust_bc_mes_dist =  @temp_cust_bc_mes_dist
*      " and cust_bc_CANC_INDI is initial
*      INTO CORRESPONDING FIELDS OF TABLE @batch_rec.
*      IF sy-subrc <> 0.
*        MESSAGE ID sy-msgid TYPE sy-msgty NUMBER sy-msgno
*        WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4 INTO ex_text.
*      ENDIF.
      SELECT  matnr, charg, cust_bc_canc_indi
          "FROM  Zp_s_mcn_batch_cust_bm_cl023b          " 
          FROM Zp_s_mcn_dbatch_canc_indi            " 
        FOR ALL ENTRIES IN @mcha_key_t
           WHERE
                matnr = @mcha_key_t-matnr
           AND  charg = @mcha_key_t-charg
           "AND  cust_bc_mes_dist =  @temp_cust_bc_mes_dist  " 
           INTO CORRESPONDING FIELDS OF TABLE @batch_rec.
      " {
      IF sy-subrc NE 0.
        SELECT  matnr, charg, cust_bc_mes_dist
            FROM Zp_s_mcn_dbatch_mes_distr
            FOR ALL ENTRIES IN @mcha_key_t
             WHERE
                     matnr = @mcha_key_t-matnr
                AND  charg = @mcha_key_t-charg
                AND cust_bc_mes_dist =  @temp_cust_bc_mes_dist

          INTO CORRESPONDING FIELDS OF TABLE @batch_rec.
        DATA(rc) = sy-subrc ##needed.
      ENDIF.
      "}  




    ENDIF.



    iv_logsys = business_sys_to_logsys( business_system  ).
    APPEND iv_logsys TO receivers.

    READ TABLE  batch_rec ASSIGNING  FIELD-SYMBOL(<batch_rec>) INDEX 1 .

    IF sy-subrc EQ 0.
      mcha_key_s-matnr = <batch_rec>-matnr.
      mcha_key_s-charg = <batch_rec>-charg.
      GET REFERENCE OF mcha_key_s INTO lr_mcha_key.

      IF ( <batch_rec>-cust_bc_canc_indi NE '01' AND <batch_rec>-cust_bc_canc_indi NE '02' AND <batch_rec>-cust_bc_canc_indi NE '03' ).

        "{
        "        DATA l_mara TYPE mara.
        DATA e1batmas TYPE e1batmas.

        READ TABLE idoc_data ASSIGNING FIELD-SYMBOL(<segment>) WITH  KEY segnam = 'E1BATMAS'.
        IF sy-subrc EQ 0.
          e1batmas =  <segment>-sdata.
          CALL FUNCTION 'CONVERSION_EXIT_MATN1_OUTPUT'  "cause AIF index
            EXPORTING
              input  = e1batmas-material_long
            IMPORTING
              output = e1batmas-material_long
            EXCEPTIONS
              " length_error = 1
              OTHERS = 2.
          DATA(rc_i0002c) = sy-subrc ##needed.

          e1batmas-material =   e1batmas-material_long.
          <segment>-sdata = e1batmas.
        ENDIF.
        "}

        TRY.
            CALL FUNCTION 'ALE_IDOCS_CREATE'
              EXPORTING
                idoc_control                = idoc_control
                obj_type                    = obj_type
              TABLES
                idoc_data                   = idoc_data
                receivers                   = receivers
                created_idocs_additional    = created_idocs_additional
              EXCEPTIONS
                idoc_input_was_inconsistent = 1
                OTHERS                      = 2.
            IF sy-subrc <> 0.
              MESSAGE ID sy-msgid TYPE sy-msgty NUMBER sy-msgno
              WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4 INTO ex_text.

            ENDIF.


            LOOP AT created_idocs_additional ASSIGNING FIELD-SYMBOL(<ale_idoc_status>).
              idoc_number =  CONV edi_docnum( <ale_idoc_status>-docnum ).
              ir_application_log->add_msg_idoc( EXPORTING iv_idoc_number = idoc_number
                iv_serv_impl   = o_drf_mes_batch_out->ms_runtime_parameter_ext-outb_impl
                ir_object      =  lr_mcha_key
                ) .
            ENDLOOP.
            CLEAR created_idocs_additional[].

          CATCH cx_root INTO ex_object_cx_root.
            ex_text = ex_object_cx_root->get_text( ).
            ex_text_long = ex_object_cx_root->get_longtext( ).
        ENDTRY.

      ELSE.

        ir_application_log->add_msg(
        iv_msgty = if_drf_const=>msg_type_warning
        iv_msgno = '012'
        iv_msgid = 'ZP_MCN'
        iv_msgv1 = <batch_rec>-matnr
        iv_msgv2 = <batch_rec>-charg
        iv_msgv3 = <batch_rec>-cust_bc_canc_indi
        ir_object      =  lr_mcha_key

        ).
      ENDIF.
    ENDIF.
  ENDMETHOD.
ENDCLASS.