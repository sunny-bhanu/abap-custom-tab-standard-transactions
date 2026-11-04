"! <p class="shorttext synchronized">Stock popup for the custom tabs in ME51N and ME21N</p>
"! Shared by both routes:
"!   PR route (ME51N to ME53N): BAdI ME_PROCESS_REQ_CUST keeps the item
"!     buffer up to date, the MEREQ001 subscreen SAPLXM02 0111 calls SHOW.
"!   PO route (ME21N to ME23N): the MM06E005 subscreen SAPLXM06 0111
"!     calls SHOW with the items handed over by EXIT_SAPMM06E_016.
"!
"! Static attributes live per internal session. The BAdI class and the
"! exit function groups are loaded into the same internal session as
"! SAPLMEGUI, so they see the same buffer, and two ME51N windows (two
"! sessions) never see each other's data. No SAP memory is involved.
CLASS zcl_mm_stock_tab DEFINITION
  PUBLIC
  FINAL
  CREATE PRIVATE.

  PUBLIC SECTION.
    TYPES:
      BEGIN OF ty_item,
        item  TYPE n LENGTH 5,          " BNFPO or EBELP
        matnr TYPE matnr,
        werks TYPE werks_d,
      END OF ty_item,
      ty_items TYPE SORTED TABLE OF ty_item WITH UNIQUE KEY item.

    "! PR route: called from ME_PROCESS_REQ_CUST~PROCESS_ITEM
    CLASS-METHODS set_item
      IMPORTING is_item TYPE ty_item.

    "! PR route: called for deleted items
    CLASS-METHODS remove_item
      IMPORTING iv_item TYPE ty_item-item.

    "! PR route: called from ME_PROCESS_REQ_CUST~OPEN and ~CLOSE
    CLASS-METHODS clear_items.

    CLASS-METHODS get_items
      RETURNING VALUE(rt_items) TYPE ty_items.

    "! Both routes: unrestricted stock in all plants and storage
    "! locations for the materials of the given items
    CLASS-METHODS show
      IMPORTING it_items TYPE ty_items
                iv_title TYPE csequence.

  PRIVATE SECTION.
    TYPES:
      BEGIN OF ty_stock,
        matnr TYPE matnr,
        werks TYPE werks_d,
        lgort TYPE lgort_d,
        lgobe TYPE lgobe,
        labst TYPE labst,               " unrestricted-use stock
        meins TYPE meins,
      END OF ty_stock,
      ty_stock_tab TYPE STANDARD TABLE OF ty_stock WITH EMPTY KEY.

    CLASS-DATA:
      gt_items  TYPE ty_items,
      gt_stock  TYPE ty_stock_tab,      " must outlive SHOW: the grid keeps a reference
      go_dialog TYPE REF TO cl_gui_dialogbox_container,
      go_grid   TYPE REF TO cl_gui_alv_grid.

    CLASS-METHODS read_stock
      IMPORTING it_items        TYPE ty_items
      RETURNING VALUE(rt_stock) TYPE ty_stock_tab.

    CLASS-METHODS build_fieldcat
      RETURNING VALUE(rt_fcat) TYPE lvc_t_fcat.

    CLASS-METHODS on_close
      FOR EVENT close OF cl_gui_dialogbox_container.
ENDCLASS.



