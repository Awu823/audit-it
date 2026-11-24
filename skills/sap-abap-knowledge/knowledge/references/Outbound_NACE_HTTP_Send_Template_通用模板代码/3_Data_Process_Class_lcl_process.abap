*&---------------------------------------------------------------------*
*& Include          Z_YOUR_PROGRAM_CI1
*&---------------------------------------------------------------------*
* Design Spec     : Z_YOUR_DESIGN_SPEC
* Functional Spec : Z_YOUR_FUNCTIONAL_SPEC
* Process         : Perform Your Outbound Process
* History -------------------------------------------------------------*
* Date       | Change    | Contrib. | Description
*----------------------------------------------------------------------*
* 01.01.2026 |0000000000 |          | Initial version
*&---------------------------------------------------------------------*
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*
CLASS lcl_process DEFINITION.
  PUBLIC SECTION.
*    CONSTANTS lang TYPE spras VALUE 'E'.
*    CONSTANTS parvw TYPE parvw VALUE 'WE'.

    METHODS:
      constructor IMPORTING i_screen TYPE char1,

      fetch_form_data IMPORTING document      TYPE  vbeln_vl "lips-vbeln"
                      EXPORTING e_item_data   TYPE z_your_item_tab
                                e_header_data TYPE z_your_header_st
                                e_signature   TYPE z_your_footer_st
                                e_section2    TYPE z_your_sec2_st
                                e_form_name   TYPE text255,




      generate_form IMPORTING i_item_data     TYPE z_your_item_tab
                              i_header_data   TYPE z_your_header_st
                              i_signature     TYPE z_your_footer_st
                              i_section2      TYPE z_your_sec2_st
                              i_form_name     TYPE text255
                    RETURNING VALUE(r_return) TYPE sysubrc.
*      get_esign.

  PRIVATE SECTION.
    METHODS:

      set_parameters

        CHANGING
          c_outputparams TYPE sfpoutputparams
          c_docparams    TYPE sfpdocparams
          c_device       TYPE output_device,

      protocol_update.
ENDCLASS.
CLASS lcl_process IMPLEMENTATION.
  METHOD constructor.
    g_screen_display = i_screen.
    g_nast   = nast.
  ENDMETHOD.

  METHOD fetch_form_data.

    TRY.
        DATA(application_object) = z_your_efr=>factory( i_application_id = CONV z_your_efr_app-id( g_efr_name ) ).

      CATCH z_cx_your_efr INTO DATA(o_ref).
*        MESSAGE exception_ref TYPE 'I' DISPLAY LIKE exception_ref->message_type.
        DATA(lv_msg)  = o_ref->get_longtext( ) ##NEEDED.
        RETURN.
    ENDTRY.

    DATA(parameter_definition) =  application_object->get_parameter_definition('Z_YOUR_PART_FUN' ).
    DATA(parameter_definition1) = application_object->get_parameter_definition('Z_YOUR_TYPE' ).
    DATA(print_signature) = application_object->get_parameter_definition('PRINT_SIGNATURES' ).

    DATA: form_name           TYPE z_your_efr_param,
          part_function       TYPE z_your_efr_param,
          identification_type TYPE z_your_efr_param,
          print_signatures    TYPE z_your_efr_param.

    "CAPTURING PARTNER_FUNCTION FROM EFR
    TRY.
        application_object->get_parameter_value(
          EXPORTING
            i_parameter_id    = parameter_definition-parameter_id
            i_filter          = 'PARTNER_FUNCTION'
          CHANGING
            c_parameter_value = part_function
             ).

      CATCH z_cx_your_efr INTO o_ref.
        lv_msg  = o_ref->get_longtext( ) ##NEEDED.
        RETURN.
    ENDTRY.

    TRY.
        application_object->get_parameter_value(
          EXPORTING
            i_parameter_id    = parameter_definition1-parameter_id
            i_filter          = 'Type'
          CHANGING
            c_parameter_value = identification_type
             ).
      CATCH z_cx_your_efr INTO o_ref.
        lv_msg  = o_ref->get_longtext( ) ##NEEDED.
        RETURN.
    ENDTRY.

    SELECT SINGLE vbelv  FROM z_your_vbfa
     WHERE vbeln  = @document
     INTO @DATA(sub_seq).
    IF sy-subrc <> 0.
      CLEAR sub_seq.
    ENDIF.


    SELECT  SINGLE SalesOrg, DistrChannel, SoldToParty
      FROM z_your_vbak
      WHERE SalesDocument = @sub_seq
      INTO @DATA(vbak_line).
    IF sy-subrc <> 0.
      CLEAR vbak_line.
    ENDIF.
      g_val = |{ vbak_line-salesorg }/{ vbak_line-soldtoparty }|.
    TRY.
        CALL METHOD application_object->get_parameter_values
          EXPORTING
            i_parameter_id     = 'Z_YOUR_FORM'
          RECEIVING
            r_parameter_values = DATA(form_name_t).

      CATCH z_cx_your_efr INTO o_ref. ""INTO exception_ref.
        lv_msg  = o_ref->get_longtext( ) ##NEEDED.
    ENDTRY.
