# DRF Interfaces

## Process Order

| Class | Description |
|---|---|
| `ZCL_P_DCB_DRF_BIOPRORD_FLT` | DRF Filter for Process Order |
| `ZCL_P_DCB_DRF_BIOPRORD_OUT` | DRF Transfer of Process Order |
| `ZCL_P_DCB_DRF_BLPRORD_FLT` | DRF Filter for BL Process Order |
| `ZCL_P_DCB_DRF_BLPRORD_OUT` | DRF Transfer of BL Process Order |
| `ZCL_P_DCB_DRF_DIA_OR_FLT` | DRF Filter for Process Order |
| `ZCL_P_DCB_DRF_DIA_OR_OUT` | DRF Transfer of Production Order for DIA |
| `ZCL_P_DCB_DRF_GNEPO_OUT_OL` | DRF Transfer of Process Order |
| `ZCL_P_DCB_DRF_GNEPRORD_FLT` | DRF Filter for Process Order |
| `ZCL_P_DCB_DRF_GNEPRORD_OUT` | DRF Transfer of GNE Process Order |
| `ZCL_DRF_REF_PROCORD_FLTR` | DRF Filter for Process Order |
| `ZCL_DRF_REF_PROCORD_OUT` | DRF Transfer of Process Order |

## Product version with BOM

| Class |
|---|
| `ZCL_DRF_REF_PRODVER_OUT` |
| `ZCL_P_DCB_DRF_PRODVER_FLTR` |

---

## Implementation steps

### How the GT process order → MES outbound works (DRF)

**Which classes:** no class has "GT" in its name. The notes call the standard interface AIF_NS / AIF_IFNAME the "GT S/4 MES Interfaces", and that is `ZCL_DRF_REF_PROCORD_FLTR` + `ZCL_DRF_REF_PROCORD_OUT` ("DRF Transfer of Process Order"). The BL, GNE and BIO process order classes are site-specific copies of it. If you meant one of those, tell me and I'll do that one.

**What it sends:** a released process order with only the operations and phases that MES may receive. It's sent as `PPINT_MFGORD_EXECT_REQ_V2` through AIF namespace AIF_NS, interface AIF_IFNAME, logical port AIF_LOGICAL_PORT.

**Key:** `COMES_S_DRF_PROD_KEY`, which is just `AUFNR`.

**Central config table:** `Zp_po_rt`. Each row is plant + order type + PHSEQ (control recipe destination) + business system, with an optional NO_SEND flag. An empty PHSEQ is a wildcard.

**The DRF framework calls the methods in this order:**

1. **Step 1: initialize**
   - Creates the instance and stores it in the class attribute `mo_drf_mes_procord_out`, which the other methods read their runtime parameters from.
   - Returns the key table type `tt_key_table`.

2. **Step 2: Finding which orders changed** — the class has two ways to do this.

   - **A. `analyze_changes_by_chg_pointer`** (message type `P1T_MES_MFGORD_EXE_REQ_OUT`, object class `ORDER`):
     - Removes duplicate pointers per object, then takes the AUFNR from pointers on table AFVU (operation user fields), CLASSIF or CLASSIFY (classification, added under ticket).
     - Keeps only orders that appear in CDS `ZP_S_PROCORD_FLT1` with mes = receiver, meaning at least one operation is routed to this MES system.
     - Calls `change_is_valid_for_drf` for each order. The order is only added to `ct_changed_objects` if that returns a reason.
     - It reads the order with `BAPI_PROCORD_GET_DETAIL` (header, phases, components).
     - Blocks the order if its status is GLOCK, TECO or CUST_LOCK (system or user status). It must also be REL or PREL (messages 022 and 023).
     - It compares the order with what was last sent, using the AIF index `ZP_DCB_AIF_1` and the stored copies of the last message:
       - `ZP_DCB_PO_S` (header)
       - `ZP_DCB_PO_58` (operations)
       - `ZP_DCB_PO_60` (components)
     - These set a reason, so the order is sent:
       - It was never sent before (message 032).
       - The BAPI failed, which forces a send.
       - A stored copy of the last message is missing (message 008).
       - A routed operation isn't in the last message, or has no phase (messages 029 and 030).
     - These only write a log message and don't trigger a send: changes to total quantity, basic or scheduled dates, phase resources (031), or component material, batch, quantity or unit (015–028). They were switched off on .

   - **B. `analyze_changes_by_others`** (time-based delta):
     - Takes orders with status changes since yesterday (`ZP_S_DCB_PROCORD_JCDS`).
     - Marks an order as changed if its latest status change is newer than its latest AIF send to this business system.

