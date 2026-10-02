/**
 * EventTrigger13
 * --------------
 * Technical trigger for the Event__c object.
 *
 * The trigger itself contains NO business logic. It only collects the trigger
 * context and delegates to EventTriggerHandler, which is invoked ONCE per
 * transaction (not once per record), so the whole chain is bulkified.
 *
 * Contexts used:
 *   before insert -> PreventDoubleBooking (venue conflict validation)
 *   before update -> PreventDoubleBooking (venue conflict validation)
 *   after insert  -> VenueStatusHelper    (book the venue for confirmed events)
 *   after update  -> VenueStatusHelper    (book / release the venue)
 */
trigger EventTrigger13 on Event__c (before insert, before update, after insert, after update) {
    EventTriggerHandler.handle(Trigger.new, Trigger.oldMap);
}
