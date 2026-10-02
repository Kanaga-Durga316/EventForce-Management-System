# EVENTFORCE - SECURITY MODEL

## 1. Roles and role hierarchy

Salesforce roles are **not** deployable in a DX project (role metadata can only be created
in Setup or inside a managed package). Create the following hierarchy manually:

Setup | Quick Create | Roles

```
CEO
├── VP Operations
│   ├── Event Admin              (regional office 1)
│   └── Event Admin              (regional office 2)
├── Event Manager
│   ├── Event Coordinator        (north)
│   │   ├── Event Coordinator    (south)
│   │   └── Client User
│   ├── Vendor Manager
│   │   └── Vendor User
│   └── Venue Manager
│       └── Venue User
```

The hierarchy is what makes the "see my team's events" behaviour possible; the shipped
`Event_Sharing_For_Vendors` rule is the only sharing rule of the project and grants a
vendor read access to the events of that vendor only.

## 2. Organization-Wide Defaults

| Object | OWD | Internal sharing | Why |
| --- | --- | --- | --- |
| Event__c | **Private** | Edit | Required by the project definition. Events are only visible to the owner, the manager, and users reached by a sharing rule. |
| Client__c | Private | Edit | Client contacts are commercially sensitive. |
| Vendor__c | Private | Edit | Vendor prices (EventVendor__c.Fee__c) are commercially sensitive. |
| Venue__c | Public Read Only | Edit | Venues are shared reference data that has to be visible to everybody. |
| Feedback__c | Private | Edit | Feedback belongs to the client. |
| EventVendor__c | Public Read Only | Edit | Junction object: read access follows the event, which is granted to the vendor through the sharing rule. |
| EventForce_Schedule__c | Public Read Only | Edit | Configuration read by ScheduleCompleteEvents. |

Set them in Setup | Sharing Settings | Edit (read the OWD from
`force-app/main/default/objects/<Object>/<Object>.object-meta.xml`, `sharingModel`).

## 3. Permission sets (deployed)

| Permission set | Label | Events | Clients | Vendors | Venues | Feedback | EventVendor |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `Event_Admin` | Event Admin | CRUD + View All | CRUD + View All | CRUD + View All | CRUD + View All | CRUD + View All | CRUD + View All |
| `Event_Coordinator` | Event Coordinator | CRUD | Read | Read | Read | CRUD | CRUD |
| `Vendor_Manager` | Vendor Manager | Read | Read | CRUD | Read | - | CRUD |
| `Venue_Manager` | Venue Manager | Read | Read | Read | CRUD | - | - |
| `Client` | Client | Read | Read | - | - | Create/Read/Edit | - |

Field level security is generated from the actual field metadata
(`scripts/build-permissionsets.ps1`), so every role gets either editable or read-only
access to every field of the objects listed above. No role has `Modify All Records`;
only `Event Admin` has `View All Records`.

Apex class access (`EventTriggerHandler`, `VenueStatusHelper`, `PreventDoubleBooking`,
`BatchCompleteEvents`, `ScheduleCompleteEvents`) and access to the custom setting
`EventForce_Schedule__c` are granted to `Event Admin` only. All other logic runs in
system mode, so no additional Apex access is required for the business roles.

## 4. Sharing rules

### Event_Sharing_For_Vendors (deployed)

| Setting | Value |
| --- | --- |
| Object | Event__c |
| Type | Criteria based sharing rule |
| Criteria | `Vendor_Contact_Email__c = $User.Email` |
| Share with | Role: **Vendor Manager** (and its subordinates) |
| Access level | Read Only |

Result: a vendor user whose login email equals the *Vendor Contact Email* of an event sees
exactly that event and nothing else - no other event, no client record, no vendor pricing.

## 5. Least privilege rules applied

1. Event__c is private; a coordinator only sees their own events plus what is shared.
2. Read-only roles (Client, Vendor Manager, Venue Manager) never receive delete or
   `View All Records` rights.
3. Only the Event Admin can change the automation configuration (custom setting).
4. The vendor sharing rule is read only - a vendor can never edit an event.
5. Apex classes are not exposed to the business roles; nothing can be invoked from the
   developer console by a coordinator.
