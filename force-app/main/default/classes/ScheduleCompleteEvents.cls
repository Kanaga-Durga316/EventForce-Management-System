/**
 * ScheduleCompleteEvents
 * ----------------------
 * Schedulable entry point that runs BatchCompleteEvents every night.
 *
 * Configuration
 *   The schedule and the batch size are read from the custom setting
 *   "Event Scheduler Settings" (API name: EventForce_Schedule__c) so that they can
 *   be changed by an administrator without redeploying code:
 *       Cron_Expression__c  - CronTrigger expression, default "0 0 2 * * ?" (02:00)
 *       Batch_Size__c       - records per execute(), default 200
 *   If no configuration record exists, the documented defaults are used.
 */
public with sharing class ScheduleCompleteEvents implements Schedulable {

    /** Default job name shown in Setup > Scheduled Apex. */
    public static final String JOB_NAME = 'EventForce Complete Events';

    /** Default cron expression: every day at 02:00. */
    public static final String DEFAULT_CRON = '0 0 2 * * ?';

    /** Default number of records per batch scope. */
    public static final Integer DEFAULT_BATCH_SIZE = 200;

    /** @description Runs the batch asynchronously. */
    public void execute(SchedulableContext sc) {
        Integer batchSize = resolveBatchSize();
        Database.executeAsync(new BatchCompleteEvents(batchSize));
    }

    /**
     * @description Schedules (or reschedules) the nightly job using the
     *             configured cron expression. Safe to call repeatedly: Salesforce
     *             only keeps one scheduled job per job name.
     * @return id of the created CronTrigger
     */
    public static String scheduleFromSettings() {
        return System.schedule(JOB_NAME, new ScheduleCompleteEvents(), resolveCronExpression());
    }

    /**
     * @description Schedules the job with an explicit cron expression.
     * @param cronExpression valid CronTrigger expression
     * @param jobName        name of the scheduled job
     * @return id of the created CronTrigger
     */
    public static String schedule(String jobName, String cronExpression) {
        return System.schedule(jobName, new ScheduleCompleteEvents(), cronExpression);
    }

    /** @return cron expression from the custom setting, or the default value. */
    @TestVisible
    private static String resolveCronExpression() {
        EventForce_Schedule__c settings = getSettings();
        if (settings != null && String.isNotBlank(settings.Cron_Expression__c)) {
            return settings.Cron_Expression__c;
        }
        return DEFAULT_CRON;
    }

    /** @return batch size from the custom setting (1 - 200), or the default value. */
    @TestVisible
    private static Integer resolveBatchSize() {
        EventForce_Schedule__c settings = getSettings();
        if (settings != null && settings.Batch_Size__c != null) {
            return Math.max(1, Math.min(settings.Batch_Size__c.intValue(), 200));
        }
        return DEFAULT_BATCH_SIZE;
    }

    /** @return the single configuration record, or null when none is set up. */
    private static EventForce_Schedule__c getSettings() {
        List<EventForce_Schedule__c> settings = EventForce_Schedule__c.getValues().getAll();
        if (settings == null || settings.isEmpty()) {
            return null;
        }
        return settings[0];
    }
}
