# abap-custom-tab-standard-transactions

**A custom "Stock" tab with a popup ALV on the item detail of the Enjoy purchasing transactions: ME51N/ME52N/ME53N through screen exit `MEREQ001` plus BAdI `ME_PROCESS_REQ_CUST`, and ME21N/ME22N/ME23N through screen exit `MM06E005`.**

## Requirement

While creating a purchase requisition or purchase order, buyers wanted to see the **unrestricted stock of the item materials in every plant and storage location** without leaving the transaction, so that idle stock at another site is used before a new purchase is raised.

## Two transactions, two sets of hooks

| Transaction | Hooks | Objects in this repo |
|---|---|---|
| ME51N / ME52N / ME53N | Screen exit **`MEREQ001`** (CMOD project, customer subscreen `SAPLXM02 0111`, exit `EXIT_SAPLMEREQ_001`) plus BAdI **`ME_PROCESS_REQ_CUST`** (`OPEN`, `PROCESS_ITEM`, `CLOSE`) | [`zcl_im_me_process_req_stock.clas.abap`](zcl_im_me_process_req_stock.clas.abap), [`zxm02top.prog.abap`](zxm02top.prog.abap), [`zxm02u01.prog.abap`](zxm02u01.prog.abap), [`zxm02i01.prog.abap`](zxm02i01.prog.abap) |
| ME21N / ME22N / ME23N | Screen exit **`MM06E005`** (CMOD project, customer subscreen `SAPLXM06 0111` on the item tab "Customer Data", exit `EXIT_SAPMM06E_016`) | [`zxm06top.prog.abap`](zxm06top.prog.abap), [`zxm06u41.prog.abap`](zxm06u41.prog.abap), [`zxm06i01.prog.abap`](zxm06i01.prog.abap) |

Both routes call **one** popup class: [`zcl_mm_stock_tab.clas.abap`](zcl_mm_stock_tab.clas.abap). It reads stock through the released CDS views `I_MaterialStock` and `I_StorageLocation` and shows it in `CL_GUI_DIALOGBOX_CONTAINER` + `CL_GUI_ALV_GRID`.

## Which hook sees what

| Hook | What it sees | Used for |
|---|---|---|
| `ME_PROCESS_REQ_CUST~PROCESS_ITEM` | **Every** requisition item that is created or changed, before the first save as well | Keeps the item buffer in `ZCL_MM_STOCK_TAB` in step with the screen |
| `ME_PROCESS_REQ_CUST~OPEN` / `~CLOSE` | Start and end of a document in the session | Clears the buffer |
| `EXIT_SAPLMEREQ_001` (`IM_REQ_ITEM`) | Only the item **on display** | Fallback when the BAdI implementation is not active |
| `EXIT_SAPMM06E_016` (`TEKPO`) | All items of the purchase order on the screen | Fills the PO item list directly |

The subscreen alone would only know one item. The BAdI is what lets the popup show the stock for all materials of the requisition.

## Problem 1: handing data from the standard program to the button

The BAdI class, the exit function group and the subscreen are different programs. They need a shared place for the item data.

**Solution:** the BAdI writes into **static attributes of a global class** (`ZCL_MM_STOCK_TAB`); the exits write into **globals of their own function group** (`XM02`, `XM06`), which is also where the subscreen PAI runs. Static attributes and function group globals live per internal session, so:

- the data comes from the document in memory, which means **unsaved items work** in ME51N / ME21N,
- two ME51N windows are two sessions and never see each other's data.

Alternatives rejected:

- `SET/GET PARAMETER ID 'BAN' / 'BES'`: SAP memory belongs to the user logon, so a second session can overwrite it, and it only carries the **last saved** document number. In create mode it points to the previous document and the select on EBAN / EKPO finds nothing for the new one.
- `EXPORT/IMPORT ... MEMORY ID`: works, but adds a second copy of the data where a class attribute is enough.

## Problem 2: custom function codes in ME21N

In ME21N the GUI status is owned by `SAPLMEGUI`; a plain push button on a customer subscreen raises a function code that the standard PAI does **not** route to the exit, so the click is lost.

**Solution:** declare the button's function type as **`E` (Exit Command)** in Screen Painter and handle it in a `MODULE ... AT EXIT-COMMAND` in the subscreen's flow logic:

```abap
PROCESS BEFORE OUTPUT.
PROCESS AFTER INPUT.
  MODULE user_command_0111 AT EXIT-COMMAND.   " type-E function codes only, before the standard PAI
```

The ME51N subscreen uses the same technique, so both routes behave the same.

## Design notes

- The tab is **display-only**. Writing back into the PR / PO needs `CI_EBANDB` / `CI_EKPODB` appends and the import exits (`EXIT_SAPLMEREQ_003`, `EXIT_SAPMM06E_018`), a different exercise.
- Stock is read **per click**, not in PBO, so the transaction stays fast when nobody opens the popup.
- `I_MaterialStock` is filtered on `InventoryStockType = '01'` (unrestricted) and an empty `InventorySpecialStockType` (own stock, the same figure as `MARD-LABST`), and summed per storage location. Add quality inspection (`'02'`) or blocked (`'07'`) stock if needed.
- The tab title is SAP's standard "Customer Data" title of the customer subscreen; changing it is a text topic, not code.
- If an unsaved item is deleted in ME51N, check on your release that `PROCESS_ITEM` reports it; otherwise rebuild the buffer from the header in `PROCESS_HEADER`.

## Delivered vs this version

The first version I delivered on a project used the same hooks and the same popup, with a simpler handover. This repo is the version I would build today.

| Topic | First delivered version | This version | Why it changed |
|---|---|---|---|
| Handover to the button | PR: `PROCESS_ITEM` put the PR number into `SET PARAMETER ID 'BAN'`. PO: `GET PARAMETER ID 'BES'` | Class attributes (PR) and function group globals filled by `EXIT_SAPMM06E_016` (PO) | SAP memory is per user logon and only holds the last saved number |
| Item data | `SELECT` on EBAN / EKPO by document number | Items from the document in memory | Works before the first save |
| Stock source | `MARD` (unrestricted stock `LABST`) | Released CDS view `I_MaterialStock` | Clean core: ATC flags `MARD` in S/4HANA |
| Scope of the popup | All plants for the materials of the document | Same | Unchanged business rule |

## Steps to reproduce

1. **SE24**: create the classes `ZCL_MM_STOCK_TAB` and `ZCL_IM_ME_PROCESS_REQ_STOCK` from this repo.
2. **SE19**: implementation of classic BAdI `ME_PROCESS_REQ_CUST` with class `ZCL_IM_ME_PROCESS_REQ_STOCK`.
3. **CMOD**: one project with `MEREQ001` and `MM06E005`. Fill `ZXM02TOP`, `ZXM02U01`, `ZXM02I01` and `ZXM06TOP`, `ZXM06U41`, `ZXM06I01` from this repo.
4. **SE51**: subscreens `SAPLXM02 0111` and `SAPLXM06 0111`, each with push button "Display stock", function code `ZSTOCK`, function type `E`, and the flow logic above.
5. Message class `ZMM`: 003 *Enter a material on at least one item first*, 004 *Stock display could not be built*, 005 *No unrestricted stock in any plant*.
6. Activate the project and test ME51N and ME21N: item detail, tab "Customer Data", button, popup.

---
*Written as generic reference material. No client data or client-specific logic.* MIT License, see [LICENSE](LICENSE).
