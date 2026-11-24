class ZCL_HTTP_SENDER definition
  public
  final
  create public .

public section.

  data G_OTF type FPFORMOUTPUT .
  data G_FILENAME type STRING .
  class-data G_MESSAGE type CHAR30 .

  methods CONSTRUCTOR
    importing
      !I_FILENAME type STRING
      !I_OTF type FPFORMOUTPUT .
  methods SEND_DATA
    exporting
      !E_RESPONSE type z_your_http_response .
protected section.
private section.

  class-data G_DESTINATION type CHAR30 .

  methods GET_PARAMETER .
  methods OTF_TO_JSON
    exporting
      !E_JSON_CONTENT type STRING .
ENDCLASS.



CLASS ZCL_HTTP_SENDER IMPLEMENTATION.


  method CONSTRUCTOR.
* Design Spec:    Z_YOUR_FUNCTIONAL_SPEC
* Technical Spec: Z_YOUR_DESIGN_SPEC
* Process:        Interface for sending and recieving from RFC
* History -------------------------------------------------------------*
* Date       | Change    | Contrib. | Description
*----------------------------------------------------------------------*
* 01.01.2026 ||           | Initial version
*&---------------------------------------------------------------------*
*&---------------------------------------------------------------------*
*&---------------------------------------------------------------------*
    g_filename = i_filename.
    g_otf = i_otf.
  endmethod.


  METHOD get_parameter.
* Design Spec:    Z_YOUR_FUNCTIONAL_SPEC
* Technical Spec: Z_YOUR_DESIGN_SPEC
* Process:        Interface for sending and recieving from RFC
* History -------------------------------------------------------------*
* Date       | Change    | Contrib. | Description
*----------------------------------------------------------------------*
* 01.01.2026 ||           | Initial version
*&---------------------------------------------------------------------*
*&---------------------------------------------------------------------*


    CONSTANTS: efr  TYPE char40 VALUE 'Z_YOUR_EFR_APP',
               dest TYPE char40 VALUE 'Z_YOUR_RFC_DEST'.

    TRY.
        DATA(application_object) = z_your_efr=>factory( i_application_id = efr ).

      CATCH z_cx_your_efr INTO DATA(exception).
*        MESSAGE exception TYPE 'E' INTO g_message.
        CALL METHOD exception->get_text
          RECEIVING
            result = DATA(error).
        g_message = error.
        CLEAR application_object.
    ENDTRY.

    IF application_object IS BOUND.

      TRY.

*                            TRY.
          application_object->get_parameter_values(
            EXPORTING
              i_parameter_id     = dest
*                                i_grouping         = SPACE
*                                i_filter_range     =
*                                i_all_group_values = ABAP_FALSE
            RECEIVING
              r_parameter_values = DATA(parameters) )
              .
          IF parameters IS  NOT INITIAL.
            g_destination = parameters[ 1 ]-parameter_value.
          ENDIF.
*
        CATCH z_cx_your_efr INTO exception.
*         MESSAGE exception TYPE 'E'.
          CALL METHOD exception->get_text
            RECEIVING
              result = error.
          g_message = error.
          CLEAR parameters.

      ENDTRY.

    ENDIF.
  ENDMETHOD.


  METHOD otf_to_json.
* Design Spec:    Z_YOUR_FUNCTIONAL_SPEC
* Technical Spec: Z_YOUR_DESIGN_SPEC
* Process:        Interface for sending and recieving from RFC
* History -------------------------------------------------------------*
* Date       | Change    | Contrib. | Description
*----------------------------------------------------------------------*
* 01.01.2026 ||           | Initial version
*&---------------------------------------------------------------------*
*&---------------------------------------------------------------------*


    DATA:
      json_str    TYPE string,
      pdf_xstring TYPE xstring,
      base64_conv TYPE string.

*    DATA jsoncontent TYPE  z_your_http_response.


    TYPES: BEGIN OF ty_file_data,
             partner   TYPE c LENGTH 20,
             file_name TYPE c LENGTH 255,
             file_content   TYPE string,
           END OF ty_file_data.

    DATA: jsoncontent TYPE ty_file_data.


    IF g_otf IS INITIAL.
      RETURN.
    ENDIF.
    CONSTANTS: efr     TYPE char40 VALUE 'Z_YOUR_EFR_APP',
               partner TYPE char40 VALUE 'PARTNER'.

    TRY.
        DATA(application_object) = z_your_efr=>factory( i_application_id = efr ).
      CATCH z_cx_your_efr INTO DATA(exception).
        MESSAGE exception TYPE 'E'.
    ENDTRY.

    IF application_object IS BOUND.

      TRY.
*fetch the EFR parameter partner
          CALL METHOD application_object->get_parameter_values(
            EXPORTING
              i_parameter_id     = partner
            RECEIVING
              r_parameter_values = DATA(partner_t) ).
        CATCH z_cx_your_efr.
          MESSAGE exception TYPE 'E'.
      ENDTRY.
      IF partner_t IS  NOT INITIAL.
        DATA(partner_par) = partner_t[ 1 ]-parameter_value.
      ENDIF.
    ENDIF.
