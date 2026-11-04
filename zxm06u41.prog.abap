*&---------------------------------------------------------------------*
*& Include ZXM06U41
*& EXIT_SAPMM06E_016 (MM06E005): export data to the customer subscreen
*& of the purchasing document item (PBO).
*& TEKPO holds all items of the document as they are on the screen,
*& unsaved ones included, so no GET PARAMETER ID 'BES' and no EKPO read.
*&---------------------------------------------------------------------*
CLEAR gt_po_items.

LOOP AT tekpo ASSIGNING FIELD-SYMBOL(<ls_po_item>)
     WHERE matnr IS NOT INITIAL         " skip text and service items
       AND loekz IS INITIAL.            " skip deleted or blocked items
  INSERT VALUE #( item  = <ls_po_item>-ebelp
                  matnr = <ls_po_item>-matnr
                  werks = <ls_po_item>-werks ) INTO TABLE gt_po_items.
ENDLOOP.
