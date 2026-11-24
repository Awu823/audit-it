*&---------------------------------------------------------------------*
*& Subroutinenpool Z_YOUR_PROGRAM
*&---------------------------------------------------------------------*
*&---------------------------------------------------------------------*
*&
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
PROGRAM z_your_program MESSAGE-ID z_your_msgid.


INCLUDE z_your_program_top.
INCLUDE z_your_program_ci1.


FORM entry USING i_returncode TYPE sysubrc   ##CALLED
                 i_screen     TYPE char1.

  DATA(g_process) = NEW lcl_process( i_screen ).
  IF g_process IS BOUND.
    DATA bo TYPE vbeln_vl.
    bo = nast-objky.
    g_process->fetch_form_data( EXPORTING document = bo
                      IMPORTING
                        e_item_data   = g_item_data
      e_header_data = g_header_data
      e_signature = g_footer_data
      e_section2 = g_section2
      e_form_name = gv_form_name
    ).
    IF g_item_data IS NOT INITIAL.
      i_returncode = g_process->generate_form( EXPORTING
        i_item_data   = g_item_data
                     i_header_data = g_header_data
                     i_signature   = g_footer_data
                     i_section2     = g_section2
                     i_form_name   = gv_form_name
          ).
    ENDIF.

  ENDIF.
ENDFORM.
