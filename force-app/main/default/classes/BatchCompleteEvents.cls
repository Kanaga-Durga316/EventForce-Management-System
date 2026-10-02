/**
 * BatchCompleteEvents
 * -------------------
 * Marks every past event as "Completed".
 *
 * Behaviour
 *   - Only events whose Event_Date__c is before today are considered.
 *   - Only events whose status can logically become Completed are selected, so
 *     cancelled events and already completed events are never touched.
 *   - The query is run once for the whole batch scope (Database.QueryLocator),
 *     therefore the class is safe for large data volumes.
 *   - Partial success: if one record fails, the others are still completed.
 */
public with sharing class BatchCompleteEvents implements Database.Batchable<SObject> {

    /** Default number of records processed in one execute(). */
    public static final Integer DEFAULT_SCOPE_SIZE = 200;

    /** Event__c.Status__c value written by the batch. */
    public static final String STATUS_COMPLETED = 'Completed';

    /** Statuses that are still allowed to move to Completed. */
    @TestVisible
    private static final Set<String> ELIGIBLE_STATUSES = new Set<String>{ 'Draft', 'Pending Cancellation', 'Confirmed' };

    /** Records processed per execute() call - configurable through ScheduleCompleteEvents. */
    public Integer scopeSize { get; private set; }

    public BatchCompleteEvents() {
        this(DEFAULT_SCOPE_SIZE);
    }

    public BatchCompleteEvents(Integer scopeSize) {
        this.scopeSize = (scopeSize == null || scopeSize < 1) ? DEFAULT_SCOPE_SIZE : Math.min(scopeSize, 200);
    }

    /**
     * @description Collects the records to update.
     * @param bc batch context (unused)
     * @return query locator over the events that are still to be completed
     */
    public Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator(
            'SELECT Id, Name, Event_Date__c, Status__c ' +
            'FROM Event__c ' +
            'WHERE Event_Date__c != null ' +
            'AND Event_Date__c < :System.today() ' +
            'AND Status__c IN :ELIGIBLE_STATUSES'
        );
    }

    /**
     * @description Updates one scope. One DML statement, no SOQL.
     * @param bc     batch context
     * @param scope  list of Event__c records
     */
    public void execute(Database.BatchableContext bc, List<Event__c> scope) {
        if (scope == null || scope.isEmpty()) {
            return;
        }

        List<Event__c> eventsToUpdate = new List<Event__c>();
        for (Event__c event : scope) {
            if (event.Status__c == STATUS_COMPLETED) {
                continue; // never write a record that is already up to date
            }
            event.Status__c = STATUS_COMPLETED;
            eventsToUpdate.add(event);
        }

        if (eventsToUpdate.isEmpty()) {
            return;
        }

        try {
            // allOrNone = false so a single failure does not block the scope.
            Database.update(eventsToUpdate, false);
        } catch (DmlException e) {
            System.debug(LoggingLevel.ERROR, 'BatchCompleteEvents - DML error: ' + e.getMessage());
        }
    }

    /**
     * @description Called once after the last execute().
     * @param bc batch context
     */
    public void finish(Database.BatchableContext bc) {
        System.debug(LoggingLevel.INFO, 'BatchCompleteEvents finished for batch job ' + bc.getJobId());
    }
}