3. **Step 3: `enrich_filter_criteria`**
   - Adds MES = receiver business system to the external criteria on `ZP_S_PROCORD_FLT1`. This is what limits manual DRFOUT runs to the receiver.

4. **Step 4: Filter, FLTR->apply_filter**
   - Builds two dynamic WHERE clauses:
     - The object filter is one group per key line, joined with OR. Its fields are AUFNR, AUART, WERKS, PLNBEZ, SFCPF, DISPO, MES and the basic and scheduled dates and times. Values with `*` or `+` become LIKE.
     - The external filter comes from the selection screen and the criteria added in Step 3 (`FREE_SELECTIONS_RANGE_2_WHERE`).
   - Authority check on object `ZP_DRF`: activity 16, plus application, outbound implementation and receiver (). If it fails, it logs error 062 and stops.
   - Selects candidates in two passes, up to 5,000 orders each:
     - `ZP_S_PROCORD_FLT1` joins operations to `Zp_po_rt` on plant, order type and PHSEQ, or on plant and order type for wildcard rows. It drops NO_SEND rows and applies both WHERE clauses.
     - `ZP_S_PROCORD_FLT2` covers the XStep/PI-sheet operations (`…_OPER_COFT`), joined on plant and PHSEQ only. It applies only the object filter.
   - Re-checks the combined list against FLT1 with both clauses (fix ), so an order found only through FLT2 must still pass FLT1. If both passes found nothing, it logs message 002.

5. **Step 5: `read_complete_data`**
   - Order data is read in bulk for the whole package:
     - In bypass-filter run mode, it calls the filter itself.
     - Calls `CO_DB_ORDER_PRE_READ`, then the standard buffer reads: header (CAUFV), items (AFPO), sequences (AFFL), operations (AFVG), components (RESB); serial numbers (`GET_SERNOS_OF_DOCUMENT`) and relationships (`NW_BT_AFAB_OF_ORDER`); production resources/tools assignments (`CF_BT_CO_AFFHD_TAB_GET`).
   - Reads the active statuses of each order (`STATUS_READ`) and their short texts (TJ02T) into `mt_jstat_by_aufnr`.
   - Reads the operation user fields (AFVU), activity types (AFVC) and standard values (AFVV).

6. **Step 6: `map_data2message`** (once per order)
   - Cuts the buffers down to this order and gets the plant time zone of the MES system.
   - Fills in PHSEQ for XStep operations: if an operation has no PHSEQ, it's taken from `…_OPER_COFT`, but only if the destination exists in TC52 with type 3.
   - Operation filter, using `Zp_po_rt` for this plant, order type and receiver:
     - Wildcards are ignored when any specific rule exists.
     - A phase is kept if its PHSEQ has a rule. Its operation number and its parent operation go into `tobesent_oprs`; the parent comes from `BAPI_PROCORD_GET_DETAIL`.
     - An operation follows its parent phase's rule.
     - Everything not in `tobesent_oprs` is removed. Phases and operations whose rule is NO_SEND are then removed too.
     - Removing an operation also removes its sequences, relationships and production resource assignments.
     - If nothing is left, it logs warning 010 and returns.
   - Status filter: only operations with status I0002 (released) stay. Their release date and time come from JCDS. If none are left, it logs warning 011. If the order is flagged for deletion, it logs warning 013. Either way it returns.
   - Standard mapping: `CL_PPINT_SOA_MFG_ORD_MAPPING->map_mfgorder_v2`.
   - Customer additions to the message:
     - Business system, and the cost center or WBS element from the order's settlement rule (COBRB).
     - Long text with extra quantity (`get_exqty_orderltext`).
     - BOM and recipe ECNs (SAENR / PAENR), production supervisor, priority and run ID.
     - Key-value pairs LeadingOrder and SuperiorOrder.
     - Campaign (PCMP).
     - Commercial units throughout, goods receipt quantity on the items, standard value parameter texts (`TCN01_READ`) and standard text key.
     - On components: ECN, fixed quantity, scrap %, bulk indicator, and the custom fields FIELD_MLTBTCH_RES and FIELD_WEIGHING_TP_RES ().
     - Times converted to the plant time zone. Empty times become 240000.
     - "Freshly released" flag: `crtd_rel_flag = X` on each operation that hasn't been sent since it was released (checked against the AIF log).
     - Removes the StartEvent and EndEvent nodes and their relationships.

