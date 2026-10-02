# EVENTFORCE - MANUAL TESTING CHECKLIST

Legend: [ ] not verified, [x] verified. Execute the list in the order given - every step
builds on the data created by the previous step.

## A. Objects, fields and app

- [ ] Setup | Object Manager shows Event, Client, Vendor, Venue, Feedback, Event Vendor.
- [ ] Event has the picklist Status with Draft / Pending Cancellation / Confirmed / Cancelled / Completed and default value Draft.
- [ ] Event shows the formula fields Duration (Days), Event Month, Days Until Event, Upcoming Event (checkbox), Status Indicator and Client Email.
- [ ] App Launcher contains "Event Planner Management System" with the tabs Event, Client, Vendor, Venue, Feedback, Reports, Dashboards.
- [ ] Each tab opens the list view of the object.

## B. Event creation and validation

- [ ] Create an event without Event Date -> blocked with "Enter the date of the event."
- [ ] Create an event without Client -> blocked with "Select the client this event is organised for."
- [ ] Set the status to Confirmed without a venue -> blocked with the venue message.
- [ ] Set End Date before Start Date -> blocked.
- [ ] Set the status to Confirmed with a past event date -> blocked.
- [ ] Create a valid event with all fields -> saved, Status = Draft.

## C. Double booking

- [ ] Create event A: venue Hall 1, date 20.10.2026, Confirmed -> saved, Hall 1 becomes Booked.
- [ ] Create event B: venue Hall 1, same date -> blocked, message names Hall 1 and event A.
- [ ] Create event C: venue Hall 2, same date -> saved.
- [ ] Create event D: venue Hall 1, date 21.10.2026 -> saved.
- [ ] Edit event D: set the date to 20.10.2026 -> blocked.
- [ ] Edit event A: change only the description -> saved (no self conflict).
- [ ] Cancel event A (through the approval process, see D) and create a new event on Hall 1 / 20.10.2026 -> saved.
- [ ] Insert 3 events in one go (Data | Import Wizard or Lightning Mass Create) with two of them on the same venue and date -> exactly the two duplicates are rejected.

## D. Venue status automation

- [ ] Confirm an event -> its venue shows Booked.
- [ ] Cancel the event -> the venue shows Available again.
- [ ] Two confirmed events on the same venue but different dates; cancel one -> venue stays Booked.
- [ ] Cancel the second one -> venue becomes Available.
- [ ] Move an event from Hall 1 to Hall 2 (status Confirmed) -> Hall 1 Available, Hall 2 Booked.
- [ ] Edit an event without touching status or venue -> the venue record is not modified (check "Last Modified Date").

## E. Cancellation approval process

- [ ] Set the status of a Confirmed event to Cancelled directly -> blocked by the validation rule.
- [ ] Set the status to Pending Cancellation, enter a cancellation reason -> allowed.
- [ ] Submit the record for approval -> a process instance is created (App Launcher | Process or the record's approval history).
- [ ] Approve it -> Status = Cancelled, the venue is released, the approval history shows the decision.
- [ ] Repeat with a second event and reject it -> the status returns to Confirmed, the venue stays Booked.
- [ ] Try to submit an event whose status is not Pending Cancellation -> the submit option is not offered.

## F. Client reminder (Flow)

- [ ] Create an event with a future date (e.g. in 5 days) and a client with an email address -> a flow interview is created (Setup | Flows | Event - Client Reminder 3 Days Before | Flow Runs).
- [ ] In Flow Runs, the scheduled path "Reminder 3 Days Before" is waiting.
- [ ] Create an event with a past date -> no flow interview is created.
- [ ] Create an event, then cancel it before the reminder time -> when the scheduled path wakes up, the decision sends the email to "Skip Reminder".
- [ ] Confirm the email: Setup | Email | Outbound Emails / or the client's inbox contains the subject "EventForce reminder: your event is in 3 days" with the event name, date and venue.

## G. Automatic completion (Batch + Schedulable)

- [ ] Create two events with a past date and status Draft -> both are saved.
- [ ] Setup | Scheduled Apex | Run (ScheduleCompleteEvents) -> a batch job appears in Setup | Monitor | Apex Jobs with status "Success".
- [ ] Both past events now show Status = Completed.
- [ ] A cancelled event with a past date is still Cancelled.
- [ ] An event of today is still Draft.
- [ ] Setup | Custom Settings | Event Scheduler Settings: change Batch Size to 50 and Cron Expression to `0 0 3 * * ?`, run the class again -> job succeeds, next execution at 03:00.

## H. Reports and dashboard

- [ ] Report "Upcoming Events by Month" shows the events grouped by month with the event date, client, venue and status; cancelled events are not listed.
- [ ] Report "Event Status Summary" shows one row per status with the number of records.
- [ ] Report "Venue Availability" is grouped by venue status (Available / Booked / Under Maintenance).
- [ ] Report "Vendor Assignments by Event" lists the vendor assignments grouped by vendor.
- [ ] Dashboard "EventForce Operations Dashboard" shows the four components and refreshes.

## I. Security

- [ ] A user with the `Event Admin` permission set can create, edit and delete events, clients, vendors, venues, feedback and assignments.
- [ ] A user with `Event Coordinator` can create and edit their own events but sees **no** events of a different coordinator (OWD Private).
- [ ] A user with `Venue Manager` can edit venues and can only read events and vendors.
- [ ] A user with `Vendor Manager` can edit vendors and assignments and can only read events.
- [ ] A user with `Client` can read events, read the client record and create feedback, but cannot delete anything.
- [ ] A vendor user whose login email equals the Vendor Contact Email of an event sees exactly this event (read only) and no other event.
- [ ] The same vendor user cannot see the Fee__c of the assignment or the client record.

## J. Apex test classes (automated)

- [ ] `sf apex run test --test-level RunLocalTests --code-coverage` finishes with 0 failures.
- [ ] Coverage: `EventTriggerHandler`, `VenueStatusHelper`, `PreventDoubleBooking`, `BatchCompleteEvents`, `ScheduleCompleteEvents` are above 90%.
- [ ] `EventForceSecurityTest` passes, which proves that the five permission sets are deployed and that Event__c is private.
- [ ] The test data created by the tests does not remain in the org (roll back behaviour).

## K. Regression after deployment

- [ ] Re-run a full deploy (`sf project deploy start --source-dir force-app`) -> no changes, no failures (destructive changes check).
- [ ] Retrieve the objects back into the source (`sf project retrieve start --metadata Event__c`) -> the retrieved files match the source, no unmanaged drift.
