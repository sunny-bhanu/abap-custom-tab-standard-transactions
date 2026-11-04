*&---------------------------------------------------------------------*
*& Include ZXM02U01
*& EXIT_SAPLMEREQ_001 (MEREQ001): export data to the customer subscreen
*& SAPLXM02 0111 of the requisition item (PBO).
*& Interface: IM_REQ_ITEM TYPE REF TO IF_PURCHASE_REQUISITION_ITEM
*&---------------------------------------------------------------------*
" Remember which item is on display. The item comes from the document
" in memory, so this also works in ME51N before the first save.
CLEAR gs_req_item.

IF im_req_item IS BOUND.
  DATA(ls_req_item) = im_req_item->get_data( ).
  gs_req_item = VALUE #( item  = ls_req_item-bnfpo
                         matnr = ls_req_item-matnr
                         werks = ls_req_item-werks ).
ENDIF.
