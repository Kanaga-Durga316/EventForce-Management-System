/**
 * VenueStatusHelperTest
 * ---------------------
 * Covers the venue availability automation:
 *   - a confirmed event books its venue
 *   - a cancelled event releases its venue
 *   - events without a venue never break the helper
 *   - 200 events in one transaction are handled in bulk
 */
@IsTest
private class VenueStatusHelperTest {

    /** Confirmed event -> its venue becomes Booked. */
    @IsTest
    static void confirmedEventBooksVenue() {
        Test.startTest();

        Venue__c venue = EventForceTestData.createVenue('Aurora Hall');
        Client__c client = EventForceTestData.createClient('Sunrise Corp');
        Event__c event = EventForceTestData.createEvent(
            'Sunrise Annual Meet', client.Id, venue.Id, Date.today().addDays(10), 'Confirmed'
        );
        insert event;

        Venue__c updated = [SELECT Status__c FROM Venue__c WHERE Id = :venue.Id];
        System.assertEquals('Booked', updated.Status__c, 'A confirmed event must book the venue.');

        Test.stopTest();
    }

    /** Cancelled event -> the venue is released again. */
    @IsTest
    static void cancelledEventReleasesVenue() {
        Test.startTest();

        Venue__c venue = EventForceTestData.createVenue('Aurora Hall');
        Client__c client = EventForceTestData.createClient('Sunrise Corp');
        Event__c event = EventForceTestData.createEvent(
            'Sunrise Annual Meet', client.Id, venue.Id, Date.today().addDays(10), 'Confirmed'
        );
        insert event;
        System.assertEquals('Booked', [SELECT Status__c FROM Venue__c WHERE Id = :venue.Id].Status__c);

        event.Status__c = 'Cancelled';
        update event;

        System.assertEquals('Available', [SELECT Status__c FROM Venue__c WHERE Id = :venue.Id].Status__c,
            'A cancelled event must release the venue.');

        Test.stopTest();
    }

    /** Draft event -> the venue stays available (only Confirmed books a venue). */
    @IsTest
    static void draftEventDoesNotBookVenue() {
        Test.startTest();

        Venue__c venue = EventForceTestData.createVenue('Banquet Block');
        Client__c client = EventForceTestData.createClient('Nova Ltd');
        Event__c event = EventForceTestData.createEvent(
            'Draft Plan', client.Id, venue.Id, Date.today().addDays(20), 'Draft'
        );
        insert event;

        System.assertEquals('Available', [SELECT Status__c FROM Venue__c WHERE Id = :venue.Id].Status__c,
            'Only a confirmed event may book a venue.');

        Test.stopTest();
    }

    /** Two confirmed events on different dates keep the venue booked after a cancellation of one of them. */
    @IsTest
    static void venueStaysBookedWhileAnotherConfirmedEventExists() {
        Test.startTest();

        Venue__c venue = EventForceTestData.createVenue('Grand Ballroom');
        Client__c client = EventForceTestData.createClient('Orion Group');
        Event__c firstEvent = EventForceTestData.createEvent(
            'Orion Day One', client.Id, venue.Id, Date.today().addDays(5), 'Confirmed'
        );
        Event__c secondEvent = EventForceTestData.createEvent(
            'Orion Day Two', client.Id, venue.Id, Date.today().addDays(6), 'Confirmed'
        );
        insert new List<Event__c>{ firstEvent, secondEvent };

        firstEvent.Status__c = 'Cancelled';
        update firstEvent;

        System.assertEquals('Booked', [SELECT Status__c FROM Venue__c WHERE Id = :venue.Id].Status__c,
            'The venue must stay booked while a second confirmed event still uses it.');

        secondEvent.Status__c = 'Cancelled';
        update secondEvent;

        System.assertEquals('Available', [SELECT Status__c FROM Venue__c WHERE Id = :venue.Id].Status__c,
            'The last cancelled event must release the venue.');

        Test.stopTest();
    }

    /** Moving an event to another venue releases the previous venue. */
    @IsTest
    static void movingEventReleasesPreviousVenue() {
        Test.startTest();

        Venue__c firstVenue = EventForceTestData.createVenue('Hall One');
        Venue__c secondVenue = EventForceTestData.createVenue('Hall Two');
        Client__c client = EventForceTestData.createClient('Zenith Inc');
        Event__c event = EventForceTestData.createEvent(
            'Zenity Summit', client.Id, firstVenue.Id, Date.today().addDays(12), 'Confirmed'
        );
        insert event;

        event.Venue__c = secondVenue.Id;
        update event;

        System.assertEquals('Available', [SELECT Status__c FROM Venue__c WHERE Id = :firstVenue.Id].Status__c,
            'The old venue must be released.');
        System.assertEquals('Booked', [SELECT Status__c FROM Venue__c WHERE Id = :secondVenue.Id].Status__c,
            'The new venue must be booked.');

        Test.stopTest();
    }

