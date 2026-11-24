**Document Information**

| **Document Name** | FS\_0C\_AS Automatic WO Email Notification |
| --- | --- |
| **Document Type** | Functional Specification |
| **Document Location** | Electronically stored in SolMan ALM |
| **Associated Documents** | NA |

Document approval is done in Solution Manager. Please refer to the document history in Solution Manager for details.

| **DOCUMENT HISTORY** | |
| --- | --- |
| **Version** | **Changes** |
| 1.0 | First Approved version |
|  |  |

**Table of Contents Page**

[1. Purpose 3](#_heading=h.kikpkxk1k8mr)

[2. Definitions 3](#_heading=h.bvt1vx6xl2b)

[3. Template Considerations 4](#_heading=h.az4z5k8zxjt5)

[4. Type of Development 4](#_heading=h.wvmo01c20jiq)

[4.1 Enhancement 5](#_heading=h.e3a4mily6u02)

[4.1.1 Program Logic 5](#_heading=h.jdbc6oehhen6)

[4.1.2 Actors / User Groups 6](#_heading=h.5gmuoih12hso)

[4.1.3 Use Cases List 6](#_heading=h.v9aaa7nnbv6z)

[4.1.3.1 New Function / Change to Function 6](#_heading=h.ff18v7nbt226)

[4.1.3.2 New / Enhanced Screen 7](#_heading=h.izwgdh265iej)

[4.1.4 Input Validation 7](#_heading=h.wnccm9mxwy9b)

[4.1.5 Assumptions / Business Rules / Constraints 7](#_heading=h.vcac7i33ve4b)

[4.2 Language/Translation 8](#_heading=h.9jgu3ih1cwoy)

[5. Cross Functional 9](#_heading=h.3s1sdn9m9r)

[5.1 Authorisation 9](#_heading=h.o0pbdh9f2hix)

[5.2 Security 9](#_heading=h.a1wt1jrl014j)

[5.3 Error Handling or Monitoring 9](#_heading=h.xfxyhdfqxrj7)

[5.4 Performance 9](#_heading=h.yru7cils5x2s)

[5.5 Archiving 9](#_heading=h.hx76b0dk8ud4)

[5.6 Audit Trail 9](#_heading=h.ho778audexm5)

[5.7 Electronic Signature 9](#_heading=h.ucnb2vgqa1t)

[5.8 ICFR 9](#_heading=h.8ing9ihu5wox)

[6. Testing Considerations 9](#_heading=h.ytw6pg97hkgx)

# Purpose

This Functional Specification defines the requirements for automating real-time notifications when Basic Finish Dated is changed within Maintenance work orders.

Specifically, this enhancement triggers an automated email and SAP Fiori Launchpad notification to the System Owner whenever the Basic Finish Date of a YPM1 or YPM2 maintenance order is extended to a later date and saved in change mode.

The desired functionality relates to the process mentioned in Table 1.

| **Process level** | **Number** | **Description** |
| --- | --- | --- |
| L4 | 10.3.1.5 | Plan Maintenance |
| L5 | 210 | Re-Plan Work Order |
|  |  |  |
|  |  |  |

Table 1: Reference to Process and Process step in SolMan.

ITRequirement – This Enhancement relates to the requirement mentioned in Table 2

| **Requirement ID** | **Description** |
| --- | --- |
| 45441 | Order Basic finish date change email |
|  |  |

Table 2: Reference to Requirement ID in SolMan.

# Definitions

See [<u>CSV Glossary</u>](https://sites.google.com/roche.com/risk-based-csv/pharma-it-csv-glosssary) (at Global IT Glossary).

Additionally, the following additional terms and abbreviations are used in this document:

| **Term** | **Definition** |
| --- | --- |
| GUI | Graphical User Interface |
| App | Application |
| BAPI | Business Application Programming Interface |
| BAdI | Business Add-Ins |
| EFR | Roche Enhancement Framework |

# Template Considerations

| **Selection** | **Expected WRICEF usage** |
| --- | --- |
| ☑ | *Multi Site* |
| ☐ | *Single Site* |

# Type of Development

| **Selection** | **Type of Development** |
| --- | --- |
| ☑ | *Enhancement* |
| ☐ | *Interface* |
| ☐ | *Report* |
| ☐ | *Workflow* |
| ☐ | *Form* |
| ☐ | *Conversion* |

## Enhancement

### Program Logic

![](data:image/png;base64...)

Figure 1: Program Logic

Assumptions:

1. The enhancement logic will exclusively evaluate Plant Maintenance orders, filtered by Order Category AUTYP = 30.
2. Processing is restricted to Maintenance Order Types AUART = YPM1 and YPM4 where the Technical Object’s ABC Indicator is set to ABCKZ = A (indicating GMP relevance).
3. EFR Framework will be configured with a dedicated Application Identifier and parameter values maintained as follows:

* Order Category (AUTYP): 30
* Order Types (AUART): YPM1, YPM4
* ABC Indicator (ABCKZ): A

1. Notifications will trigger solely when an existing order's Basic Finish Date (GLTRP) is updated and saved in change mode. Initial order creation will be explicitly excluded from this logic.
2. The notification recipient will be determined dynamically based on the System Owner assigned to the Equipment master record. Notifications will be dispatched concurrently via external email (Gmail) and as an in-app notification within the SAP Fiori Launchpad.

### Actors / User Groups

| **Sr. No** | **Actor/User** | **Expected Actions** |
| --- | --- | --- |
| 1 | Maintenance Planner | Whenever the maintenance planner extends the Basic Finish Date (GLTRP) of a maintenance order (Type YPM1 or YPM2) in change mode and saves the order. |
|  |  |  |

### Use Cases List

Upon saving a work order, the system automatically dispatches notifications whenever the Basic Finish Date is modified on orders matching the specified Order Type and ABC Indicator rules defined in the EFR framework.

#### Function

BAPI\_ALM\_ORDER\_GET\_DETAIL: BAPI used to get maintenance order details

BAPI\_EMPLOYEE\_GETDATA: BAPI used to get asset owner email details

This functionality will be executed only for the **maintenance order types** which are listed in the **Roche Enhancement Framework** (**EFR**) - transaction /RGS/S\_EFR\_CUST to maintain the parameters.

* Order Category (AUTYP): 30
* Order Types (AUART): YPM1, YPM4
* ABC Indicator (ABCKZ): A

When a Maintenance Planner modifies the **Basic Finish Date** (AFKO-GLTRP) of an eligible Plant Maintenance order in change mode and saves the order, the system must validate the order against the EFR framework parameters. If all conditions are met, the system will dynamically identify the **Asset System Owner** assigned to the linked Equipment and dispatch both an email notification and an SAP Fiori Launchpad notification.

##### Change Detection & Event Trigger

##### Upon saving the maintenance order in change mode, check if the Basic Finish Date (AFKO-GLTRP) has been updated to a future/extended date compared to the previous state.

##### If GLTRP has not been modified (or modified to an earlier/same date), terminate notification processing and proceed with standard order save.

1. Order Validation against EFR Framework
   * Call function module BAPI\_ALM\_ORDER\_GET\_DETAIL passing the Order Number (AUFNR) as the input parameter to retrieve order details.
   * Read the retrieved Order Type (AUART) and the assigned Equipment's ABC Indicator (ABCKZ).
   * Compare AUART and ABCKZ against the parameter table entries maintained in the EFR Framework.
   * If matched, proceed to the next step. If mismatched, save the order successfully without triggering any email or Fiori notifications.
2. Recipient Identification
   * Query table AUFK with the Order Number (AUFK-AUFNR = AFKO-AUFNR) to retrieve the Object Number (AUFK-OBJNR).
   * Query table IHPA using the Object Number (IHPA-OBJNR = AUFK-OBJNR) to fetch partner details.
   * Filter IHPA table to select the Partner Number (IHPA-PARNR) where Partner Function IHPA-PARVW = YS (Asset System Owner).
   * Pass the retrieved Partner Number (IHPA-PARNR) into the EMPLOYEE\_ID parameter of BAPI\_EMPLOYEE\_GETDATA and retrieve the user's communication details (Email address)
3. Trigger Notification
   * **Email Notification:** Construct and send an email to the System Owner's email address using the defined Email Template (see template details below).
   * **Fiori Launchpad Notification:** Push an in-app notification to the System Owner's Fiori Launchpad Inbox / Notification Center.

**Email Format:**

Subject: [Action Required] Basic Finish Date Updated for Maintenance Order {AUFNR}

Dear System Owner,
Please be advised that the Basic Finish Date for Maintenance Order {AUFNR} has been updated.
Order Details:

* Work Order Number: {AUFNR}
* Order Type: {AUART}
* Equipment: {EQUNR} - {EQKTX}
* New Basic Finish Date: {GLTRP}
* Changed By: {UNAME}

Please access the SAP Fiori Launchpad to review the updated order details.

#### New / Enhanced Screen

There is no new screen in this enhancement.

### Input Validation

There are no inputs from the user. The necessary details are fetched from the work order & EFR parameters. Hence there is no requirement for input validation in this enhancement.

### Assumptions / Business Rules / Constraints

* This enhancement is applicable for respective values configured in EFR parameters.
* This enhancement is applicable only for the following Applications / Program:-
  + Change Maintenance Order -> EAMS\_WDA\_ORDNTF\_OIF
  + GUI transaction -> IW32

## Language/Translation

N/A

# Cross Functional

## Authorisation

N/A (There are no specific Authorization requirements foreseen for this requirement).

## Security

N/A (There are no specific security requirements foreseen for this requirement).

## Error Handling or Monitoring

N/A (There are no specific error handling or monitoring foreseen for this requirement).

## Performance

N/A There are no specific requirements for performance. The performance will be the same as the original apps.

## Archiving

N/A (There is no requirement for Archiving).

## Audit Trail

N/A (There are no Audit Trial needs foreseen).

## Electronic Signature

N/A (There is no requirement for an electronic signature).

## ICFR

N/A (There are no ICFR requirements for this step).

# Testing Considerations

These are the data consideration and set up requirements:-

* Equipment records exist with both target (ABCKZ = A) and non-target (ABCKZ ≠ A) ABC Indicators
* In-Scope / Target Scenario: Maintenance Orders (YPM1 & YPM4) assigned to Equipment with ABC Indicator A. (Expectation: Trigger Notification)
* Out-of-Scope (Order Type Match, ABC Mismatch): Maintenance Orders (YPM1 & YPM4) assigned to Equipment with ABC Indicator other than A. (Expectation: No Trigger)
* Out-of-Scope (ABC Match, Order Type Mismatch): Maintenance Orders of types other than YPM1 & YPM4 assigned to Equipment with ABC Indicator A. (Expectation: No Trigger)
* Out-of-Scope (Full Mismatch): Maintenance Orders of types other than YPM1 & YPM4 assigned to Equipment with ABC Indicator other than A. (Expectation: No Trigger)

**Test Case**

| **Sr. No** | **Test Scenario** | **Expected Results** |
| --- | --- | --- |
| 1 | Initial Order Creation (In-Scope Order & Equipment) | 1. Order is created successfully. 2. No email or Fiori notification is triggered during creation. |
| 2 | Update Basic Finish Date to a Future Date (In-Scope) | 1. Change is saved successfully. 2. Email notification sent to the Equipment's System Owner. 3. Notification appears in Fiori Inbox/Notification Center. |
| 3 | Save Order in Change Mode *Without* Modifying Finish Date | 1. Order updates successfully. 2. No notification triggered (date change requirement not met) |
| 4 | Out-of-Scope Order Type (AUART ≠ YPM1/YPM2) | 1. Order updates successfully. 2. No notification triggered (Order Type out of scope) |
| 5 | Out-of-Scope ABC Indicator (ABCKZ ≠ A) | 1. Order updates successfully. 2. No notification triggered (Order Type out of scope) |

Table 1: Testing considerations