*  data : form_name type
    READ TABLE form_name_t ASSIGNING FIELD-SYMBOL(<form>) WITH KEY filter = g_val.
    IF sy-subrc = 0.
      form_name = <form>-parameter_value.
    ENDIF.

    IF form_name IS INITIAL.
       g_val = |{ vbak_line-salesorg }|.
         READ TABLE form_name_t ASSIGNING FIELD-SYMBOL(<form2>) WITH KEY filter = g_val.
      IF sy-subrc = 0.
        form_name = <form2>-parameter_value.
      ENDIF.
    ENDIF.


    IF  form_name IS NOT INITIAL.
      e_form_name = form_name.
    ENDIF.

    IF document IS NOT INITIAL.
*      "Header data

      SELECT SINGLE delivery, ReferenceSDDocument , DeliveryItem
        FROM z_your_lips
        INTO @DATA(lips_val)
        WHERE delivery = @document.
      IF sy-subrc <> 0.
        CLEAR lips_val.
      ENDIF.

      SELECT SINGLE Customer_Reference , Your_Reference
        FROM z_your_vbkd
        WHERE Sales_Doc_No = @lips_val-referencesddocument
        INTO @DATA(lw_vbkd).
      IF sy-subrc <> 0.
        CLEAR lw_vbkd.
      ENDIF.
      e_header_data-agreement_no = lw_vbkd-customer_reference.
      e_header_data-title_no = lw_vbkd-Your_Reference.


      SELECT SINGLE delivery_id ,created_by
        FROM z_your_likp
        INTO @DATA(lw_likp)
        WHERE delivery_id   = @lips_val-delivery.
      IF sy-subrc <> 0.
        CLEAR lw_likp.
      ENDIF.
      e_header_data-delivery_note = lw_likp-delivery_id.

      SELECT SINGLE addressid
        FROM z_your_vbpa
        INTO @DATA(lv_adrnr)
        WHERE sddocument  = @lips_val-delivery
        AND partnerfunction = 'WE'.

      IF sy-subrc = 0.
        CALL FUNCTION 'ADDRESS_INTO_PRINTFORM'
          EXPORTING
            address_type                   = addrtype           " Address type: 1,2,3 or ' '(default)
            address_number                 = lv_adrnr            " Address number (data is read directly)
          IMPORTING
            address_not_found              = g_not_found
            address_printform_table        = g_shiptoaddress
          EXCEPTIONS
            address_blocked                = 1                " Address Blocked
            person_blocked                 = 2                " Person Blocked
            contact_person_blocked         = 3                " Contact Person Blocked
            addr_to_be_formated_is_blocked = 4                " Address to be formatted is blocked
            OTHERS                         = 5.         " Formatted address in table form

        IF sy-subrc <> 0 AND g_not_found = abap_true.
          CLEAR g_shiptoaddress.
        ENDIF.

        DATA: first_line TYPE abap_bool.
        IF sy-subrc = 0.
          LOOP AT g_shiptoaddress ASSIGNING FIELD-SYMBOL(<lwa_g_shiptoaddress>).
            IF first_line = abap_false.
              e_header_data-address = <lwa_g_shiptoaddress>-address_line.
              first_line = abap_true.  " Set flag to true after the first iteration
            ELSE.
              " For subsequent address lines, add a comma before the address line
              CONCATENATE e_header_data-address <lwa_g_shiptoaddress>-address_line INTO e_header_data-address SEPARATED BY ', '.
            ENDIF.
          ENDLOOP.
        ENDIF.
      ENDIF.
    ENDIF.

    SELECT SINGLE ReferenceSDDocument FROM z_your_lips
     WHERE Delivery = @document
     INTO @DATA(sales_order).
    IF sy-subrc <> 0.
      CLEAR sales_order.
    ENDIF.

    "  DELIVERY_NUMBER
    CALL FUNCTION 'READ_TEXT'
      EXPORTING
        id                      = 'Z_YOUR_TEXT_1'              " Text ID of text to be read
        language                = g_nast-spras          " Language of text to be read
        name                    = CONV thead-tdname( sales_order )     " Name of text to be read
        object                  = 'Z_YOUR_OBJECT'             " Object of text to be read
      TABLES
        lines                   = g_lines            " Lines of text read
      EXCEPTIONS
        id                      = 1                " Text ID invalid
        language                = 2                " Invalid language
        name                    = 3                " Invalid text name
        not_found               = 4                " Text not found
        object                  = 5                " Invalid text object
        reference_check         = 6                " Reference chain interrupted
        wrong_access_to_archive = 7                " Archive handle invalid for access
        OTHERS                  = 8.

    IF sy-subrc = 0.
      READ TABLE g_lines  INTO DATA(wa_eline) INDEX 1.
      IF sy-subrc = 0.
        e_header_data-delivery_no = wa_eline-tdline.
      ENDIF.
    ENDIF.
    CLEAR g_lines .


    SELECT SINGLE customer,partnerfunction
      FROM z_your_vbpa
       WHERE partnerfunction = @part_function AND
         sddocument = @lips_val-referencesddocument
      INTO @DATA(kunnr_val).
    IF sy-subrc <> 0.
      CLEAR kunnr_val.
    ENDIF.

    SELECT SINGLE Idnumber,Type FROM z_your_but0id
     WHERE partner =  @kunnr_val-customer
     AND Type = @identification_type
     INTO @DATA(patientid).
    IF sy-subrc <> 0.
      CLEAR patientid.
    ENDIF.

    "Correction start BOL FEILD DEFECT
    DATA :
      wa_e1stats TYPE e1stats,
      lv_bol     TYPE string,
      lv_custpo  TYPE string.
    lv_custpo = wa_eline-tdline.
    REPLACE ALL OCCURRENCES OF '/' IN lv_custpo WITH '-'.
    REPLACE ALL OCCURRENCES OF '.' IN lv_custpo WITH '-'.
    SELECT SINGLE Docnum,Refint,Mestyp
       FROM z_your_edidc
      WHERE Refint = @document
      AND Mestyp = 'STATUS'
       INTO @DATA(docum).
    IF sy-subrc = 0.
      SELECT SINGLE IDocnumber,
                     Counter,
                       Segmentnumber,
                       Segmentname,
                       Psegmentnumber,
                       Herarchylevel,
                       Dataaging,
                       Dtint2,
                       Applicationdata FROM z_your_edid4
                               WHERE IDocnumber = @docum-docnum
                              INTO @DATA(bol).
      IF sy-subrc = 0.
        wa_E1STATS = bol-applicationdata.
        lv_bol = wa_e1stats-stapa2.
      ENDIF.
    ENDIF.
    gv_filename = |Z_YOUR_PREFIX_{ lv_custpo }_{ patientid-idnumber }_{ lv_bol }_{ document }_{ g_nast-erdat }{ g_nast-eruhr }.PDF |.

