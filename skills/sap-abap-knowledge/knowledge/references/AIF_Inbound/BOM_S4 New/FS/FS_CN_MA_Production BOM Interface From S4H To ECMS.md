**Document Information**

| **Document Name** | FS\_CN\_MA\_Production BOM Interface From S4H to ECMS |
| --- | --- |
| **Document Type** | Functional Specification |
| **Document Location** | Electronically stored in Solman ALM |
| **Associated Documents** | CG\_CN\_XF ECMS Integration  FS\_CN\_MA\_Production BOM interface to ECMS MW.docx  FS\_CN\_MA\_Production BOM to ECMS MW Attachment |

Document approval is done in Solution Manager. Please refer to the document history in Solution Manager for details.

| **DOCUMENT HISTORY** | |
| --- | --- |
| **Version** | **Changes** |
| 1.0 | First Approved version |
|  |  |

**Table of Contents Page**

[**1.**](#_heading=h.iv2yhwvvjnqf) **Purpose 1**

[**2.**](#_heading=h.q2kb0a48zpue) **Definition 2**

[**3.**](#_heading=h.bm20ftn1txnt) **Template Considerations 2**

[**4.**](#_heading=h.jinu7t34qi3u) **Type of Development 3**

[4.1](#_heading=h.dj4bjijjuszq) Interface 3

[4.1.1](#_heading=h.uaq4q24mulbk) Business Object 3

[4.1.2](#_heading=h.e4xt27e6ikb8) Integration logic 4

[4.1.2.1](#_heading=h.xxlybmcnxa5d) Message generation 5

[4.1.2.2](#_heading=h.fqtzzhi0llfj) Message structure 5

[4.1.2.3](#_heading=h.wjos7l2qfeb2) DRF Distribution 6

[4.1.2.4](#_heading=h.bt9yttu4e9w6) DRF technical details 7

[4.1.3](#_heading=h.qw8jzkm9rep4) Field Mapping 8

[4.1.4](#_heading=h.arz1y93o0c4z) Data Access and Validation 8

[4.1.5](#_heading=h.b3hydd30fe7f) Message Transformation and Enrichment 8

[4.1.6](#_heading=h.i2t1k7op42wd) Confirmation & Error Handling 8

[4.1.7](#_heading=h.awqjnb2kk5vt) Data load requirement during site rollout 9

[4.2](#_heading=h.3as4poj) Language/ Translation 10

[**5.**](#_heading=h.dvtr7fvw5sr1) **Cross Functional 10**

[5.1](#_heading=h.fqycf39cwih4) Authorization 10

[5.2](#_heading=h.hxiz08deawui) Security 10

[5.3](#_heading=h.t1w11999fpqj) Error Handling or Monitoring 10

[5.4](#_heading=h.89oq4m3hmah6) Monitoring 10

[5.5](#_heading=h.j5wz9esm8vvx) Performance 11

[5.6](#_heading=h.p464lvkgvxz) Archiving 11

[5.7](#_heading=h.y32mgqgxvpq9) Audit Trail 11

[5.8](#_heading=h.3f0v1zauf9lt) Electronic Signature 11

[5.9](#_heading=h.t3821ccmiy7x) ICFR 11

[**6.**](#_heading=h.5kco3dnfnxw4) **Testing Considerations 11**

# Purpose

The purpose of this Functional Specification is to detail the technical design and functional requirements for replicating Production Bill of Materials (BOM) master data from SAP S/4HANA ERP to the Electronic Customs Management System (ECMS) via MuleSoft middleware. This interface supports regulatory compliance, customs declaration, and manufacturing tracking for Roche Diagnostics Suzhou.

To ensure high scalability, scheduled batch execution, and alignment with Roche S/4HANA standard architecture, data replication is governed by SAP Data Replication Framework (DRF) utilizing scheduled nightly batch processing via transaction DRFOUT while supporting on-demand manual triggers.

![](data:image/png;base64...)

Fig (1) S4H-ECMS Integration channels

This document covers production Bom flow between S4H and ECMS systems.

* The message distribution is based on SAP API and Web services technologies with only one message type valid for all ECMS destinations.
* The API and Web Services connection to MuleSoft. MuleSoft will be used as a standardized and canonical integration point.
* MuleSoft message adaptation and distribution it to ECMS systems. (this is covered in “FS\_CN\_DL\_Production BOM interface to ECMS MW interface MW” document.

This FS is written in accordance with the following reference process.

| **Process level** | **Number** | **Description** |
| --- | --- | --- |
| L4 | 13.9.1.253 | Maintain Discrete Mfg. Master Data (Routings, BoM, PV) |

Tab(1). L4 process

| **Sr.No** | **Req. ID** | **Description** |
| --- | --- | --- |
| 1 | 44893 | S4H to ECMS Production BOM interface |

Tab(2). IT Requirement information

# Definition

See [<u>CSV Glossary</u>](https://sites.google.com/roche.com/risk-based-csv/pharma-it-csv-glosssary) (at Global IT Glossary).

Additionally, the following additional terms and abbreviations are used in this document:

| **Term** | **Definition** |
| --- | --- |
| ECMS | Electronic Customs Management System |

Tab(3). Definition

# Template Considerations

| **Selection** | **Expected WRICEF usage** |
| --- | --- |
| ☐ | *Multi Site* |
| ☒ | *Single Site* |

Tab(4). WRICEF Usage

# Type of Development

| **Selection** | **Type of Development** |
| --- | --- |
| ☐ | *Enhancement* |
| ☒ | *Interface* |
| ☐ | *Report* |
| ☐ | *Workflow* |
| ☐ | *Form* |
| ☐ | *Conversion* |

Tab(5). Type of Development

## Interface

### Business Object

Roche uses S/4HANA as a leading system during transferring Production Bills of Materials (BOMs) to the ECMS system in the Roche landscape. Since Production BOM data flows from S/4HANA to the ECMS system, it is an outbound interface from the S/4HANA system perspective.

The interface is triggered for the replication of Production BOMs in S/4HANA. The fields identified for distribution, data format, and mapping are available in the referenced documents.

![](data:image/png;base64...)

Fig (2) Message structure and APi’s

| **Interface Name** | **BOM SAP to ECMS interface** |
| --- | --- |
| Direction (with respect to S4H) | **Outbound** - Interface data flows outbound from S4H to middleware and finishing in ECMS system |
| Interface Usage Type | Interface is triggered either **manually or in a background job based on change pointers** |
| Interface Frequency | Scheduled Nightly Batch (Every night 11:00 PM) for automatic incremental updates; On-Demand for manual execution |
| Type of Records Sent | **MANUAL EXECUTION: Full record load** - Send all records that fulfill the selection criteria every time interface is executed. Transferring can be executed with the following filtering criteria, these criteria will be implemented in DRF functionality:   * Production plant * Material * Bom usage * Alternative BOM Number * BOM version valid from date   **AUTOMATIC EXECUTION**: **Full record load** - Send all records that fulfill the selection criteria setting in the Job variants. |
| Volume  (Per single execution) | **Average Volume:** 300 doc’s / day  **Peak Volume:**  1000 doc’s / day |

Tab (3) Interface overview

Detailed information about DRF and AIF logic is available in ECMS CG: **CG\_CN\_XF ECMS Integration**

Specific for this object, we need to have this configured:

| DRF | Replication Model: ZCN\_ECMS  Outbound Implementation:ZDCN\_PBOM |
| --- | --- |
| AIF | Namespace: ZDECMS  Interface Name: ZO\_PBOM  Additional selection criteria:  Material (MATNR)  Plant (WERKS)  Bom usage (STLAN)  Alternative BOM Number(STLAL) |

### Integration logic

The figure below shows the main integration step.

1. This interface will leverage the SAP standard interface to replicate Bom <u>“</u> [<u>Bill of Material API (API\_BILL\_OF\_MATERIAL\_SRV;v=2)</u>](https://help.sap.com/docs/SAP_S4HANA_ON-PREMISE/9f047b05da4545ca8f9ebfc22acefd06/ac29c05833e44980ab6b236e409f2429.html?q=API_BILL_OF_MATERIAL_SRV)<u>”</u> with required enhancement detailed in this document.
2. The XML must be split into a maximum of 2000 lines per XML.
   E.g. if the total stock balance is 3999 lines, we need to perform 2 API calls of 2000 lines and 1999 lines.
3. Once in the middleware (MuleSoft) the API message will be converted to JSON structure and sent to the ECMS system. All the value transformations and filtering will be done in SAP. MuleSoft will do only the technical mapping from message to message.
4. If #2 is true, also add the fact that ECMS will do the combination
5. For each call there will be a response confirming the processing or error to the source system. ECMS will confirm MuleSoft and MuleSoft will confirm SAP. Monitoring will be done with AIF standard tools.

![](data:image/png;base64...)

![](data:image/png;base64...)

Fig (3) S4H-ECMS Production BOM integration details

### Message generation

Production BOM interface will be executed during scheduled nightly batch runs or via on-demand manual triggers. Extraction logic evaluates active BOMs based on scheduled batch filters and effective validity dates.

The production BOM interface can be triggered in two ways:

| **Type** | **Trigger** | **Frequency** | **Filter** | **Description** |
| --- | --- | --- | --- | --- |
| Initial | Manual (DRFOUT) | Not relevant | * Plant * Bom Usage | Sends all matching BOMs for system cutover or initial sync. |
| Scheduled Nightly Batch | Nightly Job (DRFOUT) | Every night 11:00 PM | * Material * Plant * Bom Usage * Valid-To Date * Valid-From Date | Send all production Bom included in user selection with change pointer active.  This functionality will be executed with API mode Change |
| Manual Ad-Hoc | Manual (DRFOUT) | On-Demand | * Material * Plant * Bom Usage * ECN * Valid-To Date * Valid-From Date | Immediate ad-hoc push for urgent production needs without altering job variant. |

Tab (4). Triggering methods

**DRF change point:**

DRF selection and filtering will evaluate the relevant engineering change number (ECN) and object key definitions.

| **Changed object** | **Selection Key** |
| --- | --- |
| Bill of materials | Bill of materials type  Plant  Material  Bill of materials alternative  Engineering change number |

In the table below there are described all changes to a production BOM and the interface triggering:

* Change : indicates the object and main action executed
* Update / Create Bom:
  + “C”: create object
  + “U”: update object
* ECN required: indicates if an engineering change number is required to do the action.

| **Change** | **Update/Create BOM?** | **ECN required** | **Interface trigger** | **Comment** |
| --- | --- | --- | --- | --- |
| **<u>BoM</u>** | --- | --- | --- | --- |
| ***Header*** | --- | --- | --- | --- |
| Change Base Quantity | U | Yes | Yes | Change in table STKO fields: BMENG and BMEIN |
| Change valid-from date | U | Yes | Yes | Change in table STKO fields: DATUV a |
| Change valid-to date | U | Yes | Yes | Change in table STKO fields: DATUB |
| ***Item*** | --- | --- | --- | --- |
| Change component quantity or UoM of component | U | Yes | Yes | Change in table STPO fields: MEINS and MENGE |
| Add additional component / change component / remove component | U | Yes | Yes | new entry in STPO |
| Change-valid from or valid-to date of component | U | Yes | Yes | New entry in STPO, change in STPO-DATUV and STPO-AENNR |
| Change component scrap | U | Yes | Yes | Change in table STPO fields: AUSCH |
| Change operation scrap | U | Yes | Yes | Change in table STPO fields: AVOAU |

### Message structure

| **ID** | **Source API field** | **Destination structure** | **TYPE** | **M / O** | **NOTES / FIELD DESCRIPTION** |
| --- | --- | --- | --- | --- | --- |
| ID01 | MATERIAL | copExgNo | CHAR 40 | M | BOM Header material including FG/SEMI (MAST-MATNR) |
| ID02 | COMPONENT\_MATNR | copImgNo | CHAR 40 | M | BOM Item material / components (STPO-IDNRK) |
| ID03 | QUANTITY | decCm | DEC(13,3) | M | Component quantity (STPO-MENGE) |
| ID04 | VALID\_FROM | startDate | DATS 8 | O | Components validate start date (YYYYMMDD) (STPO-DATUV) |
| ID05 | VALID\_TO | endDate | DATS 8 | O | Components validate end date (YYYYMMDD) (STPO-DATUB) |
| ID06 | BOM\_CREATION | bomCreation | DATS 8 | O | BOM creation date (STKO-ANDAT) |
| ID07 | ALTERNATIVE\_BOM | alternativeBom | CHAR 2 | O | Alternative BOM number (MAST-STLAL) |
| ID08 | BOM\_NO | bomNo | CHAR 8 | O | Number of BOM (MAST-STLNR) |
| ID09 | CHANGE\_NO | changeNo | CHAR 12 | O | Engineering Change Number (AENR-AENNR) |
| ID10 | BOM\_USAGE | useTo | CHAR 1 | O | BOM usage (MAST-STLAN) |
| ID11 | HEADER\_START\_DATE | bomStartDate | DATS 8 | O | BOM header validate start date (YYYYMMDD) (STKO-DATUV) |
| ID12 | HEADER\_END\_DATE | bomEndDate | DATS 8 | O | BOM header validate end date (YYYYMMDD) (STKO-DATUB) |
| ID13 | HEADER\_QTY | copExgQty | DEC(13,3) | M | BOM header Qty (STKO-BMENG) |
| ID14 | HEADER\_UNIT | copExgUnit | UNIT 3 | O | UoM of finished/semi-finished goods (MARA-MEINS) |
| ID15 | COMPONENT\_UNIT | copImgUnit | UNIT 3 | O | Components UoM / customs unit (STPO-MEINS) |
| ID16 | OPERATION\_SCRAP | OperationScrap | DEC(5,2) | M | Operation scrap % or Qty (STPO-AUSCH) |
| ID17 | COMPONENT\_SCRAP | ComponentScrap | DEC(5,2) | M | Components scrap % or Qty (STPO-KAUSF) |

The message structure will reflect the fields mapped, see document

“*FS\_CN\_DL\_Production\_BOM\_to\_ECMS\_MW\_Attachment 0.2”*

#### 1、ECN (Engineering Change Number) Handling Logic in DRF

During batch extraction, the outbound service mapping logic evaluates ECN attributes and validity dates for transmission:

1. **ECN Field Mapping**:
   * Extract AENNR (Engineering Change Number) and DATUV (Valid-From Date) directly from STKO (Header) / STPO (Item).
   * Pass AENNR as the ChangeMasterID / ECN\_Number in the outbound API payload.
2. **ECN Status Verification**:
   * Filter out BOM changes attached to unreleased or blocked ECNs (Check ECN status in AENR).
3. **Future Effective Date Handling**:
   * DRF extracts the BOM structure based on the targeted evaluation date (default: SY-DATUM).
   * If a BOM modification carries an ECN with a future effective date (DATUV > SY-DATUM), pass DATUV explicitly in the payload so the target system can schedule the cut-over locally.

### DRF technical details

In order to set up a distribution scenario within DRF, there are 2 main steps needed

* Create the necessary dictionary objects:
  + object key structure: determines how to identify the DRF objects
  + Selection parameter: determines the selection fields for DRF executions
* Do the necessary customizing in DRF

The DRF implementation will follow these guidelines:

Object key structure:

Selection parameter structure and table type:

| **Field** | **Mandatory** | **Data element** | **Description** | **Comments** |
| --- | --- | --- | --- | --- |
| MAST-WERKS | YES | WERKS\_D | Plant Code | default=Q511 |
| MAST-MATNR | No | MATNR | Material ID | None |
| MAST-STLAN | YES | STLAN | BOM Usage | default=1 |
| MAST-STLAL | No | STLAL | Alternative BOM | None |
| STKO-DATUV | No | DATUV | Valid-To Date of Production BOM | None |
| STKO-DATUB | No | DATUB | Valid-From Date of Production BOM | None |

### Field Mapping

Data transformation will be done in DRF and Field-mapping API to B2MML will be done in the Middleware system. See document “FS\_CN\_DL\_Production\_BOM\_to\_ECMS\_MW\_Attachment 0.2”

### Data Access and Validation

For the desired interface, there would not be any sensitive or legal requirement.

This interface needs an immediate response from the interface provider (Mule soft)

* Successful message: - Message successfully passed via Mule soft and no specific sending sequence is required
* Unsuccessful message: - Message failed in Mule soft or from Mulesoft to ECMS.

### Message Transformation and Enrichment

* The content of the message needs mapping with ECMS system field.
* The ECMS system data format is captured.
* The Mapping of source fields vs target fields is required and will be done in Mule soft.

Once XML is created, it must be mapped to JSON format. This mapping is described in FS\_CN\_MA\_Production BOM interface to ECMS MW.docx.

### Confirmation & Error Handling

Error handling must be able to track any problem during all interface process, form message generation to ECMS reception:

* Errors in DRF message generation
* Errors sending to Mulesoft
* Errors in Mulesoft processing
* Errors sending from Mulesoft to ECMS
* Errors in ECMS processing

In any case of one of the above errors the sender system (S4H) should be informed with the error code and details (Production BOM, wrong value….) and an error log will be generated.

* The interfaced-related errors Log needs to be maintained in Mule soft for 21 days.
* The correction of the message content is not allowed in the target system in case of errors.

Error handling will be done in AIF functionality; here all the errors in the interface will be collected and classified. Errors must be detailed enough to be analyzed by AIF monitoring enhancement. This means must be possible to classify errors by:

* ECMS destination system
* Error type
* Material
* Plant
* Field and value (if relevant)

The error received in AIF will include:

* The error received in AIF will include: Object: Production BOM is mandatory, and depending on the specific error context, detailed objects attached to the message log will include: Parent Material (MATNR), Plant (WERKS Q511), Component Item (IDNRK), and Engineering Change Number (AENNR/ECN).
* Error code: technical code defining the error type
* Error description: description text for error code
* Error details: failed field, values and other technical information that can be carried from ECMS and/or Mulesoft.

**If the errors show up, will resend Production Bom again by manually triggering the DRFOUT instead of reprocessing the message from AIF.**

### Data load requirement during site rollout

Will this interface be leveraged to carry out data load during the site rollout cut over phase? - Yes

| Sites where this load applies | RDSZ |
| --- | --- |
| Minimum Load expected (volume of records) | 300/Day |
| Maximum Load expected (volume of record) | 1000/Day |
| Any other comments | n/a |

## Language/ Translation

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

Tab. Language Translation

# Cross Functional

## Authorization

Specific authorization cases:

* Manual triggering: manual triggering must be done with DRF (transaction DRF\_OUT) under authorization based on :
  + SAP Plant code (Auth Object:M\_MATE\_WRK)
* It is required to create an authorization object to restrict AIF monitoring on a Field level –ECMS destination system.

## Security

Not relevant (There are no security requirements relevant for this interface)

## Error Handling or Monitoring

Below are some of the errors to be included

* Connection error - Should start processing in the similar way once the connection is established back again
* Missing field error - Error message should clearly define the details of the field missing and once the field is corrected it should be processed accordingly
* Data pairing – Data should be paired properly in middleware
* Filter criteria and Logic- Filter criteria and logic should be defined in Middleware level.

## Monitoring

SAP AIF is a standard component in ERP that allows interface monitoring and alerting for this specific interface by IT and/or business personnel (error reprocessing is handled via DRFOUT re-execution rather than direct reprocessing in AIF).

* Using SAP AIF as a single access point for all interface monitoring by Business and IT. Integration will provide feedback (Green or Red) for all applications, whether S/4HANA or ECMS (via MuleSoft synchronous response). If needed, ECMS / MuleSoft should enhance functionality to provide such status feedback.
* Have the capability to reprocess failed messages, collective & individually including resending outbound messages.

![https://lh5.googleusercontent.com/JypMNNgErHYjpTlRud41yo4phH2OWtzf2rd7dHrrOnAeENY0BeulspbBDYSYpTK8EgjZ058OvIhcwmnAJzEZufEcCSZeSeHqPDZsZ5XxwVBxJdzA3v_C9gUVVoTTZHh3KYL0TIY](data:image/png;base64...)

* The below architecture and workflow describes an example of a Production BOM replication from S/4HANA ERP to ECMS and the potential fail points where the message can encounter an error. SAP AIF will provide support to identify and resolve such error

![](data:image/png;base64...)

Fig (4): Error handling

AIF core configuration is covered in the document CG\_CN\_XF ECMS Integration

**USER NOTIFICATIONS**

The system should be prepared to send notifications to facilitate the monitoring (mail and SAP alert system) containing:

* Interface type/interface name
* ECMS system source/destination
* A dynamic text providing instructions based on the error code received.
* GUID to identify the error
* Link to the error message via /AIF/ERR

Emails can be routed to individual accounts, generic accounts or user groups based on:

1. Interface type/interface name
2. ECMS system source/destination
3. Error type

## Performance

The E2E synchronous response time is expected to be less than 60 seconds.

## Archiving

Not relevant (There are no archiving requirements relevant for this interface).

## Audit Trail

Complete audit history recorded via DRF outbound execution logs and AIF message logs.

## Electronic Signature

Not relevant (There are no electronic signature requirements relevant for this interface)

## ICFR

Not relevant (There are no ICFR requirements relevant for this interface)

# Testing Considerations

| **Test case** | **Expected Result** |
| --- | --- |
| **Scenario 1: Send data from foreground** | |
| Execute the process in foreground manually (DRFOUT) | 1.Data could be replicated to MIddleware  2.Data is sent to ECMS system from Middleware  2.Successful message can be received  3.Log is correctly recorded |
| **Scenario 2: Send data in Background** | |
| Execute scheduled background job (DRFOUT) | 1.Data could be replicated to MIddleware  2.Data is sent to ECMS system from Middleware  2.Successful message can be received  3.Log is correctly recorded |
| **Scenario 3: Send data in Foreground/background** | |
| Execute job/transaction across foreground and background modes | 1.Data fail to replicated to ECMS  2.Error message received  3.Log is correctly recorded |
| **Scenario 4: Reexecute the process in Foreground/background** | |
| Reexecute failed or existing process via DRFOUT in foreground/background mode | 1.Data is successfully replicated  2.Successful message can be received  3.Log is correctly recorded |

Tab. Test cases