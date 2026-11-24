**Document Information**

| **Document Name** | DS\_CN\_MA\_Production BOM Interface From S4H to ECMS |
| --- | --- |
| **Document Type** | Design Specification |
| **Document Location** | Electronically stored in SolMan ALM |
| **Associated Documents** | CG\_CN\_XF ECMS Integration  FS\_CN\_MA\_Production BOM interface to ECMS MW.docx  FS\_CN\_MA\_Production BOM to ECMS MW Attachment |

Document approval is done in Solution Manager. Please refer to the document history in Solution Manager for details.

| **DOCUMENT HISTORY** | |
| --- | --- |
| **Version** | **Changes** |
| 1.0 | First Approved version |
|  |  |

**Table of Contents Page**

[1.](#_heading=h.iv2yhwvvjnqf) Document Purpose and Scope 3

[2.](#_heading=h.q2kb0a48zpue) Definitions 3

[3.](#_heading=h.bm20ftn1txnt) Solution Design – Description 3

[3.1](#_heading=h.dj4bjijjuszq) Business Purpose 3

[3.2](#_heading=h.uaq4q24mulbk) High Level Overview 4

[3.3](#_heading=h.e4xt27e6ikb8) Solution Details 4

[3.3.1](#_heading=h.xxlybmcnxa5d) Implementation Details 4

[3.3.2](#_heading=h.fqtzzhi0llfj) Data Model 8

[3.3.3](#_heading=h.wjos7l2qfeb2) User Interface / Form Layout 9

[3.3.4](#_heading=h.bt9yttu4e9w6) Interface Details 9

[4.](#_heading=h.qw8jzkm9rep4) Solution Configuration Design 10

[4.1](#_heading=h.arz1y93o0c4z) Administrative Configuration Design 10

[4.2](#_heading=h.b3hydd30fe7f) Template Configuration Design 10

[4.3](#_heading=h.i2t1k7op42wd) Rollout Configuration Design 10

[5.](#_heading=h.awqjnb2kk5vt) Authorization 10

[6.](#_heading=h.3as4poj) Error Handling 11

[7.](#_heading=h.dvtr7fvw5sr1) Translation / Multi-Language Enablement 11

[8.](#_heading=h.fqycf39cwih4) Dependencies / Constraints / Assumptions 11

# Document Purpose and Scope

This document describes the implementation for replicating Production Bill of Materials (BOM) master data from SAP S/4HANA ERP to the Electronic Customs Management System (ECMS) via MuleSoft middleware. Its purpose is to specify the design of the solution, as described by the Functional Specification FS\_CN\_MA\_Production BOM Interface From S4H to ECMS.

The interface supports regulatory compliance, customs declaration, and manufacturing tracking for Roche Diagnostics Suzhou (RDSZ).

The scope of this document is as follows.

* SAP Data Replication Framework (DRF) outbound implementation for the Production BOM business object.
* DRF dictionary objects (object key structure, selection parameter structure and table type).
* DRF / AIF customizing (replication model, outbound implementation, AIF namespace and interface).
* Data extraction, ECN validation, message generation and message mapping.
* Message sending via Application Integration Framework (AIF) to MuleSoft middleware.
* AIF-based monitoring, error handling and user notification.

# Definitions

Commonly used terms and definitions can be found in Computerized System Glossary.
The additional terms and abbreviations that are used in this document are explained below.

| **Term** | **Definition** |
| --- | --- |
| S4H | SAP Business Suite 4 SAP HANA |
| ECMS | Electronic Customs Management System |
| BOM | Bill of Materials |
| DRF | Data Replication Framework |
| AIF | Application Integration Framework |
| ECN | Engineering Change Number |
| MW / MuleSoft | MuleSoft Middleware (canonical integration point) |
| API | Application Programming Interface |
| WSDL | Web Services Description Language |
| OData | Open Data Protocol |

# Solution Design – Description

## Business Purpose

* Replicate Production Bill of Materials (BOM) master data from SAP S/4HANA ERP to the Electronic Customs Management System (ECMS) through MuleSoft middleware.
* Govern the replication with the SAP Data Replication Framework (DRF) using scheduled nightly batch processing (transaction DRFOUT, daily 11:00 PM) while supporting on-demand manual triggers.
* Ensure regulatory compliance, customs declaration, and manufacturing tracking for Roche Diagnostics Suzhou.

## High Level Overview

* The interface is an **outbound** interface from S/4HANA. Production BOM data flows S/4HANA → MuleSoft → ECMS.
* The message distribution is based on SAP API and Web services technologies with a single message type valid for all ECMS destinations.
* The interface is implemented as a DRF outbound interface based on the merged Cust-Prod Bill of Material service **ZBOMReplReq\_CUST\_PROD** (WSDL **ZBOM\_REPLICATE\_REQ\_CUST\_PROD.WSDL** — manually created from the combined CUST + PROD BOM structure; MW has not yet provided an official WSDL). The merged service transports both Custom BOM and Production BOM fields; this implementation handles **Production BOMs only** (BOM usage = '1'). Custom BOMs (usage = 'X') are handled by a separate future implementation class.
* The message is sent as **one BOM per message** (single AIF send): one message carries one BOM header and its complete set of component items.
* MuleSoft is used as a standardized and canonical integration point. MuleSoft converts the API message to JSON and sends it to ECMS. All value transformations and filtering are done in SAP; MuleSoft performs only the technical message-to-message mapping.
* Monitoring is done with AIF standard tools; for each call a synchronous response (success or error) confirms processing back to the source system.
* DRF configuration: Replication Model **ZCN\_ECMS**, Outbound Implementation **ZDCN\_PBOM**.
* AIF configuration: Namespace **ZDECMS**, Interface Name **ZO\_PBOM**, Logical Port **ZECMSBOMOUT**.
* The message is sent through AIF using proxy `/AIF/SEND_WITH_PROXY`; the AIF namespace/interface is registered with the generated DDIC proxy structure `zzbomreplicate_request` (root sap\_struct, package $TMP).

## Solution Details

**Index of Important Objects**

| **Object type** | **Object Name** | **Object description** |
| --- | --- | --- |
| DRF Replication Model | ZCN\_ECMS | ECMS replication model |
| DRF Outbound Implementation | ZDCN\_PBOM | Production BOM outbound implementation |
| DRF Business Object | ZCN\_PBOM | Production BOM business object |
| DRF Object-Level Filter | ZCL\_MIT\_DCN\_DRF\_BOM\_OUT\_FLTR | Production BOM object-level filter (implements IF\_DRF\_FILTER) |
| Outbound Adapter Class | ZCL\_M1T\_DCN\_BOM\_OUT | DRF outbound adapter (implements IF\_DRF\_OUTBOUND) |
| Business Singleton Class | ZCL\_M1T\_DCN\_BOM2\_OUT\_IMPL | Production BOM business logic (merged Cust-Prod ZBOM implementation) |
| AIF Namespace | ZDECMS | AIF namespace for ECMS |
| AIF Interface | ZO\_PBOM | AIF outbound interface for Production BOM |
| Logical Port | ZECMSBOMOUT | AIF logical port / proxy to MuleSoft |
| Service | ZBOMReplReq\_CUST\_PROD | Merged Cust-Prod Bill of Material service (ZBOM\_REPLICATE\_REQ\_CUST\_PROD.WSDL) |
| AIF Proxy Structure | zzbomreplicate\_request | Generated DDIC proxy sap\_struct for /AIF/SEND\_WITH\_PROXY |

### Implementation Details

The DRF outbound implementation follows the recommended three-layer architecture: **filter + framework adapter (out) + business singleton (biz)**. This keeps the framework adapter thin and places all business logic in a testable business singleton.

**1. Dictionary Objects**

Object key structure – determines how to identify the DRF objects (BOM type / Plant / Material / BOM alternative / BOM category / ECN):

| **Field** | **Data element** | **Description** |
| --- | --- | --- |
| STLAN | STLAN | BOM usage (BOM type) |
| WERKS | WERKS\_D | Plant |
| MATNR | MATNR | Material |
| STLAL | STLAL | Alternative BOM |
| STLTY | STLTY | BOM category |
| AENNR | AENNR | Engineering change number (ECN) |
| STLNR | STNUM | BOM number (pre-fetched by filter, non-key field) |

Object key table type: SORTED TABLE with UNIQUE KEY **STLAN WERKS MATNR STLAL STLTY AENNR**.

Selection parameter structure and table type – determines the selection fields for DRF executions:

| **Field** | **Mandatory** | **Data element** | **Description** | **Comments** |
| --- | --- | --- | --- | --- |
| MAST-WERKS | YES | WERKS\_D | Plant Code | default=Q511 |
| MAST-MATNR | No | MATNR | Material ID | None |
| MAST-STLAN | YES | STLAN | BOM Usage | default=1 |
| MAST-STLAL | No | STLAL | Alternative BOM | None |
| STKO-DATUV | No | DATUV | Valid-From Date of Production BOM | None |
| STKO-DATUB | No | DATUB | Valid-To Date of Production BOM | None |

**2. DRF Customizing**

Configure the DRF outbound implementation ZDCN\_PBOM with:
* Business object ZCN\_PBOM (object key structure above).
* Outbound implementation ZDCN\_PBOM with implementation class ZCL\_M1T\_DCN\_BOM\_OUT (implements IF\_DRF\_OUTBOUND).
* Object-level filter class ZCL\_MIT\_DCN\_DRF\_BOM\_OUT\_FLTR (implements IF\_DRF\_FILTER).
* Replication model ZCN\_ECMS linking business object and outbound implementation.
* Package size = 1 (single object per package) to guarantee one message per object and avoid "last message only" packaging issues.

**3. Outbound Adapter Class (ZCL\_M1T\_DCN\_BOM\_OUT)**

A thin adapter that implements IF\_DRF\_OUTBOUND and forwards every lifecycle method to the business singleton (created once in INITIALIZE and reused for the whole run). The adapter carries no business logic.

In INITIALIZE it:
* Creates the business singleton and passes the runtime parameters (drf\_s\_runtime\_parameter\_ext).
* Sets `es_runtime_param_out_impl-table_type_name` to the business singleton's object key table type (`<BIZ>=>key_table_ty`).
* Sets `es_runtime_param_out_impl-package_size = 1` (single object per package).
* Returns the adapter instance to the framework.

Lifecycle methods forwarded: INITIALIZE, ANALYZE\_CHANGES\_BY\_CHG\_POINTER, ANALYZE\_CHANGES\_BY\_OTHERS, ENRICH\_FILTER\_CRITERIA, READ\_COMPLETE\_DATA, MAP\_DATA2MESSAGE, SEND\_MESSAGE, FINALIZE. Non-enabled methods (ANALYZE\_CHANGES\_BY\_MDG\_CP, APPLY\_NODE\_INST\_FILTER\_MULTI/SINGLE, BUILD\_PARALLEL\_PACKAGE) remain empty.

**4. Business Singleton Class (ZCL\_M1T\_DCN\_BOM2\_OUT\_IMPL)**

Contains all business logic for the merged Cust-Prod ZBOM implementation. Handles **Production BOMs only** (BOM usage = '1'); Custom BOMs ('X') are handled by a separate future implementation class.

* **ANALYZE\_CHANGES\_BY\_CHG\_POINTER** – change pointer mode. Parses the DRF change pointer table (DRF\_T\_BDCP) and resolves CDOBJID into object keys:
  * MAST change pointers: CDOBJID is built as MATNR(18) + WERKS(4) + STLAN(1) + STLAL(2) → offsets 0 / 18 / 22 / 23.
  * STKO / STPO change pointers: object-level trigger, CDOBJID+1(8) = BOM number (STLNR), used to reverse-lookup MAST (MATNR/WERKS/STLAN/STLAL) for the full object key.
  * Reverse-lookups MAST (STLNR) and STKO (STLTY/AENNR); validates ECN status; outputs the valid object keys.
* **ANALYZE\_CHANGES\_BY\_OTHERS** – initial / manual mode. When no change pointer exists, retrieves MAST by default conditions (plant Q511, BOM usage 1) with a row-count guard (maximum 1000, aligned with the FS volume cap; logs a warning when the limit is exceeded and an info message when below the minimum of 300).
* **ENRICH\_FILTER\_CRITERIA** – parses the screen selection criteria (rsds\_trange) into WERKS / MATNR / STLAN / STLAL / DATUV / DATUB; fills the mandatory defaults (plant Q511, BOM usage 1); rebuilds the external criteria for MAST (WERKS/MATNR/STLAN/STLAL) and STKO (DATUV/VALID\_TO).
* **READ\_COMPLETE\_DATA** – bulk read of the BOM data into memory buffers:
  * Applies the object-level filter when the run mode bypasses filtering.
  * STKO: INNER JOIN with the BOM number set, restricted to **STLTY = 'M'** (Production BOM category), **LKENZ <> 'X'** (not deleted), **STLST = '01'** (active status), and the **validity window** from the screen selection (DATUV IN selection / valid\_to IN selection).
  * STPO: INNER JOIN with the BOM number set, restricted to **STLTY = 'M'** and **LKENZ <> 'X'**.
  * STAS: item selection nodes, restricted to **STLTY = 'M'**.
  * MARA: bulk read for the header and component units (FOR ALL ENTRIES with empty-table guard).
* **MAP\_DATA2MESSAGE** – per object, resolves the BOM header (STKO), the item selection nodes (STAS → STLKN), and the component lines (STPO), maps them to the local message buffer (header + items), then builds the ZBOM AIF message via BUILD\_AIF\_MESSAGE.
* **SEND\_MESSAGE** – validates mandatory fields, overrides the message creation date/time at send time, and sends the message to MuleSoft via AIF (/AIF/SEND\_WITH\_PROXY) as a single AIF send per BOM.
* **FINALIZE** – controls change pointer deletion (ev\_delete\_change\_pointer = true when there are no erroneous objects and the run is not a repeated initial run) and writes run statistics.

**5. Object-Level Filter (ZCL\_MIT\_DCN\_DRF\_BOM\_OUT\_FLTR)**

Implements IF\_DRF\_FILTER. Filters candidate objects to those the target system cares about:
* Builds a dynamic WHERE from the object conditions and external criteria (rsds\_trange via FREE\_SELECTIONS\_RANGE\_2\_WHERE, filter selection structure ZMCN\_BOM\_DRF\_FLTR\_S); uses cl\_abap\_dyn\_prg=>quote for injection-safe quoting, with LIKE (escaped \* / +) for wildcards and EQ otherwise.
* Reverse-checks existence in MAST (matnr/werks/stlan/stlal) and pre-fetches STLNR (BOM number) so the business singleton avoids re-reading MAST.
* Explicitly deduplicates the candidate list (STANDARD table + SORT + DELETE ADJACENT DUPLICATES) and applies a row-count guard (5000) with an application-log warning at the limit.
* Date screening is intentionally not part of the filter (the selection structure holds only MAST columns); validity dates are enforced in the business layer (READ\_COMPLETE\_DATA).
* The DRFOUT authorization check is defined but not enabled (a BOM-specific authorization object must be created to enable it).

**6. ECN Validation**

ECN (Engineering Change Number) is the effective switch for BOM / master data: only a released ECN is allowed outbound.
* Extract AENNR and DATUV from STKO (header) / STPO (item); pass AENNR as the change number (ID19 CHANGE\_NO) in the outbound payload.
* Filter out BOM changes attached to unreleased or blocked ECNs by checking **AENR.AENST = '2'** (released). AENR main key = MANDT + AENNR (unique); status field = AENST; no plant dimension.
* Batch preload AENR status once per analyze pass (eliminates N+1) and validate in memory; the number of filtered objects is reported to the application log.
* Effective date handling: the BOM header start date (ID21 HEADER\_START\_DATE) is always set from STKO-DATUV and the item start date (ID06 VALID\_FROM) from STPO-DATUV. A future effective date (DATUV > SY-DATUM) is therefore always carried in the payload, letting the target system schedule the cut-over locally.

**7. Message Generation**

Extraction logic evaluates active BOMs based on the scheduled batch filters and effective validity dates. The interface is triggered in three ways:

| **Type** | **Trigger** | **Frequency** | **Filter** |
| --- | --- | --- | --- |
| Initial | Manual (DRFOUT) | Not relevant | Plant, BOM Usage |
| Scheduled Nightly Batch | Nightly Job (DRFOUT) | Every night 11:00 PM | Material, Plant, BOM Usage, Valid-To Date, Valid-From Date (API mode Change, change pointer active) |
| Manual Ad-Hoc | Manual (DRFOUT) | On-Demand | Material, Plant, BOM Usage, ECN, Valid-To Date, Valid-From Date |

**8. Message Sending**

The message is sent as **one BOM per message** (single AIF send per BOM): one message carries one BOM header and its complete set of component items. There is no 2000-line XML splitting.

* The message is built into the generated DDIC proxy structure `zzbomreplicate_request` (the AIF sap\_struct) via BUILD\_AIF\_MESSAGE.
* Proxy controller flags (PRXCTRLTAB) are set at every level (root, parameters, message\_header, bom, bomheader, bomcomponent) so the proxy runtime serializes the populated fields.
* The message header is built by BUILD\_BUSINESS\_HEADER: id/uuid (UUID C32 via cl\_system\_uuid), creation\_date\_time (system time → UTC → proxy datetime via cl\_bs\_soa\_convert\_xsddatetime), sender\_business\_system\_id (LCR\_GET\_OWN\_BUSINESS\_SYSTEM), recipient\_business\_system\_id (from the runtime parameter). The creation date/time is overridden at send time (CET → UTC via convert\_timestamp).
* Field conversions: material via CONVERSION\_EXIT\_MATN1\_OUTPUT (internal → external format); unit via CONVERSION\_EXIT\_CUNIT\_OUTPUT (internal → commercial format) with leading/trailing space trim.
* Sending: `/AIF/SEND\_WITH\_PROXY` (ns / ifname / ifversion / logical port / iv\_persist\_xml = 'X'), with TRY/CATCH for cx\_bs\_soa\_exception and cx\_ai\_system\_fault; a PERSISTENCY\_ERROR (sy-subrc = 1) is tolerated; business errors in the return table are checked.
* After sending: object-level AIF log association (add\_msg\_xi) and replication status write-back (repstatus = 'SN' on success, 'SE' on error).

**9. Mandatory Field Validation**

Before sending, the implementation validates mandatory fields and raises an error (business object type `BILL_OF_MATERIAL`, message `ZDCN_PBOM` / `001`) when a BOM header or item is incomplete:
* Mandatory header fields: MATERIAL (ID01), HEADER\_QTY (ID23).
* Mandatory item fields: COMPONENT\_MATNR (ID03), QUANTITY (ID04), OPERATION\_SCRAP (ID25), COMPONENT\_SCRAP (ID26); scrap values must be non-negative.

**10. Data Access and Validation**

There are no sensitive or legal requirements. The interface needs an immediate response from the interface provider (MuleSoft):
* Successful message: message successfully passed via MuleSoft; no specific sending sequence is required.
* Unsuccessful message: message failed in MuleSoft or from MuleSoft to ECMS.

**11. Message Transformation and Enrichment**

The message content is mapped to the ECMS fields; the ECMS data format is captured. Source field vs. target field mapping is done in MuleSoft. Once the XML is created it must be mapped to JSON (mapping described in the associated MW attachment documents).

### Data Model

The data model is the outbound message structure (header + items) based on the merged Cust-Prod ZBOM service `ZBOMReplReq_CUST_PROD`. Fields are classified as **[COMMON]** (sent for both Cust and Prod BOMs), **[PROD]** (Production BOM only) and **[CUST]** (Custom BOM only).

**This implementation handles Production BOMs only (BOM usage = '1') and populates the [PROD] + [COMMON] fields. [CUST]-specific fields are NOT populated by this class and are handled by a separate future Custom BOM implementation class.**

| **ID** | **Source API field** | **Cust/Prod** | **Destination structure** | **TYPE** | **M / O** | **NOTES / FIELD DESCRIPTION** |
| --- | --- | --- | --- | --- | --- | --- |
| ID01 | MATERIAL | [COMMON] | copExgNo | CHAR 40 | M | BOM Header material including FG/SEMI (MAST-MATNR) |
| ID02 | BOM\_VERSION | [CUST] | bomVersion | CHAR 8 | M | Custom Logic (Custom field) - NOT sent by this class |
| ID03 | COMPONENT\_MATNR | [COMMON] | copImgNo | CHAR 40 | M | BOM Item material / components (STPO-IDNRK) |
| ID04 | QUANTITY | [COMMON] | decCm | DEC(13,3) | M | Component quantity (STPO-MENGE) |
| ID05 | COMPONENT\_UNIT | [COMMON] | copImgUnit | UNIT 3 | O | Components UoM / customs unit (STPO-MEINS) |
| ID06 | VALID\_FROM | [COMMON] | startDate | DATS 8 | M | Components validate start date (YYYYMMDD) (STPO-DATUV) |
| ID07 | VALID\_TO | [COMMON] | endDate | DATS 8 | O | Components validate end date (YYYYMMDD) (STPO-valid\_to) |
| ID08 | BondMark1 | [CUST] | bondMark1 | CHAR 2 | M | Custom Logic (Custom field) - NOT sent by this class |
| ID09 | BondMark2 | [CUST] | bondMark2 | CHAR 2 | M | Custom Logic (Custom field) - NOT sent by this class |
| ID10 | note | [CUST] | note | CHAR 50 | O | No Logic, Send Blank (Custom field) - NOT sent by this class |
| ID11 | PLANT | [COMMON] | plant | CHAR 4 | M | Plant (MAST-WERKS) |
| ID12 | note2 | [CUST] | note2 | CHAR 50 | O | No Logic, Send Blank (Custom field) - NOT sent by this class |
| ID13 | BOM\_Type | [CUST] | bomType | CHAR 1 | M | Custom Logic (Always Send 0) - NOT sent by this class |
| ID14 | Batch\_NO. | [CUST] | batchNo | CHAR 10 | O | No Logic, Send Blank (Custom field) - NOT sent by this class |
| ID15 | HEADER\_UNIT | [COMMON] | copExgUnit | UNIT 3 | O | UoM of finished/semi-finished goods (MARA-MEINS) |
| ID16 | BOM\_CREATION | [PROD] | bomCreation | DATS 8 | O | BOM creation date (STKO-ANDAT) |
| ID17 | ALTERNATIVE\_BOM | [PROD] | alternativeBom | CHAR 2 | O | Alternative BOM number (MAST-STLAL) |
| ID18 | BOM\_NO | [PROD] | bomNo | CHAR 8 | O | Number of BOM (MAST-STLNR) |
| ID19 | CHANGE\_NO | [PROD] | changeNo | CHAR 12 | O | Engineering Change Number (STKO-AENNR) |
| ID20 | BOM\_USAGE | [PROD] | useTo | CHAR 1 | O | BOM usage; this class always sends '1' (Production BOM) |
| ID21 | HEADER\_START\_DATE | [PROD] | bomStartDate | DATS 8 | O | BOM header validate start date (YYYYMMDD) (STKO-DATUV) |
| ID22 | HEADER\_END\_DATE | [PROD] | bomEndDate | DATS 8 | O | BOM header validate end date (YYYYMMDD) (STKO-valid\_to) |
| ID23 | HEADER\_QTY | [PROD] | copExgQty | DEC(13,3) | M | BOM header Qty (STKO-BMENG) |
| ID24 | COMPONENT\_UNIT | [PROD] | copImgUnit | UNIT 3 | O | Component UoM (STPO-MEINS) - duplicate of ID05, excluded |
| ID25 | OPERATION\_SCRAP | [PROD] | OperationScrap | DEC(5,2) | M | Operation scrap % or Qty (STPO-AVOAU) |
| ID26 | COMPONENT\_SCRAP | [PROD] | ComponentScrap | DEC(5,2) | M | Components scrap % or Qty (STPO-AUSCH) |

The BOM header additionally carries **BOMCategory** (the Production BOM category, STKO-STLTY = 'M').

> **Note:** `ZBOM_REPLICATE_REQ_CUST_PROD.WSDL` was manually created from the combined CUST + PROD BOM structure (MW has not yet provided an official WSDL). The message structure / field mapping above and the generated AIF proxy structure (`zzbomreplicate_request`) are provisional and must be re-verified (proxy re-generated) once MW provides the official WSDL.

> **Note:** In SAP the message is populated into the ZBOM proxy structure (`zzbomreplicate_request` → `parameters` → `bom` → `bomheader` / `bomcomponent[]`) using the ZBOM WSDL element names (e.g. `material`, `plant`, `bill_of_material`, `bill_of_material_component`, `bill_of_material_item_quantity`). The **Destination structure** column lists the ECMS-side target field names (e.g. `copExgNo`, `decCm`, `copImgUnit`) that MuleSoft maps the ZBOM message to.

The message structure reflects the fields mapped in the document "FS\_CN\_DL\_Production\_BOM\_to\_ECMS\_MW\_Attachment 0.2".

### User Interface / Form Layout

N/A (No User Interface / Form Layout is in the scope of this development)

### Interface Details

| **Interface Name** | **BOM SAP to ECMS interface** |
| --- | --- |
| Direction (with respect to S4H) | **Outbound** - Interface data flows outbound from S4H to middleware and finishing in ECMS system |
| Interface Usage Type | Interface is triggered either **manually or in a background job based on change pointers** |
| Interface Frequency | Scheduled Nightly Batch (Every night 11:00 PM) for automatic incremental updates; On-Demand for manual execution |
| Type of Records Sent | **MANUAL EXECUTION: Full record load** - Send all records that fulfill the selection criteria every time interface is executed. Filtering criteria (implemented in DRF): Production plant, Material, BOM usage, Alternative BOM number, BOM version valid from date. **AUTOMATIC EXECUTION: Full record load** - Send all records that fulfill the selection criteria set in the Job variants. |
| Volume (Per single execution) | **Average Volume:** 300 doc's / day  **Peak Volume:** 1000 doc's / day |

| **DRF** | Replication Model: ZCN\_ECMS  Outbound Implementation: ZDCN\_PBOM |
| --- | --- |
| **AIF** | Namespace: ZDECMS  Interface Name: ZO\_PBOM  Additional selection criteria: Material (MATNR), Plant (WERKS), BOM usage (STLAN), Alternative BOM Number (STLAL) |

**AIF configuration**: the outbound implementation sends through the merged Cust-Prod ZBOM service `ZBOMReplReq_CUST_PROD` via `/AIF/SEND_WITH_PROXY` (single AIF send per BOM). The AIF namespace / interface / logical port are configured as **ZDECMS** / **ZO\_PBOM** / **ZECMSBOMOUT**. The AIF namespace/interface is registered with the generated DDIC proxy structure `zzbomreplicate_request` (root sap_struct, package $TMP).

# Solution Configuration Design

The DRF and AIF configuration is maintained as follows:

| **Component** | **Configuration** |
| --- | --- |
| DRF Replication Model | ZCN\_ECMS |
| DRF Outbound Implementation | ZDCN\_PBOM |
| DRF Business Object | ZCN\_PBOM |
| DRF Object-Level Filter | ZCL\_MIT\_DCN\_DRF\_BOM\_OUT\_FLTR |
| DRF Filter Selection Structure | ZMCN\_BOM\_DRF\_FLTR\_S (matnr / werks / stlan / stlal / stlnr) |
| AIF Namespace | ZDECMS |
| AIF Interface Name | ZO\_PBOM |
| AIF Logical Port | ZECMSBOMOUT |
| AIF Proxy Structure | zzbomreplicate\_request (package $TMP) |
| AIF Service | ZBOMReplReq\_CUST\_PROD |
| AIF Additional Selection Criteria | Material (MATNR), Plant (WERKS), BOM usage (STLAN), Alternative BOM Number (STLAL) |

## Administrative Configuration Design

DRF and AIF customizing is set up as part of the DRF / AIF configuration steps (customizing transactions for DRF outbound implementation and AIF namespace / interface). Selection parameters are maintained in the Job variants for the nightly batch (plant default Q511, BOM usage default 1). Detailed AIF core configuration is covered in the document CG\_CN\_XF ECMS Integration.

## Template Configuration Design

N/A (No Template Configuration Design is in scope of this development)

## Rollout Configuration Design

This interface is leveraged to carry out data load during the site rollout cut-over phase – **Yes**.

| Sites where this load applies | RDSZ |
| --- | --- |
| Minimum Load expected (volume of records) | 300/Day |
| Maximum Load expected (volume of record) | 1000/Day |
| Any other comments | n/a |

# Authorization

* Manual triggering: manual triggering must be done with DRF (transaction DRF\_OUT) under authorization based on SAP Plant code (Auth Object: M\_MATE\_WRK).
* An authorization object is required to restrict AIF monitoring on a field level – ECMS destination system.
* A BOM-specific authorization object is defined for the DRFOUT object-level filter but is not enabled in the current implementation (a BOM-specific authorization object must be created to enable it).

# Error Handling

Error handling must be able to track any problem during the whole interface process, from message generation to ECMS reception:

* Errors in DRF message generation.
* Errors sending to MuleSoft.
* Errors in MuleSoft processing.
* Errors sending from MuleSoft to ECMS.
* Errors in ECMS processing.

In any case of the above errors the sender system (S4H) is informed with the error code and details (Production BOM, wrong value, etc.) and an error log is generated:

* The interface-related error log is maintained in MuleSoft for 21 days.
* The correction of the message content is not allowed in the target system in case of errors.

Error handling is done in AIF functionality; here all the errors in the interface are collected and classified. Errors must be detailed enough to be analyzed by AIF monitoring enhancement, and classifiable by:
* ECMS destination system.
* Error type.
* Material.
* Plant.
* Field and value (if relevant).

The error received in AIF includes:
* Object: Production BOM (mandatory), and depending on the error context, detailed objects attached to the message log: Parent Material (MATNR), Plant (WERKS Q511), Component Item (IDNRK), Engineering Change Number (AENNR/ECN).
* Error code: technical code defining the error type.
* Error description: description text for the error code.
* Error details: failed field, values and other technical information carried from ECMS and/or MuleSoft.

**As-built validation** (before sending): the implementation validates mandatory fields at send time and raises an error (business object type `BILL_OF_MATERIAL`, error message `ZDCN_PBOM` / `001`) when a BOM header or item is incomplete. Mandatory header fields: MATERIAL (ID01) and HEADER\_QTY (ID23). Mandatory item fields: COMPONENT\_MATNR (ID03), QUANTITY (ID04), OPERATION\_SCRAP (ID25) and COMPONENT\_SCRAP (ID26) (scrap values must be non-negative). An AIF send failure (a non-zero return other than the tolerated PERSISTENCY\_ERROR, or a business error in the AIF return table) is also reported with message `ZDCN_PBOM` / `001`; a SOA/system fault (`cx\_bs\_soa\_exception` / `cx\_ai\_system\_fault`) is logged with the DRF message `S015(DRF\_OUTBOUND)`.

**If errors show up, the Production BOM is resent by manually triggering DRFOUT instead of reprocessing the message from AIF.**

# Translation / Multi-Language Enablement

Output Language, language of template, and flexibility to print in desired language.

| **Language** | **Relevant** |
| --- | --- |
| English | ☑ |
| German | ☐ |
| French | ☐ |
| Spanish | ☐ |
| Portuguese | ☐ |
| Italian | ☐ |
| Russian | ☐ |
| Chinese | ☐ |
| Thai | ☐ |
| Others (please specify) |  |

# Dependencies / Constraints / Assumptions

* This interface is implemented as a DRF outbound interface based on the merged Cust-Prod Bill of Material service `ZBOMReplReq_CUST_PROD` (WSDL `ZBOM_REPLICATE_REQ_CUST_PROD.WSDL`). The merged service transports both Custom BOM and Production BOM fields; this implementation handles **Production BOMs only** (BOM usage = '1'). Custom BOMs (usage = 'X') are handled by a separate future implementation class.
* **The WSDL `ZBOM_REPLICATE_REQ_CUST_PROD.WSDL` was manually created based on the combined CUST + PROD BOM structure; MuleSoft (MW) has not yet provided an official WSDL.** The message structure / field mapping and the generated AIF proxy structure (`zzbomreplicate_request`) are therefore **provisional** and must be re-verified (and the DDIC proxy re-generated) once MW provides the official WSDL.
* The message is sent as **one BOM per message** (single AIF send): one message carries one BOM header and its complete set of component items. There is no 2000-line XML splitting.
* The AIF namespace / interface / logical port are configured as **ZDECMS** / **ZO\_PBOM** / **ZECMSBOMOUT**.
* MuleSoft is used as a standardized and canonical integration point; all value transformations and filtering are done in SAP, and MuleSoft performs only the technical message-to-message mapping.
* Data transformation is done in DRF; field-mapping API to B2MML is done in the Middleware system (see document "FS\_CN\_DL\_Production\_BOM\_to\_ECMS\_MW\_Attachment 0.2").
* Single site (RDSZ) applies for this interface.
* The E2E synchronous response time is expected to be less than 60 seconds.
* The interface-related error log is maintained in MuleSoft for 21 days.
* Complete audit history is recorded via DRF outbound execution logs and AIF message logs.
* Correction of the message content is not allowed in the target system in case of errors.