*item_data
    DATA : lv_date       TYPE string,
           wa_item_table TYPE z_your_item_st.

    SELECT a~ReferenceSDDocument,
           a~ActualDeliveryQuantity, a~DeliveryDocumentItemText, a~ShelfLifeExpirationDate, a~batch, a~ReferenceSDDocumentItem,
           b~DocCondition
    FROM   z_your_lips AS a
    INNER JOIN z_your_vbak AS b ON b~SalesDocument = a~referencesddocument
    WHERE a~Delivery = @lips_val-delivery AND batch IS NOT INITIAL
    AND a~delivery            = @document
    AND a~ReferenceSDDocument = @lips_val-referencesddocument
    INTO TABLE @DATA(i_item_tab).
    IF sy-subrc = 0.
      IF i_item_tab IS NOT INITIAL  .
        SELECT doccondition, conditiontype, item ,Amount FROM z_your_prcd_elements INTO TABLE @DATA(lt_prcd) FOR ALL ENTRIES IN @i_item_tab
          WHERE doccondition = @i_item_tab-doccondition AND Item = @i_item_tab-ReferenceSDDocumentItem AND ( Conditiontype = 'ZCPM'
          OR Conditiontype = 'ZCPP' ).
      ENDIF.

      IF sy-subrc = 0.
        SORT i_item_tab BY ReferenceSDDocument ReferenceSDDocumentItem.
        LOOP AT i_item_tab ASSIGNING FIELD-SYMBOL(<inv_item>).
          wa_item_table-size = <inv_item>-deliverydocumentitemtext.
          wa_item_table-quantity = <inv_item>-actualdeliveryquantity.
          wa_item_table-batch = <inv_item>-batch.

          READ TABLE lt_prcd ASSIGNING FIELD-SYMBOL(<ls_prcd>) WITH KEY doccondition = <inv_item>-doccondition
                    item = <inv_item>-ReferenceSDDocumentItem
                    conditiontype = 'ZCPM'.
          IF sy-subrc = 0.
            wa_item_table-price = <ls_prcd>-amount.
          ENDIF.

          READ TABLE lt_prcd ASSIGNING FIELD-SYMBOL(<ls_prcd1>) WITH KEY doccondition = <inv_item>-doccondition
          item = <inv_item>-ReferenceSDDocumentItem
          conditiontype = 'ZCPP'.
          IF sy-subrc = 0.
            wa_item_table-gross_value = <ls_prcd1>-amount.
          ENDIF.
          wa_item_table-gross_value = wa_item_table-gross_value * wa_item_table-quantity.

          DATA(date) = <inv_item>-shelflifeexpirationdate+6(2).
          DATA(lv_month) = <inv_item>-shelflifeexpirationdate+4(2).
          DATA(lv_year) = <inv_item>-shelflifeexpirationdate+0(4).
          lv_date = date && '.' && lv_month && '.' && lv_year.
          wa_item_table-exp_date = lv_date.
          APPEND wa_item_table TO e_item_data.
          CLEAR: <inv_item>, wa_item_table.

        ENDLOOP.
      ENDIF.
    ENDIF.

