*&---------------------------------------------------------------------*
*& Function group ZMM_STOCK_TAB  -  subscreen 0100 for the "Stock" tab
*& PBO / PAI modules + popup ALV.  (Includes LZMM_STOCK_TABTOP / O01 /
*& I01 / F01 merged here for readability.)
*&---------------------------------------------------------------------*

*----------------------------------------------------------------------*
* TOP: global data of the function group
*----------------------------------------------------------------------*
TYPES: BEGIN OF ty_ctx,
         banfn TYPE banfn,
         bnfpo TYPE bnfpo,
         matnr TYPE matnr,
         werks TYPE werks_d,
       END OF ty_ctx.

TYPES: BEGIN OF ty_stock,
         werks TYPE werks_d,
         lgort TYPE lgort_d,
         lgobe TYPE lgobe,
         labst TYPE labst,          " unrestricted-use stock
         meins TYPE meins,
       END OF ty_stock.

DATA: gs_ctx       TYPE ty_ctx,
      zmm_stock_tab_ctx TYPE ty_ctx,          " screen structure
      gt_stock     TYPE STANDARD TABLE OF ty_stock WITH EMPTY KEY,
      go_dialog    TYPE REF TO cl_gui_dialogbox_container,
      go_grid      TYPE REF TO cl_gui_alv_grid,
      ok_code      TYPE sy-ucomm.

*----------------------------------------------------------------------*
* PBO
*----------------------------------------------------------------------*
MODULE status_0100 OUTPUT.
  " Pick up the context parked by the BAdI (ID 'BAN' for PR,
  " 'BES' for PO) - see ZCL_IM_ME_GUI_STOCK_TAB.
  IMPORT ctx = gs_ctx FROM MEMORY ID 'BAN'.
  IF sy-subrc <> 0.
    CLEAR gs_ctx.
  ENDIF.
  zmm_stock_tab_ctx = gs_ctx.

  " In display transactions (ME53N) the subscreen stays input-disabled;
  " the push button that opens the popup remains active.
  LOOP AT SCREEN.
    IF screen-group1 = 'INP'.
      screen-input = 0.
      MODIFY SCREEN.
    ENDIF.
  ENDLOOP.
ENDMODULE.

*----------------------------------------------------------------------*
* PAI
*----------------------------------------------------------------------*
MODULE user_command_0100 INPUT.
  CASE ok_code.
    WHEN 'ZSTOCK'.                       " push button on the tab
      PERFORM show_stock_popup.
  ENDCASE.
  CLEAR ok_code.
ENDMODULE.

*----------------------------------------------------------------------*
* Popup ALV: plant / storage-location unrestricted stock
*----------------------------------------------------------------------*
FORM show_stock_popup.
  IF gs_ctx-matnr IS INITIAL OR gs_ctx-werks IS INITIAL.
    MESSAGE s003(zmm).   " 'Enter material and plant first'
    RETURN.
  ENDIF.

  PERFORM read_stock USING gs_ctx-matnr gs_ctx-werks.

  IF go_dialog IS NOT BOUND.
    CREATE OBJECT go_dialog
      EXPORTING
        width   = 700
        height  = 300
        top     = 80
        left    = 200
        caption = |Stock for { gs_ctx-matnr ALPHA = OUT } / { gs_ctx-werks }|.

    SET HANDLER lcl_handler=>on_close FOR go_dialog.

    CREATE OBJECT go_grid
      EXPORTING
        i_parent = go_dialog.
  ENDIF.

  DATA(ls_layout) = VALUE lvc_s_layo( zebra = abap_true
                                       cwidth_opt = abap_true
                                       no_toolbar = abap_true ).

  go_grid->set_table_for_first_display(
    EXPORTING
      i_structure_name = 'ZMM_STOCK_LINE'      " DDIC structure = ty_stock
      is_layout        = ls_layout
    CHANGING
      it_outtab        = gt_stock
    EXCEPTIONS
      OTHERS           = 1 ).
  IF sy-subrc <> 0.
    MESSAGE s004(zmm) DISPLAY LIKE 'E'.   " 'Stock display could not be built'
  ENDIF.
ENDFORM.

FORM read_stock USING iv_matnr TYPE matnr
                      iv_werks TYPE werks_d.
  CLEAR gt_stock.

  " Released CDS views in preference to MARD / T001L / MARA
  SELECT s~plant                 AS werks,
         s~storagelocation       AS lgort,
         l~storagelocationname   AS lgobe,
         s~matlwrhsstkqtyinmatlbaseunit AS labst,
         p~baseunit              AS meins
    FROM i_materialstock AS s
    INNER JOIN i_product  AS p
      ON p~product = s~material
    LEFT OUTER JOIN i_storagelocation AS l
      ON  l~plant           = s~plant
      AND l~storagelocation = s~storagelocation
    WHERE s~material           = @iv_matnr
      AND s~plant              = @iv_werks
      AND s~inventorystocktype = '01'            " unrestricted use
    ORDER BY s~storagelocation
    INTO CORRESPONDING FIELDS OF TABLE @gt_stock.
ENDFORM.

*----------------------------------------------------------------------*
* Close handler for the dialog box
*----------------------------------------------------------------------*
CLASS lcl_handler DEFINITION.
  PUBLIC SECTION.
    CLASS-METHODS on_close
      FOR EVENT close OF cl_gui_dialogbox_container
      IMPORTING sender.
ENDCLASS.

CLASS lcl_handler IMPLEMENTATION.
  METHOD on_close.
    sender->set_visible( abap_false ).
  ENDMETHOD.
ENDCLASS.
