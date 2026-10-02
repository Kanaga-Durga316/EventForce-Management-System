# EVENTFORCE MANAGEMENT SYSTEM

Salesforce project (EventForce) for the complete digital management of events, clients,
vendors, venues, feedback and event/vendor assignments.

The repository is a Salesforce DX project. Everything in `force-app` can be deployed with
the Salesforce CLI; everything that Salesforce does not allow to be deployed is listed in
`docs/DEPLOYMENT_AND_MANUAL_SETUP.md` with the exact Setup path.

## 1. Project structure

```
EventForce/
├── sfdx-project.json
├── manifest/package.xml                     # full manifest, generated from the source
├── scripts/                                 # deterministic metadata generators
│   ├── build-objects.ps1                    # 6 custom objects + 52 custom fields
│   ├── build-validation-rules.ps1           # 12 validation rules
│   ├── build-permissionsets.ps1             # 5 permission sets
│   └── build-package-xml.ps1                # manifest/package.xml
├── docs/
│   ├── SECURITY_MODEL.md
│   ├── DATA_MIGRATION.md
│   ├── DEPLOYMENT_AND_MANUAL_SETUP.md
│   └── TESTING_CHECKLIST.md
└── force-app/main/default/
    ├── applications/Event_Planner_Management_System.app-meta.xml
    ├── approvalProcesses/Event_Cancellation_Approval.approvalProcess-meta.xml
    ├── classes/
    │   ├── EventTriggerHandler.cls          EventForceTestData.cls
    │   ├── VenueStatusHelper.cls            PreventDoubleBooking.cls
    │   ├── BatchCompleteEvents.cls          ScheduleCompleteEvents.cls
    │   ├── VenueStatusHelperTest.cls        PreventDoubleBookingTest.cls
    │   ├── BatchCompleteEventsTest.cls      ScheduleCompleteEventsTest.cls
    │   ├── EventTriggerHandlerTest.cls      EventForceSecurityTest.cls
    ├── customSettings/EventForce_Schedule__c/
    ├── dashboards/EventForce_Operations_Dashboard/
    ├── flows/Event_Client_Reminder_3_Days_Before.flow-meta.xml
    ├── objects/  Event__c, Client__c, Vendor__c, Venue__c, Feedback__c,
    │             EventVendor__c, EventForce_Schedule__c
    ├── permissionsets/ Event_Admin, Event_Coordinator, Vendor_Manager, Venue_Manager, Client
    ├── reports/EventForce_Reports/
    │   ├── Upcoming_Events_by_Month.report-meta.xml
    │   ├── Event_Status_Summary.report-meta.xml
    │   ├── Venue_Availability.report-meta.xml
    │   └── Vendor_Assignments_by_Event.report-meta.xml
    ├── sharingRules/Event_Sharing_For_Vendors.sharingRule-meta.xml
    ├── tabs/ Event__c, Client__c, Vendor__c, Venue__c, Feedback__c
    └── triggers/EventTrigger13.trigger
```

## 2. Automation overview

| Business rule | Implementation |
| --- | --- |
| Client reminder 3 days before the event | Flow `Event - Client Reminder 3 Days Before` (record triggered flow with a scheduled path, time offset -3 days on `Event__c.Event_Date__c`) |
| Event cancellation approval | Approval process `Event Cancellation Approval` on `Event__c` |
| Venue status automation | `VenueStatusHelper` called from `EventTriggerHandler` after insert/update |
| Event automation entry point | `EventTrigger13` (before insert, before update, after insert, after update) |
| Double booking prevention | `PreventDoubleBooking` (before insert / before update) |
| Automatic event completion | `BatchCompleteEvents` + `ScheduleCompleteEvents` (nightly, configurable) |
| Security | 5 permission sets, Event__c OWD Private, `Event_Sharing_For_Vendors` |

## 3. Quick start

```bash
sf org login sfdx --alias eventforce --set-default
sf project deploy start --source-dir force-app --target-org eventforce --wait 20 --wait-timeout 60
sf apex run test --test-level RunLocalTests --code-coverage --result-format human --wait 20 --target-org eventforce
```

See `docs/DEPLOYMENT_AND_MANUAL_SETUP.md` for the full command list, and
`docs/TESTING_CHECKLIST.md` for the manual verification checklist.
