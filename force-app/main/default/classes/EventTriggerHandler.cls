/**
 * EventTriggerHandler
 * -------------------
 * Single entry point for all Event__c automation. The trigger (EventTrigger13)
 * calls handle() exactly once per transaction; this class decides which business
 * rule has to run for the current trigger context and delegates to the
 * appropriate helper class.
 *
 * Design rules applied here:
 *   - No SOQL and no DML in this class (delegated to the helpers).
 *   - No SOQL / DML inside loops anywhere in the chain.
 *   - Records that cannot influence a venue are filtered out before any
 *     database work is done, to keep the trigger cheap.
 *   - Recursion is prevented with an in-transaction guard.
 */
public with sharing class EventTriggerHandler {

    /** Guard that stops the venue synchronisation from being re-entered. */
    private static Boolean isSyncingVenues = false;

    /** Event ids already processed in this transaction (idempotency guard). */
    private static Set<Id> processedEventIds = new Set<Id>();

    /**
     * @description Main entry point used by EventTrigger13.
     * @param newEvents  Trigger.new (empty list is allowed and simply ignored)
     * @param oldEventMap Trigger.oldMap (empty map on insert)
     */
    public static void handle(List<Event__c> newEvents, Map<Id, Event__c> oldEventMap) {
        if (newEvents == null || newEvents.isEmpty()) {
            return;
        }

        if (Trigger.isBefore) {
            PreventDoubleBooking.validate(newEvents);
            return;
        }

        Set<Id> venueIds = collectVenuesToSync(newEvents, oldEventMap);
        if (venueIds.isEmpty()) {
            return;
        }

        if (isSyncingVenues) {
            return;
        }
        isSyncingVenues = true;
        try {
            VenueStatusHelper.updateVenues(venueIds);
        } finally {
            isSyncingVenues = false;
        }
    }

    /**
     * @description Returns every venue whose availability may have changed.
     * Old venues are included on purpose: when an event is moved to another
     * venue, the venue that was freed has to be released as well.
     * @param newEvents   list of the records in the current transaction
     * @param oldEventMap previous version of the updated records
     * @return set of Venue__c ids, empty when nothing can have changed
     */
    private static Set<Id> collectVenuesToSync(List<Event__c> newEvents, Map<Id, Event__c> oldEventMap) {
        Set<Id> venueIds = new Set<Id>();
        Set<Id> eventIds = new Set<Id>();

        for (Event__c newEvent : newEvents) {
            if (newEvent == null || newEvent.Id == null || processedEventIds.contains(newEvent.Id)) {
                continue;
            }
            eventIds.add(newEvent.Id);

            Event__c oldEvent = (oldEventMap == null) ? null : oldEventMap.get(newEvent.Id);
            Boolean isInsert = (oldEvent == null);
            Boolean statusChanged = isInsert || !String.equals(newEvent.Status__c, oldEvent.Status__c);
            Boolean venueChanged = isInsert || newEvent.Venue__c != oldEvent.Venue__c;

            if (!statusChanged && !venueChanged) {
                // Nothing that influences the venue status was modified.
                continue;
            }
            if (newEvent.Venue__c != null) {
                venueIds.add(newEvent.Venue__c);
            }
            if (oldEvent != null && oldEvent.Venue__c != null) {
                venueIds.add(oldEvent.Venue__c);
            }
        }

        // Remember the events so a recursive update in the same transaction is ignored.
        if (!eventIds.isEmpty()) {
            processedEventIds.addAll(eventIds);
        }
        return venueIds;
    }

    /**
     * @description Test only hook - clears the in-transaction guards so that
     *             every test method starts from a clean state.
     */
    @TestVisible
    private static void resetState() {
        isSyncingVenues = false;
        processedEventIds = new Set<Id>();
    }
}
