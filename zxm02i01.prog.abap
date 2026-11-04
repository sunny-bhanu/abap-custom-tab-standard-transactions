*&---------------------------------------------------------------------*
*& Include ZXM02I01 (created from ZXM02ZZZ)
*& PAI of customer subscreen SAPLXM02 0111 (MEREQ001, ME51N to ME53N).
*&
*& Screen 0111: one push button "Display stock",
*&   function code ZSTOCK, function type E (exit command).
*& Flow logic:
*&   PROCESS BEFORE OUTPUT.
*&   PROCESS AFTER INPUT.
*&     MODULE user_command_0111 AT EXIT-COMMAND.
*&
*& Function type E plus AT EXIT-COMMAND is the same technique as on the
*& ME21N route: the click reaches this module before the standard PAI
*& of SAPLMEGUI, whatever that PAI does with the unknown OK code.
*&---------------------------------------------------------------------*
MODULE user_command_0111 INPUT.
  CHECK sy-ucomm = 'ZSTOCK'.

  " All items of the requisition, kept by BAdI ME_PROCESS_REQ_CUST
  gt_req_items = zcl_mm_stock_tab=>get_items( ).

  " BAdI implementation not active: fall back to the item on display
  IF gt_req_items IS INITIAL AND gs_req_item-matnr IS NOT INITIAL.
    INSERT gs_req_item INTO TABLE gt_req_items.
  ENDIF.

  zcl_mm_stock_tab=>show( it_items = gt_req_items
                          iv_title = 'Unrestricted stock in all plants' ).
ENDMODULE.
