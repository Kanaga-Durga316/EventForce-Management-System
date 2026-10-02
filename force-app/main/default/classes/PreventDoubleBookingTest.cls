/**
 * PreventDoubleBookingTest
 * ------------------------
 * Covers the double booking protection:
 *   - insert conflict, update conflict, cancelled events, same transaction
 *     conflicts, self updates and records without a venue / date.
 */
@IsTest
private class PreventDoubleBookingTest {

    /** A second event on the same venue and date is rejected. */
    @IsTest
    static void insertOnBookedVenueAndDateFails() {
        Test.startTest();

        Venue__c venue = EventForceTestData.createVenue('Crystal Palace');
        Client__c client = EventForceTestData.createClient('Vertex Corp');
        Date eventDate = Date.today().addDays(20);

        Event__c firstEvent = EventForceTestData.createEvent(
            'Vertex Launch', client.Id, venue.Id, eventDate, 'Confirmed'
        );
        insert firstEvent;

        Event__c secondEvent = EventForceTestData.createEvent(
            'Vertex Product Day', client.Id, venue.Id, eventDate, 'Confirmed'
        );

        Boolean hasError = false;
        String errorMessage = '';
        try {
            insert secondEvent;
        } catch (DmlException e) {
            hasError = true;
            errorMessage = e.getDmlMessage(0);
        }

        System.assert(hasError, 'A second event on the same venue and date must be rejected.');
        System.assert(errorMessage.contains('Crystal Palace'),
            'The error message must name the venue, but was: ' + errorMessage);
        System.assert(errorMessage.contains('Vertex Launch'),
            'The error message must name the conflicting event, but was: ' + errorMessage);

        Test.stopTest();
    }

    /** Same venue, different date -> allowed. */
    @IsTest
    static void sameVenueOnDifferentDateIsAllowed() {
        Test.startTest();

        Venue__c venue = EventForceTestData.createVenue('Crystal Palace');
        Client__c client = EventForceTestData.createClient('Vertex Corp');

        insert new List<Event__c>{
            EventForceTestData.createEvent('Day One', client.Id, venue.Id, Date.today().addDays(20), 'Confirmed'),
            EventForceTestData.createEvent('Day Two', client.Id, venue.Id, Date.today().addDays(21), 'Confirmed')
        };

        System.assertEquals(2, [SELECT COUNT() FROM Event__c WHERE Venue__c = :venue.Id],
            'Two events on different dates are allowed.');

        Test.stopTest();
    }

    /** Different venue, same date -> allowed. */
    @IsTest
    static void differentVenueOnSameDateIsAllowed() {
        Test.startTest();

        Venue__c firstVenue = EventForceTestData.createVenue('Hall North');
        Venue__c secondVenue = EventForceTestData.createVenue('Hall South');
        Client__c client = EventForceTestData.createClient('Vertex Corp');
        Date eventDate = Date.today().addDays(22);

        insert new List<Event__c>{
            EventForceTestData.createEvent('North Event', client.Id, firstVenue.Id, eventDate, 'Confirmed'),
            EventForceTestData.createEvent('South Event', client.Id, secondVenue.Id, eventDate, 'Confirmed')
        };

        System.assertEquals(2, [SELECT COUNT() FROM Event__c WHERE Event_Date__c = :eventDate]);

        Test.stopTest();
    }

    /** A cancelled event does not hold the venue any more. */
    @IsTest
    static void cancelledEventDoesNotBlockTheVenue() {
        Test.startTest();

        Venue__c venue = EventForceTestData.createVenue('Riverside Hall');
        Client__c client = EventForceTestData.createClient('Delta Events');

        Event__c cancelledEvent = EventForceTestData.createEvent(
            'Cancelled Workshop', client.Id, venue.Id, Date.today().addDays(25), 'Confirmed'
        );
        insert cancelledEvent;
        cancelledEvent.Status__c = 'Cancelled';
        update cancelledEvent;

        Event__c replacementEvent = EventForceTestData.createEvent(
            'Replacement Workshop', client.Id, venue.Id, Date.today().addDays(25), 'Confirmed'
        );
        insert replacementEvent;

        System.assertNotEquals(null, [SELECT Id FROM Event__c WHERE Id = :replacementEvent.Id],
            'A cancelled event must free the venue for a new booking.');

        Test.stopTest();
    }

