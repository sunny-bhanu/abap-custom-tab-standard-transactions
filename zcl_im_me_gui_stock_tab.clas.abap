"! <p class="shorttext synchronized">Custom "Stock" tab in ME51N/ME52N/ME53N item detail</p>
"! BAdI ME_GUI_PO_CUST — registers a customer subscreen on the
"! item-detail tab strip of the Enjoy purchasing transactions.
"! The same BAdI serves ME21N–ME23N; this implementation is
"! filtered to purchase requisitions via the view name.
"!
"! Data flow:
"!   SUBSCRIBE            -> register tab (program/screen/label)
"!   TRANSPORT_FROM_MODEL -> read current item from the MM model
"!                           (IF_PURCHASE_REQUISITION_ITEM) and park
"!                           material/plant in SAP memory (ID 'BAN')
"!   Module pool ZMM_STOCK_TAB (screen 0100) reads the memory ID in
"!   PBO and shows plant/storage-location stock in a popup ALV.
CLASS zcl_im_me_gui_stock_tab DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_ex_me_gui_po_cust.

  PRIVATE SECTION.
    CONSTANTS:
      gc_subscreen_prog TYPE syrepid        VALUE 'SAPLZMM_STOCK_TAB',
      gc_subscreen_no   TYPE sydynnr        VALUE '0100',
      gc_tab_label      TYPE string         VALUE 'Stock',
      gc_view_item_req  TYPE mmpur_bool     VALUE 'X',
      gc_memory_id_req  TYPE char3          VALUE 'BAN'.  " PR context

    TYPES: BEGIN OF ty_ctx,
             banfn TYPE banfn,
             bnfpo TYPE bnfpo,
             matnr TYPE matnr,
             werks TYPE werks_d,
           END OF ty_ctx.
ENDCLASS.



CLASS zcl_im_me_gui_stock_tab IMPLEMENTATION.

  METHOD if_ex_me_gui_po_cust~subscribe.
    " IM_APPLICATION = 'PO' for ME21N.., 'REQ' for ME51N..
    " IM_ELEMENT     = 'ITEM' for the item detail tab strip
    IF im_application <> 'REQ' OR im_element <> 'ITEM'.
      RETURN.
    ENDIF.

    CLEAR re_subscribers.
    APPEND VALUE mepo_subscriber(
             name     = 'ZSTOCKTAB'          " unique subscriber name
             program  = gc_subscreen_prog
             dynpro   = gc_subscreen_no
             struct_name = 'ZMM_STOCK_TAB_CTX'
             label    = gc_tab_label
             position = 20
             height   = 15 )
           TO re_subscribers.
  ENDMETHOD.


  METHOD if_ex_me_gui_po_cust~map_dynpro_fields.
    " Nothing to map back: the tab is display-only.
  ENDMETHOD.


  METHOD if_ex_me_gui_po_cust~transport_from_model.
    " Called every time the item detail is (re)displayed.
    IF im_name <> 'ZSTOCKTAB'.
      RETURN.
    ENDIF.

    DATA lo_item TYPE REF TO if_purchase_requisition_item.
    mmpur_dynamic_cast lo_item im_model.      " MM macro: safe cast
    IF lo_item IS NOT BOUND.
      RETURN.
    ENDIF.

    DATA(ls_item) = lo_item->get_data( ).

    DATA(ls_ctx) = VALUE ty_ctx( banfn = ls_item-banfn
                                 bnfpo = ls_item-bnfpo
                                 matnr = ls_item-matnr
                                 werks = ls_item-werks ).

    " Cross the program boundary BAdI class -> module pool through
    " SAP memory. The module pool imports the same ID in its PBO.
    EXPORT ctx = ls_ctx TO MEMORY ID gc_memory_id_req.
  ENDMETHOD.


  METHOD if_ex_me_gui_po_cust~transport_to_model.
    " Display-only tab: no data flows back into the model.
  ENDMETHOD.


  METHOD if_ex_me_gui_po_cust~execute.
    " Function codes raised on the custom subscreen arrive here.
  ENDMETHOD.

ENDCLASS.
