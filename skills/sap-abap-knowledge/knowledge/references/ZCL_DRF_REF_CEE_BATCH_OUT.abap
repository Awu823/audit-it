class ZCL_DRF_REF_CEE_BATCH_OUT definition
  public
  final
  create public .

public section.

  interfaces IF_DRF_OUTBOUND .

  types:                    "
    tt_key_table
      TYPE SORTED TABLE OF Zv_cee_drf_batch
      WITH UNIQUE KEY matnr charg werks lgort mtart .
  types:
    BEGIN OF ty_plant_range,
        sign   TYPE  sign,
        option TYPE  option,
        low    TYPE  werks_d,
        high   TYPE  werks_d,
      END OF ty_plant_range .
  types:
    tt_plant_range TYPE STANDARD TABLE OF ty_plant_range .
  types:
    BEGIN OF ty_matnr_range,
        sign   TYPE  sign,
        option TYPE  option,
        low    TYPE  matnr,
        high   TYPE  matnr,
      END OF ty_matnr_range .
  types:
    tt_matnr_range TYPE STANDARD TABLE OF ty_matnr_range .
  types:
    BEGIN OF ty_batch_range,
        sign   TYPE  sign,
        option TYPE  option,
        low    TYPE  charg_d,
        high   TYPE  charg_d,
      END OF ty_batch_range .
  types:
    tt_batch_range TYPE STANDARD TABLE OF ty_batch_range .
  types:
      "TT_MCHA_KEY    type standard table of  "ZP_MCN_DRF_MCHA_KEY  with default key.
    tt_mcha_key    TYPE STANDARD TABLE OF mcha_key WITH DEFAULT KEY .
  types:
    BEGIN OF ty_date_range,
        sign   TYPE  sign,
        option TYPE  option,
        low    TYPE  dats,
        high   TYPE  dats,
      END OF ty_date_range .
  types:
    tt_date_range TYPE STANDARD TABLE OF ty_date_range .

  constants C_CLASNUM_01 type KLASSE_D value 'cust_bm_PRODUCT' ##NO_TEXT.
  constants C_CLASNUM_02 type KLASSE_D value 'cust_bm_INTRAMATERIALS' ##NO_TEXT.
  constants C_CLASNUM_03 type KLASSE_D value 'cust_bm_TANK' ##NO_TEXT.
    "
  constants C_CLASNUM_04 type KLASSE_D value 'cust_bm_API_BIOLOGICS' ##NO_TEXT.   " BM interface classes
  constants C_CLASNUM_05 type KLASSE_D value 'cust_bm_USED_RESIN' ##NO_TEXT.   " BM interface classes
  constants C_CLASNUM_06 type KLASSE_D value 'cust_bm_USED_CARTRIDGE' ##NO_TEXT.   " BM interface classes
    "
  constants C_LOGSYS_DEFAULT type LOGSYS value 'MULESOFT' ##NO_TEXT.
    "
    "constants C_cust_bc_MES_DIST type ATNAM value 'cust_bc_MES_DIST' ##NO_TEXT.
  constants C_cust_bc_MES_DIST type ATNAM value 'MES_SYS_DISTRIBUTION' ##NO_TEXT.
PRIVATE SECTION.

  DATA ms_runtime_parameter_ext TYPE drf_s_runtime_parameter_ext .
  CLASS-DATA o_drf_batch_out TYPE REF TO ZCL_DRF_REF_CEE_BATCH_OUT .
  CLASS-DATA gc_batch_key_structure TYPE string VALUE 'ZCL_DRF_REF_CEE_BATCH_OUT=>tt_key_table' ##NO_TEXT.
ENDCLASS.



CLASS ZCL_DRF_REF_CEE_BATCH_OUT IMPLEMENTATION.


  METHOD if_drf_outbound~analyze_changes_by_chg_pointer.
