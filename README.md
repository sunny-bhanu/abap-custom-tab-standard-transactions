# abap-custom-tab-standard-transactions

**Adding a custom "Stock" tab with a popup ALV to the item detail of the Enjoy purchasing transactions - ME51N/ME52N/ME53N (BAdI) and ME21N/ME22N/ME23N (screen exit) - and the two boundary problems that come with it.**

## Requirement

While creating a purchase requisition or purchase order, buyers wanted to see **plant- and storage-location-wise unrestricted stock** of the item material without leaving the transaction.

## Two transactions, two mechanisms

| Transaction | Hook | Objects |
|---|---|---|
| ME51N / ME52N / ME53N | BAdI **`ME_GUI_PO_CUST`** (`SUBSCRIBE`, `TRANSPORT_FROM_MODEL`) - the same BAdI SAP uses for both PR and PO Enjoy screens, filtered on `IM_APPLICATION = 'REQ'`; item data from `IF_PURCHASE_REQUISITION_ITEM` | [`zcl_im_me_gui_stock_tab.clas.abap`](zcl_im_me_gui_stock_tab.clas.abap) + function group `ZMM_STOCK_TAB` screen `0100` |
| ME21N / ME22N / ME23N | Screen exit **`MM06E005`** (function group `XM06`, customer subscreen `SAPLXM06 0111`), function exits `EXIT_SAPMM06E_006/007/012/013` | Same module pool / popup logic, context passed via memory ID `BES` |

Both routes reuse **one** popup implementation: [`lzmm_stock_tabi01.prog.abap`](lzmm_stock_tabi01.prog.abap) - `CL_GUI_DIALOGBOX_CONTAINER` + `CL_GUI_ALV_GRID`, stock read through released CDS views `I_MaterialStock`, `I_Product` and `I_StorageLocation`.

## Problem 1 - crossing the program boundary

The BAdI implementation class runs inside `SAPLMEGUI`; the subscreen's PBO/PAI runs inside `SAPLZMM_STOCK_TAB`. They share no global data.

**Solution:** `EXPORT … TO MEMORY ID` in `TRANSPORT_FROM_MODEL`, `IMPORT … FROM MEMORY ID` in the subscreen PBO. The IDs follow the SAP parameter IDs of the documents - **`BAN`** (requisition) and **`BES`** (purchase order) - so a developer debugging later recognises them immediately. Memory is per internal session, so parallel ME51N windows do not collide.

Alternatives rejected:
- Global class attributes - the module pool cannot see the BAdI's instance.
- `SET/GET PARAMETER` - SPA/GPA is user-wide, not session-wide; two sessions overwrite each other.

## Problem 2 - custom function codes in ME21N

In ME21N the GUI status is owned by `SAPLMEGUI`; a plain push button on a customer subscreen raises a function code that the standard PAI does **not** route to the exit - the click is silently swallowed.

**Solution:** declare the button's function type as **`E` (Exit Command)** in Screen Painter and handle it in a `MODULE … AT EXIT-COMMAND` in the subscreen's flow logic:

```abap
PROCESS AFTER INPUT.
 MODULE exit_0111 AT EXIT-COMMAND. " fires before standard PAI, for type-E fcodes only
 ...
```

Exit-command modules run **before** field transport and before the standard program's PAI, so the popup can be opened without the standard logic consuming the OK code. (For ME51N the BAdI's `EXECUTE` method receives the function code directly, so this trick is only needed on the screen-exit route.)

## Design notes

- The tab is **display-only**; `TRANSPORT_TO_MODEL` and `MAP_DYNPRO_FIELDS` are intentionally empty. Writing back into the PR/PO model from a custom tab needs a `CI_EBANDB` / `CI_EKPODB` append and the full mapping - a different (and well documented) exercise.
- `LOOP AT SCREEN` disables input fields in ME53N / ME23N while keeping the stock button active.
- Stock is read **per click**, not in PBO, so the transaction stays fast when the user never opens the popup.
- `I_MaterialStock` is filtered on `InventoryStockType = '01'` (unrestricted). Extend the select for quality-inspection (`'02'`) or blocked (`'07'`) stock if required.

## Steps to reproduce (PR route)

1. **SE80** → function group `ZMM_STOCK_TAB` → subscreen `0100` with structure `ZMM_STOCK_TAB_CTX` (display fields) and push button `ZSTOCK`.
2. **SE11** → structure `ZMM_STOCK_LINE` (plant, storage location, name, quantity, unit) for the ALV field catalogue.
3. **SE19** → BAdI `ME_GUI_PO_CUST` → implementation with the class from this repo. Subscriber name must be unique system-wide.
4. Message class `ZMM` → 003 *Enter material and plant first*, 004 *Stock display could not be built*.
5. Test ME51N → item detail → **Stock** tab → button → popup ALV.

---
*Written as generic reference material. No client data or client-specific logic.* MIT License - see [LICENSE](LICENSE).