*    section 2
    IF form_name = 'FORM1'.
      e_section2-delivered = '4'.
      e_section2-received = '0'.
    ELSEIF form_name = 'FORM2'.
      SELECT SINGLE Supplement     "NoofContacts
        FROM z_your_vbak
        WHERE SalesDocument = @lips_val-referencesddocument
        INTO @DATA(section).

      IF sy-subrc = 0.
        e_section2-delivered = section.
        e_section2-received = '0'.

      ENDIF.

      SELECT SINGLE SalesUnit
        FROM z_your_lips_alt
        WHERE Delivery = @lips_val-delivery
         INTO @e_section2-uom.
      IF g_nast-spras = 'L'.
        e_section2-uom = 'Z_UOM'.
      ENDIF.
      IF sy-subrc <> 0.
        CLEAR section.
      ENDIF.
    ENDIF.

    CALL FUNCTION 'READ_TEXT'
      EXPORTING
        id                      = 'Z_YOUR_TEXT_2'              " Text ID of text to be read
        language                = g_nast-spras           " Language of text to be read
        name                    = CONV thead-tdname( lips_val-referencesddocument )   " Name of text to be read
        object                  = 'Z_YOUR_OBJECT'           " Object of text to be read
      TABLES
        lines                   = g_lines          " Lines of text read
      EXCEPTIONS
        id                      = 1                " Text ID invalid
        language                = 2                " Invalid language
        name                    = 3                " Invalid text name
        not_found               = 4                " Text not found
        object                  = 5                " Invalid text object
        reference_check         = 6                " Reference chain interrupted
        wrong_access_to_archive = 7                " Archive handle invalid for access
        OTHERS                  = 8.

    IF sy-subrc = 0.
      READ TABLE g_lines  INTO DATA(lw_lines1) INDEX 1.
      IF sy-subrc = 0.
        e_section2-comments = lw_lines1-tdline.
      ENDIF.
    ENDIF.
    IF sy-subrc <> 0.
      IF g_nast-spras = 'L'.
        e_section2-comments = 'brak'.
      ENDIF.
      IF g_nast-spras = 'E'.
        e_section2-comments  = 'None'.
      ENDIF.
