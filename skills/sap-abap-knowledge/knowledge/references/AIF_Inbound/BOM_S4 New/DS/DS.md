**Document Information**

| **Document Name** | DS\_0C\_AS Automatic WO Email Notification |
| --- | --- |
| **Document Type** | Design Specification |
| **Document Location** | Electronically stored in SolMan ALM |
| **Associated Documents** | No Associated documents |

Document approval is done in Solution Manager. Please refer to the document history in Solution Manager for details.

| **DOCUMENT HISTORY** | |
| --- | --- |
| **Version** | **Changes** |
| 1.0 | First Approved version WP 8000670257 / WI 3200042150 |

**Table of Contents Page**

[1.](#_heading=h.gx3ca6pz6023) Document Purpose and Scope 3

[2.](#_heading=h.m4cnl29kkv4u) Definitions 3

[3.](#_heading=h.1nhb12jbglix) Solution Design – Description 3

[3.1](#_heading=h.ynmzxstp9o4w) Business Purpose 3

[3.2](#_heading=h.ijvtb940ejex) High Level Overview 3

[3.3](#_heading=h.x4ve5oams9gg) Solution Details 3

[3.3.1](#_heading=h.t6eugyp3tvv2) Implementation Details 4

[3.3.2](#_heading=h.1jx5znbqn4mr) Data Model 5

[3.3.3](#_heading=h.14wsc16gyf9t) User Interface / Form Layout 5

[3.3.4](#_heading=h.w6qtmtalaahb) Interface Details 5

[4.](#_heading=h.ydsd7z787zzq) Solution Configuration Design 5

[4.1](#_heading=h.qg6w8lsoh182) Administrative Configuration Design 5

[4.2](#_heading=h.b0gyl8n3x7rt) Template Configuration Design 5

[4.3](#_heading=h.exl5wbmd3v1) Rollout Configuration Design 5

[5.](#_heading=h.2z0ydq6znih9) Authorization 5

[6.](#_heading=h.jy8jlzfyv1aa) Error Handling 6

[7.](#_heading=h.rx8drzuk4q8) Translation / Multi-Language Enablement 6

[8.](#_heading=h.juousqxm5lhy) Dependencies / Constraints / Assumptions 6

# Document Purpose and Scope

This document describes the implementation for automating real-time notifications when Basic Finish Dated is changed within Maintenance work orders. Its purpose is to specify the design of the solution, as described by the Functional Specification FS\_0C\_AS Automatic WO Email Notification.

The scope of this document is as follows.

* User exit for Maintenance work order change.
* EFR application and parameter ID
* FM for fetch data for send notification and email
* Classes and methods for send notification and email.

# Definitions

Commonly used terms and definitions can be found in Computerized System Glossary.
The additional terms and abbreviations that are used in this document are explained below.

| **Term** | **Definition** |
| --- | --- |
| S4H | SAP Business Suite 4 SAP HANA |
| WO | Work Order |
| EFR | Roche Enhancement Framework |
| OData | Open Data Protocol |
| DMS | Document Management System |

# Solution Design – Description

## Business Purpose

* Implement an enhancement triggers an automated email and SAP Fiori Launchpad notification to the System Owner whenever the Basic Finish Date of a YPM1 or YPM4 maintenance order is extended to a later date and saved in change mode.

## High Level Overview

* In SAP enhancement IWO10009, component EXIT\_SAPLCOIH\_009, implement an enhancement /RGS/I\_JCA\_WO\_CHANGE\_NOTIF.
* EFR application ID /RGS/I\_JCA\_WO\_CHANGE\_NOTIFICATION

Parameter ID ‘CONDITION’

Parameter ID ‘SWERK’

* Wrapper FM /RGS/I\_JCA\_WO\_SEND\_NOTIF
* Create Class /RGS/CL\_I\_JCA\_WO\_CHANGE\_NOTI

Method WO\_SEND\_NOTIFICATION

Method WO\_SEND\_MAIL

* Provider ID /RGS/I\_JCA\_WO\_NOTIFPROVIDER and Provider Class /RGS/CL\_I\_JCA\_WO\_NOTIFPROVIDER

## Solution Details

**Index of Important Objects**

| **Object type** | **Object Name** | **Object description** |
| --- | --- | --- |
| Package | /RGS/I\_JCA\_PLANT\_MAINTENANCE | 10.3.1.5 Plan Maintenance |
| Enhancement Implementation | /RGS/I\_JCA\_WO\_CHANGE\_NOTIF | Enhancment implementation for auto send notification |
| Function Module | /RGS/I\_JCA\_WO\_SEND\_NOTIF | WO change notification |
| Class | /RGS/CL\_I\_JCA\_WO\_CHANGE\_NOTI | Work order change notification |
| Class | /RGS/CL\_I\_JCA\_WO\_NOTIFPROVIDER | WO notification provider class |

### Implementation Details

1. SMOD – SAP Enhancements IWO10009, FM EXIT\_SAPLCOIH\_009, ENHANCEMENT /RGS/I\_JCA\_WO\_CHANGE\_NOTIF
2. Check EFR application ID /RGS/I\_JCA\_WO\_CHANGE\_NOTIFICATION
3. Get EFR parameters for CONDITION and SWERK
4. Check if AUTYP(order category) AUART(order type) ABCKZ(ABC indicator) ILART(maintenance activity type) in CONDITION parameters and SWERK(maintenance plant) in SWERK parameters and IPHAS(Maintenance Processing Phase) is 2

4>IF pass EFR check, call FM /RGS/I\_JCA\_WO\_SEND\_NOTIF for get mail and notification details

1.Get old basic finish date from i\_maintenanceorder by AUFNR(work order number)

2.Check if new basic finish date is greater than old basic finish date

5>IF YES, get

1.Get equipment description from /rgs/s\_b\_eqkt

2.Get partner ID and work order status using FM BAPI\_ALM\_ORDER\_GET\_DETAIL

3.Get recipients using FM BAPI\_EMPLOYEE\_GETDATA' by partner ID

4.If failed to get recipients, then return with do nothing

5.Get SO10 text(ID YY10\_/RGS/I\_JCA\_WO\_CHANGE\_NOTIFICATION) for notification content

6>Call method /rgs/cl\_i\_jca\_wo\_change\_noti=>wo\_send\_mail

7>Call method /rgs/cl\_i\_jca\_wo\_change\_noti=>wo\_send\_notification

1. SE24 – Create Class /RGS/CL\_I\_JCA\_WO\_CHANGE\_NOTI

Method WO\_SEND\_NOTIFICATION

WO\_SEND\_MAIL

1. SE24 – Create Class /RGS/CL\_I\_JCA\_WO\_NOTIFPROVIDER

Method /IWNGW/IF\_NOTIF\_PROVIDER~GET\_NOTIFICATION\_TYPE\_TEXT

/IWNGW/IF\_NOTIF\_PROVIDER~GET\_NOTIFICATION\_TYPE

1. Config notification Provider /RGS/I\_JCA\_WO\_NOTIFPROVIDER and Provider Class /RGS/CL\_I\_JCA\_WO\_NOTIFPROVIDER
2. SO10 (YY10\_/RGS/I\_JCA\_WO\_CHANGE\_NOTIFICATION)

– Maintain notification content text in language EN DE ZH JA

### Data Model

N/A (No Data Model)

### User Interface / Form Layout

N/A (No User Interface / Form Layout is in the scope of this development)

### Interface Details

NA (No Interface detail is in the scope of this development)

# Solution Configuration Design

EFR framework is used to maintain parameter values used in this implementation

| EFR application ID | /RGS/I\_JCA\_WO\_CHANGE\_NOTIFICATION | |
| --- | --- | --- |
| Parameter ID | CONDITION  SWERK | |
| Parameter name | Parameter Description | Example Values |
| CONDITION  SWERK | Order Type|ABC Indicator|Maintenance Activity Type  Maintenance Plant | 30|YPM4|A|119  YY10 |

## Administrative Configuration Design

N/A (No Administrative Configuration Design is in scope of this development)

## Template Configuration Design

N/A (No Template Configuration Design is in scope of this development)

## Rollout Configuration Design

N/A (No Rollout Configuration Design is in scope of this development)

# Authorization

Roles for Maintenance Order change

# Error Handling

N/A (No Error Handling is in scope of this development)

# Translation / Multi-Language Enablement

SO10 text in EN,DE,ZH,JA (YY10\_/RGS/I\_JCA\_WO\_CHANGE\_NOTIFICATION)

# Dependencies / Constraints / Assumptions

N/A (No Dependencies / Constraints / Assumptions is in the scope of this development)