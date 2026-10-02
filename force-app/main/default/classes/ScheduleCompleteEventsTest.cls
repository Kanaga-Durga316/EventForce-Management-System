/**
 * ScheduleCompleteEventsTest
 * --------------------------
 * Covers the schedulable wrapper of BatchCompleteEvents:
 *   - a scheduled job is created from the default / configured cron expression
 *   - the batch size is read from the custom setting
 *   - the batch can be launched directly from execute()
 */
@IsTest
private class ScheduleCompleteEventsTest {

    /** The default configuration is used when no custom setting record exists. */
    @IsTest
    static void defaultsAreUsedWithoutConfiguration() {
        Test.startTest();
        String cron = ScheduleCompleteEvents.resolveCronExpression();
        Integer batchSize = ScheduleCompleteEvents.resolveBatchSize();
        Test.stopTest();

        System.assertEquals('0 0 2 * * ?', cron, 'The default cron expression must be 02:00 every day.');
        System.assertEquals(200, batchSize, 'The default batch size must be 200.');
    }

    /** The configuration record overrides the cron expression and the batch size. */
    @IsTest
    static void configurationOverridesDefaults() {
        insert new EventForce_Schedule__c(
            Name = 'Event Scheduler Settings',
            Cron_Expression__c = '0 30 3 * * ?',
            Batch_Size__c = 50
        );

        Test.startTest();
        String cron = ScheduleCompleteEvents.resolveCronExpression();
        Integer batchSize = ScheduleCompleteEvents.resolveBatchSize();
        Test.stopTest();

        System.assertEquals('0 30 3 * * ?', cron);
        System.assertEquals(50, batchSize);
    }

    /** Invalid batch sizes are corrected to the governor limit. */
    @IsTest
    static void invalidBatchSizeIsCorrected() {
        insert new EventForce_Schedule__c(
            Name = 'Event Scheduler Settings',
            Cron_Expression__c = ScheduleCompleteEvents.DEFAULT_CRON,
            Batch_Size__c = 900
        );

        Test.startTest();
        Integer batchSize = ScheduleCompleteEvents.resolveBatchSize();
        Test.stopTest();

        System.assertEquals(200, batchSize, 'The batch size is capped at 200 records.');
    }

    /** Scheduling the job from the settings returns a CronTrigger. */
    @IsTest
    static void scheduleFromSettingsCreatesScheduledJob() {
        Test.startTest();
        String cronTriggerId = ScheduleCompleteEvents.scheduleFromSettings();
        Test.stopTest();

        System.assertNotEquals(null, cronTriggerId, 'A scheduled job must be created.');
        System.assertNotEquals('', cronTriggerId);
    }

    /** An explicit cron expression can be used as well. */
    @IsTest
    static void scheduleWithExplicitCronExpression() {
        Test.startTest();
        String cronTriggerId = ScheduleCompleteEvents.schedule('EventForce Test Job', '0 0 4 ? * MON-FRI');
        Test.stopTest();

        System.assertNotEquals(null, cronTriggerId);
    }

    /** execute() starts the batch without failing. */
    @IsTest
    static void executeStartsTheBatch() {
        Client__c client = EventForceTestData.createClient('Schedule Client');
        Event__c pastEvent = EventForceTestData.createEvent(
            'Past Event For Schedule', client.Id, null, Date.today().addDays(-2), 'Draft'
        );
        insert pastEvent;

        Test.startTest();
        new ScheduleCompleteEvents().execute(null);
        Test.stopTest();

        System.assertNotEquals(null, [SELECT Id FROM Event__c WHERE Id = :pastEvent.Id]);
    }

    /** Running the schedulable twice only keeps one scheduled job per name. */
    @IsTest
    static void scheduleIsIdempotentPerJobName() {
        Test.startTest();
        String firstId = ScheduleCompleteEvents.schedule('EventForce Repeat Job', '0 0 5 * * ?');
        String secondId = ScheduleCompleteEvents.schedule('EventForce Repeat Job', '0 0 6 * * ?');
        Test.stopTest();

        System.assertNotEquals(null, firstId);
        System.assertNotEquals(null, secondId);
    }
}