    /** Events without a venue must not break the automation. */
    @IsTest
    static void eventWithoutVenueIsIgnored() {
        Test.startTest();

        Client__c client = EventForceTestData.createClient('Lumen Ltd');
        Event__c event = EventForceTestData.createEvent(
            'Venue To Be Decided', client.Id, null, Date.today().addDays(30), 'Draft'
        );
        insert event;

        System.assertNotEquals(null, [SELECT Id FROM Event__c WHERE Id = :event.Id],
            'An event without a venue must still be saved.');

        Test.stopTest();
    }

    /** 200 events across 200 venues in a single transaction (bulk behaviour). */
    @IsTest
    static void bulkConfirmedEventsBookEveryVenue() {
        Test.startTest();

        List<Venue__c> venues = new List<Venue__c>();
        List<Event__c> events = new List<Event__c>();
        Client__c client = EventForceTestData.createClient('Bulk Client');

        for (Integer i = 0; i < 200; i++) {
            venues.add(new Venue__c(Name = 'Bulk Venue ' + i, Status__c = 'Available', Capacity__c = 100 + i));
        }
        insert venues;

        for (Integer i = 0; i < 200; i++) {
            events.add(EventForceTestData.createEvent(
                'Bulk Event ' + i, client.Id, venues[i].Id, Date.today().addDays(40 + i), 'Confirmed'
            ));
        }
        insert events;

        Integer bookedVenues = [
            SELECT COUNT()
            FROM Venue__c
            WHERE Id IN :new Map<Id, Venue__c>(venues).keySet() AND Status__c = 'Booked'
        ];
        System.assertEquals(200, bookedVenues, 'All 200 venues must be booked in one transaction.');

        Test.stopTest();
    }

    /** Cancelling all confirmed events of a bulk insert releases the venues. */
    @IsTest
    static void bulkCancellationReleasesEveryVenue() {
        Test.startTest();

        List<Venue__c> venues = new List<Venue__c>();
        List<Event__c> events = new List<Event__c>();
        Client__c client = EventForceTestData.createClient('Bulk Client');

        for (Integer i = 0; i < 50; i++) {
            venues.add(new Venue__c(Name = 'Release Venue ' + i, Status__c = 'Available', Capacity__c = 80));
        }
        insert venues;
        for (Integer i = 0; i < 50; i++) {
            events.add(EventForceTestData.createEvent(
                'Release Event ' + i, client.Id, venues[i].Id, Date.today().addDays(60 + i), 'Confirmed'
            ));
        }
        insert events;

        for (Event__c event : events) {
            event.Status__c = 'Cancelled';
        }
        update events;

        Integer bookedVenues = [SELECT COUNT() FROM Venue__c WHERE Id IN :new Map<Id, Venue__c>(venues).keySet() AND Status__c = 'Booked'];
        System.assertEquals(0, bookedVenues, 'Every venue must be released after a bulk cancellation.');

        Test.stopTest();
    }

    /** The helper can also be called directly with a set of venue ids. */
    @IsTest
    static void helperCanBeCalledDirectly() {
        Test.startTest();

        Venue__c venue = EventForceTestData.createVenue('Direct Call Hall');
        Client__c client = EventForceTestData.createClient('Direct Client');
        Event__c event = EventForceTestData.createEvent(
            'Direct Call Event', client.Id, venue.Id, Date.today().addDays(15), 'Confirmed'
        );
        insert event;

        VenueStatusHelper.updateVenues(new Set<Id>{ venue.Id });
        System.assertEquals('Booked', [SELECT Status__c FROM Venue__c WHERE Id = :venue.Id].Status__c);

        VenueStatusHelper.updateVenuesForEvents(new List<Event__c>{ event });
        VenueStatusHelper.updateVenues(null);
        VenueStatusHelper.updateVenues(new Set<Id>());
        System.assertEquals(1, [SELECT COUNT() FROM Venue__c WHERE Id = :venue.Id AND Status__c = 'Booked']);

        Test.stopTest();
    }
}
