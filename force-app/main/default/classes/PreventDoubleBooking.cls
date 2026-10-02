/**
 * PreventDoubleBooking
 * --------------------
 * Stops two events from using the same Venue__c on the same Event_Date__c.
 *
 * Business rule
 *   An event cannot be inserted or updated when another event already exists
 *   with the same Venue__c, the same Event_Date__c and an active status
 *   (any status other than "Cancelled" - a cancelled event does not hold the
 *   venue any more).
 *
 * Bulkification
 *   - ONE SOQL retrieves every existing event that could conflict.
 *   - No SOQL and no DML inside a loop.
 *   - Conflicts inside the same transaction (two new events for the same venue
 *     and date) are detected and reported on both records.
 *   - The record being updated is never reported against itself.
 */
public with sharing class PreventDoubleBooking {

    /** Cancelled events do not block a venue. */
    public static final String EVENT_CANCELLED = 'Cancelled';

    private static final String KEY_SEPARATOR = '|';

    /**
     * @description Called from the before insert / before update trigger context.
     * @param events all Event__c records of the current transaction
     */
    public static void validate(List<Event__c> events) {
        if (events == null || events.isEmpty()) {
            return;
        }

        Set<Id> existingIds = new Set<Id>();
        Set<Id> venueIds = new Set<Id>();
        Set<Date> eventDates = new Set<Date>();

        for (Event__c event : events) {
            if (event == null || event.Venue__c == null || event.Event_Date__c == null) {
                continue;
            }
            if (event.Id != null) {
                existingIds.add(event.Id);
            }
            if (isCancelled(event)) {
                continue;
            }
            venueIds.add(event.Venue__c);
            eventDates.add(event.Event_Date__c);
        }

        if (venueIds.isEmpty() || eventDates.isEmpty()) {
            return;
        }

        Map<String, Event__c> existingConflicts = getExistingConflicts(venueIds, eventDates, existingIds);

        // Venue names are only read when a conflict has to be reported (one query).
        Map<Id, String> venueNamesById = getVenueNames(venueIds);

        // Bookings created earlier in the same transaction.
        Map<String, Event__c> batchBookings = new Map<String, Event__c>();

        for (Event__c event : events) {
            if (event.Venue__c == null || event.Event_Date__c == null || isCancelled(event)) {
                continue;
            }

            String key = buildKey(event.Venue__c, event.Event_Date__c);

            Event__c storedConflict = existingConflicts.get(key);
            if (storedConflict != null) {
                event.addError(
                    'Venue "' + venueNamesById.get(storedConflict.Venue__c) + '" is already booked for ' +
                    formatDate(event.Event_Date__c) + ' by event "' + storedConflict.Name + '". ' +
                    'Choose another venue or another date.',
                    false
                );
                continue;
            }

            Event__c batchConflict = batchBookings.get(key);
            if (batchConflict != null) {
                event.addError(
                    'Venue "' + venueNamesById.get(event.Venue__c) + '" is already used for ' +
                    formatDate(event.Event_Date__c) + ' by event "' + batchConflict.Name + '" ' +
                    'in the same transaction. Each venue can only host one event per day.',
                    false
                );
                continue;
            }

            batchBookings.put(key, event);
        }
    }

    /**
     * @description Reads the venue names of the batch (single query) so that the
     *             error messages can name the venue.
     * @param venueIds venues of the current transaction
     * @return map of venue id to venue name
     */
    private static Map<Id, String> getVenueNames(Set<Id> venueIds) {
        Map<Id, String> venueNamesById = new Map<Id, String>();
        for (Venue__c venue : [SELECT Id, Name FROM Venue__c WHERE Id IN :venueIds]) {
            venueNamesById.put(venue.Id, venue.Name);
        }
        return venueNamesById;
    }

    /**
     * @description Retrieves all stored events that could clash, in a single query.
     * @param venueIds    venues present in the current transaction
     * @param eventDates  event dates present in the current transaction
     * @param existingIds ids of the records being updated (excluded from the query)
     * @return map of "venueId|date" to the conflicting event already in the org
     */
    private static Map<String, Event__c> getExistingConflicts(Set<Id> venueIds, Set<Date> eventDates, Set<Id> existingIds) {
        List<Event__c> conflicts;

        if (existingIds.isEmpty()) {
            // Pure insert: no record of the batch exists in the database yet.
            conflicts = [
                SELECT Id, Name, Venue__c, Event_Date__c, Status__c
                FROM Event__c
                WHERE Venue__c IN :venueIds
                  AND Event_Date__c IN :eventDates
                  AND (Status__c = null OR Status__c != :EVENT_CANCELLED)
            ];
        } else {
            // Insert + update: the updated records must not conflict with themselves.
            conflicts = [
                SELECT Id, Name, Venue__c, Event_Date__c, Status__c
                FROM Event__c
                WHERE Venue__c IN :venueIds
                  AND Event_Date__c IN :eventDates
                  AND Id NOT IN :existingIds
                  AND (Status__c = null OR Status__c != :EVENT_CANCELLED)
            ];
        }

        Map<String, Event__c> conflictsByKey = new Map<String, Event__c>();
        for (Event__c conflict : conflicts) {
            conflictsByKey.put(buildKey(conflict.Venue__c, conflict.Event_Date__c), conflict);
        }
        return conflictsByKey;
    }

    /** @return true when the event does not hold its venue any more. */
    private static Boolean isCancelled(Event__c event) {
        return EVENT_CANCELLED.equalsIgnoreCase(event.Status__c);
    }

    /** @return "venueId|yyyy-MM-dd" - stable key for a venue/day combination. */
    private static String buildKey(Id venueId, Date eventDate) {
        return venueId + KEY_SEPARATOR + DateTime.newInstance(eventDate.year(), eventDate.month(), eventDate.day()).format('yyyy-MM-dd');
    }

    /** @return date rendered in the user locale, used inside error messages. */
    private static String formatDate(Date eventDate) {
        return DateTime.newInstance(eventDate.year(), eventDate.month(), eventDate.day()).format('dd/MM/yyyy');
    }
}

