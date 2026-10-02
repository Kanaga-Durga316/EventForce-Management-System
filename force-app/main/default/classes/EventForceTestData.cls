/**
 * EventForceTestData
 * ------------------
 * Central factory for the test data of the EventForce Management System.
 * Every test method creates its own data, nothing is shared between tests and
 * no test depends on data that already exists in the org.
 */
@IsTest
public class EventForceTestData {

    /** @return a client with a unique name inside the test transaction. */
    public static Client__c createClient(String name) {
        Client__c client = new Client__c(
            Name = name,
            Email__c = 'contact@eventforce.test',
            Phone__c = '+91 90000 00000',
            Company__c = name + ' Enterprises'
        );
        insert client;
        return client;
    }

    /** @return an available venue with a unique name inside the test transaction. */
    public static Venue__c createVenue(String name) {
        Venue__c venue = new Venue__c(
            Name = name,
            Status__c = 'Available',
            City__c = 'Pune',
            Capacity__c = 250,
            Contact_Email__c = 'venue@eventforce.test'
        );
        insert venue;
        return venue;
    }

    /** @return an event. Null arguments are left empty on purpose. */
    public static Event__c createEvent(String name, Id clientId, Id venueId, Date eventDate, String status) {
        Event__c event = new Event__c(
            Name = name,
            Client__c = clientId,
            Venue__c = venueId,
            Event_Date__c = eventDate,
            Start_Date__c = eventDate,
            End_Date__c = eventDate,
            Status__c = status
        );
        return event;
    }

    /** @return the number of currently stored events, used to prove "no extra update". */
    public static Integer countEvents() {
        return [SELECT COUNT() FROM Event__c];
    }
}