CLASS zcl_mm_stock_tab IMPLEMENTATION.

  METHOD set_item.
    IF is_item-matnr IS INITIAL.        " text or service item: no stock to show
      remove_item( is_item-item ).
      RETURN.
    ENDIF.

    INSERT is_item INTO TABLE gt_items.
    IF sy-subrc <> 0.                   " item already buffered: material or plant changed
      MODIFY TABLE gt_items FROM is_item.
    ENDIF.
  ENDMETHOD.


  METHOD remove_item.
    DELETE TABLE gt_items WITH TABLE KEY item = iv_item.
  ENDMETHOD.


  METHOD clear_items.
    CLEAR gt_items.
  ENDMETHOD.


  METHOD get_items.
    rt_items = gt_items.
  ENDMETHOD.


  METHOD show.
    DATA lv_caption TYPE c LENGTH 60.

    IF it_items IS INITIAL.
      MESSAGE s003(zmm).                " 'Enter a material on at least one item first'
      RETURN.
    ENDIF.

    gt_stock = read_stock( it_items ).
    IF gt_stock IS INITIAL.
      MESSAGE s005(zmm).                " 'No unrestricted stock in any plant'
      RETURN.
    ENDIF.

    lv_caption = iv_title.

    IF go_dialog IS BOUND.
      " Popup already open in this session: just refresh it
      go_dialog->set_caption( lv_caption ).
      go_dialog->set_visible( abap_true ).
      go_grid->refresh_table_display( ).
      RETURN.
    ENDIF.

    CREATE OBJECT go_dialog
      EXPORTING
        width   = 760
        height  = 320
        top     = 80
        left    = 160
        caption = lv_caption.
    SET HANDLER on_close FOR go_dialog.

    CREATE OBJECT go_grid
      EXPORTING
        i_parent = go_dialog.

    DATA(lt_fcat) = build_fieldcat( ).

    go_grid->set_table_for_first_display(
      EXPORTING
        is_layout       = VALUE lvc_s_layo( zebra      = abap_true
                                            cwidth_opt = abap_true
                                            no_toolbar = abap_true )
      CHANGING
        it_outtab       = gt_stock
        it_fieldcatalog = lt_fcat
      EXCEPTIONS
        OTHERS          = 1 ).
    IF sy-subrc <> 0.
      MESSAGE s004(zmm) DISPLAY LIKE 'E'. " 'Stock display could not be built'
    ENDIF.
  ENDMETHOD.


  METHOD read_stock.
    DATA lt_matnr TYPE RANGE OF matnr.

    lt_matnr = VALUE #( FOR GROUPS lv_matnr OF ls_item IN it_items
                        GROUP BY ls_item-matnr
                        ( sign = 'I' option = 'EQ' low = lv_matnr ) ).
    IF lt_matnr IS INITIAL.
      RETURN.
    ENDIF.

    " Released CDS view instead of MARD: in S/4HANA the MARD quantity
    " fields are a compatibility view over MATDOC and ATC flags the read.
    " All plants on purpose: the buyer wants to see idle stock at other
    " sites before buying. Own stock only, like MARD-LABST.
    SELECT s~material                              AS matnr,
           s~plant                                 AS werks,
           s~storagelocation                       AS lgort,
           l~storagelocationname                   AS lgobe,
           SUM( s~matlwrhsstkqtyinmatlbaseunit )   AS labst,
           s~materialbaseunit                      AS meins
      FROM i_materialstock AS s
      LEFT OUTER JOIN i_storagelocation AS l
        ON  l~plant           = s~plant
        AND l~storagelocation = s~storagelocation
      WHERE s~material                  IN @lt_matnr
        AND s~inventorystocktype         = '01'      " unrestricted use
        AND s~inventoryspecialstocktype  = @space    " no special stock
        AND s~storagelocation           <> @space
      GROUP BY s~material, s~plant, s~storagelocation,
               l~storagelocationname, s~materialbaseunit
      HAVING SUM( s~matlwrhsstkqtyinmatlbaseunit ) <> 0
      ORDER BY s~material, s~plant, s~storagelocation
      INTO CORRESPONDING FIELDS OF TABLE @rt_stock.
  ENDMETHOD.


  METHOD build_fieldcat.
    " Reference fields give labels, conversion exits and the unit link
    " without a DDIC structure for the popup.
    rt_fcat = VALUE #(
      ( fieldname = 'MATNR' ref_table = 'MARA'  ref_field = 'MATNR' )
      ( fieldname = 'WERKS' ref_table = 'MARD'  ref_field = 'WERKS' )
      ( fieldname = 'LGORT' ref_table = 'MARD'  ref_field = 'LGORT' )
      ( fieldname = 'LGOBE' ref_table = 'T001L' ref_field = 'LGOBE' )
      ( fieldname = 'LABST' ref_table = 'MARD'  ref_field = 'LABST' qfieldname = 'MEINS' )
      ( fieldname = 'MEINS' ref_table = 'MARA'  ref_field = 'MEINS' ) ).
  ENDMETHOD.


  METHOD on_close.
    " Release the controls so the next click builds a fresh popup
    IF go_grid IS BOUND.
      go_grid->free( EXCEPTIONS OTHERS = 1 ).
    ENDIF.
    IF go_dialog IS BOUND.
      go_dialog->free( EXCEPTIONS OTHERS = 1 ).
    ENDIF.
    CLEAR: go_grid, go_dialog.
  ENDMETHOD.

ENDCLASS.