*      e_section2-comments  = 'None'.
    ENDIF.

    "SIGNATURE
    SELECT SINGLE CreatedByUser
      FROM z_your_lips_alt
       WHERE delivery = @lips_val-delivery
      INTO @e_signature-created_by_user.
    IF sy-subrc <> 0.
      CLEAR lips_val.
    ENDIF.

    "defect 0000000000
    TRY.
        application_object->get_parameter_value(
          EXPORTING
            i_parameter_id    = print_signature-parameter_id
            i_filter          = e_signature-created_by_user
          CHANGING
            c_parameter_value = print_signatures
             ).
      CATCH z_cx_your_efr INTO o_ref.
        lv_msg  = o_ref->get_longtext( ) ##NEEDED.
        RETURN.
    ENDTRY.

*      CATCH z_cx_your_efr INTO exception_ref.
***        MESSAGE exception_ref TYPE 'I' DISPLAY LIKE exception_ref->message_type.
*       CLEAR print_signatures.
*      ENDTRY.

    IF print_signatures IS NOT INITIAL.
      e_header_data-signature = print_signatures.
    ENDIF.
    "end defect 0000000000

    SELECT  SINGLE Persnumber
      FROM z_your_usr21
      WHERE bname = @e_signature-created_by_user
      INTO @DATA(Persnumber).
    IF sy-subrc <> 0.
      CLEAR persnumber.
    ENDIF.
    SELECT SINGLE NameFirst,NameLast
      FROM z_your_adrp
      WHERE persnumber = @persnumber
      INTO @DATA(names).
    IF sy-subrc = 0 .
      e_signature-first_name = |{ names-namefirst } { names-namelast }|.
    ENDIF.
  ENDMETHOD.

  METHOD generate_form.

    set_parameters(
    CHANGING
    c_outputparams = g_outputparams
    c_docparams    = g_docparams
    c_device       = g_device
    ).

    CALL FUNCTION 'FP_JOB_OPEN'
      CHANGING
        ie_outputparams = g_outputparams
      EXCEPTIONS
        cancel          = 1
        usage_error     = 2
        system_error    = 3
        internal_error  = 4
        OTHERS          = 5.
    IF sy-subrc <> 0.
* Implement suitable error handling here
      r_return = sy-subrc.
      protocol_update( ).
    ENDIF.

    SELECT SINGLE sform FROM z_your_tnapr INTO @DATA(g_fpname)    ##NEEDED
      WHERE Kschl = @nast-kschl.
    IF sy-subrc <> 0.
      CLEAR g_fpname.
    ENDIF.

    TRY.
        CALL FUNCTION 'FP_FUNCTION_MODULE_NAME'
          EXPORTING
            i_name     = g_fpname    "'Z_YOUR_FORM_NAME'
          IMPORTING
            e_funcname = g_fmname1.

      CATCH cx_fp_api_repository  " Exception API (Repository)
               cx_fp_api_usage       " Exception API (Use)
               cx_fp_api_internal.   " Exception API (Internal)
        r_return = sy-subrc..
    ENDTRY.

    CALL FUNCTION g_fmname1
      EXPORTING
        /1bcdwb/docparams  = g_docparams
        i_header           = i_header_data
        i_signature        = i_signature
        i_nast             = g_nast
        i_section2         = i_section2
        i_item             = i_item_data
        i_form_name        = i_form_name
      IMPORTING
        /1bcdwb/formoutput = g_formoutput
      EXCEPTIONS
        usage_error        = 1
        system_error       = 2
        internal_error     = 3
        OTHERS             = 4.
    IF sy-subrc <> 0.
* Implement suitable error handling here
      r_return = sy-subrc.
      protocol_update( ).
    ENDIF.

    CALL FUNCTION 'FP_JOB_CLOSE'
      EXCEPTIONS
        usage_error    = 1
        system_error   = 2
        internal_error = 3
        OTHERS         = 4.
    IF sy-subrc <> 0.
* Implement suitable error handling here
      r_return = sy-subrc.
      protocol_update( ).
    ELSE .
      r_return = sy-subrc.
      protocol_update( ).
    ENDIF.

    IF nast-nacha = '8' AND nast-vstat NE '1'.
      DATA: http_sender  TYPE REF TO zcl_http_sender.
      CREATE OBJECT http_sender
        EXPORTING
          i_filename = gv_filename
          i_otf      = g_formoutput.

      CALL METHOD http_sender->send_data
        IMPORTING
          e_response = g_response.
