/**
 * EventForceSecurityTest
 * ----------------------
 * Verifies the security model that is part of the EventForce package:
 *   - the five EventForce permission sets are deployed
 *   - a user with the "Event Coordinator" permission set can work on events
 *   - a user without any EventForce permission set is blocked (least privilege)
 *   - Event__c.Organization-Wide Default is Private: a coordinator cannot see
 *     the events of another coordinator without a sharing rule
 */
@IsTest
private class EventForceSecurityTest {

    private static final List<String> PERMISSION_SET_NAMES = new List<String>{
        'Event Admin', 'Event Coordinator', 'Vendor Manager', 'Venue Manager', 'Client'
    };

    /** All EventForce permission sets must be part of the deployment. */
    @IsTest
    static void permissionSetsAreDeployed() {
        for (String permissionSetName : PERMISSION_SET_NAMES) {
            List<PermissionSet> permissionSets = [SELECT Id FROM PermissionSet WHERE Name = :permissionSetName];
            System.assertEquals(1, permissionSets.size(), 'Permission set "' + permissionSetName + '" is missing.');
        }
    }

    /** A coordinator can create and update events, a standard user cannot. */
    @IsTest
    static void permissionsFollowLeastPrivilege() {
        User coordinator = createUser('evfco');
        assignPermissionSet(coordinator.Id, 'Event Coordinator');
        User standardUser = createUser('evfpl');

        Client__c client = EventForceTestData.createClient('Security Client');
        Venue__c venue = EventForceTestData.createVenue('Security Venue');

        System.runAs(coordinator) {
            Test.startTest();
            Event__c event = EventForceTestData.createEvent(
                'Coordinator Event', client.Id, venue.Id, Date.today().addDays(40), 'Draft'
            );
            insert event;
            Test.stopTest();
            System.assertNotEquals(null, [SELECT Id FROM Event__c WHERE Id = :event.Id]);
        }

        Test.startTest();
        Boolean blocked = false;
        try {
            System.runAs(standardUser) {
                insert EventForceTestData.createEvent(
                    'Blocked Event', client.Id, venue.Id, Date.today().addDays(41), 'Draft'
                );
            }
        } catch (Exception e) {
            blocked = true;
        }
        Test.stopTest();

        System.assert(blocked, 'A user without an EventForce permission set must not be able to create events.');
    }

    /** Event__c OWD is Private - coordinators only see their own events. */
    @IsTest
    static void eventObjectIsPrivateByDefault() {
        User firstCoordinator = createUser('evffst');
        User secondCoordinator = createUser('evfsnd');
        assignPermissionSet(firstCoordinator.Id, 'Event Coordinator');
        assignPermissionSet(secondCoordinator.Id, 'Event Coordinator');

        Client__c client = EventForceTestData.createClient('Security Client');
        Venue__c venue = EventForceTestData.createVenue('Security Venue');

        System.runAs(firstCoordinator) {
            insert EventForceTestData.createEvent(
                'Private Event', client.Id, venue.Id, Date.today().addDays(45), 'Draft'
            );
        }

        System.runAs(secondCoordinator) {
            System.assertEquals(0, [SELECT COUNT() FROM Event__c],
                'Event__c is private: another coordinator must not see the event.');
        }

        System.runAs(firstCoordinator) {
            System.assertEquals(1, [SELECT COUNT() FROM Event__c],
                'The owner of the event must see the event.');
        }
    }

    /** Helper: creates a user with the Standard User profile. */
    private static User createUser(String alias) {
        Profile profile = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        User user = new User(
            Alias = alias,
            Email = alias + '@eventforce-example.com',
            Username = alias + '@eventforce-example.com',
            LastName = 'EventForce',
            ProfileId = profile.Id,
            TimeZoneSidKey = 'Asia/Kolkata',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US'
        );
        insert user;
        return user;
    }

    /** Helper: assigns a permission set to a user. */
    private static void assignPermissionSet(Id userId, String permissionSetName) {
        PermissionSet permissionSet = [SELECT Id FROM PermissionSet WHERE Name = :permissionSetName LIMIT 1];
        insert new PermissionSetAssignment(AssigneeId = userId, PermissionSetId = permissionSet.Id);
    }
}

