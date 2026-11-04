*&---------------------------------------------------------------------*
*& Include ZXM02TOP
*& Global data of exit function group XM02 (enhancement MEREQ001).
*& Exit EXIT_SAPLMEREQ_001 and the PAI of subscreen SAPLXM02 0111 run in
*& this same function group, so a global here is enough to hand the
*& item on display from the exit to the button. No SAP memory needed.
*&---------------------------------------------------------------------*
DATA: gs_req_item  TYPE zcl_mm_stock_tab=>ty_item,   " item on display
      gt_req_items TYPE zcl_mm_stock_tab=>ty_items.  " items for the popup
