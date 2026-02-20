/**
 * @description Batch class to identify Open (non-converted) Lead records that have been open
 *              for more than 60 days and create a follow-up Task for each Lead.
 *              Task is assigned to the Lead owner with a 2-day due date.
 *
 * @see KAN-4
 *
 * @example
 * // Execute the batch with default 60-day threshold
 * Database.executeBatch(new OpenLeadFollowUpBatch());
 *
 * // Execute with custom batch size
 * Database.executeBatch(new OpenLeadFollowUpBatch(), 50);
 */
public with sharing class OpenLeadFollowUpBatch implements Database.Batchable<SObject> {

    private static final String TASK_SUBJECT = 'Close the Lead or mark it Bogus';
    private static final String TASK_STATUS = 'Not Started';
    private static final String TASK_PRIORITY = 'Normal';
    private static final Integer DAYS_OPEN_THRESHOLD = 60;
    private static final Integer TASK_DUE_DAYS = 2;

    /**
     * Holds the CreatedDate cutoff for the start query.
     * Must be public so Salesforce's batch serialization preserves it across
     * start/execute/finish calls. Private fields are not serialized by the batch framework.
     * Use the single-arg constructor (or set this field directly in tests) to override.
     */
    public Date queryThresholdDate;

    public OpenLeadFollowUpBatch() {
        this.queryThresholdDate = Date.today().addDays(-DAYS_OPEN_THRESHOLD);
    }

    /**
     * @description Constructor that allows overriding the threshold date.
     *              Useful for scheduled jobs that need a custom lookback window.
     * @param thresholdDate Cutoff date — Leads created on or before this date are processed.
     */
    public OpenLeadFollowUpBatch(Date thresholdDate) {
        this.queryThresholdDate = thresholdDate;
    }

    // ─── Batchable Interface ──────────────────────────────────────────────────

    /**
     * @description Queries Open (non-converted) Lead records created on or before the threshold date.
     * @param batchContext The batch context provided by the platform.
     * @return Database.QueryLocator for the matching Lead records.
     */
    public Database.QueryLocator start(Database.BatchableContext batchContext) {
        Date thresholdDate = queryThresholdDate;
        return Database.getQueryLocator(
            [
                SELECT Id, OwnerId
                FROM Lead
                WHERE IsConverted = false
                AND CreatedDate <= :thresholdDate
            ]
        );
    }

    /**
     * @description Creates a follow-up Task for each Lead in the batch scope,
     *              assigned to the Lead owner with a 2-day due date.
     * @param batchContext The batch context provided by the platform.
     * @param scope List of Lead records to process.
     */
    public void execute(Database.BatchableContext batchContext, List<Lead> scope) {
        Date dueDate = Date.today().addDays(TASK_DUE_DAYS);
        List<Task> tasksToInsert = new List<Task>();

        for (Lead lead : scope) {
            tasksToInsert.add(
                new Task(
                    Subject = TASK_SUBJECT,
                    WhoId = lead.Id,
                    OwnerId = lead.OwnerId,
                    ActivityDate = dueDate,
                    Status = TASK_STATUS,
                    Priority = TASK_PRIORITY
                )
            );
        }

        if (tasksToInsert.isEmpty()) {
            return;
        }

        List<Database.SaveResult> results = Database.insert(tasksToInsert, false, AccessLevel.USER_MODE);

        for (Integer i = 0; i < results.size(); i++) {
            if (!results[i].isSuccess()) {
                for (Database.Error err : results[i].getErrors()) {
                    System.debug(
                        LoggingLevel.ERROR,
                        'Failed to create Task for Lead Id: ' + scope[i].Id +
                        ' | Error: ' + err.getStatusCode() + ' - ' + err.getMessage()
                    );
                }
            }
        }
    }

    /**
     * @description Called after all batches complete. Logs a summary of the batch execution.
     * @param batchContext The batch context provided by the platform.
     */
    public void finish(Database.BatchableContext batchContext) {
        AsyncApexJob job = [
            SELECT Id, NumberOfErrors, JobItemsProcessed, TotalJobItems
            FROM AsyncApexJob
            WHERE Id = :batchContext.getJobId()
            WITH USER_MODE
        ];

        System.debug(
            LoggingLevel.INFO,
            'OpenLeadFollowUpBatch completed. ' +
            'Batches processed: ' + job.JobItemsProcessed +
            ' | Errors: ' + job.NumberOfErrors +
            ' | Total batches: ' + job.TotalJobItems
        );
    }
}
