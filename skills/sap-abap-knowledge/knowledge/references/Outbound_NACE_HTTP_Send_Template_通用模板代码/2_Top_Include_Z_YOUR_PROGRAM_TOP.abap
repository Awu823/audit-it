*&---------------------------------------------------------------------*
*& Include          Z_YOUR_PROGRAM_TOP
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

TABLES:nast.
DATA : g_item_data      TYPE z_your_item_tab,
       g_section2       TYPE z_your_sec2_st,
       g_header_data    TYPE z_your_header_st,
       g_footer_data    TYPE z_your_footer_st,
       g_lines          TYPE STANDARD TABLE OF tline,
       g_shiptoaddress  TYPE szadr_printform_table,
       g_not_found      TYPE fpboolean,
       g_nast           TYPE nast,
       g_screen_display TYPE char1,
       g_outputparams   TYPE sfpoutputparams,
       g_docparams      TYPE sfpdocparams,
       g_device         TYPE output_device,
*       g_fpname         TYPE fpname,
       g_fmname1        TYPE rs38l_fnam,
       g_formoutput     TYPE fpformoutput ##NEEDED,
*       g_esign          TYPE z_your_esign_st,
       g_val            TYPE char30,
       g_response       TYPE z_your_http_response,
       gv_filename      TYPE string,
       gv_form_name     TYPE text255.
CONSTANTS: c_printer TYPE output_device VALUE 'P',
           c_title   TYPE fptitle       VALUE 'Output',
           addrtype  TYPE ad_adrtype VALUE '1'.
DATA : g_efr_name TYPE string VALUE 'Z_YOUR_EFR_APP'.
