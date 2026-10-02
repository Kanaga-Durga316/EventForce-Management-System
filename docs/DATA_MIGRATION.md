# EVENTFORCE - DATA MIGRATION

Scope: Events, Clients, Vendors, Venues and Feedback (and their relations).
Tool: **Data Import Wizard** (recommended, allows field mapping and duplicate prevention)
or **Data Loader** for large volumes.

## 0. Order of import (dependencies)

```
1. Client__c    (no dependency)
2. Vendor__c    (no dependency)
3. Venue__c     (no dependency)
4. Event__c     (Client__c + Venue__c via Salesforce IDs)
5. EventVendor__c (Event__c master-detail + Vendor__c)
6. Feedback__c  (Event__c + Client__c)
```

Import parents before children, otherwise the lookup fields cannot be resolved.

## 1. Field mapping (Data Import Wizard / Data Loader mapping file)

| Target object | Source column (header) | Field API name | Required |
| --- | --- | --- | --- |
| Client__c | Client Name | `Name` | yes |
| Client__c | Email | `Email__c` | no (needed for the reminder) |
| Client__c | Phone | `Phone__c` | no |
| Client__c | Company | `Company__c` | no |
| Client__c | City | `City__c` | no |
| Client__c | Legacy Client Id | `External_ID__c` | **yes** (external id) |
| Vendor__c | Vendor Name | `Name` | yes |
| Vendor__c | Contact Email | `Contact_Email__c` | no |
| Vendor__c | Phone | `Phone__c` | no |
| Vendor__c | Category | `Category__c` | no (default `Other`) |
| Vendor__c | Rating | `Rating__c` | no |
| Vendor__c | Status | `Status__c` | no (default `Active`) |
| Vendor__c | Legacy Vendor Id | `External_ID__c` | **yes** (external id) |
| Venue__c | Venue Name | `Name` | yes |
| Venue__c | Status | `Status__c` | no (default `Available`, maintained by the automation) |
| Venue__c | City | `City__c` | no |
| Venue__c | Capacity | `Capacity__c` | no |
| Venue__c | Address | `Address__c` | no |
| Venue__c | Contact Email | `Contact_Email__c` | no |
| Venue__c | Legacy Venue Id | `External_ID__c` | **yes** (external id) |
| Event__c | Event Name | `Name` | yes |
| Event__c | Event Date | `Event_Date__c` | yes (validation rule) |
| Event__c | Start Date | `Start_Date__c` | no |
| Event__c | End Date | `End_Date__c` | no |
| Event__c | Status | `Status__c` | no (default `Draft`) |
| Event__c | Client (Legacy Client Id) | `Client__c` | yes (lookup, resolve by external id) |
| Event__c | Venue (Legacy Venue Id) | `Venue__c` | required when status = `Confirmed` |
| Event__c | Cancellation Reason | `Cancellation_Reason__c` | required when status = `Cancelled` |
| Event__c | Vendor Contact Email | `Vendor_Contact_Email__c` | needed for the vendor sharing rule |
| Event__c | Legacy Event Id | `External_ID__c` | **yes** (external id) |
| EventVendor__c | Assignment | `Name` | yes |
| EventVendor__c | Event (Legacy Event Id) | `Event__c` | yes (master-detail) |
| EventVendor__c | Vendor (Legacy Vendor Id) | `Vendor__c` | yes (lookup) |
| EventVendor__c | Role | `Role__c` | no |
| EventVendor__c | Fee | `Fee__c` | no |
| EventVendor__c | Assignment Status | `Assignment_Status__c` | no (default `Requested`) |
| EventVendor__c | Legacy Assignment Id | `External_ID__c` | **yes** (external id) |
| Feedback__c | Feedback Reference | `Name` | yes |
| Feedback__c | Event (Legacy Event Id) | `Event__c` | yes (validation rule) |
| Feedback__c | Client (Legacy Client Id) | `Client__c` | no, must match the client of the event |
| Feedback__c | Rating | `Rating__c` | no (0 - 5) |
| Feedback__c | Comments | `Comments__c` | no |
| Feedback__c | Submitted Date | `Submitted_Date__c` | no |
| Feedback__c | Legacy Feedback Id | `External_ID__c` | **yes** (external id) |

## 2. Relationship mapping

The import file contains **legacy keys, not Salesforce IDs**. In the Data Import Wizard use
"Relationships" and map:

* `Event__c.Client__c` -> match `Client__c.External_ID__c` (Match by: **External ID**)
* `Event__c.Venue__c` -> match `Venue__c.External_ID__c`
* `EventVendor__c.Event__c` -> match `Event__c.External_ID__c`
* `EventVendor__c.Vendor__c` -> match `Vendor__c.External_ID__c`
* `Feedback__c.Event__c` -> match `Event__c.External_ID__c`
* `Feedback__c.Client__c` -> match `Client__c.External_ID__c`

With Data Loader, upload the parents first, export the created records with their
Salesforce IDs (`Id` column), and use a second mapping file that contains those IDs
instead of the legacy keys.

## 3. Duplicate prevention

* `External_ID__c` is marked as **External ID** on all six objects, so a repeated import
  performs an **Update** instead of creating a second record (Data Import Wizard:
  "Use an existing record to update" + external id).
* Import in two passes: first with `Name` only, then with the external id for matching, if
  the legacy system has no stable name.
* Export existing `External_ID__c` values before the first import and compare the sets
  (Excel: `=COUNTIF(Existing, New)`) to prove that no legacy row is imported twice.

## 4. Data validation before the import

Run these checks on the extract file:

1. `Event__c.Event_Date__c` not empty and formatted `yyyy-mm-dd` (validation rule
   *Event_Date_Required*).
2. `Event__c.End_Date__c` >= `Event__c.Start_Date__c` (*End_Date_After_Start_Date*).
3. `Event__c.Client__c` resolves to exactly one client (mandatory).
4. `Event__c.Venue__c` resolves to exactly one venue and **is unique per event date**
   (rule *PreventDoubleBooking* rejects the whole file, so check duplicates first:
   `COUNTIFS(Venue, venue, EventDate, date) > 1`).
5. `Event__c.Status__c` only contains `Draft, Pending Cancellation, Confirmed, Cancelled,
   Completed`.
6. `Event__c.Status__c = 'Cancelled'` rows also carry `Cancellation_Reason__c`
   (*Cancellation_Reason_Required*).
7. `Feedback__c.Rating__c` between 0 and 5 and `Feedback__c.Client__c` equal to the client
   of the referenced event.
8. `Venue__c.Capacity__c` >= 1.

## 5. Loading and post-processing

```bash
# Data Loader mapping files are plain CSV; example for Client__c
sf data import bulk request --file Client__c.csv --job-type insert --object Client__c
```

After the import:

1. Run a data quality report: `SELECT Status__c, COUNT(Id) FROM Event__c GROUP BY Status__c`.
2. Check for empty venues: `SELECT Id, Name FROM Event__c WHERE Venue__c = null`.
3. Confirm the automation: the first confirmed event loaded must have booked its venue -
   if the import was executed with the trigger disabled, re-save one event or run the
   confirm/cancel cycle once.
4. Schedule `ScheduleCompleteEvents` (Setup | Scheduled Apex | Schedule New) so that
   historical events with a past date are completed.
