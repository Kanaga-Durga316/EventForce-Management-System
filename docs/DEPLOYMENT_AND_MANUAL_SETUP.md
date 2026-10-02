# EVENTFORCE - DEPLOYMENT AND MANUAL SETUP

## 1. Salesforce CLI commands

```bash
# 0) show the installed CLI version
sf --version

# 1) authenticate
sf org login sfdx --alias eventforce --set-default
#    Dev Hub / Developer Edition only:
# sf org login sfdx --alias eventforce --set-default --instance-url https://<your-domain>.my.salesforce.com
#    or with a dev hub + scratch org:
# sf org create scratch --definition-file scratch-def.json --alias eventforce --set-default

# 2) check who you are talking to
sf org display --target-org eventforce

# 3) deploy the whole source directory (recommended)
sf project deploy start --source-dir force-app --target-org eventforce --wait 20 --wait-timeout 60

# 3b) deploy only the manifest (equivalent, generated from the source)
sf project deploy start --manifest manifest/package.xml --target-org eventforce --wait 20 --wait-timeout 60

# 3c) deploy only some component types
sf project deploy start --metadata ApexTrigger,CustomObject,CustomField,ValidationRule,Flow,ApprovalProcess,CustomPermissionSet,SharingRule,CustomTab,CustomApplication,Report,Dashboard,CustomSettings --source-dir force-app --target-org eventforce --wait 20

# 4) quick deploy (the fast path - compile only, no metadata coverage check)
sf project deploy quick --source-dir force-app --target-org eventforce --wait 20

# 5) run the tests
sf apex run test --test-level RunLocalTests --code-coverage --result-format human --wait 20 --target-org eventforce

# 5b) run one class only
sf apex run test --tests PreventDoubleBookingTest,BatchCompleteEventsTest,VenueStatusHelperTest,ScheduleCompleteEventsTest,EventTriggerHandlerTest,EventForceSecurityTest --code-coverage --result-format human --wait 20 --target-org eventforce

# 6) check the deployment status / list recent deployments
sf project deploy report --target-org eventforce

# 7) retrieve metadata back from the org
sf project retrieve start --metadata ApexClass,ValidationRule,Flow,ApprovalProcess,CustomPermissionSet,SharingRule --target-org eventforce
sf project retrieve start --metadata Event__c,Client__c,Vendor__c,Venue__c,Feedback__c,EventVendor__c --target-org eventforce --output-dir force-app

# 8) deploy (or schedule) the nightly batch from the CLI
sf apex run --class ScheduleCompleteEvents
```

Command outputs: `sf project deploy start --dry-run` validates the manifest without
touching the org - always run it first in a new org.

## 2. Manual steps in Salesforce Setup (cannot be deployed as source)

| # | What | Where |
| --- | --- | --- |
| 1 | Role hierarchy (CEO, VP Operations, Event Manager, Event Coordinator, Vendor Manager, Venue Manager) | Setup | Quick Create | Roles |
| 2 | Organization-Wide Defaults per object | Setup | Sharing Settings | Edit (values in `docs/SECURITY_MODEL.md`) |
| 3 | Schedule `ScheduleCompleteEvents` nightly | Setup | Scheduled Apex | Schedule New: class `ScheduleCompleteEvents`, default cron `0 0 2 * * ?` (configurable in the custom setting `Event Scheduler Settings`) |
| 4 | Activate the `Event_Sharing_For_Vendors` sharing rule | Setup | Sharing Settings | Edit `Event__c` | Sharing Rules (the rule is deployed inactive-safe, check "Active") |
| 5 | Custom profiles (System Administrator / EventForce User) | Setup | Profiles | New. Profiles are not deployable; assign the permission sets to the profiles instead. |
| 6 | Email sender address, email templates (optional branded copy) | Setup | Email | "My Email Addresses" |
| 7 | Lightning Experience app as default | App Launcher | Event Planner Management System | "Set as Default Page" |
| 8 | Tab visibility per user | Setup | Profiles / Permission Sets | Permission set tab settings are deployed; profile level tabs only for custom profiles |
| 9 | Flow execution: the scheduled path needs the org to be online (Hibernate aware) - nothing to configure, but the flow is **Active** after deployment | Setup | Flows | Event - Client Reminder 3 Days Before |

## 3. Metadata that is deployed but must be verified once

Some metadata types are sensitive to the exact XML element order of the org's API version.
If the deployment of one of the following components is rejected, the component itself is
correct in content - rebuild it with the builder and the settings listed here:

| Component | Verification / fallback |
| --- | --- |
| `Event_Client_Reminder_3_Days_Before.flow-meta.xml` | Setup | Flows. Create a record-triggered flow: "When a record is created" on Event__c, filter `Is_Upcoming__c = true` and `Status__c != Cancelled`, scheduled path "Reminder 3 Days Before" with time trigger `Event_Date__c`, offset `-3` days, then a decision on `Is_Upcoming__c`/`Status__c` and an **Action: Send Email** to `Client_Email__c` with the shipped subject/body. |
| `Event_Cancellation_Approval.approvalProcess-meta.xml` | Setup | Process Automation | Process Builder *or* the classic wizard: entry criteria `Status__c = 'Pending Cancellation' AND Cancellation_Reason__c != blank`, next approver "Managers", final actions: approve -> `Status__c = "Cancelled"`, reject -> `Status__c = "Confirmed"`. |
| `Event_Sharing_For_Vendors.sharingRule-meta.xml` | Setup | Sharing Settings. Object `Event__c`, criteria `Vendor_Contact_Email__c = $User.Email`, share with role **Vendor Manager**, read only. |
| `reports/*` and `dashboards/*` | Setup | Reports / Dashboards. Column list, groupings and filters are documented in the delivery notes; rebuild with Report Builder if the XML is rejected. |
| `tabs/*.tab-meta.xml` | Setup | Apps | Tabs can be created manually; the custom object tab name must match the object API name. |
| `EventForce_Schedule__c.settings-meta.xml` | Setup | Custom Settings | "Event Scheduler Settings" -> create the row `Default` with `Cron Expression = 0 0 2 * * ?` and `Batch Size = 200`. The Apex falls back to these same defaults when no row exists. |

## 4. Deployment order inside one `sf project deploy start`

Salesforce resolves the dependencies of a single deployment automatically, but the order
below is the safe sequence for a partially deployed org:

1. Custom objects + custom fields (`CustomObject`, `CustomField`)
2. Validation rules (`ValidationRule`), custom setting
3. Permission sets, tabs, application, sharing rules
4. Flow, approval process
5. Reports and dashboards
6. Apex classes, trigger, test classes (run at the end of the same deployment)

## 5. Rollback / troubleshooting

| Symptom | Cause | Fix |
| --- | --- | --- |
| `Error: Field ... does not exist` | Field API name in a formula, report or flow does not match the org | Regenerate with `scripts\build-objects.ps1` and redeploy, or retrieve the object from the org first |
| Tests fail: `No such column 'Client__r.Email__c'` | Cross object formula blocked because the formula was created before the lookup | Recreate the formula field after the lookup exists |
| `FIELD_CUSTOM_VALIDATION_EXCEPTION` on cancellation | The `Cancellation_Requires_Approval` rule is working as designed | Set the status to *Pending Cancellation* and submit for approval |
| Flow does not fire | The event was created with a past date | Expected: the flow filter is `Is_Upcoming__c = true` |
| `System.AsyncException: Too many SOQL queries` | Automated process volume | Run the batch from Setup | Scheduled Apex, one run per night |