*----------------------------------------------------------------------*
* Functional Spec: CWP_Material Master Data Transfer_S4H
* Technical Spec: CWP_Material Master Data Transfer_S4H
* Process: Mantains product master data
* History -------------------------------------------------------------*
* Date       | Change              | Contributor     | Description
*----------------------------------------------------------------------*
*----------------------------------------------------------------------*
*----------------------------------------------------------------------*


    TYPES: BEGIN OF ty_cp_entries,
             matnr TYPE matnr,
             werks TYPE werks_d,
             charg TYPE charg_d,
             lgort TYPE lgort_d,
           END OF ty_cp_entries,
           ty_tt_cp_entries TYPE STANDARD TABLE OF ty_cp_entries WITH DEFAULT KEY,
           BEGIN OF ty_cd_batch,
             matnr   TYPE matnr,
             werks   TYPE werks_d,
             charg   TYPE charg_d,
             flag(1) TYPE c,
           END OF ty_cd_batch.

    DATA: cp_entries   TYPE ty_tt_cp_entries,
          cp_entry     TYPE ty_cp_entries,
          cp_key_struc TYPE ty_cd_batch.

*   Extract key fields from selected change pointers data, to obtain affected batches to be exported
    LOOP AT it_change_pointer ASSIGNING FIELD-SYMBOL(<mdg_cp>) WHERE cdchgid = 'I' OR cdchgid = 'U'.

      cp_key_struc = <mdg_cp>-cdobjid.

      CLEAR cp_entry.

      cp_entry-matnr = cp_key_struc-matnr.
      cp_entry-charg = cp_key_struc-charg.

      IF cp_entry IS NOT INITIAL.

        INSERT cp_entry INTO TABLE cp_entries.

      ENDIF.

    ENDLOOP.

*   If there is data coming from a change pointer, select master data for those batches complying with it, otherwise no data is selected
    IF cp_entries[] IS NOT INITIAL.

*     Proceed with the selection
      SELECT matnr, charg, werks, storagelocation, materialtype
      FROM Zs_b_mcha AS mcha INNER JOIN i_physinvtryindbatchstorloc AS mchb ON mcha~matnr = mchb~material AND
                                                                                   mcha~werks = mchb~plant AND
                                                                                   mcha~charg = mchb~batch
                                 INNER JOIN i_material AS mat                   ON mat~material = mcha~matnr
      INTO TABLE @ct_changed_objects
      FOR ALL ENTRIES IN @cp_entries
      WHERE matnr = @cp_entries-matnr AND
            charg  = @cp_entries-charg.
      IF sy-subrc <> 0.

        CLEAR ct_changed_objects.

      ENDIF.

    ENDIF.

  ENDMETHOD.


  METHOD if_drf_outbound~analyze_changes_by_mdg_cp.

  ENDMETHOD.


  METHOD IF_DRF_OUTBOUND~ANALYZE_CHANGES_BY_OTHERS.

  ENDMETHOD.


  METHOD IF_DRF_OUTBOUND~APPLY_NODE_INST_FILTER_MULTI.
    RETURN.
  ENDMETHOD.


  METHOD IF_DRF_OUTBOUND~APPLY_NODE_INST_FILTER_SINGLE.
    RETURN.
  ENDMETHOD.


  METHOD IF_DRF_OUTBOUND~BUILD_PARALLEL_PACKAGE.
  ENDMETHOD.


  METHOD IF_DRF_OUTBOUND~ENRICH_FILTER_CRITERIA.


  ENDMETHOD.


  METHOD IF_DRF_OUTBOUND~FINALIZE.



  ENDMETHOD.


  METHOD IF_DRF_OUTBOUND~INITIALIZE.
*----------------------------------------------------------------------*
* Functional Spec: CWP_Material Master Data Transfer_S4H
* Technical Spec: CWP_Material Master Data Transfer_S4H
* Process: Mantains product master data
* History -------------------------------------------------------------*
* Date       | Change              | Contributor     | Description
*----------------------------------------------------------------------*
*----------------------------------------------------------------------*


    CREATE OBJECT o_drf_batch_out.
    o_drf_batch_out->ms_runtime_parameter_ext = is_runtime_param.

    es_runtime_param_out_impl-table_type_name =  gc_batch_key_structure.
    eo_if_drf_outbound = o_drf_batch_out.

  ENDMETHOD.


  METHOD IF_DRF_OUTBOUND~MAP_DATA2MESSAGE.

  ENDMETHOD.


  METHOD IF_DRF_OUTBOUND~READ_COMPLETE_DATA.

  ENDMETHOD.


  METHOD if_drf_outbound~send_message.