7. **Step 7: `send_message`** (once per order)
   - Returns straight away if the standard MES BAdI says nothing changed (`CL_IM_CO_MES_INTEGRATION->get_data_change_flag( )` is initial) or if the message is empty.
   - Builds a new message header with the creation time converted to UTC and the receiver.
   - `order_status_is_valid_for_drf`: if the order is TECO, GLOCK or CUST_LOCK, it clears the message and logs warning 012.
   - Writes AIF log message 019, then calls `/AIF/SEND_WITH_PROXY`. On success:
     - adds AIF message 19;
     - calls `set_distribution_status`, which is switched off and does nothing;
     - runs `COMMIT WORK AND WAIT`.
   - Writes the XI message GUID to the DRF log and AIF log message 020, and sets the replication status to SN.

### How the Production Version → MES outbound works (DRF)

These two classes form one DRF replication. It sends production versions (MKAL), each with its master recipe and BOM header, from S/4 to MES through AIF (namespace AIF_NS, interface AIF_IFNAME_PV).

- `ZCL_P_DCB_DRF_PRODVER_FLTR` implements `IF_DRF_FILTER`. It decides which PVs go to which MES system.
- `ZCL_DRF_REF_PRODVER_OUT` implements `IF_DRF_OUTBOUND`. It finds what changed, reads the data, builds the message and sends it.

**The object key everywhere is `ZP_DCB_DRF_S_PRODVERS_KEY`, made of MATNR, WERKS and VERID.**

**The DRF framework (DRFOUT or change-pointer processing) calls the methods in this order:**

1. **Step 1: initialize**
   - Creates a new instance of the outbound class.
   - Copies the runtime parameters into it: application, business system, run mode, test-run flag and log.
   - Tells DRF the key table type is `ZP_DCB_DRF_T_PRODVERS_KEY`.
   - Sets the key date to today and keeps a pointer to the application log.

2. **Step 2: `analyze_changes_by_chg_pointer`** (delta/change-pointer runs only)
   - It turns raw change pointers into a list of affected PV keys.
   - Removes duplicate pointers that have the same object class, object ID, table and table key, then sorts them by table. The log gets one section per table, with one message 011 per pointer.
   - Works out the affected PVs for each change-document object:

     | Object class / table | Path to the affected PVs |
     |---|---|
     | MATERIAL / DMKAL | Takes MATNR, WERKS and VERID straight from the pointer key |
     | PLAN / MAPL | MAPL → MKAL (matching group and group counter) |
     | PLAN / PLMZ | PLMZ → MAPL → MKAL |
     | PLAN / PLPO | PLPO → PLAS → PLKO → MAPL (same plant) → MKAL |
     | PLAN / PLKZ | PLKZ → PLAS → PLKO → MAPL → MKAL |
     | STUE_V / CSBOM | MAST (production usage 1) → MKAL → MKAL_AEND, kept only where the change number matches the pointer |
     | STUE / STKO, STPO, STAS, STZU | (STAS → STKO →) MAST, production usage 1 → MKAL (matching BOM alternative) |
     | AENNR_S4H / AEOI | Skips change-number pointers that aren't type 2. Nothing else is done with them. |

   - Every PV it finds is logged (messages 018 and 020–026) with the key attached as the log object.
   - Builds the result: removes duplicate keys, then keeps only those found in CDS `ZP_S_DCB_PRODVER_FLT_AENN2`. What's left becomes `ct_changed_objects`.

3. **Step 3: Filter, FLTR->apply_filter**
   - DRF calls this for the changed objects, or for the manual selection in DRFOUT.
   - Builds two dynamic WHERE clauses:
     - The object filter is one (MATNR = … AND WERKS = … AND VERID = …) group per key, joined with OR. Values containing `*` or `+` become LIKE with `%` or `_`.
     - The external filter comes from the DRFOUT selection screen (structure `ZP_DCB_DRF_S_PRODVERS_FLT2`), converted with `FREE_SELECTIONS_RANGE_2_WHERE`.
   - Authority check on object `ZP_DRF`: activity 16, plus DRF application, outbound implementation and receiver (). If it fails, it logs error 062 in `ZP_DCB_PROCORD` and stops.
   - Checks the MES criterion. If the selection contains a MES value, it's renamed to BUSINESS_SYSTEM and checked against `ZP_S_DCB_PRODVER_DRF_MES`. If the current receiver isn't in the allowed list, it logs warning 007 and stops.
   - Selects the candidates from CDS `ZP_S_DCB_MKAL_PLAS_PLPO_RT`. It applies both WHERE clauses plus mes = `iv_business_system`, so only PVs routed to this MES system get through. The result is capped at 5,000 rows. If nothing is found, it logs message 002.
   - Re-reads `I_PRODUCTIONVERSION` for those keys to add the change number, and returns `et_filtered_objects`.

