/**
 * BatchCompleteEventsTest
 * -----------------------
 * Covers the automatic event completion:
 *   - past events are completed
 *   - today and future events are untouched
 *   - cancelled and already completed events are never re-processed
 *   - a custom scope size is honoured
 */
@IsTest
private class BatchCompleteEventsTest {

    /** Past events are completed, future events are not. */
    @IsTest
    static void pastEventsAreCompleted() {
        Client__c client = EventForceTestData.createClient('Batch Client');
        Venue__c venue = EventForceTestData.createVenue('Batch Venue');

        Event__c pastDraft = EventForceTestData.createEvent(
            'Past Draft Event', client.Id, venue.Id, Date.today().addDays(-5), 'Draft'
        );
        Event__c pastPending = EventForceTestData.createEvent(
            'Past Pending Event', client.Id, null, Date.today().addDays(-3), 'Pending Cancellation'
        );
        Event__c todayEvent = EventForceTestData.createEvent(
            'Today Event', client.Id, null, Date.today(), 'Draft'
        );
        Event__c futureEvent = EventForceTestData.createEvent(
            'Future Event', client.Id, null, Date.today().addDays(7), 'Draft'
        );
        insert new List<Event__c>{ pastDraft, pastPending, todayEvent, futureEvent };

        Test.startTest();
        Database.executeAsync(new BatchCompleteEvents());
        Test.stopTest();

        Set<Id> eventIds = new Set<Id>{ new List<Id>{ pastDraft.Id, pastPending.Id, todayEvent.Id, futureEvent.Id } };
        Map<Id, String> statusById = new Map<Id, String>([SELECT Id, Status__c FROM Event__c WHERE Id IN :eventIds]);

        System.assertEquals('Completed', statusById.get(pastDraft.Id), 'A past draft event must be completed.');
        System.assertEquals('Completed', statusById.get(pastPending.Id), 'A past pending event must be completed.');
        System.assertEquals('Draft', statusById.get(todayEvent.Id), 'An event of today must not be completed.');
        System.assertEquals('Draft', statusById.get(futureEvent.Id), 'A future event must not be completed.');
    }

    /** Cancelled and already completed events are outside the batch scope. */
    @IsTest
    static void cancelledAndCompletedEventsAreNotTouched() {
        Client__c client = EventForceTestData.createClient('Batch Client');

        Event__c pastCancelled = EventForceTestData.createEvent(
            'Past Cancelled Event', client.Id, null, Date.today().addDays(-10), 'Cancelled'
        );
        Event__c pastCompleted = EventForceTestData.createEvent(
            'Past Completed Event', client.Id, null, Date.today().addDays(-20), 'Completed'
        );
        insert new List<Event__c>{ pastCancelled, pastCompleted };

        DateTime completedModifiedBefore = [SELECT LastModifiedDate FROM Event__c WHERE Id = :pastCompleted.Id].LastModifiedDate;

        Test.startTest();
        Database.executeAsync(new BatchCompleteEvents(50));
        Test.stopTest();

        System.assertEquals('Cancelled', [SELECT Status__c FROM Event__c WHERE Id = :pastCancelled.Id].Status__c,
            'A cancelled event stays cancelled.');
        System.assertEquals('Completed', [SELECT Status__c FROM Event__c WHERE Id = :pastCompleted.Id].Status__c,
            'A completed event stays completed.');
        System.assert(completedModifiedBefore == [SELECT LastModifiedDate FROM Event__c WHERE Id = :pastCompleted.Id].LastModifiedDate,
            'A record outside the batch scope must not be updated at all.');
    }

    /** Completing a past confirmed event releases the venue it was holding. */
    @IsTest
    static void completingPastEventReleasesVenue() {
        Client__c client = EventForceTestData.createClient('Batch Client');
        Venue__c venue = EventForceTestData.createVenue('Batch Venue');

        Event__c pastConfirmed = EventForceTestData.createEvent(
            'Past Confirmed Event', client.Id, venue.Id, Date.today().addDays(-1), 'Draft'
        );
        insert pastConfirmed;
        pastConfirmed.Status__c = 'Confirmed';
        update pastConfirmed;
        System.assertEquals('Booked', [SELECT Status__c FROM Venue__c WHERE Id = :venue.Id].Status__c);

        Test.startTest();
        Database.executeAsync(new BatchCompleteEvents());
        Test.stopTest();

        System.assertEquals('Completed', [SELECT Status__c FROM Event__c WHERE Id = :pastConfirmed.Id].Status__c);
        System.assertEquals('Available', [SELECT Status__c FROM Venue__c WHERE Id = :venue.Id].Status__c,
            'A completed event no longer holds the venue.');
    }

    /** Running the batch on an org without eligible events must not fail. */
    @IsTest
    static void batchWithoutEligibleRecordsDoesNothing() {
        Client__c client = EventForceTestData.createClient('Batch Client');
        Event__c futureEvent = EventForceTestData.createEvent(
            'Only Future Event', client.Id, null, Date.today().addDays(3), 'Draft'
        );
        insert futureEvent;

        Test.startTest();
        Database.executeAsync(new BatchCompleteEvents());
        Test.stopTest();

        System.assertEquals(1, [SELECT COUNT() FROM Event__c WHERE Status__c = 'Draft']);
    }

    /** The batch scope size is configurable and validated. */
    @IsTest
    static void scopeSizeIsConfigurableAndValidated() {
        System.assertEquals(BatchCompleteEvents.DEFAULT_SCOPE_SIZE, new BatchCompleteEvents().scopeSize);
        System.assertEquals(25, new BatchCompleteEvents(25).scopeSize);
        System.assertEquals(200, new BatchCompleteEvents(5000).scopeSize, 'The scope size is capped at 200.');
        System.assertEquals(200, new BatchCompleteEvents(null).scopeSize);
        System.assertEquals(200, new BatchCompleteEvents(0).scopeSize);
    }

    /** The locator only selects events that can be completed. */
    @IsTest
    static void startLocatorOnlyReturnsEligibleEvents() {
        Client__c client = EventForceTestData.createClient('Batch Client');
        insert new List<Event__c>{
            EventForceTestData.createEvent('Locator Past Draft', client.Id, null, Date.today().addDays(-1), 'Draft'),
            EventForceTestData.createEvent('Locator Past Cancelled', client.Id, null, Date.today().addDays(-1), 'Cancelled'),
            EventForceTestData.createEvent('Locator Future Draft', client.Id, null, Date.today().addDays(1), 'Draft')
        };

        Test.startTest();
        Database.QueryLocator locator = new BatchCompleteEvents().start(null);
        List<Event__c> scope = locator.getRecords();
        Test.stopTest();

        System.assertEquals(1, scope.size(), 'Only the past, still open event is in scope.');
        System.assertEquals('Locator Past Draft', scope[0].Name);
    }
}