*----------------------------------------------------------------------*
* Functional Spec: CWP_Material Master Data Transfer_S4H
* Technical Spec: CWP_Material Master Data Transfer_S4H
* Process: Mantains product master data
* History -------------------------------------------------------------*
* Date       | Change              | Contributor     | Description
*----------------------------------------------------------------------*
*----------------------------------------------------------------------*

    CONSTANTS c_xfields(33) TYPE c VALUE 'XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX'.

    DATA: recipient_table      TYPE STANDARD TABLE OF bdi_logsys WITH DEFAULT KEY,
          mcha_e               TYPE mcha,
          batchattributes      TYPE bapibatchatt,
          batchattributesx     TYPE bapibatchattx,
          batchstatus          TYPE bapibatchstatus,
          batchstatusx         TYPE bapibatchstatusx,
          created_idocs        TYPE STANDARD TABLE OF swotobjid WITH DEFAULT KEY,
          batchstoragelocation TYPE bapibatchstoloc-stge_loc.

*   Only one destination system per call expected
    IF ct_obj_rep_sta[] IS NOT INITIAL.

      INSERT VALUE #( logsys = ct_obj_rep_sta[ 1 ]-business_system ) INTO TABLE recipient_table.

      LOOP AT ct_obj_rep_sta ASSIGNING FIELD-SYMBOL(<object>).

        DATA(key) = CONV Zv_cee_drf_batch( <object>-object_id ).

        CALL FUNCTION 'VB_BATCH_GET_DETAIL'
          EXPORTING
            matnr              = key-matnr
            charg              = key-charg
            werks              = key-werks
            read_from_buffer   = 'X'
          IMPORTING
            ymcha              = mcha_e
          EXCEPTIONS
            no_material        = 1
            no_batch           = 2
            no_plant           = 3
            material_not_found = 4
            plant_not_found    = 5
            no_authority       = 6
            batch_not_exist    = 7
            OTHERS             = 8.
        IF sy-subrc = 0.

          CALL FUNCTION 'MAP2E_MCHA_TO_BAPIBATCHATT'
            EXPORTING
              mcha         = mcha_e
            CHANGING
              bapibatchatt = batchattributes.

          batchattributesx = c_xfields.
          batchstatus      = mcha_e-zustd.
          batchstatusx     = c_xfields.
          batchstoragelocation = key-lgort.

          CALL FUNCTION 'ALE_BATCH_SAVE_REPLICA'
            EXPORTING
              materiallong            = key-matnr
              batch                   = key-charg
              plant                   = key-werks
              batchattributes         = batchattributes
              batchattributesx        = batchattributesx
              batchstatus             = batchstatus
              batchstatusx            = batchstatusx
              batchstoragelocation    = batchstoragelocation
            TABLES
              receivers               = recipient_table
              communication_documents = created_idocs
            EXCEPTIONS
              error_creating_idocs    = 1
              OTHERS                  = 2.
          IF sy-subrc = 0.

            LOOP AT created_idocs ASSIGNING FIELD-SYMBOL(<created_idoc>).

              DATA(application_log) = o_drf_batch_out->ms_runtime_parameter_ext-bal.

              application_log->add_msg_idoc( EXPORTING iv_idoc_number = CONV ale_docnum( <created_idoc>-objkey )
                                                       iv_serv_impl   = o_drf_batch_out->ms_runtime_parameter_ext-outb_impl
                                                       ir_object      = REF #( key ) ).

            ENDLOOP.

          ENDIF.

        ENDIF.

      ENDLOOP.

    ENDIF.

  ENDMETHOD.
ENDCLASS.