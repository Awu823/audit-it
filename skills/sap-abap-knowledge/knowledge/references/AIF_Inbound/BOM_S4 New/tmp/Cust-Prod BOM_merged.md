# Merged Cust-Prod BOM Structure

This is a merged structure combining both Cust BOM and Prod BOM fields.
Fields unique to Cust BOM are marked with **[CUST]**, fields unique to Prod BOM are marked with **[PROD]**, 
and common fields (appearing in both) are marked as **[COMMON]**.

---

## Merged Field Table

| ID | Field Name | Cust/Prod | Data Type | Length | Description | Origin |
|----|-----------|-----------|-----------|--------|-------------|--------|
| ID01 | MATERIAL | [COMMON] | CHAR 40 | M | BOM Header material including FG/SEMI (MAST-MATNR) | Both |
| ID02 | BOM_Version | [CUST] | CHAR 8 | M | Custom Logic (Custom field) | Cust |
| ID03 | COMPONENT_MATNR | [COMMON] | CHAR 40 | M | BOM Item material / components (STPO-IDNRK) | Both |
| ID04 | QUANTITY | [COMMON] | DEC(13,3) | M | Component quantity (STPO-MENGE) | Both |
| ID05 | COMPONENT_UNIT | [COMMON] | UNIT 3 | O | Components UoM / customs unit (STPO-MEINS) | Both |
| ID06 | VALID_FROM | [COMMON] | DATS 8 | M | validate start date (YYYYMMDD) Custom Logic | Both |
| ID07 | VALID_TO | [COMMON] | DATS 8 | O | validate end date (YYYYMMDD) Custom Logic | Both |
| ID08 | BondMark1 | [CUST] | CHAR 2 | M | Custom Logic (Custom field) | Cust |
| ID09 | BondMark2 | [CUST] | CHAR 2 | M | Custom Logic (Custom field) | Cust |
| ID10 | note | [CUST] | CHAR50 | O | No Logic, Send Blank (Custom field) | Cust |
| ID11 | PLANT | [CUST] | CHAR(4) | M | Available in Standard API(MAST-WERKS) | Cust |
| ID12 | note2 | [CUST] | CHAR50 | O | No Logic, Send Blank (Custom field) | Cust |
| ID13 | BOM_Type | [CUST] | CHAR 1 | M | Custom Logic(Always Send 0) | Cust |
| ID14 | Batch_NO. | [CUST] | CHAR 10 | O | No Logic, Send Blank (Custom field) | Cust |
| ID15 | HEADER_UNIT | [COMMON] | UNIT 3 | O | BOM header Unit(STPO-BMEIN) | Both |
| ID16 | BOM_CREATION | [PROD] | DATS 8 | O | BOM Creation Date, STKO-ANDAT | Prod |
| ID17 | ALTERNATIVE_BOM | [PROD] | CHAR 2 | O | Alternative BOM Number, MAST-STLAL | Prod |
| ID18 | BOM_NO | [PROD] | CHAR 8 | O | BOM Number, MAST-STLNR | Prod |
| ID19 | CHANGE_NO | [PROD] | CHAR 12 | O | Engineering Change Number, AENR-AENNR | Prod |
| ID20 | BOM_USAGE | [PROD] | CHAR 1 | O | BOM Usage, MAST-STLAN | Prod |
| ID21 | HEADER_START_DATE | [PROD] | DATS 8 | O | BOM Header Valid From, STKO-DATUV | Prod |
| ID22 | HEADER_END_DATE | [PROD] | DATS 8 | O | BOM Header Valid To, STKO-DATUB | Prod |
| ID23 | HEADER_QTY | [PROD] | DEC(13,3) | M | BOM Header Quantity, STKO-BMENG | Prod |
| ID24 | COMPONENT_UNIT | [PROD] | UNIT 3 | O | Component UoM/Customs Unit, STPO-MEINS | Prod *(duplicate of ID05)* |
| ID25 | OPERATION_SCRAP | [PROD] | DEC(5,2) | M | Operation Scrap % or Quantity, STPO-AUSCH | Prod |
| ID26 | COMPONENT_SCRAP | [PROD] | DEC(5,2) | M | Component Scrap % or Quantity, STPO-KAUSF | Prod |

---

## Merged Field Summary

- **Total unique fields**: 26
- **Common fields** (in both Cust and Prod): ID01, ID03, ID04, ID05, ID06, ID07, ID15 (**7 fields**)
- **Cust-only fields**: ID02, ID08, ID09, ID10, ID11, ID12, ID13, ID14 (**8 fields**)
- **Prod-only fields**: ID16, ID17, ID18, ID19, ID20, ID21, ID22, ID23, ID25, ID26 (**10 fields**)
- **Note**: ID24 is a duplicate of ID05 (COMPONENT_UNIT from Prod), removed from final count

---

## Service Interface Note

This merged structure can be used by a service interface to transport both Cust BOM and Prod BOM data.

**The interface should handle field mapping based on the BOM type (Cust or Prod) being processed.**

- When processing a **Cust BOM**, include fields marked [CUST] + common fields [COMMON]
- When processing a **Prod BOM**, include fields marked [PROD] + common fields [COMMON]
- The interface can use the [CUST]/[PROD]/[COMMON] markers to determine which fields apply to each BOM type