    /** Two new events competing for the same slot inside one transaction. */
    @IsTest
    static void conflictsInsideTheSameTransactionAreDetected() {
        Test.startTest();

        Venue__c venue = EventForceTestData.createVenue('Forum Hall');
        Client__c client = EventForceTestData.createClient('Sigma Group');
        Date eventDate = Date.today().addDays(28);

        List<Event__c> events = new List<Event__c>{
            EventForceTestData.createEvent('Sigma Morning', client.Id, venue.Id, eventDate, 'Confirmed'),
            EventForceTestData.createEvent('Sigma Evening', client.Id, venue.Id, eventDate, 'Confirmed'),
            EventForceTestData.createEvent('Sigma Free Slot', client.Id, venue.Id, Date.today().addDays(29), 'Confirmed')
        };

        Database.SaveResult[] results = Database.insert(events, false);

        System.assert(results[0].isSuccess(), 'The first event of the transaction must be inserted.');
        System.assert(!results[1].isSuccess(), 'The conflicting event of the same transaction must be rejected.');
        System.assert(results[1].getErrors()[0].getStatusCode() == StatusCode.ERROR,
            'The second event must carry an error.');
        System.assert(results[2].isSuccess(), 'The event on a free date must be inserted.');
        System.assertEquals(2, [SELECT COUNT() FROM Event__c WHERE Venue__c = :venue.Id]);

        Test.stopTest();
    }

    /** Updating an event onto an already used venue/date is rejected. */
    @IsTest
    static void updateOntoBookedVenueAndDateFails() {
        Test.startTest();

        Venue__c venue = EventForceTestData.createVenue('Summit Hall');
        Client__c client = EventForceTestData.createClient('Kappa Events');

        insert new List<Event__c>{
            EventForceTestData.createEvent('Kappa Day One', client.Id, venue.Id, Date.today().addDays(11), 'Confirmed'),
            EventForceTestData.createEvent('Kappa Day Two', client.Id, venue.Id, Date.today().addDays(12), 'Confirmed')
        };

        List<Event__c> events = [SELECT Id, Event_Date__c FROM Event__c WHERE Venue__c = :venue.Id ORDER BY Name];
        events[1].Event_Date__c = events[0].Event_Date__c;

        Database.SaveResult[] results = Database.update(events, false);
        System.assert(results[0].isSuccess(), 'The unchanged event stays valid.');
        System.assert(!results[1].isSuccess(), 'Moving an event onto a booked date must be rejected.');

        Test.stopTest();
    }

    /** Updating a record without changing venue or date must not conflict with itself. */
    @IsTest
    static void updateWithoutVenueOrDateChangeDoesNotConflict() {
        Venue__c venue = EventForceTestData.createVenue('Loop Hall');
        Client__c client = EventForceTestData.createClient('Loop Events');
        Event__c event = EventForceTestData.createEvent(
            'Loop Gala', client.Id, venue.Id, Date.today().addDays(35), 'Confirmed'
        );
        insert event;

        event.Status__c = 'Completed';
        event.Name = 'Loop Gala - Final';

        Test.startTest();
        update event;
        Test.stopTest();

        System.assertEquals(1, [SELECT COUNT() FROM Event__c WHERE Venue__c = :venue.Id AND Name = 'Loop Gala - Final'],
            'The record must be updated even though it keeps the same venue and date.');
    }

    /** Events without venue or without date are not validated by this rule. */
    @IsTest
    static void eventsWithoutVenueOrDateAreNotValidated() {
        Test.startTest();

        Client__c client = EventForceTestData.createClient('Edge Events');

        List<Event__c> events = new List<Event__c>{
            EventForceTestData.createEvent('No Venue Event', client.Id, null, Date.today().addDays(8), 'Draft'),
            EventForceTestData.createEvent('No Date Event', client.Id, null, null, 'Draft')
        };
        Database.SaveResult[] results = Database.insert(events, false);

        System.assert(results[0].isSuccess(), 'An event without venue is valid.');
        System.assert(results[1].isSuccess(), 'An event without date is valid.');

        Test.stopTest();
    }

    /** Many events, many venues, mixed result - all in one transaction. */
    @IsTest
    static void bulkInsertOfManyEventsFindsEveryConflict() {
        Test.startTest();

        Client__c client = EventForceTestData.createClient('Bulk Client');
        List<Venue__c> venues = new List<Venue__c>();
        for (Integer i = 0; i < 10; i++) {
            venues.add(new Venue__c(Name = 'Double Booking Venue ' + i, Status__c = 'Available', Capacity__c = 100));
        }
        insert venues;

        Date eventDate = Date.today().addDays(50);
        List<Event__c> events = new List<Event__c>();
        for (Integer i = 0; i < 10; i++) {
            events.add(EventForceTestData.createEvent('First Booking ' + i, client.Id, venues[i].Id, eventDate, 'Confirmed'));
            events.add(EventForceTestData.createEvent('Second Booking ' + i, client.Id, venues[i].Id, eventDate, 'Confirmed'));
        }

        Database.SaveResult[] results = Database.insert(events, false);
        Integer failures = 0;
        for (Database.SaveResult result : results) {
            if (!result.isSuccess()) {
                failures++;
            }
        }

        System.assertEquals(10, failures, 'Exactly the second booking of every venue must fail.');
        System.assertEquals(10, [SELECT COUNT() FROM Event__c WHERE Venue__c IN :new Map<Id, Venue__c>(venues).keySet()]);

        Test.stopTest();
    }
}