*      IF g_response-status_code = '200' OR g_response-status_code = '201'   ##BOOL_OK.
      IF g_response IS NOT INITIAL.
        sy-mSGNO = g_response-status_code.
        sy-msgid = 'Z_YOUR_RSPNS_MSG'.
        sy-msgv1 = g_response-status_message.
        IF sy-msgty  = 'E'.
          r_return = 4.
        ENDIF.
        protocol_update( ).
      ENDIF.
    ENDIF.
  ENDMETHOD.

  METHOD protocol_update.
    CHECK g_screen_display = abap_false.

    CALL FUNCTION 'NAST_PROTOCOL_UPDATE'
      EXPORTING
        msg_arbgb              = sy-msgid
        msg_nr                 = sy-msgno
        msg_ty                 = sy-msgty
        msg_v1                 = sy-msgv1
        msg_v2                 = sy-msgv2
        msg_v3                 = sy-msgv3
        msg_v4                 = sy-msgv4
      EXCEPTIONS
        message_type_not_valid = 1
        no_sy_message          = 2
        OTHERS                 = 3.

    IF sy-subrc <> 0.
      CHECK 1 = 1.
    ENDIF.
  ENDMETHOD.

  METHOD set_parameters.

    DATA: t685b_rec     TYPE z_your_t685b.

    CASE g_nast-nacha.
      WHEN '1'.
        c_device  = c_printer.
      WHEN OTHERS.
        CLEAR c_device.
    ENDCASE.
    IF NOT g_screen_display IS INITIAL.
      c_outputparams-noprint   = abap_true.
      c_outputparams-nopributt = abap_true.
      c_outputparams-noarchive = abap_true.
      c_outputparams-getpdf    = abap_false.
      c_outputparams-preview   = abap_true.
    ELSE.
      TRY.
          IF cl_fp_feature_test=>is_available(
          iv_feature = cl_fp_feature_test=>gc_render_pdfa1 ) = abap_true.
            c_outputparams-pdfnorm = if_fp_pdf_norm=>pdf_a1.
          ENDIF.
        CATCH cx_fp_runtime.
          protocol_update( ).
      ENDTRY.
    ENDIF.
    IF nast-nacha = '8'.
      c_outputparams-getpdf = abap_true.
    ENDIF.
    c_outputparams-title     = c_title.
    c_outputparams-nodialog  = abap_true.
    c_outputparams-dest      = g_nast-ldest.
    c_outputparams-copies    = g_nast-anzal.
    c_outputparams-dataset   = g_nast-dsnam.
    c_outputparams-suffix1   = g_nast-dsuf1.
    c_outputparams-suffix2   = g_nast-dsuf2.
    c_outputparams-cover     = g_nast-tdocover.
    c_outputparams-covtitle  = g_nast-tdcovtitle.
    c_outputparams-authority = g_nast-tdautority.
    c_outputparams-receiver  = g_nast-tdreceiver.
    c_outputparams-division  = g_nast-tddivision.
    c_outputparams-arcmode   = g_nast-tdarmod.
    c_outputparams-reqnew    = abap_true.
    c_outputparams-reqimm    = g_nast-dimme.
    c_outputparams-reqdel    = g_nast-delet.
    c_outputparams-senddate  = g_nast-vsdat.
    c_outputparams-sendtime  = g_nast-vsura.

    c_docparams-langu        = g_nast-spras.
    c_docparams-replangu2    = 'E'.  "English
    c_docparams-country      = 'IN'.
    c_docparams-fillable     = space.

    IF g_nast-tdarmod = '2' OR g_nast-tdarmod = '3'.
      SELECT SINGLE arcobjart FROM z_your_t685b
      INTO @t685b_rec
      WHERE kappl = @g_nast-kappl AND
            kschl = @g_nast-kschl.

      IF sy-subrc = 0 AND t685b_rec-arcobjart IS NOT INITIAL.


        c_docparams-daratab = VALUE #( ( function   = 'DARA'
                                         mandant    = sy-mandt
                                         sap_object = 'Z_YOUR_SAP_OBJECT'
                                         ar_object  = t685b_rec-arcobjart
                                         object_id  = g_nast-objky
                                         notiz      = TEXT-023 ) ).
      ENDIF.

    ENDIF.
  ENDMETHOD.
ENDCLASS.