*

    pdf_xstring = g_otf-pdf.
*converting the PDF from OTF to BASE64 format
    CALL FUNCTION 'SCMS_BASE64_ENCODE_STR'
      EXPORTING
        input  = pdf_xstring
      IMPORTING
        output = base64_conv.
*    Assigning filenme to the json workarea
    jsoncontent-file_name = g_filename.
*  Assigning the content which is in BASE64 to json workare
    jsoncontent-file_content = base64_conv.
*    Assigning partner from EFR to json work area
    jsoncontent-partner = partner_par.
*    Convertin json workarea content  to json structure
    json_str = /ui2/cl_json=>serialize( data        = jsoncontent
                                            compress    = abap_false ).
*                                            pretty_name = /ui2/cl_json=>pretty_mode-camel_case ).

    e_json_content = json_str.
  ENDMETHOD.


  METHOD send_data.
* Design Spec:    Z_YOUR_FUNCTIONAL_SPEC
* Technical Spec: Z_YOUR_DESIGN_SPEC
* Process:        Interface for sending and recieving from RFC
* History -------------------------------------------------------------*
* Date       | Change    | Contrib. | Description
*----------------------------------------------------------------------*
* 01.01.2026 ||           | Initial version
*&---------------------------------------------------------------------*
*&---------------------------------------------------------------------*


    DATA: class_http_client TYPE REF TO if_http_client,
          http_status       TYPE string,
          http_response     TYPE string,
          json_str          TYPE string.
*          response          TYPE z_your_http_response.


*get destination maintained in EFR
    get_parameter( ).

* Convert the OTF and filename to json format
    otf_to_json(
      IMPORTING
        e_json_content = json_str )
        .
*if json contains value and destination maintained in the EFR contaiins value then only proceed.
    IF g_destination IS NOT INITIAL AND json_str IS NOT INITIAL.

*=>create_by_destination


*
      cl_http_client=>create_by_destination(
        EXPORTING
          destination                = g_destination
        IMPORTING
          client                     = class_http_client
        EXCEPTIONS
          argument_not_found         = 1
          destination_not_found      = 2
          destination_no_authority   = 3
          plugin_not_active          = 4
          internal_error             = 5
          oa2c_set_token_error       = 6
          oa2c_missing_authorization = 7
          oa2c_invalid_config        = 8
          oa2c_invalid_parameters    = 9
          oa2c_invalid_scope         = 10
          oa2c_invalid_grant         = 11
          OTHERS                     = 12
             ) .
      IF sy-subrc = 0.
*             Implement suitable error handling here

        class_http_client->propertytype_logon_popup = class_http_client->co_disabled.

        class_http_client->request->set_content_type( content_type = if_rest_media_type=>gc_appl_json ).

        class_http_client->request->set_cdata( json_str ).

        CALL METHOD class_http_client->send
          EXPORTING
            timeout                    = if_http_client=>co_timeout_infinite
          EXCEPTIONS
            http_communication_failure = 1
            http_invalid_state         = 2
            http_processing_failed     = 3
            http_invalid_timeout       = 4
            OTHERS                     = 5.

        IF sy-subrc IS INITIAL.


*        * Get the response back
          CALL METHOD class_http_client->receive
            EXCEPTIONS
              http_communication_failure = 1
              http_invalid_state         = 2
              http_processing_failed     = 3
              OTHERS                     = 4.

          IF sy-subrc IS NOT INITIAL.

            http_status = class_http_client->response->get_header_field( '~status_code' ).

*Error in getting response from External API*
            e_response-status_code = '005'.
            MESSAGE e005 INTO e_response-status_message  .
          ELSE.

            http_status = class_http_client->response->get_header_field( '~status_code' ).

            http_response = class_http_client->response->get_header_field( '~status_reason' ).

            http_response = class_http_client->response->get_cdata( ).

            /ui2/cl_json=>deserialize( EXPORTING json        = http_response
                                                pretty_name = /ui2/cl_json=>pretty_mode-camel_case
                                      CHANGING data = e_response ).

            IF http_status = '200' OR http_status = '201'.
*        success
              e_response-status_code = '000'.

            ELSEIF http_status = '400'.
              e_response-status_code = '001'.
              MESSAGE e001 INTO e_response-status_message .
            ELSE.
              e_response-status_code = '002'.
              MESSAGE e002 INTO e_response-status_message .
*              e_response-status_message = 'File transfer failed'.
*          error
            ENDIF.
          ENDIF.


        ELSE.
*      Error in sending HTTP request to External API, Connection error with External API
          e_response-status_code = '003'.
          MESSAGE e003 INTO e_response-status_message .
        ENDIF.
      ELSE.

*        Error creating HTTP client for the RFC Destination
        e_response-status_code = '004'.
        MESSAGE e004 INTO e_response-status_message .

      ENDIF.
      else.
        e_response-status_code = '006'.
        MESSAGE e006 INTO e_response-status_message .
    ENDIF.
  ENDMETHOD.
ENDCLASS.
