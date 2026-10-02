/**
 * EventTriggerHandlerTest
 * -----------------------
 * Exercises EventTrigger13 end to end, so both the trigger and the handler are
 * covered:
 *   - validation on before insert / before update (double booking)
 *   - venue booking on after insert
 *   - venue release on after update
 *   - no database work when nothing relevant changed
 */
@IsTest
private class EventTriggerHandlerTest {

    /** After insert: a confirmed event books the venue. */
    @IsTest
    static void insertConfirmedEventBooksVenue() {
        Venue__c venue = EventForceTestData.createVenue('Handler Hall');
        Client__c client = EventForceTestData.createClient('Handler Client');

        Test.startTest();
        insert EventForceTestData.createEvent(
            'Handler Event', client.Id, venue.Id, Date.today().addDays(9), 'Confirmed'
        );
        Test.stopTest();

        System.assertEquals('Booked', [SELECT Status__c FROM Venue__c WHERE Id = :venue.Id].Status__c);
    }

    /** Before insert: the trigger rejects a double booking. */
    @IsTest
    static void insertDoubleBookingIsRejectedByTrigger() {
        Venue__c venue = EventForceTestData.createVenue('Handler Hall');
        Client__c client = EventForceTestData.createClient('Handler Client');
        Date eventDate = Date.today().addDays(9);
        insert EventForceTestData.createEvent('First Booking', client.Id, venue.Id, eventDate, 'Confirmed');

        Test.startTest();
        Boolean rejected = false;
        try {
            insert EventForceTestData.createEvent('Second Booking', client.Id, venue.Id, eventDate, 'Confirmed');
        } catch (DmlException e) {
            rejected = true;
        }
        Test.stopTest();

        System.assert(rejected, 'EventTrigger13 must prevent a double booking on before insert.');
        System.assertEquals(1, [SELECT COUNT() FROM Event__c WHERE Venue__c = :venue.Id]);
    }

    /** Before update: moving an event onto a booked date is rejected. */
    @IsTest
    static void updateDoubleBookingIsRejectedByTrigger() {
        Venue__c venue = EventForceTestData.createVenue('Handler Hall');
        Client__c client = EventForceTestData.createClient('Handler Client');
        insert new List<Event__c>{
            EventForceTestData.createEvent('Day One', client.Id, venue.Id, Date.today().addDays(14), 'Confirmed'),
            EventForceTestData.createEvent('Day Two', client.Id, venue.Id, Date.today().addDays(15), 'Confirmed')
        };

        List<Event__c> events = [SELECT Id, Event_Date__c FROM Event__c WHERE Venue__c = :venue.Id ORDER BY Name];

        Test.startTest();
        events[1].Event_Date__c = events[0].Event_Date__c;
        Boolean rejected = false;
        try {
            update events;
        } catch (DmlException e) {
            rejected = true;
        }
        Test.stopTest();

        System.assert(rejected, 'EventTrigger13 must prevent a double booking on before update.');
    }

    /** After update: cancelling a confirmed event releases the venue. */
    @IsTest
    static void cancelEventReleasesVenue() {
        Venue__c venue = EventForceTestData.createVenue('Handler Hall');
        Client__c client = EventForceTestData.createClient('Handler Client');
        Event__c event = EventForceTestData.createEvent(
            'Cancellable Event', client.Id, venue.Id, Date.today().addDays(18), 'Confirmed'
        );
        insert event;

        Test.startTest();
        event.Status__c = 'Cancelled';
        event.Cancellation_Reason__c = 'Client postponed the event';
        update event;
        Test.stopTest();

        System.assertEquals('Available', [SELECT Status__c FROM Venue__c WHERE Id = :venue.Id].Status__c);
    }

    /** An update that touches neither status nor venue does not update the venue. */
    @IsTest
    static void unrelatedUpdateDoesNotUpdateVenue() {
        Venue__c venue = EventForceTestData.createVenue('Handler Hall');
        Client__c client = EventForceTestData.createClient('Handler Client');
        Event__c event = EventForceTestData.createEvent(
            'Stable Event', client.Id, venue.Id, Date.today().addDays(21), 'Confirmed'
        );
        insert event;
        DateTime venueModifiedBefore = [SELECT LastModifiedDate FROM Venue__c WHERE Id = :venue.Id].LastModifiedDate;

        Test.startTest();
        event.Vendor_Contact_Email__c = 'vendor@eventforce.test';
        update event;
        Test.stopTest();

        Venue__c reloaded = [SELECT LastModifiedDate, Status__c FROM Venue__c WHERE Id = :venue.Id];
        System.assertEquals('Booked', reloaded.Status__c);
        System.assert(venueModifiedBefore == reloaded.LastModifiedDate,
            'The venue must not be updated when neither the venue nor the event status changed.');
    }

    /** Insert of several events in one transaction books every venue. */
    @IsTest
    static void bulkInsertThroughTrigger() {
        Client__c client = EventForceTestData.createClient('Handler Client');
        List<Venue__c> venues = new List<Venue__c>();
        for (Integer i = 0; i < 5; i++) {
            venues.add(new Venue__c(Name = 'Trigger Venue ' + i, Status__c = 'Available', Capacity__c = 120));
        }
        insert venues;

        List<Event__c> events = new List<Event__c>();
        for (Integer i = 0; i < 5; i++) {
            events.add(EventForceTestData.createEvent(
                'Trigger Event ' + i, client.Id, venues[i].Id, Date.today().addDays(30 + i), 'Confirmed'
            ));
        }

        Test.startTest();
        insert events;
        Test.stopTest();

        System.assertEquals(5, [SELECT COUNT() FROM Venue__c WHERE Id IN :new Map<Id, Venue__c>(venues).keySet() AND Status__c = 'Booked']);
    }

    /** The handler is safe to call with an empty batch (defensive behaviour). */
    @IsTest
    static void handlerIgnoresEmptyBatch() {
        Test.startTest();
        EventTriggerHandler.handle(new List<Event__c>(), new Map<Id, Event__c>());
        EventTriggerHandler.handle(null, null);
        Test.stopTest();

        System.assertEquals(0, EventForceTestData.countEvents());
    }
}
