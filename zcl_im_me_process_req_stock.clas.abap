"! <p class="shorttext synchronized">ME51N Stock tab: collect the requisition items for the popup</p>
"! Implementation of BAdI ME_PROCESS_REQ_CUST.
"!
"! Why this BAdI is needed next to the MEREQ001 screen exit:
"!   The customer subscreen (SAPLXM02 0111) only ever sees the item that
"!   is on display. PROCESS_ITEM runs for every item that is created or
"!   changed, before the first save as well, so the buffer in
"!   ZCL_MM_STOCK_TAB always mirrors the requisition on the screen,
"!   unsaved items included. The popup can then show the stock for all
"!   materials of the requisition, which is what buyers asked for.
CLASS zcl_im_me_process_req_stock DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_ex_me_process_req_cust.
ENDCLASS.



CLASS zcl_im_me_process_req_stock IMPLEMENTATION.

  METHOD if_ex_me_process_req_cust~open.
    " A requisition is opened in this session (create, change or display):
    " start from an empty buffer.
    zcl_mm_stock_tab=>clear_items( ).
  ENDMETHOD.


  METHOD if_ex_me_process_req_cust~process_item.
    DATA(ls_item) = im_item->get_data( ).

    IF ls_item-loekz IS NOT INITIAL.     " item flagged for deletion
      zcl_mm_stock_tab=>remove_item( ls_item-bnfpo ).
      RETURN.
    ENDIF.

    zcl_mm_stock_tab=>set_item( VALUE #( item  = ls_item-bnfpo
                                         matnr = ls_item-matnr
                                         werks = ls_item-werks ) ).
  ENDMETHOD.


  METHOD if_ex_me_process_req_cust~close.
    zcl_mm_stock_tab=>clear_items( ).
  ENDMETHOD.


  " The remaining methods are not used by this enhancement. They are
  " listed so the class activates without warnings.
  METHOD if_ex_me_process_req_cust~initialize.
  ENDMETHOD.

  METHOD if_ex_me_process_req_cust~process_header.
  ENDMETHOD.

  METHOD if_ex_me_process_req_cust~process_account.
  ENDMETHOD.

  METHOD if_ex_me_process_req_cust~check.
  ENDMETHOD.

  METHOD if_ex_me_process_req_cust~post.
  ENDMETHOD.

  METHOD if_ex_me_process_req_cust~fieldselection_header.
  ENDMETHOD.

  METHOD if_ex_me_process_req_cust~fieldselection_header_refkeys.
  ENDMETHOD.

  METHOD if_ex_me_process_req_cust~fieldselection_item.
  ENDMETHOD.

  METHOD if_ex_me_process_req_cust~fieldselection_item_refkeys.
  ENDMETHOD.

ENDCLASS.
