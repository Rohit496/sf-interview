/**
 * @description Batch class to archive Soft Drink records where Tags__c equals 'Archive'.
 *              Sets Status__c to 'Archive' for matching records that are not already archived.
 *
 * @example
 * // Execute the batch with default batch size (200)
 * Database.executeBatch(new SoftDrinkArchiveBatch());
 *
 * // Execute with custom batch size
 * Database.executeBatch(new SoftDrinkArchiveBatch(), 100);
 */
public with sharing class SoftDrinkArchiveBatch implements Database.Batchable<SObject> {

    private static final String TAG_ARCHIVE = 'Archive';
    private static final String STATUS_ARCHIVE = 'Archive';

    /**
     * @description Queries Soft_Drink__c records tagged for archival that are not already archived.
     * @param batchContext The batch context provided by the platform.
     * @return Database.QueryLocator for the matching records.
     */
    public Database.QueryLocator start(Database.BatchableContext batchContext) {
        return Database.getQueryLocator(
            [
                SELECT Id, Status__c
                FROM Soft_Drink__c
                WHERE Tags__c = :TAG_ARCHIVE
                AND Status__c != :STATUS_ARCHIVE
                WITH USER_MODE
            ]
        );
    }

    /**
     * @description Updates Status__c to 'Archive' for each record in the batch scope.
     * @param batchContext The batch context provided by the platform.
     * @param scope List of Soft_Drink__c records to process.
     */
    public void execute(Database.BatchableContext batchContext, List<Soft_Drink__c> scope) {
        for (Soft_Drink__c drink : scope) {
            drink.Status__c = STATUS_ARCHIVE;
        }

        List<Database.SaveResult> results = Database.update(scope, false, AccessLevel.USER_MODE);

        for (Integer i = 0; i < results.size(); i++) {
            if (!results[i].isSuccess()) {
                for (Database.Error err : results[i].getErrors()) {
                    System.debug(LoggingLevel.ERROR,
                        'Failed to archive Soft_Drink__c Id: ' + scope[i].Id +
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

        System.debug(LoggingLevel.INFO,
            'SoftDrinkArchiveBatch completed. ' +
            'Batches processed: ' + job.JobItemsProcessed +
            ' | Errors: ' + job.NumberOfErrors +
            ' | Total batches: ' + job.TotalJobItems
        );
    }
}
