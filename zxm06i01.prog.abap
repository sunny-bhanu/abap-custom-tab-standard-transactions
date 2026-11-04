*&---------------------------------------------------------------------*
*& Include ZXM06I01 (created from ZXM06ZZZ)
*& PAI of customer subscreen SAPLXM06 0111 (MM06E005, ME21N to ME23N).
*&
*& Screen 0111: one push button "Display stock",
*&   function code ZSTOCK, function type E (exit command).
*& Flow logic:
*&   PROCESS BEFORE OUTPUT.
*&   PROCESS AFTER INPUT.
*&     MODULE user_command_0111 AT EXIT-COMMAND.
*&
*& In ME21N the GUI status belongs to SAPLMEGUI. A normal push button on
*& the customer subscreen raises a function code the standard PAI does
*& not pass on, so the click is lost. A type-E function code is handled
*& by the AT EXIT-COMMAND module before the standard PAI runs.
*&---------------------------------------------------------------------*
MODULE user_command_0111 INPUT.
  CHECK sy-ucomm = 'ZSTOCK'.

  zcl_mm_stock_tab=>show( it_items = gt_po_items
                          iv_title = 'Unrestricted stock in all plants' ).
ENDMODULE.
