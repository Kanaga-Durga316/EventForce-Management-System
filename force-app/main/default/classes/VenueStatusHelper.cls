/**
 * VenueStatusHelper
 * -----------------
 * Keeps Venue__c.Status__c in sync with the status of the events that use it.
 *
 * Business rules
 *   - An event with status "Confirmed" books its venue  -> Venue status = Booked
 *   - An event with status "Cancelled" releases its venue -> Venue status = Available
 *
 * Bulkification
 *   - ONE SOQL for the venues, ONE SOQL for the events of those venues,
 *     ONE DML for all venues that actually need to change.
 *   - A venue is only released when NO confirmed event still uses it, which
 *     makes the helper safe when several events share the same venue.
 *   - Venues that already hold the target status are never updated.
 */
public with sharing class VenueStatusHelper {

    /** Venue__c.Status__c picklist values. */
    public static final String VENUE_AVAILABLE = 'Available';
    public static final String VENUE_BOOKED = 'Booked';

    /** Event__c.Status__c value that books a venue. */
    public static final String EVENT_CONFIRMED = 'Confirmed';

    /**
     * @description Entry point used by EventTriggerHandler.
     * @param venueIds ids of every venue that has to be re-evaluated
     */
    public static void updateVenues(Set<Id> venueIds) {
        if (venueIds == null || venueIds.isEmpty()) {
            return;
        }

        // 1. Venues of interest (single query, never inside a loop).
        List<Venue__c> venues = [
            SELECT Id, Name, Status__c
            FROM Venue__c
            WHERE Id IN :venueIds
        ];
        if (venues.isEmpty()) {
            return;
        }

        Set<Id> bookedVenueIds = getVenuesWithConfirmedEvent(venueIds);

        // 2. Build the update list in memory only.
        List<Venue__c> venuesToUpdate = new List<Venue__c>();
        for (Venue__c venue : venues) {
            String targetStatus = bookedVenueIds.contains(venue.Id) ? VENUE_BOOKED : VENUE_AVAILABLE;
            if (targetStatus != venue.Status__c) {
                venue.Status__c = targetStatus;
                venuesToUpdate.add(venue);
            }
        }

        if (venuesToUpdate.isEmpty()) {
            return;
        }

        // 3. One DML statement for every venue.
        try {
            update venuesToUpdate;
        } catch (DmlException e) {
            System.debug(LoggingLevel.ERROR,
                'VenueStatusHelper - venues were not updated: ' + e.getMessage());
        }
    }

    /**
     * @description Convenience overload for a batch of events (new + old venues).
     * @param events list of events to evaluate
     */
    public static void updateVenuesForEvents(List<Event__c> events) {
        if (events == null || events.isEmpty()) {
            return;
        }
        Set<Id> venueIds = new Set<Id>();
        for (Event__c event : events) {
            if (event != null && event.Venue__c != null) {
                venueIds.add(event.Venue__c);
            }
        }
        updateVenues(venueIds);
    }

    /**
     * @description Finds every venue that still has at least one confirmed event.
     * @param venueIds venues to check
     * @return ids of the venues that must be marked as Booked
     */
    private static Set<Id> getVenuesWithConfirmedEvent(Set<Id> venueIds) {
        Set<Id> bookedVenueIds = new Set<Id>();
        List<Event__c> confirmedEvents = [
            SELECT Venue__c
            FROM Event__c
            WHERE Venue__c IN :venueIds
              AND Status__c = :EVENT_CONFIRMED
        ];
        for (Event__c confirmedEvent : confirmedEvents) {
            if (confirmedEvent.Venue__c != null) {
                bookedVenueIds.add(confirmedEvent.Venue__c);
            }
        }
        return bookedVenueIds;
    }
}