4. **Step 4: `read_complete_data`**
   - In bypass-filter run mode only, it calls the filter class itself (`get_filter( )->apply_filter`) with no external criteria.
   - Reads `I_PRODUCTIONVERSION` for the keys, keeping only PVs that are:
     - valid to today or later,
     - status 1,
     - BOM check status 1.
   - For each PV it builds a master-recipe key from the PV's routing group and counter (`billofoperationsgroup` / `billofoperationsvariant`) and calls `recipe_read_complete_data`:
     - Reads the recipe: `CL_PPPI_SOA_MASTER_RECIPE->get_details_cds` returns the headers, material assignment, activities, component allocations and relationships.
     - Trims component allocations:
       - Drops allocations that belong to another production version.
       - Drops allocations that end today and whose BOM item is flagged for deletion in `ZS_B_STAS` (fix ).
     - CRD check (which operations MES may receive):
       - Gets the order type from `ZP_S_DCB_MARC-CO_PRODPRF`.
       - Reads the routing rules from `Zp_po_rt` for that plant, order type and business system. Rules flagged NO_SEND go into a separate block list.
       - A phase is kept only if its PHSEQ has a rule. An operation is kept only if its parent phase's PHSEQ has a rule.
       - A wildcard rule (empty PHSEQ) allows everything except the NO_SEND entries. Wildcards are ignored when any specific rule exists.
       - Rejected operations are removed from the activities, from relationships in both directions and from component allocations.
       - If no operations are left, it logs warning 029.
     - Maps the result with `recipe_map_data_to_message` (about 1,100 lines adapted from SAP's standard recipe mapping) into `PPINT_MFG_MSTR_RCP_INFO_MSG`.
     - Stores everything in `mt_data_buffer`: the key, the full PV row and the recipe message.

5. **Step 5: `map_data2message`** (once per object)
   - Finds the object's entry in `mt_data_buffer`.
   - Converts the base unit to ISO and only continues if that succeeds. Units are then output in commercial format (language E).
   - Fills `PRODUCTION_VERSION_INFORMATION` with all PV fields: lot sizes, validity, routing, BOM alternative and usage, storage locations, warehouse, supply area and so on.
   - Copies the recipe's bill of operations for that VERID into the message.
   - Adds the message header from `get_business_header`: a new UUID, the UTC creation time, the sender from `LCR_GET_OWN_BUSINESS_SYSTEM`, and the receiver.
   - Adds the BOM header from `A_BILLOFMATERIAL`, using the BOMs whose validity overlaps the PV's:
     - Main BOM: expired BOMs are dropped. Of the rest, the one with the latest end date supplies the category, number, texts, quantity, unit and ECN (`bom_header_ecn`, fix ).
     - BOM_EXTRA_DATA: one segment per BOM version, sorted by start date. Each end date except the last is shifted back one day so the periods don't overlap. Only segments still valid today are kept (fixes  and ).
   - Stores the finished message in `mt_output_buffer`.

6. **Step 6: `send_message`** (once per object)
   - Gets the key from `ct_obj_rep_sta[1]` and the message from `mt_output_buffer`.
   - Skips anything that isn't a master recipe. If the routing type isn't 2, it logs warning 040 and returns, so no routing types other than master recipes are sent.
   - Only sends if both the PV block and the activity network are filled.
   - Sets the creation time again, converted from CET to UTC (WI ), and converts the material number to output format.
   - Unless it's a test run, it calls `/AIF/SEND_WITH_PROXY` with namespace AIF_NS, interface AIF_IFNAME_PV version 1, logical port AIF_LOGICAL_PORT_PV, and saves the XML. On success it writes the XI message GUID to the DRF log with `add_msg_xi`.
   - If the proxy raises an exception, it sets the replication status to SE and logs message 015 with the error text.

7. **Step 7: `finalize`**
   - Closes the log level and sets `ev_delete_change_pointer = true`, so the change pointers are used up.